// FitTracker/Views/Onboarding/OnboardingProgressBar.swift
// 6-segment horizontal progress indicator for onboarding flow.
// Completed segments use brand primary, active segment uses brand gradient,
// upcoming segments use a muted surface color.
//
// v2 UX alignment (2026-04-07):
//  - AppMotion.stepTransition token [P1-02]
//  - AppSize.progressBarHeight token [P2-02]

import SwiftUI

struct OnboardingProgressBar: View {
    let currentStep: Int
    let totalSteps: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: AppSpacing.xxxSmall) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Capsule()
                    .fill(fillColor(for: index))
                    .overlay {
                        // Gradient overlay for the active segment only
                        if index == currentStep {
                            Capsule()
                                .fill(AppGradient.brand)
                        }
                    }
                    .clipShape(Capsule())
                    .frame(height: AppSize.progressBarHeight)
                    .animation(
                        reduceMotion ? .none : AppMotion.stepTransition,
                        value: currentStep
                    )
            }
        }
        .frame(height: AppSize.progressBarHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Onboarding progress")
        .accessibilityValue("Step \(currentStep + 1) of \(totalSteps)")
    }

    private func fillColor(for index: Int) -> Color {
        if index < currentStep {
            return AppColor.Brand.primary
        } else if index == currentStep {
            // Transparent base — gradient overlay handles this segment
            return Color.clear
        } else {
            return AppColor.Surface.tertiary
        }
    }
}

// MARK: - Preview

#if DEBUG
struct OnboardingProgressBar_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: AppSpacing.large) {
            OnboardingProgressBar(currentStep: 0, totalSteps: 6)
            OnboardingProgressBar(currentStep: 3, totalSteps: 6)
            OnboardingProgressBar(currentStep: 5, totalSteps: 6)
        }
        .padding(AppSpacing.medium)
        .background(AppGradient.screenBackground)
    }
}
#endif
