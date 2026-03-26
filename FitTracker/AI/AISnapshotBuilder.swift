import Foundation

enum AISnapshotBuilder {
    static func build(
        profile: UserProfile,
        preferences: UserPreferences,
        liveMetrics: LiveMetrics,
        dailyLogs: [DailyLog],
        todayDayType: DayType,
        now: Date = Date()
    ) -> LocalUserSnapshot {
        let sortedLogs = dailyLogs
            .filter { $0.date <= now }
            .sorted { $0.date > $1.date }
        let recent7 = Array(sortedLogs.prefix(7))
        let recent14 = Array(sortedLogs.prefix(14))

        let latestLog = sortedLogs.first
        let currentWeight = liveMetrics.weightKg
            ?? latestLog?.biometrics.weightKg
            ?? profile.startWeightKg
        let currentBodyFat = liveMetrics.bodyFatPct.map { $0 * 100 }
            ?? latestLog?.biometrics.bodyFatPercent
            ?? profile.startBodyFatPct
        let goalPlan = profile.nutritionPlan(
            currentWeightKg: currentWeight,
            currentBodyFatPercent: currentBodyFat,
            isTrainingDay: todayDayType.isTrainingDay,
            preferences: preferences
        )

        var snapshot = LocalUserSnapshot()
        snapshot.ageYears = profile.age
        snapshot.genderIdentity = "prefer_not_to_say"
        snapshot.bmiValue = bmi(weightKg: currentWeight, heightCm: profile.heightCm)
        snapshot.activeWeeks = max(0, Int(ceil(Double(profile.daysSinceStart) / 7.0)))
        snapshot.programPhase = todayDayType.aiProgramPhase
        snapshot.trainingDaysPerWeek = DayType.allCases.filter(\.isTrainingDay).count
        snapshot.avgSessionMinutes = averageSessionMinutes(from: recent14, fallbackDayType: todayDayType)
        snapshot.primaryGoal = primaryGoal(for: preferences)

        let latestNutrition = latestLog?.nutritionLog
        snapshot.caloricBalanceDelta = caloricBalanceDelta(
            actualCalories: latestNutrition?.resolvedCalories,
            targetCalories: goalPlan.calories
        )
        snapshot.dailyProteinGrams = latestNutrition?.resolvedProteinG
        snapshot.proteinTargetGrams = goalPlan.proteinG
        snapshot.mealsPerDay = latestNutrition?.meals.filter { $0.status == .completed }.count
            ?? latestNutrition?.meals.count
        snapshot.dietPattern = "standard"

        snapshot.avgSleepHours = averageSleepHours(from: recent7, liveMetrics: liveMetrics)
        snapshot.sleepQuality = sleepQuality(for: snapshot.avgSleepHours)
        snapshot.restingHeartRate = restingHeartRate(from: recent7, liveMetrics: liveMetrics)
        snapshot.stressLevel = stressLevel(from: latestLog)

        let weeklySessions = recent7.filter { hasCompletedWorkout(in: $0) }.count
        snapshot.weeklySessionCount = weeklySessions
        snapshot.weeklyActiveMinutes = weeklyActiveMinutes(from: recent7)
        snapshot.avgDailySteps = averageDailySteps(from: recent7, liveMetrics: liveMetrics)
        snapshot.workoutConsistency = workoutConsistency(
            completedSessions: weeklySessions,
            scheduledSessions: snapshot.trainingDaysPerWeek ?? 0
        )

        return snapshot
    }

    private static func bmi(weightKg: Double?, heightCm: Double) -> Double? {
        guard let weightKg, heightCm > 0 else { return nil }
        let heightMeters = heightCm / 100
        return weightKg / (heightMeters * heightMeters)
    }

    private static func primaryGoal(for preferences: UserPreferences) -> String {
        switch preferences.nutritionGoalMode {
        case .fatLoss: return "weight_loss"
        case .maintain: return "maintenance"
        case .gain: return "muscle_gain"
        }
    }

