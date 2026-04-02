// Services/Analytics/MockAnalyticsAdapter.swift
// Debug/preview adapter — logs events to console via os_log.
// Used in DEBUG builds and SwiftUI previews.

import Foundation
import os.log

final class MockAnalyticsAdapter: AnalyticsProvider {

    private let logger = Logger(subsystem: "com.fitme.analytics", category: "Mock")

    /// Captured events for unit testing
    private(set) var capturedEvents: [(name: String, parameters: [String: Any]?)] = []
    private(set) var capturedScreens: [String] = []

    func configure() {
        logger.info("MockAnalytics configured")
    }

    func logEvent(_ name: String, parameters: [String: Any]?) {
        capturedEvents.append((name: name, parameters: parameters))
        logger.debug("EVENT: \(name) \(String(describing: parameters))")
    }

    func logScreenView(_ screenName: String, screenClass: String?) {
        capturedScreens.append(screenName)
        logger.debug("SCREEN: \(screenName)")
    }

    func setUserProperty(_ value: String?, forName name: String) {
        logger.debug("USER_PROP: \(name) = \(value ?? "nil")")
    }

    func setUserID(_ id: String?) {
        logger.debug("USER_ID: \(id ?? "nil")")
    }

    func setConsent(analyticsStorage: Bool, adStorage: Bool) {
        logger.debug("CONSENT: analytics=\(analyticsStorage) ads=\(adStorage)")
    }

    /// Reset captured data (for testing)
    func reset() {
        capturedEvents.removeAll()
        capturedScreens.removeAll()
    }
}
