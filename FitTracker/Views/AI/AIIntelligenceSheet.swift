// FitTracker/Views/AI/AIIntelligenceSheet.swift
// Full recommendation sheet — segment sections, readiness breakdown, feedback row.

import SwiftUI

struct AIIntelligenceSheet: View {
    @EnvironmentObject private var orchestrator:   AIOrchestrator
    @EnvironmentObject private var dataStore:      EncryptedDataStore
    @EnvironmentObject private var analytics:      AnalyticsService
    @EnvironmentObject private var healthService:  HealthKitService
    @EnvironmentObject private var readinessAware: ReadinessAwareAlertStore
    @EnvironmentObject private var trendAlert:     TrendAlertStore
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

                    // C2 — readiness-aware training alert banner (when present)
                    if let context = readinessAware.current() {
                        readinessAwareBanner(context: context)
                    }

                    // Segment sections
                    ForEach(AISegment.allCases, id: \.self) { segment in
                        segmentSection(segment)
                    }

                    // Readiness breakdown
                    readinessSection

                    // C4 — Your HRV Trend (sustained-trend advisory, when present)
                    if let context = trendAlert.current() {
                        hrvTrendSection(context: context)
                    }

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
                    .accessibilityLabel("Close")
                }
            }
            .onAppear { analytics.logAiSheetOpened(entryPoint: "insight_card") }
        }
    }

    // MARK: - C2 banner

    @ViewBuilder
    private func readinessAwareBanner(context: ReadinessAlertContext) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Text(context.recommendation.headline)
                .font(AppText.sectionTitle)
                .foregroundStyle(AppColor.Text.primary)

            Text("Readiness \(context.readinessScore)/100. Driving factor: \(context.drivingComponent.rawValue.capitalized).")
                .font(AppText.caption)
                .foregroundStyle(AppColor.Text.secondary)

            HStack(spacing: AppSpacing.xSmall) {
                ForEach(ReadinessAlertRecommendation.allCases, id: \.self) { option in
                    ctaButton(option: option, context: context)
                }
            }
        }
        .padding(AppSpacing.medium)
        .background(
            AppColor.Surface.primary,
            in: RoundedRectangle(cornerRadius: AppRadius.card)
        )
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func ctaButton(option: ReadinessAlertRecommendation, context: ReadinessAlertContext) -> some View {
        let isPrimary = option == context.recommendation
        let background: Color = isPrimary ? AppColor.Brand.primary : AppColor.Surface.secondary
        let foreground: Color = isPrimary ? AppColor.Text.inversePrimary : AppColor.Text.primary

        Button {
            handleCTA(option, context: context)
        } label: {
            Text(option.primaryCTA)
                .font(AppText.caption)
                .padding(.horizontal, AppSpacing.small)
                .padding(.vertical, AppSpacing.xxSmall)
                .background(background, in: Capsule())
                .foregroundStyle(foreground)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.primaryCTA)
    }

    private func handleCTA(_ choice: ReadinessAlertRecommendation, context: ReadinessAlertContext) {
        analytics.logHomeReadinessAlertActionTaken(
            recommendation: context.recommendation.rawValue,
            chosen: choice.rawValue
        )
        readinessAware.clear()
        dismiss()
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

    // MARK: - C4 — Your HRV Trend section

    @ViewBuilder
    private func hrvTrendSection(context: TrendAlertContext) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Text("Your HRV Trend")
                .font(AppText.sectionTitle)
                .foregroundStyle(AppColor.Text.primary)

            HRVTrendChart(
                dailySamples: paddedSamples(from: context),
                baseline: context.baseline,
                floor: context.floor,
                referenceDates: paddedDates(from: context)
            )

            Text("Baseline computed from your last 30 days. Adjust at Settings → Notifications → Trend Alerts.")
                .font(AppText.caption)
                .foregroundStyle(AppColor.Text.secondary)

            HStack(spacing: AppSpacing.medium) {
                Spacer()
                trendFeedbackButton(rating: "positive", icon: "hand.thumbsup", kind: context.kind.rawValue)
                trendFeedbackButton(rating: "negative", icon: "hand.thumbsdown", kind: context.kind.rawValue)
                Spacer()
            }
            .padding(.top, AppSpacing.xSmall)
        }
        .padding(AppSpacing.medium)
        .background(
            AppColor.Surface.primary,
            in: RoundedRectangle(cornerRadius: AppRadius.card)
        )
        .accessibilityElement(children: .contain)
    }

    private func trendFeedbackButton(rating: String, icon: String, kind: String) -> some View {
        Button {
            analytics.logHomeTrendAlertActionTaken(kind: kind, rating: rating)
            trendAlert.clear()
        } label: {
            Image(systemName: icon)
                .font(AppText.subheading)
                .foregroundStyle(AppColor.Text.secondary)
                .padding(AppSpacing.xSmall)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(rating == "positive" ? "Helpful" : "Not helpful")
    }

    /// Pads the context's samples array to 7 days (oldest → newest) so the
    /// chart renders a full week even when the trigger only fires on the
    /// most recent 3 days. Missing days surface as nil (gaps in the line).
    private func paddedSamples(from context: TrendAlertContext) -> [Double?] {
        let prefixCount = max(0, 7 - context.samples.count)
        let prefix: [Double?] = Array(repeating: nil, count: prefixCount)
        let recent: [Double?] = context.samples.map { Optional($0) }
        return prefix + recent
    }

    private func paddedDates(from context: TrendAlertContext) -> [Date] {
        let calendar = Calendar.current
        let endDate = context.generatedAt
        return (0..<7).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: endDate)
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
                .frame(width: AppSize.captionLabelWidth, alignment: .leading)

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
                .frame(width: AppSize.iconContainer, alignment: .trailing)
        }
    }
}
