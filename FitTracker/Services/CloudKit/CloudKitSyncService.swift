// Services/CloudKit/CloudKitSyncService.swift
// CloudKit Private Database sync — ALL data encrypted before leaving device
// Server stores only opaque encrypted blobs. CloudKit never sees plaintext.
// Apple-platform only: iOS 17+, iPadOS 17+, macOS 14+

import Foundation
import CloudKit
import CryptoKit
import SwiftUI

// ─────────────────────────────────────────────────────────
// MARK: – CloudKit record type constants
// ─────────────────────────────────────────────────────────

private enum CKRecordType {
    static let dailyLog       = "EncryptedDailyLog"
    static let weeklySnapshot = "EncryptedWeeklySnapshot"
    static let userProfile    = "EncryptedUserProfile"
    static let userPreferences = "EncryptedUserPreferences"
    static let cardioAsset    = "EncryptedCardioAsset"
}

private enum CKField {
    static let blob       = "encryptedBlob"     // Data — our AES+ChaCha cipher
    static let logicDate  = "logicDate"          // Date — for querying/sorting (not sensitive)
    static let recordVersion = "recordVersion"   // Int — schema migration
    static let assetData  = "assetData"          // CKAsset — encrypted image blob
    static let assetRef   = "assetRef"           // String — foreign key to CardioLog
}

private enum SyncStateKey {
    static let userProfileDigest     = "ft.sync.userProfileDigest"
    static let userPreferencesDigest = "ft.sync.userPreferencesDigest"
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

    private let containerIdentifier = "iCloud.com.fittracker.regev"
    private lazy var container: CKContainer? = makeContainer()
    private let defaults = UserDefaults.standard
    private var privateDB: CKDatabase? { container?.privateCloudDatabase }

