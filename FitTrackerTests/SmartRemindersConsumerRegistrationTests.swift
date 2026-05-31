// FitTrackerTests/SmartRemindersConsumerRegistrationTests.swift
// Tests for the C1 first slice — smart-reminders consumer registration.

import XCTest
@testable import FitTracker

@MainActor
final class SmartRemindersConsumerRegistrationTests: XCTestCase {

    override func setUp() {
        super.setUp()
        NotificationConsumerRegistry.shared.reset()
    }

    override func tearDown() {
        NotificationConsumerRegistry.shared.reset()
        super.tearDown()
    }

    // MARK: - Consumer descriptor shape

    func test_consumer_hasStableID() {
        XCTAssertEqual(SmartRemindersConsumerRegistration.consumerID, "smart-reminders")
        XCTAssertEqual(SmartRemindersConsumerRegistration.consumer().id, "smart-reminders")
    }

    func test_consumer_typeIdentifiersCoverEveryReminderType() {
        let descriptor = SmartRemindersConsumerRegistration.consumer()
        let typeIDs = Set(descriptor.typeIdentifiers)
        let expected = Set(ReminderType.allCases.map(\.rawValue))
        XCTAssertEqual(typeIDs, expected)
    }

    func test_consumer_urlPatternsCoverEveryReminderTypeDeepLink() {
        let descriptor = SmartRemindersConsumerRegistration.consumer()
        let patterns = Set(descriptor.urlPatterns)
        let expected = Set(ReminderType.allCases.map(\.deepLink))
        XCTAssertEqual(patterns, expected)
    }

    func test_consumer_primaryCapTagIsStandard() {
        XCTAssertEqual(SmartRemindersConsumerRegistration.consumer().primaryCapTag, .standard)
    }

    // MARK: - Registration

    func test_registerAtAppInit_succeedsOnCleanRegistry() {
        let ok = SmartRemindersConsumerRegistration.registerAtAppInit()
        XCTAssertTrue(ok)

        let registered = NotificationConsumerRegistry.shared.consumer(forID: "smart-reminders")
        XCTAssertNotNil(registered)
        XCTAssertEqual(registered?.id, "smart-reminders")
        XCTAssertEqual(registered?.displayName, "Smart Reminders")
    }

    func test_registerAtAppInit_isIdempotent() {
        let first = SmartRemindersConsumerRegistration.registerAtAppInit()
        let second = SmartRemindersConsumerRegistration.registerAtAppInit()
        let third = SmartRemindersConsumerRegistration.registerAtAppInit()
        XCTAssertTrue(first)
        XCTAssertTrue(second)
        XCTAssertTrue(third)
        XCTAssertEqual(NotificationConsumerRegistry.shared.consumers.count, 1)
    }

    func test_registerAtAppInit_failsOnCollidingPattern() {
        // Pre-register a different consumer that claims one of smart-reminders'
        // URLs. smart-reminders registration should then fail (and the pre-existing
        // consumer's claim must survive).
        let interloper = NotificationConsumerRegistry.Consumer(
            id: "interloper",
            displayName: "Interloper",
            typeIdentifiers: ["interloper"],
            urlPatterns: ["fitme://training"],
            primaryCapTag: .standard
        )
        XCTAssertTrue(NotificationConsumerRegistry.shared.register(interloper))

        let smartOK = SmartRemindersConsumerRegistration.registerAtAppInit()
        XCTAssertFalse(smartOK)
        XCTAssertNil(NotificationConsumerRegistry.shared.consumer(forID: "smart-reminders"))
        XCTAssertNotNil(NotificationConsumerRegistry.shared.consumer(forID: "interloper"))
    }
}
