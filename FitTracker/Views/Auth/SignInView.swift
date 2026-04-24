// Views/Auth/SignInView.swift
// Sign-in screen presented as a sheet from WelcomeView.
// Primary paths: Apple sign-in or passkey / security key.

import SwiftUI
import AuthenticationServices

struct SignInView: View {

    @EnvironmentObject var signIn: SignInService
    @Environment(\.dismiss) var dismiss

    @State private var errorBanner: String?
    @State private var shakeOffset: CGFloat = 0

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {

                // Background
                AppColor.Background.appPrimary.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.large) {

                        // ── Header ────────────────────────────────────
                        VStack(spacing: AppSpacing.xSmall) {
                            Image(systemName: "figure.strengthtraining.traditional")
                                .font(AppText.metricHero)
                                .foregroundStyle(AppGradient.brand)
                                .padding(.top, AppSpacing.xxSmall)

                            Text("Continue to \(AppBrand.name)")
                                .font(AppText.pageTitle)
                                .foregroundStyle(AppColor.Text.primary)

                            Text("Use Apple or a passkey to get back to your encrypted training data.")
                                .font(AppText.subheading)
                                .foregroundStyle(AppColor.Text.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, AppSpacing.small)

                        // ── Error banner ──────────────────────────────
                        if let err = errorBanner {
                            HStack(spacing: AppSpacing.xxSmall) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(AppColor.Status.warning)
                                Text(err)
                                    .font(AppText.caption)
                                    .foregroundStyle(AppColor.Text.primary)
                                Spacer()
                                Button { errorBanner = nil } label: {
                                    Image(systemName: "xmark")
                                        .font(AppText.caption)
                                        .foregroundStyle(AppColor.Text.secondary)
                                }
                            }
                            .padding(AppSpacing.xSmall)
                            .background(AppColor.Status.warning.opacity(0.10), in: RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                                    .stroke(AppColor.Status.warning.opacity(0.25))
                            )
                            .offset(x: shakeOffset)
                        }

                        VStack(spacing: AppSpacing.xSmall) {

                            SocialSignInButton(
                                provider: .apple,
                                isLoading: signIn.isLoading
                            ) {
                                signIn.signInWithApple()
                            }

                            VStack(spacing: AppSpacing.xxSmall) {
                                PasskeyActionButton(
                                    icon: "person.badge.key.fill",
                                    title: "Use Passkey",
                                    subtitle: "Sign in with a saved passkey or security key",
                                    color: .indigo,
                                    isLoading: signIn.isLoading
                                ) {
                                    signIn.signInWithPasskey()
                                }
                                .disabled(!signIn.isPasskeyConfigured)

                                PasskeyActionButton(
                                    icon: "plus.circle.fill",
                                    title: "Create Passkey",
                                    subtitle: "Create one on this device or register a hardware key",
                                    color: .purple,
                                    isLoading: signIn.isLoading
                                ) {
                                    signIn.registerPasskey()
                                }
                                .disabled(!signIn.isPasskeyConfigured)
                            }

                            #if targetEnvironment(simulator)
                            Button { signIn.signInAsTestUser() } label: {
                                HStack(spacing: AppSpacing.xSmall) {
                                    Image(systemName: "hammer.fill")
                                        .foregroundStyle(AppColor.Status.warning)
                                    Text("Continue as Test User")
                                        .font(AppText.callout)
                                        .foregroundStyle(AppColor.Status.warning)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, AppSpacing.small)
                                .background(AppColor.Status.warning.opacity(0.12), in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                                        .stroke(AppColor.Status.warning.opacity(0.3))
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(signIn.isLoading)
                            #endif
                        }

                        // ── Footer ────────────────────────────────────
                        VStack(spacing: AppSpacing.xxSmall) {
                            Text("Apple sign-in is the default. Passkeys work for iCloud Keychain and hardware keys like YubiKey.")
                                .font(AppText.caption)
                                .foregroundStyle(AppColor.Text.secondary)
                            if !signIn.isPasskeyConfigured {
                                Text("Passkey setup is currently unavailable until `PasskeyRelyingPartyID` is configured.")
                                    .font(AppText.monoLabel)
                                    .foregroundStyle(AppColor.Status.warning)
                            }
                            Text("Your data stays private, encrypted, and inside your Apple ecosystem.")
                                .font(AppText.monoLabel)
                                .foregroundStyle(AppColor.Text.tertiary)
                        }
                        .multilineTextAlignment(.center)
                        .padding(.bottom, AppSpacing.large)
                    }
                    .padding(.horizontal, AppSpacing.large)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(AppColor.Text.secondary)
                }
            }
            // Watch auth state
            .onChange(of: signIn.state) { _, newState in
                switch newState {
                case .authenticated:
                    dismiss()
                case .error(let msg):
                    errorBanner = msg
                    withAnimation(AppEasing.short.repeatCount(3, autoreverses: true)) {
                        shakeOffset = 6
                    }
                    Task { try? await Task.sleep(for: .milliseconds(300)); shakeOffset = 0 }
                default:
                    break
                }
            }
        }
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – Social Sign-In Button
// ─────────────────────────────────────────────────────────

