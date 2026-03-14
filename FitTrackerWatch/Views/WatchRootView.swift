// FitTrackerWatch/Views/WatchRootView.swift
// Root TabView: Workout / Metrics / Supplements

import SwiftUI

struct WatchRootView: View {

    @EnvironmentObject var session: WatchSessionManager

    var body: some View {
        TabView {
            ActiveWorkoutView()
                .environmentObject(session)
                .tabItem { Label("Workout", systemImage: "figure.strengthtraining.traditional") }

            MetricsView()
                .environmentObject(session)
                .tabItem { Label("Metrics", systemImage: "heart.fill") }

            SupplementCheckView()
                .environmentObject(session)
                .tabItem { Label("Supplements", systemImage: "pills.fill") }
        }
        .onAppear { session.requestTodayData() }
    }
}
