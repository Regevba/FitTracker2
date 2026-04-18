import Foundation

enum AISnapshotBuilder {

    /// Build a LocalUserSnapshot using the adapter registry. Each adapter
    /// contributes its disjoint set of fields to the snapshot.
    ///
    /// Returns both the snapshot AND the adapter list so callers can wire the
    /// adapters into `AIOrchestrator.setAdapters(_:)` for downstream
    /// validation/evidence-chain use (audit DEEP-AI-007). Previously the
    /// adapter array was constructed here and silently discarded, leaving
    /// `AIOrchestrator.lastAdapters` permanently empty.
    static func build(
        profile: UserProfile,
        preferences: UserPreferences,
        liveMetrics: LiveMetrics,
        dailyLogs: [DailyLog],
        todayDayType: DayType,
        now: Date = Date(),
        readiness: ReadinessResult? = nil
    ) -> (snapshot: LocalUserSnapshot, adapters: [any AIInputAdapter]) {
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

        // DEEP-AI-010: assert adapter sourceID disjointness in debug builds.
        // Two adapters writing the same source ID would silently overwrite each
        // other's contributions and corrupt validation evidence chains.
        #if DEBUG
        let ids = adapters.map(\.sourceID)
        assert(Set(ids).count == ids.count,
               "AIInputAdapter sourceIDs must be unique, got: \(ids)")
        #endif

        var snapshot = LocalUserSnapshot()
        for adapter in adapters {
            adapter.contribute(to: &snapshot)
        }
        return (snapshot, adapters)
    }
}
