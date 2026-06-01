// FitTrackerTests/TrendAlertStoreTests.swift
// C4 feature: trend-alerts-hrv.
//
// Mirrors the ReadinessAwareAlertStore test pattern: update + clear +
// same-day current + cross-day staleness.

import XCTest
@testable import FitTracker

@MainActor
final class TrendAlertStoreTests: XCTestCase {

    private func sampleContext(generatedAt: Date) -> TrendAlertContext {
        TrendAlertContext(
            kind: .hrvSustainedLow,
            samples: [38, 36, 35],
            baseline: 55,
            floor: 40,
            sustainedDays: 3,
            generatedAt: generatedAt
        )
    }

    func test_initialState_latestIsNil() {
        let store = TrendAlertStore()
        XCTAssertNil(store.latest)
        XCTAssertNil(store.current())
    }

    func test_updateSetsLatest() {
        let store = TrendAlertStore()
        let ctx = sampleContext(generatedAt: Date())
        store.update(ctx)
        XCTAssertEqual(store.latest, ctx)
    }

    func test_clearRemovesLatest() {
        let store = TrendAlertStore()
        store.update(sampleContext(generatedAt: Date()))
        store.clear()
        XCTAssertNil(store.latest)
        XCTAssertNil(store.current())
    }

    func test_currentReturnsNilWhenCrossDay() {
        let store = TrendAlertStore()
        let cal = Calendar.current
        let yesterday = cal.date(byAdding: .day, value: -1, to: Date())!
        let today     = Date()
        store.update(sampleContext(generatedAt: yesterday))
        XCTAssertNil(store.current(at: today, calendar: cal),
                     "Cross-day context should be treated as stale")
    }
}
