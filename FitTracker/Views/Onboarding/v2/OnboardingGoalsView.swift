// FitTracker/Views/Onboarding/OnboardingGoalsView.swift
// Onboarding Step 1 — Goal selection with tappable cards.
//
// v2 UX alignment (2026-04-07):
//  - AnalyticsScreen.onboardingGoals enum [P1-01]
//  - onboarding_goal_selected event [P0-04]
//  - onboarding_step_viewed event [P0-02]
//  - sensoryFeedback haptic on selection [P0-05]
//  - ScrollView wrapper for Dynamic Type [P1-06]
//  - Skip transparency footer [P1-11]

import SwiftUI

struct OnboardingGoalsView: View {
    let onContinue: () -> Void
    let onSkip: () -> Void

    @EnvironmentObject private var analytics: AnalyticsService
    @EnvironmentObject private var dataStore: EncryptedDataStore
    @State private var selectedGoal: String?

    private let goals: [(label: String, icon: String, value: String)] = [
        ("Build Muscle", "figure.strengthtraining.traditional", "build_muscle"),
        ("Lose Fat", "flame.fill", "lose_fat"),
        ("Maintain", "heart.fill", "maintain"),
        ("General Fitness", "figure.run", "general_fitness"),
    ]

    private let columns = [
        GridItem(.flexible(), spacing: AppSpacing.xSmall),
        GridItem(.flexible(), spacing: AppSpacing.xSmall),
    ]

    var body: some View {
        ScrollView {
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
                            analytics.logOnboardingGoalSelected(goalValue: goal.value)
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.small)
                .sensoryFeedback(.selection, trigger: selectedGoal)

                Spacer().frame(height: AppSpacing.large)

                VStack(spacing: AppSpacing.xSmall) {
                    Button(action: {
                        if let label = selectedGoal,
                           let goal = FitnessGoal(rawValue: label) {
                            dataStore.userProfile.fitnessGoal = goal
                        }
                        onContinue()
                    }) {
                        Text("Continue")
                            .font(AppText.button)
                            .foregroundStyle(AppColor.Text.inversePrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: AppSize.ctaHeight)
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

                    Text("You can set this later in Settings.")
                        .font(AppText.caption)
                        .foregroundStyle(AppColor.Text.tertiary)
                        .padding(.top, AppSpacing.xxxSmall)
                }
                .padding(.horizontal, AppSpacing.small)
                .padding(.bottom, AppSpacing.xLarge)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Color.clear)
        .onAppear {
            analytics.logScreenView(AnalyticsScreen.onboardingGoals, screenClass: "OnboardingGoalsView")
            analytics.logOnboardingStepViewed(stepIndex: 1, stepName: "goals")
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
                    .font(AppText.iconMedium)
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
                .environmentObject(EncryptedDataStore())
        }
    }
}
#endif
