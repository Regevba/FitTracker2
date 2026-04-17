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
import os.log
import Supabase  // supabase-swift v2.x

private let syncLogger = Logger(subsystem: "com.fitme.sync", category: "supabase")

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

    // Realtime channel — held to keep the subscription alive and to allow unsubscribe.
    private var realtimeChannel: RealtimeChannelV2?

    /// Debounce task for realtime events — prevents concurrent fetch storms.
    private var realtimeDebounceTask: Task<Void, Never>?

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
        guard SupabaseRuntimeConfiguration.isConfigured else {
            status = .disabled
            return
        }
        guard case .idle = status else { return }
        let session: Session
        do {
            session = try await supabase.auth.session
        } catch {
            syncLogger.error("Auth session expired during push: \(error.localizedDescription)")
            status = .failed("Auth session expired")
            return
        }
        let userID = session.user.id
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
                syncLogger.error("Push failed for daily log \(log.id): \(error.localizedDescription)")
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
                syncLogger.error("Push failed for weekly snapshot \(snap.id): \(error.localizedDescription)")
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
        guard SupabaseRuntimeConfiguration.isConfigured else {
            status = .disabled
            return
        }
        guard case .idle = status else { return }
        let session = try? await supabase.auth.session
        guard let userID = session?.user.id else { return }
        status = .syncing
        let lastPull = UserDefaults.standard.object(forKey: "supabase.lastPull") as? Date ?? .distantPast
        await pullRecords(since: lastPull, userID: userID, dataStore: dataStore)
    }

    /// Pull ALL records — used on first login to a new device.
    /// On subsequent session refreshes, use `fetchChanges()` for incremental pull.
    func fetchAllRecords(dataStore: EncryptedDataStore) async {
        guard SupabaseRuntimeConfiguration.isConfigured else {
            status = .disabled
            return
        }
        guard case .idle = status else { return }
        let session = try? await supabase.auth.session
        guard let userID = session?.user.id else { return }

        // Only do a full pull when no prior pull exists (first login).
        // Session refreshes should use fetchChanges() for incremental pull.
        let hasExistingPull = UserDefaults.standard.object(forKey: "supabase.lastPull") != nil
        if hasExistingPull {
            await fetchChanges(dataStore: dataStore)
            return
        }

        status = .syncing
        await pullRecords(since: .distantPast, userID: userID, dataStore: dataStore)
    }

    // MARK: - Realtime

    /// Subscribe to real-time changes on `sync_records` for the signed-in user.
    /// When the server notifies of a new/updated row, the app pulls the full incremental
    /// change set via `fetchChanges()` — we don't trust the realtime payload directly
    /// because the payload is unencrypted metadata only (encrypted_payload is not sent
    /// in the Change event to avoid unnecessary data transfer).
    func subscribeRealtime(dataStore: EncryptedDataStore) async {
        guard SupabaseRuntimeConfiguration.isConfigured else {
            status = .disabled
            return
        }
        guard realtimeChannel == nil else { return }   // already subscribed
        guard let session = try? await supabase.auth.session else { return }
        let userID = session.user.id.uuidString

        let channel = supabase.realtimeV2.channel("sync_records:\(userID)")

        // Listen for INSERT and UPDATE on rows belonging to this user.
        // RLS on the `sync_records` table ensures the server only broadcasts
        // rows where user_id matches the authenticated session.
        _ = channel.onPostgresChange(
            InsertAction.self,
            schema: "public",
            table: "sync_records"
        ) { [weak self] _ in
            guard let self else { return }
            Task { await self.debouncedFetchChanges(dataStore: dataStore) }
        }

        _ = channel.onPostgresChange(
            UpdateAction.self,
            schema: "public",
            table: "sync_records"
        ) { [weak self] _ in
            guard let self else { return }
            Task { await self.debouncedFetchChanges(dataStore: dataStore) }
        }

        do {
            try await channel.subscribeWithError()
            realtimeChannel = channel
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    /// Debounce realtime events — coalesces rapid-fire notifications into a single fetch.
    private func debouncedFetchChanges(dataStore: EncryptedDataStore) {
        realtimeDebounceTask?.cancel()
        realtimeDebounceTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            await fetchChanges(dataStore: dataStore)
        }
    }

    func unsubscribeRealtime() async {
        guard let channel = realtimeChannel else { return }
        await channel.unsubscribe()
        realtimeChannel = nil
    }

    // MARK: - Cardio Assets

    /// Encrypt and upload a cardio image to Supabase Storage; record metadata in cardio_assets.
    func uploadCardioImage(_ imageData: Data, log: DailyLog, cardioType: String) async throws -> String {
        guard SupabaseRuntimeConfiguration.isConfigured else {
            status = .disabled
            throw SupabaseRuntimeConfiguration.missingConfigurationError
        }
        let session = try? await supabase.auth.session
        guard let userID = session?.user.id else {
            throw FTAuthError.unknown
        }
        let encrypted = try await EncryptionService.shared.encryptRaw(imageData)
        let path = "\(userID.uuidString)/\(log.date.isoDateString)/\(cardioType.lowercased()).ftenc"

        try await supabase.storage
            .from("cardio-images")
            .upload(path, data: encrypted, options: FileOptions(upsert: true))

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
        guard SupabaseRuntimeConfiguration.isConfigured else {
            status = .disabled
            throw SupabaseRuntimeConfiguration.missingConfigurationError
        }
        let encrypted = try await supabase.storage
            .from("cardio-images")
            .download(path: storagePath)
        return try await EncryptionService.shared.decryptRaw(encrypted)
    }

    /// Delete all remote user data owned by the currently authenticated user.
    func deleteAllUserData() async throws {
        guard SupabaseRuntimeConfiguration.isConfigured else {
            status = .disabled
            throw SupabaseRuntimeConfiguration.missingConfigurationError
        }
        guard let session = try? await supabase.auth.session else { return }
        let userID = session.user.id.uuidString
        status = .syncing

        struct CardioAssetPathRow: Decodable {
            let storagePath: String

            enum CodingKeys: String, CodingKey {
                case storagePath = "storage_path"
            }
        }

        let assetRows: [CardioAssetPathRow] = try await supabase
            .from("cardio_assets")
            .select("storage_path")
            .eq("user_id", value: userID)
            .execute()
            .value

        if !assetRows.isEmpty {
            _ = try await supabase.storage
                .from("cardio-images")
                .remove(paths: assetRows.map(\.storagePath))
        }

        try await supabase
            .from("cardio_assets")
            .delete()
            .eq("user_id", value: userID)
            .execute()

        try await supabase
            .from("sync_records")
            .delete()
            .eq("user_id", value: userID)
            .execute()

        status = .idle
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

            var oldestFailure: Date?
            for row in rows {
                guard let payloadData = Data(base64Encoded: row.encryptedPayload) else { continue }
                do {
                    try await applyRow(row.recordType,
                                       payload: payloadData,
                                       checksum: row.checksum,
                                       dataStore: dataStore)
                } catch {
                    // Track failed row so we don't advance lastPull past it
                    syncLogger.error("Decryption failed for \(row.recordType): \(error.localizedDescription)")
                    oldestFailure = min(oldestFailure ?? row.lastModified, row.lastModified)
                }
            }

            // Pull cardio asset metadata (images fetched lazily on display)
            try await fetchCardioAssetMetadata(userID: userID, since: lastPull, dataStore: dataStore)

            // Don't advance lastPull past decryption failures — re-fetch from before the oldest failure
            if let oldest = oldestFailure {
                UserDefaults.standard.set(oldest.addingTimeInterval(-1), forKey: "supabase.lastPull")
            } else {
                UserDefaults.standard.set(Date(), forKey: "supabase.lastPull")
            }
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
                // Compute checksum from plaintext so identical data always produces the same hash,
                // regardless of per-encryption IV differences in the ciphertext.
                let plaintext = try JSONEncoder().encode(value)
                let checksum = SHA256.hash(data: plaintext).hexString
                let lastSyncedChecksum = UserDefaults.standard.string(forKey: digestKey) ?? ""
                guard checksum != lastSyncedChecksum else { continue }  // unchanged — skip

                let blob = try await EncryptionService.shared.encrypt(value)
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
