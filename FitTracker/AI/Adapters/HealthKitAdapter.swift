// AI/Adapters/HealthKitAdapter.swift
// Contributes biometric and recovery fields from LiveMetrics + DailyLog biometrics.

import Foundation

struct HealthKitAdapter: AIInputAdapter {
    let sourceID = "healthkit"

    private let liveMetrics: LiveMetrics
    private let recentLogs: [DailyLog]  // most-recent-first, pre-sorted
    private let profile: UserProfile
    private let readiness: ReadinessResult?

    var lastUpdated: Date? { recentLogs.first?.date }

    init(liveMetrics: LiveMetrics, recentLogs: [DailyLog], profile: UserProfile, readiness: ReadinessResult?) {
        self.liveMetrics = liveMetrics
        self.recentLogs = recentLogs
        self.profile = profile
        self.readiness = readiness
    }

    func contribute(to snapshot: inout LocalUserSnapshot) {
        let recent7 = Array(recentLogs.prefix(7))

        // BMI
        let currentWeight = liveMetrics.weightKg
            ?? recentLogs.first?.biometrics.weightKg
            ?? profile.startWeightKg
        snapshot.bmiValue = Self.bmi(weightKg: currentWeight, heightCm: profile.heightCm)

        // Sleep
        snapshot.avgSleepHours = Self.averageSleepHours(from: recent7, liveMetrics: liveMetrics)
        snapshot.sleepQuality = Self.sleepQuality(for: snapshot.avgSleepHours)

        // Heart rate
        snapshot.restingHeartRate = Self.restingHeartRate(from: recent7, liveMetrics: liveMetrics)

        // Stress
        snapshot.stressLevel = Self.stressLevel(from: recentLogs.first)

        // Steps
        snapshot.avgDailySteps = Self.averageDailySteps(from: recent7, liveMetrics: liveMetrics)

        // Readiness Engine v2
        if let r = readiness {
            snapshot.readinessScore = r.overallScore
            snapshot.readinessConfidence = r.confidence.rawValue
            snapshot.readinessRecommendation = r.recommendation.rawValue
            snapshot.hrvComponentScore = r.hrvScore
            snapshot.sleepComponentScore = r.sleepScore
            snapshot.trainingLoadComponentScore = r.trainingLoadScore
            snapshot.rhrComponentScore = r.rhrScore
            snapshot.fatigueFlags = r.bodyCompFlags.map { $0.rawValue }
        }
    }

    // MARK: - Private helpers (extracted from AISnapshotBuilder)

    private static func bmi(weightKg: Double?, heightCm: Double) -> Double? {
        guard let weightKg, heightCm > 0 else { return nil }
        let heightMeters = heightCm / 100
        return weightKg / (heightMeters * heightMeters)
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

    private static func averageDailySteps(from logs: [DailyLog], liveMetrics: LiveMetrics) -> Int? {
        let values = logs.compactMap(\.biometrics.stepCount)
        if let averageRounded = values.averageRounded {
            return averageRounded
        }
        return liveMetrics.stepCount
    }
}

// MARK: - Array helpers (match existing AISnapshotBuilder)

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
