// Services/Reminders/ReminderScheduler.swift
// Core engine for smart reminders.
// Enforces a global daily cap (3/day), per-type daily cap, per-type lifetime cap,
// and a quiet-hours window (10 PM – 7 AM local time).

import Foundation
import UserNotifications

@MainActor
final class ReminderScheduler: ObservableObject {

    static let shared = ReminderScheduler()

    // ── Constants ────────────────────────────────────────

    private let center           = UNUserNotificationCenter.current()
    private let maxDailyGlobal   = 3
    private let quietHourStart   = 22   // 10 PM — inclusive
    private let quietHourEnd     = 7    // 7 AM  — exclusive
    private let minIntervalHours = 4    // minimum gap between any two reminders

    // ── Published state ──────────────────────────────────

    @Published var scheduledCount: Int = 0

    // ── Init ─────────────────────────────────────────────

    private init() {}

    // ── Public API ───────────────────────────────────────

    /// Schedules a reminder notification if all frequency and quiet-hour guards
    /// pass.  Silently no-ops when any guard rejects the request.
    ///
    /// - Parameters:
    ///   - type:         The `ReminderType` that categorises this notification.
    ///   - body:         The notification body string (personalised by the caller).
    ///   - delayMinutes: How many minutes from now the notification should fire.
    ///                   Pass `0` to fire after a 1-second delay (effectively
    ///                   immediate, required by UNTimeIntervalNotificationTrigger).
    func scheduleIfAllowed(
        type: ReminderType,
        body: String,
        delayMinutes: Int = 0
    ) async {
        // 1. Quiet-hours guard
        guard !isQuietHour() else { return }

        // 2. Global daily cap
        let pending = await pendingCount()
        guard pending < maxDailyGlobal else { return }

        // 3. Per-type daily cap (resets at midnight via key naming)
        guard !dailyCapReached(for: type) else { return }

        // 4. Per-type lifetime cap
        if let maxLifetime = type.maxLifetime {
            let sent = lifetimeSentCount(for: type)
            guard sent < maxLifetime else { return }
        }

        // 5. Minimum interval since last reminder of any type
        guard minimumIntervalElapsed() else { return }

        // Build content
        let content = UNMutableNotificationContent()
        content.title = type.title
        content.body  = body
        content.sound = .default
        content.userInfo = [
            "type":     type.rawValue,
            "deepLink": type.deepLink
        ]

        // Build trigger
        let interval = delayMinutes > 0
            ? TimeInterval(delayMinutes * 60)
            : TimeInterval(1)
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: interval,
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "\(type.rawValue)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
            recordScheduled(for: type)
            scheduledCount += 1
        } catch {
            // Notifications are best-effort; silent failure is intentional.
        }
    }

    /// Removes all pending smart-reminder notification requests and resets
    /// the in-memory scheduled count.
    func cancelAll() {
        center.removeAllPendingNotificationRequests()
        scheduledCount = 0
    }

    /// Removes all pending notifications belonging to a specific `ReminderType`.
    func cancel(type: ReminderType) {
        Task {
            let pending = await center.pendingNotificationRequests()
            let ids = pending
                .filter { $0.identifier.hasPrefix(type.rawValue) }
                .map(\.identifier)
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    // ── Private helpers ──────────────────────────────────

    private func isQuietHour() -> Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= quietHourStart || hour < quietHourEnd
    }

    private func pendingCount() async -> Int {
        await center.pendingNotificationRequests().count
    }

    // MARK: Daily cap (per-type, resets at midnight)

    private func dailyCapKey(for type: ReminderType) -> String {
        let dateStamp = ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: Date()))
        return "ft.reminder.\(type.rawValue).daily.\(dateStamp)"
    }

    private func dailyCapReached(for type: ReminderType) -> Bool {
        let count = UserDefaults.standard.integer(forKey: dailyCapKey(for: type))
        return count >= type.maxPerDay
    }

    // MARK: Lifetime cap (per-type)

    private func lifetimeSentCount(for type: ReminderType) -> Int {
        UserDefaults.standard.integer(forKey: "ft.reminder.\(type.rawValue).sentCount")
    }

    // MARK: Minimum interval

    private func lastScheduledKey() -> String { "ft.reminder.lastScheduledDate" }

    private func minimumIntervalElapsed() -> Bool {
        guard let last = UserDefaults.standard.object(forKey: lastScheduledKey()) as? Date else {
            return true
        }
        let elapsed = Date().timeIntervalSince(last) / 3600
        return elapsed >= Double(minIntervalHours)
    }

    // MARK: Record a successful schedule

    private func recordScheduled(for type: ReminderType) {
        let defaults = UserDefaults.standard

        // Daily count
        let dailyKey = dailyCapKey(for: type)
        defaults.set(defaults.integer(forKey: dailyKey) + 1, forKey: dailyKey)

        // Lifetime count
        let lifetimeKey = "ft.reminder.\(type.rawValue).sentCount"
        defaults.set(defaults.integer(forKey: lifetimeKey) + 1, forKey: lifetimeKey)

        // Last-scheduled timestamp (for minimum-interval guard)
        defaults.set(Date(), forKey: lastScheduledKey())
    }
}
