// FitTrackerTests/AnalyticsAdaptiveIntelligenceEventsTests.swift
// D1 (adaptive-intelligence-next-pass) T8 — analytics event-naming + param contract.
//
// Asserts that the 4 new home_ai_feedback_* event names + 3 new params land
// at the canonical screen-prefixed strings and survive future renames.

import XCTest
@testable import FitTracker

final class AnalyticsAdaptiveIntelligenceEventsTests: XCTestCase {

    func testEventNamesAreScreenPrefixed() {
        XCTAssertEqual(
            AnalyticsEvent.homeAiFeedbackSignalUnsuppressedByTrend,
            "home_ai_feedback_signal_unsuppressed_by_trend")
        XCTAssertEqual(
            AnalyticsEvent.homeAiFeedbackSuppressedDetailOpened,
            "home_ai_feedback_suppressed_detail_opened")
        XCTAssertEqual(
            AnalyticsEvent.homeAiFeedbackSignalManuallyUnsuppressed,
            "home_ai_feedback_signal_manually_unsuppressed")
        XCTAssertEqual(
            AnalyticsEvent.homeAiFeedbackSignalBlacklistedPermanently,
            "home_ai_feedback_signal_blacklisted_permanently")
    }

    func testNewParamNames() {
        XCTAssertEqual(AnalyticsParam.priorDismissalCount, "prior_dismissal_count")
        XCTAssertEqual(AnalyticsParam.daysSinceLastDismiss, "days_since_last_dismiss")
        XCTAssertEqual(AnalyticsParam.viaTrend, "via_trend")
    }
}
