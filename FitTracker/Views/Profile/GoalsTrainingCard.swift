// FitTracker/Views/Profile/GoalsTrainingCard.swift
import SwiftUI

struct GoalsTrainingCard: View {
    let fitnessGoal: FitnessGoal?
    let targetWeightMin: Double
    let targetWeightMax: Double
    let trainingDaysPerWeek: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppSpacing.small) {
                Image(systemName: "target")
                    .font(AppText.titleMedium)
                    .foregroundStyle(AppColor.Accent.achievement)
                    .frame(width: 36, height: 36)
                    .background(AppColor.Accent.achievement.opacity(0.12), in: RoundedRectangle(cornerRadius: AppRadius.small))

                VStack(alignment: .leading, spacing: AppSpacing.micro) {
                    Text("Goals & Training")
                        .font(AppText.callout)
                        .foregroundStyle(AppColor.Text.primary)
                    Text(summaryLine)
                        .font(AppText.caption)
                        .foregroundStyle(AppColor.Text.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(AppText.caption)
                    .foregroundStyle(AppColor.Text.tertiary)
            }
            .padding(AppSpacing.medium)
            .background(AppColor.Surface.primary, in: RoundedRectangle(cornerRadius: AppRadius.card))
            .shadow(color: AppShadow.cardColor, radius: AppShadow.cardRadius, y: AppShadow.cardYOffset)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Goals and Training")
        .accessibilityValue(summaryLine)
        .accessibilityHint("Double tap to edit")
    }

    private var summaryLine: String {
        let goal = fitnessGoal?.rawValue ?? "Not set"
        let weight = "\(Int(targetWeightMin))–\(Int(targetWeightMax)) kg"
        return "\(goal) · \(weight) · \(trainingDaysPerWeek) days/week"
    }
}
