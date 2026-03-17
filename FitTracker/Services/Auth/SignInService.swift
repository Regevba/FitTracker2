// Services/Auth/SignInService.swift
// Session + auth flow manager for:
//   - Sign in with Apple
//   - Google sign-in (adapter-backed, mockable)
//   - Email registration / verification / login (adapter-backed, mockable)
//   - Passkey / WebAuthn login and registration

import Foundation
import AuthenticationServices
import SwiftUI
import CryptoKit
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// ─────────────────────────────────────────────────────────
// MARK: – Session model
// ─────────────────────────────────────────────────────────

struct UserSession: Codable, Sendable, Equatable {
    var provider:      AuthProvider
    var userID:        String
    var displayName:   String
    var email:         String?
    var phone:         String?
    var avatarURL:     URL?
    var sessionToken:  String
    var credentialID:  Data?
    var signedInAt:    Date = Date()

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
    case email    = "Email"
}

enum AuthState: Equatable {
    case welcome
    case signIn
    case authenticated(UserSession)
    case error(String)
}

enum AuthRoute: Hashable {
    case registerMethods
    case loginMethods
    case emailRegistration
    case emailVerification
    case emailLogin
}

struct PendingEmailRegistration: Codable, Hashable, Sendable {
    var firstName: String
    var lastName: String
    var birthday: Date
    var email: String
    var password: String

