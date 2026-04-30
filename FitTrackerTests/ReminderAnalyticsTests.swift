// FitTrackerTests/ReminderAnalyticsTests.swift
// Verifies the analytics instrumentation added to the smart-reminder pipeline:
//   - AnalyticsService.logReminder{Shown,Tapped,Dismissed,Disabled,Suppressed,Scheduled}
//   - ReminderScheduler.cancel{All,(type:)} fire reminder_disabled with reason
//   - ReminderNotificationDelegate.postDeepLinkNotification posts on the right Name
//
// We don't construct UNNotification objects (they have private inits).
// Instead, we verify the AnalyticsService logging surface + scheduler hooks +
// the static deep-link helper.

import XCTest
import UserNotifications
@testable import FitTracker

@MainActor
final class ReminderAnalyticsTests: XCTestCase {

    // MARK: - Test fixtures

    private var mock: MockAnalyticsAdapter!
    private var service: AnalyticsService!

    override func setUp() {
        super.setUp()
        mock = MockAnalyticsAdapter()
        let consent = ConsentManager()
        consent.grantConsent()
        service = AnalyticsService(provider: mock, consent: consent)
    }

    override func tearDown() {
        ReminderScheduler.shared.analytics = nil
        mock = nil
        service = nil
        super.tearDown()
    }

    // MARK: - AnalyticsService helpers

    func testLogReminderShown_logsCorrectEventAndType() {
        service.logReminderShown(type: ReminderType.healthKitConnect.rawValue)
        let events = mock.capturedEvents.filter { $0.name == AnalyticsEvent.reminderShown }
        XCTAssertEqual(events.count, 1)
        let cat = events.first?.parameters?[AnalyticsParam.itemCategory] as? String
        XCTAssertEqual(cat, "healthkit_connect")
    }

