// Views/Auth/WelcomeView.swift
// First screen the user sees before signing in.
// Keeps the entry point focused on continuing into the encrypted app.

import SwiftUI

struct WelcomeView: View {

    @EnvironmentObject var signIn: SignInService

    @State private var showSignIn       = false
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
            GeometryReader { _ in
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

                VStack(spacing: 22) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.12))
                            .frame(width: 120, height: 120)
                            .blur(radius: 16)
                        Circle()
                            .stroke(
                                AngularGradient(colors: [.green, .mint, .green.opacity(0.3), .green],
                                                center: .center),
                                lineWidth: 1.5
                            )
                            .frame(width: 96, height: 96)
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
                        Text(AppBrand.name)
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text("Continue into your encrypted training workspace.")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.9))

                        Text("Apple sign-in and passkeys are supported. \(AppBrand.name) keeps your health data encrypted on device and before sync.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 14)
                    }
                    .offset(y: textOffset)
                    .opacity(textOpacity)
                }

                Spacer().frame(height: 36)

                VStack(spacing: 10) {
                    welcomeFactRow(icon: "lock.shield.fill", text: "Encrypted locally before any iCloud sync")
                    welcomeFactRow(icon: "faceid", text: "Face ID or Touch ID can protect reopen access")
                    welcomeFactRow(icon: "key.fill", text: "Passkeys and security keys are supported")
                }
                .opacity(buttonsOpacity)
                .padding(.horizontal, 28)

                Spacer()

                VStack(spacing: 14) {
                    Button {
                        showSignIn = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.title3)
                            Text("Continue")
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

                    Text("Choose Apple sign-in or a passkey on the next screen.")
                        .font(.caption)
                        .foregroundStyle(.secondary.opacity(0.65))
                        .multilineTextAlignment(.center)
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
    }

    private func welcomeFactRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.green)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.78))
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}
