// FitTracker/Views/Settings/v2/Components/SettingsScaffolds.swift
// Settings v2 — shared scaffolds (detail screen container, section card, value row, supporting text).
// Extracted from SettingsView.swift in Audit M-1b (UI-002 decomposition).

import SwiftUI

struct SettingsDetailScaffold<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            AppGradient.screenBackground
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.large) {
                    SettingsHomeHeader(title: title, subtitle: subtitle)
                    content
                }
                .padding(.horizontal, AppSpacing.medium)
                .padding(.top, AppSpacing.small)
                .padding(.bottom, AppSpacing.large)
            }
        }
    }
}

struct SettingsSectionCard<Content: View>: View {
    let title: String
    let eyebrow: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
            VStack(alignment: .leading, spacing: AppSpacing.xxxSmall) {
                Text(eyebrow.uppercased())
                    .font(AppText.captionStrong)
                    .tracking(1.1)
                    .foregroundStyle(AppColor.Text.tertiary)
                Text(title)
                    .font(AppText.sectionTitle)
                    .foregroundStyle(AppColor.Text.primary)
            }

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.small)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .fill(AppColor.Surface.elevated.opacity(0.96))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.large)
                        .stroke(AppColor.Border.subtle, lineWidth: 1)
                )
        )
        .shadow(color: AppShadow.cardColor, radius: AppShadow.cardRadius, y: AppShadow.cardYOffset)
    }
}

struct SettingsValueRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xSmall) {
            Text(title)
                .font(AppText.body)
                .foregroundStyle(AppColor.Text.primary)
            Spacer()
            Text(value)
                .font(AppText.chip)
                .foregroundStyle(AppColor.Text.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct SettingsSupportingText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(AppText.subheading)
            .foregroundStyle(AppColor.Text.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
