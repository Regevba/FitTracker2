// FitTracker/Views/AI/AIFeedbackView.swift
// Thumbs-up / thumbs-down feedback row for AI recommendations.
//
// C5 ai-user-feedback-loop (2026-06-01) — thumbs-down now surfaces
// DismissReasonPicker (5 enum + 80-char free-text). Picked reason flows into
// feedbackController.record() so the on-device reinforcement loop can weight
// suppression smarter (e.g., `already_aware` is less negative than `disagree`).

import SwiftUI

struct AIFeedbackView: View {
    @EnvironmentObject private var analytics: AnalyticsService
    @EnvironmentObject private var feedbackController: RecommendationFeedbackController
    @State private var submitted = false
    @State private var showDismissReasonPicker = false

    var body: some View {
        VStack(spacing: AppSpacing.small) {
            if submitted {
                HStack(spacing: AppSpacing.xSmall) {
                    Image(systemName: AppIcon.checkmarkCircle)
                        .foregroundStyle(AppColor.Status.success)
                    Text("Thanks for the feedback!")
                        .font(AppText.caption)
                        .foregroundStyle(AppColor.Text.secondary)
                }
                .transition(.opacity)
            } else {
                HStack(spacing: AppSpacing.medium) {
                    Text("Was this helpful?")
                        .font(AppText.caption)
                        .foregroundStyle(AppColor.Text.secondary)

                    Button {
                        withAnimation(AppMotion.quickInteraction) { submitted = true }
                        analytics.logAiFeedbackSubmitted(segment: "all", rating: "positive")
                        feedbackController.record(outcome: RecommendationOutcome(
                            segment: "all",
                            signals: [],
                            confidenceLevel: "unknown",
                            source: "sheet",
                            action: .accepted,
                            dismissReason: nil
                        ))
                    } label: {
                        Image(systemName: AppIcon.thumbsUp)
                            .foregroundStyle(AppColor.Status.success)
                            .frame(width: AppSize.tapTarget, height: AppSize.tapTarget)
                    }
                    .accessibilityLabel("Helpful")

                    Button {
                        // Show the dismiss-reason picker; record happens once a reason is picked
                        // (or once Cancel is tapped — same as today's "negative" rating fires).
                        showDismissReasonPicker = true
                    } label: {
                        Image(systemName: AppIcon.thumbsDown)
                            .foregroundStyle(AppColor.Status.warning)
                            .frame(width: AppSize.tapTarget, height: AppSize.tapTarget)
                    }
                    .accessibilityLabel("Not helpful")
                }
            }
        }
        .padding(AppSpacing.medium)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Feedback section")
        .modifier(DismissReasonPicker(isPresented: $showDismissReasonPicker) { reason in
            withAnimation(AppMotion.quickInteraction) { submitted = true }
            analytics.logAiFeedbackSubmitted(segment: "all", rating: "negative")
            feedbackController.record(outcome: RecommendationOutcome(
                segment: "all",
                signals: [],
                confidenceLevel: "unknown",
                source: "sheet",
                action: .dismissed,
                dismissReason: reason
            ))
        })
    }
}
