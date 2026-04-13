// FitTracker/Services/Auth/GoogleAuthProvider.swift
// FitTracker/Services/Auth/GoogleAuthProvider.swift
// Real Google Sign-In provider using the GoogleSignIn SDK + Supabase idToken exchange.
//
// Runtime activation still depends on:
//   1. A valid Google client ID in Info.plist
//   2. A valid reversed client ID URL scheme in Info.plist
//   3. Google provider enabled in Supabase Auth
//
// SignInService uses GoogleRuntimeConfiguration to keep the live UI honest
// until those runtime pieces are actually present.

import Auth   // supabase-swift
import GoogleSignIn
import UIKit

enum GoogleRuntimeConfiguration {
    static func clientID(in bundle: Bundle = .main) -> String? {
        let value = (bundle.object(forInfoDictionaryKey: "GoogleClientID") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !value.contains("YOUR_GOOGLE_CLIENT_ID") else { return nil }
        return value
    }

    static func reversedClientID(in bundle: Bundle = .main) -> String? {
        let value = (bundle.object(forInfoDictionaryKey: "GoogleReversedClientID") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !value.contains("YOUR_REVERSED_CLIENT_ID") else { return nil }
        return value
    }

    static var isConfigured: Bool {
        clientID() != nil && reversedClientID() != nil
    }
}

struct GoogleAuthProvider: GoogleAuthProviding {

    func signIn() async throws -> UserSession {
        guard let clientID = GoogleRuntimeConfiguration.clientID() else {
            throw NSError(
                domain: "FitTracker.Auth",
                code: 503,
                userInfo: [NSLocalizedDescriptionKey: "Google Sign-In is not configured. Add GoogleClientID to Info.plist."]
            )
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        guard let rootVC = await rootViewController() else {
            throw FTAuthError.noRootViewController
        }
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
