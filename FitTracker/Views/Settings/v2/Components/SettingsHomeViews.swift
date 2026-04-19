// FitTracker/Views/Settings/v2/Components/SettingsHomeViews.swift
// Settings v2 — home-screen sub-components (header, category card, badge row, badge view).
// Extracted from SettingsView.swift in Audit M-1c (UI-002 decomposition).

import SwiftUI

struct SettingsHomeHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {
            Text(title)
                .font(AppText.hero)
                .foregroundStyle(AppColor.Text.primary)

            Text(subtitle)
                .font(AppText.body)
                .foregroundStyle(AppColor.Text.secondary)
        }
    }
}

struct SettingsCategoryCard: View {
    let category: SettingsCategory
    let summary: String
    let badges: [SettingsSummaryBadge]
    let featured: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
            HStack(alignment: .top) {
                Image(systemName: category.icon)
                    .font(featured ? AppText.sectionTitle : AppText.callout)
                    .foregroundStyle(category.tint)
                    .frame(width: 34, height: 34)
                    .background(category.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: AppRadius.small))

                Spacer(minLength: 12)

                Image(systemName: "chevron.right")
                    .font(AppText.captionStrong)
                    .foregroundStyle(AppColor.Text.tertiary)
            }

            VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {
                Text(category.title)
                    .font(featured ? AppText.sectionTitle : AppText.button)
                    .foregroundStyle(AppColor.Text.primary)
                    .multilineTextAlignment(.leading)

                Text(summary)
                    .font(AppText.subheading)
                    .foregroundStyle(AppColor.Text.secondary)
                    .lineLimit(featured ? 2 : 3)
                    .multilineTextAlignment(.leading)
            }

            if !badges.isEmpty {
                FlexibleBadgeRow(badges: badges)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(featured ? AppSpacing.small : AppSpacing.small)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .fill(AppColor.Surface.elevated.opacity(featured ? 0.96 : 0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.large)
                        .stroke(AppColor.Border.subtle, lineWidth: 1)
                )
        )
        .shadow(color: AppShadow.cardColor, radius: AppShadow.cardRadius, y: AppShadow.cardYOffset)
    }
}

struct FlexibleBadgeRow: View {
    let badges: [SettingsSummaryBadge]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: AppSpacing.xxSmall) {
                ForEach(badges) { badge in
                    SettingsBadgeView(badge: badge)
                }
            }

            VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {
                ForEach(badges) { badge in
                    SettingsBadgeView(badge: badge)
                }
            }
        }
    }
}

struct SettingsBadgeView: View {
    let badge: SettingsSummaryBadge

    var body: some View {
        HStack(spacing: AppSpacing.xxSmall) {
            Circle()
                .fill(badge.tint)
                .frame(width: 6, height: 6)
            Text(badge.title)
                .font(AppText.captionStrong)
        }
        .foregroundStyle(badge.tint)
        .padding(.horizontal, AppSpacing.xxSmall)
        .padding(.vertical, AppSpacing.xxSmall)
        .background(badge.tint.opacity(0.12), in: Capsule())
    }
}
