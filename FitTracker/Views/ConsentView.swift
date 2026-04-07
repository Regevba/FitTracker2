// Views/ConsentView.swift
// GDPR analytics consent screen — shown once after sign-in.
// Design aligned with Figma "Privacy + Permissions" screen language:
// light blue background, shield illustration, centered layout,
// brand CTA button, quiet skip option.

import SwiftUI

struct ConsentView: View {
    @EnvironmentObject private var analytics: AnalyticsService
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Shield illustration (matches Figma shield+lock+check pattern)
            ZStack {
                Circle()
                    .fill(AppColor.Brand.coolSoft.opacity(0.5))
                    .frame(width: 160, height: 160)

                // Shield body
                Image(systemName: "lock.shield.fill")
                    .font(AppText.iconHero)
                    .foregroundStyle(AppColor.Brand.secondary)

                // Check badge
                Image(systemName: "checkmark.circle.fill")
                    .font(AppText.subheading)
                    .foregroundStyle(AppColor.Status.success)
                    .background(Circle().fill(Color.white).frame(width: 26, height: 26))
                    .offset(x: 44, y: -44)
            }
            .padding(.bottom, AppSpacing.large)

            // Title — matches Figma: Inter Bold 28px, #1F2429
            Text("Help Us Improve FitMe")
                .font(AppText.titleStrong)
                .foregroundStyle(AppColor.Text.primary)
                .multilineTextAlignment(.center)

            Spacer().frame(height: AppSpacing.small)

            // Description — matches Figma: Inter Regular 17px, #59616B
            Text("We use anonymous analytics to understand how the app is used and make it better. Your health data is never shared.")
                .font(AppText.bodyRegular)
                .foregroundStyle(AppColor.Text.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.medium)

            Spacer().frame(height: AppSpacing.large)

            // What we track / don't track — card style
            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                trackingRow(allowed: true, text: "App usage patterns")
                trackingRow(allowed: true, text: "Screen views")
                trackingRow(allowed: true, text: "Feature adoption")
                Divider().padding(.vertical, AppSpacing.xxxSmall)
                trackingRow(allowed: false, text: "Health data values")
                trackingRow(allowed: false, text: "Personal information")
                trackingRow(allowed: false, text: "Location or contacts")
            }
            .padding(AppSpacing.medium)
            .background(AppColor.Surface.primary)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
            .shadow(color: AppShadow.cardColor, radius: AppShadow.cardRadius, y: AppShadow.cardYOffset)
            .padding(.horizontal, AppSpacing.medium)

            Spacer().frame(height: AppSpacing.small)

            // Learn more link
            Button {
                if let url = URL(string: "https://fitme.app/privacy") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Learn more about our privacy practices")
                    .font(AppText.caption)
                    .foregroundStyle(AppColor.Accent.primary)
            }

            Spacer()

            // Accept button — matches Figma: brand orange, 20px radius, white text
            Button {
                analytics.consent.grantConsent()
                analytics.syncConsentToProvider()
                analytics.logConsentGranted(type: "gdpr")
                Task { await analytics.consent.requestATT() }
                onComplete()
            } label: {
                Text("Accept & Continue")
                    .font(AppText.button)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.small)
            }
            .background(AppColor.Brand.primary)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
            .shadow(color: AppShadow.ctaColor, radius: AppShadow.ctaRadius, y: AppShadow.ctaYOffset)
            .padding(.horizontal, AppSpacing.large)

            Spacer().frame(height: AppSpacing.small)

            // Decline button — matches Figma "Skip for now" quiet style
            Button {
                analytics.consent.denyConsent()
                analytics.syncConsentToProvider()
                analytics.logConsentDenied(type: "gdpr")
                onComplete()
            } label: {
                Text("Continue Without")
                    .font(AppText.body)
                    .foregroundStyle(AppColor.Text.tertiary)
            }

            // Footer
            Text("You can change this anytime in Settings → Data.")
                .font(AppText.caption)
                .foregroundStyle(AppColor.Text.tertiary)
                .padding(.top, AppSpacing.small)
                .padding(.bottom, AppSpacing.large)
        }
        .padding(.horizontal, AppSpacing.large)
        .background(AppColor.Background.appTint)
        .analyticsScreen(AnalyticsScreen.consent)
    }

    @ViewBuilder
    private func trackingRow(allowed: Bool, text: String) -> some View {
        HStack(spacing: AppSpacing.xSmall) {
            Image(systemName: allowed ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(allowed ? AppColor.Status.success : AppColor.Status.error)
                .font(AppText.body)
            Text(text)
                .font(AppText.body)
                .foregroundStyle(AppColor.Text.primary)
        }
    }
}
