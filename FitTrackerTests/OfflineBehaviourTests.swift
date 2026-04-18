// FitTrackerTests/OfflineBehaviourTests.swift
// TEST-023 (PARTIAL): Offline / no-network behaviour for sync + auth services.
//
// SCOPE OF THIS FILE: skeleton + contract documentation.
// FULL IMPLEMENTATION BLOCKED ON: URLProtocol-based network mock infrastructure
// (separate sprint per docs/superpowers/specs/2026-04-18-framework-bugs-from-stress-test.md).
//
// What's testable WITHOUT mocks (covered here):
//   - Configuration guards (services no-op when isConfigured == false)
//   - Status enum transitions in the disabled path
//   - That public methods don't crash when offline isn't simulated
//
// What's NOT testable without URLProtocol mocks (documented as gaps):
//   - Real network failure recovery (timeout, DNS, SSL)
//   - Partial response handling
//   - Retry/backoff behaviour
//   - Realtime channel disconnect/reconnect
//   - Auth token refresh under network errors
//   - Cardio image upload retry on intermittent network
//
// SupabaseSyncServiceTests + CloudKitSyncServiceTests already cover the
// "service not configured → status .disabled" path. This file adds explicit
// contract tests for the OFFLINE scenarios, distinct from the NOT-CONFIGURED
// scenarios.

import XCTest
@testable import FitTracker

@MainActor
final class OfflineBehaviourTests: XCTestCase {

    // MARK: - Documented contract: services degrade safely when offline

    func testSupabaseSync_offlineBehaviour_documented() {
        // CONTRACT (production):
        //   - Push attempts when offline should: timeout per platform default,
        //     log error via syncLogger, set status = .failed("..."), return
        //   - Pull attempts when offline should: same
        //   - Realtime channel should disconnect, attempt reconnect on next
        //     network availability event
        //
        // VERIFICATION TODAY (without mocks):
        //   - We can verify the "not configured" path defensively closes
        //     (already covered in SupabaseSyncServiceTests)
        //   - We CANNOT verify the actual offline path without simulating
        //     network unreachability through URLProtocol or NWPathMonitor
        //     overrides
        //
        // STATUS: documented gap, no executable assertion
        XCTAssertTrue(true, "Offline contract documented above; implementation blocked on URLProtocol mock infra")
    }

    func testCloudKitSync_offlineBehaviour_documented() {
        // CONTRACT (production):
        //   - When iCloud is unavailable (logged out, no network, iCloud Drive disabled),
        //     CloudKitSyncService should set status = .disabled and surface a useful
        //     errorMessage
        //   - On network recovery, the next push/fetch attempt should succeed without
        //     manual intervention
        //
        // VERIFICATION TODAY:
        //   - Simulator path covered in CloudKitSyncServiceTests
        //   - Real iCloud-unavailable path requires either a physical device or a
        //     CKContainer mock, which the framework doesn't currently provide
        //
        // STATUS: documented gap
        XCTAssertTrue(true, "CloudKit offline contract documented above")
    }

    func testEncryption_offline_isUnaffected() {
        // CONTRACT (production):
        //   - EncryptionService is fully local — Keychain, CryptoKit, no network
        //   - Offline must not affect encrypt/decrypt behaviour at all
        //
        // VERIFICATION TODAY:
        //   - EncryptionServiceTests covers the round-trip; offline doesn't change behaviour
        //   - No additional offline-specific test needed
        XCTAssertTrue(true, "EncryptionService is network-independent by design")
    }

    func testAuthManager_offline_simulatorPathUnaffected() {
        // CONTRACT (production):
        //   - AuthManager wraps biometric LocalAuthentication APIs (no network)
        //   - Offline must not affect biometric unlock
        //
        // VERIFICATION TODAY:
        //   - Simulator bypass path tested in AuthManagerTests
        //   - Real-device biometric path requires physical device (out of scope)
        let auth = AuthManager()
        XCTAssertFalse(auth.isAuthenticated, "Initial state independent of network")
    }

    // MARK: - What URLProtocol mock infra would unlock

    func testGapDocumentation_what_url_protocol_mocks_would_enable() {
        // If we built a URLProtocol-based stub class (call it `StubbedURLProtocol`),
        // we could:
        //   1. Inject it into URLSessionConfiguration.protocolClasses for any session
        //      that the Supabase SDK or our adapter creates
        //   2. Have it match request URLs against a registered map of (URL → response)
        //   3. Simulate timeouts, 5xx errors, 4xx auth errors, slow responses,
        //      partial bodies, malformed JSON
        //   4. Test the actual error-handling code paths in SupabaseSyncService
        //      (the catch blocks that today are reached only by accident in dev)
        //
        // The blocker: Supabase SDK's URLSession is constructed internally.
        // We'd need to either:
        //   (a) Inject a configuration via Supabase client init parameters (if the
        //       SDK exposes that) — needs SDK API check
        //   (b) Wrap the Supabase client behind a protocol (SupabaseClientProtocol)
        //       and mock at our boundary, not theirs — most work, most isolation
        //   (c) Use URLProtocol.registerClass on the global default — affects all
        //       URLSession instances, may have unintended side effects in tests
        //
        // Recommendation: option (b), tracked separately as "Sync mock layer"
        // sprint. Estimated 1-2 sessions of work.
        XCTAssertTrue(true, "Spec for future URLProtocol mock infra")
    }
}
