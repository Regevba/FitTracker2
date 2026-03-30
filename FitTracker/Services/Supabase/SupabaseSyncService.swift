// FitTracker/Services/Supabase/SupabaseSyncService.swift
// Supabase sync layer: push, incremental pull, full pull (new device), realtime.
// All health data is encrypted BEFORE leaving the device — server stores .ftenc blobs only.
//
// Three triggers (matching CloudKitSyncService pattern):
//   App becomes active  → fetchChanges() + subscribeRealtime()
//   App backgrounds     → unsubscribeRealtime() + pushPendingChanges()
//   First login         → fetchAllRecords() (called from FitTrackerApp on activeSession change)

import Foundation
import CryptoKit
import Supabase  // supabase-swift v2.x

// MARK: - Sync Status

enum SupabaseSyncStatus: Equatable {
    case idle
    case syncing
    case failed(String)
    case offline
    case disabled
}

// MARK: - SupabaseSyncService

@MainActor
final class SupabaseSyncService: ObservableObject {

    @Published private(set) var status: SupabaseSyncStatus = .idle

    // MARK: - Record Type Constants

    private enum RT {
        static let dailyLog        = "daily_log"
        static let weeklySnapshot  = "weekly_snapshot"
        static let userProfile     = "user_profile"
        static let userPreferences = "user_preferences"
        static let mealTemplates   = "meal_templates"
    }

    // MARK: - Push

    /// Upload all records that have `needsSync = true`.
    /// Per-record do/catch: a single failure marks status but doesn't abort the rest.
    func pushPendingChanges(dataStore: EncryptedDataStore) async {
        guard case .idle = status else { return }
        let session = try? await supabase.auth.session
        guard let userID = session?.user.id else { return }
        status = .syncing
        var anyFailed = false

        // Daily logs
        for log in dataStore.dailyLogs.filter({ $0.needsSync }) {
            do {
                let blob = try await EncryptionService.shared.encrypt(log)
                let checksum = SHA256.hash(data: blob).hexString
                try await supabase
                    .from("sync_records")
                    .upsert([
                        "user_id":           userID.uuidString,
                        "record_type":       RT.dailyLog,
                        "logic_date":        log.date.isoDateString,
                        "encrypted_payload": blob.base64EncodedString(),
                        "checksum":          checksum,
                        "last_modified":     log.lastModified.iso8601String
                    ], onConflict: "user_id,record_type,logic_date")
                    .execute()
                dataStore.markSynced(logID: log.id)
            } catch {
                anyFailed = true
            }
        }

        // Weekly snapshots
        for snap in dataStore.weeklySnapshots.filter({ $0.needsSync }) {
            do {
                let blob = try await EncryptionService.shared.encrypt(snap)
                let checksum = SHA256.hash(data: blob).hexString
                try await supabase
                    .from("sync_records")
                    .upsert([
                        "user_id":           userID.uuidString,
                        "record_type":       RT.weeklySnapshot,
                        "week_start":        snap.weekStart.isoDateString,
                        "encrypted_payload": blob.base64EncodedString(),
                        "checksum":          checksum,
                        "last_modified":     snap.lastModified.iso8601String
                    ], onConflict: "user_id,record_type,week_start")
                    .execute()
                dataStore.markSnapshotSynced(id: snap.id)
            } catch {
                anyFailed = true
            }
        }

        // Singletons
        let singletonsFailed = await pushSingletons(userID: userID, dataStore: dataStore)
        anyFailed = anyFailed || singletonsFailed

        status = anyFailed ? .failed("One or more records failed to sync") : .idle
    }

    // MARK: - Pull (Incremental)

    /// Pull records modified since the last successful pull.
    func fetchChanges(dataStore: EncryptedDataStore) async {
        guard case .idle = status else { return }
        let session = try? await supabase.auth.session
        guard let userID = session?.user.id else { return }
        status = .syncing
        let lastPull = UserDefaults.standard.object(forKey: "supabase.lastPull") as? Date ?? .distantPast
        await pullRecords(since: lastPull, userID: userID, dataStore: dataStore)
    }

