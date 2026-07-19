// FitTrackerTests/SnapshotTests/SnapshotFixtures.swift
//
// FIT-152 (T4/T3) — shared full-graph environment-object fixtures for
// screen-level snapshot tests.
//
// The v2 screens (Home/Stats/Settings/Nutrition/Training) are built on top of a
// large @EnvironmentObject graph and embed subviews that pull in still more
// stores (e.g. Home's readiness-aware alert subview needs ReadinessAwareAlertStore).
// The T3 record pass hit "missing environment object" render crashes because
// each recipe injected only the objects the *top-level* screen declared, not the
// transitive closure its subviews need.
//
// This helper closes that gap: `.snapshotEnvironment()` injects the WHOLE known
// v2 env-object closure in one call, so a screen recipe never crashes on a
// subview's dependency. Every service here is constructed with its no-arg
// initializer into a clean, empty-state instance (deterministic across
// simulators — no seeded data that could drift). The graph mirrors the app's own
// RootTabView injection (FitTrackerApp.swift) plus the two extra stores subviews
// reach for (ReminderPreferencesStore, RecommendationFeedbackController,
// ReadinessAwareAlertStore).
//
// Render-verification is CI-gated: these recipes are captured by the
// SNAPSHOT_MODE=record job (ios-snapshot-record.yml) in the CI simulator, then
// the PNGs are committed and the gate flips to verify. See
// docs/process/snapshot-testing.md.

import SwiftUI
@testable import FitTracker

@MainActor
extension View {
    /// Inject the full v2 environment-object closure for screen snapshots.
    /// One call so a screen recipe can never crash on a subview's missing
    /// environment object. All instances are empty-state (deterministic).
    func snapshotEnvironment() -> some View {
        self
            .environmentObject(EncryptedDataStore())
            .environmentObject(HealthKitService())
            .environmentObject(TrainingProgramStore())
            .environmentObject(AppSettings())
            .environmentObject(AnalyticsService.makeDefault())
            .environmentObject(SignInService())
            .environmentObject(AuthManager())
            .environmentObject(CloudKitSyncService())
            .environmentObject(SupabaseSyncService())
            .environmentObject(WatchConnectivityService())
            .environmentObject(ReminderPreferencesStore())
            .environmentObject(RecommendationFeedbackController())
            .environmentObject(ReadinessAwareAlertStore())
            .environmentObject(TrendAlertStore())
    }
}