    private static func caloricBalanceDelta(actualCalories: Double?, targetCalories: Double) -> Int? {
        guard let actualCalories else { return nil }
        return Int(actualCalories.rounded() - targetCalories.rounded())
    }

    private static func averageSessionMinutes(from logs: [DailyLog], fallbackDayType: DayType) -> Int? {
        let durations = logs.compactMap { log -> Int? in
            let cardioMinutes = Int(log.cardioLogs.values.compactMap(\.durationMinutes).reduce(0, +).rounded())
            let strengthMinutes = log.exerciseLogs.isEmpty ? 0 : max(20, log.exerciseLogs.count * 10)
            let estimated = cardioMinutes + strengthMinutes
            return estimated > 0 ? estimated : nil
        }
        if let average = durations.averageRounded {
            return average
        }
        return fallbackDayType.isTrainingDay ? 45 : 30
    }

    private static func averageSleepHours(from logs: [DailyLog], liveMetrics: LiveMetrics) -> Double? {
        let values = logs.compactMap { $0.biometrics.effectiveSleep }
        return values.average ?? liveMetrics.sleepHours
    }

    private static func restingHeartRate(from logs: [DailyLog], liveMetrics: LiveMetrics) -> Int? {
        let values = logs.compactMap { $0.biometrics.effectiveRestingHR }
        if let average = values.average {
            return Int(average.rounded())
        }
        if let restingHR = liveMetrics.restingHR {
            return Int(restingHR.rounded())
        }
        return nil
    }

    private static func stressLevel(from log: DailyLog?) -> String {
        guard let log else { return "moderate" }
        if let mood = log.mood, mood <= 2 { return "high" }
        if let energy = log.energyLevel, energy <= 2 { return "high" }
        if let craving = log.cravingLevel, craving >= 4 { return "high" }
        if let mood = log.mood, mood >= 4, let energy = log.energyLevel, energy >= 4 { return "low" }
        return "moderate"
    }

    private static func sleepQuality(for hours: Double?) -> String? {
        guard let hours else { return nil }
        switch hours {
        case ..<6: return "poor"
        case 6..<7.5: return "fair"
        default: return "good"
        }
    }

    private static func hasCompletedWorkout(in log: DailyLog) -> Bool {
        !log.exerciseLogs.isEmpty || log.cardioLogs.values.contains { ($0.durationMinutes ?? 0) > 0 }
    }

    private static func weeklyActiveMinutes(from logs: [DailyLog]) -> Int? {
        let total = logs.reduce(0.0) { partial, log in
            let cardioMinutes = log.cardioLogs.values.compactMap(\.durationMinutes).reduce(0, +)
            let strengthMinutes = Double(log.exerciseLogs.count * 10)
            return partial + cardioMinutes + strengthMinutes
        }
        guard total > 0 else { return nil }
        return Int(total.rounded())
    }

    private static func averageDailySteps(from logs: [DailyLog], liveMetrics: LiveMetrics) -> Int? {
        let values = logs.compactMap(\.biometrics.stepCount)
        if let average = values.averageRounded {
            return average
        }
        return liveMetrics.stepCount
    }

    private static func workoutConsistency(completedSessions: Int, scheduledSessions: Int) -> String? {
        guard scheduledSessions > 0 else { return nil }
        let ratio = Double(completedSessions) / Double(scheduledSessions)
        switch ratio {
        case ..<0.5: return "low"
        case 0.5..<0.8: return "moderate"
        default: return "high"
        }
    }
}

private extension Array where Element == Double {
    var average: Double? {
        guard !isEmpty else { return nil }
        return reduce(0, +) / Double(count)
    }
}

private extension Array where Element == Int {
    var averageRounded: Int? {
        guard !isEmpty else { return nil }
        return Int((Double(reduce(0, +)) / Double(count)).rounded())
    }
}
