// Services/Analytics/FirebaseAnalyticsAdapter.swift
// GA4 implementation of AnalyticsProvider via Firebase SDK.

import Foundation
import FirebaseCore
import FirebaseAnalytics

final class FirebaseAnalyticsAdapter: AnalyticsProvider {

    func configure() {
        // FirebaseApp.configure() is called in FitTrackerApp.init()
        // Do not call it here — calling it twice crashes.
        // Override the plist's IS_ANALYTICS_ENABLED=false default;
        // GDPR consent gating is handled separately via setConsent().
        Analytics.setAnalyticsCollectionEnabled(true)
    }

    func logEvent(_ name: String, parameters: [String: Any]?) {
        Analytics.logEvent(name, parameters: parameters)
    }

    func logScreenView(_ screenName: String, screenClass: String?) {
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: screenName,
            AnalyticsParameterScreenClass: screenClass ?? "SwiftUIView",
        ])
    }

    func setUserProperty(_ value: String?, forName name: String) {
        Analytics.setUserProperty(value, forName: name)
    }

    func setUserID(_ id: String?) {
        Analytics.setUserID(id)
    }

    func setConsent(analyticsStorage: Bool, adStorage: Bool) {
        Analytics.setConsent([
            .analyticsStorage: analyticsStorage ? .granted : .denied,
            .adStorage: adStorage ? .granted : .denied,
        ])
    }
}
