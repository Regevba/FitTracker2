// FitTrackerTests/TrendAlertObserverTests.swift
// C4 feature: trend-alerts-hrv.
//
// Covers the user-facing gates (opt-out + 7-day de-dupe + consumer
// registration shape) without exercising the full async
// NotificationGateway dispatch path — that integration is deferred to a
// Tier 2.1 smoke test.

import XCTest
@testable import FitTracker

@MainActor
final class TrendAlertObserverTests: XCTestCase {

    private var observer: TrendAlertObserver!
    private let testDate = Date(timeIntervalSince1970: 1_780_000_000) // 2026-06-04 ~ 20:26 UTC

    override func setUp() async throws {
        try await super.setUp()
        observer = TrendAlertObserver()
        observer._resetForTesting(date: testDate)
    }

    override func tearDown() async throws {
        observer._resetForTesting(date: testDate)
        observer = nil
        try await super.tearDown()
    }

    // MARK: - De-dupe (7-day window)

    func test_initialState_notFiredThisWeek() {
        XCTAssertFalse(observer.alreadyFiredThisWeek(date: testDate))
    }

    func test_weekKeyDedupeBlocksRefire() {
        // Mark fired today; verify same-week date is also blocked
        UserDefaults.standard.set(true, forKey: keyFor(testDate))
        XCTAssertTrue(observer.alreadyFiredThisWeek(date: testDate))
    }

    func test_dedupeOpensInFollowingWeek() {
        // Mark fired today; verify 8 days later (next ISO week) is unblocked
        UserDefaults.standard.set(true, forKey: keyFor(testDate))
        let nextWeek = Calendar.current.date(byAdding: .day, value: 8, to: testDate)!
        XCTAssertFalse(observer.alreadyFiredThisWeek(date: nextWeek))
    }

    // MARK: - Feature toggle

    func test_isFeatureEnabledDefaultTrue() {
        UserDefaults.standard.removeObject(forKey: TrendAlertObserver.optOutKey)
        XCTAssertTrue(observer.isFeatureEnabled())
    }

    func test_isFeatureEnabledReadsUserDefaults() {
        UserDefaults.standard.set(false, forKey: TrendAlertObserver.optOutKey)
        XCTAssertFalse(observer.isFeatureEnabled())
        UserDefaults.standard.set(true, forKey: TrendAlertObserver.optOutKey)
        XCTAssertTrue(observer.isFeatureEnabled())
    }

    // MARK: - Consumer registration shape

    func test_consumerRegistrationHasStableID() {
        XCTAssertEqual(
            TrendAlertObserver.consumerRegistration.id,
            "push-notifications.trendAlert"
        )
        XCTAssertEqual(
            TrendAlertObserver.consumerRegistration.primaryCapTag,
            .standard
        )
        XCTAssertTrue(
            TrendAlertObserver.consumerRegistration.urlPatterns
                .contains("fitme://nav/home")
        )
        XCTAssertTrue(
            TrendAlertObserver.consumerRegistration.typeIdentifiers
                .contains("trendAlert")
        )
    }

    // MARK: - Helpers

    private func keyFor(_ date: Date) -> String {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return "ft.trendAlert.fired.\(comps.yearForWeekOfYear ?? 0).w\(comps.weekOfYear ?? 0)"
    }
}
