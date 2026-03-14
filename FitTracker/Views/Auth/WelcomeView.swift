// Views/Auth/WelcomeView.swift
// First screen the user sees before signing in.
// "Welcome Regev, ready to begin"
// → Log In button (active)  → SignInView sheet
// → Register button (cosmetic only — visual placeholder for future)

import SwiftUI

struct WelcomeView: View {

    @EnvironmentObject var signIn: SignInService
    @EnvironmentObject var dataStore: EncryptedDataStore

    @State private var showSignIn       = false
    @State private var showRegisterNote = false
    @State private var logoScale: CGFloat = 0.6
    @State private var logoOpacity: CGFloat = 0
    @State private var textOffset: CGFloat = 30
    @State private var textOpacity: CGFloat = 0
    @State private var buttonsOffset: CGFloat = 40
    @State private var buttonsOpacity: CGFloat = 0

    var body: some View {
        ZStack {
            // ── Background gradient ───────────────────────
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.08, blue: 0.06),
                         Color(red: 0.06, green: 0.14, blue: 0.10),
                         Color(red: 0.02, green: 0.06, blue: 0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Subtle grid pattern overlay
            GeometryReader { geo in
                Canvas { ctx, size in
                    let spacing: CGFloat = 32
                    var path = Path()
                    var x: CGFloat = 0
                    while x < size.width {
                        path.move(to: .init(x: x, y: 0))
                        path.addLine(to: .init(x: x, y: size.height))
                        x += spacing
                    }
                    var y: CGFloat = 0
                    while y < size.height {
                        path.move(to: .init(x: 0, y: y))
                        path.addLine(to: .init(x: size.width, y: y))
                        y += spacing
                    }
                    ctx.stroke(path, with: .color(.green.opacity(0.04)), lineWidth: 0.5)
                }
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // ── Logo + branding ───────────────────────
                VStack(spacing: 20) {
                    ZStack {
                        // Outer glow ring
                        Circle()
                            .fill(Color.green.opacity(0.12))
                            .frame(width: 120, height: 120)
                            .blur(radius: 16)
                        // Icon ring
                        Circle()
                            .stroke(
                                AngularGradient(colors: [.green, .mint, .green.opacity(0.3), .green],
                                                center: .center),
                                lineWidth: 1.5
                            )
                            .frame(width: 96, height: 96)
                        // Icon
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 38, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(colors: [.green, .mint],
                                               startPoint: .top, endPoint: .bottom)
                            )
                    }
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)

                    VStack(spacing: 8) {
                        Text("FitTracker")
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        // Personalised welcome line
                        HStack(spacing: 6) {
                            Text("Welcome back")
                                .foregroundStyle(.secondary)
                            if !dataStore.userProfile.name.isEmpty {
                                Text(dataStore.userProfile.name)
                                    .foregroundStyle(
                                        LinearGradient(colors: [.green, .mint],
                                                       startPoint: .leading, endPoint: .trailing)
                                    )
                                    .fontWeight(.semibold)
                            }
                        }
                        .font(.title3)

                        Text("Ready to begin")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .opacity(0.7)
                    }
                    .offset(y: textOffset)
                    .opacity(textOpacity)
                }

                Spacer().frame(height: 56)

                // ── Tagline chips ─────────────────────────
                HStack(spacing: 10) {
                    ForEach(["🔒 Encrypted", "☁️ CloudKit", "⌚ Apple Watch"], id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Color.white.opacity(0.06), in: Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.08)))
                    }
                }
                .opacity(buttonsOpacity)

                Spacer()

                // ── Action buttons ────────────────────────
                VStack(spacing: 14) {

                    // LOG IN — active
                    Button {
                        showSignIn = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.title3)
                            Text("Log In")
                                .font(.headline)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .opacity(0.6)
                        }
                        .padding(.horizontal, 22)
                        .padding(.vertical, 17)
                        .foregroundStyle(.black)
                        .background(
                            LinearGradient(colors: [.green, Color(red: 0.2, green: 0.85, blue: 0.5)],
                                           startPoint: .leading, endPoint: .trailing),
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                        .shadow(color: .green.opacity(0.35), radius: 12, y: 4)
                    }
                    .buttonStyle(.plain)

                    // REGISTER — cosmetic (visual only)
                    Button {
                        showRegisterNote = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "person.badge.plus")
                                .font(.title3)
                                .opacity(0.5)
                            Text("Create Account")
                                .font(.headline)
                                .opacity(0.5)
                            Spacer()
                            Text("Coming soon")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Color.secondary.opacity(0.1), in: Capsule())
                        }
                        .padding(.horizontal, 22)
                        .padding(.vertical, 17)
                        .foregroundStyle(.white)
                        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1)))
                    }
                    .buttonStyle(.plain)

                    // Privacy footnote
                    Text("Your health data never leaves your Apple ecosystem.\nAll data is double-encrypted end-to-end.")
                        .font(.caption2)
                        .foregroundStyle(.secondary.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 28)
                .offset(y: buttonsOffset)
                .opacity(buttonsOpacity)

                Spacer().frame(height: 48)
            }
        }
        // ── Entry animations ──────────────────────────────
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.1)) {
                logoScale = 1.0; logoOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.4)) {
                textOffset = 0; textOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.7)) {
                buttonsOffset = 0; buttonsOpacity = 1.0
            }
        }
        // ── Sign-in sheet ─────────────────────────────────
        .sheet(isPresented: $showSignIn) {
            SignInView()
                .environmentObject(signIn)
                .presentationDetents([.large])
                .presentationCornerRadius(28)
                .presentationBackground(.ultraThinMaterial)
        }
        // ── Register toast ────────────────────────────────
        .alert("Coming Soon", isPresented: $showRegisterNote) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Account registration will be available in the next update. Use Log In with Apple, Google, or Facebook to get started now.")
        }
    }
}
