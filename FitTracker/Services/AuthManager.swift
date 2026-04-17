// Services/AuthManager.swift
// Biometric lock after sign-in — Face ID / Touch ID only
// Separate from SignInService (social/passkey auth)

import Foundation
@preconcurrency import LocalAuthentication
import SwiftUI

@MainActor
protocol BiometricQuickUnlockProviding {
    var isAvailable: Bool { get }
    var biometricLabel: String { get }
    var biometricName: String { get }
    var biometricIcon: String { get }
    func authenticateForQuickUnlock() async -> Bool
}

// ─────────────────────────────────────────────────────────
// MARK: – Biometric Lock Manager
// ─────────────────────────────────────────────────────────

@MainActor
final class AuthManager: ObservableObject, BiometricQuickUnlockProviding {

    @Published var isAuthenticated = false
    @Published var authError: String?

    init() {}

    func authenticate() {
        Task {
            _ = await authenticateForQuickUnlock()
        }
    }

    func authenticateForQuickUnlock() async -> Bool {
        #if targetEnvironment(simulator)
        isAuthenticated = true
        authError = nil
        await EncryptionService.shared.setSessionContext(LAContext())
        return true
        #else
        let ctx = LAContext()
        ctx.localizedFallbackTitle = ""
        var err: NSError?

        if ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err) {
            return await withCheckedContinuation { continuation in
                ctx.evaluatePolicy(
                    .deviceOwnerAuthenticationWithBiometrics,
                    localizedReason: "Unlock \(AppBrand.name) to access your encrypted health data"
                ) { ok, e in
                    Task { @MainActor [weak self] in
                        self?.isAuthenticated = ok
                        self?.authError = ok ? nil : e?.localizedDescription
                        if ok {
                            await EncryptionService.shared.setSessionContext(ctx)
                        }
                        continuation.resume(returning: ok)
                    }
                }
            }
        } else {
            isAuthenticated = false
            authError = "Face ID or Touch ID is required to unlock \(AppBrand.name). Set up biometrics in device settings, then try again."
            return false
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

    var isAvailable: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        let ctx = LAContext()
        var error: NSError?
        return ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        #endif
    }

    var biometricType: LABiometryType? {
        #if targetEnvironment(simulator)
        return .faceID
        #else
        let ctx = LAContext()
        var error: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return nil
        }
        return ctx.biometryType
        #endif
    }

    var biometricLabel: String {
        switch biometricType {
        case .faceID: "Use Face ID"
        case .touchID: "Use Touch ID"
        default: "Use Biometrics"
        }
    }

    var biometricName: String {
        switch biometricType {
        case .faceID: "Face ID"
        case .touchID: "Touch ID"
        default: "biometric unlock"
        }
    }

    var biometricIcon: String {
        switch biometricType {
        case .faceID: "faceid"
        case .touchID: "touchid"
        default: "lock.open.fill"
        }
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – Biometric lock screen (shown after sign-in)
// ─────────────────────────────────────────────────────────

struct LockScreenView: View {

    @EnvironmentObject var auth: AuthManager
    @State private var hasAttemptedAutoUnlock = false

    var body: some View {
        ZStack {
            AppGradient.authBackground
                .ignoresSafeArea()

            VStack {
                Spacer()

                VStack(spacing: AppSpacing.large) {
                    ZStack {
                        Circle()
                            .fill(AppColor.Brand.primary.opacity(0.14))
                            .frame(width: 108, height: 108)
                            .blur(radius: 10)
                        Circle()
                            .stroke(AppColor.Brand.primary.opacity(0.22), lineWidth: 1)
                            .frame(width: 86, height: 86)
                        Image(systemName: "lock.shield.fill")
                            .font(AppText.iconLarge)
                            .foregroundStyle(AppColor.Brand.primary)
                    }

                    VStack(spacing: AppSpacing.xxSmall) {
                        Text("Unlock \(AppBrand.name)")
                            .font(AppText.pageTitle)
                            .foregroundStyle(AppColor.Text.primary)
                        Text("Use \(biometricName) to reopen your encrypted data.")
                            .font(AppText.subheading)
                            .foregroundStyle(AppColor.Text.secondary)
                            .multilineTextAlignment(.center)
                    }

                    Button { auth.authenticate() } label: {
                        HStack(spacing: AppSpacing.xxSmall) {
                            Image(systemName: biometricIcon).font(AppText.titleMedium)
                            Text(biometricLabel).fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.small)
                        .background(AppColor.Brand.primary, in: RoundedRectangle(cornerRadius: AppRadius.medium))
                        .foregroundStyle(AppColor.Text.primary)
                    }
                    .buttonStyle(.plain)

                    if let err = auth.authError {
                        Text(err)
                            .font(AppText.caption)
                            .foregroundStyle(AppColor.Status.error.opacity(0.82))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(AppSpacing.xLarge)
                .frame(maxWidth: 360)
                .background(AppColor.Surface.materialLight, in: RoundedRectangle(cornerRadius: AppRadius.xLarge))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.xLarge)
                        .stroke(AppColor.Border.subtle, lineWidth: 1)
                )
                .padding(.horizontal, AppSpacing.large)

                Spacer()
            }
        }
        .onAppear {
            // Auto-trigger Face ID/Touch ID on appear — no manual button press needed
            guard !hasAttemptedAutoUnlock else { return }
            hasAttemptedAutoUnlock = true
            Task {
                try? await Task.sleep(for: .seconds(0.3))  // brief branded delay
                auth.authenticate()
            }
        }
    }

    private var biometricLabel: String { auth.biometricLabel.replacingOccurrences(of: "Use", with: "Unlock with") }
    private var biometricName: String { auth.biometricName }
    private var biometricIcon: String { auth.biometricIcon }
}
