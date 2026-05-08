// FitTrackerTests/AuthPolishV2Tests.swift
// auth-polish-v2 D2 — eval test cases for the Block A + Block B additions.
//
// Coverage:
//   - SignInService password reset state (A2/A3/A4/A5):
//     cooldown, attemptCount, requestedAt, deep-link URL handling, flag reset.
//   - AppSettings.hasAskedForBiometricActivation persistence (B2).
//   - AuthManager activation predicate + simulator-path activation (B2).
//   - AuthManager.attemptUnlock simulator outcome (B4).
//   - AuthManager.biometricTypeAnalytics mapping (B4).
//
// iOS Simulator bypass makes biometric paths deterministic. Tests cover
// what's deterministic on the simulator; real-device LAError reason
// classification (B4) is exercised by classifyLAError unit logic via
// the public attemptUnlock surface in production.

import XCTest
@testable import FitTracker

@MainActor
final class AuthPolishV2Tests: XCTestCase {

    // MARK: - SignInService password reset state (A5)

    func testRequestPasswordReset_success_setsCooldownAttemptCountAndTimestamp() async {
        let signIn = makeSignInService(emailProvider: StubEmailAuthProvider())

        XCTAssertEqual(signIn.passwordResetAttemptCount, 0, "starts at 0 before first request")
        XCTAssertNil(signIn.passwordResetRequestedAt)
        XCTAssertEqual(signIn.passwordResetCooldownRemaining, 0)

        await signIn.requestPasswordReset(email: "test@example.com")

        XCTAssertEqual(signIn.passwordResetAttemptCount, 1, "increments on first success")
        XCTAssertNotNil(signIn.passwordResetRequestedAt, "set on first success")
        XCTAssertGreaterThan(signIn.passwordResetCooldownRemaining, 0, "cooldown timer started")
        XCTAssertNil(signIn.authErrorMessage)
    }

    func testRequestPasswordReset_duringCooldown_doesNotIncrementAttemptOrResetTimestamp() async {
        let signIn = makeSignInService(emailProvider: StubEmailAuthProvider())
        await signIn.requestPasswordReset(email: "test@example.com")
        let firstRequestedAt = signIn.passwordResetRequestedAt

        await signIn.requestPasswordReset(email: "test@example.com")

        XCTAssertEqual(signIn.passwordResetAttemptCount, 1, "still 1 — second call short-circuited")
        XCTAssertEqual(signIn.passwordResetRequestedAt, firstRequestedAt, "timestamp preserved")
        XCTAssertNotNil(signIn.statusMessage, "status communicates cooldown to user")
    }

    func testSetNewPassword_success_clearsAttemptCountAndTimestamp() async {
        let signIn = makeSignInService(emailProvider: StubEmailAuthProvider())
        await signIn.requestPasswordReset(email: "test@example.com")
        XCTAssertEqual(signIn.passwordResetAttemptCount, 1)
        XCTAssertNotNil(signIn.passwordResetRequestedAt)

        await signIn.setNewPassword("NewPass1!")

        XCTAssertEqual(signIn.passwordResetAttemptCount, 0, "reset to 0 on success")
        XCTAssertNil(signIn.passwordResetRequestedAt, "timestamp cleared")
        XCTAssertNil(signIn.authErrorMessage)
    }

    func testHandleIncomingURL_validRecoveryURL_setsPendingURL() async {
        let signIn = makeSignInService(emailProvider: StubEmailAuthProvider())
        let url = URL(string: "fitme://reset-password?token=abc")!

        await signIn.handleIncomingURL(url)

        XCTAssertEqual(signIn.pendingPasswordResetURL, url)
        XCTAssertNil(signIn.authErrorMessage)
    }

    func testHandleIncomingURL_wrongScheme_isIgnored() async {
        let signIn = makeSignInService(emailProvider: StubEmailAuthProvider())
        let url = URL(string: "https://example.com/reset-password")!

        await signIn.handleIncomingURL(url)

        XCTAssertNil(signIn.pendingPasswordResetURL, "non-fitme schemes are dropped silently")
        XCTAssertNil(signIn.authErrorMessage)
    }

