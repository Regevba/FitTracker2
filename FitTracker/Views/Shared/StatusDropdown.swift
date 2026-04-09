// FitTracker/Views/Shared/StatusDropdown.swift
// Extracted from TrainingPlanView.swift (v1) during Training v2 refactor.
// Used by: v2/TrainingPlanView, NutritionView.

import SwiftUI

struct StatusDropdown: View {
    let status:   TaskStatus
    let onSelect: (TaskStatus) -> Void

    var body: some View {
        Menu {
            Button { onSelect(.completed) } label: { Label("Completed", systemImage: "checkmark.circle.fill") }
            Button { onSelect(.partial)   } label: { Label("Partial",   systemImage: "circle.lefthalf.filled") }
            Button { onSelect(.missed)    } label: { Label("Missed",    systemImage: "xmark.circle.fill") }
            Divider()
            Button { onSelect(.pending)   } label: { Label("Reset",     systemImage: "arrow.counterclockwise") }
        } label: {
            HStack(spacing: AppSpacing.xxxSmall) {
                Circle().fill(color).frame(width: 6, height: 6)
                Text(status.rawValue.capitalized).font(AppText.caption)
                Image(systemName: "chevron.down").font(AppText.monoLabel)
            }
            .foregroundStyle(color)
            .padding(.horizontal, AppSpacing.xxSmall).padding(.vertical, AppSpacing.xxxSmall)
            .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: AppRadius.xSmall))
        }
    }

    private var color: Color {
        switch status {
        case .completed: AppColor.Status.success
        case .partial: AppColor.Status.warning
        case .missed: AppColor.Status.error
        case .pending: AppColor.Text.secondary
        }
    }
}
