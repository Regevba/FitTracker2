// FitTrackerTests/AnalyticsEventNamingTests.swift
// auth-polish-v2 D4 — naming-convention unit tests for AnalyticsEvent /
// AnalyticsScreen / AnalyticsParam constants.
//
// Project rule (CLAUDE.md → "Analytics Naming Convention", est. 2026-04-08):
// every event tied to a specific screen MUST start with that screen's prefix:
//   home_*, nutrition_*, training_*, stats_*, settings_*, onboarding_*, auth_*
// Plus extension prefixes for additional surfaces:
//   profile_*, import_*, reminder_*
// Cross-screen lifecycle and GA4 recommended events stay unprefixed.
//
// These tests guard two things:
// (1) all 9 auth-polish-v2 events fired by A5+B4 carry the auth_ prefix,
// (2) the AnalyticsParam + AnalyticsScreen + AnalyticsEvent constants used
//     by auth-polish-v2 conform to the snake_case + max-40-chars GA4 rule.

import XCTest
@testable import FitTracker

final class AnalyticsEventNamingTests: XCTestCase {

    // MARK: - auth-polish-v2 event prefix compliance

    /// All 9 events shipped by auth-polish-v2 (A5 + B4) must start with auth_.
    func testAuthPolishV2_allEventsCarryAuthPrefix() {
        let authPolishV2Events: [String] = [
            // A5 — forgot password
            AnalyticsEvent.authPasswordResetRequested,
            AnalyticsEvent.authPasswordResetCompleted,
            AnalyticsEvent.authPasswordResetResend,
            AnalyticsEvent.authPasswordResetResendBlocked,
            // B4 — biometric
            AnalyticsEvent.authBiometricActivationOffered,
            AnalyticsEvent.authBiometricActivated,
            AnalyticsEvent.authBiometricActivationDeclined,
            AnalyticsEvent.authBiometricUnlockCompleted,
            AnalyticsEvent.authBiometricUnlockFailed,
        ]
        XCTAssertEqual(authPolishV2Events.count, 9)
        for name in authPolishV2Events {
            XCTAssertTrue(
                name.hasPrefix("auth_"),
                "auth-polish-v2 event '\(name)' must carry the auth_ prefix"
            )
        }
    }

    // MARK: - GA4 length + character rule

    /// GA4 caps event names at 40 characters and requires snake_case.
    func testAuthPolishV2_eventNamesUnder40CharsAndSnakeCase() {
        let names: [String] = [
            AnalyticsEvent.authPasswordResetRequested,
            AnalyticsEvent.authPasswordResetCompleted,
            AnalyticsEvent.authPasswordResetResend,
            AnalyticsEvent.authPasswordResetResendBlocked,
            AnalyticsEvent.authBiometricActivationOffered,
            AnalyticsEvent.authBiometricActivated,
            AnalyticsEvent.authBiometricActivationDeclined,
            AnalyticsEvent.authBiometricUnlockCompleted,
            AnalyticsEvent.authBiometricUnlockFailed,
        ]
        for name in names {
            XCTAssertLessThanOrEqual(name.count, 40, "GA4 event name limit: \(name) is \(name.count) chars")
            XCTAssertTrue(
                isSnakeCase(name),
                "GA4 requires snake_case lowercase ASCII letters, digits, underscores: \(name)"
            )
        }
    }

    // MARK: - Param + Screen names

    /// Params introduced by A5 + B4 must be snake_case + ≤40 chars.
    func testAuthPolishV2_paramsAreSnakeCaseAndUnderLimit() {
        let names: [String] = [
            // A5
            AnalyticsParam.emailProvided,
            AnalyticsParam.timeToCompleteSeconds,
            AnalyticsParam.cooldownRemainingSeconds,
            AnalyticsParam.attemptNumber,
            // B4
            AnalyticsParam.biometricType,
            AnalyticsParam.provider,
            AnalyticsParam.durationMs,
        ]
        for name in names {
            XCTAssertLessThanOrEqual(name.count, 40)
            XCTAssertTrue(
                isSnakeCase(name),
                "Param '\(name)' must be snake_case lowercase ASCII"
            )
        }
    }

    /// Screen names introduced by A5 + B4 must be snake_case + ≤40 chars.
    func testAuthPolishV2_screensAreSnakeCaseAndUnderLimit() {
        let names: [String] = [
            // A5
            AnalyticsScreen.forgotPassword,
            AnalyticsScreen.emailSentConfirmation,
            AnalyticsScreen.setNewPassword,
            // B4
            AnalyticsScreen.biometricActivationSheet,
            AnalyticsScreen.biometricUnlock,
        ]
        for name in names {
            XCTAssertLessThanOrEqual(name.count, 40)
            XCTAssertTrue(
                isSnakeCase(name),
                "Screen '\(name)' must be snake_case lowercase ASCII"
            )
        }
    }

    // MARK: - Conversion event registration

    /// PRD §Analytics Spec marks 2 of the 9 new events as conversions:
    /// auth_password_reset_completed (A5) and auth_biometric_activated (B4).
    /// Both must be present in AnalyticsConversion.events.
    func testAuthPolishV2_conversionsRegistered() {
        let registered = Set(AnalyticsConversion.events)
        XCTAssertTrue(
            registered.contains(AnalyticsEvent.authPasswordResetCompleted),
            "auth_password_reset_completed must be a conversion event"
        )
        XCTAssertTrue(
            registered.contains(AnalyticsEvent.authBiometricActivated),
            "auth_biometric_activated must be a conversion event"
        )
    }

    // MARK: - Helpers

    /// Strict GA4 snake_case: lowercase ASCII letters, digits, underscores;
    /// must start with a letter (not a digit, not an underscore).
    private func isSnakeCase(_ s: String) -> Bool {
        guard let first = s.first, first.isLetter, first.isLowercase else { return false }
        for ch in s {
            let isLowerLetter = ch.isLetter && ch.isLowercase
            let isDigit = ch.isNumber
            let isUnderscore = ch == "_"
            if !(isLowerLetter || isDigit || isUnderscore) { return false }
        }
        return true
    }
}
