// Views/ConsentView.swift
// GDPR analytics consent screen — shown once after sign-in.
// Two clear choices: Accept & Continue / Continue Without.
// Triggers ATT dialog on accept.

import SwiftUI

struct ConsentView: View {
    @EnvironmentObject private var analytics: AnalyticsService
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: AppSpacing.large) {
            Spacer()

            // Icon
            Image(systemName: "chart.bar.xaxis.ascending")
                .font(.system(size: 48))
                .foregroundStyle(AppColor.Brand.primary)
                .padding(.bottom, AppSpacing.small)

            // Title
            Text("Help Us Improve FitMe")
                .font(AppText.titleStrong)
                .foregroundStyle(AppColor.Text.primary)
                .multilineTextAlignment(.center)

            // Description
            Text("We use anonymous analytics to understand how the app is used and make it better.")
                .font(AppText.bodyRegular)
                .foregroundStyle(AppColor.Text.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.large)

            // What we track / don't track
            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                trackingRow(allowed: true, text: "App usage patterns")
                trackingRow(allowed: true, text: "Screen views")
                trackingRow(allowed: true, text: "Feature adoption")
                trackingRow(allowed: false, text: "Health data values")
                trackingRow(allowed: false, text: "Personal information")
                trackingRow(allowed: false, text: "Location or contacts")
            }
            .padding(AppSpacing.medium)
            .background(AppColor.Surface.secondary)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
            .padding(.horizontal, AppSpacing.large)

            // Learn more link
            Button {
                // Open privacy policy URL
                if let url = URL(string: "https://fitme.app/privacy") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Learn more about our privacy practices")
                    .font(AppText.caption)
                    .foregroundStyle(AppColor.Accent.primary)
            }

            Spacer()

            // Accept button
            Button {
                analytics.consent.grantConsent()
                analytics.syncConsentToProvider()
                analytics.logConsentGranted(type: "gdpr")
                Task {
                    await analytics.consent.requestATT()
                }
                onComplete()
            } label: {
                Text("Accept & Continue")
                    .font(AppText.button)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.small)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColor.Brand.primary)
            .padding(.horizontal, AppSpacing.large)

            // Decline button
            Button {
                analytics.consent.denyConsent()
                analytics.syncConsentToProvider()
                analytics.logConsentDenied(type: "gdpr")
                onComplete()
            } label: {
                Text("Continue Without")
                    .font(AppText.body)
                    .foregroundStyle(AppColor.Text.secondary)
            }

            // Footer
            Text("You can change this anytime in Settings → Data.")
                .font(AppText.caption)
                .foregroundStyle(AppColor.Text.tertiary)
                .padding(.bottom, AppSpacing.large)
        }
        .background(AppColor.Background.appPrimary)
        .analyticsScreen(AnalyticsScreen.consent)
    }

    @ViewBuilder
    private func trackingRow(allowed: Bool, text: String) -> some View {
        HStack(spacing: AppSpacing.xSmall) {
            Image(systemName: allowed ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(allowed ? AppColor.Status.success : AppColor.Status.error)
                .font(.system(size: 16))
            Text(text)
                .font(AppText.body)
                .foregroundStyle(AppColor.Text.primary)
        }
    }
}
