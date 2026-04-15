// FitTracker/Views/Onboarding/v2/OnboardingSuccessView.swift
// Onboarding Step 6 — Success animation after account creation.
// Animated checkmark + "Welcome to FitMe!" + auto-advance after 2s.

import SwiftUI

struct OnboardingSuccessView: View {
    let onContinue: () -> Void

    @EnvironmentObject private var signIn: SignInService
    @EnvironmentObject private var analytics: AnalyticsService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showCheckmark = false
    @State private var showText = false
    @State private var showHint = false

    private var displayName: String {
        let name = signIn.activeSession?.displayName ?? ""
        return name.components(separatedBy: " ").first ?? "there"
    }

    var body: some View {
        VStack(spacing: AppSpacing.large) {
            Spacer()

            // Animated checkmark circle
            ZStack {
                Circle()
                    .fill(AppColor.Surface.inverse)
                    .frame(width: 80, height: 80)
                    .scaleEffect(showCheckmark ? 1.0 : 0.3)
                    .opacity(showCheckmark ? 1.0 : 0.0)

                Image(systemName: "checkmark")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(AppColor.Brand.primary)
                    .opacity(showCheckmark ? 1.0 : 0.0)
            }

            // Welcome text
            VStack(spacing: AppSpacing.xSmall) {
                Text("Welcome to FitMe!")
                    .font(AppText.hero)
                    .foregroundStyle(AppColor.Text.inversePrimary)

                Text("\(displayName), your account is ready.")
                    .font(AppText.body)
                    .foregroundStyle(AppColor.Text.inverseSecondary)
            }
            .opacity(showText ? 1.0 : 0.0)

            Spacer()

            // Tap hint
            Text("Tap anywhere to continue")
                .font(AppText.caption)
                .foregroundStyle(AppColor.Text.inverseTertiary)
                .opacity(showHint ? 1.0 : 0.0)
                .padding(.bottom, AppSpacing.xLarge)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppGradient.brand.ignoresSafeArea())
        .contentShape(Rectangle())
        .onTapGesture {
            onContinue()
        }
        .onAppear {
            analytics.logOnboardingSuccessShown()
            analytics.logOnboardingStepViewed(stepIndex: 6, stepName: "success")

            if reduceMotion {
                showCheckmark = true
                showText = true
                showHint = true
            } else {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    showCheckmark = true
                }
                withAnimation(.easeOut(duration: 0.4).delay(0.4)) {
                    showText = true
                }
                withAnimation(.easeIn(duration: 0.3).delay(1.0)) {
                    showHint = true
                }
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(2))
            onContinue()
        }
        .accessibilityLabel("Welcome to FitMe! \(displayName), your account is ready. Double tap to continue.")
    }
}
