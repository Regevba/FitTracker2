// FitTrackerTests/SnapshotTests/V2ComponentSnapshotTests.swift
//
// FIT-152 (T4) — snapshot-testing foundation.
//
// Baselines the shared design-system components that the v2 screens are built
// from — the highest-leverage, lowest-flake starting point (self-contained,
// no injected environment/state). Fixed-size layout + perceptual precision keep
// the images deterministic across simulators. The 6 v2 screens + 4 auth views
// (which require mock view-model / store injection) are the documented
// follow-up, added once the CI-recorded baseline flow is proven (see
// docs/process/snapshot-testing.md).
//
// Runs only when SNAPSHOT_MODE is set (see SnapshotTestSupport) — the default
// `Build and Test` run skips these so it never reddens without baselines.

import XCTest
import SwiftUI
import SnapshotTesting
@testable import FitTracker

final class V2ComponentSnapshotTests: XCTestCase {

    /// Assert a fixed-size light-mode image snapshot with tolerance for
    /// cross-OS anti-aliasing differences. Records when SNAPSHOT_MODE=record.
    private func assertComponent<V: View>(
        _ view: V,
        width: CGFloat,
        height: CGFloat,
        named name: String = #function,
        file: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line
    ) {
        let hosted = view
            .frame(width: width, height: height)
            .background(Color.white)
        assertSnapshot(
            of: hosted,
            as: .image(
                precision: 0.98,
                perceptualPrecision: 0.98,
                layout: .fixed(width: width, height: height),
                traits: .init(userInterfaceStyle: .light)
            ),
            record: SnapshotMode.isRecording,
            file: file,
            testName: testName,
            line: line
        )
    }

    func testAppProgressRing() throws {
        try requireSnapshotMode()
        assertComponent(
            AppProgressRing(value: 0.6, color: AppColor.Status.warning, label: "60%"),
            width: 80, height: 80
        )
    }

    func testAppPickerChipSelected() throws {
        try requireSnapshotMode()
        assertComponent(
            AppPickerChip(label: "Selected", isSelected: true) {},
            width: 140, height: 56
        )
    }

    func testAppSegmentedControl() throws {
        try requireSnapshotMode()
        assertComponent(
            AppSegmentedControl(options: ["Day", "Week", "Month"], selection: .constant("Week")),
            width: 320, height: 56
        )
    }

    func testAppMetricColumn() throws {
        try requireSnapshotMode()
        assertComponent(
            AppMetricColumn(
                icon: "scalemass.fill", title: "WEIGHT", value: "82.5",
                unit: "kg", target: "Goal 80 kg", tintColor: .blue
            ),
            width: 160, height: 140
        )
    }

    // MARK: - Screen-level snapshots (T3 — recorded via the ios-snapshot-record CI job)
    //
    // T3 expands snapshot coverage from DS components to full v2 screens. Like
    // the component tests these SKIP in the default `Build and Test` run (no
    // baselines) and are captured by the SNAPSHOT_MODE=record CI job (T2), then
    // committed and flipped to verify. The Home (MainScreenView) recipe mirrors
    // the screen's own #Preview env-object graph. The remaining v2 screens
    // (Stats/Settings/Nutrition/Training/Readiness) + the 4 auth views land as
    // each grows a construction recipe alongside the T2 record pipeline —
    // today only MainScreenView ships a #Preview to mirror.

    /// Full-device fixed-size light-mode screen snapshot. iPhone 17 logical
    /// size (393×852). @MainActor because the screen's env-object services are
    /// main-actor-isolated (same as the SwiftUI preview context).
    @MainActor
    private func assertScreen(
        _ view: some View,
        width: CGFloat = 393,
        height: CGFloat = 852,
        file: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line
    ) {
        assertSnapshot(
            of: view.frame(width: width, height: height),
            as: .image(
                precision: 0.98,
                perceptualPrecision: 0.98,
                layout: .fixed(width: width, height: height),
                traits: .init(userInterfaceStyle: .light)
            ),
            record: SnapshotMode.isRecording,
            file: file,
            testName: testName,
            line: line
        )
    }

    // T3: each screen recipe now injects the full env-object closure via
    // `.snapshotEnvironment()` (SnapshotFixtures.swift), so a subview's
    // dependency (e.g. Home's ReadinessAwareAlertStore) no longer crashes the
    // render. Real initializers mirror the RootTabView call sites. All guard on
    // requireSnapshotMode (skip in the default run) + skipVerifyUntilBaselineRecorded
    // (skip in verify until the CI-recorded baseline lands), so they only render
    // under SNAPSHOT_MODE=record. Baselines are captured by the ios-snapshot-record
    // job, then committed and the gate flips to verify.

