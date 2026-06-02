// Views/Training/v2/ExerciseDetailView.swift
// C3 exercise-search-filter (2026-06-02)
//
// Push-navigation detail view for a single exercise. Read-only — no "add
// to plan" affordance (C6 surface). Surfaces:
//   - Full name + day-type chip
//   - Sets × reps × rest (large + readable header)
//   - Coaching cue paragraph
//   - Progression note (if non-empty)
//   - Muscle + equipment badges

import SwiftUI

struct ExerciseDetailView: View {
    let exercise: ExerciseDefinition

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                header
                coachingCueSection
                if !exercise.progressionNote.isEmpty {
                    progressionSection
                }
                badgesSection
            }
            .padding(AppSpacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(AppGradient.screenBackground.ignoresSafeArea())
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            HStack(spacing: AppSpacing.xSmall) {
                Text(exercise.dayType.rawValue)
                    .font(AppText.caption)
                    .foregroundStyle(AppColor.Text.secondary)
                    .padding(.horizontal, AppSpacing.small)
                    .padding(.vertical, AppSpacing.micro)
                    .background(
                        Capsule().fill(AppColor.Surface.tertiary)
                    )
                Text(exercise.category.rawValue.capitalized)
                    .font(AppText.caption)
                    .foregroundStyle(AppColor.Text.secondary)
                    .padding(.horizontal, AppSpacing.small)
                    .padding(.vertical, AppSpacing.micro)
                    .background(
                        Capsule().fill(AppColor.Surface.tertiary)
                    )
            }

            HStack(spacing: AppSpacing.large) {
                statColumn(label: "Sets", value: "\(exercise.targetSets)")
                statColumn(label: "Reps", value: exercise.targetReps)
                statColumn(label: "Rest", value: exercise.restSeconds > 0 ? "\(exercise.restSeconds)s" : "—")
            }
            .padding(AppSpacing.medium)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .fill(AppColor.Surface.secondary)
            )
        }
    }

    private func statColumn(label: String, value: String) -> some View {
        VStack(spacing: AppSpacing.micro) {
            Text(value)
                .font(AppText.titleMedium)
                .foregroundStyle(AppColor.Text.primary)
            Text(label)
                .font(AppText.caption)
                .foregroundStyle(AppColor.Text.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var coachingCueSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Text("Coaching Cue")
                .font(AppText.caption)
                .foregroundStyle(AppColor.Text.secondary)
                .textCase(.uppercase)
            Text(exercise.coachingCue)
                .font(AppText.body)
                .foregroundStyle(AppColor.Text.primary)
        }
    }

    private var progressionSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Text("Progression")
                .font(AppText.caption)
                .foregroundStyle(AppColor.Text.secondary)
                .textCase(.uppercase)
            Text(exercise.progressionNote)
                .font(AppText.body)
                .foregroundStyle(AppColor.Text.primary)
        }
    }

    private var badgesSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Text("Targets")
                .font(AppText.caption)
                .foregroundStyle(AppColor.Text.secondary)
                .textCase(.uppercase)
            FlowLayout(spacing: AppSpacing.xSmall) {
                ForEach(exercise.muscleGroups, id: \.rawValue) { muscle in
                    badge(text: muscle.rawValue.capitalized)
                }
                badge(text: exercise.equipment.rawValue.capitalized)
            }
        }
    }

    private func badge(text: String) -> some View {
        Text(text)
            .font(AppText.caption)
            .foregroundStyle(AppColor.Text.primary)
            .padding(.horizontal, AppSpacing.small)
            .padding(.vertical, AppSpacing.micro)
            .background(
                Capsule().fill(AppColor.Surface.secondary)
            )
    }
}

// MARK: - FlowLayout (lightweight wrap for badges)

private struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var width: CGFloat = 0
        var height: CGFloat = 0
        var rowHeight: CGFloat = 0
        var x: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth {
                width = max(width, x)
                height += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        width = max(width, x)
        height += rowHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
