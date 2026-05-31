// FitTracker/Views/Settings/v2/Components/ImportedPlanRow.swift
// Bespoke list row for the Imported Plans List screen (T13 of import-training-
// plan resume, 2026-05-06). Mirrors `SettingsActionLabel` visual conventions
// (26pt rounded-square icon, AppText.button title, AppText.subheading subtitle,
// chevron trailing) but adds an inline ACTIVE pill slot that
// `SettingsActionLabel` cannot host.
//
// Documented in `docs/design-system/feature-memory.md` per the design-system
// evolution rule. First list-of-items row in Settings v2.

import SwiftUI

struct ImportedPlanRow: View {
    let plan: ImportedTrainingPlan

    // L353 Phase 1 (2026-05-31): scale the icon-container frame with Dynamic Type
    // so a user at AX5 settings gets a proportionally larger icon, not the
    // captionStrong-sized symbol clipped to a 26pt box.
    @ScaledMetric private var iconBox: CGFloat = 26

    var body: some View {
        HStack(spacing: AppSpacing.xSmall) {
            Image(systemName: plan.source.iconName)
                .font(AppText.captionStrong)
                .foregroundStyle(AppColor.Accent.primary)
                .frame(width: iconBox, height: iconBox)
                .background(AppColor.Accent.primary.opacity(0.14),
                            in: RoundedRectangle(cornerRadius: AppRadius.xSmall))

            VStack(alignment: .leading, spacing: AppSpacing.micro) {
                HStack(spacing: AppSpacing.xxSmall) {
                    Text(plan.name)
                        .font(AppText.button)
                        .foregroundStyle(AppColor.Text.primary)
                        .lineLimit(1)
                    if plan.isActive {
                        Text("ACTIVE")
                            .font(AppText.monoCaption)
                            .foregroundStyle(AppColor.Text.inversePrimary)
                            .padding(.horizontal, AppSpacing.xxSmall)
                            .padding(.vertical, AppSpacing.micro)
                            .background(AppColor.Status.success, in: Capsule())
                            .accessibilityHint("Currently active training plan")
                    }
                }
                Text(subtitle)
                    .font(AppText.subheading)
                    .foregroundStyle(AppColor.Text.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(AppText.captionStrong)
                .foregroundStyle(AppColor.Text.tertiary)
        }
        .padding(.vertical, AppSpacing.xxxSmall)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabelText)
    }

    private var subtitle: String {
        let days = plan.days.count
        let exercises = plan.days.reduce(0) { $0 + $1.exercises.count }
        let dayWord = days == 1 ? "day" : "days"
        let exWord = exercises == 1 ? "exercise" : "exercises"
        return "\(days) \(dayWord) · \(exercises) \(exWord) · \(Self.relativeDate(plan.lastModified)) · \(plan.source.displayLabel)"
    }

    private var accessibilityLabelText: String {
        let active = plan.isActive ? ", active" : ""
        return "\(plan.name), \(plan.source.displayLabel), \(subtitle)\(active)"
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    private static func relativeDate(_ date: Date) -> String {
        relativeFormatter.localizedString(for: date, relativeTo: Date())
    }
}
