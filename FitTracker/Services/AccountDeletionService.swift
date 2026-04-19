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

    /// Request account deletion — starts 30-day grace period.
    /// Audit BE-023: also persisted to Supabase user_metadata so a reinstall
    /// during the grace period restores the deletion intent rather than
    /// silently cancelling it. Local write is the source of truth for UI;
    /// remote write is best-effort and logged on failure.
    func requestDeletion(authMethod: String) async {
        let now = Date()
        deletionScheduledAt = now
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: "ft.deletion.scheduledAt")
        do {
            try await supabaseSync.setRemoteDeletionScheduledAt(now)
        } catch {
            // Local copy stands; remote sync will retry on next launch via checkGracePeriod
            deletionError = "Saved locally; remote sync failed: \(error.localizedDescription)"
        }
        analytics.logAccountDeleteRequested(method: authMethod)
    }

    /// Cancel pending deletion — restores account. Audit BE-023: also clears
    /// the remote user_metadata flag so a fresh install doesn't see a stale
    /// deletion request.
    func cancelDeletion() async {
        let remaining = daysRemaining ?? 0
        deletionScheduledAt = nil
        UserDefaults.standard.removeObject(forKey: "ft.deletion.scheduledAt")
        do {
            try await supabaseSync.setRemoteDeletionScheduledAt(nil)
        } catch {
            deletionError = "Cleared locally; remote sync failed: \(error.localizedDescription)"
        }
        analytics.logAccountDeleteCancelled(daysRemaining: remaining)
    }

    /// Check if there's a pending deletion on launch. Audit BE-023: in
    /// addition to UserDefaults, fetch the remote `deletionScheduledAt` from
    /// Supabase user_metadata. The earlier of the two timestamps wins —
    /// that's the original deletion request, even if the local copy was
    /// wiped by a reinstall. Sync the result back to local so UI is consistent.
    func checkGracePeriod() async {
        let storedTs = UserDefaults.standard.double(forKey: "ft.deletion.scheduledAt")
        let local: Date? = storedTs > 0 ? Date(timeIntervalSince1970: storedTs) : nil
        let remote = await supabaseSync.fetchRemoteDeletionScheduledAt()

        let resolved: Date? = switch (local, remote) {
        case (nil, nil): nil
        case (nil, .some(let r)): r
        case (.some(let l), nil): l
        case (.some(let l), .some(let r)): min(l, r)  // earlier wins — the original deletion intent
        }

        deletionScheduledAt = resolved
        if let resolved, local != resolved {
            // Remote was earlier (or local was missing) — restore local cache.
            UserDefaults.standard.set(resolved.timeIntervalSince1970, forKey: "ft.deletion.scheduledAt")
        }
    }

    // MARK: - Execute Deletion (after grace period)

    /// Execute the full deletion cascade across all 9 data stores
    func executeDeletion() async {
        isDeleting = true
        deletionError = nil
        var deletedStores: [String] = []
        var failedStores: [String] = []

        analytics.setUserID(nil)

        do {
            await supabaseSync.unsubscribeRealtime()
            try await supabaseSync.deleteAllUserData()
            deletedStores.append("supabase")
        } catch {
            failedStores.append("supabase")
        }

        do {
            try await cloudSync.deleteAllUserRecords()
            deletedStores.append("cloudkit")
        } catch {
            failedStores.append("cloudkit")
        }

        do {
            try dataStore.deletePersistedData()
            deletedStores.append("device")
        } catch {
            failedStores.append("device")
        }

        do {
            try await EncryptionService.shared.deleteStoredKeys()
            deletedStores.append("keychain")
        } catch {
            failedStores.append("keychain")
        }

        clearUserDefaults()
        deletedStores.append("userdefaults")

        if failedStores.isEmpty {
            analytics.logAccountDeleteCompleted(storesDeleted: deletedStores)
        } else {
            deletionError = "Deleted: \(deletedStores.joined(separator: ", ")). Still pending: \(failedStores.joined(separator: ", "))."
        }

        signIn.signOut()
        isDeleting = false
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
