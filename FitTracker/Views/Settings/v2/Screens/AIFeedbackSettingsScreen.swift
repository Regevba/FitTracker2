// FitTracker/Views/Settings/v2/Screens/AIFeedbackSettingsScreen.swift
// C5 ai-user-feedback-loop (2026-06-01).
//
// Settings detail screen showing on-device AI feedback history:
//   - Total outcomes recorded
//   - Per-segment acceptance rate breakdown (training/recovery/nutrition/stats)
//   - Currently suppressed signals (>=3 dismissals in last 30 days)
//   - Opt-out toggle (default ON; gates AIOrchestrator reinforcement loop)
//   - Clear-all button (GDPR + reset-on-distrust)
//
// All copy + behavior per docs/product/prd/ai-user-feedback-loop.md.

import SwiftUI

struct AIFeedbackSettingsScreen: View {
    @EnvironmentObject private var feedbackController: RecommendationFeedbackController
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var analytics: AnalyticsService
    @State private var showClearConfirm = false

    var body: some View {
        SettingsDetailScaffold(
            title: SettingsCategory.aiFeedback.title,
            subtitle: "Manage what the AI learns from your taps. Everything here stays on this device."
        ) {
            totalSection
            perSegmentSection
            suppressedSignalsSection
            controlsSection
        }
    }

    // MARK: - Sections

    private var totalSection: some View {
        SettingsSectionCard(title: "Feedback Activity", eyebrow: "What's Recorded") {
            HStack {
                VStack(alignment: .leading, spacing: AppSpacing.micro) {
                    Text(feedbackController.totalCount == 0 ? "No outcomes yet" : "\(feedbackController.totalCount) outcomes recorded")
                        .font(AppText.body)
                        .foregroundStyle(AppColor.Text.primary)
                    Text(feedbackController.totalCount == 0
                         ? "Once you tap thumbs up or down on insights, your history will appear here."
                         : "Every thumbs-up and thumbs-down you tap is stored on this device.")
                        .font(AppText.caption)
                        .foregroundStyle(AppColor.Text.secondary)
                }
                Spacer(minLength: AppSpacing.medium)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var perSegmentSection: some View {
        SettingsSectionCard(title: "Acceptance Rate by Topic", eyebrow: "Per Segment") {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                ForEach(AISegment.allCases, id: \.rawValue) { segment in
                    perSegmentRow(segment)
                }
            }
        }
    }

    @ViewBuilder
    private func perSegmentRow(_ segment: AISegment) -> some View {
        let outcomes = feedbackController.outcomes(for: segment)
        let rate = feedbackController.acceptanceRate(for: segment)
        HStack {
            Text(segment.rawValue.capitalized)
                .font(AppText.body)
                .foregroundStyle(AppColor.Text.primary)
            Spacer()
            if let rate {
                Text("\(Int(rate * 100))% · \(outcomes.count) outcomes")
                    .font(AppText.caption)
                    .foregroundStyle(AppColor.Text.secondary)
            } else if outcomes.isEmpty {
                Text("—")
                    .font(AppText.caption)
                    .foregroundStyle(AppColor.Text.secondary)
            } else {
                Text("\(outcomes.count) of 5 (below quorum)")
                    .font(AppText.caption)
                    .foregroundStyle(AppColor.Text.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var suppressedSignalsSection: some View {
        SettingsSectionCard(title: "Currently Suppressed", eyebrow: "Last 30 Days") {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                let allSuppressed = collectSuppressed()
                if allSuppressed.isEmpty {
                    Text("No signals are currently suppressed. The reinforcement loop suppresses a signal after 3+ dismissals within 30 days.")
                        .font(AppText.caption)
                        .foregroundStyle(AppColor.Text.secondary)
                } else {
                    ForEach(allSuppressed, id: \.label) { item in
                        HStack(spacing: AppSpacing.xSmall) {
                            Image(systemName: "eye.slash.fill")
                                .foregroundStyle(AppColor.Text.secondary)
                            Text(item.label)
                                .font(AppText.body)
                                .foregroundStyle(AppColor.Text.primary)
                            Spacer()
                            Text(item.segment)
                                .font(AppText.caption)
                                .foregroundStyle(AppColor.Text.secondary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }

    private var controlsSection: some View {
        SettingsSectionCard(title: "Controls", eyebrow: "Opt-Out & Clear") {
            Toggle(isOn: $settings.aiFeedbackLoopEnabled) {
                VStack(alignment: .leading, spacing: AppSpacing.micro) {
                    Text("Use my feedback to personalize recommendations")
                        .font(AppText.body)
                        .foregroundStyle(AppColor.Text.primary)
                    Text(settings.aiFeedbackLoopEnabled
                         ? "When on, the AI engine adapts to your thumbs-up/down history."
                         : "AI recommendations will come from the engine baseline only — your feedback is still recorded but won't influence what you see.")
                        .font(AppText.caption)
                        .foregroundStyle(AppColor.Text.secondary)
                }
            }
            .tint(AppColor.Brand.primary)
            .accessibilityLabel("AI feedback reinforcement loop")

            Button(role: .destructive) {
                showClearConfirm = true
            } label: {
                HStack {
                    Image(systemName: "trash.fill")
                    Text("Clear feedback history")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Clear all feedback history")
            .confirmationDialog(
                "Clear feedback history?",
                isPresented: $showClearConfirm,
                titleVisibility: .visible
            ) {
                Button("Clear history", role: .destructive) {
                    let cleared = feedbackController.totalCount
                    feedbackController.clearAll()
                    analytics.logHomeAiFeedbackHistoryCleared(totalOutcomesCleared: cleared)
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This resets your acceptance rates and unsuppresses all signals. This action is irreversible but doesn't delete any HealthKit or workout data.")
            }
        }
    }

    // MARK: - Helpers

    private struct SuppressedItem: Identifiable {
        var id: String { "\(segment):\(label)" }
        let label: String
        let segment: String
    }

    private func collectSuppressed() -> [SuppressedItem] {
        AISegment.allCases.flatMap { segment in
            feedbackController.frequentlyDismissedSignals(for: segment).map {
                SuppressedItem(label: $0, segment: segment.rawValue.capitalized)
            }
        }
    }
}
