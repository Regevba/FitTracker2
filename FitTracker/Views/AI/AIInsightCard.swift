// FitTracker/Views/AI/AIInsightCard.swift
// Compact Home tab card — shows the brand logo avatar + one AI insight.
// Taps open AIIntelligenceSheet for the full recommendation set.

import SwiftUI

struct AIInsightCard: View {
    @EnvironmentObject private var orchestrator: AIOrchestrator
    @EnvironmentObject private var analytics: AnalyticsService
    @State private var showSheet = false

    var body: some View {
        Button {
            showSheet = true
            analytics.logAiInsightTap(segment: primarySegment)
        } label: {
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
        .onAppear {
            analytics.logAiInsightShown(
                segment: primarySegment,
                confidence: primaryRecommendation.map { _ in "medium" } ?? "none",
                sourceTier: "local"
            )
        }
        .accessibilityLabel("AI insight: \(insightTitle). \(insightSubtitle). Double tap to see all recommendations.")
    }

    // MARK: - Derived

    private var hasInsight: Bool {
        !orchestrator.latestRecommendations.isEmpty
    }

    private var primaryRecommendation: AIRecommendation? {
        // Priority: recovery > training > nutrition > stats
        for segment in [AISegment.recovery, .training, .nutrition, .stats] {
            if let rec = orchestrator.latestRecommendations[segment] {
                return rec
            }
        }
        return nil
    }

    private var primarySegment: String {
        for segment in [AISegment.recovery, .training, .nutrition, .stats] {
            if orchestrator.latestRecommendations[segment] != nil {
                return segment.rawValue
            }
        }
        return "none"
    }

    private var insightTitle: String {
        guard let rec = primaryRecommendation else {
            return "Analyzing your data..."
        }
        // Map internal signals to human-readable copy
        return rec.signals.first.map(humanReadableSignal) ?? "Check your latest insights"
    }

    private var insightSubtitle: String {
        guard primaryRecommendation != nil else {
            return "Collecting data for personalized insights"
        }
        return "Tap to see all AI recommendations"
    }

    /// Maps internal signal keys to user-facing copy.
    /// Follows "Celebration Not Guilt" principle — encouraging, never judgmental.
    private func humanReadableSignal(_ signal: String) -> String {
        switch signal {
        case let s where s.contains("sleep_deprivation") || s.contains("sleep_debt"):
            return "Your sleep quality could use a boost"
        case let s where s.contains("elevated_resting_hr") || s.contains("elevated_hr"):
            return "Your heart rate is a bit elevated today"
        case let s where s.contains("recovery_phase") || s.contains("keep_intensity"):
            return "Your body is in recovery mode"
        case let s where s.contains("protein_below"):
            return "You might want to up your protein today"
        case let s where s.contains("high_frequency") || s.contains("overreaching"):
            return "Consider dialing back intensity"
        case let s where s.contains("readiness_critical"):
            return "Your body needs rest today"
        case let s where s.contains("hydration"):
            return "Watch your hydration levels"
        case let s where s.contains("consistency") || s.contains("streak"):
            return "Great consistency — keep it up!"
        default:
            return "New insight available"
        }
    }
}
