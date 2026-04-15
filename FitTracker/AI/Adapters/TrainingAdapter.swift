// AI/Adapters/TrainingAdapter.swift
// Contributes training volume and consistency fields from DailyLog exercise/cardio data.

import Foundation

struct TrainingAdapter: AIInputAdapter {
    let sourceID = "training"

    private let recentLogs: [DailyLog]  // most-recent-first, pre-sorted
    private let todayDayType: DayType

    var lastUpdated: Date? { recentLogs.first?.date }

    init(recentLogs: [DailyLog], todayDayType: DayType) {
        self.recentLogs = recentLogs
        self.todayDayType = todayDayType
    }

    func contribute(to snapshot: inout LocalUserSnapshot) {
        let recent7 = Array(recentLogs.prefix(7))
        let recent14 = Array(recentLogs.prefix(14))

        snapshot.avgSessionMinutes = Self.averageSessionMinutes(from: recent14, fallbackDayType: todayDayType)

        let weeklySessions = recent7.filter { Self.hasCompletedWorkout(in: $0) }.count
        snapshot.weeklySessionCount = weeklySessions
        snapshot.weeklyActiveMinutes = Self.weeklyActiveMinutes(from: recent7)
        snapshot.workoutConsistency = Self.workoutConsistency(
            completedSessions: weeklySessions,
            scheduledSessions: snapshot.trainingDaysPerWeek ?? 0
        )
    }

    // MARK: - Private helpers (extracted from AISnapshotBuilder)

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

private extension Array where Element == Int {
    var averageRounded: Int? {
        guard !isEmpty else { return nil }
        return Int((Double(reduce(0, +)) / Double(count)).rounded())
    }
}
