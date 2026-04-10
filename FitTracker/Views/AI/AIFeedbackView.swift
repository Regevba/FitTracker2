// FitTracker/Views/AI/AIFeedbackView.swift
// Thumbs-up / thumbs-down feedback row for AI recommendations.

import SwiftUI

struct AIFeedbackView: View {
    @EnvironmentObject private var analytics: AnalyticsService
    @State private var submitted = false

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
                    } label: {
                        Image(systemName: "hand.thumbsup.fill")
                            .foregroundStyle(AppColor.Status.success)
                            .frame(width: 44, height: 44)
                    }

                    Button {
                        withAnimation(AppMotion.quickInteraction) { submitted = true }
                        analytics.logAiFeedbackSubmitted(segment: "all", rating: "negative")
                    } label: {
                        Image(systemName: "hand.thumbsdown.fill")
                            .foregroundStyle(AppColor.Status.warning)
                            .frame(width: 44, height: 44)
                    }
                }
            }
        }
        .padding(AppSpacing.medium)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Feedback section")
    }
}
