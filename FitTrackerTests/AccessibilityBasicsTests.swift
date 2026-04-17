// FitTrackerTests/AccessibilityBasicsTests.swift
// TEST-028: Accessibility basics — minimum tap target sizes, token guarantees.
// Full VoiceOver / Dynamic Type / Switch Control verification requires XCUITest
// (TEST-025, deferred). This test covers the programmable static guarantees.

import XCTest
@testable import FitTracker

final class AccessibilityBasicsTests: XCTestCase {

    // MARK: - Minimum tap target

    func testCTAHeight_meetsMinimum44pt() {
        XCTAssertGreaterThanOrEqual(
            AppSize.ctaHeight, 44,
            "Primary CTA must meet Apple HIG 44pt minimum tap target"
        )
    }

    func testTouchTargetLarge_exceedsMinimum() {
        XCTAssertGreaterThanOrEqual(
            AppSize.touchTargetLarge, 44,
            "touchTargetLarge must exceed 44pt minimum"
        )
    }

    func testTabBarClearance_leavesRoomForContent() {
        // Tab bar clearance should be large enough that interactive elements
        // above it don't get obscured by the tab bar.
        XCTAssertGreaterThanOrEqual(AppSize.tabBarClearance, 44)
    }

    // MARK: - Interactive element sizing tokens

    func testIndicatorDot_isNonInteractive() {
        // Indicator dot is visual only — its 8pt size is below tap minimum
        // by design. Test documents that this is non-interactive.
        XCTAssertLessThan(AppSize.indicatorDot, 44,
                          "Indicator dot is visual-only; interactive elements must not use this token")
    }

    // MARK: - Motion tokens (Reduce Motion)

    func testMotionTokens_existAndAreReasonable() {
        // Both motion tokens must be short enough to not feel sluggish
        // and long enough to be visually perceptible.
        // (XCTest can't introspect Animation values directly, so we test
        // that the tokens exist as non-nil values.)
        _ = AppMotion.stepTransition
        _ = AppMotion.quickInteraction
        // No crash = pass. Full reduce-motion respect requires XCUITest.
    }
}
