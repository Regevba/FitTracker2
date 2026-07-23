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

// ─────────────────────────────────────────────────────────
// MARK: – Inert AI stubs (Home v2)
// ─────────────────────────────────────────────────────────
//
// Home v2 embeds AIInsightCard, which declares `@EnvironmentObject var
// orchestrator: AIOrchestrator`. AIOrchestrator has no no-arg factory — its
// init takes an engine client, a foundation model, and two closures — so Home
// was the one v2 screen that could not be rendered by `.snapshotEnvironment()`
// and stayed hard-skipped through the 2026-07-18 and 07-20 record runs.
//
// These two stubs are deliberately INERT rather than merely deterministic:
// `fetchInsight` and `adapt` both throw, so the orchestrator settles into its
// empty/`lastError` state without performing any I/O, spawning a task that
// could still be in flight at capture time, or emitting content that would
// drift between simulators. A snapshot baseline must be a pure function of the
// code, and an AI recommendation is exactly the kind of value that is not.
// Home therefore records with its insight card in the no-recommendation state.
//
// AIOrchestratorTests has similar stubs, but they are `private` to that file
// (and configurable, which is the wrong default here), so these are separate
// on purpose.

private struct SnapshotInertEngineClient: AIEngineClientProtocol {
    struct Inert: Error {}
    func fetchInsight(
        segment: AISegment,
        payload: [String: String],
        jwt: String
    ) async throws -> AIRecommendation {
        throw Inert()
    }
}

private struct SnapshotInertFoundationModel: FoundationModelProtocol {
    struct Inert: Error {}
    // Report unavailable so the orchestrator skips the Tier-3 adaptation path
    // entirely instead of calling adapt() and handling a throw.
    var isAvailable: Bool { false }
    func adapt(
        recommendation: AIRecommendation,
        snapshot: LocalUserSnapshot
    ) async throws -> (recommendation: AIRecommendation, confidence: Double) {
        throw Inert()
    }
}

@MainActor
private func makeSnapshotOrchestrator() -> AIOrchestrator {
    AIOrchestrator(
        engineClient: SnapshotInertEngineClient(),
        foundationModel: SnapshotInertFoundationModel(),
        snapshot: { LocalUserSnapshot() },
        goalMode: { .maintain }
    )
}

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
            .environmentObject(makeSnapshotOrchestrator())
    }
}
