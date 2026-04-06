// FitTracker/Views/Onboarding/OnboardingHealthKitView.swift
// Onboarding Step 3 — HealthKit permission request.
import SwiftUI

struct OnboardingHealthKitView: View {
    let onContinue: () -> Void
    let onSkip: () -> Void

    @EnvironmentObject private var analytics: AnalyticsService
    @EnvironmentObject private var healthService: HealthKitService

    private let dataTypes: [(icon: String, label: String)] = [
        ("heart.fill", "Heart Rate"),
        ("waveform.path.ecg", "Heart Rate Variability"),
        ("figure.walk", "Steps"),
        ("bed.double.fill", "Sleep"),
    ]

    var body: some View {
        VStack(spacing: AppSpacing.large) {
            Spacer()

            VStack(spacing: AppSpacing.medium) {
                Image(systemName: "heart.text.square")
                    .font(AppText.iconHero)
                    .foregroundStyle(AppColor.Brand.primary)

                Text("Sync your health data")
                    .font(AppText.pageTitle)
                    .foregroundStyle(AppColor.Text.primary)

                Text("FitMe uses Apple Health to track your recovery and training readiness.")
                    .font(AppText.body)
                    .foregroundStyle(AppColor.Text.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.small)
            }

            // Data type rows
            VStack(spacing: AppSpacing.xxSmall) {
                ForEach(dataTypes, id: \.label) { dataType in
                    HealthDataRow(icon: dataType.icon, label: dataType.label)
                }
            }
            .padding(.horizontal, AppSpacing.small)

            Spacer()

            VStack(spacing: AppSpacing.xSmall) {
                Button {
                    Task {
                        try? await healthService.requestAuthorization()
                        onContinue()
                    }
                } label: {
                    Text("Connect Health")
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
            analytics.logScreenView("onboarding_healthkit")
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
