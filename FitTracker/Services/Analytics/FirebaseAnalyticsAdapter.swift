// Services/Analytics/FirebaseAnalyticsAdapter.swift
// GA4 implementation of AnalyticsProvider via Firebase SDK.

import Foundation
import FirebaseCore
import FirebaseAnalytics

final class FirebaseAnalyticsAdapter: AnalyticsProvider {

    func configure() {
        // FirebaseApp.configure() is called in FitTrackerApp.init()
        // Do not call it here — calling it twice crashes.
    }

    func logEvent(_ name: String, parameters: [String: Any]?) {
        Analytics.logEvent(name, parameters: parameters)
    }

    func logScreenView(_ screenName: String, screenClass: String?) {
        Analytics.logEvent(AnalyticsEvents.screenView, parameters: [
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
