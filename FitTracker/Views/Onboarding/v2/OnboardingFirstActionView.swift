// FitTracker/Views/Onboarding/OnboardingFirstActionView.swift
// Onboarding final step — success confirmation + first action selection.
// If user authenticated: shows "Account successfully created!" then action cards.
// If user skipped auth: shows just the action cards.

import SwiftUI

struct OnboardingFirstActionView: View {
    var isAuthenticated: Bool = false
    let onComplete: () -> Void

    @EnvironmentObject private var signIn: SignInService
    @EnvironmentObject private var analytics: AnalyticsService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showContent = false
    @State private var lastTappedAction: String?

    private var displayName: String {
        let name = signIn.activeSession?.displayName ?? ""
        let first = name.components(separatedBy: " ").first ?? ""
        return first.isEmpty ? "" : ", \(first)"
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: AppSpacing.large) {
                    Spacer().frame(height: AppSpacing.xLarge)

                    if isAuthenticated {
                        // Success confirmation
                        VStack(spacing: AppSpacing.medium) {
                            ZStack {
                                Circle()
                                    .fill(AppColor.Status.success.opacity(0.15))
                                    .frame(width: 80, height: 80)

                                Image(systemName: "checkmark")
                                    .font(AppText.displayLarge)
                                    .foregroundStyle(AppColor.Status.success)
                            }
                            .scaleEffect(showContent ? 1.0 : 0.5)
                            .opacity(showContent ? 1.0 : 0.0)

                            Text("Account successfully created!")
                                .font(AppText.titleStrong)
                                .foregroundStyle(AppColor.Text.primary)
                                .multilineTextAlignment(.center)
                                .opacity(showContent ? 1.0 : 0.0)
                        }
                    }

                    // Title
                    Text(isAuthenticated ? "Let's get started\(displayName)" : "Let's get started!")
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
                            lastTappedAction = "workout"
                            analytics.logSelectContent(contentType: "onboarding_first_action", itemId: "workout")
                            onComplete()
                        }

                        FirstActionCard(
                            icon: "fork.knife",
                            label: "Log Your First Meal"
                        ) {
                            lastTappedAction = "meal"
                            analytics.logSelectContent(contentType: "onboarding_first_action", itemId: "meal")
                            onComplete()
                        }
                    }
                    .padding(.horizontal, AppSpacing.small)
                    .sensoryFeedback(.success, trigger: lastTappedAction)

                    Spacer().frame(height: AppSpacing.xLarge)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(Color.clear)
        .onAppear {
            analytics.logScreenView(AnalyticsScreen.onboardingFirstAction, screenClass: "OnboardingFirstActionView")
            analytics.logOnboardingStepViewed(stepIndex: 6, stepName: "first_action")

            if isAuthenticated {
                if reduceMotion {
                    showContent = true
                } else {
                    withAnimation(AppSpring.stepAdvance.delay(0.2)) {
                        showContent = true
                    }
                }
            }
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
                    .font(AppText.iconMedium)
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
            OnboardingFirstActionView(isAuthenticated: true, onComplete: {})
        }
    }
}
#endif
