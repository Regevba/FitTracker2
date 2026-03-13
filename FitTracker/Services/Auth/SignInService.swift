// Services/Auth/SignInService.swift
// Full sign-in service:
//   - Sign in with Apple   (AuthenticationServices — native, no SDK)
//   - Google Sign-In       (GoogleSignIn SDK via SPM)
//   - Facebook Login       (FacebookSDK via SPM)
//   - Passkey / WebAuthn   (AuthenticationServices ASAuthorizationController)
//   - YubiKey / FIDO2 hardware key (ASAuthorizationPlatformPublicKeyCredentialProvider)
//
// Platform: iOS 17+, iPadOS 17+, macOS 14+

import Foundation
import AuthenticationServices
import SwiftUI
import CryptoKit
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

#if os(iOS)
typealias PlatformViewController = UIViewController
#elseif os(macOS)
typealias PlatformViewController = NSViewController
#endif

// ─────────────────────────────────────────────────────────
// MARK: – Session model
// ─────────────────────────────────────────────────────────

struct UserSession: Codable, Sendable, Equatable {
    var provider:      AuthProvider
    var userID:        String       // provider's unique user ID
    var displayName:   String
    var email:         String?
    var phone:         String?
    var avatarURL:     URL?
    var sessionToken:  String       // provider access token / Apple auth code
    var credentialID:  Data?        // passkey credential ID (if passkey login)
    var signedInAt:    Date         = Date()

    var initials: String {
        let parts = displayName.split(separator: " ")
        let first = parts.first.map { String($0.prefix(1)) } ?? ""
        let last  = parts.dropFirst().first.map { String($0.prefix(1)) } ?? ""
        return (first + last).uppercased()
    }
}

enum AuthProvider: String, Codable, Sendable {
    case apple    = "Apple"
    case google   = "Google"
    case facebook = "Facebook"
    case passkey  = "Passkey"
}

// ─────────────────────────────────────────────────────────
// MARK: – Auth state
// ─────────────────────────────────────────────────────────

enum AuthState: Equatable {
    case welcome
    case signIn
    case authenticated(UserSession)
    case error(String)
}

// ─────────────────────────────────────────────────────────
// MARK: – Sign-In Service
// ─────────────────────────────────────────────────────────

@MainActor
final class SignInService: NSObject, ObservableObject {

    @Published var state:      AuthState = .welcome
    @Published var isLoading:  Bool      = false

    // Passkey / YubiKey challenge (from server in production)
    private var currentChallenge: Data = Data()

    // Cached window reference for ASAuthorizationControllerPresentationContextProviding.
    // Populated on the main actor before performRequests() is called, so the nonisolated
    // delegate callback never needs to call DispatchQueue.main.sync (which deadlocks on macOS
    // when the delegate is invoked from the main thread).
    #if os(iOS)
    private var cachedWindow: UIWindow?
    #elseif os(macOS)
    private var cachedWindow: NSWindow?
    #endif

    var isAuthenticated: Bool {
        if case .authenticated = state { return true }
        return false
    }

    var currentSession: UserSession? {
        if case .authenticated(let s) = state { return s }
        return nil
    }

