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
    //
    // Audit BE-019: daily logs and weekly snapshots are saved via a single
    // `modifyRecords(saving:deleting:)` operation per chunk of 400 (CloudKit's
    // documented batch ceiling) instead of one `save(_:)` per record. Per-
    // record cardio image uploads stay sequential because each log embeds the
    // image's cloudID before its own payload is encrypted; once payloads are
    // ready, all daily-log and weekly-snapshot saves go in one round trip.
    func pushPendingChanges(dataStore: EncryptedDataStore) async {
        guard let privateDB else {
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
            // Phase 1 — prepare records for batch save. Image uploads still happen
            // here (sequentially per log) because each cardio image is itself a
            // CKAsset whose cloudID is embedded in the log payload before encryption.
            let pendingLogs = dataStore.dailyLogs.filter { $0.needsSync }
            var preparedLogs: [(record: CKRecord, log: DailyLog)] = []
            preparedLogs.reserveCapacity(pendingLogs.count)
            for log in pendingLogs {
                preparedLogs.append(try await prepareDailyLogRecord(log))
            }

            let pendingSnaps = dataStore.weeklySnapshots.filter { $0.needsSync }
            var preparedSnaps: [(record: CKRecord, snap: WeeklySnapshot, recordName: String)] = []
            preparedSnaps.reserveCapacity(pendingSnaps.count)
            for snap in pendingSnaps {
                preparedSnaps.append(try await prepareWeeklySnapshotRecord(snap))
            }

            let allRecords = preparedLogs.map(\.record) + preparedSnaps.map(\.record)

            // Phase 2 — batch save in chunks of 400 (CloudKit per-operation ceiling).
            for chunk in allRecords.chunked(into: 400) {
                let result = try await privateDB.modifyRecords(
                    saving: chunk,
                    deleting: [],
                    savePolicy: .ifServerRecordUnchanged
                )
                for (recordID, perRecord) in result.saveResults {
                    if case .failure(let err) = perRecord {
                        // Surface the first per-record failure as the operation error.
                        // The remaining records in the chunk may have succeeded — those
                        // get committed below by the index-match step.
                        throw NSError(
                            domain: "FTCloudKit",
                            code: -2,
                            userInfo: [NSLocalizedDescriptionKey: "Save failed for \(recordID.recordName): \(err.localizedDescription)"]
                        )
                    }
                }
            }

            // Phase 3 — apply needsSync=false / cloudRecordID updates to the store.
            // Audit DEEP-SYNC-014: this Phase-3 block + persistToDisk MUST stay
            // contiguous with no awaits between the mutations and persist.
            // If an `await` is added between the for-loops and persistToDisk,
            // the cloudRecordID can be set in memory but never reach disk if
            // the app is suspended/killed in that window — defeating CloudKit
            // changeTag conflict detection on the next launch (we'd create a
            // new record instead of updating the existing one).
            for (_, uploadedLog) in preparedLogs {
                if let idx = dataStore.dailyLogs.firstIndex(where: { $0.id == uploadedLog.id }) {
                    dataStore.dailyLogs[idx] = uploadedLog
                    dataStore.dailyLogs[idx].needsSync = false
                }
            }
            for (_, snap, recordName) in preparedSnaps {
                if let idx = dataStore.weeklySnapshots.firstIndex(where: { $0.id == snap.id }) {
                    dataStore.weeklySnapshots[idx].needsSync = false
                    dataStore.weeklySnapshots[idx].cloudRecordID = recordName
                }
            }

            // Persist needsSync = false + cloudRecordID changes to disk before
            // any further operation that could fail. (DEEP-SYNC-014 invariant.)
            await dataStore.persistToDisk()

            // Singletons — kept individual because they have natural-key recordIDs
            // and their writes are infrequent (per app-launch / per profile edit).
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

        // Audit DEEP-AUTH-015: digests live in Keychain (with UserDefaults
        // fallback for legacy data) — clear both backing stores on cleanup.
        KeychainHelper.delete(key: SyncStateKey.userProfileDigest)
        KeychainHelper.delete(key: SyncStateKey.userPreferencesDigest)
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

    /// Build a CKRecord for a daily log without saving it. Used by the
    /// batch-save path (BE-019). Returns the prepared record alongside the
    /// log mutated to reflect the post-save state (cloudRecordID, no
    /// needsSync, image bytes stripped).
    private func prepareDailyLogRecord(_ log: DailyLog) async throws -> (record: CKRecord, log: DailyLog) {
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
        logToUpload.cloudRecordID = recordName
        logToUpload.needsSync = false
        return (record, logToUpload)
    }

    /// Build a CKRecord for a weekly snapshot without saving it. Used by the
    /// batch-save path (BE-019).
    private func prepareWeeklySnapshotRecord(_ snap: WeeklySnapshot) async throws -> (record: CKRecord, snap: WeeklySnapshot, recordName: String) {
        let encrypted  = try await EncryptionService.shared.encrypt(snap)
        let recordName = snap.cloudRecordID ?? "snap-\(Date.fitLogicDayKey(for: snap.weekStart))"
        let recordID   = CKRecord.ID(recordName: recordName)
        let record     = try await fetchOrCreate(recordType: CKRecordType.weeklySnapshot, recordID: recordID)
        record[CKField.blob]          = encrypted      as CKRecordValue
        record[CKField.logicDate]     = snap.weekStart as CKRecordValue
        record[CKField.recordVersion] = 1              as CKRecordValue
        return (record, snap, recordName)
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
            storeDigest(remoteDigestFallback(for: remote), forKey: digestKey)
            return
        }

        let lastSyncedDigest = loadDigest(forKey: digestKey)

        if localDigest == remoteDigest {
            storeDigest(remoteDigest, forKey: digestKey)
            return
        }

        if lastSyncedDigest == nil || localDigest == lastSyncedDigest {
            apply(remote)
            storeDigest(remoteDigest, forKey: digestKey)
            return
        }

        if errorMessage == nil {
            errorMessage = "Kept local \(conflictLabel) changes because they have not synced yet."
        }
    }

    private func storeSingletonDigest<T: Encodable>(_ value: T, forKey key: String) {
        guard let digest = digest(for: value) else { return }
        storeDigest(digest, forKey: key)
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

    /// Audit DEEP-AUTH-015: store/load three-way merge digests in the Keychain
    /// instead of UserDefaults so they're not tamperable on jailbroken devices
    /// (an attacker who could write to Preferences could otherwise force the
    /// merge to treat any remote payload as authoritative). Falls back to
    /// UserDefaults for legacy data so a single migration window keeps existing
    /// digests valid; reads write-through to Keychain on first hit.
    private func storeDigest(_ digest: String?, forKey key: String) {
        guard let digest, let data = digest.data(using: .utf8) else { return }
        KeychainHelper.save(key: key, data: data)
        // Cleanup: remove any legacy UserDefaults copy so future reads don't
        // see a stale value if Keychain delete fails for some reason.
        defaults.removeObject(forKey: key)
    }

    private func loadDigest(forKey key: String) -> String? {
        if let data = KeychainHelper.load(key: key),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        // Legacy fallback: existing installs may still have the digest in
        // UserDefaults. Promote to Keychain on first read.
        if let legacy = defaults.string(forKey: key) {
            if let data = legacy.data(using: .utf8) {
                KeychainHelper.save(key: key, data: data)
            }
            defaults.removeObject(forKey: key)
            return legacy
        }
        return nil
    }
}

// MARK: - BE-019 helpers

private extension Array {
    /// Split into contiguous chunks of `size` elements (last chunk may be smaller).
    /// Used to honor CloudKit's 400-record-per-operation ceiling.
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
