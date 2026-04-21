// FitTracker/Views/Shared/MilestoneModal.swift
// Extracted from TrainingPlanView.swift (v1) during Training v2 refactor.
// Used by: v2/MainScreenView (Home milestones), v2/TrainingPlanView.

import SwiftUI

struct MilestoneModal: View {
    let title: String
    let message: String
    let onDismiss: () -> Void

    @State private var autoDismissTimer: Timer? = nil

    var body: some View {
        ZStack {
            AppColor.Surface.inverse.ignoresSafeArea()

            VStack(spacing: AppSpacing.medium) {
                Text("🎉")
                    .font(AppText.iconDisplay)

                Text(title)
                    .font(AppText.metric)
                    .foregroundStyle(AppColor.Text.inversePrimary)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(AppText.subheading)
                    .foregroundStyle(AppColor.Text.inverseSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.large)

                Button("Continue") {
                    autoDismissTimer?.invalidate()
                    onDismiss()
                }
                .font(AppText.sectionTitle)
                .padding(.horizontal, AppSpacing.xxLarge)
                .padding(.vertical, AppSpacing.xSmall)
                .background(AppColor.Surface.materialLight, in: RoundedRectangle(cornerRadius: AppRadius.large))
                .foregroundStyle(AppColor.Text.inversePrimary)
            }
            .padding(AppSpacing.xLarge)
        }
        .onAppear {
            autoDismissTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
                onDismiss()
            }
        }
        .onDisappear {
            autoDismissTimer?.invalidate()
        }
    }
}
