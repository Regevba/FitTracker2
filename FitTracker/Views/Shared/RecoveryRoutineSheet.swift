// FitTracker/Views/Shared/RecoveryRoutineSheet.swift
// Extracted from MainScreenView.swift (v1) during Home v2 refactor.
// Used by: v2/MainScreenView.

import SwiftUI

struct RecoveryRoutineSheet: View {
    let routine: RecoveryRoutine
    let reasons: [String]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {
                            Text(routine.title)
                                .font(AppText.metric)
                            Text(routine.subtitle)
                                .font(AppText.body)
                                .foregroundStyle(AppColor.Text.secondary)
                        }
                        Spacer()
                        Text("\(routine.durationMinutes)m")
                            .font(.system(.title2, design: .monospaced, weight: .bold))
                            .foregroundStyle(Color.accentColor)
                    }

                    HStack(spacing: AppSpacing.xxSmall) {
                        RecoveryMetaPill(label: routine.intensityLabel, icon: "dial.low")
                        RecoveryMetaPill(label: routine.focus, icon: routine.icon)
                    }
                }

                if !reasons.isEmpty {
                    VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {
                        Text("Why today")
                            .font(AppText.sectionTitle)
                        ForEach(reasons, id: \.self) { reason in
                            HStack(alignment: .top, spacing: AppSpacing.xxSmall) {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(Color.accentColor)
                                    .padding(.top, 2)
                                Text(reason)
                                    .font(AppText.subheading)
                                    .foregroundStyle(AppColor.Text.secondary)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                    Text("Flow")
                        .font(AppText.sectionTitle)
                    ForEach(Array(routine.steps.enumerated()), id: \.element.id) { index, step in
                        HStack(alignment: .top, spacing: AppSpacing.xSmall) {
                            ZStack {
                                Circle()
                                    .fill(Color.accentColor.opacity(0.14))
                                    .frame(width: 30, height: 30)
                                Text("\(index + 1)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.accentColor)
                            }

                            VStack(alignment: .leading, spacing: AppSpacing.xxxSmall) {
                                HStack {
                                    Text(step.title)
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                    Text("\(step.minutes) min")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(AppColor.Text.secondary)
                                }
                                Text(step.detail)
                                    .font(AppText.subheading)
                                    .foregroundStyle(AppColor.Text.secondary)
                            }
                        }
                        .padding(AppSpacing.xSmall)
                        .background(AppColor.Surface.materialLight, in: RoundedRectangle(cornerRadius: AppRadius.medium))
                    }
                }

                VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {
                    Text("Coaching note")
                        .font(AppText.sectionTitle)
                    Text(routine.coachingNote)
                        .font(AppText.subheading)
                        .foregroundStyle(AppColor.Text.secondary)
                }
                .padding(AppSpacing.small)
                .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: AppRadius.button))
            }
            .padding(AppSpacing.medium)
        }
        .navigationTitle("Recovery Flow")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}

private struct RecoveryMetaPill: View {
    let label: String
    let icon: String

    var body: some View {
        HStack(spacing: AppSpacing.xxSmall) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
            Text(label)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
        .foregroundStyle(Color.accentColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color.accentColor.opacity(0.1), in: Capsule())
    }
}
