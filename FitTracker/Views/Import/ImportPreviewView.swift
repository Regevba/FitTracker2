import SwiftUI

struct ImportPreviewView: View {
    let plan: ImportedPlan
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                AppGradient.screenBackground.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.medium) {
                        // Summary
                        summaryBar

                        // Day cards
                        ForEach(plan.days.indices, id: \.self) { dayIndex in
                            dayCard(plan.days[dayIndex])
                        }
                    }
                    .padding(.horizontal, AppSpacing.medium)
                    .padding(.vertical, AppSpacing.small)
                }
            }
            .navigationTitle("Preview Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm & Import") { onConfirm() }
                        .font(AppText.button)
                        .foregroundStyle(AppColor.Status.success)
                }
            }
        }
    }

    private var summaryBar: some View {
        let exercises = plan.days.flatMap(\.exercises)
        let autoMatched = exercises.filter { ($0.mappingConfidence ?? 0) >= ExerciseMapper.autoAcceptThreshold }.count
        let needsReview = exercises.filter {
            let c = $0.mappingConfidence ?? 0
            return c >= ExerciseMapper.reviewThreshold && c < ExerciseMapper.autoAcceptThreshold
        }.count
        let unmatched = exercises.count - autoMatched - needsReview

        return HStack(spacing: AppSpacing.small) {
            Label("\(exercises.count) exercises", systemImage: "list.bullet")
            Spacer()
            if autoMatched > 0 {
                Label("\(autoMatched)", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(AppColor.Status.success)
            }
            if needsReview > 0 {
                Label("\(needsReview)", systemImage: "pencil.circle.fill")
                    .foregroundStyle(AppColor.Status.warning)
            }
            if unmatched > 0 {
                Label("\(unmatched)", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(AppColor.Status.error)
            }
        }
        .font(AppText.caption)
        .padding(AppSpacing.small)
        .background(AppColor.Surface.primary, in: RoundedRectangle(cornerRadius: AppRadius.medium))
    }

    private func dayCard(_ day: ImportedDay) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
            Text(day.name)
                .font(AppText.sectionTitle)
                .foregroundStyle(AppColor.Text.primary)

            ForEach(day.exercises.indices, id: \.self) { i in
                exerciseRow(day.exercises[i])
                if i < day.exercises.count - 1 {
                    Divider()
                }
            }
        }
        .padding(AppSpacing.small)
        .background(AppColor.Surface.primary, in: RoundedRectangle(cornerRadius: AppRadius.card))
    }

    private func exerciseRow(_ exercise: ImportedExercise) -> some View {
        HStack {
            // Confidence indicator
            confidenceIcon(exercise.mappingConfidence ?? 0)

            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.rawName)
                    .font(AppText.body)
                    .foregroundStyle(AppColor.Text.primary)
                if let mapped = exercise.mappedExerciseId {
                    Text("→ \(mapped.replacingOccurrences(of: "_", with: " ").capitalized)")
                        .font(AppText.caption)
                        .foregroundStyle(AppColor.Text.secondary)
                }
            }

            Spacer()

            Text("\(exercise.sets) × \(exercise.reps)")
                .font(AppText.monoCaption)
                .foregroundStyle(AppColor.Text.tertiary)
        }
    }

    private func confidenceIcon(_ confidence: Double) -> some View {
        Group {
            if confidence >= ExerciseMapper.autoAcceptThreshold {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AppColor.Status.success)
            } else if confidence >= ExerciseMapper.reviewThreshold {
                Image(systemName: "pencil.circle.fill")
                    .foregroundStyle(AppColor.Status.warning)
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(AppColor.Status.error)
            }
        }
        .font(AppText.body)
    }
}
