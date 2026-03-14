// Views/Stats/StatsDataHelpers.swift
import Foundation

extension EncryptedDataStore {

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

    // MARK: – Zone 2 Cardio

    /// Total cardio duration (minutes) per DailyLog where avgHeartRate is in 106–124 bpm.
    func zone2Minutes(from: Date, to: Date) -> [(date: Date, minutes: Double)] {
        dailyLogs
            .filter { log in
                log.date >= from && log.date <= to
            }
            .sorted { $0.date < $1.date }
            .compactMap { log in
                let minutes = log.cardioLogs.values.compactMap { cardioLog -> Double? in
                    guard let hr = cardioLog.avgHeartRate,
                          hr >= 106 && hr <= 124,
                          let duration = cardioLog.durationMinutes
                    else { return nil }
                    return duration
                }.reduce(0, +)
                guard minutes > 0 else { return nil }
                return (date: log.date, minutes: minutes)
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
                    calories: nutrition.totalCalories,
                    proteinG: nutrition.totalProteinG,
                    supplementPct: supplementPct
                )
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
