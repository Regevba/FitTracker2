// FitTracker/Services/Auth/SupabaseAppleAuthProvider.swift
// Replaces SystemAppleAuthProvider. Exchanges Apple idToken with Supabase to
// obtain a JWT stored as UserSession.sessionToken.
//
// REQUIRES: supabase-swift package + Apple Developer enrollment resolved.
// Apple provider activation: Supabase → Auth → Providers → Apple (Service ID + .p8 key).

import AuthenticationServices
import CryptoKit
import Auth  // Supabase Auth module

/// Apple Sign In → Supabase JWT exchange.
/// Uses CheckedContinuation to bridge delegate callbacks into async/throws.
@MainActor
final class SupabaseAppleAuthProvider: NSObject, AppleAuthProviding {

    private var continuation: CheckedContinuation<UserSession, Error>?
    private var currentNonce: String?

    func startSignIn() async throws -> UserSession {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let rawNonce = Self.randomNonceString()
            self.currentNonce = rawNonce

            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = Self.sha256(rawNonce)

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    // MARK: - Nonce Helpers

    private static func randomNonceString(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var nonce = ""
        var remaining = length
        while remaining > 0 {
            let randoms: [UInt8] = (0..<16).compactMap { _ in
                var byte: UInt8 = 0
                guard SecRandomCopyBytes(kSecRandomDefault, 1, &byte) == errSecSuccess else { return nil }
                return byte
            }
            for byte in randoms {
                guard remaining > 0 else { break }
                if byte < charset.count {
                    nonce.append(charset[Int(byte)])
                    remaining -= 1
                }
            }
        }
        return nonce
    }

    private static func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension SupabaseAppleAuthProvider: ASAuthorizationControllerDelegate {

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        Task { @MainActor in
            guard
                let cred = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = cred.identityToken,
                let idToken = String(data: tokenData, encoding: .utf8),
                let nonce = currentNonce
            else {
                continuation?.resume(throwing: FTAuthError.missingCredential)
                continuation = nil
                return
            }
            do {
                let session = try await supabase.auth.signInWithIdToken(
                    credentials: .init(provider: .apple, idToken: idToken, nonce: nonce))
                let name = [cred.fullName?.givenName, cred.fullName?.familyName]
                    .compactMap { $0 }
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
                var userSession = UserSession(from: session, displayName: name)
                userSession.provider = .apple
                continuation?.resume(returning: userSession)
            } catch {
                continuation?.resume(throwing: error)
            }
            continuation = nil
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor in
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension SupabaseAppleAuthProvider: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated { presentationAnchorOnMainActor() }
    }

    @MainActor
    private func presentationAnchorOnMainActor() -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
            ?? UIWindow(frame: UIScreen.main.bounds)
    }
}
