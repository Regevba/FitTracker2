// FitTracker/Views/Onboarding/OnboardingFirstActionView.swift
// Onboarding Step 4 — First action selection to complete onboarding.
import SwiftUI

struct OnboardingFirstActionView: View {
    var selectedGoal: String?
    let onComplete: () -> Void

    @EnvironmentObject private var analytics: AnalyticsService

    private var title: String {
        switch selectedGoal {
        case "Build Muscle":    return "Ready to build muscle?"
        case "Lose Fat":        return "Ready to lose fat?"
        case "Maintain":        return "Ready to maintain?"
        case "General Fitness": return "Ready to get fit?"
        default:                return "Let's get started!"
        }
    }

    var body: some View {
        VStack(spacing: AppSpacing.large) {
            Spacer()

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
                    analytics.logSelectContent(contentType: "onboarding_first_action", itemId: "workout")
                    onComplete()
                }

                FirstActionCard(
                    icon: "fork.knife",
                    label: "Log Your First Meal"
                ) {
                    analytics.logSelectContent(contentType: "onboarding_first_action", itemId: "meal")
                    onComplete()
                }
            }
            .padding(.horizontal, AppSpacing.small)

            Spacer()
        }
        .background(Color.clear)
        .onAppear {
            analytics.logScreenView("onboarding_first_action")
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
                    .font(.system(size: 32, weight: .medium))
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
