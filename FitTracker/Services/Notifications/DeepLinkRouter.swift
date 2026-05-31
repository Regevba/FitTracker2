// Services/Notifications/DeepLinkRouter.swift
//
// Single entry point for all `fitme://...` URLs in the app. Replaces the
// fragmented surfaces that existed before push-notifications-v2:
//   - Auth (`fitme://reset-password`) had its own dedicated `.onOpenURL` handler
//   - v1 `DeepLinkHandler.targetTab(_:)` was 14 LOC of dead code (zero callers)
//   - Smart-reminders broadcast `.fitMeReminderTapped` via NotificationCenter;
//     this router subscribes in init() and forwards to handle(url:source:) so
//     reminder taps no longer drop silently (E-5 wiring, shipped 2026-05-24)
//
// Owned by: push-notifications-v2 (FIT-23).
//
// URL grammar (nested verb-noun, per PRD PN-7 / ux-spec §6.3):
//   fitme://nav/{tab}            → .navigateToTab(AppTab)
//   fitme://action/{action}      → .presentSheet(SheetIdentifier)
//   fitme://auth/{flow}          → .authFlow(URL) — forwarded to SignInService
//   fitme://settings/{section}   → .settingsSection(SettingsSection)
//
// SwiftUI root subscribes to `pendingDeepLink` via `.onChange(of:)` and emits
// the action. Cold-start safe: the router holds `pendingDeepLink` until a
// subscriber consumes it.
//
// Idempotency: same (url, source) within 200ms is a no-op (prevents
// notification-tap + .onOpenURL race).

import Foundation
import SwiftUI

// MARK: - Action variants

enum DeepLinkAction: Equatable {
    case navigateToTab(AppTab)
    case presentSheet(SheetIdentifier)
    case authFlow(URL)
    case settingsSection(SettingsSection)
}

enum SheetIdentifier: String, Equatable {
    case logMeal     = "log-meal"
    case logWorkout  = "log-workout"
    case logBiometric = "log-biometric"
}

enum SettingsSection: String, Equatable {
    case health      = "health"
    case dataExport  = "data-export"
    case account     = "account"
    case notifications = "notifications"
}

// MARK: - Source

enum DeepLinkSource: String, Sendable {
    case notification
    case url
    case programmatic
}

// MARK: - Outcome (analytics)

enum DeepLinkOutcome: String, Sendable {
    case succeeded
    case failed_no_pattern_match
    case failed_navigation
}

// MARK: - Router

@MainActor
final class DeepLinkRouter: ObservableObject {

    static let shared = DeepLinkRouter()

    /// Subscribers (SwiftUI root via `.onChange(of:)`) observe this and emit
    /// the action when set. Subscriber must clear via `consume()` after handling.
    @Published var pendingDeepLink: DeepLinkAction?

    /// Optional analytics surface — nil in tests so the router is hermetic.
    /// Set by FitTrackerApp at init.
    weak var analytics: AnalyticsService?

    /// Optional auth bridge — `.authFlow` URLs are forwarded here.
    /// Set by FitTrackerApp at init.
    var authHandler: ((URL) async -> Void)?

    /// Tracks the most recent (url, source) call for idempotency dedup.
    private var lastHandled: (url: String, source: DeepLinkSource, at: Date)?

    private let dedupeWindow: TimeInterval = 0.2 // 200ms

    private init() {
        subscribeToReminderTaps()
    }

    /// E-5 wiring (cadence-followups, shipped 2026-05-24): subscribe to the
    /// `.fitMeReminderTapped` Notification broadcast that `ReminderNotificationDelegate`
    /// fires when the user taps a smart-reminder notification. Previously the
    /// broadcast had no consumer and taps dropped silently. Now we read the
    /// `deepLink` userInfo string, parse to URL, and forward to handle().
    ///
    /// Idempotent: the existing 200ms (url, source) dedup window in handle()
    /// protects against double-fire if iOS also delivers via .onOpenURL.
    private func subscribeToReminderTaps() {
        NotificationCenter.default.addObserver(
            forName: .fitMeReminderTapped,
            object: nil,
            queue: .main
        ) { [weak self] notif in
            guard
                let self,
                let userInfo = notif.userInfo,
                let urlString = userInfo["deepLink"] as? String,
                let url = URL(string: urlString)
            else { return }
            self.handle(url: url, source: .notification)
        }
    }

    // MARK: Handle