    var fullName: String {
        [firstName, lastName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

struct EmailRegistrationChallenge: Codable, Hashable, Sendable {
    var email: String
    var expectedCode: String
    var expiresAt: Date
}

protocol AppleAuthProviding {
    @MainActor
    func startSignIn(using service: SignInService)
}

protocol GoogleAuthProviding {
    func signIn() async throws -> UserSession
}

protocol EmailAuthProviding {
    func register(_ draft: PendingEmailRegistration) async throws -> EmailRegistrationChallenge
    func verify(code: String, challenge: EmailRegistrationChallenge, draft: PendingEmailRegistration) async throws -> UserSession
    func login(email: String, password: String) async throws -> UserSession
}

struct SystemAppleAuthProvider: AppleAuthProviding {
    @MainActor
    func startSignIn(using service: SignInService) {
        service.startSystemAppleSignIn()
    }
}

struct MockGoogleAuthProvider: GoogleAuthProviding {
    func signIn() async throws -> UserSession {
        try await Task.sleep(for: .milliseconds(700))
        return UserSession(
            provider: .google,
            userID: UUID().uuidString,
            displayName: "Google User",
            email: "user@gmail.com",
            sessionToken: UUID().uuidString
        )
    }
}

struct MockEmailAuthProvider: EmailAuthProviding {
    func register(_ draft: PendingEmailRegistration) async throws -> EmailRegistrationChallenge {
        try await Task.sleep(for: .milliseconds(600))
        return EmailRegistrationChallenge(
            email: draft.email,
            expectedCode: "48291",
            expiresAt: Date().addingTimeInterval(600)
        )
    }

    func verify(code: String, challenge: EmailRegistrationChallenge, draft: PendingEmailRegistration) async throws -> UserSession {
        try await Task.sleep(for: .milliseconds(400))

        guard Date() <= challenge.expiresAt else {
            throw NSError(
                domain: "FitTracker.Auth",
                code: 410,
                userInfo: [NSLocalizedDescriptionKey: "This verification code expired. Please request a new one."]
            )
        }

        guard code == challenge.expectedCode else {
            throw NSError(
                domain: "FitTracker.Auth",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "The verification code is incorrect."]
            )
        }

        return UserSession(
            provider: .email,
            userID: draft.email.lowercased(),
            displayName: draft.fullName,
            email: draft.email,
            sessionToken: UUID().uuidString
        )
    }

    func login(email: String, password: String) async throws -> UserSession {
        try await Task.sleep(for: .milliseconds(500))

        guard !email.isEmpty, !password.isEmpty else {
            throw NSError(
                domain: "FitTracker.Auth",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Enter your email and password to continue."]
            )
        }

        let inferredName = email.split(separator: "@").first
            .map { $0.replacingOccurrences(of: ".", with: " ").capitalized }
            ?? "FitTracker User"

        return UserSession(
            provider: .email,
            userID: email.lowercased(),
            displayName: inferredName,
            email: email,
            sessionToken: UUID().uuidString
        )
    }
}

@MainActor
final class SignInService: NSObject, ObservableObject {

    @Published var isLoading = false
    @Published var navigationPath: [AuthRoute] = []
    @Published var authErrorMessage: String?
    @Published var statusMessage: String?
    @Published private(set) var activeSession: UserSession?
    @Published private(set) var storedSession: UserSession?
    @Published private(set) var pendingEmailRegistration: PendingEmailRegistration?
    @Published private(set) var pendingEmailChallenge: EmailRegistrationChallenge?
    @Published private(set) var hasRegisteredPasskey: Bool

    private let appleProvider: AppleAuthProviding
    private let googleProvider: GoogleAuthProviding
    private let emailProvider: EmailAuthProviding

    private var currentChallenge: Data = Data()
    private var pendingUserHandle: String = ""
    private var pendingDisplayName: String = ""

    #if os(iOS)
    private var cachedWindow: UIWindow?
    #elseif os(macOS)
    private var cachedWindow: NSWindow?
    #endif

    override init() {
        self.appleProvider = SystemAppleAuthProvider()
        self.googleProvider = MockGoogleAuthProvider()
        self.emailProvider = MockEmailAuthProvider()
        self.hasRegisteredPasskey = UserDefaults.standard.bool(forKey: Self.passkeyRegisteredKey)
        super.init()
    }

    init(
        appleProvider: AppleAuthProviding,
        googleProvider: GoogleAuthProviding,
        emailProvider: EmailAuthProviding
    ) {
        self.appleProvider = appleProvider
        self.googleProvider = googleProvider
        self.emailProvider = emailProvider
        self.hasRegisteredPasskey = UserDefaults.standard.bool(forKey: Self.passkeyRegisteredKey)
        super.init()
    }

    static let sessionKey = "ft.session"
    private static let passkeyRegisteredKey = "ft.passkeyRegistered"

    var state: AuthState {
        if let activeSession {
            return .authenticated(activeSession)
        }
        if let authErrorMessage {
            return .error(authErrorMessage)
        }
        return .welcome
    }

    var isAuthenticated: Bool { activeSession != nil }
    var currentSession: UserSession? { activeSession ?? storedSession }
    var hasStoredSession: Bool { storedSession != nil }
    var isPasskeyConfigured: Bool { passkeyRelyingPartyIdentifier != nil }
    var canShowPasskeyLogin: Bool { hasRegisteredPasskey && isPasskeyConfigured }

    func restoreSession() {
        guard activeSession == nil else { return }

        if let data = KeychainHelper.load(key: Self.sessionKey),
           let session = try? JSONDecoder().decode(UserSession.self, from: data) {
            storedSession = session
        } else {
            storedSession = nil
        }
    }

    func lockForReopen() {
        activeSession = nil
        statusMessage = nil
        authErrorMessage = nil
        navigationPath.removeAll()
    }

    func resumeStoredSession() {
        guard let storedSession else { return }
        activeSession = storedSession
        authErrorMessage = nil
        statusMessage = nil
        navigationPath.removeAll()
    }

    func signOut() {
        KeychainHelper.delete(key: Self.sessionKey)
        activeSession = nil
        storedSession = nil
        pendingEmailRegistration = nil
        pendingEmailChallenge = nil
        navigationPath.removeAll()
        authErrorMessage = nil
        statusMessage = nil
    }

    func openRegisterFlow() {
        authErrorMessage = nil
        statusMessage = nil
        navigationPath = [.registerMethods]
    }

    func openLoginFlow() {
        authErrorMessage = nil
        statusMessage = nil
        navigationPath = [.loginMethods]
    }

    func showEmailRegistration() {
        authErrorMessage = nil
        statusMessage = nil
        navigationPath.append(.emailRegistration)
    }

    func showEmailLogin() {
        authErrorMessage = nil
        statusMessage = nil
        navigationPath.append(.emailLogin)
    }

    func resetToEntry() {
        authErrorMessage = nil
        statusMessage = nil
        navigationPath.removeAll()
    }

    func startEmailRegistration(_ draft: PendingEmailRegistration) async {
        isLoading = true
        authErrorMessage = nil
        statusMessage = nil

        do {
            let challenge = try await emailProvider.register(draft)
            pendingEmailRegistration = draft
            pendingEmailChallenge = challenge
            navigationPath = [.registerMethods, .emailVerification]
            isLoading = false
        } catch {
            isLoading = false
            authErrorMessage = error.localizedDescription
        }
    }

    func verifyEmailRegistrationCode(_ code: String) async {
        guard let draft = pendingEmailRegistration,
              let challenge = pendingEmailChallenge else {
            authErrorMessage = "Your registration session expired. Please start again."
            resetToEntry()
            return
        }

        isLoading = true
        authErrorMessage = nil

        do {
            let session = try await emailProvider.verify(code: code, challenge: challenge, draft: draft)
            pendingEmailRegistration = nil
            pendingEmailChallenge = nil
            finishSignIn(session)
            statusMessage = "Your email is verified and your account is ready."
        } catch {
            isLoading = false
            authErrorMessage = error.localizedDescription
        }
    }

    func signInWithEmail(email: String, password: String) async {
        isLoading = true
        authErrorMessage = nil
        statusMessage = nil

        do {
            let session = try await emailProvider.login(email: email, password: password)
            finishSignIn(session)
        } catch {
            isLoading = false
            authErrorMessage = error.localizedDescription
        }
    }

    func signInWithGoogle() {
        isLoading = true
        authErrorMessage = nil
        statusMessage = nil

        Task {
            do {
                let session = try await googleProvider.signIn()
                await MainActor.run {
                    self.finishSignIn(session)
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.authErrorMessage = error.localizedDescription
                }
            }
        }
    }

    func signInWithApple() {
        authErrorMessage = nil
        statusMessage = nil
        isLoading = true
        appleProvider.startSignIn(using: self)
    }

    @MainActor
    func startSystemAppleSignIn() {
        #if os(iOS)
        cachedWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
        #elseif os(macOS)
        cachedWindow = NSApplication.shared.windows.first
        #endif

        let nonce = generateNonce()
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    func signInWithPasskey(userHandle: String? = nil) {
        isLoading = true
        authErrorMessage = nil
        statusMessage = nil

        guard let relyingPartyID = passkeyRelyingPartyIdentifier else {
            isLoading = false
            authErrorMessage = "Passkey is not configured. Add PasskeyRelyingPartyID to Info.plist."
            return
        }

        #if os(iOS)
        cachedWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
        #elseif os(macOS)
        cachedWindow = NSApplication.shared.windows.first
        #endif

        pendingUserHandle = userHandle ?? storedSession?.userID ?? activeSession?.userID ?? "fittracker-user"
        pendingDisplayName = currentSession?.displayName ?? "FitTracker User"
        currentChallenge = generateRandomBytes(count: 32)

        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: relyingPartyID)
        let assertionRequest = provider.createCredentialAssertionRequest(challenge: currentChallenge)

        let securityKeyProvider = ASAuthorizationSecurityKeyPublicKeyCredentialProvider(relyingPartyIdentifier: relyingPartyID)
        let securityKeyRequest = securityKeyProvider.createCredentialAssertionRequest(challenge: currentChallenge)

        let controller = ASAuthorizationController(authorizationRequests: [assertionRequest, securityKeyRequest])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    func registerPasskey(userHandle: String = "fittracker-user", displayName: String = "") {
        isLoading = true
        authErrorMessage = nil
        statusMessage = nil

        guard let relyingPartyID = passkeyRelyingPartyIdentifier else {
            isLoading = false
            authErrorMessage = "Passkey is not configured. Add PasskeyRelyingPartyID to Info.plist."
            return
        }

        #if os(iOS)
        cachedWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
        #elseif os(macOS)
        cachedWindow = NSApplication.shared.windows.first
        #endif

        let session = currentSession
        pendingUserHandle = session?.userID ?? userHandle
        pendingDisplayName = displayName.isEmpty ? (session?.displayName ?? "FitTracker User") : displayName
        currentChallenge = generateRandomBytes(count: 32)

        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: relyingPartyID)
        let userID = pendingUserHandle.data(using: .utf8) ?? Data()

        let platformRequest = provider.createCredentialRegistrationRequest(
            challenge: currentChallenge,
            name: pendingDisplayName,
            userID: userID
        )
        platformRequest.userVerificationPreference = .required

        let securityKeyProvider = ASAuthorizationSecurityKeyPublicKeyCredentialProvider(relyingPartyIdentifier: relyingPartyID)
        let securityKeyRequest = securityKeyProvider.createCredentialRegistrationRequest(
            challenge: currentChallenge,
            displayName: pendingDisplayName,
            name: pendingUserHandle,
            userID: userID
        )
        securityKeyRequest.attestationPreference = .direct
        securityKeyRequest.userVerificationPreference = .required

        let controller = ASAuthorizationController(authorizationRequests: [platformRequest, securityKeyRequest])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    func addPasskeyForCurrentUser() {
        let session = currentSession
        registerPasskey(
            userHandle: session?.userID ?? "fittracker-user",
            displayName: session?.displayName ?? "FitTracker User"
        )
    }

    #if targetEnvironment(simulator)
    func signInAsTestUser() {
        let session = UserSession(
            provider: .apple,
            userID: UUID().uuidString,
            displayName: "Regev",
            email: "regev@simulator.local",
            sessionToken: UUID().uuidString
        )
        finishSignIn(session)
    }
    #endif

    private func finishSignIn(_ session: UserSession) {
        activeSession = session
        storedSession = session
        saveSession(session)
        navigationPath.removeAll()
        pendingEmailRegistration = nil
        pendingEmailChallenge = nil
        authErrorMessage = nil
        isLoading = false

        if session.provider == .passkey {
            setHasRegisteredPasskey(true)
        }
    }

    private func saveSession(_ session: UserSession) {
        if let encoded = try? JSONEncoder().encode(session) {
            KeychainHelper.save(key: Self.sessionKey, data: encoded)
        }
    }

    private func setHasRegisteredPasskey(_ value: Bool) {
        hasRegisteredPasskey = value
        UserDefaults.standard.set(value, forKey: Self.passkeyRegisteredKey)
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

    private var passkeyRelyingPartyIdentifier: String? {
        let value = (Bundle.main.object(forInfoDictionaryKey: "PasskeyRelyingPartyID") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value.contains(".") else { return nil }
        return value
    }
}

extension SignInService {
    static func mergedAppleSession(
        userID: String,
        incomingName: String,
        incomingEmail: String?,
        existingAppleSession: UserSession?
    ) -> UserSession {
        UserSession(
            provider: .apple,
            userID: userID,
            displayName: incomingName.isEmpty ? (existingAppleSession?.displayName ?? "Apple User") : incomingName,
            email: incomingEmail ?? existingAppleSession?.email,
            phone: existingAppleSession?.phone,
            avatarURL: existingAppleSession?.avatarURL,
            sessionToken: userID
        )
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
            case let cred as ASAuthorizationAppleIDCredential:
                let name = [cred.fullName?.givenName, cred.fullName?.familyName]
                    .compactMap { $0 }
                    .joined(separator: " ")

                let session = Self.mergedAppleSession(
                    userID: cred.user,
                    incomingName: name,
                    incomingEmail: cred.email,
                    existingAppleSession: storedSession?.provider == .apple ? storedSession : nil
                )
                finishSignIn(session)

            case let cred as ASAuthorizationPlatformPublicKeyCredentialAssertion:
                let session = UserSession(
                    provider: .passkey,
                    userID: String(data: cred.userID, encoding: .utf8) ?? pendingUserHandle,
                    displayName: pendingDisplayName.isEmpty ? (currentSession?.displayName ?? "User") : pendingDisplayName,
                    email: storedSession?.email,
                    sessionToken: cred.signature.base64EncodedString(),
                    credentialID: cred.credentialID
                )
                finishSignIn(session)

            case let cred as ASAuthorizationSecurityKeyPublicKeyCredentialAssertion:
                let session = UserSession(
                    provider: .passkey,
                    userID: String(data: cred.userID, encoding: .utf8) ?? pendingUserHandle,
                    displayName: pendingDisplayName.isEmpty ? (currentSession?.displayName ?? "User") : pendingDisplayName,
                    email: storedSession?.email,
                    sessionToken: cred.signature.base64EncodedString(),
                    credentialID: cred.credentialID
                )
                finishSignIn(session)

            case _ as ASAuthorizationPlatformPublicKeyCredentialRegistration,
                 _ as ASAuthorizationSecurityKeyPublicKeyCredentialRegistration:
                setHasRegisteredPasskey(true)
                statusMessage = "Passkey added. You can use it from the login screen next time."
                authErrorMessage = nil
                isLoading = false

            default:
                authErrorMessage = "Unknown credential type received."
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
            if authError?.code != .canceled {
                authErrorMessage = error.localizedDescription
            }
        }
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – Presentation context
// ─────────────────────────────────────────────────────────

extension SignInService: ASAuthorizationControllerPresentationContextProviding {
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
    private static let service = "com.fittracker.regev"

    static func save(key: String, data: Data) {
        let q: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        SecItemDelete(q as CFDictionary)
        SecItemAdd(q as CFDictionary, nil)
    }

    static func load(key: String) -> Data? {
        let q: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        SecItemCopyMatching(q as CFDictionary, &result)
        return result as? Data
    }

    static func delete(key: String) {
        let q: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
        ]
        SecItemDelete(q as CFDictionary)
    }
}