struct SocialSignInButton: View {

    let provider:  AuthProvider
    let isLoading: Bool
    let action:    () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.xSmall) {
                providerIcon
                    .frame(width: 28)

                Text("Continue with \(provider.rawValue)")
                    .font(AppText.callout)
                    .foregroundStyle(labelColor)

                Spacer()

                if isLoading {
                    FitMeLogoLoader(mode: .breathe, size: .small)
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal, AppSpacing.medium)
            .padding(.vertical, AppSpacing.small)
            .background(bgColor, in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .shadow(color: shadowColor, radius: 6, y: 2)
        }
        .accessibilityIdentifier("auth.signin.\(provider.accessibilitySlug)")
        .buttonStyle(.plain)
        .disabled(isLoading)
        .opacity(isLoading ? 0.7 : 1.0)
    }

    @ViewBuilder
    private var providerIcon: some View {
        switch provider {
        case .apple:
            Image(systemName: "apple.logo")
                .font(AppText.titleMedium)
                .foregroundStyle(labelColor)
        case .google, .facebook:
            Image(systemName: provider == .google ? "g.circle.fill" : "f.circle.fill")
                .font(AppText.titleMedium)
                .foregroundStyle(labelColor)
        case .passkey:
            Image(systemName: "key.fill")
                .font(AppText.callout)
                .foregroundStyle(AppColor.Accent.sleep)
        case .email:
            Image(systemName: "envelope.fill")
                .font(AppText.callout)
                .foregroundStyle(AppColor.Accent.secondary)
        }
    }

    private var bgColor: Color {
        switch provider {
        case .apple:              return Color(.label)
        case .google, .facebook:  return AppColor.Brand.warm.opacity(0.08)
        case .passkey:            return AppColor.Accent.sleep.opacity(0.08)
        case .email:              return AppColor.Accent.secondary.opacity(0.08)
        }
    }

    private var labelColor: Color {
        switch provider {
        case .apple:              return AppColor.Text.inversePrimary
        case .google, .facebook:  return AppColor.Brand.warm
        case .passkey:            return AppColor.Accent.sleep
        case .email:              return AppColor.Accent.secondary
        }
    }

    private var borderColor: Color {
        switch provider {
        case .apple:              return .clear
        case .google, .facebook:  return AppColor.Brand.warm.opacity(0.25)
        case .passkey:            return AppColor.Accent.sleep.opacity(0.25)
        case .email:              return AppColor.Accent.secondary.opacity(0.25)
        }
    }

    private var shadowColor: Color {
        switch provider {
        case .apple:              return AppShadow.cardColor
        case .google, .facebook:  return AppColor.Brand.warm.opacity(0.1)
        case .passkey:            return AppColor.Accent.sleep.opacity(0.1)
        case .email:              return AppColor.Accent.secondary.opacity(0.14)
        }
    }
}

private extension AuthProvider {
    var accessibilitySlug: String {
        switch self {
        case .apple:
            return "apple"
        case .google:
            return "google"
        case .facebook:
            return "facebook"
        case .passkey:
            return "passkey"
        case .email:
            return "email"
        }
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – Passkey action button
// ─────────────────────────────────────────────────────────

struct PasskeyActionButton: View {
    let icon:      String
    let title:     String
    let subtitle:  String
    let color:     Color
    let isLoading: Bool
    let action:    () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.xSmall) {
                Image(systemName: icon)
                    .font(AppText.callout)
                    .foregroundStyle(color)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: AppSpacing.micro) {
                    Text(title)
                        .font(AppText.callout)
                        .foregroundStyle(AppColor.Text.primary)
                    Text(subtitle)
                        .font(AppText.monoLabel)
                        .foregroundStyle(AppColor.Text.secondary)
                }

                Spacer()

                if isLoading {
                    FitMeLogoLoader(mode: .breathe, size: .small)
                } else {
                    Image(systemName: "chevron.right")
                        .font(AppText.captionStrong)
                        .foregroundStyle(AppColor.Text.secondary)
                }
            }
            .padding(AppSpacing.xSmall)
            .background(color.opacity(0.06), in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                    .stroke(color.opacity(0.15))
            )
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}
