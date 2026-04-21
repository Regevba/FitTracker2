import SwiftUI

struct ProfileHeroSection: View {
    let displayName: String
    let age: Int
    let heightCm: Double
    let experienceLevel: ExperienceLevel?
    let fitnessGoal: FitnessGoal?
    let programPhase: ProgramPhase
    let daysSinceStart: Int
    let onGoalTap: () -> Void
    let onAvatarTap: () -> Void

    var body: some View {
        VStack(spacing: AppSpacing.small) {
            // Avatar circle
            Button(action: onAvatarTap) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    AppColor.Accent.recovery.opacity(0.88),
                                    AppColor.Brand.secondary.opacity(0.72)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 72, height: 72)
                    Text(initials)
                        .font(AppText.titleStrong)
                        .foregroundStyle(AppColor.Text.inversePrimary)
                }
            }
            .accessibilityLabel("Profile picture, \(displayName)")

            // Name
            Text(displayName)
                .font(AppText.titleStrong)
                .foregroundStyle(AppColor.Text.primary)

            // Personal details line
            Text(personalDetailsLine)
                .font(AppText.caption)
                .foregroundStyle(AppColor.Text.secondary)

            // Badges row
            HStack(spacing: AppSpacing.xSmall) {
                if let goal = fitnessGoal {
                    Button(action: onGoalTap) {
                        Text(goal.rawValue)
                            .font(AppText.caption)
                            .foregroundStyle(AppColor.Text.inversePrimary)
                            .padding(.horizontal, AppSpacing.small)
                            .padding(.vertical, AppSpacing.xxxSmall)
                            .background(AppColor.Accent.primary, in: Capsule())
                    }
                    .accessibilityLabel("Fitness goal: \(goal.rawValue)")
                    .accessibilityHint("Double tap to edit goal")
                }

                Text("\(programPhase.rawValue) · Day \(daysSinceStart)")
                    .font(AppText.caption)
                    .foregroundStyle(AppColor.Text.tertiary)
                    .padding(.horizontal, AppSpacing.small)
                    .padding(.vertical, AppSpacing.xxxSmall)
                    .background(AppColor.Surface.secondary, in: Capsule())
                    .accessibilityLabel("Program phase: \(programPhase.rawValue), day \(daysSinceStart)")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.medium)
        .background(AppColor.Surface.primary, in: RoundedRectangle(cornerRadius: AppRadius.card))
    }

    private var personalDetailsLine: String {
        var parts: [String] = ["\(age)"]
        parts.append("\(Int(heightCm)) cm")
        if let exp = experienceLevel {
            parts.append(exp.rawValue)
        }
        return parts.joined(separator: " · ")
    }

    private var initials: String {
        let parts = displayName.split(separator: " ")
        let first = parts.first?.prefix(1) ?? "F"
        let last = parts.count > 1 ? parts.last?.prefix(1) ?? "" : ""
        return "\(first)\(last)".uppercased()
    }
}
