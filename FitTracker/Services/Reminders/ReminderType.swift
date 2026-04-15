// Services/Reminders/ReminderType.swift
// Defines the set of smart reminder types, their display metadata,
// frequency caps, and deep-link destinations.

import Foundation

enum ReminderType: String, CaseIterable, Codable {
    case healthKitConnect    = "healthkit_connect"
    case accountRegistration = "account_registration"
    case nutritionGap        = "nutrition_gap"
    case trainingDay         = "training_day"
    case restDay             = "rest_day"
    case engagement          = "engagement"

    // ── Display ──────────────────────────────────────────

    var title: String {
        switch self {
        case .healthKitConnect:    "Unlock your readiness score ❤️"
        case .accountRegistration: "Your data deserves a backup ☁️"
        case .nutritionGap:        "Protein check-in 🥩"
        case .trainingDay:         "Time to train 💪"
        case .restDay:             "Rest day — recover well 🧘"
        case .engagement:          "Miss you! 👋"
        }
    }

    // ── Frequency caps ───────────────────────────────────

    /// Maximum number of times this type may fire in a single calendar day.
    var maxPerDay: Int { 1 }

    /// Maximum number of times this type may ever fire (nil = unlimited).
    var maxLifetime: Int? {
        switch self {
        case .healthKitConnect, .accountRegistration, .engagement: 3
        default: nil
        }
    }

    // ── Routing ──────────────────────────────────────────

    var deepLink: String {
        switch self {
        case .healthKitConnect:    "fitme://settings/health"
        case .accountRegistration: "fitme://auth"
        case .nutritionGap:        "fitme://nutrition"
        case .trainingDay:         "fitme://training"
        case .restDay:             "fitme://home"
        case .engagement:          "fitme://home"
        }
    }
}
