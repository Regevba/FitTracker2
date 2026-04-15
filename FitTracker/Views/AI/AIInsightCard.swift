// FitTracker/Views/AI/AIInsightCard.swift
// Compact Home tab card — shows the brand logo avatar + one AI insight.
// Taps open AIIntelligenceSheet for the full recommendation set.

import SwiftUI

struct AIInsightCard: View {
    @EnvironmentObject private var orchestrator: AIOrchestrator
    @EnvironmentObject private var analytics: AnalyticsService
    @State private var showSheet = false
    @State private var feedbackGiven = false

    var body: some View {
        Button {
            showSheet = true
            analytics.logAiInsightTap(segment: primarySegment)
        } label: {
            HStack(spacing: AppSpacing.medium) {
                FitMeLogoLoader(mode: hasInsight ? .breathe : .shimmer, size: .small)

                VStack(alignment: .leading, spacing: AppSpacing.xxxSmall) {
                    HStack(spacing: AppSpacing.xxSmall) {
                        Text(insightTitle)
                            .font(AppText.subheading)
                            .foregroundStyle(AppColor.Text.primary)
                            .lineLimit(2)

                        if let badge = confidenceBadge {
                            Text(badge)
                                .font(AppText.footnote)
                                .foregroundStyle(AppColor.Text.tertiary)
                                .padding(.horizontal, AppSpacing.xxSmall)
                                .padding(.vertical, 2)
                                .background(AppColor.Surface.secondary, in: Capsule())
                        }
                    }

                    Text(insightSubtitle)
                        .font(AppText.caption)
                        .foregroundStyle(AppColor.Text.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if hasInsight && !feedbackGiven {
                    feedbackButtons
                } else {
                    Image(systemName: AppIcon.forward)
                        .font(AppText.caption)
                        .foregroundStyle(AppColor.Text.tertiary)
                }
            }
            .padding(AppSpacing.medium)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppRadius.card))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showSheet) {
            AIIntelligenceSheet()
        }
        .onAppear {
            analytics.logAiInsightShown(
                segment: primarySegment,
                confidence: confidenceLevel,
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

    // MARK: - Confidence

    private var primaryValidated: ValidatedRecommendation? {
        for segment in [AISegment.recovery, .training, .nutrition, .stats] {
            if let validated = orchestrator.validatedRecommendations[segment] {
                return validated
            }
        }
        return nil
    }

    private var confidenceLevel: String {
        primaryValidated?.overallConfidence.rawValue ?? "none"
    }

    private var confidenceBadge: String? {
        guard let validated = primaryValidated else { return nil }
        switch validated.overallConfidence {
        case .medium: return "Limited data"
        case .low:    return "Suggestion"
        case .high:   return nil  // no badge needed for high confidence
        }
    }

    // MARK: - Feedback

    private var feedbackButtons: some View {
        HStack(spacing: AppSpacing.xSmall) {
            Button {
                recordFeedback(.accepted)
            } label: {
                Image(systemName: "hand.thumbsup")
                    .font(AppText.caption)
                    .foregroundStyle(AppColor.Text.tertiary)
            }
            .buttonStyle(.plain)

            Button {
                recordFeedback(.dismissed)
            } label: {
                Image(systemName: "hand.thumbsdown")
                    .font(AppText.caption)
                    .foregroundStyle(AppColor.Text.tertiary)
            }
            .buttonStyle(.plain)
        }
        .accessibilityLabel("Rate this recommendation")
    }

    private func recordFeedback(_ action: UserAction) {
        feedbackGiven = true
        guard let validated = primaryValidated else { return }

        let outcome = RecommendationOutcome(
            segment: validated.recommendation.segment,
            signals: validated.recommendation.signals,
            confidenceLevel: validated.overallConfidence.rawValue,
            source: validated.evidenceChain.isEmpty ? "local" : "cloud",
            action: action,
            dismissReason: nil,
            timestamp: Date()
        )

        // Log analytics — reuse existing feedback method with appropriate rating
        if action == .accepted {
            analytics.logAiFeedbackSubmitted(segment: validated.recommendation.segment, rating: "positive")
        } else {
            analytics.logAiFeedbackSubmitted(segment: validated.recommendation.segment, rating: "negative")
        }

        // TODO: Wire to RecommendationMemory singleton when DI is set up
        _ = outcome
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
