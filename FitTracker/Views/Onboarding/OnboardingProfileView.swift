// FitTracker/Views/Onboarding/OnboardingProfileView.swift
// Onboarding Step 2 — Training experience and weekly frequency.
import SwiftUI

struct OnboardingProfileView: View {
    let onContinue: () -> Void
    let onSkip: () -> Void

    @EnvironmentObject private var analytics: AnalyticsService

    @State private var selectedExperience: String?
    @State private var selectedFrequency: Int?

    private let experienceLevels = ["Beginner", "Intermediate", "Advanced"]
    private let frequencyRange = 2...6

    var body: some View {
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
            analytics.logScreenView("onboarding_profile")
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
                .frame(width: 48, height: 48)
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
        }
    }
}
#endif
