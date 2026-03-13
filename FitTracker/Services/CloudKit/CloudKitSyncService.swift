// Services/CloudKit/CloudKitSyncService.swift
// CloudKit Private Database sync — ALL data encrypted before leaving device
// Server stores only opaque encrypted blobs. CloudKit never sees plaintext.
// Apple-platform only: iOS 17+, iPadOS 17+, macOS 14+

import Foundation
import CloudKit
import SwiftUI

// ─────────────────────────────────────────────────────────
// MARK: – CloudKit record type constants
// ─────────────────────────────────────────────────────────

private enum CKRecordType {
    static let dailyLog       = "EncryptedDailyLog"
    static let weeklySnapshot = "EncryptedWeeklySnapshot"
    static let userProfile    = "EncryptedUserProfile"
    static let cardioAsset    = "EncryptedCardioAsset"
}

private enum CKField {
    static let blob       = "encryptedBlob"     // Data — our AES+ChaCha cipher
    static let logicDate  = "logicDate"          // Date — for querying/sorting (not sensitive)
    static let recordVersion = "recordVersion"   // Int — schema migration
    static let assetData  = "assetData"          // CKAsset — encrypted image blob
    static let assetRef   = "assetRef"           // String — foreign key to CardioLog
}

// ─────────────────────────────────────────────────────────
// MARK: – Sync Status
// ─────────────────────────────────────────────────────────

enum SyncStatus: String {
    case idle      = "Synced"
    case syncing   = "Syncing…"
    case failed    = "Sync Failed"
    case offline   = "Offline"
    case disabled  = "iCloud Disabled"
}

// ─────────────────────────────────────────────────────────
// MARK: – CloudKit Sync Service
// ─────────────────────────────────────────────────────────

@MainActor
final class CloudKitSyncService: ObservableObject {

    @Published var status:        SyncStatus = .idle
    @Published var lastSyncDate:  Date?
    @Published var iCloudAvailable: Bool = false
    @Published var errorMessage:  String?

    private let container = CKContainer(identifier: "iCloud.com.fittracker.regev")
    private var privateDB: CKDatabase { container.privateCloudDatabase }

    // ── Init ─────────────────────────────────────────────
    init() {
        Task { await checkiCloudStatus() }
    }

    // ── iCloud account check ─────────────────────────────
    func checkiCloudStatus() async {
        do {
            let accountStatus = try await container.accountStatus()
            iCloudAvailable = (accountStatus == .available)
            status = iCloudAvailable ? .idle : .disabled
        } catch {
            iCloudAvailable = false
            status = .offline
        }
    }

    // ── Push pending changes UP to CloudKit ─────────────
    func pushPendingChanges(dataStore: EncryptedDataStore) async {
        if !iCloudAvailable { await checkiCloudStatus() }
        guard iCloudAvailable else { status = .offline; return }
        status = .syncing

        do {
            // Upload daily logs that need sync
            let pendingLogs = dataStore.dailyLogs.filter { $0.needsSync }
            for log in pendingLogs {
                let recordName = try await uploadDailyLog(log)
                // Mark as synced in the store
                if let idx = dataStore.dailyLogs.firstIndex(where: { $0.id == log.id }) {
                    dataStore.dailyLogs[idx].needsSync = false
                    dataStore.dailyLogs[idx].cloudRecordID = recordName
                }
            }

            // Upload weekly snapshots
            let pendingSnaps = dataStore.weeklySnapshots.filter { $0.needsSync }
            for snap in pendingSnaps {
                let recordName = try await uploadWeeklySnapshot(snap)
                if let idx = dataStore.weeklySnapshots.firstIndex(where: { $0.id == snap.id }) {
                    dataStore.weeklySnapshots[idx].needsSync = false
                    dataStore.weeklySnapshots[idx].cloudRecordID = recordName
                }
            }

            // Upload user profile
            try await uploadUserProfile(dataStore.userProfile)
            await dataStore.persistToDisk()

            lastSyncDate = Date()
            status = .idle
        } catch {
            status = .failed
            errorMessage = error.localizedDescription
        }
    }

    // ── Fetch changes DOWN from CloudKit ────────────────
    func fetchChanges(dataStore: EncryptedDataStore) async {
        if !iCloudAvailable { await checkiCloudStatus() }
        guard iCloudAvailable else { status = .offline; return }
        status = .syncing

        do {
            // Fetch daily logs
            let remoteLogs = try await fetchEncryptedRecords(
                ofType: CKRecordType.dailyLog,
                as: DailyLog.self
            )
            // Merge: remote wins on conflict (last-write-wins by logicDate)
            for remote in remoteLogs {
                if let local = dataStore.log(for: remote.date) {
                    if remote.lastModified > local.lastModified {
                        dataStore.dailyLogs.removeAll { Calendar.current.isDate($0.date, inSameDayAs: remote.date) }
                        var r = remote; r.needsSync = false
                        dataStore.dailyLogs.append(r)
                    }
                } else {
                    var r = remote; r.needsSync = false
                    dataStore.dailyLogs.append(r)
                }
            }
            dataStore.dailyLogs.sort { $0.date > $1.date }

            // Fetch weekly snapshots
            let remoteSnaps = try await fetchEncryptedRecords(
                ofType: CKRecordType.weeklySnapshot,
                as: WeeklySnapshot.self
            )
            for remote in remoteSnaps {
                if let idx = dataStore.weeklySnapshots.firstIndex(where: { Calendar.current.isDate($0.weekStart, inSameDayAs: remote.weekStart) }) {
                    // Keep local unsynced edits; otherwise refresh from cloud.
                    if !dataStore.weeklySnapshots[idx].needsSync {
                        var r = remote; r.needsSync = false
                        dataStore.weeklySnapshots[idx] = r
                    }
                } else {
                    var r = remote; r.needsSync = false
                    dataStore.weeklySnapshots.append(r)
                }
            }
            dataStore.weeklySnapshots.sort { $0.weekStart > $1.weekStart }

            if let remoteProfile = try await fetchUserProfile() {
                dataStore.userProfile = remoteProfile
            }

            await dataStore.persistToDisk()
            lastSyncDate = Date()
            status = .idle
        } catch {
            status = .failed
            errorMessage = error.localizedDescription
        }
    }

