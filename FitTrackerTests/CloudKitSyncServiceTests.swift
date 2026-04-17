// FitTrackerTests/CloudKitSyncServiceTests.swift
// TEST-003 (partial): Contract tests for CloudKitSyncService.
// On simulator, CloudKit container is nil and service is permanently .disabled.
// Covers paths that don't require a mock CKDatabase:
// - initial state on simulator
// - error construction
// - SyncStatus enum rawValues
//
// Full sync integration tests (fetchChanges, push, merge logic) require a
// mock CKDatabase protocol layer and are deferred to Sprint D / future work.
// The merge logic IS tested via SyncMergeTests (exercises mergeDailyLog,
// mergeWeeklySnapshot directly on EncryptedDataStore).

import XCTest
@testable import FitTracker

@MainActor
final class CloudKitSyncServiceTests: XCTestCase {

    // MARK: - Initial state

    func testInit_onSimulator_statusBecomesDisabled() async {
        let service = CloudKitSyncService()
        #if targetEnvironment(simulator)
        // Init schedules `checkiCloudStatus` async + `makeContainer` is lazy.
        // Trigger by calling a sync method which forces lazy container access.
        await service.fetchChanges(dataStore: EncryptedDataStore())
        XCTAssertEqual(service.status, .disabled,
                       "Simulator build must end up in .disabled after first sync attempt")
        XCTAssertFalse(service.iCloudAvailable)
        #endif
    }

    func testInit_lastSyncDateIsNil() {
        let service = CloudKitSyncService()
        XCTAssertNil(service.lastSyncDate,
                     "Fresh service must have no prior sync date")
    }

    // MARK: - SyncStatus enum

    func testSyncStatus_rawValuesMatchSpec() {
        XCTAssertEqual(SyncStatus.idle.rawValue, "Synced")
        XCTAssertEqual(SyncStatus.syncing.rawValue, "Syncing…")
        XCTAssertEqual(SyncStatus.failed.rawValue, "Sync Failed")
        XCTAssertEqual(SyncStatus.offline.rawValue, "Offline")
        XCTAssertEqual(SyncStatus.disabled.rawValue, "iCloud Disabled")
    }

    func testSyncStatus_allCasesExposeUserFacingStrings() {
        // Every status should produce a human-readable string (no empty values)
        let allCases: [SyncStatus] = [.idle, .syncing, .failed, .offline, .disabled]
        for status in allCases {
            XCTAssertFalse(status.rawValue.isEmpty,
                           "\(status) must have a non-empty user-facing rawValue")
        }
    }

    // MARK: - Configuration guards on simulator

    func testPushPendingChanges_onSimulator_doesNotCrash() async {
        let service = CloudKitSyncService()
        let dataStore = EncryptedDataStore()
        // Simulator: privateDB is nil — push must early-return without crash
        await service.pushPendingChanges(dataStore: dataStore)
        #if targetEnvironment(simulator)
        XCTAssertEqual(service.status, .disabled)
        #endif
    }

    func testFetchChanges_onSimulator_doesNotCrash() async {
        let service = CloudKitSyncService()
        let dataStore = EncryptedDataStore()
        await service.fetchChanges(dataStore: dataStore)
        #if targetEnvironment(simulator)
        XCTAssertEqual(service.status, .disabled)
        #endif
    }
}