    /// Resolves a URL into a `DeepLinkAction` and emits via `pendingDeepLink`.
    /// Called by:
    ///   - `FitTrackerApp.onOpenURL` (system → app, source=`.url`)
    ///   - `ReminderNotificationDelegate.didReceive` (notification tap, source=`.notification`)
    ///   - In-app callers (source=`.programmatic`)
    @discardableResult
    func handle(url: URL, source: DeepLinkSource) -> DeepLinkOutcome {
        let urlString = url.absoluteString

        // Dedup: same (url, source) within 200ms is a no-op
        if let last = lastHandled,
           last.url == urlString,
           last.source == source,
           Date().timeIntervalSince(last.at) < dedupeWindow {
            return .succeeded // last call already routed
        }
        lastHandled = (urlString, source, Date())

        // Resolve to action
        guard let action = Self.resolve(url: url) else {
            log(source: source, urlPattern: urlString, destination: "unknown", outcome: .failed_no_pattern_match)
            return .failed_no_pattern_match
        }

        // Special-case: auth URLs are forwarded to the existing SignInService.handleIncomingURL
        // (preserves the auth-polish-v2 reset-password flow without re-implementing it here).
        // We still set pendingDeepLink so subscribers can observe the auth-flow event,
        // and we still log analytics, but the actual session exchange happens in SignInService.
        if case .authFlow(let authURL) = action, let handler = authHandler {
            Task { await handler(authURL) }
        }

        pendingDeepLink = action
        log(source: source, urlPattern: urlString, destination: Self.destinationCategory(action), outcome: .succeeded)
        return .succeeded
    }

    /// Subscriber calls after handling `pendingDeepLink` to clear it for the next event.
    func consume() {
        pendingDeepLink = nil
    }

    /// Test-only: reset dedup window so consecutive identical calls don't collapse.
    /// Hermetic harness uses this between assertions.
    #if DEBUG
    func _resetDedupForTesting() {
        lastHandled = nil
    }
    #endif

    // MARK: - URL → Action resolver

    /// Pure function (testable in isolation). Returns nil for unknown patterns.
    static func resolve(url: URL) -> DeepLinkAction? {
        // Scheme must be fitme; future Universal Links (https://fitme.app/...) plug in here
        guard url.scheme == "fitme" else { return nil }
        guard let host = url.host?.lowercased() else { return nil }

        // path components — first non-"/" component is the {action/tab/section/flow}
        let path = url.pathComponents.filter { $0 != "/" }
        let firstSegment = path.first?.lowercased()

        switch host {
        case "nav":
            guard let segment = firstSegment, let tab = mapTab(segment) else { return nil }
            return .navigateToTab(tab)

        case "action":
            guard let segment = firstSegment, let sheet = SheetIdentifier(rawValue: segment) else { return nil }
            return .presentSheet(sheet)

        case "auth":
            // Pass the full URL through (caller may need query params, e.g. reset-password token)
            return .authFlow(url)

        case "settings":
            guard let segment = firstSegment, let section = SettingsSection(rawValue: segment) else { return nil }
            return .settingsSection(section)

        default:
            return nil
        }
    }

    private static func mapTab(_ segment: String) -> AppTab? {
        switch segment {
        case "home", "main":  return .main
        case "training":      return .training
        case "nutrition":     return .nutrition
        case "stats":         return .stats
        default:              return nil
        }
    }

    private static func destinationCategory(_ action: DeepLinkAction) -> String {
        switch action {
        case .navigateToTab:     return "tab"
        case .presentSheet:      return "sheet"
        case .authFlow:          return "auth"
        case .settingsSection:   return "settings"
        }
    }

    // MARK: - Analytics

    private func log(source: DeepLinkSource, urlPattern: String, destination: String, outcome: DeepLinkOutcome) {
        analytics?.logDeepLinkRouted(
            source: source.rawValue,
            destination: destination,
            urlPattern: urlPattern,
            outcome: outcome.rawValue
        )
    }

    // MARK: - Smart-reminders deep-link registry (C1 item #3, 2026-05-31)

    /// Source of truth for smart-reminder deep-link URLs. Previously these
    /// strings lived inline in `ReminderType.deepLink` — that property now
    /// delegates here so the router owns the mapping. Per L207 backlog
    /// item #3.
    ///
    /// `nonisolated` so non-MainActor callers (notification delegate,
    /// background Codable decoding paths) can resolve a URL without
    /// crossing actor boundaries.
    nonisolated static func deepLinkURL(forReminderTypeRawValue rawValue: String) -> String {
        switch rawValue {
        case "healthkit_connect":    return "fitme://settings/health"
        case "account_registration": return "fitme://auth"
        case "nutrition_gap":        return "fitme://nutrition"
        case "training_day":         return "fitme://training"
        case "rest_day":             return "fitme://home"
        case "engagement":           return "fitme://home"
        default:                     return "fitme://home"
        }
    }
}