    /// Pull ALL records — used on first login to a new device.
    func fetchAllRecords(dataStore: EncryptedDataStore) async {
        guard case .idle = status else { return }
        let session = try? await supabase.auth.session
        guard let userID = session?.user.id else { return }
        status = .syncing
        UserDefaults.standard.removeObject(forKey: "supabase.lastPull")
        await pullRecords(since: .distantPast, userID: userID, dataStore: dataStore)
    }

    // MARK: - Realtime

    /// Subscribe to real-time changes on `sync_records` for the signed-in user.
    /// NOTE: Realtime subscription is a no-op pending supabase-swift 2.x API stabilisation.
    /// The app syncs reliably via fetchChanges() on each app-foreground event.
    func subscribeRealtime(dataStore: EncryptedDataStore) async {
        // TODO: wire up realtime when the supabase-swift 2.x channel API stabilises.
    }

    func unsubscribeRealtime() async {
        // No-op: realtime subscription not active.
    }

    // MARK: - Cardio Assets

    /// Encrypt and upload a cardio image to Supabase Storage; record metadata in cardio_assets.
    func uploadCardioImage(_ imageData: Data, log: DailyLog, cardioType: String) async throws -> String {
        let session = try? await supabase.auth.session
        guard let userID = session?.user.id else {
            throw FTAuthError.unknown
        }
        let encrypted = try await EncryptionService.shared.encryptRaw(imageData)
        let path = "\(userID.uuidString)/\(log.date.isoDateString)/\(cardioType.lowercased()).ftenc"

        try await supabase.storage
            .from("cardio-images")
            .upload(path: path, file: encrypted, options: FileOptions(upsert: true))

        let checksum = SHA256.hash(data: encrypted).hexString
        try await supabase
            .from("cardio_assets")
            .upsert([
                "user_id":       userID.uuidString,
                "logic_date":    log.date.isoDateString,
                "cardio_type":   cardioType,
                "storage_path":  path,
                "checksum":      checksum,
                "last_modified": Date().iso8601String
            ], onConflict: "user_id,logic_date,cardio_type")
            .execute()
        return path
    }

    /// Download and decrypt a cardio image from Supabase Storage.
    func downloadCardioImage(storagePath: String) async throws -> Data {
        let encrypted = try await supabase.storage
            .from("cardio-images")
            .download(path: storagePath)
        return try await EncryptionService.shared.decryptRaw(encrypted)
    }
}

// MARK: - Private Helpers

private extension SupabaseSyncService {

