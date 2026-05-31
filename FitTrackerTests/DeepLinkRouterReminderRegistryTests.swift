// FitTrackerTests/DeepLinkRouterReminderRegistryTests.swift
// Verifies the smart-reminders deep-link registry now owned by
// DeepLinkRouter (C1 item #3, L207 backlog).

import XCTest
@testable import FitTracker

final class DeepLinkRouterReminderRegistryTests: XCTestCase {

    // MARK: - Backward-compat: behavior preserved after delegating

    func test_healthKitConnect_routesToSettingsHealth() {
        XCTAssertEqual(
            DeepLinkRouter.deepLinkURL(forReminderTypeRawValue: "healthkit_connect"),
            "fitme://settings/health"
        )
    }

    func test_accountRegistration_routesToAuth() {
        XCTAssertEqual(
            DeepLinkRouter.deepLinkURL(forReminderTypeRawValue: "account_registration"),
            "fitme://auth"
        )
    }

    func test_nutritionGap_routesToNutrition() {
        XCTAssertEqual(
            DeepLinkRouter.deepLinkURL(forReminderTypeRawValue: "nutrition_gap"),
            "fitme://nutrition"
        )
    }

    func test_trainingDay_routesToTraining() {
        XCTAssertEqual(
            DeepLinkRouter.deepLinkURL(forReminderTypeRawValue: "training_day"),
            "fitme://training"
        )
    }

    func test_restDay_routesToHome() {
        XCTAssertEqual(
            DeepLinkRouter.deepLinkURL(forReminderTypeRawValue: "rest_day"),
            "fitme://home"
        )
    }

    func test_engagement_routesToHome() {
        XCTAssertEqual(
            DeepLinkRouter.deepLinkURL(forReminderTypeRawValue: "engagement"),
            "fitme://home"
        )
    }

    // MARK: - Resilience

    func test_unknownRawValue_fallsBackToHome() {
        XCTAssertEqual(
            DeepLinkRouter.deepLinkURL(forReminderTypeRawValue: "totally_made_up_type"),
            "fitme://home"
        )
        XCTAssertEqual(
            DeepLinkRouter.deepLinkURL(forReminderTypeRawValue: ""),
            "fitme://home"
        )
    }

    // MARK: - Round-trip via ReminderType

    @MainActor
    func test_reminderTypeDeepLink_delegatesToRouter() {
        for type in ReminderType.allCases {
            let routerURL = DeepLinkRouter.deepLinkURL(forReminderTypeRawValue: type.rawValue)
            XCTAssertEqual(
                type.deepLink, routerURL,
                "ReminderType.deepLink for \(type) should match router registry"
            )
        }
    }
}
