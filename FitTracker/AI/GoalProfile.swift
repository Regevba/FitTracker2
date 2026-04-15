// AI/GoalProfile.swift
// Maps each NutritionGoalMode to prioritized metric drivers and messaging emphasis.
// The AI engine uses this to weight recommendations by what matters for the user's goal.

import Foundation

// MARK: - MetricDriver

struct MetricDriver: Sendable {
    enum Direction: String, Sendable {
        case lower      // deficit, reduced intake
        case higher     // surplus, increased intake
        case maintain   // stay within range
    }

    let metric: String        // "caloric_balance", "protein_adequacy", etc.
    let direction: Direction
    let weight: Double        // 0-1, relative importance for this goal
    let explanation: String   // human-readable: "caloric deficit is the #1 driver of fat loss"
}

// MARK: - GoalProfile

struct GoalProfile: Sendable {
    let goal: NutritionGoalMode
    let primaryDrivers: [MetricDriver]
    let secondaryDrivers: [MetricDriver]
    let messagingEmphasis: [AISegment: String]

    /// Factory: resolve the correct profile for a goal mode.
    static func forGoal(_ goal: NutritionGoalMode) -> GoalProfile {
        switch goal {
        case .fatLoss:  return .fatLoss
        case .gain:     return .muscleGain
        case .maintain: return .maintenance
        }
    }
}

// MARK: - Goal Definitions

extension GoalProfile {

    static let fatLoss = GoalProfile(
        goal: .fatLoss,
        primaryDrivers: [
            MetricDriver(
                metric: "caloric_balance",
                direction: .lower,
                weight: 0.40,
                explanation: "Caloric deficit is the #1 driver of fat loss — you must consume less energy than you expend."
            ),
            MetricDriver(
                metric: "protein_adequacy",
                direction: .higher,
                weight: 0.25,
                explanation: "High protein (≥ target) preserves lean mass during a deficit and increases satiety."
            ),
        ],
        secondaryDrivers: [
            MetricDriver(
                metric: "macro_split",
                direction: .maintain,
                weight: 0.15,
                explanation: "Balanced carb/fat ratio supports hormonal health and training performance in a deficit."
            ),
            MetricDriver(
                metric: "training_volume",
                direction: .maintain,
                weight: 0.10,
                explanation: "Strength training during fat loss signals the body to preserve muscle tissue."
            ),
            MetricDriver(
                metric: "sleep_quality",
                direction: .higher,
                weight: 0.10,
                explanation: "Poor sleep raises cortisol, which promotes fat retention and muscle breakdown."
            ),
        ],
        messagingEmphasis: [
            .nutrition: "Focus on your deficit target and protein intake — these are the two levers that drive fat loss while preserving muscle.",
            .training: "Strength work during a deficit tells your body to keep muscle. Maintain volume, don't chase PRs.",
            .recovery: "Sleep and stress management are force multipliers — poor sleep raises cortisol which fights fat loss.",
            .stats: "Track body composition trends, not just scale weight. Fat loss with stable lean mass is the goal.",
        ]
    )

    static let muscleGain = GoalProfile(
        goal: .gain,
        primaryDrivers: [
            MetricDriver(
                metric: "caloric_balance",
                direction: .higher,
                weight: 0.30,
                explanation: "A caloric surplus provides the energy substrate for new muscle tissue synthesis."
            ),
            MetricDriver(
                metric: "protein_adequacy",
                direction: .higher,
                weight: 0.30,
                explanation: "Protein ≥1.6g/kg is the building material — without it, surplus calories become fat, not muscle."
            ),
        ],
        secondaryDrivers: [
            MetricDriver(
                metric: "training_progressive_overload",
                direction: .higher,
                weight: 0.20,
                explanation: "Progressive overload is the stimulus. Without increasing volume or load, surplus has nothing to build."
            ),
            MetricDriver(
                metric: "carb_timing",
                direction: .maintain,
                weight: 0.10,
                explanation: "Carbs around training replenish glycogen and support performance in the next session."
            ),
            MetricDriver(
                metric: "recovery_quality",
                direction: .higher,
                weight: 0.10,
                explanation: "Muscle grows during rest, not during training. Recovery quality determines adaptation rate."
            ),
        ],
        messagingEmphasis: [
            .nutrition: "You need a surplus to grow. Hit your calorie target and prioritize protein — these fuel muscle synthesis.",
            .training: "Progressive overload is the growth signal. Your surplus fuels the adaptation — keep pushing volume.",
            .recovery: "Muscle grows during rest, not during training. Prioritize sleep and manage training frequency.",
            .stats: "Track strength progression and body weight trend. Lean gain means slow, consistent weight increase.",
        ]
    )

    static let maintenance = GoalProfile(
        goal: .maintain,
        primaryDrivers: [
            MetricDriver(
                metric: "caloric_balance",
                direction: .maintain,
                weight: 0.30,
                explanation: "Staying within ±100 kcal of your target maintains current body composition."
            ),
            MetricDriver(
                metric: "workout_consistency",
                direction: .maintain,
                weight: 0.25,
                explanation: "Consistency matters more than intensity at maintenance — show up regularly."
            ),
        ],
        secondaryDrivers: [
            MetricDriver(
                metric: "protein_adequacy",
                direction: .maintain,
                weight: 0.20,
                explanation: "Adequate protein maintains lean mass even without a growth stimulus."
            ),
            MetricDriver(
                metric: "recovery_stability",
                direction: .maintain,
                weight: 0.15,
                explanation: "Stable HRV and RHR trends indicate your body is well-adapted to current load."
            ),
            MetricDriver(
                metric: "macro_variety",
                direction: .maintain,
                weight: 0.10,
                explanation: "Balanced macro intake supports long-term health and prevents micronutrient gaps."
            ),
        ],
        messagingEmphasis: [
            .nutrition: "You're in maintenance — keep calories steady and protein adequate. No need to push surplus or deficit.",
            .training: "Consistency beats intensity at maintenance. Regular sessions maintain your fitness base.",
            .recovery: "Stable biometrics mean your body is well-adapted. Watch for drift, not spikes.",
            .stats: "Flat trends are the goal. Body comp, strength, and biometrics should hold steady.",
        ]
    )
}
