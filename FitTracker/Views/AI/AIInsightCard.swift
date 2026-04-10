// FitTracker/Views/AI/AIInsightCard.swift
// Compact Home tab card — shows the brand logo avatar + one AI insight.
// Taps open AIIntelligenceSheet for the full recommendation set.

import SwiftUI

struct AIInsightCard: View {
    @EnvironmentObject private var orchestrator: AIOrchestrator
    @State private var showSheet = false

    var body: some View {
        Button { showSheet = true } label: {
            HStack(spacing: AppSpacing.medium) {
                FitMeLogoLoader(mode: hasInsight ? .breathe : .shimmer, size: .small)

                VStack(alignment: .leading, spacing: AppSpacing.xxxSmall) {
                    Text(insightTitle)
                        .font(AppText.subheading)
                        .foregroundStyle(AppColor.Text.primary)
                        .lineLimit(2)

                    Text(insightSubtitle)
                        .font(AppText.caption)
                        .foregroundStyle(AppColor.Text.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: AppIcon.forward)
                    .font(AppText.caption)
                    .foregroundStyle(AppColor.Text.tertiary)
            }
            .padding(AppSpacing.medium)
            .background(AppColor.Surface.primary, in: RoundedRectangle(cornerRadius: AppRadius.card))
            .shadow(
                color: AppShadow.cardColor,
                radius: AppShadow.cardRadius,
                y: AppShadow.cardYOffset
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showSheet) {
            AIIntelligenceSheet()
        }
        .accessibilityLabel("AI insight: \(insightTitle). \(insightSubtitle). Double tap to see all recommendations.")
    }

    // MARK: - Derived

    private var hasInsight: Bool {
        !orchestrator.latestRecommendations.isEmpty
    }

    private var insightTitle: String {
        if let training = orchestrator.latestRecommendations[.training],
           let signal = training.signals.first {
            return signal
        }
        if let recovery = orchestrator.latestRecommendations[.recovery],
           let signal = recovery.signals.first {
            return signal
        }
        if let first = orchestrator.latestRecommendations.values.first,
           let signal = first.signals.first {
            return signal
        }
        return "Analyzing your data..."
    }

    private var insightSubtitle: String {
        hasInsight
            ? "Tap to see all AI recommendations"
            : "Collecting data for personalized insights"
    }
}