    @MainActor
    func testHomeScreenV2() throws {
        // T3: Home still fails to render even with the full `.snapshotEnvironment()`
        // graph — verified 2026-07-18 via local SNAPSHOT_MODE=record (failed at
        // 0.000s while Stats/Nutrition/Training/Settings all recorded PNGs). Home's
        // AIInsightCard subtree needs a constructed AIOrchestrator, which has no
        // factory (init takes engineClient + foundationModel + pcc + snapshot/goalMode
        // closures — a stub AIEngineClient + FallbackFoundationModel is required).
        // Building that stub is the remaining T3 piece; kept hard-skipped so the
        // ios-snapshot-record job never crashes. Recipe preserved for that pass.
        try XCTSkipIf(true, "Home v2 needs a stubbed AIOrchestrator (no factory) — remaining T3 piece; see SnapshotFixtures.")
        try requireSnapshotMode()
        try skipVerifyUntilBaselineRecorded()
        assertScreen(
            NavigationStack {
                MainScreenView(selectedTab: .constant(.main), statsMetric: .constant(nil))
            }
            .snapshotEnvironment()
            .background(AppGradient.screenBackground)
        )
    }

    @MainActor
    func testStatsScreenV2() throws {
        try requireSnapshotMode()
        try skipVerifyUntilBaselineRecorded()
        assertScreen(
            NavigationStack {
                StatsView(initialMetric: nil)
            }
            .snapshotEnvironment()
            .background(AppGradient.screenBackground)
        )
    }

    @MainActor
    func testNutritionScreenV2() throws {
        try requireSnapshotMode()
        try skipVerifyUntilBaselineRecorded()
        assertScreen(
            NavigationStack {
                NutritionView()
            }
            .snapshotEnvironment()
            .background(AppGradient.screenBackground)
        )
    }

    @MainActor
    func testTrainingPlanScreenV2() throws {
        try requireSnapshotMode()
        try skipVerifyUntilBaselineRecorded()
        assertScreen(
            NavigationStack {
                TrainingPlanView(initialDay: nil)
            }
            .snapshotEnvironment()
            .background(AppGradient.screenBackground)
        )
    }

    @MainActor
    func testSettingsScreenV2() throws {
        try requireSnapshotMode()
        try skipVerifyUntilBaselineRecorded()
        assertScreen(
            NavigationStack {
                SettingsView()
            }
            .snapshotEnvironment()
            .background(AppGradient.screenBackground)
        )
    }

    // MARK: - Auth-view screen snapshots (T3)
    //
    // The 4 auth views need only a tiny env-object graph (unlike Home's full
    // 15-object graph + AIOrchestrator), so their recipes are complete and were
    // verified to render without env-graph crashes in local SNAPSHOT_MODE=record
    // (the same failure mode Home hit). They skip in the default `Build and Test`
    // run (requireSnapshotMode) and are captured by the SNAPSHOT_MODE=record CI
    // job (T2), then committed and flipped to verify. The 5 remaining v2 screens
    // (Home/Stats/Settings/Nutrition/Training/Readiness) need the shared
    // full-graph SnapshotFixtures helper (multi-session — see snapshot-testing.md).

    @MainActor
    func testWelcomeAuthView() throws {
        // T3: WelcomeView renders BLANK in the CI recorder (verified 2026-07-20 —
        // the ios-snapshot-record artifact PNG was the bare gradient, no logo/buttons),
        // unlike SignInView which renders correctly wrapped in a NavigationStack. The
        // local "wrote a PNG" check did not catch this (a blank PNG is still a PNG).
        // Likely an onAppear-driven reveal animation or missing navigation context that
        // collapses the layout at capture time. Kept hard-skipped so the blank frame is
        // never committed as a baseline; fixing the recipe (add NavigationStack / settle
        // the animation) is the remaining T3 piece for this surface.
        try XCTSkipIf(true, "WelcomeView renders blank in CI record — recipe needs a fix; see 2026-07-20 record run.")
        try requireSnapshotMode()
        try skipVerifyUntilBaselineRecorded()
        assertScreen(
            WelcomeView()
                .environmentObject(SignInService())
        )
    }

    @MainActor
    func testSignInAuthView() throws {
        try requireSnapshotMode()
        try skipVerifyUntilBaselineRecorded()
        assertScreen(
            NavigationStack {
                SignInView()
                    .environmentObject(SignInService())
            }
        )
    }

    @MainActor
    func testBiometricUnlockAuthView() throws {
        try requireSnapshotMode()
        try skipVerifyUntilBaselineRecorded()
        assertScreen(
            BiometricUnlockView()
                .environmentObject(AuthManager())
                .environmentObject(SignInService())
                .environmentObject(AnalyticsService.makeDefault())
        )
    }

    @MainActor
    func testOnboardingWelcomeV2View() throws {
        try requireSnapshotMode()
        try skipVerifyUntilBaselineRecorded()
        assertScreen(
            OnboardingWelcomeView(onContinue: {})
                .environmentObject(AnalyticsService.makeDefault())
        )
    }
}
