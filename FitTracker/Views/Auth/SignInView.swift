// Views/Auth/SignInView.swift
// Sign-in screen presented as a sheet from WelcomeView.
// Providers: Apple · Google · Facebook
// Passkey / YubiKey: separate expandable section

import SwiftUI
import AuthenticationServices

struct SignInView: View {

    @EnvironmentObject var signIn: SignInService
    @Environment(\.dismiss) var dismiss

    @State private var showPasskeySection = false
    @State private var errorBanner: String?
    @State private var shakeOffset: CGFloat = 0

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {

                // Background
                Color(.systemBackground).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {

                        // ── Header ────────────────────────────────────
                        VStack(spacing: 10) {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 52))
                                .foregroundStyle(
                                    LinearGradient(colors: [.green, .mint],
                                                   startPoint: .top, endPoint: .bottom)
                                )
                                .padding(.top, 8)

                            Text("Sign In")
                                .font(.system(.title, design: .rounded, weight: .bold))

                            Text("Choose how you'd like to continue")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
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

                        // ── Social sign-in buttons ────────────────────
                        VStack(spacing: 12) {

                            // Apple
                            SocialSignInButton(
                                provider: .apple,
                                isLoading: signIn.isLoading
                            ) {
                                signIn.signInWithApple()
                            }

                        }

                        // ── Divider ───────────────────────────────────
                        HStack(spacing: 12) {
                            Rectangle().fill(Color.secondary.opacity(0.2)).frame(height: 0.5)
                            Text("or").font(.caption).foregroundStyle(.secondary)
                            Rectangle().fill(Color.secondary.opacity(0.2)).frame(height: 0.5)
                        }

                        // ── Passkey / YubiKey section ─────────────────
                        VStack(spacing: 0) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showPasskeySection.toggle()
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "key.fill")
                                        .font(.subheadline)
                                        .foregroundStyle(.purple)
                                        .frame(width: 28)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Sign in with Passkey or Security Key")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.primary)
                                        Text("YubiKey · NFC · USB-C hardware keys supported")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: showPasskeySection ? "chevron.up" : "chevron.down")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(16)
                                .background(Color.purple.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.purple.opacity(0.18)))
                            }
                            .buttonStyle(.plain)

                            if showPasskeySection {
                                VStack(spacing: 10) {
                                    // Authenticate with existing passkey
                                    PasskeyActionButton(
                                        icon: "person.badge.key.fill",
                                        title: "Use Saved Passkey",
                                        subtitle: "Stored on this device or iCloud Keychain",
                                        color: .purple,
                                        isLoading: signIn.isLoading
                                    ) {
                                        signIn.signInWithPasskey()
                                    }

                                    // Register new passkey
                                    PasskeyActionButton(
                                        icon: "plus.circle.fill",
                                        title: "Register New Passkey",
                                        subtitle: "Create a passkey or add a YubiKey / security key",
                                        color: .indigo,
                                        isLoading: signIn.isLoading
                                    ) {
                                        signIn.registerPasskey()
                                    }

                                }
                                .padding(.top, 8)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }

                        // ── Footer ────────────────────────────────────
                        VStack(spacing: 4) {
                            Text("By continuing, you agree to our Terms of Service.")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Text("Your data stays private, encrypted, and on your Apple devices.")
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
