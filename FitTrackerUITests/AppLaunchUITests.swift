// FitTrackerUITests/AppLaunchUITests.swift
// Bootstrap XCUITest. Proves the UI test target compiles, links, and can drive
// the FitTracker app via XCUIApplication. Asserts only that the app reaches
// `.runningForeground` — predicate-on-content assertions belong in M-4b/c
// where the launch fixture state is owned.
// Audit M-4a (TEST-025).

import XCTest

final class AppLaunchUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAppLaunches() throws {
        let app = XCUIApplication()
        app.launch()

        let foregrounded = app.wait(for: .runningForeground, timeout: 10.0)
        XCTAssertTrue(
            foregrounded,
            "App did not reach .runningForeground within 10s of launch."
        )
    }
}
