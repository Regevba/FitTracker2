// BiometricUnlockView.swift — auth-polish-v2 B3
// Per PRD §FR-7..8 and ux-spec.md §5.5. Full-screen biometric-first unlock
// shown when `signIn.hasStoredSession && settings.requireBiometricUnlockOnReopen
// && biometricAuth.isAvailable`. Replaces the older inline LockScreenView
// (still defined in AuthManager.swift for backward compatibility).
//
// Auto-triggers the biometric scan on appear (one shot per presentation).
// On success the parent transitions away — this view doesn't own routing.

import SwiftUI

struct BiometricUnlockView: View {
    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var signIn: SignInService
    @EnvironmentObject private var analytics: AnalyticsService

    /// Optional fallback when the user opts out of biometric unlock for this
    /// session. Parent should transition to the email login surface.
    var onUsePassword: (() -> Void)?

    @State private var hasAttemptedAutoUnlock = false

    var body: some View {
        ZStack {
            AppGradient.authBackground
                .ignoresSafeArea()

            VStack(spacing: AppSpacing.large) {
                Spacer(minLength: 0)

                FitMeBrandIcon(size: 72)
                    .accessibilityHidden(true)

                Text("Welcome back, \(firstName)")
                    .font(AppText.hero)
                    .foregroundStyle(AppColor.Text.inversePrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .accessibilityLabel("Welcome back, \(firstName)")
                    .accessibilityAddTraits(.isHeader)

                Image(systemName: auth.biometricIcon)
                    .font(.system(size: 88, weight: .medium))
                    .foregroundStyle(AppColor.Accent.secondary)
                    .accessibilityHidden(true)

                Spacer(minLength: AppSpacing.medium)

                if let err = auth.authError {
                    AuthBannerView(
                        icon: "exclamationmark.triangle.fill",
                        text: err,
                        tint: AppColor.Status.error
                    )
                    .accessibilityLabel("\(biometricName) authentication failed. Use your password instead")
                }

                Button {
                    Task { await attemptUnlock() }
                } label: {
                    Text("Unlock with \(biometricName)")
                }
                .buttonStyle(AuthPrimaryButtonStyle())
                .accessibilityLabel("Unlock with \(biometricName)")
                .accessibilityHint("Authenticates using your device's biometric sensor to open \(AppBrand.name)")

                if let onUsePassword {
                    Button {
                        onUsePassword()
                    } label: {
                        Text("Use password")
                            .font(AppText.subheading)
                            .foregroundStyle(AppColor.Text.inverseSecondary)
                            .underline()
                    }
                    .frame(minHeight: AppSize.tapTarget)
                    .contentShape(Rectangle())
                    .accessibilityLabel("Use password instead")
                    .accessibilityHint("Signs you in with your email and password")
                }
            }
            .padding(.horizontal, AppSpacing.large)
            .padding(.vertical, AppSpacing.xLarge)
        }
        .onAppear {
            guard !hasAttemptedAutoUnlock else { return }
            hasAttemptedAutoUnlock = true
            Task {
                try? await Task.sleep(for: .seconds(0.3))
                await attemptUnlock()
            }
        }
    }

    private func attemptUnlock() async {
        let outcome = await auth.attemptUnlock()
        if outcome.succeeded {
            // B4 — _unlock_completed. duration_ms drives PRD §guardrail
            // "P95 < 1500ms".
            analytics.logAuthBiometricUnlockCompleted(
                biometricType: auth.biometricTypeAnalytics,
                durationMs: outcome.durationMs
            )
        } else {
            // B4 — _unlock_failed. reason classified from the LAError code
            // by AuthManager.classifyLAError; "other" when no error / unknown.
            analytics.logAuthBiometricUnlockFailed(
                biometricType: auth.biometricTypeAnalytics,
                reason: outcome.reason ?? "other"
            )
        }
    }

    private var firstName: String {
        // UserSession exposes `displayName` (e.g. "Regev Barak"); take the
        // first whitespace-separated token. Falls back to a generic greeting
        // when the session isn't available (defensive only — view shouldn't
        // present otherwise).
        guard let displayName = signIn.currentSession?.displayName else { return "back" }
        return displayName.split(separator: " ").first.map(String.init) ?? displayName
    }

    private var biometricName: String {
        auth.biometricLabel.replacingOccurrences(of: "Use ", with: "")
    }
}
