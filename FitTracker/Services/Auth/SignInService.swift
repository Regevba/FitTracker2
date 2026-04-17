// Services/Auth/SignInService.swift
// Session + auth flow manager for:
//   - Sign in with Apple (Supabase-backed)
//   - Google sign-in (adapter-backed, mockable)
//   - Email registration / verification / login (adapter-backed, mockable)
//   - Passkey / WebAuthn login and registration

import Foundation
import AuthenticationServices
import os.log
import SwiftUI

private let authLogger = Logger(subsystem: "com.fitme.auth", category: "signIn")
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// ─────────────────────────────────────────────────────────
// MARK: – Session model
// ─────────────────────────────────────────────────────────

/// Documents what kind of value `UserSession.sessionToken` holds.
/// Added in audit Sprint D to address DEEP-AUTH-004 — sessionToken historically
/// held 5 untyped value classes (UUID, passkey signature, Supabase JWT,
/// debug literal, Apple userID) with no type contract.
///
/// Optional for backward compat — legacy decoded sessions have nil tokenType
/// and callers must treat nil as "unknown legacy token".
enum SessionTokenType: String, Codable, Sendable {
    case supabaseJWT          // Supabase-issued JWT (parseable header.payload.signature)
    case passkeySignature     // ASAuthorizationPlatformPublicKeyCredentialAssertion.signature base64
    case appleUserID          // Apple ID token from Sign in with Apple
    case debugSimulator       // Simulator/test build token — must never appear in release
    case reviewMode           // App Store review build token — gated by #if DEBUG
}

struct UserSession: Codable, Sendable, Equatable {
    var provider:           AuthProvider
    var userID:             String
    var displayName:        String
    var email:              String?
    var phone:              String?
    var avatarURL:          URL?
    var sessionToken:       String
    /// What kind of value `sessionToken` holds. Optional for backward compat.
    var tokenType:          SessionTokenType?
    var backendAccessToken: String?
    var credentialID:       Data?
    var signedInAt:         Date = Date()

    var initials: String {
        let parts = displayName.split(separator: " ")
        let first = parts.first.map { String($0.prefix(1)) } ?? ""
        let last  = parts.dropFirst().first.map { String($0.prefix(1)) } ?? ""
        return (first + last).uppercased()
    }

