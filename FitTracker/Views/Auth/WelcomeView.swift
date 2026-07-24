// Views/Auth/WelcomeView.swift
// First screen the user sees before signing in.
// Keeps the entry point focused on continuing into the encrypted app.

import SwiftUI

struct WelcomeView: View {

    @EnvironmentObject var signIn: SignInService

    /// When true, the view seeds every animated element at its post-entry
    /// settled value and skips the `.onAppear` reveal. The entry animation is
    /// gated behind `.onAppear`, which never fires (or never completes) under
    /// the off-screen snapshot host, so the default render captures the
    /// pre-reveal state — a bare gradient. Rendering the settled state directly
    /// is the tractable fix (waiting / drawHierarchyInKeyWindow were ruled out).
    /// See observed-patterns W46. Production default (`false`) is unchanged.
    private let snapshotSettled: Bool

    @State private var showSignIn: Bool
    @State private var logoScale: CGFloat
    @State private var logoOpacity: CGFloat
    @State private var textOffset: CGFloat
    @State private var textOpacity: CGFloat
    @State private var buttonsOffset: CGFloat
    @State private var buttonsOpacity: CGFloat

    init(snapshotSettled: Bool = false) {
        self.snapshotSettled = snapshotSettled
        _showSignIn = State(initialValue: false)
        _logoScale = State(initialValue: snapshotSettled ? 1.0 : 0.6)
        _logoOpacity = State(initialValue: snapshotSettled ? 1.0 : 0)
        _textOffset = State(initialValue: snapshotSettled ? 0 : 30)
        _textOpacity = State(initialValue: snapshotSettled ? 1.0 : 0)
        _buttonsOffset = State(initialValue: snapshotSettled ? 0 : 40)
        _buttonsOpacity = State(initialValue: snapshotSettled ? 1.0 : 0)
    }

    var body: some View {
        ZStack {
            // ── Background gradient ───────────────────────
            AppGradient.authBackground
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
                    ctx.stroke(path, with: .color(AppColor.Accent.recovery.opacity(0.04)), lineWidth: 0.5)
                }
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: AppSpacing.large) {
                    ZStack {
                        Circle()
                            .fill(AppColor.Accent.recovery.opacity(0.12))
                            .frame(width: AppSize.illustrationLarge, height: AppSize.illustrationLarge)
                            .blur(radius: 16)
                        Circle()
                            .stroke(
                                AngularGradient(
                                    colors: [
                                        AppColor.Accent.recovery,
                                        AppColor.Brand.secondary,
                                        AppColor.Accent.recovery.opacity(0.3),
                                        AppColor.Accent.recovery,
                                    ],
                                    center: .center
                                ),
                                lineWidth: 1.5
                            )
                            .frame(width: AppSize.iconJumbo, height: AppSize.iconJumbo)
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(AppText.metricHero)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [AppColor.Accent.recovery, AppColor.Brand.secondary],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)

                    VStack(spacing: AppSpacing.xxSmall) {
                        Text(AppBrand.name)
                            .font(AppText.metricHero)
                            .foregroundStyle(AppColor.Text.inversePrimary)

                        Text("Continue into your encrypted training workspace.")
                            .font(AppText.titleMedium)
                            .foregroundStyle(AppColor.Text.inversePrimary.opacity(0.9))

                        Text("Apple sign-in and passkeys are supported. \(AppBrand.name) keeps your health data encrypted on device and before sync.")
                            .font(AppText.subheading)
                            .foregroundStyle(AppColor.Text.inverseSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppSpacing.xSmall)
                    }
                    .offset(y: textOffset)
                    .opacity(textOpacity)
                }

                Spacer().frame(height: AppSize.tapTargetCompact)

                VStack(spacing: AppSpacing.xxSmall) {
                    welcomeFactRow(icon: "lock.shield.fill", text: "Encrypted locally before any iCloud sync")
                    welcomeFactRow(icon: "faceid", text: "Face ID or Touch ID can protect reopen access")
                    welcomeFactRow(icon: "key.fill", text: "Passkeys and security keys are supported")
                }
                .opacity(buttonsOpacity)
                .padding(.horizontal, AppSpacing.xLarge)

                Spacer()

                VStack(spacing: AppSpacing.xSmall) {
                    AppButton(
                        title: "Continue",
                        systemImage: "arrow.right.circle.fill",
                        hierarchy: .primary
                    ) {
                        showSignIn = true
                    }

                    Text("Choose Apple sign-in or a passkey on the next screen.")
                        .font(AppText.caption)
                        .foregroundStyle(AppColor.Text.inverseTertiary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, AppSpacing.xLarge)
                .offset(y: buttonsOffset)
                .opacity(buttonsOpacity)

                Spacer().frame(height: 48)
            }
        }
        // ── Entry animations ──────────────────────────────
        .onAppear {
            // Snapshot renders the settled state directly (elements already at
            // their revealed values); no animation to schedule. See W46.
            guard !snapshotSettled else { return }
            withAnimation(AppSpring.hero.delay(0.1)) {
                logoScale = 1.0; logoOpacity = 1.0
            }
            withAnimation(AppEasing.heroEntry.delay(0.4)) {
                textOffset = 0; textOpacity = 1.0
            }
            withAnimation(AppEasing.heroEntry.delay(0.7)) {
                buttonsOffset = 0; buttonsOpacity = 1.0
            }
        }
        // ── Sign-in sheet ─────────────────────────────────
        .sheet(isPresented: $showSignIn) {
            SignInView()
                .environmentObject(signIn)
                .presentationDetents([.large])
                .presentationCornerRadius(AppSheet.authCornerRadius)
                .presentationBackground(.ultraThinMaterial)
        }
    }

    private func welcomeFactRow(icon: String, text: String) -> some View {
        HStack(spacing: AppSpacing.xSmall) {
            Image(systemName: icon)
                .font(AppText.captionStrong)
                .foregroundStyle(AppColor.Accent.recovery)
                .frame(width: 24)
            Text(text)
                .font(AppText.subheading)
                .foregroundStyle(AppColor.Text.inverseSecondary)
            Spacer()
        }
        .padding(.horizontal, AppSpacing.xSmall)
        .padding(.vertical, AppSpacing.xSmall)
        .background(AppColor.Surface.materialLight, in: RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                .stroke(AppColor.Border.subtle, lineWidth: 1)
        )
    }
}
