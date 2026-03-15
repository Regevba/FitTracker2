// Views/Stats/StatsDataHelpers.swift
import Foundation

private enum StatsBucket {
    case day
    case week
}

enum StatsSourceBadgeKind: String, CaseIterable, Identifiable {
    case appleHealth
    case healthKitOff
    case appleWatch
    case smartScale
    case bodyCheckIns
    case manualRecovery
    case nutritionLogs
    case trainingLogs

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appleHealth:
            return "Apple Health"
        case .healthKitOff:
            return "HealthKit Off"
        case .appleWatch:
            return "Apple Watch"
        case .smartScale:
            return "Smart Scale"
        case .bodyCheckIns:
            return "Body Check-ins"
        case .manualRecovery:
            return "Manual Recovery"
        case .nutritionLogs:
            return "Nutrition Logs"
        case .trainingLogs:
            return "Training Logs"
        }
    }
}

struct StatsCoverageSummary {
    let loggedDays: Int
    let totalDays: Int
    let bodyDays: Int
    let recoveryDays: Int
    let nutritionDays: Int
    let trainingDays: Int

    var coverageText: String {
        "\(loggedDays)/\(max(totalDays, 1)) days logged"
    }

    var detailText: String {
        "Body \(bodyDays) · Recovery \(recoveryDays) · Nutrition \(nutritionDays) · Training \(trainingDays)"
    }
}

private extension StatsPeriod {
    var statsBucket: StatsBucket {
        switch self {
        case .threeMonths, .sixMonths:
            return .week
        case .daily, .weekly, .monthly:
            return .day
        }
    }
}

private extension Calendar {
    func statsBucketStart(for date: Date, bucket: StatsBucket) -> Date {
        switch bucket {
        case .day:
            return startOfDay(for: date)
        case .week:
            return dateInterval(of: .weekOfYear, for: date)?.start ?? startOfDay(for: date)
        }
    }
}

private extension Array where Element == Double {
    var statsAverage: Double? {
        guard !isEmpty else { return nil }
        return reduce(0, +) / Double(count)
    }
}

private extension DailyBiometrics {
    var hasSmartScaleSignals: Bool {
        bodyWaterPercent != nil ||
        muscleMassKg != nil ||
        boneMassKg != nil ||
        visceralFatRating != nil ||
        metabolicAge != nil ||
        basalMetabolicRate != nil
    }

    var hasBodyCheckInSignals: Bool {
        weightKg != nil || bodyFatPercent != nil || leanBodyMassKg != nil || bmi != nil
    }

    var hasManualRecoverySignals: Bool {
        manualRestingHR != nil || manualHRV != nil || manualSleepHours != nil
    }
}

extension EncryptedDataStore {
    func statsCoverageSummary(from: Date, to: Date) -> StatsCoverageSummary {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: from)
        let end = calendar.startOfDay(for: to)
        let totalDays = max((calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1, 1)

        let logsInRange = dailyLogs.filter { log in
            let day = calendar.startOfDay(for: log.date)
            return day >= start && day <= end
        }

        let loggedDays = Set(logsInRange.map { calendar.startOfDay(for: $0.date) }).count
        let bodyDays = logsInRange.filter { $0.biometrics.hasBodyCheckInSignals || $0.biometrics.hasSmartScaleSignals }.count
        let recoveryDays = logsInRange.filter {
            $0.biometrics.effectiveHRV != nil ||
            $0.biometrics.effectiveRestingHR != nil ||
            $0.biometrics.effectiveSleep != nil
        }.count
        let nutritionDays = logsInRange.filter {
            $0.nutritionLog.resolvedCalories != nil ||
            $0.nutritionLog.resolvedProteinG != nil ||
            $0.supplementLog.morningStatus == .completed ||
            $0.supplementLog.eveningStatus == .completed
        }.count
        let trainingDays = logsInRange.filter { !$0.exerciseLogs.isEmpty || !$0.cardioLogs.isEmpty }.count

        return StatsCoverageSummary(
            loggedDays: loggedDays,
            totalDays: totalDays,
            bodyDays: bodyDays,
            recoveryDays: recoveryDays,
            nutritionDays: nutritionDays,
            trainingDays: trainingDays
        )
    }

