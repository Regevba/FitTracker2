// FitTracker/Views/Onboarding/OnboardingWelcomeView.swift
// Onboarding Step 0 — Welcome screen
// Orange gradient bg, brand icon, tagline, pinned CTA at bottom.

import SwiftUI

struct OnboardingWelcomeView: View {
    let onContinue: () -> Void

    @EnvironmentObject private var analytics: AnalyticsService

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Brand icon + text
            VStack(spacing: AppSpacing.medium) {
                FitMeBrandIcon.hero
                    .padding(.bottom, AppSpacing.xSmall)

                Text("Your fitness command center")
                    .font(AppText.subheading)
                    .foregroundStyle(AppColor.Text.inverseSecondary)
                    .multilineTextAlignment(.center)

                Text("Training · Nutrition · Recovery · AI")
                    .font(AppText.caption)
                    .foregroundStyle(AppColor.Text.inverseTertiary)
            }

            Spacer()

            // Pinned CTA at bottom
            Button(action: onContinue) {
                Text("Get Started")
                    .font(AppText.button)
                    .foregroundStyle(AppColor.Brand.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: AppSize.ctaHeight)
            }
            .background(
                AppColor.Surface.primary.opacity(0.95),
                in: RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
            )
            .shadow(
                color: AppShadow.ctaInverseColor,
                radius: AppShadow.ctaInverseRadius,
                y: AppShadow.ctaInverseYOffset
            )
            .buttonStyle(.plain)
            .padding(.horizontal, AppSpacing.medium)
            .padding(.bottom, AppSpacing.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppGradient.brand.ignoresSafeArea())
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
