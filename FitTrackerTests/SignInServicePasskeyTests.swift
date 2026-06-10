// FitTrackerTests/SignInServicePasskeyTests.swift
// T3 (test-coverage master plan) — SignInService passkey / WebAuthn unit tests.
//
// SignInService is on the CLAUDE.md high-risk list yet had ZERO direct tests.
//
// SCOPE NOTE (learned by running these): the test bundle inherits the app's
// Info.plist, which carries a real `PasskeyRelyingPartyID` — so in the test
// environment `isPasskeyConfigured` is TRUE and the "not-configured" guard is
// unreachable. And `signInWithPasskey()` / `registerPasskey()`, when configured,
// proceed into the `ASAuthorizationController` system UI flow (presentation
// anchor + system passkey sheet) which is device-only and must NOT be invoked
// headless. So — exactly like AuthManagerTests documents for real-device
// biometrics — the registration/assertion flow is out of scope here.
//
// What IS covered (deterministic + environment-independent): the invariants
// that gate the affordance, the PERSISTED token-type contract (raw values are
// stored in sessions — a rename silently breaks every stored session on
// upgrade), and the UserSession Codable round-trip for a passkey session.

import XCTest
@testable import FitTracker

@MainActor
final class SignInServicePasskeyTests: XCTestCase {

    // MARK: - canShowPasskeyLogin invariants (env-independent)

    func testCanShowPasskeyLogin_impliesConfiguredAndRegistered() {
        // canShowPasskeyLogin = hasRegisteredPasskey && isPasskeyConfigured.
        // Whatever the environment's config, the affordance can only be shown
        // when BOTH are true — a logical invariant that must always hold.
        let svc = SignInService()
        if svc.canShowPasskeyLogin {
            XCTAssertTrue(svc.isPasskeyConfigured,
                          "canShowPasskeyLogin must imply isPasskeyConfigured")
            XCTAssertTrue(svc.hasRegisteredPasskey,
                          "canShowPasskeyLogin must imply hasRegisteredPasskey")
        }
    }

    func testCanShowPasskeyLogin_falseWithoutRegisteredPasskey() {
        // A fresh service has no registered passkey, so the login affordance is
        // hidden regardless of whether the relying party is configured.
        let svc = SignInService()
        if !svc.hasRegisteredPasskey {
            XCTAssertFalse(svc.canShowPasskeyLogin)
        }
    }

    func testIsPasskeyConfigured_isStableForRepeatedReads() {
        // The computed property must be a pure read (no side effects / flakiness).
        let svc = SignInService()
        XCTAssertEqual(svc.isPasskeyConfigured, svc.isPasskeyConfigured)
    }

    // MARK: - Persisted SessionTokenType contract (must NOT drift)

    func testSessionTokenType_rawValuesStable() {
        // These raw values are persisted inside stored UserSessions; renaming a
        // case would silently invalidate every stored session on app upgrade.
        XCTAssertEqual(SessionTokenType.passkeySignature.rawValue, "passkeySignature")
        XCTAssertEqual(SessionTokenType.supabaseJWT.rawValue, "supabaseJWT")
        XCTAssertEqual(SessionTokenType.appleUserID.rawValue, "appleUserID")
        XCTAssertEqual(SessionTokenType.debugSimulator.rawValue, "debugSimulator")
        XCTAssertEqual(SessionTokenType.reviewMode.rawValue, "reviewMode")
    }

    func testSessionTokenType_codableRoundTrip() throws {
        for token in [SessionTokenType.passkeySignature, .supabaseJWT, .appleUserID] {
            let data = try JSONEncoder().encode(token)
            XCTAssertEqual(try JSONDecoder().decode(SessionTokenType.self, from: data), token)
        }
    }

    func testSessionTokenType_decodesFromStoredRawValue() throws {
        // Forward-compat: a previously-stored "passkeySignature" string still decodes.
        let decoded = try JSONDecoder().decode(SessionTokenType.self,
                                               from: Data("\"passkeySignature\"".utf8))
        XCTAssertEqual(decoded, .passkeySignature)
    }

    func testAuthProvider_passkey_rawValueStable() {
        XCTAssertEqual(AuthProvider.passkey.rawValue, "Passkey")
    }

    // MARK: - UserSession Codable round-trip for a passkey session

    func testUserSession_passkeySession_codableRoundTrip() throws {
        let credential = Data([0x01, 0x02, 0x03, 0x04])
        let session = UserSession(
            provider: .passkey,
            userID: "user-123",
            displayName: "Test User",
            email: "test@example.com",
            phone: nil,
            avatarURL: nil,
            sessionToken: "c2lnbmF0dXJl",          // base64 "signature"
            tokenType: .passkeySignature,
            backendAccessToken: nil,
            credentialID: credential
        )
        let data = try JSONEncoder().encode(session)
        let decoded = try JSONDecoder().decode(UserSession.self, from: data)
        XCTAssertEqual(decoded.provider, .passkey)
        XCTAssertEqual(decoded.tokenType, .passkeySignature)
        XCTAssertEqual(decoded.credentialID, credential)
        XCTAssertEqual(decoded, session, "Passkey session must survive a Codable round-trip intact")
    }

    func testUserSession_tokenType_optionalForBackwardCompat() throws {
        // A legacy session JSON without `tokenType` must still decode (the field
        // is Optional precisely for backward compat with pre-typing sessions).
        let legacy = """
        {"provider":"Passkey","userID":"u","displayName":"A B","sessionToken":"t","signedInAt":0}
        """
        let decoded = try JSONDecoder().decode(UserSession.self, from: Data(legacy.utf8))
        XCTAssertNil(decoded.tokenType)
        XCTAssertEqual(decoded.provider, .passkey)
    }

    func testUserSession_initials_derivedFromDisplayName() {
        let session = UserSession(
            provider: .passkey, userID: "u", displayName: "Ada Lovelace",
            email: nil, phone: nil, avatarURL: nil,
            sessionToken: "t", tokenType: .passkeySignature,
            backendAccessToken: nil, credentialID: nil
        )
        XCTAssertEqual(session.initials, "AL")
    }
}