    // ── Restore session from Keychain on launch ───────────
    func restoreSession() {
        if let data = KeychainHelper.load(key: "ft.session"),
           let session = try? JSONDecoder().decode(UserSession.self, from: data) {
            state = .authenticated(session)
        } else {
            state = .welcome
        }
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Sign in with Apple
    // ─────────────────────────────────────────────────────

    func signInWithApple() {
        isLoading = true
        // Cache the window on the main actor NOW, before handing off to the delegate which
        // is nonisolated. This avoids the DispatchQueue.main.sync deadlock on macOS.
        #if os(iOS)
        cachedWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
        #elseif os(macOS)
        cachedWindow = NSApplication.shared.windows.first
        #endif

        let nonce   = generateNonce()
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Sign in with Google
    // ─────────────────────────────────────────────────────
    // Google Sign-In SDK: add to SPM as https://github.com/google/GoogleSignIn-iOS
    // Client ID in Info.plist key: GIDClientID = YOUR_CLIENT_ID.apps.googleusercontent.com

    func signInWithGoogle(presenting: PlatformViewController?) {
        isLoading = true

        // ── SPM dependency: GoogleSignIn ────────────────
        // import GoogleSignIn (uncomment when SDK added to project)
        //
        // GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: googleClientID)
        // GIDSignIn.sharedInstance.signIn(withPresenting: presenting ?? UIViewController()) { result, error in
        //     Task { @MainActor in
        //         self.isLoading = false
        //         if let error { self.state = .error(error.localizedDescription); return }
        //         guard let user = result?.user else { return }
        //         let session = UserSession(
        //             provider: .google,
        //             userID: user.userID ?? UUID().uuidString,
        //             displayName: user.profile?.name ?? "Google User",
        //             email: user.profile?.email,
        //             sessionToken: user.idToken?.tokenString ?? ""
        //         )
        //         self.finishSignIn(session)
        //     }
        // }

        // ── Fallback stub until SDK is added ──────────
        simulateSignIn(provider: .google, name: "Google User", email: "user@gmail.com")
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Sign in with Facebook
    // ─────────────────────────────────────────────────────
    // Facebook SDK: add to SPM as https://github.com/facebook/facebook-ios-sdk
    // App ID in Info.plist: FacebookAppID, FacebookClientToken, LSApplicationQueriesSchemes

    func signInWithFacebook(presenting: PlatformViewController?) {
        isLoading = true

        // ── SPM dependency: FacebookLogin ───────────────
        // import FacebookLogin (uncomment when SDK added to project)
        //
        // let manager = LoginManager()
        // manager.logIn(permissions: [.publicProfile, .email], from: presenting) { result, error in
        //     Task { @MainActor in
        //         self.isLoading = false
        //         if let error { self.state = .error(error.localizedDescription); return }
        //         guard case .success(let granted, _, let token) = result, !granted.isEmpty else { return }
        //
        //         // Fetch profile via Graph API
        //         GraphRequest(graphPath: "me", parameters: ["fields": "id,name,email"]).start { _, result, _ in
        //             Task { @MainActor in
        //                 let dict = result as? [String: String] ?? [:]
        //                 let session = UserSession(
        //                     provider: .facebook,
        //                     userID: dict["id"] ?? UUID().uuidString,
        //                     displayName: dict["name"] ?? "Facebook User",
        //                     email: dict["email"],
        //                     sessionToken: token?.tokenString ?? ""
        //                 )
        //                 self.finishSignIn(session)
        //             }
        //         }
        //     }
        // }

        // ── Fallback stub until SDK is added ──────────
        simulateSignIn(provider: .facebook, name: "Facebook User", email: "user@facebook.com")
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Passkey / YubiKey (WebAuthn / FIDO2)
    // ─────────────────────────────────────────────────────
    // No external SDK — uses AuthenticationServices natively (iOS 16+)
    // Supports:
    //   • Device passkey (synced via iCloud Keychain)
    //   • Physical FIDO2 key: YubiKey 5 NFC, Security Key NFC, YubiKey Bio
    //   • NFC or USB-A/C via Lightning adapter

    func signInWithPasskey(userHandle: String = "regev") {
        isLoading = true
        guard let relyingPartyID = passkeyRelyingPartyIdentifier else {
            isLoading = false
            state = .error("Passkey is not configured. Add PasskeyRelyingPartyID to Info.plist.")
            return
        }
        // Cache window reference on main actor before delegate callback runs.
        #if os(iOS)
        cachedWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
        #elseif os(macOS)
        cachedWindow = NSApplication.shared.windows.first
        #endif

        // In production: fetch challenge from your server (prevents replay attacks)
        currentChallenge = generateRandomBytes(count: 32)

        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(
            relyingPartyIdentifier: relyingPartyID
        )

        // Assertion request — authenticate with existing passkey
        let assertionRequest = provider.createCredentialAssertionRequest(
            challenge: currentChallenge
        )

        // Also allow security keys (YubiKey, etc.)
        let securityKeyProvider = ASAuthorizationSecurityKeyPublicKeyCredentialProvider(
            relyingPartyIdentifier: relyingPartyID
        )
        let securityKeyRequest = securityKeyProvider.createCredentialAssertionRequest(
            challenge: currentChallenge
        )

        let controller = ASAuthorizationController(authorizationRequests: [
            assertionRequest,
            securityKeyRequest,        // includes YubiKey FIDO2
        ])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    // Register a new passkey (called during first-time setup)
    func registerPasskey(userHandle: String = "regev", displayName: String = "Regev") {
        isLoading = true
        guard let relyingPartyID = passkeyRelyingPartyIdentifier else {
            isLoading = false
            state = .error("Passkey is not configured. Add PasskeyRelyingPartyID to Info.plist.")
            return
        }
        // Cache window reference on main actor before delegate callback runs.
        #if os(iOS)
        cachedWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
        #elseif os(macOS)
        cachedWindow = NSApplication.shared.windows.first
        #endif
        currentChallenge = generateRandomBytes(count: 32)

        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(
            relyingPartyIdentifier: relyingPartyID
        )

        let userID = (userHandle.data(using: .utf8) ?? Data())
        let regRequest = provider.createCredentialRegistrationRequest(
            challenge: currentChallenge,
            name: displayName,
            userID: userID
        )
        regRequest.userVerificationPreference = .required

        // Also allow security key registration
        let secKeyProvider = ASAuthorizationSecurityKeyPublicKeyCredentialProvider(
            relyingPartyIdentifier: relyingPartyID
        )
        let secKeyRegRequest = secKeyProvider.createCredentialRegistrationRequest(
            challenge: currentChallenge,
            displayName: displayName,
            name: userHandle,
            userID: userID
        )
        secKeyRegRequest.attestationPreference = .direct
        secKeyRegRequest.userVerificationPreference = .required

        let controller = ASAuthorizationController(authorizationRequests: [
            regRequest,
            secKeyRegRequest,
        ])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Sign out
    // ─────────────────────────────────────────────────────

    func signOut() {
        KeychainHelper.delete(key: "ft.session")
        withAnimation(.easeInOut(duration: 0.4)) {
            state = .welcome
        }
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Private helpers
    // ─────────────────────────────────────────────────────

    private func finishSignIn(_ session: UserSession) {
        isLoading = false
        if let encoded = try? JSONEncoder().encode(session) {
            KeychainHelper.save(key: "ft.session", data: encoded)
        }
        withAnimation(.easeInOut(duration: 0.5)) {
            state = .authenticated(session)
        }
    }

    private func simulateSignIn(provider: AuthProvider, name: String, email: String) {
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(800))
            let session = UserSession(
                provider: provider,
                userID: UUID().uuidString,
                displayName: name,
                email: email,
                sessionToken: UUID().uuidString
            )
            self?.finishSignIn(session)
        }
    }

    private func generateNonce() -> String {
        let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<32).compactMap { _ in chars.randomElement() })
    }

    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hashed = SHA256.hash(data: data)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func generateRandomBytes(count: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return Data(bytes)
    }

    private var googleClientID: String {
        Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String ?? ""
    }

    private var passkeyRelyingPartyIdentifier: String? {
        let value = (Bundle.main.object(forInfoDictionaryKey: "PasskeyRelyingPartyID") as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value.contains(".") else { return nil }
        return value
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – ASAuthorizationControllerDelegate
// ─────────────────────────────────────────────────────────

extension SignInService: ASAuthorizationControllerDelegate {

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        Task { @MainActor in
            isLoading = false

            switch authorization.credential {

            // ── Apple ID ──────────────────────────────
            case let cred as ASAuthorizationAppleIDCredential:
                let name = [cred.fullName?.givenName, cred.fullName?.familyName]
                    .compactMap { $0 }.joined(separator: " ")
                let existingAppleSession = currentSession?.provider == .apple ? currentSession : nil
                // Use cred.user (the stable userIdentifier) as the session token.
                // authorizationCode is a single-use, short-lived code and must NOT be stored.
                let session = UserSession(
                    provider: .apple,
                    userID: cred.user,
                    displayName: name.isEmpty ? (existingAppleSession?.displayName ?? "Apple User") : name,
                    email: cred.email ?? existingAppleSession?.email,
                    phone: existingAppleSession?.phone,
                    avatarURL: existingAppleSession?.avatarURL,
                    sessionToken: cred.user
                )
                finishSignIn(session)

            // ── Passkey assertion (device or YubiKey) ─
            case let cred as ASAuthorizationPlatformPublicKeyCredentialAssertion:
                let session = UserSession(
                    provider: .passkey,
                    userID: String(data: cred.userID, encoding: .utf8) ?? "passkey-user",
                    displayName: "Regev",
                    sessionToken: cred.signature.base64EncodedString(),
                    credentialID: cred.credentialID
                )
                finishSignIn(session)

            // ── Security key (YubiKey) assertion ─────
            case let cred as ASAuthorizationSecurityKeyPublicKeyCredentialAssertion:
                let session = UserSession(
                    provider: .passkey,
                    userID: String(data: cred.userID, encoding: .utf8) ?? "seckey-user",
                    displayName: "Regev (Security Key)",
                    sessionToken: cred.signature.base64EncodedString(),
                    credentialID: cred.credentialID
                )
                finishSignIn(session)

            // ── Passkey registration ──────────────────
            case let cred as ASAuthorizationPlatformPublicKeyCredentialRegistration:
                let session = UserSession(
                    provider: .passkey,
                    userID: String(data: cred.rawClientDataJSON, encoding: .utf8)?.prefix(36).description ?? UUID().uuidString,
                    displayName: "Regev",
                    sessionToken: cred.rawAttestationObject?.base64EncodedString() ?? "",
                    credentialID: cred.credentialID
                )
                finishSignIn(session)

            // ── Security key registration ─────────────
            case let cred as ASAuthorizationSecurityKeyPublicKeyCredentialRegistration:
                let session = UserSession(
                    provider: .passkey,
                    userID: UUID().uuidString,
                    displayName: "Regev (Security Key)",
                    sessionToken: cred.rawAttestationObject?.base64EncodedString() ?? "",
                    credentialID: cred.credentialID
                )
                finishSignIn(session)

            default:
                state = .error("Unknown credential type received.")
            }
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor in
            isLoading = false
            let authError = error as? ASAuthorizationError
            // Code 1001 = user cancelled — don't show error
            if authError?.code != .canceled {
                state = .error(error.localizedDescription)
            }
        }
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – Presentation context
// ─────────────────────────────────────────────────────────

extension SignInService: ASAuthorizationControllerPresentationContextProviding {
    // cachedWindow is always populated before performRequests() is called (on the main actor),
    // so this nonisolated callback can safely return it without any cross-thread dispatch.
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated { presentationAnchorOnMainActor() }
    }

    @MainActor
    private func presentationAnchorOnMainActor() -> ASPresentationAnchor {
        #if os(iOS)
        return cachedWindow
            ?? UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }
            ?? UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first?
                .windows
                .first
            ?? UIWindow(frame: UIScreen.main.bounds)
        #elseif os(macOS)
        return cachedWindow ?? NSApplication.shared.windows.first ?? NSWindow()
        #endif
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – Keychain helper
// ─────────────────────────────────────────────────────────

enum KeychainHelper {
    static func save(key: String, data: Data) {
        let q: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrAccount: key, kSecValueData: data,
                                  kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        SecItemDelete(q as CFDictionary)
        SecItemAdd(q as CFDictionary, nil)
    }

    static func load(key: String) -> Data? {
        let q: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrAccount: key,
                                  kSecReturnData: true, kSecMatchLimit: kSecMatchLimitOne]
        var result: AnyObject?
        SecItemCopyMatching(q as CFDictionary, &result)
        return result as? Data
    }

    static func delete(key: String) {
        let q: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrAccount: key]
        SecItemDelete(q as CFDictionary)
    }
}
