// FitTracker/Views/Settings/v2/Screens/SuppressedSignalDetailScreen.swift
// D1 (adaptive-intelligence-next-pass) — transparency UX (D1.d).
//
// Pushed from AIFeedbackSettingsScreen when the user taps a row in the
// "Currently Suppressed" section. Shows:
//   - Why the signal was suppressed (3+ dismissals within 30d, with dates)
//   - Whether the 7d acceptance-trend criterion currently fires (auto-recover hint)
//   - Two user actions: Un-suppress (14d window) or Blacklist permanently
//
// 100% on-device. All copy + behavior per
// docs/product/prd/adaptive-intelligence-next-pass.md §D1.d.

import SwiftUI

struct SuppressedSignalDetailScreen: View {
    let segment: AISegment
    let signal: String

    @EnvironmentObject private var feedbackController: RecommendationFeedbackController
    @EnvironmentObject private var analytics: AnalyticsService
    @Environment(\.dismiss) private var dismiss

    @State private var showUnsuppressConfirm = false
    @State private var showBlacklistConfirm = false

    var body: some View {
        SettingsDetailScaffold(
            title: signal,
            subtitle: "Why this signal was suppressed for \(segment.rawValue.capitalized) — and what you can do about it."
        ) {
            whySuppressedSection
            trendSection
            actionsSection
        }
        .onAppear {
            analytics.logHomeAiFeedbackSuppressedDetailOpened(
                segment: segment.rawValue,
                signal: signal,
                dismissalCount: dismissalCount
            )
        }
    }

    // MARK: - Computed (read from RecommendationMemory via controller)

    private var segmentOutcomes: [RecommendationOutcome] {
        feedbackController.outcomes(for: segment)
    }

    /// Lifetime dismissals for this signal+segment.
    private var dismissalCount: Int {
        AcceptanceTrendDetector.priorDismissalCount(
            signal: signal, segment: segment, outcomes: segmentOutcomes)
    }

    /// Most recent dismissals for the explanation list (newest first, capped at 5).
    private var recentDismissals: [Date] {
        segmentOutcomes
            .filter { $0.signals.contains(signal) && $0.action == .dismissed }
            .map(\.timestamp)
            .sorted(by: >)
            .prefix(5)
            .map { $0 }
    }

    private var trendCriterionFires: Bool {
        AcceptanceTrendDetector.shouldUnsuppressByTrend(
            signal: signal,
            segment: segment,
            outcomes: segmentOutcomes
        )
    }

    private var daysSinceLast: Int {
        AcceptanceTrendDetector.daysSinceLastDismiss(
            signal: signal, segment: segment, outcomes: segmentOutcomes)
    }

    // MARK: - Sections

    private var whySuppressedSection: some View {
        SettingsSectionCard(title: "Why It Was Suppressed", eyebrow: "Last 30 Days") {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                Text("This signal showed up in \(dismissalCount) recommendation\(dismissalCount == 1 ? "" : "s") you dismissed.")
                    .font(AppText.body)
                    .foregroundStyle(AppColor.Text.primary)
                if recentDismissals.isEmpty {
                    Text("(No dismissal timestamps recorded — this can happen if the entries were cleared.)")
                        .font(AppText.caption)
                        .foregroundStyle(AppColor.Text.secondary)
                } else {
                    Text("Most recent dismissals:")
                        .font(AppText.caption)
                        .foregroundStyle(AppColor.Text.secondary)
                    ForEach(recentDismissals, id: \.self) { date in
                        HStack(spacing: AppSpacing.xSmall) {
                            Image(systemName: "hand.thumbsdown")
                                .foregroundStyle(AppColor.Text.secondary)
                            Text(date.formatted(date: .abbreviated, time: .shortened))
                                .font(AppText.caption)
                                .foregroundStyle(AppColor.Text.secondary)
                        }
                    }
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var trendSection: some View {
        SettingsSectionCard(title: "Auto-Recovery", eyebrow: "Last 7 Days") {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                if trendCriterionFires {
                    HStack(spacing: AppSpacing.xSmall) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppColor.Brand.primary)
                        Text("Auto-recovery is eligible — your recent acceptance rate cleared the 50% threshold.")
                            .font(AppText.body)
                            .foregroundStyle(AppColor.Text.primary)
                    }
                    Text("The next AI recommendation that includes this signal will un-suppress it automatically for 14 days. You can also un-suppress it now below.")
                        .font(AppText.caption)
                        .foregroundStyle(AppColor.Text.secondary)
                } else {
                    HStack(spacing: AppSpacing.xSmall) {
                        Image(systemName: "clock")
                            .foregroundStyle(AppColor.Text.secondary)
                        Text("Auto-recovery isn't eligible yet.")
                            .font(AppText.body)
                            .foregroundStyle(AppColor.Text.primary)
                    }
                    Text(daysSinceLast == Int.max
                         ? "No dismissals recorded for this signal."
                         : "Last dismissal was \(daysSinceLast) day\(daysSinceLast == 1 ? "" : "s") ago. Accept 3+ recommendations with this signal in 7 days (≥50% rate) to enable auto-recovery, or use the controls below.")
                        .font(AppText.caption)
                        .foregroundStyle(AppColor.Text.secondary)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var actionsSection: some View {
        SettingsSectionCard(title: "Controls", eyebrow: "Override") {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                Button {
                    showUnsuppressConfirm = true
                } label: {
                    HStack {
                        Image(systemName: "arrow.uturn.left")
                        Text("Un-suppress for 14 days")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Un-suppress \(signal) for 14 days")
                .confirmationDialog(
                    "Un-suppress this signal?",
                    isPresented: $showUnsuppressConfirm,
                    titleVisibility: .visible
                ) {
                    Button("Un-suppress for 14 days") {
                        feedbackController.recordManualUnsuppression(
                            signal: signal, in: segment, viaTrend: trendCriterionFires)
                        analytics.logHomeAiFeedbackSignalManuallyUnsuppressed(
                            segment: segment.rawValue, signal: signal, viaTrend: trendCriterionFires)
                        dismiss()
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("The AI will stop downgrading recommendations that include this signal for the next 14 days. After that, the normal reinforcement rule applies again.")
                }

                Button(role: .destructive) {
                    showBlacklistConfirm = true
                } label: {
                    HStack {
                        Image(systemName: "nosign")
                        Text("Blacklist permanently")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Blacklist \(signal) permanently")
                .confirmationDialog(
                    "Blacklist this signal permanently?",
                    isPresented: $showBlacklistConfirm,
                    titleVisibility: .visible
                ) {
                    Button("Blacklist permanently", role: .destructive) {
                        feedbackController.recordBlacklist(
                            signal: signal, in: segment, dismissalCount: dismissalCount)
                        analytics.logHomeAiFeedbackSignalBlacklistedPermanently(
                            segment: segment.rawValue, signal: signal, dismissalCount: dismissalCount)
                        dismiss()
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("Future AI recommendations involving this signal will always be downgraded for \(segment.rawValue.capitalized). To revoke this, clear your feedback history in Settings.")
                }
            }
        }
    }
}
