// FitTracker/Views/Onboarding/OnboardingView.swift
// Main onboarding container — manages 6-step flow with progress tracking.
// Consent is integrated as step 5 (after HealthKit, before First Action).
// Swipe is disabled; the user advances only via explicit button actions.

import SwiftUI

struct OnboardingView: View {
    @State private var currentStep = 0
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @EnvironmentObject var healthService: HealthKitService
    @EnvironmentObject var analytics: AnalyticsService

    let onComplete: () -> Void

    private let totalSteps = 6

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar — hidden on welcome step (0) and consent step (4)
            if currentStep > 0 && currentStep != 4 {
                OnboardingProgressBar(currentStep: currentStep, totalSteps: totalSteps)
                    .padding(.horizontal, AppSpacing.medium)
                    .padding(.top, AppSpacing.small)
                    .transition(.opacity)
            }

            // Page content — swipe disabled
            TabView(selection: $currentStep) {
                OnboardingWelcomeView(onContinue: { advance() })
                    .tag(0)
                OnboardingGoalsView(onContinue: { advance() }, onSkip: { advance() })
                    .tag(1)
                OnboardingProfileView(onContinue: { advance() }, onSkip: { advance() })
                    .tag(2)
                OnboardingHealthKitView(onContinue: { advance() }, onSkip: { advance() })
                    .tag(3)
                OnboardingConsentView(onAccept: {
                    analytics.consent.grantConsent()
                    analytics.syncConsentToProvider()
                    analytics.logConsentGranted(type: "gdpr")
                    Task { await analytics.consent.requestATT() }
                    advance()
                }, onDecline: {
                    analytics.consent.denyConsent()
                    analytics.syncConsentToProvider()
                    analytics.logConsentDenied(type: "gdpr")
                    advance()
                })
                    .tag(4)
                OnboardingFirstActionView(onComplete: { completeOnboarding() })
                    .tag(5)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .scrollDisabled(true)
            .animation(.easeInOut(duration: 0.3), value: currentStep)
        }
        .background(currentStep == 0 ? AnyShapeStyle(AppGradient.brand) : AnyShapeStyle(AppColor.Background.appTint))
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
            analytics.logOnboardingStepCompleted(stepIndex: completedStep, stepName: stepName(for: completedStep))
        }
    }

    private func completeOnboarding() {
        hasCompletedOnboarding = true
        analytics.logEvent(AnalyticsEvent.tutorialComplete, parameters: [
            "steps_completed": totalSteps
        ])
        analytics.setOnboardingCompleted(true)
        onComplete()
    }

    private func stepName(for index: Int) -> String {
        switch index {
        case 0: return "welcome"
        case 1: return "goals"
        case 2: return "profile"
        case 3: return "healthkit"
        case 4: return "consent"
        case 5: return "first_action"
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
            .environmentObject(AnalyticsService.makeDefault())
    }
}
#endif
