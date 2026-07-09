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

    // ── Analytics ────────────────────────────────────────
    // Set by FitTrackerApp at launch. When nil (test harnesses without
    // analytics), instrumentation no-ops without affecting scheduling.
    weak var analytics: AnalyticsService?

    // ── User preferences (v2) ────────────────────────────
    // FIT-210: set by FitTrackerApp at launch to the app-level v2
    // ReminderPreferencesStore. When nil (test harnesses without the store),
    // user preferences don't gate — the per-type/lifetime caps + gateway still
    // apply. Weak to avoid a retain cycle (the app owns the @StateObject).
    weak var reminderPreferences: ReminderPreferencesStore?

    // ── Init ─────────────────────────────────────────────

    private init() {}

    // ── Public API ───────────────────────────────────────

    /// Schedules a reminder notification if all smart-reminder guards pass AND
    /// the v2 NotificationGateway accepts the dispatch.
    ///
    /// **Guard ownership split (C1 item #1, 2026-05-31):**
    ///
    /// - Smart-reminders owns: per-type daily cap, per-type lifetime cap, minimum
    ///   interval between any two reminders. These are smart-reminders' policy and
    ///   the gateway has no concept of `ReminderType`.
    /// - `NotificationGateway` owns: authorization, quiet hours, global standard-tag
    ///   cap (3/day). Routing through the gateway means smart-reminders + future
    ///   consumers (ReadinessAlertObserver, etc.) share one accurate cap counter.
    ///
    /// Silently no-ops when any guard rejects the request. Analytics events are
    /// emitted at every gate so downstream funnel analysis can attribute drop-off.
    ///
    /// - Parameters:
    ///   - type:         The `ReminderType` that categorises this notification.
    ///   - body:         The notification body string (personalised by the caller).
    ///   - delayMinutes: How many minutes from now the notification should fire.
    ///                   Pass `0` to fire after a 1-second delay (required by
    ///                   `UNTimeIntervalNotificationTrigger`).
    func scheduleIfAllowed(
        type: ReminderType,
        body: String,
        delayMinutes: Int = 0
    ) async {
        // 0. User preferences (v2 settings screen — FIT-210): master switch +
        //    per-type toggle + the user-configurable daily cap. `isEnabled(for:)`
        //    maps 1:1 onto ReminderType (master AND per-type must be on).
        //    Gates BEFORE the internal caps so a user opt-out short-circuits.
        if let prefs = reminderPreferences {
            guard prefs.isEnabled(for: type) else {
                analytics?.logReminderSuppressed(type: type.rawValue, reason: "user_disabled")
                return
            }
            guard todaySendCount() < prefs.dailyCap else {
                analytics?.logReminderSuppressed(type: type.rawValue, reason: "user_daily_cap")
                return
            }
        }

        // 1. Per-type daily cap (resets at midnight via key naming)
        guard !dailyCapReached(for: type) else {
            analytics?.logReminderSuppressed(type: type.rawValue, reason: "per_type_daily_cap")
            return
        }

        // 2. Per-type lifetime cap
        if let maxLifetime = type.maxLifetime {
            let sent = lifetimeSentCount(for: type)
            guard sent < maxLifetime else {
                analytics?.logReminderSuppressed(type: type.rawValue, reason: "lifetime_cap")
                analytics?.logReminderDisabled(type: type.rawValue, reason: "lifetime_cap_reached")
                return
            }
        }

        // 3. Minimum interval since last reminder of any type
        guard minimumIntervalElapsed() else {
            analytics?.logReminderSuppressed(type: type.rawValue, reason: "min_interval")
            return
        }

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

        // Route through the v2 NotificationGateway (auth + quiet hours +
        // standard-tag global cap all enforced there).
        let result = await NotificationGateway.shared.dispatch(
            content: content,
            trigger: trigger,
            consumerID: SmartRemindersConsumerRegistration.consumerID,
            tag: .standard
        )

        switch result {
        case .dispatched:
            recordScheduled(for: type)
            incrementDailyCount()
            scheduledCount += 1
            analytics?.logReminderScheduled(type: type.rawValue)
        case .denied_unauthorized:
            analytics?.logReminderSuppressed(type: type.rawValue, reason: "system_unauthorized")
        case .suppressed(let reason):
            // Map gateway suppression reasons to existing smart-reminder analytics
            // taxonomy where possible; otherwise emit the gateway's raw reason.
            let mapped: String
            switch reason {
            case .quiet_hours:       mapped = "quiet_hours"
            case .standard_cap:      mapped = "global_daily_cap"
            case .critical_cap:      mapped = "critical_cap"  // shouldn't fire for smart-reminders (tag=.standard)
            case .scheduling_failed: mapped = "system_add_failed"
            }
            analytics?.logReminderSuppressed(type: type.rawValue, reason: mapped)
        }
    }

    /// Removes all pending smart-reminder notification requests and resets
    /// the in-memory scheduled count.
    func cancelAll() {
        center.removeAllPendingNotificationRequests()
        scheduledCount = 0
        analytics?.logReminderDisabled(type: "all", reason: "cancel_all")
    }

    /// Removes all pending notifications belonging to a specific `ReminderType`.
    func cancel(type: ReminderType) {
        analytics?.logReminderDisabled(type: type.rawValue, reason: "cancel_type")
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

    // MARK: Global daily send count (actual sends, resets at midnight)

    private func dateKey() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: Date())
    }

    private func todaySendCount() -> Int {
        let key = "ft.reminder.dailyCount.\(dateKey())"
        return UserDefaults.standard.integer(forKey: key)
    }

    private func incrementDailyCount() {
        let key = "ft.reminder.dailyCount.\(dateKey())"
        UserDefaults.standard.set(todaySendCount() + 1, forKey: key)
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
