// FitTracker/Views/AI/AIRecommendationCard.swift
// Single recommendation card — segment header, signal text, confidence + source badges.

import SwiftUI

struct AIRecommendationCard: View {
    let recommendation: AIRecommendation
    let segment: AISegment

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            // Segment header
            HStack(spacing: AppSpacing.xSmall) {
                Image(systemName: segmentIcon)
                    .font(AppText.caption)
                    .foregroundStyle(AppColor.Text.secondary)
                Text(segment.rawValue.capitalized)
                    .font(AppText.caption)
                    .foregroundStyle(AppColor.Text.secondary)
            }

            // Recommendation text
            Text(recommendationText)
                .font(AppText.body)
                .foregroundStyle(AppColor.Text.primary)
                .fixedSize(horizontal: false, vertical: true)

            // Badges row
            HStack(spacing: AppSpacing.small) {
                // Confidence badge
                Text(confidenceLabel)
                    .font(AppText.caption)
                    .foregroundStyle(AppColor.Text.inversePrimary)
                    .padding(.horizontal, AppSpacing.small)
                    .padding(.vertical, AppSpacing.xxxSmall)
                    .background(confidenceColor, in: Capsule())

                // Source tier badge
                Text(sourceTier)
                    .font(AppText.caption)
                    .foregroundStyle(AppColor.Text.tertiary)
                    .padding(.horizontal, AppSpacing.small)
                    .padding(.vertical, AppSpacing.xxxSmall)
                    .background(AppColor.Surface.tertiary, in: Capsule())

                Spacer()
            }
        }
        .padding(AppSpacing.medium)
        .background(AppColor.Surface.secondary, in: RoundedRectangle(cornerRadius: AppRadius.card))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(segment.rawValue) recommendation: \(recommendationText). Confidence: \(confidenceLabel)")
    }

    // MARK: - Helpers

    private var segmentIcon: String {
        switch segment {
        case .training:  return AppIcon.training
        case .nutrition: return AppIcon.nutrition
        case .recovery:  return AppIcon.heart
        case .stats:     return AppIcon.stats
        }
    }

    private var recommendationText: String {
        let joined = recommendation.signals.joined(separator: ". ")
        return joined.isEmpty ? "No signals available" : joined
    }

    private var confidenceLabel: String {
        if recommendation.confidence >= 0.7 { return "High" }
        if recommendation.confidence >= 0.4 { return "Medium" }
        return "Low"
    }

    private var confidenceColor: Color {
        if recommendation.confidence >= 0.7 { return AppColor.Status.success }
        if recommendation.confidence >= 0.4 { return AppColor.Brand.primary }
        return AppColor.Status.warning
    }

    private var sourceTier: String {
        if recommendation.escalateToLLM { return "AI" }
        return recommendation.confidence > 0.25 ? "Cloud" : "Local"
    }
}
