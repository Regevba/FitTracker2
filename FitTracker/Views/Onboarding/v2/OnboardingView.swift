// FitTracker/Views/Onboarding/OnboardingView.swift
// Main onboarding container — manages 8-step flow with progress tracking.
// Steps: Welcome → Goals → Profile → HealthKit → Consent → Auth → Success → First Action
// Auth is embedded (step 5) — user creates account before entering the app.
// Swipe is disabled; the user advances only via explicit button actions.

import SwiftUI

struct OnboardingView: View {
    @State private var currentStep = 0
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @EnvironmentObject var healthService: HealthKitService
    @EnvironmentObject var signIn: SignInService
    @EnvironmentObject var analytics: AnalyticsService
    @EnvironmentObject var dataStore: EncryptedDataStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let onComplete: () -> Void

    private let totalSteps = 8

    var body: some View {
        VStack(spacing: 0) {
            // Top bar: Back button (steps 1-4, 7) + Progress bar
            HStack(spacing: AppSpacing.xSmall) {
                if canGoBack {
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

                // Progress bar — hidden on welcome (0), auth (5), success (6)
                if showProgressBar {
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
                OnboardingAuthView(
                    onAuthenticated: {
                        // New account created — show success, then first action
                        analytics.logOnboardingAuthCompleted(method: "unknown", isNewAccount: true)
                        advance()
                    },
                    onLogin: {
                        // Returning user — skip success + first action, go to Home
                        analytics.logOnboardingAuthCompleted(method: "unknown", isNewAccount: false)
                        completeOnboarding()
                    },
                    onSkip: {
                        // Guest mode — skip auth, enter app without account
                        analytics.logOnboardingSkipped(stepIndex: 5, stepName: "auth")
                        advance() // go to first action, then Home
                    }
                )
                    .tag(5)
                OnboardingSuccessView(onContinue: { advance() })
                    .tag(6)
                OnboardingFirstActionView(onComplete: { completeOnboarding() })
                    .tag(7)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .scrollDisabled(true)
            .animation(reduceMotion ? .none : AppMotion.stepTransition, value: currentStep)
        }
        .background(stepBackground)
        .onAppear {
            analytics.logTutorialBegin()
            analytics.logScreenView(AnalyticsScreen.onboarding, screenClass: "OnboardingView")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Onboarding, step \(currentStep + 1) of \(totalSteps)")
    }

    // MARK: - Navigation

    private var canGoBack: Bool {
        // Back allowed on steps 1-4 and 7 (not welcome, auth, success)
        [1, 2, 3, 4, 7].contains(currentStep)
    }

    private var showProgressBar: Bool {
        // Show on steps 1-4 and 7 (not welcome, auth, success)
        [1, 2, 3, 4, 7].contains(currentStep)
    }

    private var stepBackground: some ShapeStyle {
        switch currentStep {
        case 0: AnyShapeStyle(AppGradient.brand)         // Welcome — orange
        case 6: AnyShapeStyle(AppGradient.brand)         // Success — orange (bookend)
        default: AnyShapeStyle(AppColor.Background.appTint) // All other steps
        }
    }

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
        case 5: return "auth"
        case 6: return "success"
        case 7: return "first_action"
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
            .environmentObject(SignInService())
            .environmentObject(AnalyticsService.makeDefault())
            .environmentObject(EncryptedDataStore())
    }
}
#endif
