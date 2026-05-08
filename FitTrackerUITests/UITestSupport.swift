// FitTrackerUITests/UITestSupport.swift
// Shared launch helpers for UI tests. Wraps XCUIApplication with the
// FitTracker-specific environment knobs (FITTRACKER_REVIEW_AUTH,
// FITTRACKER_SKIP_AUTO_LOGIN, FITTRACKER_FORCE_ONBOARDING) discovered in
// FitTrackerApp.swift +
// SignInService.swift.
// Audit M-4 (TEST-025).

import XCTest

enum LaunchMode {
    case authenticated      // FITTRACKER_REVIEW_AUTH=authenticated → app skips auth, opens to home
    case settingsReview     // FITTRACKER_REVIEW_AUTH=settings → app opens to settings tab
    case forcedSignIn       // Skip auto-login + force onboarding so the embedded auth step is deterministic
    case biometricOffer     // FITTRACKER_REVIEW_BIOMETRIC_OFFER=1 → mounts BiometricActivationSheet on first frame (auth-polish-v2 D3)
    case biometricLock      // FITTRACKER_REVIEW_BIOMETRIC_LOCK=1 → routes rootView into BiometricUnlockView (auth-polish-v2 D3)
    case standard           // No env overrides — app launches as a real first-time user would
}

enum UITestSupport {
    /// Launch the app with the requested mode + return the running app.
    /// Asserts the app reaches `.runningForeground` within 10s.
    @discardableResult
    static func launch(mode: LaunchMode = .standard, file: StaticString = #file, line: UInt = #line) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment = launchEnvironment(for: mode)
        app.launch()

        let foregrounded = app.wait(for: .runningForeground, timeout: 10.0)
        XCTAssertTrue(
            foregrounded,
            "App did not reach .runningForeground within 10s for mode \(mode)",
            file: file, line: line
        )

        return app
    }

    private static func launchEnvironment(for mode: LaunchMode) -> [String: String] {
        switch mode {
        case .authenticated:
            return ["FITTRACKER_REVIEW_AUTH": "authenticated"]
        case .settingsReview:
            return ["FITTRACKER_REVIEW_AUTH": "settings"]
        case .forcedSignIn:
            return [
                "FITTRACKER_SKIP_AUTO_LOGIN": "1",
                "FITTRACKER_FORCE_ONBOARDING": "1",
            ]
        case .biometricOffer:
            // Bypass onboarding so the rootView's app branch renders, then
            // FITTRACKER_REVIEW_BIOMETRIC_OFFER mounts the activation sheet
            // on first frame.
            return [
                "FITTRACKER_REVIEW_AUTH": "authenticated",
                "FITTRACKER_REVIEW_BIOMETRIC_OFFER": "1",
            ]
        case .biometricLock:
            // Force the rootView's BiometricUnlockView branch unconditionally.
            return [
                "FITTRACKER_REVIEW_AUTH": "authenticated",
                "FITTRACKER_REVIEW_BIOMETRIC_LOCK": "1",
            ]
        case .standard:
            return [:]
        }
    }
}
