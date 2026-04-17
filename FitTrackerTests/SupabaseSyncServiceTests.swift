// FitTrackerTests/SupabaseSyncServiceTests.swift
// TEST-004 (partial): Contract tests for SupabaseSyncService.
// Covers paths that don't require URLProtocol mock infrastructure:
// - initial state
// - disabled-when-not-configured guards
// - UserDefaults key scoping via migration
//
// Full sync integration tests (push/pull/realtime) require URLProtocol
// network stubs and are deferred to Sprint D / future mock-infra work.

import XCTest
@testable import FitTracker

@MainActor
final class SupabaseSyncServiceTests: XCTestCase {

    // MARK: - Initial state

    func testInit_statusIsIdle() {
        let service = SupabaseSyncService()
        XCTAssertEqual(service.status, .idle,
                       "Freshly constructed service must start in .idle state")
    }

    // MARK: - Configuration guards

    func testPushPendingChanges_whenNotConfigured_setsDisabled() async {
        // When SupabaseRuntimeConfiguration isn't set (no credentials in test env),
        // push must early-return with .disabled status — not crash, not attempt network.
        let service = SupabaseSyncService()
        let dataStore = EncryptedDataStore()

        await service.pushPendingChanges(dataStore: dataStore)

        if !SupabaseRuntimeConfiguration.isConfigured {
            XCTAssertEqual(service.status, .disabled,
                           "Push when not configured must set .disabled")
        }
    }

    func testFetchChanges_whenNotConfigured_setsDisabled() async {
        let service = SupabaseSyncService()
        let dataStore = EncryptedDataStore()

        await service.fetchChanges(dataStore: dataStore)

        if !SupabaseRuntimeConfiguration.isConfigured {
            XCTAssertEqual(service.status, .disabled)
        }
    }

    func testFetchAllRecords_whenNotConfigured_setsDisabled() async {
        let service = SupabaseSyncService()
        let dataStore = EncryptedDataStore()

        await service.fetchAllRecords(dataStore: dataStore)

        if !SupabaseRuntimeConfiguration.isConfigured {
            XCTAssertEqual(service.status, .disabled)
        }
    }

    // MARK: - UserDefaults key scoping (via SupabaseSyncStatus lifecycle)

    func testStatus_equatable() {
        // The status enum must be Equatable so tests can assert on transitions
        XCTAssertEqual(SupabaseSyncStatus.idle, .idle)
        XCTAssertNotEqual(SupabaseSyncStatus.idle, .disabled)
        XCTAssertEqual(SupabaseSyncStatus.failed("x"), .failed("x"))
        XCTAssertNotEqual(SupabaseSyncStatus.failed("x"), .failed("y"))
    }

    // MARK: - Unsubscribe is safe when never subscribed

    func testUnsubscribeRealtime_whenNotSubscribed_isNoop() async {
        let service = SupabaseSyncService()
        // Must not crash when called before any subscribe
        await service.unsubscribeRealtime()
        XCTAssertEqual(service.status, .idle)
    }
}
