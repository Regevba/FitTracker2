// Services/Notifications/NotificationPreferencesStore.swift
// UserDefaults-backed store for per-type notification preferences and
// global frequency cap.  All keys use the "ft.notification." prefix.

import Foundation
import SwiftUI

// ─────────────────────────────────────────────────────────
// MARK: – Notification Preferences Store
// ─────────────────────────────────────────────────────────

@MainActor
final class NotificationPreferencesStore: ObservableObject {

    // ── Keys ─────────────────────────────────────────────

    private enum Keys {
        static let masterEnabled            = "ft.notification.masterEnabled"
        static let workoutRemindersEnabled  = "ft.notification.workoutRemindersEnabled"
        static let readinessAlertsEnabled   = "ft.notification.readinessAlertsEnabled"
        static let recoveryNudgesEnabled    = "ft.notification.recoveryNudgesEnabled"
        static let maxDailyNotifications    = "ft.notification.maxDailyNotifications"
    }

    // ── Published properties ─────────────────────────────

    /// Master kill-switch: when `false`, no notifications fire regardless of
    /// per-type settings.
    @Published var masterEnabled: Bool = true {
        didSet { UserDefaults.standard.set(masterEnabled, forKey: Keys.masterEnabled) }
    }

    /// Controls workout-reminder notifications (10 AM on training days).
    @Published var workoutRemindersEnabled: Bool = true {
        didSet { UserDefaults.standard.set(workoutRemindersEnabled, forKey: Keys.workoutRemindersEnabled) }
    }

    /// Controls readiness-alert notifications (8 AM when score < 40).
    @Published var readinessAlertsEnabled: Bool = true {
        didSet { UserDefaults.standard.set(readinessAlertsEnabled, forKey: Keys.readinessAlertsEnabled) }
    }

    /// Controls recovery-nudge notifications (7 PM after 4+ consecutive training days).
    @Published var recoveryNudgesEnabled: Bool = true {
        didSet { UserDefaults.standard.set(recoveryNudgesEnabled, forKey: Keys.recoveryNudgesEnabled) }
    }

    /// Maximum number of notifications delivered across all types per calendar day.
    /// Default: 2 (matches UX spec frequency cap).
    @Published var maxDailyNotifications: Int = 2 {
        didSet { UserDefaults.standard.set(maxDailyNotifications, forKey: Keys.maxDailyNotifications) }
    }

    // ── Init ─────────────────────────────────────────────

    init() {
        let defaults = UserDefaults.standard

        // Only override the Swift default if the key has been written before.
        if defaults.object(forKey: Keys.masterEnabled) != nil {
            masterEnabled = defaults.bool(forKey: Keys.masterEnabled)
        }
        if defaults.object(forKey: Keys.workoutRemindersEnabled) != nil {
            workoutRemindersEnabled = defaults.bool(forKey: Keys.workoutRemindersEnabled)
        }
        if defaults.object(forKey: Keys.readinessAlertsEnabled) != nil {
            readinessAlertsEnabled = defaults.bool(forKey: Keys.readinessAlertsEnabled)
        }
        if defaults.object(forKey: Keys.recoveryNudgesEnabled) != nil {
            recoveryNudgesEnabled = defaults.bool(forKey: Keys.recoveryNudgesEnabled)
        }
        if defaults.object(forKey: Keys.maxDailyNotifications) != nil {
            maxDailyNotifications = defaults.integer(forKey: Keys.maxDailyNotifications)
        }
    }

    // ── Convenience ──────────────────────────────────────

    /// Returns `true` if the given notification type is allowed by both the
    /// master switch and the per-type toggle.
    func isEnabled(for type: NotificationType) -> Bool {
        guard masterEnabled else { return false }
        switch type {
        case .workoutReminder: return workoutRemindersEnabled
        case .readinessAlert:  return readinessAlertsEnabled
        case .recoveryNudge:   return recoveryNudgesEnabled
        }
    }
}
