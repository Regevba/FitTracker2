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
                .frame(width: 6, height: 6)
            Text(watchService.status.label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(AppColor.Text.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
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
