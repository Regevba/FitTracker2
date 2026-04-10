// FitTracker/Views/Onboarding/OnboardingConsentView.swift
// Onboarding Step 4 — Analytics consent (GDPR)
// Figma ref: "Privacy + Permissions" pattern (node 474:2)
// Light blue bg, shield illustration, consent explanation,
// brand CTA "Accept & Continue", quiet "Continue Without"
//
// v2 UX alignment (2026-04-07):
//  - ScrollView wrapper for Dynamic Type [P1-06]
//  - AppSize.iconBadge token [P2-02]
//  - AppColor.Text.inversePrimary instead of .white [P1-05]
//  - AppSize.ctaHeight token [P1-03]
//  - onboarding_step_viewed event [P0-02]

import SwiftUI

struct OnboardingConsentView: View {
    @EnvironmentObject private var analytics: AnalyticsService
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        ScrollView {
        VStack(spacing: 0) {
            Spacer().frame(height: AppSpacing.xxLarge)

            // Shield illustration — matches Figma shield+lock+check
            ZStack {
                Circle()
                    .fill(AppColor.Brand.coolSoft.opacity(0.5))
                    .frame(width: 160, height: 160)

                Image(systemName: "lock.shield.fill")
                    .font(AppText.iconHero)
                    .foregroundStyle(AppColor.Brand.secondary)

                Image(systemName: "checkmark.circle.fill")
                    .font(AppText.subheading)
                    .foregroundStyle(AppColor.Status.success)
                    .background(Circle().fill(AppColor.Surface.primary).frame(width: AppSize.iconBadge, height: AppSize.iconBadge))
                    .offset(x: 44, y: -44)
            }
            .padding(.bottom, AppSpacing.large)

            // Title — Figma: Inter Bold 28px
            Text("Help Us Improve FitMe")
                .font(AppText.titleStrong)
                .foregroundStyle(AppColor.Text.primary)
                .multilineTextAlignment(.center)

            Spacer().frame(height: AppSpacing.small)

            // Description
            Text("We use anonymous analytics to understand how the app is used. Your health data is never shared.")
                .font(AppText.bodyRegular)
                .foregroundStyle(AppColor.Text.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.medium)

            Spacer().frame(height: AppSpacing.large)

            // What we track / don't track
            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                consentRow(allowed: true, text: "App usage patterns")
                consentRow(allowed: true, text: "Screen views & feature adoption")
                Divider().padding(.vertical, AppSpacing.xxxSmall)
                consentRow(allowed: false, text: "Health data values")
                consentRow(allowed: false, text: "Personal information")
            }
            .padding(AppSpacing.medium)
            .background(AppColor.Surface.primary)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
            .shadow(color: AppShadow.cardColor, radius: AppShadow.cardRadius, y: AppShadow.cardYOffset)
            .padding(.horizontal, AppSpacing.medium)

            Spacer()

            // Accept — Figma: brand orange, 20px radius, white text
            Button(action: onAccept) {
                Text("Accept & Continue")
                    .font(AppText.button)
                    .foregroundStyle(AppColor.Text.inversePrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: AppSize.ctaHeight)
            }
            .background(AppColor.Brand.primary, in: RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous))
            .shadow(color: AppShadow.ctaColor, radius: AppShadow.ctaRadius, y: AppShadow.ctaYOffset)
            .buttonStyle(.plain)
            .padding(.horizontal, AppSpacing.large)

            Spacer().frame(height: AppSpacing.small)

            // Decline — Figma: quiet gray text
            Button(action: onDecline) {
                Text("Continue Without")
                    .font(AppText.body)
                    .foregroundStyle(AppColor.Text.tertiary)
            }

            Text("You can change this anytime in Settings.")
                .font(AppText.caption)
                .foregroundStyle(AppColor.Text.tertiary)
                .padding(.top, AppSpacing.xSmall)
                .padding(.bottom, AppSpacing.large)
        }
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .onAppear {
            analytics.logScreenView(AnalyticsScreen.consent, screenClass: "OnboardingConsentView")
            analytics.logOnboardingStepViewed(stepIndex: 4, stepName: "consent")
        }
    }

    @ViewBuilder
    private func consentRow(allowed: Bool, text: String) -> some View {
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
