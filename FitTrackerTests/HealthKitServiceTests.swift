// FitTrackerTests/HealthKitServiceTests.swift
// TEST-005: HealthKit data mapping — tests LiveMetrics computed properties
// and MetricStatus enum. HKHealthStore interaction requires a physical device
// and is covered by integration tests (deferred).

import XCTest
@testable import FitTracker

@MainActor
final class HealthKitServiceTests: XCTestCase {

    // MARK: - LiveMetrics.restingHRStatus

    func testRestingHRStatus_excellent_below60() {
        var m = LiveMetrics()
        m.restingHR = 55
        XCTAssertEqual(m.restingHRStatus, .excellent)
    }

    func testRestingHRStatus_good_60to74() {
        var m = LiveMetrics()
        m.restingHR = 65
        XCTAssertEqual(m.restingHRStatus, .good)
    }

    func testRestingHRStatus_caution_75to84() {
        var m = LiveMetrics()
        m.restingHR = 80
        XCTAssertEqual(m.restingHRStatus, .caution)
    }

    func testRestingHRStatus_alert_85plus() {
        var m = LiveMetrics()
        m.restingHR = 90
        XCTAssertEqual(m.restingHRStatus, .alert)
    }

    func testRestingHRStatus_unknown_whenNil() {
        let m = LiveMetrics()
        XCTAssertEqual(m.restingHRStatus, .unknown)
    }

    // MARK: - LiveMetrics.hrvStatus

    func testHRVStatus_excellent_above45() {
        var m = LiveMetrics()
        m.hrv = 50
        XCTAssertEqual(m.hrvStatus, .excellent)
    }

    func testHRVStatus_good_35to44() {
        var m = LiveMetrics()
        m.hrv = 40
        XCTAssertEqual(m.hrvStatus, .good)
    }

    func testHRVStatus_caution_28to34() {
        var m = LiveMetrics()
        m.hrv = 30
        XCTAssertEqual(m.hrvStatus, .caution)
    }

    func testHRVStatus_alert_below28() {
        var m = LiveMetrics()
        m.hrv = 20
        XCTAssertEqual(m.hrvStatus, .alert)
    }

    func testHRVStatus_unknown_whenNil() {
        let m = LiveMetrics()
        XCTAssertEqual(m.hrvStatus, .unknown)
    }

    // MARK: - isReadyForTraining gate

    func testIsReadyForTraining_highHRVLowRHR_ready() {
        var m = LiveMetrics()
        m.restingHR = 58
        m.hrv = 50
        XCTAssertTrue(m.isReadyForTraining)
    }

    func testIsReadyForTraining_lowHRV_notReady() {
        var m = LiveMetrics()
        m.restingHR = 58
        m.hrv = 20
        XCTAssertFalse(m.isReadyForTraining, "HRV below 28 should block training readiness")
    }

    func testIsReadyForTraining_highRHR_notReady() {
        var m = LiveMetrics()
        m.restingHR = 80
        m.hrv = 50
        XCTAssertFalse(m.isReadyForTraining, "RHR ≥ 75 should block training readiness")
    }

    func testIsReadyForTraining_missingData_notReady() {
        let m = LiveMetrics()
        XCTAssertFalse(m.isReadyForTraining, "Missing biometrics must default to not-ready")
    }

    // MARK: - Boundary values (documents thresholds)

    func testRestingHRStatus_boundaryAt60() {
        var m = LiveMetrics()
        m.restingHR = 60
        XCTAssertEqual(m.restingHRStatus, .good, "RHR = 60 is good (boundary, not excellent)")
    }

    func testHRVStatus_boundaryAt45() {
        var m = LiveMetrics()
        m.hrv = 45
        XCTAssertEqual(m.hrvStatus, .excellent, "HRV = 45 is excellent (boundary inclusive)")
    }
}
