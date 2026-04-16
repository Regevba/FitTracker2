// Services/Notifications/NotificationService.swift
// Manages UNUserNotificationCenter: authorization, scheduling, cancellation.
// Enforces quiet hours (10 PM – 7 AM) and delegates to NotificationPreferencesStore
// for per-type enable/disable and daily frequency cap.

import Foundation
import UserNotifications
import SwiftUI

// ─────────────────────────────────────────────────────────
// MARK: – Notification Type
// ─────────────────────────────────────────────────────────

enum NotificationType: String, CaseIterable, Sendable {
    case workoutReminder  = "workout_reminder"
    case readinessAlert   = "readiness_alert"
    case recoveryNudge    = "recovery_nudge"
}

// ─────────────────────────────────────────────────────────
// MARK: – Notification Service
// ─────────────────────────────────────────────────────────

@MainActor
final class NotificationService: ObservableObject {

    static let shared = NotificationService()

    @Published var isAuthorized: Bool = false

    private let center = UNUserNotificationCenter.current()
    private let preferences = NotificationPreferencesStore()

    // Quiet hours: 10 PM (22:00) – 7 AM (07:00)
    private let quietHourStart = 22
    private let quietHourEnd   = 7

    // Daily frequency tracking
    private var dailySendDateKey: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return "ft.notification.dailyCount.\(fmt.string(from: Date()))"
    }

    private var todaySendCount: Int {
        UserDefaults.standard.integer(forKey: dailySendDateKey)
    }

    private func incrementDailyCount() {
        UserDefaults.standard.set(todaySendCount + 1, forKey: dailySendDateKey)
    }

    private init() {
        // Check authorization status on init without prompting
        Task {
            await refreshAuthorizationStatus()
        }
    }

    // ── Authorization ────────────────────────────────────

    /// Requests UNUserNotificationCenter authorization (alert + sound + badge).
    /// Updates `isAuthorized` based on the result.
    func requestAuthorization() async {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
        } catch {
            isAuthorized = false
        }
    }

    /// Re-reads the current authorization status without prompting the user.
    func refreshAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }

    // ── Scheduling ───────────────────────────────────────

    /// Schedules a local notification.
    /// - Parameters:
    ///   - type: The `NotificationType` that identifies this notification.
    ///   - content: The `UNMutableNotificationContent` with title/body/category.
    ///   - trigger: A `UNNotificationTrigger` (calendar, time-interval, or location).
    /// Returns immediately if the app is currently inside quiet hours,
    /// the user hasn't authorized, or the service is not authorized.
    func scheduleNotification(
        type: NotificationType,
        content: UNMutableNotificationContent,
        trigger: UNNotificationTrigger
    ) async {
        // C2 fix: check per-type preference before scheduling
        guard isAuthorized else { return }
        guard preferences.isEnabled(for: type) else { return }
        guard !isQuietHour() else { return }

        // C1 fix: enforce daily frequency cap
        guard todaySendCount < preferences.maxDailyNotifications else { return }

        let identifier = "\(type.rawValue)_\(UUID().uuidString)"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
            incrementDailyCount()
        } catch {
            // Scheduling failure is non-fatal; the caller can retry.
        }
    }

    // ── Cancellation ─────────────────────────────────────

    /// Removes all pending and delivered notifications.
    func cancelAll() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    /// Removes all pending notifications matching the given `NotificationType`.
    func cancelByType(_ type: NotificationType) {
        Task {
            let pending = await center.pendingNotificationRequests()
            let ids = pending
                .filter { $0.identifier.hasPrefix(type.rawValue) }
                .map(\.identifier)
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    // ── Quiet hours check ────────────────────────────────

    /// Returns `true` if the current local time is within the quiet-hours window
    /// (10 PM inclusive — 7 AM exclusive).
    func isQuietHour() -> Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= quietHourStart || hour < quietHourEnd
    }
}
