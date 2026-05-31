// Services/Reminders/SmartRemindersConsumerRegistration.swift
// C1 first slice — Smart Reminders ↔ Push v2 deep-link integration
// (L207 backlog: smart-reminders gets adapted to use the v2 platform).
//
// This file registers smart-reminders as ONE consumer of the v2 notification
// platform (NotificationConsumerRegistry). The 6 ReminderType deep-link URLs
// become this consumer's claimed urlPatterns, so:
//
//   • DeepLinkRouter knows "given URL fitme://training, smart-reminders is the
//     owning consumer" — enables future consumer-aware routing logic
//   • Analytics can tag delivered notifications with `consumer_id=smart-reminders`
//     via gateway userInfo flowthrough — enables per-consumer deliverability metrics
//   • Future cross-consumer URL collisions fail-fast at app-init instead of
//     silently mis-routing at delivery time
//
// What's NOT yet wired (separate ~30min follow-up PRs):
//
//   1. ReminderScheduler.scheduleIfAllowed(...) does NOT route through
//      NotificationGateway.dispatch(...) — direct UNUserNotificationCenter
//      calls remain (backlog L207 scope item #1)
//
//   2. ReminderType.deepLink remains an inline-string source of truth.
//      Migrating to DeepLinkRouter registration entries owned by the router
//      is scope item #3.
//
//   3. ReminderNotificationDelegate.didReceive still broadcasts
//      `.fitMeReminderTapped` instead of calling DeepLinkRouter.handle(url:).
//      Scope item #4 picks one (broadcast OR direct call).
//
// Registration is idempotent — re-registering the same consumer ID replaces
// the prior entry. Safe to call from app-init on every launch.

import Foundation

@MainActor
enum SmartRemindersConsumerRegistration {

    /// Stable consumer ID. Avoid changing — referenced by analytics and any
    /// future urlPatterns collision-debug tooling.
    static let consumerID = "smart-reminders"

    /// The smart-reminders consumer descriptor: all 6 ReminderType deep-link
    /// URLs claimed under one consumer ID, primary cap tag = `.standard`
    /// (smart-reminders never fires `.critical` — that's reserved for
    /// readinessAlert which is owned by ReadinessAlertObserver, a different
    /// consumer).
    static func consumer() -> NotificationConsumerRegistry.Consumer {
        NotificationConsumerRegistry.Consumer(
            id: consumerID,
            displayName: "Smart Reminders",
            typeIdentifiers: ReminderType.allCases.map(\.rawValue),
            urlPatterns: ReminderType.allCases.map(\.deepLink),
            primaryCapTag: .standard
        )
    }

    /// Idempotent registration at app-init. Returns `true` on success, `false`
    /// if any URL pattern collides with another consumer's claim (which
    /// should never happen — but `register(_:)` returns false rather than
    /// asserting so we surface it explicitly here).
    @discardableResult
    static func registerAtAppInit() -> Bool {
        NotificationConsumerRegistry.shared.register(consumer())
    }
}
