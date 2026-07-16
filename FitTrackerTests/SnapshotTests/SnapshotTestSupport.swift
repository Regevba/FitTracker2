// FitTrackerTests/SnapshotTests/SnapshotTestSupport.swift
//
// FIT-152 (T4) — Swift snapshot-testing harness support.
//
// Snapshot baselines are simulator-specific. Local (Xcode 26 / iPhone 17 Pro,
// iOS 26) and CI (iPhone 15/16, iOS ~18) do NOT share a simulator, so a
// baseline recorded locally would fail in CI. To bootstrap safely we RECORD
// baselines in the CI environment (the `ios-snapshot-record` job runs with
// SNAPSHOT_MODE=record and uploads the __Snapshots__ dir as an artifact), then
// commit those CI-recorded PNGs and flip the gate to SNAPSHOT_MODE=verify.
//
// Until then these tests SKIP in the default `Build and Test` run (SNAPSHOT_MODE
// unset) so they never redden the required check without baselines. See
// .github/workflows/ios-snapshot-record.yml + docs/process/snapshot-testing.md.

import Foundation
import XCTest

enum SnapshotMode {
    /// Raw SNAPSHOT_MODE env value: nil (default) | "record" | "verify".
    static var current: String? {
        ProcessInfo.processInfo.environment["SNAPSHOT_MODE"]
    }

    /// True in the CI record job — captures/overwrites reference PNGs.
    static var isRecording: Bool { current == "record" }

    /// True when snapshot assertions should run at all (record OR verify).
    static var isActive: Bool { current == "record" || current == "verify" }
}

extension XCTestCase {
    /// Skip the calling test unless SNAPSHOT_MODE is set. Keeps snapshot tests
    /// out of the default test run (which has no CI-matching baselines yet).
    func requireSnapshotMode(
        file: StaticString = #filePath, line: UInt = #line
    ) throws {
        if !SnapshotMode.isActive {
            throw XCTSkip(
                "SNAPSHOT_MODE unset — snapshot tests run only in the "
                + "ios-snapshot-record job (record) or once baselines are "
                + "committed (SNAPSHOT_MODE=verify)."
            )
        }
    }

    /// Skip in verify mode when a test's CI baseline hasn't been recorded and
    /// committed yet. A new recipe is render-verified locally (record mode) but
    /// its simulator-matched baseline PNG lands via a follow-up
    /// ios-snapshot-record cycle; until then, running it under SNAPSHOT_MODE=verify
    /// would fail on a missing reference. Skipping keeps the verify gate green
    /// without a fabricated (local-sim) baseline. Remove the guard from a test
    /// once its baseline is committed. Record mode is unaffected (records the PNG).
    func skipVerifyUntilBaselineRecorded(
        _ reason: String = "baseline pending ios-snapshot-record cycle (T3)",
        file: StaticString = #filePath, line: UInt = #line
    ) throws {
        if SnapshotMode.current == "verify" {
            throw XCTSkip(reason)
        }
    }
}
