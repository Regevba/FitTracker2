// FitTrackerTests/HealthKitSourceProbeTests.swift
// Device-free tests for Tier-1 source attribution (garmin-health-connection T9).
// The probe is injected with a deterministic SignalSourceQuery fixture so no
// HealthKit store / device / simulator HealthKit data is required.

import XCTest
@testable import FitTracker

final class HealthKitSourceProbeTests: XCTestCase {

    /// Build a probe whose query returns a fixed map of signal → (bundleIDs, newest).
    private func probe(_ map: [ReadinessSignal: (Set<String>, Date?)]) -> HealthKitSourceProbe {
        HealthKitSourceProbe { signal in map[signal] ?? ([], nil) }
    }

    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: - Presence detection

    func testGarminActive_whenGarminBundleHasSignals() async {
        let p = probe([
            .hrv:       (["com.garmin.connect.mobile"], t0),
            .restingHR: (["com.garmin.connect.mobile"], t0.addingTimeInterval(60)),
            .sleep:     (["com.apple.health"], t0),   // someone else's sleep — not Garmin
        ])
        let presence = await p.presence(for: .garmin)
        XCTAssertTrue(presence.isActive)
        XCTAssertEqual(presence.signalsPresent, [.hrv, .restingHR])
        XCTAssertFalse(presence.signalsPresent.contains(.sleep), "Apple-sourced sleep must not count as Garmin")
    }

    func testNotActive_whenSourceDisjoint() async {
        let p = probe([
            .hrv:   (["com.apple.health", "com.whoop.app"], t0),
            .steps: (["com.fitbit.FitbitMobile"], t0),
        ])
        let presence = await p.presence(for: .garmin)
        XCTAssertFalse(presence.isActive)
        XCTAssertTrue(presence.signalsPresent.isEmpty)
        XCTAssertNil(presence.lastSample)
    }

    func testNewestSample_isMaxAcrossMatchingSignals() async {
        let newest = t0.addingTimeInterval(3600)
        let p = probe([
            .hrv:       (["com.garmin.connect.mobile"], t0),
            .restingHR: (["com.garmin.connect.mobile"], newest),
            .steps:     (["com.garmin.connect.mobile"], t0.addingTimeInterval(120)),
        ])
        let presence = await p.presence(for: .garmin)
        XCTAssertEqual(presence.lastSample, newest, "lastSample must be the max date across matching signals")
    }

    func testFitbit_matchesAnyKnownBundleVariant() async {
        // Fitbit has two known bundle IDs; either should match.
        let p = probe([.sleep: (["com.fitbit.FitbitiOS"], t0)])
        let presence = await p.presence(for: .fitbit)
        XCTAssertTrue(presence.isActive)
        XCTAssertEqual(presence.signalsPresent, [.sleep])
    }

    func testPresenceForAllSources_returnsOnePerSource() async {
        let p = probe([.hrv: (["com.garmin.connect.mobile"], t0)])
        let all = await p.presenceForAllSources()
        XCTAssertEqual(all.count, DataSource.allCases.count)
        XCTAssertEqual(all.first(where: { $0.source == .garmin })?.isActive, true)
        XCTAssertEqual(all.first(where: { $0.source == .fitbit })?.isActive, false)
    }

    // MARK: - Sample-type mapping (live path is device-gated; the mapping is pure)

    func testSampleTypeMapping_coversEverySignal() {
        for signal in ReadinessSignal.allCases {
            XCTAssertNotNil(HealthKitSourceProbe.sampleType(for: signal),
                            "Every readiness signal must map to a HealthKit sample type — missing \(signal)")
        }
    }
}
