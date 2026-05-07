// Services/Notifications/ReadinessAlertObserver.swift
//
// Notification consumer for the readiness-alert dispatch path. Bridges
// ReadinessEngine score output into the push-notifications-v2 platform
// (NotificationGateway) — the only NEW notification type added by v2.
//
// Owned by: push-notifications-v2 (FIT-23). Registers itself as a consumer
// of NotificationConsumerRegistry at app-init time (T6 wiring).
//
// Trigger conditions (PRD PN-9 + ux-spec §2.4):
//   - Score crosses ≥ 80 (high direction) OR ≤ 40 (low direction)
//   - Confidence: ≥ medium (i.e. ≥ 2 HK signals contributed within last 6h —
//     ReadinessEngine maps signal count to .low/.medium/.high; we accept .medium+)
//   - De-dupe: one fire per direction per local day; same-direction-same-day suppressed
//
// Cap routing (PRD PN-10):
//   - High direction → .standard tag (counts toward 3/day global cap)
//   - Low direction + workout scheduled today → .critical tag (separate 1/day bucket;
//     pre-empts global cap so a critical readiness signal never gets capped out)
//   - Low direction + no workout today → .standard tag (pre-emption gated on workout)
//
// `evaluate(...)` is called externally — typically on app foreground, after a
// HealthKit data update, or after a manual readiness compute. The engine is
// synchronous-compute (not a Combine publisher), so this observer is invoked
// imperatively rather than via subscription.

import Foundation
import UserNotifications

@MainActor
final class ReadinessAlertObserver {

    static let shared = ReadinessAlertObserver()

    /// Consumer registration. Registered with NotificationConsumerRegistry at app init.
    static let consumerRegistration = NotificationConsumerRegistry.Consumer(
        id: "push-notifications.readinessAlert",
        displayName: "Readiness Alert",
        typeIdentifiers: ["readinessAlert"],
        urlPatterns: ["fitme://nav/home"],
        primaryCapTag: .critical
    )

    private let gateway: NotificationGateway
    weak var analytics: AnalyticsService?

    /// Predicate: returns `true` if a workout is scheduled for today's local date.
    /// Defaults to `false` if not set (consumer of v2 platform may wire a real
    /// implementation in FitTrackerApp at T6 — e.g. checking TrainingPlan.todayDayType
    /// against `.rest`).
    var isWorkoutScheduledToday: () -> Bool = { false }

    private let highThreshold = 80
    private let lowThreshold = 40

    enum Direction: String {
        case high
        case low
    }

    init(gateway: NotificationGateway = .shared) {
        self.gateway = gateway
    }

    // MARK: - Evaluate + dispatch

    /// Examines a readiness result and dispatches an alert if all gates pass.
    /// Returns the dispatch result, or `nil` if the score didn't cross either threshold.
    @discardableResult
    func evaluate(_ result: ReadinessResult) async -> NotificationDispatchResult? {
        guard let direction = direction(forScore: result.overallScore) else { return nil }

        // Confidence gate: require ≥ .medium (2+ signals contributed within 6h).
        // ReadinessEngine maps signal count → confidence, so we use that derived value.
        guard isAcceptableConfidence(result.confidence) else { return nil }

        // De-dupe gate: same direction same day = suppressed
        guard !alreadyFiredToday(direction: direction) else { return nil }

        // Build content
        let content = buildContent(score: result.overallScore, direction: direction)

        // Trigger: fire-after-1-second (effectively immediate; UNTimeIntervalNotificationTrigger
        // requires a positive interval). Caller schedules at the moment the score becomes
        // available, so a 1s delay is acceptable.
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)

        // Cap routing (PRD PN-10)
        let tag: NotificationTag = (direction == .low && isWorkoutScheduledToday()) ? .critical : .standard

        let dispatchResult = await gateway.dispatch(
            content: content,
            trigger: trigger,
            consumerID: Self.consumerRegistration.id,
            tag: tag
        )

        // On successful dispatch, mark today's direction as fired (de-dupe stamp)
        if dispatchResult == .dispatched {
            markFiredToday(direction: direction)
            analytics?.logReminderScheduled(type: "readinessAlert")
        } else if case .suppressed(let reason) = dispatchResult {
            analytics?.logReminderSuppressed(type: "readinessAlert", reason: reason.rawValue)
        }

        return dispatchResult
    }

    // MARK: - Threshold + confidence gates

    private func direction(forScore score: Int) -> Direction? {
        if score >= highThreshold { return .high }
        if score <= lowThreshold { return .low }
        return nil
    }

    private func isAcceptableConfidence(_ confidence: ReadinessConfidence) -> Bool {
        switch confidence {
        case .low:           return false
        case .medium, .high: return true
        }
    }

    // MARK: - Content composition

    private func buildContent(score: Int, direction: Direction) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        switch direction {
        case .high:
            content.title = "You're ready"
            content.body  = "Readiness \(score)/100. Good conditions for a hard session today."
        case .low:
            content.title = "Take it easy today"
            content.body  = "Readiness \(score)/100. Consider a light session or rest."
        }
        content.sound = .default
        content.userInfo = [
            "type": "readinessAlert",
            "direction": direction.rawValue,
            "deepLink": "fitme://nav/home",
        ]
        return content
    }

    // MARK: - De-dupe (UserDefaults-backed, day-keyed per direction)

    private static let firedKeyPrefix = "ft.readinessAlert.fired."

    private static func todayKey(_ direction: Direction, date: Date = Date()) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return "\(firedKeyPrefix)\(direction.rawValue).\(fmt.string(from: date))"
    }

    func alreadyFiredToday(direction: Direction, date: Date = Date()) -> Bool {
        UserDefaults.standard.bool(forKey: Self.todayKey(direction, date: date))
    }

    private func markFiredToday(direction: Direction, date: Date = Date()) {
        UserDefaults.standard.set(true, forKey: Self.todayKey(direction, date: date))
    }

    // MARK: - Test seam

    #if DEBUG
    /// Resets today's de-dupe flags. Test-only.
    func _resetForTesting() {
        UserDefaults.standard.removeObject(forKey: Self.todayKey(.high))
        UserDefaults.standard.removeObject(forKey: Self.todayKey(.low))
    }
    #endif
}
