// Services/Analytics/FirebaseAnalyticsAdapter.swift
// GA4 implementation of AnalyticsProvider via Firebase SDK.
//
// Prerequisites:
// 1. Add Firebase Analytics SPM: https://github.com/firebase/firebase-ios-sdk (FirebaseAnalytics)
// 2. Add GoogleService-Info.plist to the project
// 3. Add -ObjC linker flag
// 4. Uncomment the Firebase imports and method bodies below
//
// Until Firebase SPM is added, use MockAnalyticsAdapter.

import Foundation
// import FirebaseCore
// import FirebaseAnalytics

final class FirebaseAnalyticsAdapter: AnalyticsProvider {

    func configure() {
        // FirebaseApp.configure()
        // Disable auto screen reporting (we handle it manually for SwiftUI)
        // Analytics.setAnalyticsCollectionEnabled(true)
    }

    func logEvent(_ name: String, parameters: [String: Any]?) {
        // Analytics.logEvent(name, parameters: parameters)
        #if DEBUG
        print("[Analytics:Firebase] \(name) \(parameters ?? [:])")
        #endif
    }

    func logScreenView(_ screenName: String, screenClass: String?) {
        // Analytics.logEvent(AnalyticsEventScreenView, parameters: [
        //     AnalyticsParameterScreenName: screenName,
        //     AnalyticsParameterScreenClass: screenClass ?? "SwiftUIView"
        // ])
        #if DEBUG
        print("[Analytics:Firebase] screen_view: \(screenName)")
        #endif
    }

    func setUserProperty(_ value: String?, forName name: String) {
        // Analytics.setUserProperty(value, forName: name)
    }

    func setUserID(_ id: String?) {
        // Analytics.setUserID(id)
    }

    func setConsent(analyticsStorage: Bool, adStorage: Bool) {
        // Analytics.setConsent([
        //     .analyticsStorage: analyticsStorage ? .granted : .denied,
        //     .adStorage: adStorage ? .granted : .denied,
        // ])
    }
}
