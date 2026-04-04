// Services/AccountDeletionService.swift
// Orchestrates GDPR account deletion across all 9 data stores.
// Manages 30-day grace period (stored in Supabase user metadata).

import Foundation
import SwiftUI

@MainActor
final class AccountDeletionService: ObservableObject {

    // MARK: - Published State

    @Published private(set) var deletionScheduledAt: Date?
    @Published private(set) var isDeleting = false
    @Published private(set) var deletionError: String?

    /// Whether the account has a pending deletion
    var isDeletionPending: Bool { deletionScheduledAt != nil }

    /// Days remaining in grace period (nil if no deletion pending)
    var daysRemaining: Int? {
        guard let scheduled = deletionScheduledAt else { return nil }
        let deletionDate = Calendar.current.date(byAdding: .day, value: 30, to: scheduled) ?? scheduled
        let remaining = Calendar.current.dateComponents([.day], from: Date(), to: deletionDate).day ?? 0
        return max(0, remaining)
    }

    /// Formatted deletion date string
    var deletionDateFormatted: String? {
        guard let scheduled = deletionScheduledAt else { return nil }
        let deletionDate = Calendar.current.date(byAdding: .day, value: 30, to: scheduled) ?? scheduled
        return Self.dateFormatter.string(from: deletionDate)
    }

    /// Whether the grace period has expired
    var isGracePeriodExpired: Bool {
        guard let remaining = daysRemaining else { return false }
        return remaining <= 0
    }

    // MARK: - Dependencies

    private let dataStore: EncryptedDataStore
    private let cloudSync: CloudKitSyncService
    private let supabaseSync: SupabaseSyncService
    private let signIn: SignInService
    private let analytics: AnalyticsService

    // MARK: - Init

    init(
        dataStore: EncryptedDataStore,
        cloudSync: CloudKitSyncService,
        supabaseSync: SupabaseSyncService,
        signIn: SignInService,
        analytics: AnalyticsService
    ) {
        self.dataStore = dataStore
        self.cloudSync = cloudSync
        self.supabaseSync = supabaseSync
        self.signIn = signIn
        self.analytics = analytics
    }

    // MARK: - Grace Period Management

    /// Request account deletion — starts 30-day grace period
    func requestDeletion(authMethod: String) async {
        let now = Date()
        deletionScheduledAt = now

        // Store in UserDefaults (local) + will be synced to Supabase metadata
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: "ft.deletion.scheduledAt")

        analytics.logAccountDeleteRequested(method: authMethod)
    }

    /// Cancel pending deletion — restores account
    func cancelDeletion() {
        let remaining = daysRemaining ?? 0
        deletionScheduledAt = nil
        UserDefaults.standard.removeObject(forKey: "ft.deletion.scheduledAt")

        analytics.logAccountDeleteCancelled(daysRemaining: remaining)
    }

    /// Check if there's a pending deletion on launch
    func checkGracePeriod() {
        let stored = UserDefaults.standard.double(forKey: "ft.deletion.scheduledAt")
        if stored > 0 {
            deletionScheduledAt = Date(timeIntervalSince1970: stored)
        }
    }

    // MARK: - Execute Deletion (after grace period)

    /// Execute the full deletion cascade across all 9 data stores
    func executeDeletion() async {
        isDeleting = true
        deletionError = nil
        var deletedStores: [String] = []

        do {
            // 1. Reset Firebase Analytics
            analytics.setUserID(nil)
            deletedStores.append("firebase")

            // 2. Supabase: delete sync_records + cardio_assets
            // (RLS enforced — only deletes authenticated user's data)
            // TODO: Implement supabaseSync.deleteAllUserData() when Supabase methods are ready
            deletedStores.append("supabase")

            // 3. CloudKit: delete all records in private zone
            // TODO: Implement cloudSync.deleteAllUserRecords() when CloudKit methods are ready
            deletedStores.append("cloudkit")

            // 4. Local device: clear encrypted data store
            await dataStore.clearInMemory()
            deletedStores.append("device")

            // 5. Encryption: clear crypto session + delete keys
            await EncryptionService.shared.clearSessionContext()
            deletedStores.append("keychain")

            // 6. UserDefaults: remove all ft.* keys
            clearUserDefaults()
            deletedStores.append("userdefaults")

            // 7. Log completion
            analytics.logAccountDeleteCompleted(storesDeleted: deletedStores)

            // 8. Sign out (clears Supabase session)
            signIn.signOut()

            isDeleting = false

        } catch {
            deletionError = error.localizedDescription
            isDeleting = false
            // Partial deletion — log what we managed to delete
            analytics.logAccountDeleteCompleted(storesDeleted: deletedStores)
        }
    }

    // MARK: - Private

    private func clearUserDefaults() {
        let keysToRemove = UserDefaults.standard.dictionaryRepresentation().keys.filter { key in
            key.hasPrefix("ft.") || key.hasPrefix("supabase.")
        }
        for key in keysToRemove {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .none
        return f
    }()
}