    // Shared pull logic — used by both fetchChanges and fetchAllRecords.
    func pullRecords(since lastPull: Date, userID: UUID, dataStore: EncryptedDataStore) async {
        do {
            struct SyncRow: Decodable {
                let recordType:       String
                let logicDate:        Date?
                let weekStart:        Date?
                let encryptedPayload: String   // base64-encoded by PostgREST
                let checksum:         String
                let lastModified:     Date

                enum CodingKeys: String, CodingKey {
                    case recordType       = "record_type"
                    case logicDate        = "logic_date"
                    case weekStart        = "week_start"
                    case encryptedPayload = "encrypted_payload"
                    case checksum
                    case lastModified     = "last_modified"
                }
            }

            let rows: [SyncRow] = try await supabase
                .from("sync_records")
                .select("record_type, logic_date, week_start, encrypted_payload, checksum, last_modified")
                .eq("user_id", value: userID.uuidString)
                .gte("last_modified", value: lastPull.iso8601String)
                .order("last_modified", ascending: false)
                .execute()
                .value

            for row in rows {
                guard let payloadData = Data(base64Encoded: row.encryptedPayload) else { continue }
                do {
                    try await applyRow(row.recordType,
                                       payload: payloadData,
                                       checksum: row.checksum,
                                       dataStore: dataStore)
                } catch {
                    // Decryption failure for one row should not abort the full pull
                }
            }

            // Pull cardio asset metadata (images fetched lazily on display)
            try await fetchCardioAssetMetadata(userID: userID, since: lastPull, dataStore: dataStore)

            UserDefaults.standard.set(Date(), forKey: "supabase.lastPull")
            status = .idle
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func applyRow(_ recordType: String,
                  payload: Data,
                  checksum: String,
                  dataStore: EncryptedDataStore) async throws {
        switch recordType {
        case RT.dailyLog:
            let log = try await EncryptionService.shared.decrypt(payload, as: DailyLog.self)
            dataStore.mergeDailyLog(log)

        case RT.weeklySnapshot:
            let snap = try await EncryptionService.shared.decrypt(payload, as: WeeklySnapshot.self)
            dataStore.mergeWeeklySnapshot(snap)

        case RT.userProfile:
            let profile = try await EncryptionService.shared.decrypt(payload, as: UserProfile.self)
            dataStore.mergeProfile(profile,
                                   remoteChecksum: checksum,
                                   digestKey: "supabase.user_profile")

        case RT.userPreferences:
            let prefs = try await EncryptionService.shared.decrypt(payload, as: UserPreferences.self)
            dataStore.mergePreferences(prefs,
                                       remoteChecksum: checksum,
                                       digestKey: "supabase.user_preferences")

        case RT.mealTemplates:
            let templates = try await EncryptionService.shared.decrypt(payload, as: [MealTemplate].self)
            dataStore.mergeMealTemplates(templates,
                                         remoteChecksum: checksum,
                                         digestKey: "supabase.meal_templates")

        default:
            break
        }
    }

    // Push singletons (profile, preferences, templates). Returns true if any failed.
    func pushSingletons(userID: UUID, dataStore: EncryptedDataStore) async -> Bool {
        var anyFailed = false

        let singletonJobs: [(String, any Encodable, String)] = [
            (RT.userProfile,     dataStore.userProfile,     "supabase.user_profile"),
            (RT.userPreferences, dataStore.userPreferences, "supabase.user_preferences"),
            (RT.mealTemplates,   dataStore.mealTemplates,   "supabase.meal_templates")
        ]

        for (recordType, value, digestKey) in singletonJobs {
            do {
                let blob = try await EncryptionService.shared.encrypt(value)
                let checksum = SHA256.hash(data: blob).hexString
                let lastSyncedChecksum = UserDefaults.standard.string(forKey: digestKey) ?? ""
                guard checksum != lastSyncedChecksum else { continue }  // unchanged — skip

                try await supabase
                    .from("sync_records")
                    .upsert([
                        "user_id":           userID.uuidString,
                        "record_type":       recordType,
                        "encrypted_payload": blob.base64EncodedString(),
                        "checksum":          checksum,
                        "last_modified":     Date().iso8601String
                    ], onConflict: "user_id,record_type")
                    .execute()
                UserDefaults.standard.set(checksum, forKey: digestKey)
            } catch {
                anyFailed = true
            }
        }
        return anyFailed
    }

    func fetchCardioAssetMetadata(userID: UUID, since: Date, dataStore: EncryptedDataStore) async throws {
        struct AssetRow: Decodable {
            let logicDate:   Date
            let cardioType:  String
            let storagePath: String
            enum CodingKeys: String, CodingKey {
                case logicDate   = "logic_date"
                case cardioType  = "cardio_type"
                case storagePath = "storage_path"
            }
        }
        let rows: [AssetRow] = try await supabase
            .from("cardio_assets")
            .select("logic_date, cardio_type, storage_path")
            .eq("user_id", value: userID.uuidString)
            .gte("last_modified", value: since.iso8601String)
            .execute()
            .value

        for row in rows {
            dataStore.updateCardioImagePath(date: row.logicDate,
                                            cardioType: row.cardioType,
                                            storagePath: row.storagePath)
        }
    }
}
