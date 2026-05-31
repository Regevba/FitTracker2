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

    /// Deep-link URL for this reminder type, delegated to `DeepLinkRouter`
    /// which now owns the smart-reminders URL registry (C1 item #3,
    /// L207 backlog). Behavior preserved — the same 6 URLs are returned —
    /// but the source of truth moved so DeepLinkRouter has full ownership
    /// of every consumer's URL space.
    var deepLink: String {
        DeepLinkRouter.deepLinkURL(forReminderTypeRawValue: self.rawValue)
    }

    // ── Fire-time defaults (smart-reminders-behavioral-learning PR 1) ──
    //
    // The existing trigger evaluators in ReminderTriggers.swift gate firing
    // on inline hour-of-day checks (nutrition gap >= 16, training day >= 10).
    // This property exposes those static fire-time defaults as a single
    // source of truth so the Bayesian behavioral-learning layer (PR 1+)
    // can use them as its prior centre without re-deriving the values.

    /// Static default fire hour (local time) for this reminder type.
    /// Matches the editorial defaults baked into ReminderTriggers.swift.
    /// Used as the centre of `defaultPriorDistribution`.
    var defaultFireHour: Int {
        switch self {
        case .nutritionGap:        return 16
        case .trainingDay:         return 10
        case .restDay:             return 8
        case .healthKitConnect:    return 11
        case .accountRegistration: return 14
        case .engagement:          return 18
        }
    }

    /// Tight bell curve over the 24 hour-of-day buckets, centred on
    /// `defaultFireHour`. Used as the Bayesian prior fallback when the
    /// cohort prior cache is cold.
    /// Sums to 1.0. σ = 1.5 hours (gives ~80% of mass within ±2 hours
    /// of centre).
    var defaultPriorDistribution: [Int: Double] {
        let centre = Double(defaultFireHour)
        let sigma  = 1.5
        var raw: [Int: Double] = [:]
        for h in 0..<24 {
            let dx = Double(h) - centre
            raw[h] = exp(-(dx * dx) / (2 * sigma * sigma))
        }
        let total = raw.values.reduce(0, +)
        return raw.mapValues { $0 / total }
    }
}
