// FitTrackerUITests/SignInUITests.swift
// Audit M-4c — verifies the sign-in screen renders + has tappable provider
// buttons when auto-login is disabled (FITTRACKER_SKIP_AUTO_LOGIN=1).
// Per audit TEST-025 recommendation: "sign-in" coverage.

import XCTest

final class SignInUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testSignInScreenRendersWhenAutoLoginDisabled() throws {
        let app = UITestSupport.launch(mode: .forcedSignIn)

        advanceToEmbeddedAuthStep(app)

        let candidateButtons: [(label: String, element: XCUIElement)] = [
            ("onboarding.auth.email", app.buttons["onboarding.auth.email"]),
            ("onboarding.auth.google", app.buttons["onboarding.auth.google"]),
            ("onboarding.auth.apple", app.buttons["onboarding.auth.apple"]),
            ("Continue with Email", app.buttons["Continue with Email"]),
            ("Continue with Google", app.buttons["Continue with Google"]),
            ("Continue with Apple", app.buttons["Continue with Apple"]),
        ]

        var foundLabel: String?
        for (label, element) in candidateButtons where element.waitForExistence(timeout: 2.0) {
            foundLabel = label
            break
        }

        XCTAssertNotNil(
            foundLabel,
            "No onboarding auth surface action was found after advancing through onboarding with FITTRACKER_SKIP_AUTO_LOGIN=1."
        )
    }

    private func advanceToEmbeddedAuthStep(_ app: XCUIApplication) {
        tap(app.buttons["Get Started"], timeout: 5.0)
        tap(app.buttons["Build Muscle"], timeout: 5.0)
        tap(app.buttons["Continue"], timeout: 5.0)
        tap(app.buttons["Beginner"], timeout: 5.0)
        tap(app.buttons["3 days per week"], timeout: 5.0)
        tap(app.buttons["Continue"], timeout: 5.0)

        let healthSkip = app.buttons["Skip"]
        if healthSkip.waitForExistence(timeout: 5.0) {
            healthSkip.tap()
        } else {
            tap(app.buttons["Connect Apple Health"], timeout: 5.0)
        }

        let continueWithout = app.buttons["Continue Without"]
        if continueWithout.waitForExistence(timeout: 5.0) {
            continueWithout.tap()
        } else {
            tap(app.buttons["Accept & Continue"], timeout: 5.0)
        }

        XCTAssertTrue(
            app.staticTexts["Save your progress"].waitForExistence(timeout: 5.0),
            "Expected onboarding auth step to appear after completing the pre-auth onboarding steps."
        )
    }

    private func tap(_ element: XCUIElement, timeout: TimeInterval, file: StaticString = #file, line: UInt = #line) {
        XCTAssertTrue(
            element.waitForExistence(timeout: timeout),
            "Expected element '\(element)' to exist before tapping.",
            file: file,
            line: line
        )
        element.tap()
    }
}
