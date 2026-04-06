// FitTracker/Views/Onboarding/OnboardingWelcomeView.swift
// Onboarding Step 0 — Welcome screen with branded logo and Get Started CTA.
import SwiftUI

struct OnboardingWelcomeView: View {
    let onContinue: () -> Void

    @EnvironmentObject private var analytics: AnalyticsService

    var body: some View {
        VStack(spacing: AppSpacing.large) {
            Spacer()

            VStack(spacing: AppSpacing.xSmall) {
                FitMeLogoLoader(mode: .breathe, size: .large)

                Text("Your fitness command center")
                    .font(AppText.body)
                    .foregroundStyle(AppColor.Text.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            Button(action: onContinue) {
                Text("Get Started")
                    .font(AppText.button)
                    .foregroundStyle(AppColor.Text.inversePrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.small)
                    .background(
                        AppGradient.brand,
                        in: RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
                    )
                    .shadow(
                        color: AppShadow.ctaColor,
                        radius: AppShadow.ctaRadius,
                        y: AppShadow.ctaYOffset
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, AppSpacing.small)
            .padding(.bottom, AppSpacing.xLarge)
        }
        .background(Color.clear)
        .onAppear {
            analytics.logScreenView("onboarding_welcome")
        }
    }
}

#if DEBUG
struct OnboardingWelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            AppGradient.screenBackground.ignoresSafeArea()
            OnboardingWelcomeView(onContinue: {})
        }
    }
}
#endif
