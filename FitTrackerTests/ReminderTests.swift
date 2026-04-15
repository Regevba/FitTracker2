// FitTrackerTests/ReminderTests.swift
// T12 — Unit tests for ReminderType enum: completeness, metadata,
// frequency caps, deep links, raw values, and Codable round-trip.

import XCTest
@testable import FitTracker

final class ReminderTests: XCTestCase {

    // T12-1: ReminderType enum completeness
    func testReminderTypeCount() {
        XCTAssertEqual(ReminderType.allCases.count, 6, "Should have 6 reminder types")
    }

    // T12-2: Each type has a non-empty title
    func testReminderTypeTitles() {
        for type in ReminderType.allCases {
            XCTAssertFalse(type.title.isEmpty, "\(type.rawValue) should have a non-empty title")
        }
    }

    // T12-3: Each type has a deep link starting with fitme://
    func testReminderTypeDeepLinks() {
        for type in ReminderType.allCases {
            XCTAssertTrue(
                type.deepLink.hasPrefix("fitme://"),
                "\(type.rawValue) deep link should start with fitme://"
            )
        }
    }

    // T12-4: maxPerDay is at least 1 for every type
    func testReminderTypeMaxPerDay() {
        for type in ReminderType.allCases {
            XCTAssertGreaterThanOrEqual(
                type.maxPerDay, 1,
                "\(type.rawValue) maxPerDay should be >= 1"
            )
        }
    }

    // T12-5: Lifetime-limited types have the expected caps; unlimited types return nil
    func testReminderTypeLifetimeLimits() {
        XCTAssertEqual(ReminderType.healthKitConnect.maxLifetime, 3)
        XCTAssertEqual(ReminderType.accountRegistration.maxLifetime, 3)
        XCTAssertEqual(ReminderType.engagement.maxLifetime, 3)
        XCTAssertNil(ReminderType.nutritionGap.maxLifetime,  "nutritionGap should be unlimited")
        XCTAssertNil(ReminderType.trainingDay.maxLifetime,   "trainingDay should be unlimited")
        XCTAssertNil(ReminderType.restDay.maxLifetime,       "restDay should be unlimited")
    }

    // T12-6: Raw values use snake_case (no spaces, all lowercase)
    func testReminderTypeRawValues() {
        for type in ReminderType.allCases {
            XCTAssertFalse(
                type.rawValue.contains(" "),
                "\(type.rawValue) should not contain spaces"
            )
            XCTAssertEqual(
                type.rawValue, type.rawValue.lowercased(),
                "\(type.rawValue) should be lowercase"
            )
        }
    }

    // T12-7: Codable round-trip preserves identity for every case
    func testReminderTypeCodable() throws {
        for type in ReminderType.allCases {
            let encoded = try JSONEncoder().encode(type)
            let decoded = try JSONDecoder().decode(ReminderType.self, from: encoded)
            XCTAssertEqual(type, decoded, "\(type.rawValue) should survive a Codable round-trip")
        }
    }

    // T12-8: Nutrition gap routes to the nutrition tab
    func testNutritionGapDeepLink() {
        XCTAssertEqual(ReminderType.nutritionGap.deepLink, "fitme://nutrition")
    }

    // T12-9: Training day routes to the training tab
    func testTrainingDayDeepLink() {
        XCTAssertEqual(ReminderType.trainingDay.deepLink, "fitme://training")
    }

    // T12-10: Rest day routes to home
    func testRestDayDeepLink() {
        XCTAssertEqual(ReminderType.restDay.deepLink, "fitme://home")
    }
}
