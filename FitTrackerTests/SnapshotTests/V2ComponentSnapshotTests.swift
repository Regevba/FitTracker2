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

    // Note: WelcomeView's `.onAppear` opacity reveal was previously handled by a
    // `.wait` + drawHierarchyInKeyWindow recipe. That was ruled out empirically
    // (2026-07-23, W46) and replaced by rendering the view's settled state
    // directly via `WelcomeView(snapshotSettled:)`, so a plain `assertScreen`
    // now covers it and the animation-waiting helper is no longer needed.

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
        // T3 (2026-07-23): the ORIGINAL blocker is FIXED. Home's AIInsightCard
        // subtree declares `@EnvironmentObject var orchestrator: AIOrchestrator`,
        // which has no no-arg factory, so the 07-18 and 07-20 record runs died at
        // 0.000s. The inert AI stubs now injected via `.snapshotEnvironment()`
        // (SnapshotFixtures) resolve that: Home renders fully — verified by
        // recording it locally and LOOKING at the PNG (readiness card, insight
        // card in its no-recommendation state, body composition, actions).
        //
        // Recording it surfaced a SECOND, previously-unknown blocker that keeps
        // this test skipped: Home is WALL-CLOCK DEPENDENT. The captured frame
        // read "Good evening," and "Thursday, 23 July 2026" — MainScreenView
        // calls `Date()` directly in four places (greeting hour :525, today's
        // date string :541, readiness date :65, days-since-onboarding :593).
        // A committed baseline would therefore fail the next calendar day, and
        // three times a day as the greeting rolls over.
        //
        // FIXED (T3): MainScreenView now has an injectable `now` clock seam
        // (default `{ Date() }` in production). This recipe pins it to a fixed
        // instant so the greeting ("Good evening,") and today's-date string are
        // a pure function of the code, not the wall-clock — the baseline no
        // longer rots at the next calendar day / greeting rollover.
        try requireSnapshotMode()
        try skipVerifyUntilBaselineRecorded()
        assertScreen(
            NavigationStack {
                MainScreenView(
                    selectedTab: .constant(.main),
                    statsMetric: .constant(nil),
                    now: { Self.fixedSnapshotDate }
                )
            }
            .snapshotEnvironment()
            .background(AppGradient.screenBackground)
        )
    }

    /// Fixed instant for wall-clock-dependent screen snapshots: 2026-01-15
    /// 09:41:00 UTC. 09:41 keeps the greeting in the "Good morning," branch
    /// (the classic Apple keynote time); a fixed calendar date keeps the
    /// "Thursday, 15 January 2026" string stable across record runs.
    private static let fixedSnapshotDate: Date = {
        var c = DateComponents()
        c.year = 2026; c.month = 1; c.day = 15
        c.hour = 9; c.minute = 41; c.second = 0
        c.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: c)!
    }()

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
        // T3: WelcomeView records BLANK (the PNG is the bare gradient — no logo,
        // no buttons). 2026-07-23 narrowed the mechanism but did NOT fix it, so
        // this stays skipped rather than committing a blank baseline.
        //
        // Mechanism: the view initialises logo/text/buttons at `opacity 0` and
        // reveals them from `.onAppear` with delays up to 0.7s (WelcomeView:136).
        // The capture is a faithful snapshot of the pre-reveal state. It is NOT
        // the missing-NavigationStack theory the 07-20 note guessed at — the
        // ZStack itself renders fine (the gradient and the Canvas grid both
        // appear); only the opacity-gated VStack is absent.
        //
        // Ruled out empirically, so the next attempt does not repeat them:
        //   1. `.wait(for: 1.5, on: .image(...))` alone -> still blank. Waiting
        //      cannot help if the animation was never scheduled.
        //   2. `.wait` + `drawHierarchyInKeyWindow: true` -> still blank, though
        //      the render does change (grid lines resolve, runtime 1.7s -> 3.1s),
        //      so the key window is doing something but `.onAppear` still is not
        //      driving the reveal to completion under the snapshot render.
        //
        // FIXED (T3): WelcomeView now takes `snapshotSettled: Bool` (default
        // false). When true it seeds every animated element at its post-entry
        // value and skips the `.onAppear` reveal, so the recorded frame shows
        // the full screen (logo, copy, fact rows, Continue button) instead of a
        // bare gradient. This renders the settled state directly rather than
        // trying to drive SwiftUI's animation clock from a test — `.wait` and
        // drawHierarchyInKeyWindow were both ruled out (see W46). A plain
        // `assertScreen` suffices now that there is no animation to settle.
        try requireSnapshotMode()
        try skipVerifyUntilBaselineRecorded()
        assertScreen(
            WelcomeView(snapshotSettled: true)
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
