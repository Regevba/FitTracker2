// FitTracker/Views/Shared/SyncStatusIndicator.swift
// Extracted from MainScreenView.swift (v1) during Home v2 refactor.
// Used by: v2/MainScreenView toolbar.

import SwiftUI

struct SyncStatusIndicator: View {
    @EnvironmentObject var watchService: WatchConnectivityService
    var body: some View {
        HStack(spacing: AppSpacing.xxxSmall) {
            Circle()
                .fill(watchService.status.dotColor)
                .frame(width: AppSize.indicatorDotTiny, height: AppSize.indicatorDotTiny)
            Text(watchService.status.label)
                .font(AppText.captionMicroMedium)
                .foregroundStyle(AppColor.Text.secondary)
        }
        .padding(.horizontal, AppSpacing.xSmall)
        .padding(.vertical, AppSpacing.xxSmall)
        .background(
            Capsule()
                .fill(AppColor.Surface.materialStrong)
                .overlay(
                    Capsule()
                        .stroke(AppColor.Surface.tertiary, lineWidth: 1)
                )
        )
        .shadow(color: AppShadow.cardColor, radius: 10, y: 5)
        .tint(.clear)
    }
}
