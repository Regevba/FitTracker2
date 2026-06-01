// FitTrackerTests/ReadinessAwareTrainingObserverTests.swift
// C2 feature: readiness-aware-training-alert (parent: smart-reminders).
//
// Tests cover the observer's user-facing gates (opt-out + per-day de-dupe
// + store mutation) without exercising the full async NotificationGateway
// dispatch path — that integration is deferred to a Tier 2.1 smoke test.

import XCTest
@testable import FitTracker

@MainActor
final class ReadinessAwareTrainingObserverTests: XCTestCase {

    private var observer: ReadinessAwareTrainingObserver!
    private let testDate = Date(timeIntervalSince1970: 1_780_000_000)

    override func setUp() async throws {
        try await super.setUp()
        observer = ReadinessAwareTrainingObserver()
        observer._resetForTesting(date: testDate)
    }

    override func tearDown() async throws {
        observer._resetForTesting(date: testDate)
        observer = nil
        try await super.tearDown()
    }

    // MARK: - De-dupe gate

    func test_initialState_notFiredToday() {
        XCTAssertFalse(observer.alreadyFiredToday(date: testDate))
    }

    func test_dedupeStampIsDayKeyed() {
        // After marking today fired, tomorrow's key should still be untouched
        UserDefaults.standard.set(true, forKey: keyFor(testDate))
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: testDate)!
        XCTAssertTrue(observer.alreadyFiredToday(date: testDate))
        XCTAssertFalse(observer.alreadyFiredToday(date: tomorrow),
                       "De-dupe must be per-calendar-day, not session-wide")
    }

    func test_resetForTestingClearsFiredFlag() {
        UserDefaults.standard.set(true, forKey: keyFor(testDate))
        XCTAssertTrue(observer.alreadyFiredToday(date: testDate))
        observer._resetForTesting(date: testDate)
        XCTAssertFalse(observer.alreadyFiredToday(date: testDate))
    }

    // MARK: - Feature toggle

    func test_isFeatureEnabledDefaultTrue() {
        UserDefaults.standard.removeObject(forKey: ReadinessAwareTrainingObserver.optOutKey)
        XCTAssertTrue(observer.isFeatureEnabled())
    }

    func test_isFeatureEnabledReadsUserDefaults() {
        UserDefaults.standard.set(false, forKey: ReadinessAwareTrainingObserver.optOutKey)
        XCTAssertFalse(observer.isFeatureEnabled())
        UserDefaults.standard.set(true, forKey: ReadinessAwareTrainingObserver.optOutKey)
        XCTAssertTrue(observer.isFeatureEnabled())
    }

    // MARK: - Consumer registration shape

    func test_consumerRegistrationHasStableID() {
        XCTAssertEqual(
            ReadinessAwareTrainingObserver.consumerRegistration.id,
            "push-notifications.readinessAwareTrainingAlert"
        )
        XCTAssertEqual(
            ReadinessAwareTrainingObserver.consumerRegistration.primaryCapTag,
            .standard
        )
        XCTAssertTrue(
            ReadinessAwareTrainingObserver.consumerRegistration.urlPatterns
                .contains("fitme://nav/home")
        )
    }

    // MARK: - Helpers

    private func keyFor(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return "ft.readinessAwareTrainingAlert.fired.\(fmt.string(from: date))"
    }
}
