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

    @MainActor
    func testHomeScreenV2() throws {
        try requireSnapshotMode()
        assertScreen(
            NavigationStack {
                MainScreenView(selectedTab: .constant(.main), statsMetric: .constant(nil))
                    .environmentObject(EncryptedDataStore())
                    .environmentObject(HealthKitService())
                    .environmentObject(TrainingProgramStore())
                    .environmentObject(AppSettings())
                    .environmentObject(AnalyticsService.makeDefault())
                    .environmentObject(WatchConnectivityService())
            }
            .background(AppGradient.screenBackground)
        )
    }
}
