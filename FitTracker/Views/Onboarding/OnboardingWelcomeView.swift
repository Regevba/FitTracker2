// FitTracker/Views/Onboarding/OnboardingWelcomeView.swift
// Onboarding Step 0 — Welcome screen
// Figma ref: "Onboarding / Welcome" (node 472:2)
// Orange gradient bg, white logo, "FitMe" title, tagline, white CTA button
import SwiftUI

struct OnboardingWelcomeView: View {
    let onContinue: () -> Void

    @EnvironmentObject private var analytics: AnalyticsService

    var body: some View {
        VStack(spacing: AppSpacing.medium) {
            Spacer()

            // Logo — Figma: white circle with FitMe logo
            FitMeLogoLoader(mode: .breathe, size: .large)
                .padding(.bottom, AppSpacing.xSmall)

            // App name — Figma: Inter Bold 44px, white
            Text("FitMe")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(AppColor.Text.inversePrimary)

            // Tagline — Figma: Inter Medium 20px, white 85%
            Text("Your fitness command center")
                .font(AppText.subheading)
                .foregroundStyle(AppColor.Text.inverseSecondary)
                .multilineTextAlignment(.center)

            // Pillars — Figma: Inter Regular 15px, white 65%
            Text("Training · Nutrition · Recovery · AI")
                .font(AppText.caption)
                .foregroundStyle(AppColor.Text.inverseTertiary)

            Spacer()

            // CTA — Figma: white bg, brand-primary text, 20px radius, 52pt height
            Button(action: onContinue) {
                Text("Get Started")
                    .font(AppText.button)
                    .foregroundStyle(AppColor.Brand.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
            }
            .background(.white, in: RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
            .buttonStyle(.plain)
            .padding(.horizontal, AppSpacing.medium)

            Spacer().frame(height: AppSpacing.xLarge)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppGradient.brand.ignoresSafeArea())
        .onAppear {
            analytics.logScreenView(AnalyticsScreen.onboardingWelcome, screenClass: "OnboardingWelcomeView")
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
