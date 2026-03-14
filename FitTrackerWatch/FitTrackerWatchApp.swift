// FitTrackerWatch/FitTrackerWatchApp.swift
// watchOS companion app entry point

import SwiftUI

@main
struct FitTrackerWatchApp: App {

    @StateObject private var sessionManager = WatchSessionManager()

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(sessionManager)
        }
    }
}
