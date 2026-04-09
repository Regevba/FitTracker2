// FitTracker/Views/Onboarding/OnboardingView.swift
// Main onboarding container — manages 6-step flow with progress tracking.
// Consent is integrated as step 5 (after HealthKit, before First Action).
// Swipe is disabled; the user advances only via explicit button actions.
//
// v2 UX alignment (2026-04-07):
//  - Back navigation on steps 1-5 [P0-06]
//  - Skip events fired in this container [P0-03]
//  - AppMotion.stepTransition token [P1-02]
//  - Reduce Motion respected [P1-09]

import SwiftUI

struct OnboardingView: View {
    @State private var currentStep = 0
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @EnvironmentObject var healthService: HealthKitService
    @EnvironmentObject var analytics: AnalyticsService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let onComplete: () -> Void

    private let totalSteps = 6

    var body: some View {
        VStack(spacing: 0) {
            // Top bar: Back button (steps 1-5) + Progress bar (steps 1, 2, 3, 5)
            HStack(spacing: AppSpacing.xSmall) {
                if currentStep > 0 {
                    Button(action: goBack) {
                        Image(systemName: "chevron.left")
                            .font(AppText.body)
                            .foregroundStyle(AppColor.Text.secondary)
                            .frame(width: AppSize.touchTargetLarge, height: AppSize.touchTargetLarge)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back")
                    .accessibilityHint("Returns to the previous step")
                    .transition(.opacity)
                }

                // Progress bar — hidden on welcome step (0) and consent step (4)
                if currentStep > 0 && currentStep != 4 {
                    OnboardingProgressBar(currentStep: currentStep, totalSteps: totalSteps)
                        .padding(.trailing, AppSpacing.medium)
                        .transition(.opacity)
                }
            }
            .padding(.top, AppSpacing.xxSmall)
            .padding(.leading, AppSpacing.xSmall)

            // Page content — swipe disabled
            TabView(selection: $currentStep) {
                OnboardingWelcomeView(onContinue: { advance() })
                    .tag(0)
                OnboardingGoalsView(
                    onContinue: { advance() },
                    onSkip: { skipStep() }
                )
                    .tag(1)
                OnboardingProfileView(
                    onContinue: { advance() },
                    onSkip: { skipStep() }
                )
                    .tag(2)
                OnboardingHealthKitView(
                    onContinue: { advance() },
                    onSkip: { skipStep() }
                )
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
            .animation(reduceMotion ? .none : AppMotion.stepTransition, value: currentStep)
        }
        .background(currentStep == 0 ? AnyShapeStyle(AppGradient.brand) : AnyShapeStyle(AppColor.Background.appTint))
        .onAppear {
            analytics.logTutorialBegin()
            analytics.logScreenView(AnalyticsScreen.onboarding, screenClass: "OnboardingView")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Onboarding, step \(currentStep + 1) of \(totalSteps)")
    }

    // MARK: - Navigation

    private func advance() {
        withAnimation(reduceMotion ? .none : AppMotion.stepTransition) {
            guard currentStep < totalSteps - 1 else { return }
            let completedStep = currentStep
            currentStep += 1
            analytics.logOnboardingStepCompleted(stepIndex: completedStep, stepName: stepName(for: completedStep))
        }
    }

    private func skipStep() {
        let skippedStep = currentStep
        analytics.logOnboardingSkipped(stepIndex: skippedStep, stepName: stepName(for: skippedStep))
        advance()
    }

    private func goBack() {
        withAnimation(reduceMotion ? .none : AppMotion.stepTransition) {
            guard currentStep > 0 else { return }
            currentStep -= 1
        }
    }

    private func completeOnboarding() {
        hasCompletedOnboarding = true
        analytics.logTutorialComplete()
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