    func testHandleIncomingURL_wrongHost_isIgnored() async {
        let signIn = makeSignInService(emailProvider: StubEmailAuthProvider())
        let url = URL(string: "fitme://other-action")!

        await signIn.handleIncomingURL(url)

        XCTAssertNil(signIn.pendingPasswordResetURL)
    }

    func testHandleIncomingURL_providerThrows_setsErrorAndDoesNotSetPending() async {
        let signIn = makeSignInService(emailProvider: ThrowingEmailAuthProvider())
        let url = URL(string: "fitme://reset-password")!

        await signIn.handleIncomingURL(url)

        XCTAssertNil(signIn.pendingPasswordResetURL, "URL not stored when exchange fails")
        XCTAssertNotNil(signIn.authErrorMessage, "user sees the error")
    }

    // MARK: - AppSettings.hasAskedForBiometricActivation (B2)

    func testHasAskedForBiometricActivation_defaultsFalse() {
        UserDefaults.standard.removeObject(forKey: "ft.hasAskedForBiometricActivation")
        let settings = AppSettings()
        XCTAssertFalse(settings.hasAskedForBiometricActivation)
    }

    func testHasAskedForBiometricActivation_persistsAcrossInstances() {
        UserDefaults.standard.removeObject(forKey: "ft.hasAskedForBiometricActivation")
        let first = AppSettings()
        first.hasAskedForBiometricActivation = true

        let second = AppSettings()
        XCTAssertTrue(second.hasAskedForBiometricActivation, "persisted to UserDefaults")

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "ft.hasAskedForBiometricActivation")
    }

    // MARK: - AuthManager activation predicate (B2)

    func testShouldOfferActivation_trueWhenAvailableAndBothFlagsFalse() {
        let auth = AuthManager()
        let settings = AppSettings()
        settings.requireBiometricUnlockOnReopen = false
        settings.hasAskedForBiometricActivation = false
        // isAvailable is true on simulator
        XCTAssertTrue(auth.shouldOfferActivation(settings: settings))
    }

    func testShouldOfferActivation_falseWhenAlreadyAsked() {
        let auth = AuthManager()
        let settings = AppSettings()
        settings.requireBiometricUnlockOnReopen = false
        settings.hasAskedForBiometricActivation = true
        XCTAssertFalse(auth.shouldOfferActivation(settings: settings))

        // Cleanup
        settings.hasAskedForBiometricActivation = false
        UserDefaults.standard.removeObject(forKey: "ft.hasAskedForBiometricActivation")
    }

    func testShouldOfferActivation_falseWhenAlreadyRequired() {
        let auth = AuthManager()
        let settings = AppSettings()
        settings.requireBiometricUnlockOnReopen = true
        settings.hasAskedForBiometricActivation = false
        XCTAssertFalse(auth.shouldOfferActivation(settings: settings))

        // Cleanup
        settings.requireBiometricUnlockOnReopen = false
        UserDefaults.standard.removeObject(forKey: "ft.requireBiometricUnlockOnReopen")
    }

    func testRequestActivation_simulatorPath_setsBothFlagsAndReturnsTrue() async {
        UserDefaults.standard.removeObject(forKey: "ft.requireBiometricUnlockOnReopen")
        UserDefaults.standard.removeObject(forKey: "ft.hasAskedForBiometricActivation")
        let auth = AuthManager()
        let settings = AppSettings()

        let succeeded = await auth.requestActivation(settings: settings)

        XCTAssertTrue(succeeded, "simulator bypass returns true")
        XCTAssertTrue(settings.requireBiometricUnlockOnReopen)
        XCTAssertTrue(settings.hasAskedForBiometricActivation)

        // Cleanup
        settings.requireBiometricUnlockOnReopen = false
        settings.hasAskedForBiometricActivation = false
        UserDefaults.standard.removeObject(forKey: "ft.requireBiometricUnlockOnReopen")
        UserDefaults.standard.removeObject(forKey: "ft.hasAskedForBiometricActivation")
    }

    // MARK: - AuthManager.attemptUnlock (B4)

    func testAttemptUnlock_simulatorPath_returnsSuccessOutcome() async {
        let auth = AuthManager()

        let outcome = await auth.attemptUnlock()

        XCTAssertTrue(outcome.succeeded)
        XCTAssertGreaterThanOrEqual(outcome.durationMs, 0)
        XCTAssertNil(outcome.reason)
        XCTAssertTrue(auth.isAuthenticated, "side effect: isAuthenticated set")
    }

    // MARK: - AuthManager.biometricTypeAnalytics mapping (B4)

    func testBiometricTypeAnalytics_simulatorReportsFaceID() {
        let auth = AuthManager()
        // On simulator biometricType returns .faceID per AuthManager simulator path.
        XCTAssertEqual(auth.biometricTypeAnalytics, "face_id")
    }

    // MARK: - Helpers

    private func makeSignInService(emailProvider: EmailAuthProviding) -> SignInService {
        SignInService(
            appleProvider: StubAppleAuthProvider(),
            googleProvider: MockGoogleAuthProvider(),
            emailProvider: emailProvider,
            googleAuthAvailable: true,
            emailAuthAvailable: true
        )
    }
}

