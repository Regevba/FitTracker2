// Services/Reminders/TrendAlertObserver.swift
//
// C4 feature: trend-alerts-hrv.
//
// Bridges TrendAlertTrigger's pure-function output into the v2
// NotificationGateway dispatch path. Registers as a THIRD consumer
// alongside ReadinessAlertObserver (score-crossing) and C2's
// ReadinessAwareTrainingObserver (pre-training advisory).
//
// One dispatch per 7-day rolling window (de-dupe via UserDefaults stamp,
// week-keyed). Cap routing: always `.standard` (advisory). Per PRD OQ-4,
// C2 wins the in-app banner slot on training days — the in-app store
// update is gated by C2's store state in AIInsightCard, not here. Push
// fires independently of C2 (separate cap-tag groups).
//
// User-facing opt-out: ReminderPreferencesStore.trendAlertsEnabled
// (default true). When false, evaluate(...) early-returns nil before any
// notification content is built.

import Foundation
import UserNotifications

@MainActor
final class TrendAlertObserver {

    static let shared = TrendAlertObserver()

    /// Consumer registration. Registered with NotificationConsumerRegistry
    /// at app init alongside the C2 observer's registration.
    static let consumerRegistration = NotificationConsumerRegistry.Consumer(
        id: "push-notifications.trendAlert",
        displayName: "Trend Alert",
        typeIdentifiers: ["trendAlert"],
        urlPatterns: ["fitme://nav/home"],
        primaryCapTag: .standard
    )

    private let gateway: NotificationGateway
    weak var analytics: AnalyticsService?

    /// Closure provider for the opt-out preference. Defaults to UserDefaults-
    /// backed read; tests inject a closure returning a fixed value.
    var isFeatureEnabled: () -> Bool = {
        UserDefaults.standard.object(forKey: TrendAlertObserver.optOutKey) as? Bool ?? true
    }

    init(gateway: NotificationGateway = .shared) {
        self.gateway = gateway
    }

    // MARK: - Evaluate + dispatch

    /// Examines today's HRV samples + baseline + floor and dispatches an
    /// advisory if the trigger returns a non-nil context. Idempotent per
    /// 7-day rolling window.
    @discardableResult
    func evaluate(
        hrvSamples: [Double],
        baseline: Double,
        floor: Double,
        sustainedDaysRequired: Int = TrendAlertTrigger.defaultSustainedDaysRequired,
        kind: TrendAlertKind = .hrvSustainedLow,
        now: Date = Date()
    ) async -> NotificationDispatchResult? {

        guard isFeatureEnabled() else { return nil }
        guard !alreadyFiredThisWeek(date: now) else { return nil }

        let context = TrendAlertTrigger.evaluate(
            hrvSamples: hrvSamples,
            baseline: baseline,
            floor: floor,
            sustainedDaysRequired: sustainedDaysRequired,
            kind: kind,
            generatedAt: now
        )

        guard let context else { return nil }

        // Side-channel: push the context into the in-app store BEFORE the
        // notification dispatch — the in-app banner should render even if
        // push permission is denied or capped.
        TrendAlertStore.shared.update(context)

        let content = buildContent(for: context)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)

        let dispatchResult = await gateway.dispatch(
            content: content,
            trigger: trigger,
            consumerID: Self.consumerRegistration.id,
            tag: .standard
        )

        if dispatchResult == .dispatched {
            markFiredThisWeek(date: now)
            analytics?.logReminderScheduled(type: "trendAlert")
        } else if case .suppressed(let reason) = dispatchResult {
            analytics?.logReminderSuppressed(
                type: "trendAlert",
                reason: reason.rawValue
            )
        }

        return dispatchResult
    }

    // MARK: - Content composition

    private func buildContent(for context: TrendAlertContext) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = context.kind.pushTitle
        content.body  = body(for: context)
        content.sound = .default
        content.userInfo = [
            "type": "trendAlert",
            "kind": context.kind.rawValue,
            "sustainedDays": context.sustainedDays,
            "deepLink": "fitme://nav/home",
        ]
        return content
    }

    private func body(for context: TrendAlertContext) -> String {
        switch context.kind {
        case .hrvSustainedLow:
            // Cold-start (Layer 0) vs Layer ≥1 distinction: when floor equals
            // hardFloor exactly, treat as Layer 0 and use cautious copy.
            let isColdStart = context.floor == TrendAlertTrigger.hardFloor
            if isColdStart {
                return "HRV has been low recently. Consider extra recovery."
            }
            return "HRV has been below your baseline for \(context.sustainedDays) days. Consider extra rest + hydration today."
        }
    }

    // MARK: - De-dupe (UserDefaults-backed, 7-day-window-keyed)

    private static let firedKeyPrefix = "ft.trendAlert.fired."
    static let optOutKey = "ft.trendAlert.enabled"

    /// Week key = ISO week-of-year + year. Same key for any day within
    /// the same ISO week. After the week rolls, the new key allows a
    /// fresh fire (matching PRD §"refireWindow: 7 days").
    private static func weekKey(_ date: Date, calendar: Calendar = .current) -> String {
        var cal = calendar
        cal.firstWeekday = 2 // Monday — ISO 8601
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return "\(firedKeyPrefix)\(comps.yearForWeekOfYear ?? 0).w\(comps.weekOfYear ?? 0)"
    }

    func alreadyFiredThisWeek(date: Date = Date()) -> Bool {
        UserDefaults.standard.bool(forKey: Self.weekKey(date))
    }

    private func markFiredThisWeek(date: Date) {
        UserDefaults.standard.set(true, forKey: Self.weekKey(date))
    }

    // MARK: - Test seam

    #if DEBUG
    func _resetForTesting(date: Date = Date()) {
        UserDefaults.standard.removeObject(forKey: Self.weekKey(date))
        UserDefaults.standard.removeObject(forKey: Self.optOutKey)
    }
    #endif
}
