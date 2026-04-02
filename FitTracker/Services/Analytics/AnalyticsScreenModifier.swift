// Services/Analytics/AnalyticsScreenModifier.swift
// ViewModifier for automatic screen tracking on .onAppear.
// Usage: .analyticsScreen("home")

import SwiftUI

struct AnalyticsScreenModifier: ViewModifier {
    let screenName: String
    @EnvironmentObject private var analytics: AnalyticsService

    func body(content: Content) -> some View {
        content
            .onAppear {
                analytics.logScreenView(screenName)
            }
    }
}

extension View {
    func analyticsScreen(_ name: String) -> some View {
        modifier(AnalyticsScreenModifier(screenName: name))
    }
}
