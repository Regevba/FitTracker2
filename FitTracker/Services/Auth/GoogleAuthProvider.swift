// FitTracker/Services/Auth/GoogleAuthProvider.swift
// DORMANT: MockGoogleAuthProvider is still wired in SignInService.
//
// To activate Google Sign In:
//   1. Add GoogleSignIn-iOS package: https://github.com/google/GoogleSignIn-iOS
//   2. Add the reversed client ID URL scheme to Info.plist (CFBundleURLSchemes)
//   3. Add this file to the Xcode target (currently excluded — won't compile without the package)
//   4. In SignInService.init(): swap MockGoogleAuthProvider() → GoogleAuthProvider()
//
// This file is intentionally NOT added to the Xcode target until the package is present.
// Keeping it in the repo means activation requires no new code — just the steps above.

import Auth   // supabase-swift
import UIKit

/// Real Google Sign-In provider using GIDSignIn SDK + Supabase idToken exchange.
/// Requires the GoogleSignIn-iOS Swift package (https://github.com/google/GoogleSignIn-iOS).
struct GoogleAuthProvider: GoogleAuthProviding {

    func signIn() async throws -> UserSession {
        guard let rootVC = await rootViewController() else {
            throw FTAuthError.noRootViewController
        }
        // GIDSignIn is available after GoogleSignIn-iOS package is added.
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
        guard let idToken = result.user.idToken?.tokenString else {
            throw FTAuthError.missingCredential
        }
        let session = try await supabase.auth.signInWithIdToken(
            credentials: .init(provider: .google, idToken: idToken))
        var userSession = UserSession(
            from: session,
            displayName: result.user.profile?.name ?? "")
        userSession.provider = .google
        return userSession
    }

    @MainActor
    private func rootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController
    }
}
