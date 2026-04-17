// FitTrackerTests/AuthManagerTests.swift
// TEST-002: AuthManager — simulator bypass + state transitions.
//
// iOS Simulator bypass makes biometric auth deterministic: isAvailable
// always returns true and authenticateForQuickUnlock() succeeds unconditionally.
// Tests cover this deterministic path; real-device biometric paths require
// a physical device and are not covered here.

import XCTest
import LocalAuthentication
@testable import FitTracker

@MainActor
final class AuthManagerTests: XCTestCase {

    // MARK: - Initial state

    func testInit_startsUnauthenticated() {
        let auth = AuthManager()
        XCTAssertFalse(auth.isAuthenticated)
        XCTAssertNil(auth.authError)
    }

    // MARK: - Simulator bypass

    func testAuthenticateForQuickUnlock_simulator_succeeds() async {
        let auth = AuthManager()
        let result = await auth.authenticateForQuickUnlock()

        #if targetEnvironment(simulator)
        XCTAssertTrue(result, "Simulator bypass must return true")
        XCTAssertTrue(auth.isAuthenticated)
        XCTAssertNil(auth.authError)
        #endif
    }

    func testIsAvailable_simulator_returnsTrue() {
        let auth = AuthManager()
        #if targetEnvironment(simulator)
        XCTAssertTrue(auth.isAvailable, "Simulator reports biometric as available")
        #endif
    }

    func testBiometricType_simulator_reportsFaceID() {
        let auth = AuthManager()
        #if targetEnvironment(simulator)
        XCTAssertEqual(auth.biometricType, .faceID, "Simulator reports Face ID by default")
        #endif
    }

    // MARK: - Lock cycle

    func testLockOnBackground_clearsAuthenticatedState() async {
        let auth = AuthManager()
        _ = await auth.authenticateForQuickUnlock()
        XCTAssertTrue(auth.isAuthenticated)

        auth.lockOnBackground()
        XCTAssertFalse(auth.isAuthenticated)
        XCTAssertNil(auth.authError)
    }

    func testLockOnBackground_withoutClearingSession_keepsCryptoContext() async {
        let auth = AuthManager()
        _ = await auth.authenticateForQuickUnlock()

        // lockOnBackground(clearCryptoSession: false) — used for brief background events
        auth.lockOnBackground(clearCryptoSession: false)
        XCTAssertFalse(auth.isAuthenticated,
                       "UI state must still flip to locked even when crypto session is kept")
    }

    // MARK: - Error clearing

    func testAuthenticate_clearsPreviousError() async {
        let auth = AuthManager()
        auth.authError = "stale error from previous attempt"

        _ = await auth.authenticateForQuickUnlock()

        #if targetEnvironment(simulator)
        XCTAssertNil(auth.authError, "Successful auth must clear prior error")
        #endif
    }

    // MARK: - Biometric labels

    func testBiometricLabels_faceIDOnSimulator() {
        let auth = AuthManager()
        #if targetEnvironment(simulator)
        XCTAssertEqual(auth.biometricLabel, "Use Face ID")
        XCTAssertEqual(auth.biometricName, "Face ID")
        XCTAssertEqual(auth.biometricIcon, "faceid")
        #endif
    }
}
