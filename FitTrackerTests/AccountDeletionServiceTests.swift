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

        service.cancelDeletion()

        XCTAssertNil(service.deletionScheduledAt)
        XCTAssertFalse(service.isDeletionPending)
        XCTAssertEqual(UserDefaults.standard.double(forKey: deletionKey), 0,
                       "Deletion timestamp must be removed from UserDefaults")
    }

    func testCheckGracePeriod_restoresPendingDeletionFromDefaults() {
        // Simulate an app relaunch: write directly to UserDefaults, then check
        let twoDaysAgo = Date().addingTimeInterval(-2 * 86_400)
        UserDefaults.standard.set(twoDaysAgo.timeIntervalSince1970, forKey: deletionKey)

        let service = makeService()
        XCTAssertNil(service.deletionScheduledAt, "Fresh service shouldn't auto-load")
        service.checkGracePeriod()
        XCTAssertNotNil(service.deletionScheduledAt)
        XCTAssertEqual(service.deletionScheduledAt?.timeIntervalSince1970 ?? 0,
                       twoDaysAgo.timeIntervalSince1970, accuracy: 1.0)
    }

    func testCheckGracePeriod_noStoredValue_leavesStateNil() {
        let service = makeService()
        service.checkGracePeriod()
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

    func testIsGracePeriodExpired_35DaysAgo_true() {
        let thirtyFiveDaysAgo = Date().addingTimeInterval(-35 * 86_400)
        UserDefaults.standard.set(thirtyFiveDaysAgo.timeIntervalSince1970, forKey: deletionKey)

        let service = makeService()
        service.checkGracePeriod()
        XCTAssertTrue(service.isGracePeriodExpired,
                      "Deletion scheduled 35 days ago should be past the 30-day grace window")
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
}