// MARK: - Stub providers

private struct StubAppleAuthProvider: AppleAuthProviding {
    func startSignIn() async throws -> UserSession {
        UserSession(
            provider: .apple,
            userID: "test-apple-user",
            displayName: "Test User",
            email: "test@example.com",
            sessionToken: "test-token",
            tokenType: .debugSimulator
        )
    }
}

/// Email provider that succeeds for every call without performing real I/O.
/// Used to exercise SignInService state-machine transitions in isolation.
private struct StubEmailAuthProvider: EmailAuthProviding {
    func register(_ draft: PendingEmailRegistration) async throws -> EmailRegistrationChallenge {
        EmailRegistrationChallenge(
            email: draft.email,
            expectedCode: "00000",
            expiresAt: Date().addingTimeInterval(600)
        )
    }
    func verify(code: String, challenge: EmailRegistrationChallenge, draft: PendingEmailRegistration) async throws -> UserSession {
        UserSession(
            provider: .email,
            userID: draft.email,
            displayName: draft.fullName,
            email: draft.email,
            sessionToken: "test-token",
            tokenType: .debugSimulator
        )
    }
    func login(email: String, password: String) async throws -> UserSession {
        UserSession(
            provider: .email,
            userID: email,
            displayName: "Test User",
            email: email,
            sessionToken: "test-token",
            tokenType: .debugSimulator
        )
    }
    func resendRegistrationCode(challenge: EmailRegistrationChallenge, draft: PendingEmailRegistration) async throws -> EmailRegistrationChallenge {
        challenge
    }
    func requestPasswordReset(email: String) async throws { /* no-op success */ }
    func updatePassword(newPassword: String) async throws { /* no-op success */ }
    func processRecoveryURL(_ url: URL) async throws { /* no-op success */ }
}

/// Email provider whose `processRecoveryURL` throws — used to assert the
/// SignInService.handleIncomingURL error path.
private struct ThrowingEmailAuthProvider: EmailAuthProviding {
    private struct E: Error { var localizedDescription: String { "Recovery URL invalid" } }
    func register(_ draft: PendingEmailRegistration) async throws -> EmailRegistrationChallenge { throw E() }
    func verify(code: String, challenge: EmailRegistrationChallenge, draft: PendingEmailRegistration) async throws -> UserSession { throw E() }
    func login(email: String, password: String) async throws -> UserSession { throw E() }
    func resendRegistrationCode(challenge: EmailRegistrationChallenge, draft: PendingEmailRegistration) async throws -> EmailRegistrationChallenge { throw E() }
    func requestPasswordReset(email: String) async throws { throw E() }
    func updatePassword(newPassword: String) async throws { throw E() }
    func processRecoveryURL(_ url: URL) async throws { throw E() }
}
