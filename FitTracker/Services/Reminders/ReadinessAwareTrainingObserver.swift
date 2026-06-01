// Services/Reminders/ReadinessAwareTrainingObserver.swift
//
// C2 feature: readiness-aware-training-alert (parent: smart-reminders).
//
// Bridges ReadinessAwareTrainingTrigger's pure-function recommendation into
// the v2 NotificationGateway dispatch path. Registers as a NEW consumer
// alongside (not replacing) ReadinessAlertObserver — that observer fires on
// score-crossing events; this one fires daily at the user's learned training
// start time (T-30min) regardless of recent crossings.
//
// One dispatch per local day (de-dupe via UserDefaults stamp, day-keyed).
//
// Cap routing: always `.standard` (advisory; never pre-empts cap). Critical
// signal pathway remains ReadinessAlertObserver's exclusive responsibility.
//
// User-facing opt-out: ReminderPreferencesStore.readinessAwareAlertsEnabled
// (default true). When false, evaluate(...) early-returns nil before any
// notification is built.

import Foundation
import UserNotifications

@MainActor
final class ReadinessAwareTrainingObserver {

    static let shared = ReadinessAwareTrainingObserver()

    /// Consumer registration. Registered with NotificationConsumerRegistry
    /// at app init alongside ReadinessAlertObserver's registration.
    static let consumerRegistration = NotificationConsumerRegistry.Consumer(
        id: "push-notifications.readinessAwareTrainingAlert",
        displayName: "Readiness-Aware Training Alert",
        typeIdentifiers: ["readinessAwareTrainingAlert"],
        urlPatterns: ["fitme://nav/home"],
        primaryCapTag: .standard
    )

    private let gateway: NotificationGateway
    weak var analytics: AnalyticsService?

    /// Closure provider for the opt-out preference. Defaults to UserDefaults-
    /// backed read; tests inject a closure returning a fixed value.
    var isFeatureEnabled: () -> Bool = {
        UserDefaults.standard.object(forKey: ReadinessAwareTrainingObserver.optOutKey) as? Bool ?? true
    }

    init(gateway: NotificationGateway = .shared) {
        self.gateway = gateway
    }

    // MARK: - Evaluate + dispatch

    /// Examines today's plan + readiness and dispatches an advisory if the
    /// trigger returns a non-nil recommendation. Idempotent per local day.
    @discardableResult
    func evaluate(
        readinessResult: ReadinessResult,
        scheduledDayType: DayType,
        suggestedRestSwapTarget: DayType?,
        scheduledTrainingTime: Date,
        now: Date = Date()
    ) async -> NotificationDispatchResult? {

        guard isFeatureEnabled() else { return nil }
        guard !alreadyFiredToday(date: now) else { return nil }

        let context = ReadinessAwareTrainingTrigger.evaluate(
            readinessResult: readinessResult,
            scheduledDayType: scheduledDayType,
            suggestedRestSwapTarget: suggestedRestSwapTarget,
            scheduledTrainingTime: scheduledTrainingTime,
            generatedAt: now
        )

        guard let context else { return nil }

        let content = buildContent(for: context)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)

        let dispatchResult = await gateway.dispatch(
            content: content,
            trigger: trigger,
            consumerID: Self.consumerRegistration.id,
            tag: .standard
        )

        if dispatchResult == .dispatched {
            markFiredToday(date: now)
            analytics?.logReminderScheduled(type: "readinessAwareTrainingAlert")
        } else if case .suppressed(let reason) = dispatchResult {
            analytics?.logReminderSuppressed(
                type: "readinessAwareTrainingAlert",
                reason: reason.rawValue
            )
        }

        return dispatchResult
    }

    // MARK: - Content composition

    private func buildContent(for context: ReadinessAlertContext) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = context.recommendation.headline
        content.body  = body(for: context)
        content.sound = .default
        content.userInfo = [
            "type": "readinessAwareTrainingAlert",
            "recommendation": context.recommendation.rawValue,
            "readinessScore": context.readinessScore,
            "drivingComponent": context.drivingComponent.rawValue,
            "deepLink": "fitme://nav/home",
        ]
        return content
    }

    private func body(for context: ReadinessAlertContext) -> String {
        switch context.recommendation {
        case .continueAsPlanned:
            return "Readiness \(context.readinessScore)/100. Conditions look good for today's session."
        case .adaptEasierLoad:
            return "Readiness \(context.readinessScore)/100. Consider a lighter session today."
        case .restDaySwap:
            return "Readiness \(context.readinessScore)/100. Recovery first — swap to a rest day."
        }
    }

    // MARK: - De-dupe (UserDefaults-backed, day-keyed)

    private static let firedKeyPrefix = "ft.readinessAwareTrainingAlert.fired."
    static let optOutKey = "ft.readinessAwareTrainingAlert.enabled"

    private static func todayKey(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return "\(firedKeyPrefix)\(fmt.string(from: date))"
    }

    func alreadyFiredToday(date: Date = Date()) -> Bool {
        UserDefaults.standard.bool(forKey: Self.todayKey(date))
    }

    private func markFiredToday(date: Date) {
        UserDefaults.standard.set(true, forKey: Self.todayKey(date))
    }

    // MARK: - Test seam

    #if DEBUG
    func _resetForTesting(date: Date = Date()) {
        UserDefaults.standard.removeObject(forKey: Self.todayKey(date))
        UserDefaults.standard.removeObject(forKey: Self.optOutKey)
    }
    #endif
}
