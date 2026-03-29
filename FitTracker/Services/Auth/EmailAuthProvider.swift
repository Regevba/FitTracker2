// FitTracker/Services/Auth/EmailAuthProvider.swift
// DORMANT: MockEmailAuthProvider is still wired in SignInService.
//
// To activate Email auth:
//   1. Ensure Email provider is enabled in Supabase → Auth → Providers
//   2. In SignInService.init(): swap MockEmailAuthProvider() → EmailAuthProvider()
//
// No package changes needed — supabase-swift already provides Auth.

import Auth  // Supabase Auth module

/// Real email auth provider using Supabase Auth signUp / OTP verification / signIn.
struct EmailAuthProvider: EmailAuthProviding {

    func register(_ reg: PendingEmailRegistration) async throws -> EmailRegistrationChallenge {
        // Supabase sends the verification email automatically on signUp.
        try await supabase.auth.signUp(
            email: reg.email,
            password: reg.password,
            data: [
                "first_name": .string(reg.firstName),
                "last_name":  .string(reg.lastName)
            ]
        )
        return EmailRegistrationChallenge(
            email: reg.email,
            expectedCode: "",          // server-side OTP — not echoed to client
            expiresAt: Date().addingTimeInterval(600)
        )
    }

    func verify(code: String, challenge: EmailRegistrationChallenge,
                draft: PendingEmailRegistration) async throws -> UserSession {
        let session = try await supabase.auth.verifyOTP(
            email: challenge.email,
            token: code,
            type: .signup
        )
        var userSession = UserSession(
            from: session,
            displayName: "\(draft.firstName) \(draft.lastName)"
                .trimmingCharacters(in: .whitespaces))
        userSession.provider = .email
        return userSession
    }

    func login(email: String, password: String) async throws -> UserSession {
        let session = try await supabase.auth.signIn(email: email, password: password)
        var userSession = UserSession(from: session)
        userSession.provider = .email
        return userSession
    }
}

extension EmailAuthProvider {
    func resendRegistrationCode(
        challenge: EmailRegistrationChallenge,
        draft: PendingEmailRegistration
    ) async throws -> EmailRegistrationChallenge {
        try await supabase.auth.resend(email: challenge.email, type: .signup)
        return EmailRegistrationChallenge(
            email: challenge.email,
            expectedCode: "",
            expiresAt: Date().addingTimeInterval(600)
        )
    }

    func requestPasswordReset(email: String) async throws {
        try await supabase.auth.resetPasswordForEmail(email)
    }
}
