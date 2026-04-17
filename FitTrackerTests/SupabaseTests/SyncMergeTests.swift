// FitTrackerTests/SupabaseTests/SyncMergeTests.swift
import XCTest
import CryptoKit
@testable import FitTracker

// @MainActor is required: EncryptedDataStore is @MainActor-isolated.
// Annotating the class ensures every test body runs on MainActor without
// boilerplate MainActor.run wrappers around each call site.
@MainActor
final class SyncMergeTests: XCTestCase {

    // MARK: - Daily Log Merge (last-modified wins)

    func testDailyLogMerge_remoteNewer_acceptsRemote() {
        let store = EncryptedDataStore()
        let logDate = Date()
        let local = makeDailyLog(date: logDate, notes: "local",  modifiedAt: Date().addingTimeInterval(-60))
        let remote = makeDailyLog(date: logDate, notes: "remote", modifiedAt: Date())
        store.dailyLogs = [local]
        store.mergeDailyLog(remote)
        XCTAssertEqual(store.dailyLogs.first?.notes, "remote")
    }

    func testDailyLogMerge_localNewer_keepsLocal() {
        let store = EncryptedDataStore()
        let logDate = Date()
        let local  = makeDailyLog(date: logDate, notes: "local",  modifiedAt: Date())
        let remote = makeDailyLog(date: logDate, notes: "remote", modifiedAt: Date().addingTimeInterval(-60))
        store.dailyLogs = [local]
        store.mergeDailyLog(remote)
        XCTAssertEqual(store.dailyLogs.first?.notes, "local")
    }

    func testDailyLogMerge_sameTimestamp_keepsLocal() {
        // Strict > comparison means equal timestamps don't replace local.
        // This documents the tie-break contract: local wins on ties.
        let store = EncryptedDataStore()
        let logDate = Date()
        let sharedTimestamp = Date()
        let local  = makeDailyLog(date: logDate, notes: "local",  modifiedAt: sharedTimestamp)
        let remote = makeDailyLog(date: logDate, notes: "remote", modifiedAt: sharedTimestamp)
        store.dailyLogs = [local]
        store.mergeDailyLog(remote)
        XCTAssertEqual(store.dailyLogs.first?.notes, "local",
                       "Same-timestamp tie-break: local wins (remote must be strictly newer)")
    }

    func testDailyLogMerge_noLocal_insertsRemote() {
        let store = EncryptedDataStore()
        let remote = makeDailyLog(date: Date(), notes: "remote", modifiedAt: Date())
        store.mergeDailyLog(remote)
        XCTAssertEqual(store.dailyLogs.count, 1)
        XCTAssertEqual(store.dailyLogs.first?.notes, "remote")
    }

    func testDailyLogMerge_differentLogicDates_coexistAndStaySortedNewestFirst() {
        let store = EncryptedDataStore()
        let calendar = Calendar.current
        let newerDate = calendar.startOfDay(for: Date())
        let olderDate = calendar.date(byAdding: .day, value: -1, to: newerDate)!

        let older = makeDailyLog(
            date: olderDate,
            notes: "older",
            modifiedAt: olderDate.addingTimeInterval(300)
        )
        let newer = makeDailyLog(
            date: newerDate,
            notes: "newer",
            modifiedAt: newerDate.addingTimeInterval(300)
        )

        store.mergeDailyLog(older)
        store.mergeDailyLog(newer)

        XCTAssertEqual(store.dailyLogs.count, 2)
        XCTAssertEqual(store.dailyLogs.map(\.notes), ["newer", "older"])
    }

    // MARK: - Weekly Snapshot Merge

    func testWeeklySnapshotMerge_localNeedsSync_keepsLocal() {
        let store = EncryptedDataStore()
        let weekStart = Calendar.current.startOfDay(for: Date())
        var local = makeWeeklySnapshot(weekStart: weekStart)
        local.needsSync = true
        local.avgWeightKg = 70.0
        var remote = makeWeeklySnapshot(weekStart: weekStart)
        remote.needsSync = false
        remote.avgWeightKg = 68.0
        store.weeklySnapshots = [local]
        store.mergeWeeklySnapshot(remote)
        XCTAssertEqual(store.weeklySnapshots.first?.avgWeightKg, 70.0, "local unsaved change must win")
    }

    func testWeeklySnapshotMerge_localSynced_acceptsRemote() {
        let store = EncryptedDataStore()
        let weekStart = Calendar.current.startOfDay(for: Date())
        var local = makeWeeklySnapshot(weekStart: weekStart)
        local.needsSync = false
        local.avgWeightKg = 70.0
        var remote = makeWeeklySnapshot(weekStart: weekStart)
        remote.avgWeightKg = 68.0
        store.weeklySnapshots = [local]
        store.mergeWeeklySnapshot(remote)
        XCTAssertEqual(store.weeklySnapshots.first?.avgWeightKg, 68.0, "remote wins when local is synced")
    }

    func testWeeklySnapshotMerge_differentWeeks_coexistAndStaySortedNewestFirst() {
        let store = EncryptedDataStore()
        let calendar = Calendar.current
        let newerWeekStart = calendar.startOfDay(for: Date())
        let olderWeekStart = calendar.date(byAdding: .day, value: -7, to: newerWeekStart)!

        var older = makeWeeklySnapshot(weekStart: olderWeekStart)
        older.avgWeightKg = 70.0
        var newer = makeWeeklySnapshot(weekStart: newerWeekStart)
        newer.avgWeightKg = 68.0

        store.mergeWeeklySnapshot(older)
        store.mergeWeeklySnapshot(newer)

        XCTAssertEqual(store.weeklySnapshots.count, 2)
        XCTAssertEqual(store.weeklySnapshots.map(\.avgWeightKg), [68.0, 70.0])
    }

    // MARK: - markSynced

    func testMarkSynced_clearsFlagOnMatchingLog() {
        let store = EncryptedDataStore()
        var log = makeDailyLog(date: Date(), notes: "", modifiedAt: Date())
        log.needsSync = true
        store.dailyLogs = [log]
        store.markSynced(logID: log.id)
        XCTAssertFalse(store.dailyLogs.first!.needsSync)
    }

    // MARK: - Singleton Merge (UserProfile)

    func testMergeProfile_identicalChecksums_noChange() {
        let store = EncryptedDataStore()
        let profile = store.userProfile
        guard let blob = try? JSONEncoder().encode(profile) else {
            return XCTFail("encode failed")
        }
        let checksum = SHA256.hash(data: blob).hexString
        let digestKey = "supabase.user_profile.test.\(UUID())"  // unique key per test
        UserDefaults.standard.set(checksum, forKey: digestKey)
        store.mergeProfile(profile, remoteChecksum: checksum, digestKey: digestKey)
        // No change expected — identical checksums
        XCTAssertEqual(store.userProfile.name, profile.name)
        UserDefaults.standard.removeObject(forKey: digestKey)
    }

    // MARK: - Helpers

    private func makeDailyLog(date: Date, notes: String, modifiedAt: Date) -> DailyLog {
        var log = DailyLog(date: date, phase: .recovery, dayType: .restDay, recoveryDay: 0)
        log.notes = notes
        log.lastModified = modifiedAt
        return log
    }

    private func makeWeeklySnapshot(weekStart: Date) -> WeeklySnapshot {
        WeeklySnapshot(weekStart: weekStart, weekNumber: 1)
    }
}
