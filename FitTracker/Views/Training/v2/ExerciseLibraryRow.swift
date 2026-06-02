// Views/Training/v2/ExerciseLibraryRow.swift
// C3 exercise-search-filter (2026-06-02)
//
// Single result row in the Exercise Library list. Shows name + a compact
// metadata line (muscle · equipment · sets×reps).
//
// Tappable — the parent (ExerciseLibraryView) decides whether the tap pushes
// the detail view (read-only mode) or fires the picker callback (C6 mode).

import SwiftUI

struct ExerciseLibraryRow: View {
    let exercise: ExerciseDefinition
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppSpacing.small) {
                VStack(alignment: .leading, spacing: AppSpacing.micro) {
                    Text(exercise.name)
                        .font(AppText.body)
                        .foregroundStyle(AppColor.Text.primary)
                        .multilineTextAlignment(.leading)
                    metadataLine
                }
                Spacer(minLength: AppSpacing.xSmall)
                Image(systemName: AppIcon.forward)
                    .font(AppText.caption)
                    .foregroundStyle(AppColor.Text.secondary)
            }
            .padding(.vertical, AppSpacing.xSmall)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var metadataLine: some View {
        HStack(spacing: AppSpacing.xSmall) {
            Text(primaryMuscleLabel)
            Text("·")
            Text(equipmentLabel)
            Text("·")
            Text("\(exercise.targetSets)×\(exercise.targetReps)")
        }
        .font(AppText.caption)
        .foregroundStyle(AppColor.Text.secondary)
        .lineLimit(1)
    }

    private var primaryMuscleLabel: String {
        exercise.muscleGroups.first.map { $0.rawValue.capitalized } ?? "—"
    }

    private var equipmentLabel: String {
        exercise.equipment.rawValue.capitalized
    }

    private var accessibilityLabel: String {
        "\(exercise.name), \(primaryMuscleLabel), \(equipmentLabel), \(exercise.targetSets) sets of \(exercise.targetReps)"
    }
}