    func testLogReminderTapped_logsCorrectEvent() {
        service.logReminderTapped(type: ReminderType.engagement.rawValue)
        let events = mock.capturedEvents.filter { $0.name == AnalyticsEvent.reminderTapped }
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.parameters?[AnalyticsParam.itemCategory] as? String, "engagement")
    }

    func testLogReminderDismissed_logsCorrectEvent() {
        service.logReminderDismissed(type: ReminderType.nutritionGap.rawValue)
        let events = mock.capturedEvents.filter { $0.name == AnalyticsEvent.reminderDismissed }
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.parameters?[AnalyticsParam.itemCategory] as? String, "nutrition_gap")
    }

    func testLogReminderDisabled_logsTypeAndReason() {
        service.logReminderDisabled(type: ReminderType.accountRegistration.rawValue, reason: "test_reason")
        let events = mock.capturedEvents.filter { $0.name == AnalyticsEvent.reminderDisabled }
        XCTAssertEqual(events.count, 1)
        let params = events.first?.parameters
        XCTAssertEqual(params?[AnalyticsParam.itemCategory] as? String, "account_registration")
        XCTAssertEqual(params?["reason"] as? String, "test_reason")
    }

    func testLogReminderSuppressed_logsTypeAndReason() {
        service.logReminderSuppressed(type: ReminderType.restDay.rawValue, reason: "quiet_hours")
        let events = mock.capturedEvents.filter { $0.name == AnalyticsEvent.reminderSuppressed }
        XCTAssertEqual(events.count, 1)
        let params = events.first?.parameters
        XCTAssertEqual(params?[AnalyticsParam.itemCategory] as? String, "rest_day")
        XCTAssertEqual(params?["reason"] as? String, "quiet_hours")
    }

    func testLogReminderScheduled_logsTypeOnly() {
        service.logReminderScheduled(type: ReminderType.trainingDay.rawValue)
        let events = mock.capturedEvents.filter { $0.name == AnalyticsEvent.reminderScheduled }
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.parameters?[AnalyticsParam.itemCategory] as? String, "training_day")
    }

    func testReminderEvents_areGatedByConsent() {
        // Re-create service with consent denied
        let consent = ConsentManager()
        consent.denyConsent()
        let gatedService = AnalyticsService(provider: mock, consent: consent)
        mock.reset()

        gatedService.logReminderShown(type: "x")
        gatedService.logReminderTapped(type: "x")
        gatedService.logReminderDismissed(type: "x")
        gatedService.logReminderDisabled(type: "x", reason: "y")
        gatedService.logReminderSuppressed(type: "x", reason: "y")
        gatedService.logReminderScheduled(type: "x")

        XCTAssertTrue(mock.capturedEvents.isEmpty,
                      "All reminder events must be gated by consent; none should fire when denied")
    }

    // MARK: - ReminderScheduler — cancel paths

    func testCancelAll_logsReminderDisabledWithCancelAllReason() {
        ReminderScheduler.shared.analytics = service
        ReminderScheduler.shared.cancelAll()

        let events = mock.capturedEvents.filter { $0.name == AnalyticsEvent.reminderDisabled }
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.parameters?[AnalyticsParam.itemCategory] as? String, "all")
        XCTAssertEqual(events.first?.parameters?["reason"] as? String, "cancel_all")
    }

    func testCancelType_logsReminderDisabledWithCancelTypeReason() {
        ReminderScheduler.shared.analytics = service
        ReminderScheduler.shared.cancel(type: .nutritionGap)

        let events = mock.capturedEvents.filter { $0.name == AnalyticsEvent.reminderDisabled }
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.parameters?[AnalyticsParam.itemCategory] as? String, "nutrition_gap")
        XCTAssertEqual(events.first?.parameters?["reason"] as? String, "cancel_type")
    }

    func testNilAnalytics_doesNotCrashOnCancel() {
        // Default state — analytics not injected
        ReminderScheduler.shared.analytics = nil
        ReminderScheduler.shared.cancelAll()
        ReminderScheduler.shared.cancel(type: .engagement)
        // Nothing to assert — must simply not crash.
    }

    // MARK: - Deep-link Notification

    func testFitMeReminderTappedNotification_isExposed() {
        XCTAssertEqual(Notification.Name.fitMeReminderTapped.rawValue, "fitme.reminder.tapped")
    }

    func testPostDeepLinkNotification_postsExpectedPayload() {
        let exp = expectation(description: "fitMeReminderTapped received")
        var receivedType: String?
        var receivedDeepLink: String?

        let observer = NotificationCenter.default.addObserver(
            forName: .fitMeReminderTapped,
            object: nil,
            queue: .main
        ) { note in
            receivedType = note.userInfo?["type"] as? String
            receivedDeepLink = note.userInfo?["deepLink"] as? String
            exp.fulfill()
        }

        ReminderNotificationDelegate.postDeepLinkNotification(
            type: .nutritionGap,
            userInfo: [:]
        )

        wait(for: [exp], timeout: 1.0)
        NotificationCenter.default.removeObserver(observer)

        XCTAssertEqual(receivedType, "nutrition_gap")
        XCTAssertEqual(receivedDeepLink, "fitme://nutrition")
    }

    func testPostDeepLinkNotification_carriesPayloadWhenPresent() {
        let exp = expectation(description: "fitMeReminderTapped with payload")
        var receivedPayload: String?

        let observer = NotificationCenter.default.addObserver(
            forName: .fitMeReminderTapped,
            object: nil,
            queue: .main
        ) { note in
            receivedPayload = note.userInfo?["payload"] as? String
            exp.fulfill()
        }

        ReminderNotificationDelegate.postDeepLinkNotification(
            type: .accountRegistration,
            userInfo: ["payload": "extra-data"]
        )

        wait(for: [exp], timeout: 1.0)
        NotificationCenter.default.removeObserver(observer)

        XCTAssertEqual(receivedPayload, "extra-data")
    }

    // MARK: - ReminderNotificationDelegate — analytics injection

    func testDelegate_setAnalytics_holdsReference() {
        let delegate = ReminderNotificationDelegate()
        XCTAssertNil(delegate.analytics)
        delegate.setAnalytics(service)
        XCTAssertNotNil(delegate.analytics)
        delegate.setAnalytics(nil)
        XCTAssertNil(delegate.analytics)
    }
}
