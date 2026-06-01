// FitTrackerTests/TrendAlertTriggerTests.swift
// C4 feature: trend-alerts-hrv.
//
// Pure-function decision-rule coverage. No mocks, no UserDefaults, no
// async — every test inputs a fully-specified samples + baseline + floor
// triple and asserts the trigger output.

import XCTest
@testable import FitTracker

@MainActor
final class TrendAlertTriggerTests: XCTestCase {

    private let referenceTime = Date(timeIntervalSince1970: 1_780_000_000)
    private let layer2Baseline = 55.0
    private let layer2Floor    = 40.0   // baseline - 1σ where σ=15
    private let coldStartFloor = TrendAlertTrigger.hardFloor

    // MARK: - Fires when all-below + correct count

    func test_threeBelowFloor_fires() {
        let ctx = TrendAlertTrigger.evaluate(
            hrvSamples: [38.0, 37.0, 35.0],
            baseline: layer2Baseline,
            floor: layer2Floor,
            generatedAt: referenceTime
        )
        XCTAssertNotNil(ctx)
        XCTAssertEqual(ctx?.kind, .hrvSustainedLow)
        XCTAssertEqual(ctx?.sustainedDays, 3)
        XCTAssertEqual(ctx?.samples, [38.0, 37.0, 35.0])
    }

    func test_threeExactlyAtFloor_fires() {
        let ctx = TrendAlertTrigger.evaluate(
            hrvSamples: [40.0, 40.0, 40.0],
            baseline: layer2Baseline,
            floor: layer2Floor,
            generatedAt: referenceTime
        )
        XCTAssertNotNil(ctx)
    }

    // MARK: - Nil paths

    func test_oneSampleAboveFloor_nil() {
        let ctx = TrendAlertTrigger.evaluate(
            hrvSamples: [38.0, 45.0, 35.0], // middle sample above floor
            baseline: layer2Baseline,
            floor: layer2Floor,
            generatedAt: referenceTime
        )
        XCTAssertNil(ctx)
    }

    func test_countTooLow_nil() {
        let ctx = TrendAlertTrigger.evaluate(
            hrvSamples: [38.0, 35.0], // only 2 samples
            baseline: layer2Baseline,
            floor: layer2Floor,
            generatedAt: referenceTime
        )
        XCTAssertNil(ctx)
    }

    func test_countTooHigh_nil() {
        let ctx = TrendAlertTrigger.evaluate(
            hrvSamples: [38.0, 35.0, 36.0, 37.0], // 4 samples
            baseline: layer2Baseline,
            floor: layer2Floor,
            generatedAt: referenceTime
        )
        XCTAssertNil(ctx)
    }

    func test_emptySamples_nil() {
        let ctx = TrendAlertTrigger.evaluate(
            hrvSamples: [],
            baseline: layer2Baseline,
            floor: layer2Floor,
            generatedAt: referenceTime
        )
        XCTAssertNil(ctx)
    }

    func test_nanSample_nil() {
        let ctx = TrendAlertTrigger.evaluate(
            hrvSamples: [38.0, .nan, 35.0],
            baseline: layer2Baseline,
            floor: layer2Floor,
            generatedAt: referenceTime
        )
        XCTAssertNil(ctx)
    }

    func test_infiniteSample_nil() {
        let ctx = TrendAlertTrigger.evaluate(
            hrvSamples: [38.0, .infinity, 35.0],
            baseline: layer2Baseline,
            floor: layer2Floor,
            generatedAt: referenceTime
        )
        XCTAssertNil(ctx)
    }

    // MARK: - Cold-start (Layer 0) path

    func test_coldStart_fires_belowHardFloor() {
        let ctx = TrendAlertTrigger.evaluate(
            hrvSamples: [22.0, 24.0, 23.0],
            baseline: 0,
            floor: coldStartFloor, // 25
            generatedAt: referenceTime
        )
        XCTAssertNotNil(ctx)
        XCTAssertEqual(ctx?.floor, TrendAlertTrigger.hardFloor)
    }

    func test_coldStart_silentWhenAboveHardFloor() {
        let ctx = TrendAlertTrigger.evaluate(
            hrvSamples: [26.0, 27.0, 28.0],
            baseline: 0,
            floor: coldStartFloor,
            generatedAt: referenceTime
        )
        XCTAssertNil(ctx)
    }

    // MARK: - resolvedFloor helper

    func test_resolvedFloor_baselineMinusOneStdDev() {
        let floor = TrendAlertTrigger.resolvedFloor(baseline: 60, oneStdDev: 10)
        XCTAssertEqual(floor, 50.0, accuracy: 0.001)
    }

    func test_resolvedFloor_clampsToHardFloor() {
        // baseline 30 − σ 10 = 20 < hardFloor (25) → clamps to 25
        let floor = TrendAlertTrigger.resolvedFloor(baseline: 30, oneStdDev: 10)
        XCTAssertEqual(floor, TrendAlertTrigger.hardFloor)
    }

    func test_resolvedFloor_nilInputs_returnsHardFloor() {
        XCTAssertEqual(TrendAlertTrigger.resolvedFloor(baseline: nil, oneStdDev: nil), TrendAlertTrigger.hardFloor)
        XCTAssertEqual(TrendAlertTrigger.resolvedFloor(baseline: 50, oneStdDev: nil), TrendAlertTrigger.hardFloor)
    }

    // MARK: - Median + stddev helpers

    func test_median_emptyReturnsNil() {
        XCTAssertNil(TrendAlertTrigger.median([]))
    }

    func test_median_oddCount() {
        XCTAssertEqual(TrendAlertTrigger.median([10, 50, 30]), 30)
    }

    func test_median_evenCount() {
        XCTAssertEqual(TrendAlertTrigger.median([10, 20, 30, 40]), 25)
    }

    func test_stddev_emptyReturnsNil() {
        XCTAssertNil(TrendAlertTrigger.populationStdDev([]))
    }

    func test_stddev_singleSampleReturnsZero() throws {
        let s = try XCTUnwrap(TrendAlertTrigger.populationStdDev([50.0]))
        XCTAssertEqual(s, 0.0, accuracy: 0.001)
    }

    func test_stddev_identicalReturnsZero() throws {
        let s = try XCTUnwrap(TrendAlertTrigger.populationStdDev([42.0, 42.0, 42.0]))
        XCTAssertEqual(s, 0.0, accuracy: 0.001)
    }

    func test_stddev_knownValue() {
        // values 10, 20, 30, 40, 50 — population stddev = sqrt(200) ≈ 14.142
        let s = TrendAlertTrigger.populationStdDev([10, 20, 30, 40, 50])
        XCTAssertEqual(s ?? 0, 14.142, accuracy: 0.01)
    }
}
