// FitTrackerTests/AccountDeletionServiceTests.swift
// TEST-011: AccountDeletionService — grace period lifecycle.
// Tests the deterministic state transitions (request/cancel/check).
// executeDeletion() cascades across network-dependent stores and is
// covered by higher-level integration tests (TEST-025, deferred).

import XCTest
@testable import FitTracker

@MainActor
final class AccountDeletionServiceTests: XCTestCase {

    private let deletionKey = "ft.deletion.scheduledAt"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: deletionKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: deletionKey)
        super.tearDown()
    }

    // MARK: - Grace period lifecycle

    func testRequestDeletion_setsScheduledAtAndPersists() async {
        let service = makeService()
        XCTAssertNil(service.deletionScheduledAt)

        await service.requestDeletion(authMethod: "email")

        XCTAssertNotNil(service.deletionScheduledAt)
        XCTAssertTrue(service.isDeletionPending)
        XCTAssertGreaterThan(UserDefaults.standard.double(forKey: deletionKey), 0,
                             "Deletion timestamp must persist to UserDefaults")
    }

    func testCancelDeletion_clearsStateAndRemovesFromDefaults() async {
        let service = makeService()
        await service.requestDeletion(authMethod: "apple")
        XCTAssertTrue(service.isDeletionPending)

        await service.cancelDeletion()

        XCTAssertNil(service.deletionScheduledAt)
        XCTAssertFalse(service.isDeletionPending)
        XCTAssertEqual(UserDefaults.standard.double(forKey: deletionKey), 0,
                       "Deletion timestamp must be removed from UserDefaults")
    }

    func testCheckGracePeriod_restoresPendingDeletionFromDefaults() async {
        // Simulate an app relaunch: write directly to UserDefaults, then check
        let twoDaysAgo = Date().addingTimeInterval(-2 * 86_400)
        UserDefaults.standard.set(twoDaysAgo.timeIntervalSince1970, forKey: deletionKey)

        let service = makeService()
        XCTAssertNil(service.deletionScheduledAt, "Fresh service shouldn't auto-load")
        await service.checkGracePeriod()
        XCTAssertNotNil(service.deletionScheduledAt)
        XCTAssertEqual(service.deletionScheduledAt?.timeIntervalSince1970 ?? 0,
                       twoDaysAgo.timeIntervalSince1970, accuracy: 1.0)
    }

    func testCheckGracePeriod_noStoredValue_leavesStateNil() async {
        let service = makeService()
        await service.checkGracePeriod()
        XCTAssertNil(service.deletionScheduledAt)
    }

    // MARK: - Computed properties

    func testDaysRemaining_freshRequest_is30() async {
        let service = makeService()
        await service.requestDeletion(authMethod: "email")
        XCTAssertNotNil(service.daysRemaining)
        // Freshly scheduled — should be 29 or 30 depending on clock jitter
        XCTAssertGreaterThanOrEqual(service.daysRemaining ?? 0, 29)
        XCTAssertLessThanOrEqual(service.daysRemaining ?? 0, 30)
    }

    func testIsGracePeriodExpired_freshRequest_false() async {
        let service = makeService()
        await service.requestDeletion(authMethod: "email")
        XCTAssertFalse(service.isGracePeriodExpired)
    }

    func testIsGracePeriodExpired_35DaysAgo_true() async {
        let thirtyFiveDaysAgo = Date().addingTimeInterval(-35 * 86_400)
        UserDefaults.standard.set(thirtyFiveDaysAgo.timeIntervalSince1970, forKey: deletionKey)

        let service = makeService()
        await service.checkGracePeriod()
        XCTAssertTrue(service.isGracePeriodExpired,
                      "Deletion scheduled 35 days ago should be past the 30-day grace window")
    }

    // MARK: - Cascade + network-churn chaos (FIT-157 / T9 T3 — adversarial edge cases)
    //
    // T3 exercises the GDPR deletion-intent state machine and its documented
    // "local is source of truth, remote is best-effort" resilience (Audit
    // BE-023) under adversarial conditions that need NO network mock: in the
    // test environment the Supabase/CloudKit stores are unreachable, so the
    // best-effort remote writes throw — which is precisely the network-churn
    // condition these assertions pin down.
    //
    // The destructive full executeDeletion() cascade (partial-failure across the
    // remote stores) is now covered by the "executeDeletion() partial-failure
    // cascade" section below, via the AccountDeletionSupabaseSyncing /
    // AccountDeletionCloudSyncing protocol seam (T9 — conformance-only extensions
    // on the `final` high-risk services, zero behavior change). The grace-period
    // tests here stay seam-free and side-effect-isolated (they touch only the
    // deletion key that setUp/tearDown already resets).

    func testRequestDeletion_remoteFailureDoesNotLoseLocalIntent() async {
        // Network-churn resilience: even when the best-effort remote write to
        // Supabase fails (offline test env), the LOCAL deletion intent must
        // survive — local is the source of truth (Audit BE-023).
        let service = makeService()
        await service.requestDeletion(authMethod: "email")

        XCTAssertNotNil(service.deletionScheduledAt,
                        "Local deletion intent must survive a failed remote sync")
        XCTAssertTrue(service.isDeletionPending)
        XCTAssertGreaterThan(UserDefaults.standard.double(forKey: deletionKey), 0,
                             "Local persistence must not depend on remote reachability")
        // deletionError MAY be set (remote failed) — allowed; the invariant is
        // that the local intent is intact regardless of remote outcome.
    }

    func testCancelDeletion_remoteFailureStillClearsLocalIntent() async {
        let service = makeService()
        await service.requestDeletion(authMethod: "apple")
        XCTAssertTrue(service.isDeletionPending)

        await service.cancelDeletion()

        XCTAssertNil(service.deletionScheduledAt,
                     "Local cancel must land even when the remote clear fails offline")
        XCTAssertEqual(UserDefaults.standard.double(forKey: deletionKey), 0)
    }

    func testRapidRequestCancelAlternation_leavesConsistentState() async {
        // Hammer the state machine: 20 alternating request/cancel cycles. After
        // each terminal op the published property and the UserDefaults mirror
        // must agree — no torn state, no orphaned persistence.
        let service = makeService()
        for i in 0..<20 {
            if i.isMultiple(of: 2) {
                await service.requestDeletion(authMethod: "email")
            } else {
                await service.cancelDeletion()
            }
        }
        // Last op (i=19, odd) was a cancel → cleared everywhere.
        XCTAssertNil(service.deletionScheduledAt)
        XCTAssertEqual(UserDefaults.standard.double(forKey: deletionKey), 0,
                       "UserDefaults must mirror the final published state exactly")

        // One more request → both set, still consistent.
        await service.requestDeletion(authMethod: "email")
        XCTAssertNotNil(service.deletionScheduledAt)
        XCTAssertGreaterThan(UserDefaults.standard.double(forKey: deletionKey), 0)
    }

    func testCheckGracePeriod_repeatedRelaunchIsIdempotent() async {
        // Simulate repeated cold starts (checkGracePeriod runs on every launch).
        // The resolved timestamp must be stable — repeated resolution must not
        // drift it.
        let sixDaysAgo = Date().addingTimeInterval(-6 * 86_400)
        UserDefaults.standard.set(sixDaysAgo.timeIntervalSince1970, forKey: deletionKey)

        let service = makeService()
        var resolved: [TimeInterval] = []
        for _ in 0..<8 {
            await service.checkGracePeriod()
            resolved.append(service.deletionScheduledAt?.timeIntervalSince1970 ?? -1)
        }
        XCTAssertEqual(Set(resolved).count, 1,
                       "checkGracePeriod must be idempotent across relaunches")
        XCTAssertEqual(resolved.first ?? 0, sixDaysAgo.timeIntervalSince1970, accuracy: 1.0)
    }

    func testDaysRemaining_boundarySweep_clampedAndMonotonic() async {
        // Adversarial sweep across the 30-day grace boundary. daysRemaining must
        // stay within [0, 30] and be monotonic non-increasing as the request
        // ages. Note the production semantics: daysRemaining is *whole* days
        // (Calendar truncates), and isGracePeriodExpired == (daysRemaining <= 0),
        // so expiry lands once fewer than one full day remains — i.e. at ~30d
        // elapsed. The 29↔30 truncation edge is deliberately excluded from the
        // expiry assertion (offsets stay ≤28 or ≥30) so the test is robust to
        // sub-day clock jitter.
        let offsetsDays: [Double] = [0, 1, 15, 28, 30, 31, 100]
        var lastRemaining = Int.max
        for days in offsetsDays {
            UserDefaults.standard.set(Date().addingTimeInterval(-days * 86_400).timeIntervalSince1970,
                                      forKey: deletionKey)
            let service = makeService()
            await service.checkGracePeriod()
            let remaining = service.daysRemaining ?? -1

            XCTAssertGreaterThanOrEqual(remaining, 0, "daysRemaining must clamp at 0 (age=\(days)d)")
            XCTAssertLessThanOrEqual(remaining, 30, "daysRemaining must never exceed 30 (age=\(days)d)")
            XCTAssertLessThanOrEqual(remaining, lastRemaining,
                                     "daysRemaining must be monotonic non-increasing as the request ages")
            lastRemaining = remaining

            if days >= 30 {
                XCTAssertTrue(service.isGracePeriodExpired, "grace period must be expired at age=\(days)d")
                XCTAssertEqual(remaining, 0, "expired → 0 days remaining (age=\(days)d)")
            } else {
                XCTAssertFalse(service.isGracePeriodExpired, "grace period must be active at age=\(days)d")
            }
        }
    }

    // MARK: - Helpers

    private func makeService() -> AccountDeletionService {
        AccountDeletionService(
            dataStore: EncryptedDataStore(),
            cloudSync: CloudKitSyncService(),
            supabaseSync: SupabaseSyncService(),
            signIn: SignInService(),
            analytics: AnalyticsService(provider: MockAnalyticsAdapter(), consent: ConsentManager())
        )
    }

    // MARK: - executeDeletion() partial-failure cascade (FIT-157 / T9)
    //
    // Uses the AccountDeletionSupabaseSyncing / AccountDeletionCloudSyncing seams
    // to fault-inject remote-store failures and assert the cascade semantics: a
    // failing remote step must NOT abort the cascade, and each failed store must
    // surface in deletionError's "Still pending:" segment. The local
    // device/keychain/UserDefaults steps run for real (fast + idempotent in the
    // simulator); assertions key ONLY on the two injectable remote stores so they
    // stay deterministic regardless of the local steps' outcome.

    func testExecuteDeletion_allRemoteStoresSucceed_noRemotePending() async {
        let supabase = MockDeletionSupabaseSync()
        let cloud = MockDeletionCloudSync()
        let service = makeService(supabase: supabase, cloud: cloud)

        await service.executeDeletion()

        XCTAssertTrue(supabase.unsubscribeCalled, "must unsubscribe realtime before deleting")
        XCTAssertTrue(supabase.deleteCalled)
        XCTAssertTrue(cloud.deleteCalled)
        XCTAssertFalse(service.isDeleting, "isDeleting must reset when the cascade finishes")
        XCTAssertFalse(pendingStores(service.deletionError).contains("supabase"),
                       "supabase succeeded → must not be reported pending")
        XCTAssertFalse(pendingStores(service.deletionError).contains("cloudkit"),
                       "cloudkit succeeded → must not be reported pending")
    }

    func testExecuteDeletion_supabaseFailure_cascadeContinues_andRecordsPending() async {
        let supabase = MockDeletionSupabaseSync(); supabase.deleteShouldThrow = true
        let cloud = MockDeletionCloudSync()
        let service = makeService(supabase: supabase, cloud: cloud)

        await service.executeDeletion()

        // Cascade integrity: a first-step (supabase) failure must NOT abort the
        // remaining steps — cloudkit deletion still runs.
        XCTAssertTrue(cloud.deleteCalled, "cloudkit deletion must still run after supabase throws")
        XCTAssertTrue(pendingStores(service.deletionError).contains("supabase"),
                      "failed supabase store must be reported as still pending")
        XCTAssertFalse(pendingStores(service.deletionError).contains("cloudkit"),
                       "cloudkit succeeded → not pending")
        XCTAssertFalse(service.isDeleting)
    }

    func testExecuteDeletion_cloudkitFailure_cascadeContinues_andRecordsPending() async {
        let supabase = MockDeletionSupabaseSync()
        let cloud = MockDeletionCloudSync(); cloud.deleteShouldThrow = true
        let service = makeService(supabase: supabase, cloud: cloud)

        await service.executeDeletion()

        XCTAssertTrue(supabase.deleteCalled, "supabase deletion must have run")
        XCTAssertTrue(pendingStores(service.deletionError).contains("cloudkit"),
                      "failed cloudkit store must be reported as still pending")
        XCTAssertFalse(pendingStores(service.deletionError).contains("supabase"),
                       "supabase succeeded → not pending")
        XCTAssertFalse(service.isDeleting)
    }

    func testExecuteDeletion_bothRemoteFailures_bothPending_cascadeStillCompletes() async {
        let supabase = MockDeletionSupabaseSync(); supabase.deleteShouldThrow = true
        let cloud = MockDeletionCloudSync(); cloud.deleteShouldThrow = true
        let service = makeService(supabase: supabase, cloud: cloud)

        await service.executeDeletion()

        let pending = pendingStores(service.deletionError)
        XCTAssertTrue(pending.contains("supabase"), "supabase must be pending after it throws")
        XCTAssertTrue(pending.contains("cloudkit"), "cloudkit must be pending after it throws")
        XCTAssertTrue(cloud.deleteCalled, "both delete attempts must be made even when both fail")
        XCTAssertFalse(service.isDeleting, "isDeleting resets even when every remote store fails")
    }

    // MARK: - Cascade helpers + fault-injectable mocks (FIT-157 / T9)

    /// Everything after "Still pending:" in the deletionError, or "" when the
    /// error is nil / has no pending segment. Lets cascade assertions target ONLY
    /// the injectable remote stores, independent of the local steps' outcome.
    private func pendingStores(_ error: String?) -> String {
        guard let error, let r = error.range(of: "Still pending:") else { return "" }
        return String(error[r.upperBound...])
    }

    private func makeService(
        supabase: MockDeletionSupabaseSync,
        cloud: MockDeletionCloudSync
    ) -> AccountDeletionService {
        AccountDeletionService(
            dataStore: EncryptedDataStore(),
            cloudSync: cloud,
            supabaseSync: supabase,
            signIn: SignInService(),
            analytics: AnalyticsService(provider: MockAnalyticsAdapter(), consent: ConsentManager())
        )
    }
}

// MARK: - Fault-injectable sync mocks (FIT-157 / T9)

@MainActor
private final class MockDeletionSupabaseSync: AccountDeletionSupabaseSyncing {
    var deleteShouldThrow = false
    private(set) var unsubscribeCalled = false
    private(set) var deleteCalled = false
    private(set) var setRemoteCalls: [Date?] = []

    struct InjectedFailure: Error {}

    func setRemoteDeletionScheduledAt(_ date: Date?) async throws { setRemoteCalls.append(date) }
    func fetchRemoteDeletionScheduledAt() async -> Date? { nil }
    func unsubscribeRealtime() async { unsubscribeCalled = true }
    func deleteAllUserData() async throws {
        deleteCalled = true
        if deleteShouldThrow { throw InjectedFailure() }
    }
}

@MainActor
private final class MockDeletionCloudSync: AccountDeletionCloudSyncing {
    var deleteShouldThrow = false
    private(set) var deleteCalled = false

    struct InjectedFailure: Error {}

    func deleteAllUserRecords() async throws {
        deleteCalled = true
        if deleteShouldThrow { throw InjectedFailure() }
    }
}
