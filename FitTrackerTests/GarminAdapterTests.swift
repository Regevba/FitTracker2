// FitTrackerTests/GarminAdapterTests.swift
// Device-free tests for the Tier-1 GarminAdapter (garmin-health-connection T9).
// Verifies the source-attribution seam: lastUpdated/isActive reflect presence, and
// contribute(to:) is a no-op pass-through in v1 (data flows via HealthKitAdapter).

import XCTest
@testable import FitTracker

final class GarminAdapterTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    func testSourceID_isGarmin() {
        XCTAssertEqual(GarminAdapter(presence: nil).sourceID, "garmin")
    }

    func testLastUpdated_reflectsPresence() {
        let presence = SourcePresence(source: .garmin, signalsPresent: [.hrv], lastSample: t0)
        XCTAssertEqual(GarminAdapter(presence: presence).lastUpdated, t0)
        XCTAssertNil(GarminAdapter(presence: nil).lastUpdated)
    }

    func testIsActive_reflectsSignals() {
        let active = SourcePresence(source: .garmin, signalsPresent: [.hrv], lastSample: t0)
        let inactive = SourcePresence.empty(.garmin)
        XCTAssertTrue(GarminAdapter(presence: active).isActive)
        XCTAssertFalse(GarminAdapter(presence: inactive).isActive)
        XCTAssertFalse(GarminAdapter(presence: nil).isActive)
    }

    func testContribute_isNoOp_tier1() {
        // Tier 1: GarminAdapter must NOT mutate the snapshot (data arrives via HealthKitAdapter).
        // LocalUserSnapshot isn't Equatable, so assert representative biometric/readiness
        // fields (the ones HealthKitAdapter owns) remain at their fresh-default nil.
        let presence = SourcePresence(source: .garmin, signalsPresent: [.hrv, .sleep], lastSample: t0)
        var snapshot = LocalUserSnapshot()
        GarminAdapter(presence: presence).contribute(to: &snapshot)
        XCTAssertNil(snapshot.bmiValue, "Tier-1 GarminAdapter must not write bmiValue")
        XCTAssertNil(snapshot.restingHeartRate, "Tier-1 GarminAdapter must not write restingHeartRate")
        XCTAssertNil(snapshot.readinessScore, "Tier-1 GarminAdapter must not write readinessScore")
        XCTAssertNil(snapshot.avgSleepHours, "Tier-1 GarminAdapter must not write avgSleepHours")
    }
}
