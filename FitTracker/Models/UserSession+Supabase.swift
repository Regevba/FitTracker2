// FitTracker/Models/UserSession+Supabase.swift
import Foundation
import Auth  // Supabase Auth module

extension UserSession {
    /// Initialize a UserSession from a Supabase Session.
    /// - Parameter session: The authenticated Supabase session.
    /// - Parameter displayName: Human-readable name from Apple/Google profile. Falls back to email if empty.
    /// - Note: Sets `provider = .apple` as default; callers set the correct provider after construction.
    init(from session: Session, displayName: String = "") {
        self.init(
            provider: .apple,
            userID: session.user.id.uuidString,
            displayName: displayName.isEmpty ? (session.user.email ?? "") : displayName,
            email: session.user.email,
            phone: session.user.phone,
            avatarURL: nil,
            sessionToken: session.user.id.uuidString,  // stable identity token
            backendAccessToken: session.accessToken,   // Supabase JWT for AI engine
            credentialID: nil,
            signedInAt: Date()
        )
    }
}
