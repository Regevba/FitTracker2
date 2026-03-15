// Services/AuthManager.swift
// Biometric lock after sign-in — Face ID / Touch ID only
// Separate from SignInService (social/passkey auth)

import Foundation
@preconcurrency import LocalAuthentication
import SwiftUI

// ─────────────────────────────────────────────────────────
// MARK: – Biometric Lock Manager
// ─────────────────────────────────────────────────────────

@MainActor
final class AuthManager: ObservableObject {

    @Published var isAuthenticated = false
    @Published var authError: String?

    init() { authenticate() }

    func authenticate() {
        #if targetEnvironment(simulator)
        // Skip biometric prompt on simulator — set authenticated immediately.
        isAuthenticated = true
        #else
        let ctx = LAContext()
        ctx.localizedFallbackTitle = ""
        var err: NSError?

        if ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err) {
            ctx.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                               localizedReason: "Unlock FitTracker to access your encrypted health data") { ok, e in
                Task { @MainActor [weak self] in
                    self?.isAuthenticated = ok
                    self?.authError = ok ? nil : e?.localizedDescription
                    if ok {
                        // Share the authenticated context with EncryptionService so all crypto
                        // operations in this session reuse it without re-prompting biometrics.
                        await EncryptionService.shared.setSessionContext(ctx)
                    }
                }
            }
        } else {
            // No biometrics configured — mark as authenticated immediately
            isAuthenticated = true
        }
        #endif
    }

    func lockOnBackground(clearCryptoSession: Bool = true) {
        isAuthenticated = false
        authError = nil
        guard clearCryptoSession else { return }
        // Invalidate the shared session context so the next unlock re-authenticates.
        Task { await EncryptionService.shared.clearSessionContext() }
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – Biometric lock screen (shown after sign-in)
// ─────────────────────────────────────────────────────────

struct LockScreenView: View {

    @EnvironmentObject var auth: AuthManager

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.green)
                    .symbolEffect(.pulse)

                VStack(spacing: 8) {
                    Text("FitTracker")
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Your health data is encrypted\nand protected on this device.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                VStack(spacing: 12) {
                    Button { auth.authenticate() } label: {
                        HStack(spacing: 10) {
                            Image(systemName: biometricIcon).font(.title3)
                            Text(biometricLabel).fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.green, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.black)
                    }
                    .padding(.horizontal, 32)

                    if let err = auth.authError {
                        Text(err)
                            .font(.caption2)
                            .foregroundStyle(.red.opacity(0.8))
                    }
                }

                Spacer().frame(height: 40)
            }
        }
    }

    private var biometricType: LABiometryType? {
        let ctx = LAContext()
        var error: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return nil
        }
        return ctx.biometryType
    }

    private var biometricLabel: String {
        switch biometricType {
        case .faceID:  "Unlock with Face ID"
        case .touchID: "Unlock with Touch ID"
        default:       "Unlock"
        }
    }

    private var biometricIcon: String {
        switch biometricType {
        case .faceID:  "faceid"
        case .touchID: "touchid"
        default:       "lock.open.fill"
        }
    }
}
