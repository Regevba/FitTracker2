// Services/Notifications/NotificationGateway.swift
//
// Platform layer for FitMe notifications. Single authorization wrapper, single
// dispatch surface, single cap-audit point for all notification consumers
// (smart-reminders, ReadinessAlertObserver, future training-plan / marketing-APNs /
// GDPR exports).
//
// Owned by: push-notifications-v2 (FIT-23). Replaces the v1 NotificationService.swift
// (now HISTORICAL). Smart-reminders' ReminderScheduler.scheduleIfAllowed(...) routes
// through this gateway via the paired backlog enhancement.
//
// Cap model (PRD §"Notification Types — Detail"):
//   - Standard bucket: 3 dispatches per local day total (matches smart-reminders'
//     pre-existing global cap). Counts everything except `.critical` tag.
//   - Critical bucket: 1 dispatch per local day (readinessAlert specifically).
//     Independent of standard bucket — bypasses standard cap when reached.
//
// Quiet hours: 22:00–07:00 local time. Inherited from smart-reminders'
// ReminderScheduler. Critical-tag dispatches are NOT exempted from quiet hours.

import Foundation
import UserNotifications
import SwiftUI

// MARK: - Public types

/// Tag indicating which cap bucket a dispatch counts toward.
/// Consumers choose `.critical` only for genuinely critical dispatches (readinessAlert
/// when readiness < 40 AND a workout is scheduled today, per PRD PN-10).
enum NotificationTag: String, Sendable {
    case standard
    case critical
}

/// Result of a `dispatch(...)` call. Consumers can branch on this to log analytics
/// or retry; the gateway itself does not retry.
enum NotificationDispatchResult: Sendable, Equatable {
    case dispatched
    case denied_unauthorized
    case suppressed(reason: NotificationSuppressionReason)
}

enum NotificationSuppressionReason: String, Sendable {
    case quiet_hours
    case standard_cap
    case critical_cap
    case scheduling_failed
}

// MARK: - Gateway

@MainActor
final class NotificationGateway: ObservableObject {

    static let shared = NotificationGateway()

    @Published var isAuthorized: Bool = false

    private let center = UNUserNotificationCenter.current()

    // Quiet hours (matches smart-reminders ReminderScheduler exactly)
    private let quietHourStart = 22 // inclusive
    private let quietHourEnd = 7    // exclusive

    private let standardCapPerDay = 3
    private let criticalCapPerDay = 1

    // MARK: Init

    private init() {
        Task { await refreshAuthorizationStatus() }
    }

    // MARK: Authorization

    /// Triggers the OS permission dialog. After return, `isAuthorized` reflects the
    /// user's choice. Idempotent if already granted (Apple's API short-circuits to
    /// the cached state).
    func requestAuthorization() async {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
        } catch {
            isAuthorized = false
        }
    }

    /// Re-reads the system authorization state without prompting. Call on app
    /// foreground in case the user toggled notifications in iOS Settings.
    func refreshAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }

    // MARK: Dispatch

    /// Single dispatch surface for all notification consumers.
    ///
    /// Consumers (smart-reminders' ReminderScheduler, ReadinessAlertObserver,
    /// future modules) call this instead of `UNUserNotificationCenter.current().add(_:)`
    /// directly. The gateway enforces auth + quiet hours + cap audit.
    ///
    /// - Parameters:
    ///   - content: The notification body. Caller composes title/subtitle/body/userInfo.
    ///   - trigger: Calendar/time-interval/etc trigger.
    ///   - consumerID: Caller-owned identifier for cancel-by-consumer + analytics
    ///                 attribution (e.g. "smart-reminders.trainingDay").
    ///   - tag: Cap bucket. `.standard` counts toward 3/day global; `.critical`
    ///          uses a separate 1/day bucket independent of the standard cap.
    func dispatch(
        content: UNNotificationContent,
        trigger: UNNotificationTrigger,
        consumerID: String,
        tag: NotificationTag = .standard
    ) async -> NotificationDispatchResult {

        guard isAuthorized else { return .denied_unauthorized }
        guard !isQuietHour() else { return .suppressed(reason: .quiet_hours) }

        switch tag {
        case .standard:
            guard standardCount() < standardCapPerDay else {
                return .suppressed(reason: .standard_cap)
            }
        case .critical:
            guard criticalCount() < criticalCapPerDay else {
                return .suppressed(reason: .critical_cap)
            }
        }

        let identifier = "\(consumerID).\(tag.rawValue).\(UUID().uuidString)"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
            increment(tag: tag)
            return .dispatched
        } catch {
            return .suppressed(reason: .scheduling_failed)
        }
    }

    // MARK: Cancellation

    /// Removes all pending and delivered notifications across all consumers. Use
    /// sparingly — typically only on sign-out or test-suite cleanup.
    func cancelAll() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    /// Removes pending notifications for a specific consumer. Identifiers are
    /// scoped by `"<consumerID>."` prefix.
    func cancel(consumerID: String) {
        Task {
            let pending = await center.pendingNotificationRequests()
            let prefix = "\(consumerID)."
            let ids = pending
                .filter { $0.identifier.hasPrefix(prefix) }
                .map(\.identifier)
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    // MARK: Quiet hours

    /// Returns `true` if the local time is in the 22:00–07:00 window (22:00 inclusive,
    /// 07:00 exclusive). Critical-tagged dispatches are NOT exempted.
    func isQuietHour(at date: Date = Date()) -> Bool {
        let hour = Calendar.current.component(.hour, from: date)
        return hour >= quietHourStart || hour < quietHourEnd
    }

    // MARK: - Cap counters (UserDefaults-backed, day-keyed)

    private static let standardKeyPrefix = "ft.notification.gateway.standardCount."
    private static let criticalKeyPrefix = "ft.notification.gateway.criticalCount."

    private static func todayKey(_ prefix: String, date: Date = Date()) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return "\(prefix)\(fmt.string(from: date))"
    }

    func standardCount(at date: Date = Date()) -> Int {
        UserDefaults.standard.integer(forKey: Self.todayKey(Self.standardKeyPrefix, date: date))
    }

    func criticalCount(at date: Date = Date()) -> Int {
        UserDefaults.standard.integer(forKey: Self.todayKey(Self.criticalKeyPrefix, date: date))
    }

    private func increment(tag: NotificationTag) {
        let prefix = (tag == .critical) ? Self.criticalKeyPrefix : Self.standardKeyPrefix
        let key = Self.todayKey(prefix)
        let next = UserDefaults.standard.integer(forKey: key) + 1
        UserDefaults.standard.set(next, forKey: key)
    }

    // MARK: - Test seam

    /// Resets today's cap counters. Test-only; UserDefaults is the source of truth in
    /// production. Marked `internal` (default) so XCTest can call it; not exposed via
    /// `static let shared` for safety.
    #if DEBUG
    func _resetCountsForTesting() {
        UserDefaults.standard.removeObject(forKey: Self.todayKey(Self.standardKeyPrefix))
        UserDefaults.standard.removeObject(forKey: Self.todayKey(Self.criticalKeyPrefix))
    }
    #endif
}
