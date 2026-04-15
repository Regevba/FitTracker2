// FitTracker/Views/Onboarding/OnboardingHealthKitView.swift
// Onboarding Step 3 — Apple Health permission request.
//
// v2 UX alignment (2026-04-07):
//  - permission_result event with granted bool [P0-01]
//  - onboarding_step_viewed event [P0-02]
//  - AnalyticsScreen.onboardingHealthkit enum [P1-01]
//  - sensoryFeedback haptic on tap [P0-05]
//  - ScrollView wrapper for Dynamic Type [P1-06]
//  - Loading state during HK authorization [P1-07]
//  - Denial feedback footer [P1-08]
//  - iPad fallback copy [P1-10]
//  - Skip transparency footer [P1-11]
//  - Terminology unified to "Apple Health" [P2-03]

import SwiftUI

struct OnboardingHealthKitView: View {
    let onContinue: () -> Void
    let onSkip: () -> Void

    @EnvironmentObject private var analytics: AnalyticsService
    @EnvironmentObject private var healthService: HealthKitService

    @State private var isRequestingAuthorization = false
    @State private var lastDenialMessage: String?

    private let dataTypes: [(icon: String, label: String)] = [
        ("heart.fill", "Heart Rate"),
        ("waveform.path.ecg", "Heart Rate Variability"),
        ("figure.walk", "Steps"),
        ("bed.double.fill", "Sleep"),
    ]

    private var isHealthAvailable: Bool {
        // HealthKit is unavailable on iPad
        #if targetEnvironment(macCatalyst)
        return false
        #else
        return UIDevice.current.userInterfaceIdiom == .phone
        #endif
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: AppSpacing.large) {
                    Spacer().frame(height: AppSpacing.xLarge)

                    VStack(spacing: AppSpacing.medium) {
                        Image(systemName: "heart.text.square")
                            .font(AppText.iconHero)
                            .foregroundStyle(AppColor.Brand.primary)

                        Text("Sync your Apple Health")
                            .font(AppText.pageTitle)
                            .foregroundStyle(AppColor.Text.primary)

                        Text(isHealthAvailable
                             ? "FitMe uses Apple Health to track your recovery and training readiness."
                             : "Apple Health is not available on this device. You can connect it later from your iPhone.")
                            .font(AppText.body)
                            .foregroundStyle(AppColor.Text.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppSpacing.small)
                    }

                    if isHealthAvailable {
                        VStack(spacing: AppSpacing.xxSmall) {
                            ForEach(dataTypes, id: \.label) { dataType in
                                HealthDataRow(icon: dataType.icon, label: dataType.label)
                            }
                        }
                        .padding(.horizontal, AppSpacing.small)
                    }

                    if let denial = lastDenialMessage {
                        Text(denial)
                            .font(AppText.caption)
                            .foregroundStyle(AppColor.Status.warning)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppSpacing.medium)
                            .transition(.opacity)
                    }
                }
                .padding(.bottom, AppSpacing.medium)
            }
            .scrollBounceBehavior(.basedOnSize)

            // Pinned CTA at bottom
            VStack(spacing: AppSpacing.xSmall) {
                Button {
                    Task { await connect() }
                } label: {
                    HStack(spacing: AppSpacing.xSmall) {
                        if isRequestingAuthorization {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(AppColor.Text.inversePrimary)
                        }
                        Text(isRequestingAuthorization ? "Connecting…" : (isHealthAvailable ? "Connect Apple Health" : "Continue"))
                            .font(AppText.button)
                            .foregroundStyle(AppColor.Text.inversePrimary)
                    }
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
                .disabled(isRequestingAuthorization)
                .sensoryFeedback(.impact(weight: .light), trigger: isRequestingAuthorization)

                Button(action: onSkip) {
                    Text("Skip")
                        .font(AppText.button)
                        .foregroundStyle(AppColor.Text.secondary)
                }
                .buttonStyle(.plain)

                Text("You can enable Apple Health later in Settings.")
                    .font(AppText.caption)
                    .foregroundStyle(AppColor.Text.tertiary)
                    .padding(.top, AppSpacing.xxxSmall)
            }
            .padding(.horizontal, AppSpacing.small)
            .padding(.bottom, AppSpacing.large)
        }
        .background(Color.clear)
        .onAppear {
            analytics.logScreenView(AnalyticsScreen.onboardingHealthkit, screenClass: "OnboardingHealthKitView")
            analytics.logOnboardingStepViewed(stepIndex: 3, stepName: "healthkit")
        }
    }

    private func connect() async {
        guard isHealthAvailable else {
            // No HealthKit on this device — proceed forward
            analytics.logPermissionResult(type: "healthkit", granted: false)
            onContinue()
            return
        }
        isRequestingAuthorization = true
        defer { isRequestingAuthorization = false }
        do {
            try await healthService.requestAuthorization()
            analytics.logPermissionResult(type: "healthkit", granted: true)
            onContinue()
        } catch {
            analytics.logPermissionResult(type: "healthkit", granted: false)
            withAnimation { lastDenialMessage = "We couldn't connect to Apple Health. You can enable it in Settings later." }
            // Stay on screen so user can choose Skip or retry
        }
    }
}

// MARK: - Health Data Row

private struct HealthDataRow: View {
    let icon: String
    let label: String

    var body: some View {
        HStack(spacing: AppSpacing.xSmall) {
            Image(systemName: icon)
                .font(AppText.sectionTitle)
                .foregroundStyle(AppColor.Accent.primary)
                .frame(width: 28)

            Text(label)
                .font(AppText.body)
                .foregroundStyle(AppColor.Text.primary)

            Spacer()

            Image(systemName: "checkmark.circle")
                .font(AppText.body)
                .foregroundStyle(AppColor.Text.tertiary)
        }
        .padding(.vertical, AppSpacing.xSmall)
        .padding(.horizontal, AppSpacing.small)
        .background(
            AppColor.Surface.elevated,
            in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
        )
    }
}

#if DEBUG
struct OnboardingHealthKitView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            AppGradient.screenBackground.ignoresSafeArea()
            OnboardingHealthKitView(onContinue: {}, onSkip: {})
        }
    }
}
#endif
