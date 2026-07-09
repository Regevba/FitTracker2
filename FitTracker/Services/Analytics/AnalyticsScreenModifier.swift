// Services/Analytics/AnalyticsScreenModifier.swift
// ViewModifier for automatic screen tracking on .onAppear.
// Usage: .analyticsScreen("home")

import SwiftUI

struct AnalyticsScreenModifier: ViewModifier {
    let screenName: String
    let screenClass: String?
    @EnvironmentObject private var analytics: AnalyticsService

    func body(content: Content) -> some View {
        content
            .onAppear {
                // D-3: pass a screen_class so GA4 stops reporting the generic
                // "SwiftUIView" for every screen. Defaults to the screen name,
                // which is a more useful class key for a SwiftUI app.
                analytics.logScreenView(screenName, screenClass: screenClass ?? screenName)
            }
    }
}

extension View {
    func analyticsScreen(_ name: String, screenClass: String? = nil) -> some View {
        modifier(AnalyticsScreenModifier(screenName: name, screenClass: screenClass))
    }
}
