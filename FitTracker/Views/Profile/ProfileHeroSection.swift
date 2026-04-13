import SwiftUI

struct ProfileHeroSection: View {
    let displayName: String
    let email: String?
    let fitnessGoal: FitnessGoal?
    let programPhase: ProgramPhase
    let daysSinceStart: Int
    let streakDays: Int
    let totalWorkouts: Int
    let onGoalTap: () -> Void
    let onAvatarTap: () -> Void

    var body: some View {
        VStack(spacing: AppSpacing.medium) {
            // Avatar + name row
            HStack(spacing: AppSpacing.medium) {
                // Avatar circle
                Button(action: onAvatarTap) {
                    ZStack {
                        Circle()
                            .fill(AppColor.Brand.primary)
                            .frame(width: 64, height: 64)
                        Text(initials)
                            .font(AppText.sectionTitle)
                            .foregroundStyle(.white)
                    }
                }
                .accessibilityLabel("Profile picture, \(displayName)")

                VStack(alignment: .leading, spacing: AppSpacing.xxxSmall) {
                    Text(displayName)
                        .font(AppText.sectionTitle)
                        .foregroundStyle(AppColor.Text.primary)

                    if let email {
                        Text(email)
                            .font(AppText.caption)
                            .foregroundStyle(AppColor.Text.secondary)
                    }

                    // Badges row
                    HStack(spacing: AppSpacing.xSmall) {
                        if let goal = fitnessGoal {
                            Button(action: onGoalTap) {
                                Text(goal.rawValue)
                                    .font(AppText.caption)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, AppSpacing.small)
                                    .padding(.vertical, AppSpacing.xxxSmall)
                                    .background(AppColor.Accent.primary, in: Capsule())
                            }
                            .accessibilityLabel("Fitness goal: \(goal.rawValue)")
                            .accessibilityHint("Double tap to edit goal")
                        }

                        Text(programPhase.rawValue)
                            .font(AppText.caption)
                            .foregroundStyle(AppColor.Text.tertiary)
                            .padding(.horizontal, AppSpacing.small)
                            .padding(.vertical, AppSpacing.xxxSmall)
                            .background(AppColor.Surface.secondary, in: Capsule())
                            .accessibilityLabel("Program phase: \(programPhase.rawValue)")
                    }
                }

                Spacer(minLength: 0)
            }

            // Stat row
            HStack(spacing: AppSpacing.xSmall) {
                Text("Day \(daysSinceStart)")
                Text("·")
                Text("\(streakDays)-day streak")
                Text("·")
                Text("\(totalWorkouts) workouts")
            }
            .font(AppText.caption)
            .foregroundStyle(AppColor.Text.tertiary)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Day \(daysSinceStart). \(streakDays)-day streak. \(totalWorkouts) total workouts.")
        }
        .padding(AppSpacing.medium)
        .background(AppColor.Surface.primary, in: RoundedRectangle(cornerRadius: AppRadius.card))
    }

    private var initials: String {
        let parts = displayName.split(separator: " ")
        let first = parts.first?.prefix(1) ?? "F"
        let last = parts.count > 1 ? parts.last?.prefix(1) ?? "" : ""
        return "\(first)\(last)".uppercased()
    }
}
