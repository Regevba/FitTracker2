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
        authError = nil
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
            isAuthenticated = false
            authError = "Face ID or Touch ID is required to unlock FitTracker. Set up biometrics in device settings, then try again."
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
            LinearGradient(
                colors: [Color.black, Color(red: 0.05, green: 0.12, blue: 0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack {
                Spacer()

                VStack(spacing: 22) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.14))
                            .frame(width: 108, height: 108)
                            .blur(radius: 10)
                        Circle()
                            .stroke(Color.green.opacity(0.22), lineWidth: 1)
                            .frame(width: 86, height: 86)
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundStyle(.green)
                    }

                    VStack(spacing: 8) {
                        Text("Unlock FitTracker")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(.white)
                        Text("Use \(biometricName) to reopen your encrypted data.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.68))
                            .multilineTextAlignment(.center)
                    }

                    Button { auth.authenticate() } label: {
                        HStack(spacing: 10) {
                            Image(systemName: biometricIcon).font(.title3)
                            Text(biometricLabel).fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(.green, in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(.black)
                    }
                    .buttonStyle(.plain)

                    if let err = auth.authError {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.82))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(28)
                .frame(maxWidth: 360)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 28))
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .padding(.horizontal, 24)

                Spacer()
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

    private var biometricName: String {
        switch biometricType {
        case .faceID:  "Face ID"
        case .touchID: "Touch ID"
        default:       "biometric unlock"
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