    var hasBackendAccessToken: Bool {
        guard let backendAccessToken else { return false }
        return backendAccessToken.split(separator: ".").count == 3
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

struct PendingEmailRegistration: Hashable, Sendable {
    var firstName: String
    var lastName: String
    var birthday: Date
    var email: String
    /// Not included in Codable encoding to prevent accidental serialization.
    var password: String

    var fullName: String {
        [firstName, lastName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

// Codable conformance in extension to preserve memberwise init.
// password is excluded from encoding/decoding to prevent serialization.
extension PendingEmailRegistration: Codable {
    private enum CodingKeys: String, CodingKey {
        case firstName, lastName, birthday, email
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            firstName: try c.decode(String.self, forKey: .firstName),
            lastName:  try c.decode(String.self, forKey: .lastName),
            birthday:  try c.decode(Date.self, forKey: .birthday),
            email:     try c.decode(String.self, forKey: .email),
            password:  ""
        )
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(firstName, forKey: .firstName)
        try c.encode(lastName, forKey: .lastName)
        try c.encode(birthday, forKey: .birthday)
        try c.encode(email, forKey: .email)
        // password intentionally omitted
    }
}

struct EmailRegistrationChallenge: Codable, Hashable, Sendable {
    var email: String
    var expectedCode: String
    var expiresAt: Date
}

protocol AppleAuthProviding {
    func startSignIn() async throws -> UserSession
}

protocol GoogleAuthProviding {
    func signIn() async throws -> UserSession
}

protocol EmailAuthProviding {
    func register(_ draft: PendingEmailRegistration) async throws -> EmailRegistrationChallenge
    func verify(code: String, challenge: EmailRegistrationChallenge, draft: PendingEmailRegistration) async throws -> UserSession
    func login(email: String, password: String) async throws -> UserSession
    func resendRegistrationCode(challenge: EmailRegistrationChallenge, draft: PendingEmailRegistration) async throws -> EmailRegistrationChallenge
    func requestPasswordReset(email: String) async throws
}

// SupabaseAppleAuthProvider is defined in SupabaseAppleAuthProvider.swift.

struct MockGoogleAuthProvider: GoogleAuthProviding {
    func signIn() async throws -> UserSession {
        try await Task.sleep(for: .milliseconds(700))
        return UserSession(
            provider: .google,
            userID: UUID().uuidString,
            displayName: "Google User",
            email: "user@gmail.com",
            sessionToken: UUID().uuidString,
            tokenType: .debugSimulator
        )
    }
}

struct UnavailableGoogleAuthProvider: GoogleAuthProviding {
    static let message = "Google Sign-In is not enabled in this build yet. Use Apple, Email, or Passkey."

    func signIn() async throws -> UserSession {
        throw NSError(
            domain: "FitTracker.Auth",
            code: 503,
            userInfo: [NSLocalizedDescriptionKey: Self.message]
        )
    }
}

#if DEBUG
struct LocalEmailAuthProvider: EmailAuthProviding {
    func register(_ draft: PendingEmailRegistration) async throws -> EmailRegistrationChallenge {
        try await Task.sleep(for: .milliseconds(600))
        // DEBUG-only: fixed code for Simulator/TestFlight-internal testing. Never ships in release.
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
            sessionToken: UUID().uuidString,
            tokenType: .debugSimulator,
            backendAccessToken: nil
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
            ?? "\(AppBrand.name) User"

        return UserSession(
            provider: .email,
            userID: email.lowercased(),
            displayName: inferredName,
            email: email,
            sessionToken: UUID().uuidString,
            tokenType: .debugSimulator,
            backendAccessToken: nil
        )
    }

    func resendRegistrationCode(challenge: EmailRegistrationChallenge, draft: PendingEmailRegistration) async throws -> EmailRegistrationChallenge {
        try await Task.sleep(for: .milliseconds(350))
        return EmailRegistrationChallenge(
            email: draft.email,
            expectedCode: challenge.expectedCode,
            expiresAt: Date().addingTimeInterval(600)
        )
    }

    func requestPasswordReset(email: String) async throws {
        try await Task.sleep(for: .milliseconds(450))
        guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NSError(
                domain: "FitTracker.Auth",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Enter your email address to continue."]
            )
        }
    }
}
#else
// Release builds: email auth requires a real Supabase backend.
// Until wired, reject all email auth attempts so no mock session
// can be created in a production binary.
struct UnavailableEmailAuthProvider: EmailAuthProviding {
    private static let msg = "Email sign-in is not available in this build. Use Sign in with Apple or Passkey."
    func register(_ draft: PendingEmailRegistration) async throws -> EmailRegistrationChallenge {
        throw NSError(domain: "FitTracker.Auth", code: 503, userInfo: [NSLocalizedDescriptionKey: Self.msg])
    }
    func verify(code: String, challenge: EmailRegistrationChallenge, draft: PendingEmailRegistration) async throws -> UserSession {
        throw NSError(domain: "FitTracker.Auth", code: 503, userInfo: [NSLocalizedDescriptionKey: Self.msg])
    }
    func login(email: String, password: String) async throws -> UserSession {
        throw NSError(domain: "FitTracker.Auth", code: 503, userInfo: [NSLocalizedDescriptionKey: Self.msg])
    }
    func resendRegistrationCode(challenge: EmailRegistrationChallenge, draft: PendingEmailRegistration) async throws -> EmailRegistrationChallenge {
        throw NSError(domain: "FitTracker.Auth", code: 503, userInfo: [NSLocalizedDescriptionKey: Self.msg])
    }
    func requestPasswordReset(email: String) async throws {
        throw NSError(domain: "FitTracker.Auth", code: 503, userInfo: [NSLocalizedDescriptionKey: Self.msg])
    }
}
#endif

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
    private let googleAuthAvailable: Bool
    private let emailAuthAvailable: Bool

    private var currentChallenge: Data = Data()
    private var pendingUserHandle: String = ""
    private var pendingDisplayName: String = ""

    #if os(iOS)
    private var cachedWindow: UIWindow?
    #elseif os(macOS)
    private var cachedWindow: NSWindow?
    #endif

    override init() {
        self.appleProvider = SupabaseAppleAuthProvider()
        if SupabaseRuntimeConfiguration.isConfigured && GoogleRuntimeConfiguration.isConfigured {
            self.googleProvider = GoogleAuthProvider()
            self.googleAuthAvailable = true
        } else {
            self.googleProvider = UnavailableGoogleAuthProvider()
            self.googleAuthAvailable = false
        }

        if SupabaseRuntimeConfiguration.isConfigured {
            self.emailProvider = EmailAuthProvider()
            self.emailAuthAvailable = true
        } else {
            #if DEBUG
            self.emailProvider = LocalEmailAuthProvider()
            self.emailAuthAvailable = true
            #else
            self.emailProvider = UnavailableEmailAuthProvider()
            self.emailAuthAvailable = false
            #endif
        }
        self.hasRegisteredPasskey = UserDefaults.standard.bool(forKey: Self.passkeyRegisteredKey)
        super.init()
        applyReviewSessionIfNeeded()
    }

    init(
        appleProvider: AppleAuthProviding,
        googleProvider: GoogleAuthProviding,
        emailProvider: EmailAuthProviding,
        googleAuthAvailable: Bool = true,
        emailAuthAvailable: Bool = true
    ) {
        self.appleProvider = appleProvider
        self.googleProvider = googleProvider
        self.emailProvider = emailProvider
        self.googleAuthAvailable = googleAuthAvailable
        self.emailAuthAvailable = emailAuthAvailable
        self.hasRegisteredPasskey = UserDefaults.standard.bool(forKey: Self.passkeyRegisteredKey)
        super.init()
        applyReviewSessionIfNeeded()
    }

    static let sessionKey = "ft.session"
    private static let passkeyRegisteredKey = "ft.passkeyRegistered"
    private static let reviewAuthKey = "FITTRACKER_REVIEW_AUTH"

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
    var isSupabaseConfigured: Bool { SupabaseRuntimeConfiguration.isConfigured }
    var isGoogleAuthAvailable: Bool { googleAuthAvailable }
    var isEmailAuthAvailable: Bool { emailAuthAvailable }

    /// Restores a previous session. Checks Supabase for a live/refreshable JWT;
    /// updates the stored token if valid. Call from within a Task block at app launch.
    /// Uses a 5-second timeout to prevent UI freeze if the network call hangs.
    func restoreSession(activateStoredSession: Bool = false) async {
        guard activeSession == nil else { return }
        guard SupabaseRuntimeConfiguration.isConfigured else {
            KeychainHelper.delete(key: Self.sessionKey)
            self.storedSession = nil
            return
        }

        // 1. Ask Supabase if there's a live (or refreshable) session — with 5s timeout
        //    Uses a detached task so the network call doesn't block the main actor.
        let sessionResult: String? = await withCheckedContinuation { continuation in
            let work = Task.detached {
                let session = try? await supabase.auth.session
                return session?.accessToken
            }
            Task {
                // Race: work vs 5-second timeout
                let timeout = Task {
                    try? await Task.sleep(for: .seconds(5))
                    work.cancel()
                    return nil as String?
                }
                if let token = await work.value {
                    timeout.cancel()
                    continuation.resume(returning: token)
                } else {
                    timeout.cancel()
                    continuation.resume(returning: nil)
                }
            }
        }

        if let accessToken = sessionResult {
            // 2. Load UserSession metadata from Keychain and refresh the backend JWT
            if let data = KeychainHelper.load(key: Self.sessionKey),
               var stored = try? JSONDecoder().decode(UserSession.self, from: data) {
                stored.backendAccessToken = accessToken
                self.storedSession = stored
                if activateStoredSession {
                    self.activeSession = stored
                }
                return
            }
        }

        // 3. No valid Supabase session or timeout → clear Keychain
        KeychainHelper.delete(key: Self.sessionKey)
        self.storedSession = nil
    }

    private func applyReviewSessionIfNeeded() {
        let reviewMode = ProcessInfo.processInfo.environment[Self.reviewAuthKey]?.lowercased()

        #if DEBUG && targetEnvironment(simulator)
        // Auto-login on Simulator in DEBUG builds so developers can test
        // the app without going through Apple Sign In or email OTP.
        // Set FITTRACKER_SKIP_AUTO_LOGIN=1 in the scheme to disable.
        let skipAutoLogin = ProcessInfo.processInfo.environment["FITTRACKER_SKIP_AUTO_LOGIN"] == "1"
        if reviewMode == nil && !skipAutoLogin && activeSession == nil && storedSession == nil {
            let session = UserSession(
                provider: .email,
                userID: "simulator@fitme.app",
                displayName: "Simulator User",
                email: "simulator@fitme.app",
                sessionToken: "simulator-debug-token",
                tokenType: .debugSimulator
            )
            activeSession = session
            storedSession = session
            return
        }
        #endif

        #if DEBUG
        guard reviewMode == "authenticated" || reviewMode == "settings" else { return }

        let session = UserSession(
            provider: .email,
            userID: "review@fitme.app",
            displayName: "Regev",
            email: "review@fitme.app",
            sessionToken: "review-session-token",
            tokenType: .reviewMode
        )

        activeSession = session
        storedSession = session
        statusMessage = nil
        authErrorMessage = nil
        #endif
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
        // Clear local state first to prevent stale session usage
        KeychainHelper.delete(key: Self.sessionKey)
        let wasActive = activeSession != nil
        activeSession = nil       // triggers FitTrackerApp.onChange to clear dataStore + AI
        storedSession = nil
        pendingEmailRegistration = nil
        pendingEmailChallenge = nil
        navigationPath.removeAll()
        authErrorMessage = nil
        statusMessage = nil

        // Sign out from Supabase after local state is cleared
        if wasActive, SupabaseRuntimeConfiguration.isConfigured {
            Task {
                do {
                    try await supabase.auth.signOut(scope: .local)
                } catch {
                    authLogger.error("Supabase signOut failed: \(error.localizedDescription)")
                }
            }
        }
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

    func clearFeedback() {
        authErrorMessage = nil
        statusMessage = nil
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

    func resendEmailRegistrationCode() async {
        guard let draft = pendingEmailRegistration,
              let challenge = pendingEmailChallenge else {
            authErrorMessage = "Your registration session expired. Please start again."
            resetToEntry()
            return
        }

        isLoading = true
        authErrorMessage = nil
        statusMessage = nil

        do {
            let refreshedChallenge = try await emailProvider.resendRegistrationCode(challenge: challenge, draft: draft)
            pendingEmailChallenge = refreshedChallenge
            statusMessage = "We sent a fresh verification code."
            isLoading = false
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

    func requestPasswordReset(email: String) async {
        isLoading = true
        authErrorMessage = nil
        statusMessage = nil

        do {
            try await emailProvider.requestPasswordReset(email: email)
            statusMessage = "If that email is registered, a password reset link is on the way."
            isLoading = false
        } catch {
            isLoading = false
            authErrorMessage = error.localizedDescription
        }
    }

    func signInWithGoogle() {
        guard isGoogleAuthAvailable else {
            authErrorMessage = UnavailableGoogleAuthProvider.message
            statusMessage = nil
            isLoading = false
            return
        }

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
        guard SupabaseRuntimeConfiguration.isConfigured else {
            authErrorMessage = SupabaseRuntimeConfiguration.missingConfigurationMessage
            statusMessage = nil
            isLoading = false
            return
        }
        authErrorMessage = nil
        statusMessage = nil
        isLoading = true
        Task {
            do {
                let session = try await appleProvider.startSignIn()
                finishSignIn(session)
            } catch {
                isLoading = false
                let authError = error as? ASAuthorizationError
                if authError?.code != .canceled {
                    authErrorMessage = error.localizedDescription
                }
            }
        }
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
        pendingDisplayName = currentSession?.displayName ?? "\(AppBrand.name) User"
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
        pendingDisplayName = displayName.isEmpty ? (session?.displayName ?? "\(AppBrand.name) User") : displayName
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
            displayName: session?.displayName ?? "\(AppBrand.name) User"
        )
    }

    #if targetEnvironment(simulator)
    func signInAsTestUser() {
        let session = UserSession(
            provider: .apple,
            userID: UUID().uuidString,
            displayName: "\(AppBrand.name) User",
            email: "test@simulator.local",
            sessionToken: UUID().uuidString,
            tokenType: .debugSimulator,
            backendAccessToken: nil
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
            // Note: ASAuthorizationAppleIDCredential is no longer handled here.
            // SupabaseAppleAuthProvider uses its own ASAuthorizationController + delegate.

            case let cred as ASAuthorizationPlatformPublicKeyCredentialAssertion:
                let session = UserSession(
                    provider: .passkey,
                    userID: {
                        guard let decoded = String(data: cred.userID, encoding: .utf8) else {
                            authLogger.error("Passkey cred.userID failed UTF-8 decode — falling back to pendingUserHandle")
                            return pendingUserHandle
                        }
                        return decoded
                    }(),
                    displayName: pendingDisplayName.isEmpty ? (currentSession?.displayName ?? "User") : pendingDisplayName,
                    email: storedSession?.email,
                    sessionToken: cred.signature.base64EncodedString(),
                    tokenType: .passkeySignature,
                    backendAccessToken: nil,
                    credentialID: cred.credentialID
                )
                finishSignIn(session)

            case let cred as ASAuthorizationSecurityKeyPublicKeyCredentialAssertion:
                let session = UserSession(
                    provider: .passkey,
                    userID: {
                        guard let decoded = String(data: cred.userID, encoding: .utf8) else {
                            authLogger.error("Passkey cred.userID failed UTF-8 decode — falling back to pendingUserHandle")
                            return pendingUserHandle
                        }
                        return decoded
                    }(),
                    displayName: pendingDisplayName.isEmpty ? (currentSession?.displayName ?? "User") : pendingDisplayName,
                    email: storedSession?.email,
                    sessionToken: cred.signature.base64EncodedString(),
                    tokenType: .passkeySignature,
                    backendAccessToken: nil,
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
// MARK: – Apple session merge helper

extension SignInService {
    /// Merge an incoming Apple credential with an existing session.
    /// Retains existing display name / email when the incoming values are empty.
    static func mergedAppleSession(
        userID: String,
        incomingName: String,
        incomingEmail: String?,
        existingAppleSession: UserSession?
    ) -> UserSession {
        let displayName = incomingName.isEmpty
            ? (existingAppleSession?.displayName ?? "")
            : incomingName
        let email = incomingEmail ?? existingAppleSession?.email
        return UserSession(
            provider: .apple,
            userID: userID,
            displayName: displayName,
            email: email,
            phone: existingAppleSession?.phone,
            avatarURL: existingAppleSession?.avatarURL,
            sessionToken: userID,
            tokenType: .appleUserID,
            backendAccessToken: existingAppleSession?.backendAccessToken,
            credentialID: existingAppleSession?.credentialID
        )
    }
}

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
