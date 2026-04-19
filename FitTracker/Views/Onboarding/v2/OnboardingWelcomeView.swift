// FitTracker/Views/Onboarding/OnboardingWelcomeView.swift
// Onboarding Step 0 — Welcome screen
// Blue gradient bg, orange-tinted icon, tagline, pinned CTA at bottom.

import SwiftUI

struct OnboardingWelcomeView: View {
    let onContinue: () -> Void

    @EnvironmentObject private var analytics: AnalyticsService

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Brand icon + text
            VStack(spacing: AppSpacing.medium) {
                FitMeBrandIcon(size: 180, renderingMode: .template)
                    .foregroundStyle(AppGradient.brand)
                    .padding(.bottom, AppSpacing.xSmall)

                // Audit DS-005 / UI-008: hero title uses AppText.displayHeadline
                // (32pt bold rounded) instead of a hardcoded `.system(size:)`,
                // so Dynamic Type and the design-system font scale apply.
                Text("FitMe")
                    .font(AppText.displayHeadline)
                    .foregroundStyle(AppGradient.brand)

                Text("Your fitness command center")
                    .font(AppText.subheading)
                    .foregroundStyle(AppColor.Text.primary)
                    .multilineTextAlignment(.center)

                Text("Training · Nutrition · Recovery · AI")
                    .font(AppText.caption)
                    .foregroundStyle(AppColor.Text.secondary)
            }

            Spacer()

            // Pinned CTA at bottom — orange gradient
            Button(action: onContinue) {
                Text("Get Started")
                    .font(AppText.button)
                    .foregroundStyle(AppColor.Text.inversePrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: AppSize.ctaHeight)
            }
            .background(
                AppGradient.brand,
                in: RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
            )
            .shadow(
                color: AppShadow.ctaColor,
                radius: AppShadow.ctaRadius,
                y: AppShadow.ctaYOffset
            )
            .buttonStyle(.plain)
            .padding(.horizontal, AppSpacing.medium)
            .padding(.bottom, AppSpacing.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppGradient.screenBackground.ignoresSafeArea())
        .onAppear {
            analytics.logScreenView(AnalyticsScreen.onboardingWelcome, screenClass: "OnboardingWelcomeView")
            analytics.logOnboardingStepViewed(stepIndex: 0, stepName: "welcome")
        }
    }
}

#if DEBUG
struct OnboardingWelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingWelcomeView(onContinue: {})
    }
}
#endif
