// Services/Notifications/ReminderPreferencesStore.swift
// v2 preferences store — supersedes the historical v1 NotificationPreferencesStore
// (whose 3 hard-coded types are obsolete under push-notifications-v2's 6 ReminderType cases).
// UserDefaults-backed. Keys use the "ft.reminder." prefix to namespace away from v1.
//
// Scope (this commit):
//   • Storage + Published properties for 6 per-type toggles + master + dailyCap
//   • UI binding via @EnvironmentObject in NotificationsSettingsScreen
//
// Out of scope (separate follow-up):
//   • Wiring `ReminderScheduler.scheduleIfAllowed(...)` to respect these toggles
//     before dispatching to NotificationGateway.
//
// See L349 backlog entry + PR description for the integration roadmap.

import Foundation
import SwiftUI

@MainActor
final class ReminderPreferencesStore: ObservableObject {

    // MARK: - Keys

    private enum Keys {
        static let masterEnabled    = "ft.reminder.masterEnabled"
        static let dailyCap         = "ft.reminder.dailyCap"

        static let healthKitConnect    = "ft.reminder.healthKitConnect"
        static let accountRegistration = "ft.reminder.accountRegistration"
        static let nutritionGap        = "ft.reminder.nutritionGap"
        static let trainingDay         = "ft.reminder.trainingDay"
        static let restDay             = "ft.reminder.restDay"
        static let engagement          = "ft.reminder.engagement"
        static let readinessAware      = "ft.reminder.readinessAware"
    }

    // MARK: - Published

    /// Master kill-switch. When `false`, every per-type toggle is overridden off.
    @Published var masterEnabled: Bool = true {
        didSet { UserDefaults.standard.set(masterEnabled, forKey: Keys.masterEnabled) }
    }

    /// Maximum number of reminder notifications delivered across all types per
    /// calendar day. Default 2 matches the UX-spec frequency cap codified in
    /// the push-notifications-v2 PRD. Range 0–5 in the UI.
    @Published var dailyCap: Int = 2 {
        didSet { UserDefaults.standard.set(dailyCap, forKey: Keys.dailyCap) }
    }

    @Published var healthKitConnectEnabled: Bool = true {
        didSet { UserDefaults.standard.set(healthKitConnectEnabled, forKey: Keys.healthKitConnect) }
    }

    @Published var accountRegistrationEnabled: Bool = true {
        didSet { UserDefaults.standard.set(accountRegistrationEnabled, forKey: Keys.accountRegistration) }
    }

    @Published var nutritionGapEnabled: Bool = true {
        didSet { UserDefaults.standard.set(nutritionGapEnabled, forKey: Keys.nutritionGap) }
    }

    @Published var trainingDayEnabled: Bool = true {
        didSet { UserDefaults.standard.set(trainingDayEnabled, forKey: Keys.trainingDay) }
    }

    @Published var restDayEnabled: Bool = true {
        didSet { UserDefaults.standard.set(restDayEnabled, forKey: Keys.restDay) }
    }

    @Published var engagementEnabled: Bool = true {
        didSet { UserDefaults.standard.set(engagementEnabled, forKey: Keys.engagement) }
    }

    /// C2 feature: readiness-aware training alerts. When false, the daily
    /// pre-training advisory (driven by `ReadinessAwareTrainingObserver`) is
    /// fully suppressed — no push, no in-app banner. Default true.
    @Published var readinessAwareAlertsEnabled: Bool = true {
        didSet { UserDefaults.standard.set(readinessAwareAlertsEnabled, forKey: Keys.readinessAware) }
    }

    // MARK: - Init

    init() {
        let defaults = UserDefaults.standard

        // Only override the Swift default if the key has been written before.
        if defaults.object(forKey: Keys.masterEnabled) != nil {
            masterEnabled = defaults.bool(forKey: Keys.masterEnabled)
        }
        if defaults.object(forKey: Keys.dailyCap) != nil {
            dailyCap = defaults.integer(forKey: Keys.dailyCap)
        }
        if defaults.object(forKey: Keys.healthKitConnect) != nil {
            healthKitConnectEnabled = defaults.bool(forKey: Keys.healthKitConnect)
        }
        if defaults.object(forKey: Keys.accountRegistration) != nil {
            accountRegistrationEnabled = defaults.bool(forKey: Keys.accountRegistration)
        }
        if defaults.object(forKey: Keys.nutritionGap) != nil {
            nutritionGapEnabled = defaults.bool(forKey: Keys.nutritionGap)
        }
        if defaults.object(forKey: Keys.trainingDay) != nil {
            trainingDayEnabled = defaults.bool(forKey: Keys.trainingDay)
        }
        if defaults.object(forKey: Keys.restDay) != nil {
            restDayEnabled = defaults.bool(forKey: Keys.restDay)
        }
        if defaults.object(forKey: Keys.engagement) != nil {
            engagementEnabled = defaults.bool(forKey: Keys.engagement)
        }
        if defaults.object(forKey: Keys.readinessAware) != nil {
            readinessAwareAlertsEnabled = defaults.bool(forKey: Keys.readinessAware)
        }
    }

    // MARK: - Convenience

    /// Returns `true` iff the reminder type may fire — both the master switch
    /// AND the per-type toggle must be on. Call sites in `ReminderScheduler`
    /// will use this gate in a follow-up PR.
    func isEnabled(for type: ReminderType) -> Bool {
        guard masterEnabled else { return false }
        switch type {
        case .healthKitConnect:    return healthKitConnectEnabled
        case .accountRegistration: return accountRegistrationEnabled
        case .nutritionGap:        return nutritionGapEnabled
        case .trainingDay:         return trainingDayEnabled
        case .restDay:             return restDayEnabled
        case .engagement:          return engagementEnabled
        }
    }
}
