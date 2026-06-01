// Services/Reminders/ReadinessAwareAlertStore.swift
//
// C2 feature: readiness-aware-training-alert (parent: smart-reminders).
//
// Holds the latest in-app ReadinessAlertContext so the AIInsightCard +
// AIIntelligenceSheet can surface the daily readiness-aware advisory.
// Updated by ReadinessAwareTrainingObserver.evaluate(...) when a non-nil
// context is produced (regardless of whether the push notification
// dispatched — the in-app surface should show even if push permission
// is off).
//
// One value per local day. Stale contexts (generatedAt > 24h ago) are
// treated as nil by callers via the `current(at:)` accessor.

import Foundation
import Combine

@MainActor
final class ReadinessAwareAlertStore: ObservableObject {

    static let shared = ReadinessAwareAlertStore()

    @Published private(set) var latest: ReadinessAlertContext?

    init(latest: ReadinessAlertContext? = nil) {
        self.latest = latest
    }

    /// Update the surfaced context. Callers should pass non-nil contexts
    /// only when an alert recommendation was generated.
    func update(_ context: ReadinessAlertContext?) {
        latest = context
    }

    /// Returns the latest context only if it was generated within the same
    /// local day as `now`. Returns nil for cross-day staleness.
    func current(at now: Date = Date(), calendar: Calendar = .current) -> ReadinessAlertContext? {
        guard let latest else { return nil }
        let sameDay = calendar.isDate(latest.generatedAt, inSameDayAs: now)
        return sameDay ? latest : nil
    }

    /// Clears the surfaced context. Called when the user accepts a CTA so
    /// the card returns to the default AIOrchestrator-driven content.
    func clear() {
        latest = nil
    }
}
