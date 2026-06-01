// Services/Reminders/TrendAlertStore.swift
//
// C4 feature: trend-alerts-hrv.
//
// Holds the latest in-app TrendAlertContext so the AIInsightCard +
// AIIntelligenceSheet can surface the sustained-trend advisory. Updated
// by TrendAlertObserver.evaluate(...) when a non-nil context is produced
// (regardless of whether the push notification dispatched — the in-app
// surface should show even if push permission is off).
//
// One value per local day. Stale contexts (generatedAt > 24h ago) are
// treated as nil by the `current(at:)` accessor.
//
// Mirrors C2's ReadinessAwareAlertStore exactly. Both stores coexist as
// @EnvironmentObject members of the view hierarchy.

import Foundation
import Combine

@MainActor
final class TrendAlertStore: ObservableObject {

    static let shared = TrendAlertStore()

    @Published private(set) var latest: TrendAlertContext?

    init(latest: TrendAlertContext? = nil) {
        self.latest = latest
    }

    /// Update the surfaced context. Callers should pass non-nil contexts
    /// only when the trigger has produced one.
    func update(_ context: TrendAlertContext?) {
        latest = context
    }

    /// Returns the latest context only if it was generated within the
    /// same local day as `now`. Returns nil for cross-day staleness.
    func current(at now: Date = Date(), calendar: Calendar = .current) -> TrendAlertContext? {
        guard let latest else { return nil }
        let sameDay = calendar.isDate(latest.generatedAt, inSameDayAs: now)
        return sameDay ? latest : nil
    }

    /// Clears the surfaced context. Called when the user picks the
    /// feedback affordance OR the AIInsightCard banner is dismissed.
    func clear() {
        latest = nil
    }
}
