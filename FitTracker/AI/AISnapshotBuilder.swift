import Foundation

enum AISnapshotBuilder {

    /// Build a LocalUserSnapshot using the adapter registry.
    /// Each adapter contributes its disjoint set of fields to the snapshot.
    static func build(
        profile: UserProfile,
        preferences: UserPreferences,
        liveMetrics: LiveMetrics,
        dailyLogs: [DailyLog],
        todayDayType: DayType,
        now: Date = Date(),
        readiness: ReadinessResult? = nil
    ) -> LocalUserSnapshot {
        let sortedLogs = dailyLogs
            .filter { $0.date <= now }
            .sorted { $0.date > $1.date }

        let currentWeight = liveMetrics.weightKg
            ?? sortedLogs.first?.biometrics.weightKg
            ?? profile.startWeightKg
        let currentBodyFat = liveMetrics.bodyFatPct.map { $0 * 100 }
            ?? sortedLogs.first?.biometrics.bodyFatPercent
            ?? profile.startBodyFatPct
        let goalPlan = profile.nutritionPlan(
            currentWeightKg: currentWeight,
            currentBodyFatPercent: currentBodyFat,
            isTrainingDay: todayDayType.isTrainingDay,
            preferences: preferences
        )

        let adapters: [any AIInputAdapter] = [
            ProfileAdapter(profile: profile, preferences: preferences, todayDayType: todayDayType),
            HealthKitAdapter(liveMetrics: liveMetrics, recentLogs: sortedLogs, profile: profile, readiness: readiness),
            TrainingAdapter(recentLogs: sortedLogs, todayDayType: todayDayType),
            NutritionAdapter(latestLog: sortedLogs.first, goalPlan: goalPlan, liveMetrics: liveMetrics, profile: profile),
        ]

        var snapshot = LocalUserSnapshot()
        for adapter in adapters {
            adapter.contribute(to: &snapshot)
        }
        return snapshot
    }
}
