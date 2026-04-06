// FitTracker/Views/Onboarding/OnboardingGoalsView.swift
// Onboarding Step 1 — Goal selection with tappable cards.
import SwiftUI

struct OnboardingGoalsView: View {
    let onContinue: () -> Void
    let onSkip: () -> Void

    @EnvironmentObject private var analytics: AnalyticsService
    @State private var selectedGoal: String?

    private let goals: [(label: String, icon: String)] = [
        ("Build Muscle", "figure.strengthtraining.traditional"),
        ("Lose Fat", "flame.fill"),
        ("Maintain", "heart.fill"),
        ("General Fitness", "figure.run"),
    ]

    private let columns = [
        GridItem(.flexible(), spacing: AppSpacing.xSmall),
        GridItem(.flexible(), spacing: AppSpacing.xSmall),
    ]

    var body: some View {
        VStack(spacing: AppSpacing.large) {
            Text("What's your goal?")
                .font(AppText.pageTitle)
                .foregroundStyle(AppColor.Text.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppSpacing.small)

            LazyVGrid(columns: columns, spacing: AppSpacing.xSmall) {
                ForEach(goals, id: \.label) { goal in
                    GoalCard(
                        label: goal.label,
                        icon: goal.icon,
                        isSelected: selectedGoal == goal.label
                    ) {
                        selectedGoal = goal.label
                    }
                }
            }
            .padding(.horizontal, AppSpacing.small)

            Spacer()

            VStack(spacing: AppSpacing.xSmall) {
                Button(action: onContinue) {
                    Text("Continue")
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
                .disabled(selectedGoal == nil)
                .opacity(selectedGoal == nil ? 0.5 : 1.0)

                Button(action: onSkip) {
                    Text("Skip")
                        .font(AppText.button)
                        .foregroundStyle(AppColor.Text.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, AppSpacing.small)
            .padding(.bottom, AppSpacing.xLarge)
        }
        .background(Color.clear)
        .onAppear {
            analytics.logScreenView("onboarding_goals")
        }
    }
}

// MARK: - Goal Card

private struct GoalCard: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: AppSpacing.xSmall) {
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(isSelected ? AppColor.Brand.primary : AppColor.Text.secondary)

                Text(label)
                    .font(AppText.callout)
                    .foregroundStyle(isSelected ? AppColor.Text.primary : AppColor.Text.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.large)
            .background(
                AppColor.Surface.elevated,
                in: RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                    .stroke(
                        isSelected ? AppColor.Brand.primary : AppColor.Border.subtle,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#if DEBUG
struct OnboardingGoalsView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            AppGradient.screenBackground.ignoresSafeArea()
            OnboardingGoalsView(onContinue: {}, onSkip: {})
        }
    }
}
#endif