    private func cloudKitUnavailableError() -> NSError {
        NSError(
            domain: "FTCloudKit",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "CloudKit sync is unavailable in this environment."]
        )
    }

    // ── Init ─────────────────────────────────────────────
    init() {
        Task { await checkiCloudStatus() }
    }

    private func makeContainer() -> CKContainer? {
        #if targetEnvironment(simulator)
        errorMessage = "CloudKit sync is disabled in the simulator build."
        status = .disabled
        return nil
        #else
        return CKContainer(identifier: containerIdentifier)
        #endif
    }

    // ── iCloud account check ─────────────────────────────
    func checkiCloudStatus() async {
        guard let container else {
            iCloudAvailable = false
            status = .disabled
            if errorMessage == nil {
                errorMessage = "CloudKit is unavailable in this environment."
            }
            return
        }
        do {
            let accountStatus = try await container.accountStatus()
            iCloudAvailable = (accountStatus == .available)
            status = iCloudAvailable ? .idle : .disabled
        } catch {
            iCloudAvailable = false
            status = .offline
            errorMessage = error.localizedDescription
        }
    }

    // ── Push pending changes UP to CloudKit ─────────────
    func pushPendingChanges(dataStore: EncryptedDataStore) async {
        guard privateDB != nil else {
            iCloudAvailable = false
            status = .disabled
            errorMessage = errorMessage ?? "CloudKit sync is unavailable in this environment."
            return
        }
        if !iCloudAvailable { await checkiCloudStatus() }
        guard iCloudAvailable else { status = .offline; return }
        status = .syncing
        errorMessage = nil

        do {
            // Upload daily logs that need sync
            let pendingLogs = dataStore.dailyLogs.filter { $0.needsSync }
            for log in pendingLogs {
                let uploadedLog = try await uploadDailyLog(log)
                // Mark as synced in the store
                if let idx = dataStore.dailyLogs.firstIndex(where: { $0.id == log.id }) {
                    dataStore.dailyLogs[idx] = uploadedLog
                    dataStore.dailyLogs[idx].needsSync = false
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

            // Persist needsSync = false changes to disk before continuing
            await dataStore.persistToDisk()

            // Upload user profile
            try await uploadUserProfile(dataStore.userProfile)
            try await uploadUserPreferences(dataStore.userPreferences)
            storeSingletonDigest(dataStore.userProfile, forKey: SyncStateKey.userProfileDigest)
            storeSingletonDigest(dataStore.userPreferences, forKey: SyncStateKey.userPreferencesDigest)

            lastSyncDate = Date()
            status = .idle
        } catch {
            status = .failed
            errorMessage = error.localizedDescription
        }
    }

    // ── Fetch changes DOWN from CloudKit ────────────────
    func fetchChanges(dataStore: EncryptedDataStore) async {
        guard privateDB != nil else {
            iCloudAvailable = false
            status = .disabled
            errorMessage = errorMessage ?? "CloudKit sync is unavailable in this environment."
            return
        }
        if !iCloudAvailable { await checkiCloudStatus() }
        guard iCloudAvailable else { status = .offline; return }
        status = .syncing
        errorMessage = nil

        do {
            // Fetch daily logs
            let remoteLogs = try await fetchEncryptedRecords(
                ofType: CKRecordType.dailyLog,
                as: DailyLog.self
            )
            // Merge: remote wins on conflict (last-write-wins by logicDate)
            for remote in remoteLogs {
                let remoteKey = remote.resolvedLogicDayKey
                if let local = dataStore.log(forLogicDayKey: remoteKey) {
                    // Skip remote overwrite when local has unsaved edits
                    guard !local.needsSync else { continue }
                    if remote.lastModified > local.lastModified {
                        dataStore.dailyLogs.removeAll { $0.resolvedLogicDayKey == remoteKey }
                        var r = remote
                        r.needsSync = false
                        r.logicDayKey = remoteKey
                        dataStore.dailyLogs.append(r)
                    }
                } else {
                    var r = remote
                    r.needsSync = false
                    r.logicDayKey = remoteKey
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
                if let idx = dataStore.weeklySnapshots.firstIndex(where: { logicDayKey(for: $0.weekStart) == logicDayKey(for: remote.weekStart) }) {
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

            let remoteProfile = try await fetchUserProfile()
            applyRemoteSingleton(
                remote: remoteProfile,
                local: dataStore.userProfile,
                digestKey: SyncStateKey.userProfileDigest,
                conflictLabel: "profile"
            ) { merged in
                dataStore.userProfile = merged
            }
            let remotePreferences = try await fetchUserPreferences()
            applyRemoteSingleton(
                remote: remotePreferences,
                local: dataStore.userPreferences,
                digestKey: SyncStateKey.userPreferencesDigest,
                conflictLabel: "preferences"
            ) { merged in
                dataStore.userPreferences = merged
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

        guard let privateDB else {
            throw NSError(domain: "FTCloudKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "CloudKit database unavailable"])
        }

        let saved = try await privateDB.save(record)
        return saved.recordID.recordName
    }

    // ── Download cardio summary image ───────────────────
    func downloadCardioImage(cloudID: String) async throws -> Data {
        let recordID = CKRecord.ID(recordName: cloudID)
        guard let privateDB else { throw cloudKitUnavailableError() }
        let record = try await privateDB.record(for: recordID)

        guard let asset = record[CKField.assetData] as? CKAsset,
              let fileURL = asset.fileURL else {
            throw NSError(domain: "FTCloud", code: 404, userInfo: [NSLocalizedDescriptionKey: "Asset not found"])
        }

        let encryptedData = try Data(contentsOf: fileURL)
        return try await EncryptionService.shared.decryptRaw(encryptedData)
    }

    func deleteAllUserRecords() async throws {
        guard let privateDB else { throw cloudKitUnavailableError() }
        status = .syncing

        for recordType in [
            CKRecordType.dailyLog,
            CKRecordType.weeklySnapshot,
            CKRecordType.userProfile,
            CKRecordType.userPreferences,
            CKRecordType.cardioAsset,
        ] {
            let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
            var cursor: CKQueryOperation.Cursor?

            repeat {
                let result: (matchResults: [(CKRecord.ID, Result<CKRecord, any Error>)], queryCursor: CKQueryOperation.Cursor?)
                if let activeCursor = cursor {
                    result = try await privateDB.records(continuingMatchFrom: activeCursor)
                } else {
                    result = try await privateDB.records(matching: query)
                }

                let recordIDs = result.matchResults.compactMap { _, recordResult in
                    try? recordResult.get().recordID
                }

                for recordID in recordIDs {
                    _ = try await privateDB.deleteRecord(withID: recordID)
                }

                cursor = result.queryCursor
            } while cursor != nil
        }

        defaults.removeObject(forKey: SyncStateKey.userProfileDigest)
        defaults.removeObject(forKey: SyncStateKey.userPreferencesDigest)
        lastSyncDate = nil
        status = .idle
    }

    // ── Private helpers ──────────────────────────────────

    /// Fetch an existing CKRecord (to preserve its server changeTag) or create a new one.
    /// Passing the server-vended record back to save() prevents silent overwrites when two
    /// devices write concurrently — CloudKit will detect the conflict via the changeTag.
    private func fetchOrCreate(recordType: String, recordID: CKRecord.ID) async throws -> CKRecord {
        guard let privateDB else { throw cloudKitUnavailableError() }
        do {
            return try await privateDB.record(for: recordID)
        } catch let error as CKError where error.code == .unknownItem {
            return CKRecord(recordType: recordType, recordID: recordID)
        }
    }

    private func uploadDailyLog(_ log: DailyLog) async throws -> DailyLog {
        // Strip inline JPEG bytes before encrypting — images travel as CKAssets to stay
        // well under CKRecord's 1 MB size limit. Upload each image first, keep only its cloudID.
        var logToUpload = log
        for (key, var cardio) in logToUpload.cardioLogs {
            guard let imageData = cardio.summaryImageData else { continue }
            let cloudID = try await uploadCardioImage(imageData, cardioLogID: cardio.id.uuidString)
            cardio.summaryImageCloudID = cloudID
            cardio.summaryImageData    = nil
            logToUpload.cardioLogs[key] = cardio
        }
        logToUpload.logicDayKey = logToUpload.resolvedLogicDayKey

        let encrypted  = try await EncryptionService.shared.encrypt(logToUpload)
        let recordName = log.cloudRecordID ?? "log-\(logToUpload.resolvedLogicDayKey)"
        let recordID   = CKRecord.ID(recordName: recordName)
        let record     = try await fetchOrCreate(recordType: CKRecordType.dailyLog, recordID: recordID)
        record[CKField.blob]          = encrypted        as CKRecordValue
        record[CKField.logicDate]     = logToUpload.date as CKRecordValue
        record[CKField.recordVersion] = 2         as CKRecordValue
        guard let privateDB else { throw cloudKitUnavailableError() }
        _ = try await privateDB.save(record)
        logToUpload.cloudRecordID = recordName
        logToUpload.needsSync = false
        return logToUpload
    }

    private func uploadWeeklySnapshot(_ snap: WeeklySnapshot) async throws -> String {
        let encrypted  = try await EncryptionService.shared.encrypt(snap)
        let recordName = snap.cloudRecordID ?? "snap-\(Date.fitLogicDayKey(for: snap.weekStart))"
        let recordID   = CKRecord.ID(recordName: recordName)
        let record     = try await fetchOrCreate(recordType: CKRecordType.weeklySnapshot, recordID: recordID)
        record[CKField.blob]          = encrypted      as CKRecordValue
        record[CKField.logicDate]     = snap.weekStart as CKRecordValue
        record[CKField.recordVersion] = 1              as CKRecordValue
        guard let privateDB else { throw cloudKitUnavailableError() }
        _ = try await privateDB.save(record)
        return recordName
    }

    private func uploadUserProfile(_ profile: UserProfile) async throws {
        let encrypted = try await EncryptionService.shared.encrypt(profile)
        let recordID  = CKRecord.ID(recordName: "user-profile-singleton")
        let record    = try await fetchOrCreate(recordType: CKRecordType.userProfile, recordID: recordID)
        record[CKField.blob]          = encrypted as CKRecordValue
        record[CKField.recordVersion] = 1         as CKRecordValue
        guard let privateDB else { throw cloudKitUnavailableError() }
        _ = try await privateDB.save(record)
    }

    private func uploadUserPreferences(_ preferences: UserPreferences) async throws {
        let encrypted = try await EncryptionService.shared.encrypt(preferences)
        let recordID  = CKRecord.ID(recordName: "user-preferences-singleton")
        let record    = try await fetchOrCreate(recordType: CKRecordType.userPreferences, recordID: recordID)
        record[CKField.blob]          = encrypted as CKRecordValue
        record[CKField.recordVersion] = 1         as CKRecordValue
        guard let privateDB else { throw cloudKitUnavailableError() }
        _ = try await privateDB.save(record)
    }

    private func fetchUserProfile() async throws -> UserProfile? {
        let recordID = CKRecord.ID(recordName: "user-profile-singleton")
        guard let privateDB else { throw cloudKitUnavailableError() }
        do {
            let record = try await privateDB.record(for: recordID)
            guard let blob = record[CKField.blob] as? Data else { return nil }
            return try await EncryptionService.shared.decrypt(blob, as: UserProfile.self)
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
    }

    private func fetchUserPreferences() async throws -> UserPreferences? {
        let recordID = CKRecord.ID(recordName: "user-preferences-singleton")
        guard let privateDB else { throw cloudKitUnavailableError() }
        do {
            let record = try await privateDB.record(for: recordID)
            guard let blob = record[CKField.blob] as? Data else { return nil }
            return try await EncryptionService.shared.decrypt(blob, as: UserPreferences.self)
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
    }

    private func fetchEncryptedRecords<T: Decodable>(
        ofType type: String, as decodable: T.Type
    ) async throws -> [T] where T: Sendable {
        guard let privateDB else { throw cloudKitUnavailableError() }
        let query = CKQuery(recordType: type, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: CKField.logicDate, ascending: false)]

        var items: [T] = []
        // Paginate with a cursor loop — the single-shot API is capped at ~200 records.
        var cursor: CKQueryOperation.Cursor?
        repeat {
            let result: (matchResults: [(CKRecord.ID, Result<CKRecord, any Error>)], queryCursor: CKQueryOperation.Cursor?)
            if let activeCursor = cursor {
                result = try await privateDB.records(continuingMatchFrom: activeCursor)
            } else {
                result = try await privateDB.records(matching: query)
            }

            for (_, recordResult) in result.matchResults {
                do {
                    let record = try recordResult.get()
                    guard let blob = record[CKField.blob] as? Data else { continue }
                    let item = try await EncryptionService.shared.decrypt(blob, as: T.self)
                    items.append(item)
                } catch {
                    // Log errors so they are visible rather than silently dropped.
                    print("[CloudKitSyncService] Failed to decode record of type \(type): \(error)")
                    errorMessage = "Sync decode error: \(error.localizedDescription)"
                }
            }
            cursor = result.queryCursor
        } while cursor != nil

        return items
    }

    private func logicDayKey(for date: Date) -> String {
        Date.fitLogicDayKey(for: date)
    }

    private func applyRemoteSingleton<T: Encodable>(
        remote: T?,
        local: T,
        digestKey: String,
        conflictLabel: String,
        apply: (T) -> Void
    ) {
        guard let remote else { return }
        guard
            let localDigest = digest(for: local),
            let remoteDigest = digest(for: remote)
        else {
            apply(remote)
            defaults.set(remoteDigestFallback(for: remote), forKey: digestKey)
            return
        }

        let lastSyncedDigest = defaults.string(forKey: digestKey)

        if localDigest == remoteDigest {
            defaults.set(remoteDigest, forKey: digestKey)
            return
        }

        if lastSyncedDigest == nil || localDigest == lastSyncedDigest {
            apply(remote)
            defaults.set(remoteDigest, forKey: digestKey)
            return
        }

        if errorMessage == nil {
            errorMessage = "Kept local \(conflictLabel) changes because they have not synced yet."
        }
    }

    private func storeSingletonDigest<T: Encodable>(_ value: T, forKey key: String) {
        guard let digest = digest(for: value) else { return }
        defaults.set(digest, forKey: key)
    }

    private func digest<T: Encodable>(for value: T) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(value) else { return nil }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func remoteDigestFallback<T: Encodable>(for value: T) -> String? {
        digest(for: value)
    }
}
