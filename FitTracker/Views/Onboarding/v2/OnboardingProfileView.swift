// FitTracker/Views/Onboarding/OnboardingProfileView.swift
// Onboarding Step 2 — Training experience and weekly frequency.
//
// v2 UX alignment (2026-04-07):
//  - AnalyticsScreen.onboardingProfile enum [P1-01]
//  - onboarding_step_viewed event [P0-02]
//  - sensoryFeedback haptic on selection [P0-05]
//  - ScrollView wrapper for Dynamic Type [P1-06]
//  - Skip transparency footer [P1-11]
//  - AppSize.touchTargetLarge token [P2-02]

import SwiftUI

struct OnboardingProfileView: View {
    let onContinue: () -> Void
    let onSkip: () -> Void

    @EnvironmentObject private var analytics: AnalyticsService
    @EnvironmentObject private var dataStore: EncryptedDataStore

    @State private var selectedExperience: String?
    @State private var selectedFrequency: Int?

    private let experienceLevels = ["Beginner", "Intermediate", "Advanced"]
    private let frequencyRange = 2...6

    var body: some View {
        ScrollView {
        VStack(spacing: AppSpacing.large) {
            Text("Tell us about you")
                .font(AppText.pageTitle)
                .foregroundStyle(AppColor.Text.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppSpacing.small)

            // Training Experience
            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text("Training experience")
                    .font(AppText.sectionTitle)
                    .foregroundStyle(AppColor.Text.primary)

                HStack(spacing: AppSpacing.xxSmall) {
                    ForEach(experienceLevels, id: \.self) { level in
                        ExperienceCard(
                            label: level,
                            isSelected: selectedExperience == level
                        ) {
                            selectedExperience = level
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.small)

            // Weekly Frequency
            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text("Days per week")
                    .font(AppText.sectionTitle)
                    .foregroundStyle(AppColor.Text.primary)

                HStack(spacing: AppSpacing.xxSmall) {
                    ForEach(Array(frequencyRange), id: \.self) { day in
                        FrequencyCircle(
                            value: day,
                            isSelected: selectedFrequency == day
                        ) {
                            selectedFrequency = day
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.small)

            Spacer()

            VStack(spacing: AppSpacing.xSmall) {
                Button(action: {
                    if let level = selectedExperience,
                       let experience = ExperienceLevel(rawValue: level) {
                        dataStore.userProfile.experienceLevel = experience
                    }
                    if let frequency = selectedFrequency {
                        dataStore.userProfile.trainingDaysPerWeek = frequency
                    }
                    onContinue()
                }) {
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
        .sensoryFeedback(.selection, trigger: selectedExperience)
        .sensoryFeedback(.selection, trigger: selectedFrequency)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Color.clear)
        .onAppear {
            analytics.logScreenView(AnalyticsScreen.onboardingProfile, screenClass: "OnboardingProfileView")
            analytics.logOnboardingStepViewed(stepIndex: 2, stepName: "profile")
        }
    }
}

// MARK: - Experience Card

private struct ExperienceCard: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(AppText.callout)
                .foregroundStyle(isSelected ? AppColor.Text.inversePrimary : AppColor.Text.secondary)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.small)
                .background(
                    isSelected ? AppColor.Accent.primary : AppColor.Surface.elevated,
                    in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                        .stroke(
                            isSelected ? Color.clear : AppColor.Border.subtle,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Frequency Circle

private struct FrequencyCircle: View {
    let value: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("\(value)")
                .font(AppText.button)
                .foregroundStyle(isSelected ? AppColor.Text.inversePrimary : AppColor.Text.secondary)
                .frame(width: AppSize.touchTargetLarge, height: AppSize.touchTargetLarge)
                .background(
                    isSelected ? AppColor.Accent.primary : AppColor.Surface.elevated,
                    in: Circle()
                )
                .overlay(
                    Circle()
                        .stroke(
                            isSelected ? Color.clear : AppColor.Border.subtle,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(value) days per week")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#if DEBUG
struct OnboardingProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            AppGradient.screenBackground.ignoresSafeArea()
            OnboardingProfileView(onContinue: {}, onSkip: {})
                .environmentObject(EncryptedDataStore())
        }
    }
}
#endif
