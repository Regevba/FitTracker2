// Views/Shared/LockedFeatureOverlay.swift
// Overlay presented over gated features when the user is not signed in.
// Shows the feature icon, benefit copy, and a CTA to create an account.

import SwiftUI

struct LockedFeatureOverlay: View {
    let featureIcon: String // SF Symbol name
    let featureTitle: String
    let benefitText: String
    let onCreateAccount: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            // Card
            VStack(spacing: AppSpacing.medium) {
                Image(systemName: featureIcon)
                    .font(.system(size: 40))
                    .foregroundStyle(AppColor.Accent.primary)

                Text("Unlock \(featureTitle)")
                    .font(AppText.sectionTitle)
                    .foregroundStyle(AppColor.Text.primary)

                Text(benefitText)
                    .font(AppText.body)
                    .foregroundStyle(AppColor.Text.secondary)
                    .multilineTextAlignment(.center)

                Button(action: onCreateAccount) {
                    Text("Create Account")
                        .font(AppText.button)
                        .foregroundStyle(AppColor.Text.inversePrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: AppSize.ctaHeight)
                        .background(AppColor.Accent.primary, in: RoundedRectangle(cornerRadius: AppRadius.button))
                }
                .buttonStyle(.plain)

                Button("Maybe later", action: onDismiss)
                    .font(AppText.caption)
                    .foregroundStyle(AppColor.Text.tertiary)
            }
            .padding(AppSpacing.large)
            .frame(width: 300)
            .background(AppColor.Surface.primary, in: RoundedRectangle(cornerRadius: AppRadius.card))
            .shadow(color: AppShadow.cardColor, radius: 20, y: 10)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Locked feature: \(featureTitle)")
    }
}
