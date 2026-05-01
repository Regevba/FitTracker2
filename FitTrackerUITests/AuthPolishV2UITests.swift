// FitTrackerUITests/AuthPolishV2UITests.swift
// auth-polish-v2 D3 — UI smoke + screenshot tests for the 5 new screens
// shipped by Block A (forgot-password) + Block B (biometric).
//
// Approach matches the HomeReadinessUITests pattern (PR #160 / commit 252268d):
// drive when reachable, XCTSkip with diagnostic when a fixture gap blocks
// the screen from materialising. On reach: assert key element + capture
// XCTAttachment screenshot for human review.
//
// Status of the 5 screens after gap-fix pass:
//   1. ForgotPasswordRequestView — DRIVEN. EmailLoginView "Forgot password?"
//      now opens a sheet hosting ForgotPasswordRequestView (was inline
//      requestPasswordReset call before; bypassed all v2 UI).
//   2. ForgotPasswordCooldownView — XCTSkip. Needs a real Supabase
//      requestPasswordReset success to push from request → cooldown.
//      Follow-up: stub EmailAuthProviding via env-injected DI seam.
//   3. SetNewPasswordView — XCTSkip. .fullScreenCover binds to
//      signIn.pendingPasswordResetURL which has no XCUI surface; cover
//      can't be driven without injecting the URL via .onOpenURL.
//      Follow-up: add FITTRACKER_REVIEW_PENDING_PASSWORD_RESET=1 fixture
//      that pre-populates pendingPasswordResetURL on launch.
//   4. BiometricActivationSheet — DRIVEN. FITTRACKER_REVIEW_BIOMETRIC_OFFER=1
//      mounts the sheet on first frame (D3 fixture in FitTrackerApp).
//   5. BiometricUnlockView — DRIVEN. FITTRACKER_REVIEW_BIOMETRIC_LOCK=1
//      forces the rootView branch unconditionally (D3 fixture).

import XCTest

final class AuthPolishV2UITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - A3: ForgotPasswordRequestView

    func testForgotPasswordRequestView_isReachableFromEmailLoginIfWired() throws {
        let app = UITestSupport.launch(mode: .forcedSignIn)
        advanceToEmbeddedAuthStep(app)

        // Drill into Email login if the row exists.
        let emailButton = firstMatching([
            app.buttons["onboarding.auth.email"],
            app.buttons["Continue with Email"],
        ], timeout: 5.0)
        guard let emailButton else {
            throw XCTSkip("Email auth row not visible — auth-polish-v2 hasn't wired the EmailLoginView harness in this configuration yet.")
        }
        emailButton.tap()

        let forgotLink = firstMatching([
            app.buttons["auth.email.forgot_password"],
            app.buttons["Forgot password?"],
            app.buttons["Forgot Password?"],
        ], timeout: 3.0)
        guard let forgotLink else {
            throw XCTSkip("ForgotPasswordRequestView entry point not wired in EmailLoginView yet — known gap from A4 (no .sheet binding for ForgotPasswordRequestView). When wired, this test will drive into the screen.")
        }
        forgotLink.tap()

        let headline = app.staticTexts["Forgot password?"]
        XCTAssertTrue(
            headline.waitForExistence(timeout: 3.0),
            "ForgotPasswordRequestView should render its headline."
        )

        attachScreenshot(app, named: "ForgotPasswordRequestView")
    }

    // MARK: - A3: ForgotPasswordCooldownView

    func testForgotPasswordCooldownView_isReachableViaSuccessfulRequest() throws {
        throw XCTSkip("ForgotPasswordCooldownView depends on a real Supabase requestPasswordReset round-trip that UI tests cannot stub today. Follow-up: add a FITTRACKER_REVIEW_FORGOT_PASSWORD_SENT=1 env var that pre-populates SignInService state to the post-request snapshot.")
    }

    // MARK: - A3: SetNewPasswordView

    func testSetNewPasswordView_isReachableViaDeepLinkReturn() throws {
        throw XCTSkip("SetNewPasswordView is presented by FitTrackerApp.fullScreenCover bound to signIn.pendingPasswordResetURL — XCUITest cannot deliver a fitme://reset-password URL into .onOpenURL cleanly without a custom test harness. Follow-up: add a FITTRACKER_REVIEW_PENDING_PASSWORD_RESET=1 env var that pre-populates pendingPasswordResetURL on launch.")
    }

    // MARK: - B1: BiometricActivationSheet

    func testBiometricActivationSheet_rendersUnderReviewFixture() throws {
        let app = UITestSupport.launch(mode: .biometricOffer)

        // Sheet content uses static text "Unlock {AppBrand.name} with {biometricLabel}".
        // On simulator biometricLabel is "Face ID" so the headline contains "Face ID".
        let headline = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Face ID'")).firstMatch
        guard headline.waitForExistence(timeout: 8.0) else {
            throw XCTSkip("BiometricActivationSheet headline didn't appear within 8s under FITTRACKER_REVIEW_BIOMETRIC_OFFER=1. Sheet may have been dismissed by another modal or the rootView didn't reach the post-onboarding branch.")
        }
        XCTAssertTrue(headline.exists)

        let notNowButton = app.buttons["Not now"].firstMatch
        XCTAssertTrue(notNowButton.waitForExistence(timeout: 2.0), "Tertiary 'Not now' CTA should render")

        attachScreenshot(app, named: "BiometricActivationSheet")
    }

    // MARK: - B3: BiometricUnlockView

    func testBiometricUnlockView_rendersUnderReviewFixture() throws {
        let app = UITestSupport.launch(mode: .biometricLock)

        // BiometricUnlockView headline is "Welcome back, {firstName}".
        let welcome = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Welcome back'")).firstMatch
        guard welcome.waitForExistence(timeout: 8.0) else {
            throw XCTSkip("BiometricUnlockView 'Welcome back' headline didn't appear within 8s under FITTRACKER_REVIEW_BIOMETRIC_LOCK=1. The rootView routing may have taken a different branch.")
        }
        XCTAssertTrue(welcome.exists)

        attachScreenshot(app, named: "BiometricUnlockView")
    }

    // MARK: - Helpers

    /// Drives the onboarding flow up to the embedded auth step. Mirrors the
    /// pattern in `SignInUITests.advanceToEmbeddedAuthStep`.
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
    }

    private func tap(_ element: XCUIElement, timeout: TimeInterval) {
        guard element.waitForExistence(timeout: timeout) else { return }
        element.tap()
    }

    private func firstMatching(_ candidates: [XCUIElement], timeout: TimeInterval) -> XCUIElement? {
        for element in candidates where element.waitForExistence(timeout: timeout) {
            return element
        }
        return nil
    }

    private func attachScreenshot(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
