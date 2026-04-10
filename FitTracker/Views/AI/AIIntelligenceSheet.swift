// FitTracker/Views/AI/AIIntelligenceSheet.swift
// Full recommendation sheet — segment sections, readiness breakdown, feedback row.

import SwiftUI

struct AIIntelligenceSheet: View {
    @EnvironmentObject private var orchestrator:   AIOrchestrator
    @EnvironmentObject private var dataStore:      EncryptedDataStore
    @EnvironmentObject private var analytics:      AnalyticsService
    @EnvironmentObject private var healthService:  HealthKitService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.large) {
                    // Hero avatar
                    VStack(spacing: AppSpacing.small) {
                        FitMeLogoLoader(
                            mode: .breathe,
                            size: .large,
                            message: "Here's what I see today"
                        )
                    }
                    .padding(.top, AppSpacing.large)

                    // Segment sections
                    ForEach(AISegment.allCases, id: \.self) { segment in
                        segmentSection(segment)
                    }

                    // Readiness breakdown
                    readinessSection

                    // Feedback
                    AIFeedbackView()
                        .padding(.top, AppSpacing.medium)
                }
                .padding(.horizontal, AppSpacing.medium)
            }
            .background(AppGradient.screenBackground)
            .navigationTitle("AI Intelligence")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: AppIcon.close)
                    }
                }
            }
            .onAppear { analytics.logAiSheetOpened(entryPoint: "insight_card") }
        }
    }

    // MARK: - Segment section

    @ViewBuilder
    private func segmentSection(_ segment: AISegment) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Text(segment.rawValue.capitalized)
                .font(AppText.sectionTitle)
                .foregroundStyle(AppColor.Text.primary)

            if let rec = orchestrator.latestRecommendations[segment] {
                AIRecommendationCard(recommendation: rec, segment: segment)
            } else {
                Text("Not enough data for \(segment.rawValue) insights yet")
                    .font(AppText.caption)
                    .foregroundStyle(AppColor.Text.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppSpacing.medium)
                    .background(
                        AppColor.Surface.secondary,
                        in: RoundedRectangle(cornerRadius: AppRadius.card)
                    )
            }
        }
    }

    // MARK: - Readiness breakdown

    @ViewBuilder
    private var readinessSection: some View {
        let result = dataStore.readinessResult(for: Date(), fallbackMetrics: healthService.latest)

        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Text("Your Readiness Breakdown")
                .font(AppText.sectionTitle)
                .foregroundStyle(AppColor.Text.primary)

            if let r = result {
                VStack(spacing: AppSpacing.xSmall) {
                    readinessBar(label: "HRV",      score: r.hrvScore,          color: AppColor.Chart.hrv)
                    readinessBar(label: "Sleep",    score: r.sleepScore,        color: AppColor.Accent.sleep)
                    readinessBar(label: "Training", score: r.trainingLoadScore, color: AppColor.Brand.primary)
                    readinessBar(label: "RHR",      score: r.rhrScore,          color: AppColor.Chart.heartRate)
                }
                .padding(AppSpacing.medium)
                .background(
                    AppColor.Surface.primary,
                    in: RoundedRectangle(cornerRadius: AppRadius.card)
                )

                HStack {
                    Text("Overall: \(r.overallScore)")
                        .font(AppText.sectionTitle)
                    Text("— \(r.recommendation.rawValue)")
                        .font(AppText.subheading)
                        .foregroundStyle(AppColor.Text.secondary)
                    Spacer()
                    Text(r.confidence.rawValue.capitalized)
                        .font(AppText.caption)
                        .padding(.horizontal, AppSpacing.small)
                        .padding(.vertical, AppSpacing.xxxSmall)
                        .background(AppColor.Surface.secondary, in: Capsule())
                }
            } else {
                Text("Log more data to see your readiness breakdown")
                    .font(AppText.caption)
                    .foregroundStyle(AppColor.Text.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppSpacing.medium)
                    .background(
                        AppColor.Surface.secondary,
                        in: RoundedRectangle(cornerRadius: AppRadius.card)
                    )
            }
        }
    }

    // MARK: - Readiness bar

    private func readinessBar(label: String, score: Double, color: Color) -> some View {
        HStack(spacing: AppSpacing.xSmall) {
            Text(label)
                .font(AppText.caption)
                .foregroundStyle(AppColor.Text.secondary)
                .frame(width: 60, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: AppRadius.micro)
                        .fill(AppColor.Surface.secondary)
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: AppRadius.micro)
                        .fill(color)
                        .frame(width: geo.size.width * min(1, score / 100), height: 8)
                }
            }
            .frame(height: 8)

            Text("\(Int(score))")
                .font(AppText.monoCaption)
                .foregroundStyle(AppColor.Text.tertiary)
                .frame(width: 28, alignment: .trailing)
        }
    }
}
