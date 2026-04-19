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

        // BMI — only from measured weight, never from startWeightKg (which may be stale).
        // Audit AI-008 / DEEP-AI-003: source order is liveMetrics → most-recent log → nil.
        // No fallback to profile.startWeightKg.
        let currentWeight = liveMetrics.weightKg
            ?? recentLogs.first?.biometrics.weightKg
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

    /// Audit AI-009 / DEEP-AI-003: enforce plausibility bounds before computing
    /// BMI. Heights outside 100-250cm and weights outside 30-300kg return nil
    /// instead of producing nonsense bands ("underweight" for a 1cm subject).
    private static func bmi(weightKg: Double?, heightCm: Double) -> Double? {
        guard let weightKg, heightCm >= 100, heightCm <= 250,
              weightKg >= 30, weightKg <= 300 else { return nil }
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

    private static func stressLevel(from log: DailyLog?) -> String? {
        guard let log else { return nil }
        // At least one subjective signal must be present.
        guard log.mood != nil || log.energyLevel != nil || log.cravingLevel != nil else { return nil }
        // Audit AI-007: only emit a classification when there's STRONG evidence.
        // Previously we returned "moderate" as a default whenever any signal
        // was present — that fabricated a confidence level (and suppressed the
        // orchestrator's `insufficientData` UX path) from one weak data point.
        // New rule:
        //   - Any extreme signal (mood ≤2, energy ≤2, craving ≥4) → "high"
        //   - Both mood AND energy ≥4 → "low" (need two corroborating signals)
        //   - Otherwise → nil (do not fabricate "moderate" from weak data)
        if let mood = log.mood, mood <= 2 { return "high" }
        if let energy = log.energyLevel, energy <= 2 { return "high" }
        if let craving = log.cravingLevel, craving >= 4 { return "high" }
        if let mood = log.mood, mood >= 4, let energy = log.energyLevel, energy >= 4 { return "low" }
        return nil
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