    // ── Upload cardio summary image ──────────────────────
    func uploadCardioImage(_ imageData: Data, cardioLogID: String) async throws -> String {
        // Encrypt image before upload
        let encryptedImage = try await EncryptionService.shared.encryptRaw(imageData)
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(cardioLogID).ftimg")
        defer { try? FileManager.default.removeItem(at: tmpURL) }
        try encryptedImage.write(to: tmpURL)

        let record = CKRecord(recordType: CKRecordType.cardioAsset)
        record[CKField.assetData] = CKAsset(fileURL: tmpURL)
        record[CKField.assetRef]  = cardioLogID as CKRecordValue
        record[CKField.recordVersion] = 1 as CKRecordValue

        let saved = try await privateDB.save(record)
        return saved.recordID.recordName
    }

    // ── Download cardio summary image ───────────────────
    func downloadCardioImage(cloudID: String) async throws -> Data {
        let recordID = CKRecord.ID(recordName: cloudID)
        let record = try await privateDB.record(for: recordID)

        guard let asset = record[CKField.assetData] as? CKAsset,
              let fileURL = asset.fileURL else {
            throw NSError(domain: "FTCloud", code: 404, userInfo: [NSLocalizedDescriptionKey: "Asset not found"])
        }

        let encryptedData = try Data(contentsOf: fileURL)
        return try await EncryptionService.shared.decryptRaw(encryptedData)
    }

    // ── Private helpers ──────────────────────────────────

    private func uploadDailyLog(_ log: DailyLog) async throws -> String {
        let encrypted = try await EncryptionService.shared.encrypt(log)
        let recordName = log.cloudRecordID ?? "log-\(logicDayKey(for: log.date))"
        let recordID = CKRecord.ID(recordName: recordName)
        let record = CKRecord(recordType: CKRecordType.dailyLog, recordID: recordID)
        record[CKField.blob]       = encrypted as CKRecordValue
        record[CKField.logicDate]  = log.date as CKRecordValue
        record[CKField.recordVersion] = 2 as CKRecordValue
        _ = try await privateDB.save(record)
        return recordName
    }

    private func uploadWeeklySnapshot(_ snap: WeeklySnapshot) async throws -> String {
        let encrypted = try await EncryptionService.shared.encrypt(snap)
        let recordName = snap.cloudRecordID ?? "snap-\(logicDayKey(for: snap.weekStart))"
        let recordID = CKRecord.ID(recordName: recordName)
        let record = CKRecord(recordType: CKRecordType.weeklySnapshot, recordID: recordID)
        record[CKField.blob]       = encrypted as CKRecordValue
        record[CKField.logicDate]  = snap.weekStart as CKRecordValue
        record[CKField.recordVersion] = 1 as CKRecordValue
        _ = try await privateDB.save(record)
        return recordName
    }

    private func uploadUserProfile(_ profile: UserProfile) async throws {
        let encrypted = try await EncryptionService.shared.encrypt(profile)
        let recordID = CKRecord.ID(recordName: "user-profile-singleton")
        let record = CKRecord(recordType: CKRecordType.userProfile, recordID: recordID)
        record[CKField.blob] = encrypted as CKRecordValue
        record[CKField.recordVersion] = 1 as CKRecordValue
        _ = try await privateDB.save(record)
    }

    private func fetchUserProfile() async throws -> UserProfile? {
        let recordID = CKRecord.ID(recordName: "user-profile-singleton")
        do {
            let record = try await privateDB.record(for: recordID)
            guard let blob = record[CKField.blob] as? Data else { return nil }
            return try await EncryptionService.shared.decrypt(blob, as: UserProfile.self)
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
    }

    private func fetchEncryptedRecords<T: Decodable>(
        ofType type: String, as decodable: T.Type
    ) async throws -> [T] where T: Sendable {
        let query = CKQuery(recordType: type, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: CKField.logicDate, ascending: false)]
        let result = try await privateDB.records(matching: query, resultsLimit: 200)
        var items: [T] = []
        for (_, recordResult) in result.matchResults {
            if let record = try? recordResult.get(),
               let blob = record[CKField.blob] as? Data {
                if let item = try? await EncryptionService.shared.decrypt(blob, as: T.self) {
                    items.append(item)
                }
            }
        }
        return items
    }

    private func logicDayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
