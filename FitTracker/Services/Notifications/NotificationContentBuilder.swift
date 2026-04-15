// Services/Notifications/NotificationContentBuilder.swift
// Builds UNMutableNotificationContent for each NotificationType.
// Content matches the UX spec (ux-spec.md): titles, bodies, categories,
// deep-link userInfo, and default sound for all three types.

import UserNotifications

struct NotificationContentBuilder {

    // ── T4: Workout Reminder ─────────────────────────────
    /// Builds content for a workout reminder.
    /// - Parameters:
    ///   - dayType: The training day label (e.g. "Push Day", "Leg Day").
    ///   - exerciseCount: Number of exercises in today's session.
    ///   - durationMinutes: Estimated session duration in minutes.
    static func workoutReminder(dayType: String, exerciseCount: Int, durationMinutes: Int) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "Time to train 💪"
        content.body = "\(dayType) · \(exerciseCount) exercises · ~\(durationMinutes)m"
        content.sound = .default
        content.categoryIdentifier = "workout"
        content.userInfo = ["deepLink": "fitme://training"]
        return content
    }

    // ── T5: Readiness Alert ──────────────────────────────
    /// Builds content for a low-readiness alert.
    /// - Parameter score: The user's readiness score (0–100).
    static func readinessAlert(score: Int) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "Your readiness is low today"
        content.body = "Score: \(score)/100. Consider a lighter session or rest day."
        content.sound = .default
        content.categoryIdentifier = "readiness"
        content.userInfo = ["deepLink": "fitme://home"]
        return content
    }

    // ── T6: Recovery Nudge ───────────────────────────────
    /// Builds content for a recovery nudge after consecutive training days.
    /// - Parameter consecutiveDays: Number of consecutive days trained.
    static func recoveryNudge(consecutiveDays: Int) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "Recovery check-in 🧘"
        content.body = "You've trained \(consecutiveDays) days straight. Your body may need a break."
        content.sound = .default
        content.categoryIdentifier = "recovery"
        content.userInfo = ["deepLink": "fitme://home"]
        return content
    }
}
