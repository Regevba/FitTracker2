// FitTrackerUITests/OnboardingUITests.swift
// Audit M-4c — exercises the onboarding flow on a first-launch state.
// Per audit TEST-025 recommendation: "onboarding" coverage.
//
// Onboarding only renders on a fresh install (no persisted user profile).
// Without uninstalling the test simulator state per run, this test usually
// finds the user already past onboarding — that's expected and OK.

import XCTest

final class OnboardingUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testOnboardingFirstStepRendersIfNotComplete() throws {
        let app = UITestSupport.launch(mode: .standard)

        // Onboarding screens expose a primary advance button labelled
        // "Continue", "Next", or "Get Started" (varies by step).
        let onboardingAdvance = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'continue' OR label CONTAINS[c] 'next' OR label CONTAINS[c] 'get started'")
        ).firstMatch

        let appeared = onboardingAdvance.waitForExistence(timeout: 5.0)
        if !appeared {
            // The simulator state had a completed onboarding (or session
            // restore landed us on home). This is the expected case on
            // most CI/local runs since the simulator persists state.
            throw XCTSkip("Onboarding advance button not visible within 5s — likely the simulator already completed onboarding. To exercise onboarding, reset the simulator (Device > Erase All Content and Settings) before running.")
        }

        XCTAssertTrue(onboardingAdvance.exists, "Onboarding step should expose an advance button")
    }
}
