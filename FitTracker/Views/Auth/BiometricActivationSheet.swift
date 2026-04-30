// BiometricActivationSheet.swift — auth-polish-v2 B1
// Per PRD §FR-9..11 and ux-spec.md §5.4. One-time post-sign-in modal that
// invites the user to enable Face ID / Touch ID. Presented as a `.medium`
// detent sheet from the auth flow root once per account, gated by
// `biometricAuth.isAvailable && !settings.requireBiometricUnlockOnReopen
// && !settings.hasAskedForBiometricActivation`. Trigger wiring + persistence
// land in B2/B3; analytics events in B4.
//
// Pure View: takes two callbacks (onEnable async-returns-Bool, onDecline)
// and owns its loading + error state. The actual LAContext.evaluatePolicy
// call lives in the BiometricService extension (B2); the parent (B3) wires
// onEnable to that and returns the Bool result.

import SwiftUI

struct BiometricActivationSheet: View {
    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var signIn: SignInService
    @EnvironmentObject private var analytics: AnalyticsService

    /// Performed when the user taps "Enable {biometricLabel}". Returns true
    /// when the LAContext scan succeeded and the activation flag was set
    /// (sheet dismisses), false on user-cancel / system failure (sheet stays
    /// open with the error banner).
    let onEnable: () async -> Bool

    /// Performed when the user taps "Not now". Parent sets the
    /// `hasAskedForBiometricActivation` flag and dismisses.
    let onDecline: () -> Void

    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: AppSpacing.medium) {
            FitMeBrandIcon(size: 36)
                .accessibilityHidden(true)
                .padding(.top, AppSpacing.medium)

            Text("Unlock \(AppBrand.name) with \(biometricLabel)")
                .font(AppText.pageTitle)
                .foregroundStyle(AppColor.Text.primary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel("Unlock \(AppBrand.name) with \(biometricLabel)")
                .accessibilityAddTraits(.isHeader)

            Text("Your data stays encrypted on this device.")
                .font(AppText.subheading)
                .foregroundStyle(AppColor.Text.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel("Your data stays encrypted on this device")

            if let errorMessage {
                AuthBannerView(
                    icon: "exclamationmark.triangle.fill",
                    text: errorMessage,
                    tint: AppColor.Status.error
                )
                .accessibilityLabel("Biometric authentication failed. Try again or tap Not now")
                .accessibilityAddTraits(.isStaticText)
            }

            Button {
                enableTapped()
            } label: {
                if isLoading {
                    ProgressView()
                        .tint(AppColor.Text.inversePrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.small)
                        .accessibilityLabel("Setting up \(biometricLabel), please wait")
                } else {
                    Text("Enable \(biometricLabel)")
                }
            }
            .buttonStyle(AuthPrimaryButtonStyle())
            .disabled(isLoading)
            .accessibilityLabel("Enable \(biometricLabel)")
            .accessibilityHint("Activates biometric unlock for future app launches")

            Button {
                guard !isLoading else { return }
                analytics.logAuthBiometricActivationDeclined(
                    biometricType: auth.biometricTypeAnalytics
                )
                onDecline()
            } label: {
                Text("Not now")
                    .font(AppText.subheading)
                    .foregroundStyle(AppColor.Text.secondary)
                    .underline()
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .disabled(isLoading)
            .accessibilityLabel("Not now")
            .accessibilityHint("Skips biometric setup. You can enable it later in Settings")

            Spacer(minLength: AppSpacing.small)
        }
        .padding(.horizontal, AppSpacing.medium)
        .padding(.bottom, AppSpacing.medium)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(AppRadius.authSheet)
        .background(AppColor.Surface.elevated)
        .onAppear {
            // B4 — _offered fires once when the sheet first appears. Sheet
            // dismissal flips presentation off, so .onAppear is single-shot
            // per modal lifecycle (not per state change).
            analytics.logAuthBiometricActivationOffered(
                biometricType: auth.biometricTypeAnalytics
            )
        }
    }

    private var biometricLabel: String {
        // AuthManager.biometricLabel returns "Use Face ID" / "Use Touch ID";
        // strip the "Use " prefix to compose CTA + headline naturally.
        auth.biometricLabel.replacingOccurrences(of: "Use ", with: "")
    }

    private func enableTapped() {
        guard !isLoading else { return }
        errorMessage = nil
        isLoading = true
        Task {
            let succeeded = await onEnable()
            isLoading = false
            if succeeded {
                // B4 — _activated. provider is the auth method that brought
                // the user here (PRD Yes-conversion event needs both params).
                analytics.logAuthBiometricActivated(
                    biometricType: auth.biometricTypeAnalytics,
                    provider: providerString
                )
            } else {
                // B4 — _activation_declined fires for any non-success path
                // (system-cancel, biometry-failed, etc). The sheet itself
                // stays open with the error banner; "Not now" tap is a
                // separate decline path handled by onDecline.
                analytics.logAuthBiometricActivationDeclined(
                    biometricType: auth.biometricTypeAnalytics
                )
                errorMessage = "\(biometricLabel) didn't work. Try again or tap 'Not now'."
            }
        }
    }

    private var providerString: String {
        // AuthProvider rawValues are capitalised ("Apple", "Google", ...);
        // PRD analytics enum is lowercase. Lowercase pass-through is safe
        // for current cases.
        signIn.activeSession?.provider.rawValue.lowercased() ?? "unknown"
    }
}
