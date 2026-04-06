// FitTracker/Views/Onboarding/OnboardingView.swift
// Main onboarding container — manages 5-step flow with progress tracking.
// Swipe is disabled; the user advances only via explicit button actions.

import SwiftUI

struct OnboardingView: View {
    @State private var currentStep = 0
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @EnvironmentObject var healthService: HealthKitService
    @EnvironmentObject var analytics: AnalyticsService

    let onComplete: () -> Void

    private let totalSteps = 5

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar — hidden on welcome step
            if currentStep > 0 {
                OnboardingProgressBar(currentStep: currentStep, totalSteps: totalSteps)
                    .padding(.horizontal, AppSpacing.medium)
                    .padding(.top, AppSpacing.small)
                    .transition(.opacity)
            }

            // Page content — swipe disabled via .never
            TabView(selection: $currentStep) {
                OnboardingWelcomeView(onContinue: { advance() })
                    .tag(0)
                OnboardingGoalsView(onContinue: { advance() }, onSkip: { advance() })
                    .tag(1)
                OnboardingProfileView(onContinue: { advance() }, onSkip: { advance() })
                    .tag(2)
                OnboardingHealthKitView(onContinue: { advance() }, onSkip: { advance() })
                    .tag(3)
                OnboardingFirstActionView(onComplete: { completeOnboarding() })
                    .tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .scrollDisabled(true)
            .animation(.easeInOut(duration: 0.3), value: currentStep)
        }
        .background(AppGradient.screenBackground)
        .onAppear {
            analytics.logEvent(AnalyticsEvent.tutorialBegin, parameters: nil)
            analytics.logScreenView(AnalyticsScreen.onboarding, screenClass: "OnboardingView")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Onboarding, step \(currentStep + 1) of \(totalSteps)")
    }

    // MARK: - Navigation

    private func advance() {
        withAnimation(.easeInOut(duration: 0.3)) {
            guard currentStep < totalSteps - 1 else { return }
            let completedStep = currentStep
            currentStep += 1
            analytics.logEvent("onboarding_step_completed", parameters: [
                "step_index": completedStep,
                "step_name": stepName(for: completedStep)
            ])
        }
    }

    private func completeOnboarding() {
        hasCompletedOnboarding = true
        analytics.logEvent(AnalyticsEvent.tutorialComplete, parameters: [
            "steps_completed": totalSteps
        ])
        onComplete()
    }

    private func stepName(for index: Int) -> String {
        switch index {
        case 0: return "welcome"
        case 1: return "goals"
        case 2: return "profile"
        case 3: return "healthkit"
        case 4: return "first_action"
        default: return "unknown"
        }
    }
}

// MARK: - Preview

#if DEBUG
struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(onComplete: {})
            .environmentObject(HealthKitService())
            .environmentObject(AnalyticsService())
    }
}
#endif
