// AI/Adapters/NutritionAdapter.swift
// Contributes nutrition fields from DailyLog nutrition data + UserProfile nutrition plan.

import Foundation

struct NutritionAdapter: AIInputAdapter {
    let sourceID = "nutrition"

    private let latestLog: DailyLog?
    private let goalPlan: NutritionGoalPlan
    private let liveMetrics: LiveMetrics
    private let profile: UserProfile

    var lastUpdated: Date? { latestLog?.date }

    init(latestLog: DailyLog?, goalPlan: NutritionGoalPlan, liveMetrics: LiveMetrics, profile: UserProfile) {
        self.latestLog = latestLog
        self.goalPlan = goalPlan
        self.liveMetrics = liveMetrics
        self.profile = profile
    }

    func contribute(to snapshot: inout LocalUserSnapshot) {
        let latestNutrition = latestLog?.nutritionLog

        snapshot.caloricBalanceDelta = Self.caloricBalanceDelta(
            actualCalories: latestNutrition?.resolvedCalories,
            targetCalories: goalPlan.calories
        )
        snapshot.dailyProteinGrams = latestNutrition?.resolvedProteinG
        snapshot.proteinTargetGrams = goalPlan.proteinG
        // Audit AI-010: count only `.completed` meal entries — never planned-
        // but-uneaten meals. Returns nil rather than 0 so the orchestrator
        // surfaces "no meals logged today" instead of "user ate 0 meals".
        let completedMealCount = latestNutrition?.meals.filter { $0.status == .completed }.count
        snapshot.mealsPerDay = (completedMealCount ?? 0) > 0 ? completedMealCount : nil
    }

    private static func caloricBalanceDelta(actualCalories: Double?, targetCalories: Double) -> Int? {
        guard let actualCalories else { return nil }
        return Int(actualCalories.rounded() - targetCalories.rounded())
    }
}
