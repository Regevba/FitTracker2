// FitTracker/Views/Onboarding/OnboardingFirstActionView.swift
// Onboarding Step 5 — First action selection to complete onboarding.
//
// v2 UX alignment (2026-04-07):
//  - AnalyticsScreen.onboardingFirstAction enum [P1-01]
//  - onboarding_step_viewed event [P0-02]
//  - "Ready to maintain?" → "Ready to stay on track?" [P2-04]
//  - sensoryFeedback haptic on tap [P0-05]
//  - ScrollView wrapper for Dynamic Type [P1-06]

import SwiftUI

struct OnboardingFirstActionView: View {
    var selectedGoal: String?
    let onComplete: () -> Void

    @EnvironmentObject private var analytics: AnalyticsService
    @State private var lastTappedAction: String?

    private var title: String {
        switch selectedGoal {
        case "Build Muscle":    return "Ready to build muscle?"
        case "Lose Fat":        return "Ready to lose fat?"
        case "Maintain":        return "Ready to stay on track?"
        case "General Fitness": return "Ready to get fit?"
        default:                return "Let's get started!"
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.large) {
                Spacer().frame(height: AppSpacing.xxLarge)

                Text(title)
                    .font(AppText.pageTitle)
                    .foregroundStyle(AppColor.Text.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.small)

                Text("Pick your first action to begin your journey.")
                    .font(AppText.body)
                    .foregroundStyle(AppColor.Text.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.small)

                HStack(spacing: AppSpacing.xSmall) {
                    FirstActionCard(
                        icon: "figure.strengthtraining.traditional",
                        label: "Start Your First Workout"
                    ) {
                        lastTappedAction = "workout"
                        analytics.logSelectContent(contentType: "onboarding_first_action", itemId: "workout")
                        onComplete()
                    }

                    FirstActionCard(
                        icon: "fork.knife",
                        label: "Log Your First Meal"
                    ) {
                        lastTappedAction = "meal"
                        analytics.logSelectContent(contentType: "onboarding_first_action", itemId: "meal")
                        onComplete()
                    }
                }
                .padding(.horizontal, AppSpacing.small)
                .sensoryFeedback(.success, trigger: lastTappedAction)

                Spacer().frame(height: AppSpacing.xLarge)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Color.clear)
        .onAppear {
            analytics.logScreenView(AnalyticsScreen.onboardingFirstAction, screenClass: "OnboardingFirstActionView")
            analytics.logOnboardingStepViewed(stepIndex: 5, stepName: "first_action")
        }
    }
}

// MARK: - First Action Card

private struct FirstActionCard: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: AppSpacing.xSmall) {
                Image(systemName: icon)
                    .font(AppText.iconMedium)
                    .foregroundStyle(AppColor.Brand.primary)

                Text(label)
                    .font(AppText.callout)
                    .foregroundStyle(AppColor.Text.primary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.xLarge)
            .padding(.horizontal, AppSpacing.xSmall)
            .background(
                AppColor.Surface.elevated,
                in: RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                    .stroke(AppColor.Border.subtle, lineWidth: 1)
            )
            .shadow(
                color: AppShadow.cardColor,
                radius: AppShadow.cardRadius,
                y: AppShadow.cardYOffset
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

#if DEBUG
struct OnboardingFirstActionView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            AppGradient.screenBackground.ignoresSafeArea()
            OnboardingFirstActionView(selectedGoal: "Build Muscle", onComplete: {})
        }
    }
}
#endif
