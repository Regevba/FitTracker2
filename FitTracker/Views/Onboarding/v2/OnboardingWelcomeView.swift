// FitTracker/Views/Onboarding/OnboardingWelcomeView.swift
// Onboarding Step 0 — Welcome screen
// Figma ref: "Onboarding / Welcome" (node 472:2)
// Orange gradient bg, white logo, "FitMe" title, tagline, white CTA button
//
// v2 UX alignment (2026-04-07):
//  - AppSize.ctaHeight token [P1-03]
//  - AppShadow.ctaInverse* tokens [P1-04]
//  - ScrollView wrapper for Dynamic Type [P1-06]
//  - onboarding_step_viewed analytics [P0-02]

import SwiftUI

struct OnboardingWelcomeView: View {
    let onContinue: () -> Void

    @EnvironmentObject private var analytics: AnalyticsService

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.medium) {
                Spacer().frame(height: AppSpacing.xxLarge)

                // Brand icon — Figma: 4 intertwined circles + gradient "FitMe" text
                FitMeBrandIcon.hero
                    .padding(.bottom, AppSpacing.xSmall)

                // Tagline — Figma: Inter Medium 20px, white 85%
                Text("Your fitness command center")
                    .font(AppText.subheading)
                    .foregroundStyle(AppColor.Text.inverseSecondary)
                    .multilineTextAlignment(.center)

                // Pillars — Figma: Inter Regular 15px, white 65%
                Text("Training · Nutrition · Recovery · AI")
                    .font(AppText.caption)
                    .foregroundStyle(AppColor.Text.inverseTertiary)

                Spacer().frame(height: AppSpacing.xxLarge)

                // CTA — Figma: white bg, brand-primary text, 20px radius, 52pt height
                Button(action: onContinue) {
                    Text("Get Started")
                        .font(AppText.button)
                        .foregroundStyle(AppColor.Brand.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: AppSize.ctaHeight)
                }
                .background(AppColor.Surface.inverse, in: RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous))
                .shadow(
                    color: AppShadow.ctaInverseColor,
                    radius: AppShadow.ctaInverseRadius,
                    y: AppShadow.ctaInverseYOffset
                )
                .buttonStyle(.plain)
                .padding(.horizontal, AppSpacing.medium)

                Spacer().frame(height: AppSpacing.xLarge)
            }
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
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
