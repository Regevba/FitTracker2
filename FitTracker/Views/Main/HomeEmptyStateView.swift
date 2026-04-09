// FitTracker/Views/Main/HomeEmptyStateView.swift
// Empty state displayed on the Home screen when there is no data
// (no HealthKit connection AND no manual entries).
import SwiftUI

// MARK: - EmptyReason

/// Describes why the Home screen has no data to display.
enum EmptyReason {
    /// First time the user opens the app — no data of any kind yet.
    case firstLaunch
    /// HealthKit is not connected (denied or never requested).
    case noHealthKit
    /// HealthKit may be connected but there are no metrics logged yet.
    case noData

    var title: String {
        switch self {
        case .firstLaunch: return "Welcome to FitMe!"
        case .noHealthKit:  return "Connect Apple Health"
        case .noData:       return "No metrics yet"
        }
    }

    var subtitle: String {
        switch self {
        case .firstLaunch:
            return "Connect your health data or log manually to get started"
        case .noHealthKit:
            return "FitMe works best with your health data — sleep, heart rate, and activity"
        case .noData:
            return "Start logging to see your readiness and trends"
        }
    }
}

// MARK: - HomeEmptyStateView

struct HomeEmptyStateView: View {
    let emptyReason: EmptyReason
    let onConnectHealth: () -> Void
    let onLogManually: () -> Void

    var body: some View {
        VStack(spacing: AppSpacing.medium) {
            Spacer()

            // Icon
            Image(systemName: "heart.text.clipboard")
                .font(AppText.iconLarge)
                .foregroundStyle(AppColor.Accent.primary)

            // Title
            Text(emptyReason.title)
                .font(AppText.titleMedium)
                .foregroundStyle(AppColor.Text.primary)
                .multilineTextAlignment(.center)

            // Subtitle
            Text(emptyReason.subtitle)
                .font(AppText.body)
                .foregroundStyle(AppColor.Text.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.large)

            // Buttons
            VStack(spacing: AppSpacing.xSmall) {
                // Primary — Connect Health
                Button(action: connectHealthAction) {
                    Text("Connect Health")
                        .font(AppText.button)
                        .foregroundStyle(AppColor.Text.inversePrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: AppSize.ctaHeight)
                        .background(
                            AppColor.Accent.primary,
                            in: RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Connect Health")
                .accessibilityHint(
                    emptyReason == .noHealthKit
                        ? "Opens Settings to grant Apple Health access"
                        : "Connects your Apple Health data to FitMe"
                )

                // Secondary — Log manually
                Button(action: onLogManually) {
                    Text("Log manually")
                        .font(AppText.button)
                        .foregroundStyle(AppColor.Accent.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: AppSize.ctaHeight)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
                                .strokeBorder(AppColor.Accent.primary, lineWidth: 1.5)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Log manually")
                .accessibilityHint("Opens the manual logging screen")
            }
            .padding(.horizontal, AppSpacing.large)
            .padding(.top, AppSpacing.xSmall)

            Spacer()
        }
    }

    // MARK: - Private

    /// When HealthKit was denied, deep-link to Settings; otherwise invoke the callback.
    private func connectHealthAction() {
        if emptyReason == .noHealthKit {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        } else {
            onConnectHealth()
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("First Launch") {
    HomeEmptyStateView(
        emptyReason: .firstLaunch,
        onConnectHealth: {},
        onLogManually: {}
    )
    .background(AppGradient.screenBackground)
}

#Preview("No HealthKit") {
    HomeEmptyStateView(
        emptyReason: .noHealthKit,
        onConnectHealth: {},
        onLogManually: {}
    )
    .background(AppGradient.screenBackground)
}

#Preview("No Data") {
    HomeEmptyStateView(
        emptyReason: .noData,
        onConnectHealth: {},
        onLogManually: {}
    )
    .background(AppGradient.screenBackground)
}
#endif
