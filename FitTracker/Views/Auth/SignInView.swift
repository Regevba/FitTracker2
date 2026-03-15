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
                Color(.systemBackground).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {

                        // ── Header ────────────────────────────────────
                        VStack(spacing: 12) {
                            Image(systemName: "figure.strengthtraining.traditional")
                                .font(.system(size: 44, weight: .semibold))
                                .foregroundStyle(
                                    LinearGradient(colors: [.green, .mint],
                                                   startPoint: .top, endPoint: .bottom)
                                )
                                .padding(.top, 8)

                            Text("Continue to FitTracker")
                                .font(.system(.title, design: .rounded, weight: .bold))

                            Text("Use Apple or a passkey to get back to your encrypted training data.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 16)

                        // ── Error banner ──────────────────────────────
                        if let err = errorBanner {
                            HStack(spacing: 10) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                Text(err)
                                    .font(.caption)
                                Spacer()
                                Button { errorBanner = nil } label: {
                                    Image(systemName: "xmark").font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(12)
                            .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.25)))
                            .offset(x: shakeOffset)
                        }

                        VStack(spacing: 14) {

                            SocialSignInButton(
                                provider: .apple,
                                isLoading: signIn.isLoading
                            ) {
                                signIn.signInWithApple()
                            }

                            VStack(spacing: 10) {
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
                                HStack(spacing: 12) {
                                    Image(systemName: "hammer.fill")
                                        .foregroundStyle(.orange)
                                    Text("Continue as Test User")
                                        .font(.subheadline.weight(.semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.orange.opacity(0.3)))
                            }
                            .buttonStyle(.plain)
                            .disabled(signIn.isLoading)
                            #endif
                        }

                        // ── Footer ────────────────────────────────────
                        VStack(spacing: 6) {
                            Text("Apple sign-in is the default. Passkeys work for iCloud Keychain and hardware keys like YubiKey.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if !signIn.isPasskeyConfigured {
                                Text("Passkey setup is currently unavailable until `PasskeyRelyingPartyID` is configured.")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                            Text("Your data stays private, encrypted, and inside your Apple ecosystem.")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 24)
                    }
                    .padding(.horizontal, 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.secondary)
                }
            }
            // Watch auth state
            .onChange(of: signIn.state) { _, newState in
                switch newState {
                case .authenticated:
                    dismiss()
                case .error(let msg):
                    errorBanner = msg
                    withAnimation(.default.repeatCount(3, autoreverses: true)) {
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
            HStack(spacing: 14) {
                providerIcon
                    .frame(width: 28)

                Text("Continue with \(provider.rawValue)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(labelColor)

                Spacer()

                if isLoading {
                    ProgressView()
                        .tint(labelColor)
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(bgColor, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(borderColor, lineWidth: 1)
            )
            .shadow(color: shadowColor, radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .opacity(isLoading ? 0.7 : 1.0)
    }

    @ViewBuilder
    private var providerIcon: some View {
        switch provider {
        case .apple:
            Image(systemName: "apple.logo")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(labelColor)
        case .google:
            // Google "G" drawn with SF Symbols approximation
            ZStack {
                Circle().fill(Color.white).frame(width: 26, height: 26)
                Text("G")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.26, green: 0.52, blue: 0.96))
            }
        case .facebook:
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(red: 0.23, green: 0.35, blue: 0.60))
                    .frame(width: 28, height: 28)
                Text("f")
                    .font(.system(size: 18, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
            }
        case .passkey:
            Image(systemName: "key.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.purple)
        }
    }

    private var bgColor: Color {
        switch provider {
        case .apple:    return Color(.label)            // black in light, white in dark
        case .google:   return Color(.systemBackground)
        case .facebook: return Color(red: 0.23, green: 0.35, blue: 0.60)
        case .passkey:  return Color.purple.opacity(0.08)
        }
    }

    private var labelColor: Color {
        switch provider {
        case .apple:    return Color(.systemBackground) // white in dark, black in light
        case .google:   return Color(.label)
        case .facebook: return .white
        case .passkey:  return .purple
        }
    }

    private var borderColor: Color {
        switch provider {
        case .apple:    return .clear
        case .google:   return Color.secondary.opacity(0.25)
        case .facebook: return .clear
        case .passkey:  return Color.purple.opacity(0.25)
        }
    }

    private var shadowColor: Color {
        switch provider {
        case .apple:    return Color.black.opacity(0.15)
        case .google:   return Color.black.opacity(0.06)
        case .facebook: return Color(red: 0.23, green: 0.35, blue: 0.60).opacity(0.3)
        case .passkey:  return .purple.opacity(0.1)
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
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(color)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isLoading {
                    ProgressView().tint(color).scaleEffect(0.8)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .background(color.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.15)))
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}