    func statsSourceBadges(healthService: HealthKitService) -> [StatsSourceBadgeKind] {
        var badges: [StatsSourceBadgeKind] = []

        if healthService.isAuthorized {
            badges.append(.appleHealth)
        } else {
            badges.append(.healthKitOff)
        }

        let hasWatchSignals =
            healthService.latest.hrv != nil ||
            healthService.latest.restingHR != nil ||
            healthService.latest.sleepHours != nil ||
            healthService.latest.stepCount != nil
        if hasWatchSignals {
            badges.append(.appleWatch)
        }

        let biometrics = dailyLogs.map(\.biometrics)
        if biometrics.contains(where: \.hasSmartScaleSignals) {
            badges.append(.smartScale)
        } else if biometrics.contains(where: \.hasBodyCheckInSignals) {
            badges.append(.bodyCheckIns)
        }

        if biometrics.contains(where: \.hasManualRecoverySignals) {
            badges.append(.manualRecovery)
        }

        if dailyLogs.contains(where: { log in
            log.nutritionLog.resolvedCalories != nil ||
            log.nutritionLog.resolvedProteinG != nil ||
            log.supplementLog.morningStatus == .completed ||
            log.supplementLog.eveningStatus == .completed
        }) {
            badges.append(.nutritionLogs)
        }

        if dailyLogs.contains(where: { !$0.exerciseLogs.isEmpty || !$0.cardioLogs.isEmpty }) {
            badges.append(.trainingLogs)
        }

        return badges
    }

    func statsSourceSupportText(healthService: HealthKitService) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full

        if healthService.isAuthorized, let lastSync = healthService.lastSyncDate {
            let relative = formatter.localizedString(for: lastSync, relativeTo: Date())
            return "Apple Health is active and last refreshed \(relative), so watch-derived recovery signals can blend with your logged nutrition, training, and body metrics."
        }

        if healthService.isAuthorized {
            return "Apple Health is active, so watch-derived recovery signals can blend with manual body entries and logged workouts."
        }

        return "HealthKit is not connected yet, so recovery and body trends depend more heavily on manual logging and imported device data."
    }

    // MARK: – Body Composition

    /// Returns one entry per DailyLog in [from, to] that has at least one biometric value.
    func bodyCompositionPoints(from: Date, to: Date)
        -> [(date: Date, weightKg: Double?, bodyFatPercent: Double?, leanBodyMassKg: Double?)]
    {
        dailyLogs
            .filter { log in
                log.date >= from && log.date <= to
            }
            .sorted { $0.date < $1.date }
            .compactMap { log in
                let b = log.biometrics
                guard b.weightKg != nil || b.bodyFatPercent != nil || b.leanBodyMassKg != nil else {
                    return nil
                }
                return (
                    date: log.date,
                    weightKg: b.weightKg,
                    bodyFatPercent: b.bodyFatPercent,
                    leanBodyMassKg: b.leanBodyMassKg
                )
            }
    }

    func bodyCompositionPoints(from: Date, to: Date, period: StatsPeriod)
        -> [(date: Date, weightKg: Double?, bodyFatPercent: Double?, leanBodyMassKg: Double?)]
    {
        let points = bodyCompositionPoints(from: from, to: to)
        guard period.statsBucket == .week else { return points }

        let calendar = Calendar.current
        let grouped = Dictionary(grouping: points) {
            calendar.statsBucketStart(for: $0.date, bucket: .week)
        }

        return grouped.keys.sorted().map { bucketStart in
            let samples = grouped[bucketStart, default: []]
            return (
                date: bucketStart,
                weightKg: samples.compactMap(\.weightKg).statsAverage,
                bodyFatPercent: samples.compactMap(\.bodyFatPercent).statsAverage,
                leanBodyMassKg: samples.compactMap(\.leanBodyMassKg).statsAverage
            )
        }
    }

    func bodyCompositionDetailPoints(from: Date, to: Date, period: StatsPeriod)
        -> [(date: Date, bodyWaterPercent: Double?, muscleMassKg: Double?, visceralFatRating: Double?)]
    {
        let points = dailyLogs
            .filter { log in
                log.date >= from && log.date <= to
            }
            .sorted { $0.date < $1.date }
            .compactMap { log -> (date: Date, bodyWaterPercent: Double?, muscleMassKg: Double?, visceralFatRating: Double?)? in
                let biometrics = log.biometrics
                guard biometrics.bodyWaterPercent != nil ||
                        biometrics.muscleMassKg != nil ||
                        biometrics.visceralFatRating != nil
                else {
                    return nil
                }

                return (
                    date: log.date,
                    bodyWaterPercent: biometrics.bodyWaterPercent,
                    muscleMassKg: biometrics.muscleMassKg,
                    visceralFatRating: biometrics.visceralFatRating.map(Double.init)
                )
            }

        guard period.statsBucket == .week else { return points }

        let calendar = Calendar.current
        let grouped = Dictionary(grouping: points) {
            calendar.statsBucketStart(for: $0.date, bucket: .week)
        }

        return grouped.keys.sorted().map { bucketStart in
            let samples = grouped[bucketStart, default: []]
            return (
                date: bucketStart,
                bodyWaterPercent: samples.compactMap(\.bodyWaterPercent).statsAverage,
                muscleMassKg: samples.compactMap(\.muscleMassKg).statsAverage,
                visceralFatRating: samples.compactMap(\.visceralFatRating).statsAverage
            )
        }
    }

    // MARK: – Training Volume

    /// Sum of (weightKg × repsCompleted) across all non-warmup sets per DailyLog in range.
    func trainingVolumePoints(from: Date, to: Date) -> [(date: Date, volumeKg: Double)] {
        dailyLogs
            .filter { log in
                log.date >= from && log.date <= to && log.dayType.isTrainingDay
            }
            .sorted { $0.date < $1.date }
            .compactMap { log in
                let volume = log.exerciseLogs.values.flatMap { exerciseLog in
                    exerciseLog.sets.compactMap { set -> Double? in
                        guard !set.isWarmup,
                              let weight = set.weightKg,
                              let reps = set.repsCompleted
                        else { return nil }
                        return weight * Double(reps)
                    }
                }.reduce(0, +)
                guard volume > 0 else { return nil }
                return (date: log.date, volumeKg: volume)
            }
    }

    func trainingVolumePoints(from: Date, to: Date, period: StatsPeriod) -> [(date: Date, volumeKg: Double)] {
        let points = trainingVolumePoints(from: from, to: to)
        guard period.statsBucket == .week else { return points }

        let calendar = Calendar.current
        let grouped = Dictionary(grouping: points) {
            calendar.statsBucketStart(for: $0.date, bucket: .week)
        }

        return grouped.keys.sorted().map { bucketStart in
            let total = grouped[bucketStart, default: []]
                .map(\.volumeKg)
                .reduce(0, +)
            return (date: bucketStart, volumeKg: total)
        }
    }

    // MARK: – Zone 2 Cardio

    /// Total cardio duration (minutes) per DailyLog where avgHeartRate is in the configured Zone 2 range.
    func zone2Minutes(from: Date, to: Date) -> [(date: Date, minutes: Double)] {
        let lower = Double(userPreferences.zone2LowerHR)
        let upper = Double(userPreferences.zone2UpperHR)
        return dailyLogs
            .filter { log in
                log.date >= from && log.date <= to
            }
            .sorted { $0.date < $1.date }
            .compactMap { log in
                let minutes = log.cardioLogs.values.compactMap { cardioLog -> Double? in
                    guard let hr = cardioLog.avgHeartRate,
                          hr >= lower && hr <= upper,
                          let duration = cardioLog.durationMinutes
                    else { return nil }
                    return duration
                }.reduce(0, +)
                guard minutes > 0 else { return nil }
                return (date: log.date, minutes: minutes)
            }
    }

    func zone2Minutes(from: Date, to: Date, period: StatsPeriod) -> [(date: Date, minutes: Double)] {
        let points = zone2Minutes(from: from, to: to)
        guard period.statsBucket == .week else { return points }

        let calendar = Calendar.current
        let grouped = Dictionary(grouping: points) {
            calendar.statsBucketStart(for: $0.date, bucket: .week)
        }

        return grouped.keys.sorted().map { bucketStart in
            let total = grouped[bucketStart, default: []]
                .map(\.minutes)
                .reduce(0, +)
            return (date: bucketStart, minutes: total)
        }
    }

    // MARK: – Recovery

    func recoveryPoints(from: Date, to: Date)
        -> [(date: Date, hrv: Double?, restingHR: Double?, sleepHours: Double?)]
    {
        dailyLogs
            .filter { log in
                log.date >= from && log.date <= to
            }
            .sorted { $0.date < $1.date }
            .map { log in
                let b = log.biometrics
                return (
                    date: log.date,
                    hrv: b.effectiveHRV,
                    restingHR: b.effectiveRestingHR,
                    sleepHours: b.effectiveSleep
                )
            }
    }

    func recoveryPoints(from: Date, to: Date, period: StatsPeriod)
        -> [(date: Date, hrv: Double?, restingHR: Double?, sleepHours: Double?)]
    {
        let points = recoveryPoints(from: from, to: to)
        guard period.statsBucket == .week else { return points }

        let calendar = Calendar.current
        let grouped = Dictionary(grouping: points) {
            calendar.statsBucketStart(for: $0.date, bucket: .week)
        }

        return grouped.keys.sorted().map { bucketStart in
            let samples = grouped[bucketStart, default: []]
            return (
                date: bucketStart,
                hrv: samples.compactMap(\.hrv).statsAverage,
                restingHR: samples.compactMap(\.restingHR).statsAverage,
                sleepHours: samples.compactMap(\.sleepHours).statsAverage
            )
        }
    }

    // MARK: – Nutrition Adherence

    func nutritionAdherencePoints(from: Date, to: Date)
        -> [(date: Date, calories: Double?, proteinG: Double?, supplementPct: Double)]
    {
        dailyLogs
            .filter { log in
                log.date >= from && log.date <= to
            }
            .sorted { $0.date < $1.date }
            .map { log in
                let nutrition = log.nutritionLog
                let supp = log.supplementLog
                let supplementPct =
                    (supp.morningStatus == .completed ? 0.5 : 0.0) +
                    (supp.eveningStatus == .completed ? 0.5 : 0.0)
                return (
                    date: log.date,
                    calories: nutrition.resolvedCalories,
                    proteinG: nutrition.resolvedProteinG,
                    supplementPct: supplementPct
                )
            }
    }

    func nutritionAdherencePoints(from: Date, to: Date, period: StatsPeriod)
        -> [(date: Date, calories: Double?, proteinG: Double?, supplementPct: Double)]
    {
        let points = nutritionAdherencePoints(from: from, to: to)
        guard period.statsBucket == .week else { return points }

        let calendar = Calendar.current
        let grouped = Dictionary(grouping: points) {
            calendar.statsBucketStart(for: $0.date, bucket: .week)
        }

        return grouped.keys.sorted().map { bucketStart in
            let samples = grouped[bucketStart, default: []]
            return (
                date: bucketStart,
                calories: samples.compactMap(\.calories).statsAverage,
                proteinG: samples.compactMap(\.proteinG).statsAverage,
                supplementPct: samples.map(\.supplementPct).statsAverage ?? 0
            )
        }
    }

    func activityPoints(from: Date, to: Date, period: StatsPeriod, fallbackMetrics: LiveMetrics?)
        -> [(date: Date, steps: Double?, activeCalories: Double?, vo2Max: Double?)]
    {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var points = dailyLogs
            .filter { log in
                log.date >= from && log.date <= to
            }
            .sorted { $0.date < $1.date }
            .compactMap { log -> (date: Date, steps: Double?, activeCalories: Double?, vo2Max: Double?)? in
                let biometrics = log.biometrics
                guard biometrics.stepCount != nil ||
                        biometrics.activeCalories != nil ||
                        biometrics.vo2Max != nil
                else {
                    return nil
                }

                return (
                    date: log.date,
                    steps: biometrics.stepCount.map(Double.init),
                    activeCalories: biometrics.activeCalories,
                    vo2Max: biometrics.vo2Max
                )
            }

        if let fallbackMetrics,
           from <= today && to >= today,
           fallbackMetrics.stepCount != nil || fallbackMetrics.activeCalories != nil || fallbackMetrics.vo2Max != nil,
           !points.contains(where: { calendar.isDate($0.date, inSameDayAs: today) }) {
            points.append((
                date: today,
                steps: fallbackMetrics.stepCount.map(Double.init),
                activeCalories: fallbackMetrics.activeCalories,
                vo2Max: fallbackMetrics.vo2Max
            ))
            points.sort { $0.date < $1.date }
        }

        guard period.statsBucket == .week else { return points }

        let grouped = Dictionary(grouping: points) {
            calendar.statsBucketStart(for: $0.date, bucket: .week)
        }

        return grouped.keys.sorted().map { bucketStart in
            let samples = grouped[bucketStart, default: []]
            return (
                date: bucketStart,
                steps: samples.compactMap(\.steps).statsAverage,
                activeCalories: samples.compactMap(\.activeCalories).statsAverage,
                vo2Max: samples.compactMap(\.vo2Max).statsAverage
            )
        }
    }

    func readinessPoints(from: Date, to: Date, period: StatsPeriod, fallbackMetrics: LiveMetrics?)
        -> [(date: Date, score: Int)]
    {
        let calendar = Calendar.current
        var points: [(date: Date, score: Int)] = []
        var day = calendar.startOfDay(for: from)
        let lastDay = calendar.startOfDay(for: to)

        while day <= lastDay {
            if let score = readinessScore(for: day, fallbackMetrics: fallbackMetrics) {
                points.append((date: day, score: score))
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }

        guard period.statsBucket == .week else { return points }

        let grouped = Dictionary(grouping: points) {
            calendar.statsBucketStart(for: $0.date, bucket: .week)
        }

        return grouped.keys.sorted().map { bucketStart in
            let avg = grouped[bucketStart, default: []]
                .map { Double($0.score) }
                .statsAverage ?? 0
            return (date: bucketStart, score: Int(avg.rounded()))
        }
    }

    // MARK: – Personal Records

    /// All-time max SetLog.weightKg per exerciseID, excluding warmup sets.
    /// Returns dict: [exerciseID: (weightKg: Double, date: Date)]
    func prRecords() -> [String: (weightKg: Double, date: Date)] {
        var records: [String: (weightKg: Double, date: Date)] = [:]
        for log in dailyLogs {
            for exerciseLog in log.exerciseLogs.values {
                for set in exerciseLog.sets {
                    guard !set.isWarmup, let weight = set.weightKg else { continue }
                    let exerciseID = exerciseLog.exerciseID
                    if let existing = records[exerciseID] {
                        if weight > existing.weightKg {
                            records[exerciseID] = (weightKg: weight, date: log.date)
                        }
                    } else {
                        records[exerciseID] = (weightKg: weight, date: log.date)
                    }
                }
            }
        }
        return records
    }
}

/// Epley estimated 1-rep max.  Returns nil when reps < 1 or weight ≤ 0.
func estimated1RM(weightKg: Double, reps: Int) -> Double? {
    guard reps >= 1, weightKg > 0 else { return nil }
    if reps == 1 { return weightKg }          // already a 1RM
    return weightKg * (1 + Double(reps) / 30)
}
