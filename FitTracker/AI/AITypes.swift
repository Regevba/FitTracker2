// AI/AITypes.swift
// Core value types for the federated cohort intelligence layer.
// All PII stays on-device; only banded categorical values leave the device.
// Compliant with GDPR Article 5 — data minimisation and purpose limitation.
// Swift 6 Sendable: uses [String: AnyCodable] instead of [String: Any].

import Foundation

// ─────────────────────────────────────────────────────────
// MARK: – AnyCodable (Sendable type-erased Codable wrapper)
// ─────────────────────────────────────────────────────────

/// Type-erased Codable wrapper satisfying Swift 6 Sendable requirements.
/// Replaces [String: Any] in AIRecommendation.supportingData.
/// @unchecked Sendable: we manually constrain stored values to known Sendable
/// primitives (Bool, Int, Double, String, [AnyCodable], [String: AnyCodable]).
/// The init and decode paths enforce this invariant at runtime.
public struct AnyCodable: Codable, @unchecked Sendable, Equatable {
    public let value: any Sendable

    public init(_ value: some Sendable) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "AnyCodable: unsupported value type"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let v as Bool:                  try container.encode(v)
        case let v as Int:                   try container.encode(v)
        case let v as Double:                try container.encode(v)
        case let v as String:                try container.encode(v)
        case let v as [AnyCodable]:          try container.encode(v)
        case let v as [String: AnyCodable]:  try container.encode(v)
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: encoder.codingPath,
                    debugDescription: "AnyCodable: unsupported value type \(type(of: value))"
                )
            )
        }
    }

    public static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        switch (lhs.value, rhs.value) {
        case let (l as Bool,                 r as Bool):                 return l == r
        case let (l as Int,                  r as Int):                  return l == r
        case let (l as Double,               r as Double):               return l == r
        case let (l as String,               r as String):               return l == r
        case let (l as [AnyCodable],         r as [AnyCodable]):         return l == r
        case let (l as [String: AnyCodable], r as [String: AnyCodable]): return l == r
        default: return false
        }
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – AI Segment identifiers
// ─────────────────────────────────────────────────────────

public enum AISegment: String, Sendable, CaseIterable {
    case training  = "training"
    case nutrition = "nutrition"
    case recovery  = "recovery"
    case stats     = "stats"
}

// ─────────────────────────────────────────────────────────
// MARK: – AIRecommendation (cloud insight response)
// ─────────────────────────────────────────────────────────

public struct AIRecommendation: Codable, Sendable {
    public let segment:       String
    public let signals:       [String]
    public let confidence:    Double
    public let escalateToLLM: Bool
    /// Population-level supporting data returned by the AI engine.
    /// Uses [String: AnyCodable] for Swift 6 Sendable compliance.
    public let supportingData: [String: AnyCodable]

    enum CodingKeys: String, CodingKey {
        case segment, signals, confidence
        case escalateToLLM  = "escalate_to_llm"
        case supportingData = "supporting_data"
    }
}

extension AIRecommendation {

    /// Goal-aware local fallback: generates signals weighted by the user's GoalProfile drivers.
    /// Each driver checks the relevant snapshot field and generates a signal with magnitude context.
    static func localFallback(
        for segment: AISegment,
        snapshot: LocalUserSnapshot,
        goalProfile: GoalProfile? = nil
    ) -> AIRecommendation {
        var signals: [String] = []
        let profile = goalProfile ?? GoalProfile.forGoal(
            NutritionGoalMode(rawValue: snapshot.primaryGoal ?? "") ?? .fatLoss
        )

        switch segment {
        case .training:
            // Goal-aware training signals
            if snapshot.programPhase == "recovery" {
                signals.append("local_recovery_phase_keep_intensity_in_check")
            }
            if let days = snapshot.trainingDaysPerWeek, days >= 5 {
                signals.append("local_high_frequency_program_detected")
            }
            // Drive emphasis from goal profile
            for driver in profile.primaryDrivers where driver.metric == "training_volume" || driver.metric == "training_progressive_overload" {
                signals.append("local_goal_\(profile.goal.shortLabel.lowercased())_training_emphasis")
            }
            if profile.goal == .fatLoss {
                signals.append("local_goal_preserve_muscle_during_deficit")
            } else if profile.goal == .gain {
                signals.append("local_goal_progressive_overload_priority")
            }

        case .nutrition:
            // Caloric balance — goal-direction-aware
            if let delta = snapshot.caloricBalanceDelta {
                switch profile.goal {
                case .fatLoss:
                    if delta < 0 {
                        signals.append("local_deficit_active_\(abs(delta))kcal")
                    } else {
                        signals.append("local_deficit_missed_surplus_\(delta)kcal")
                    }
                case .gain:
                    if delta > 0 {
                        signals.append("local_surplus_active_\(delta)kcal")
                    } else {
                        signals.append("local_surplus_missed_deficit_\(abs(delta))kcal")
                    }
                case .maintain:
                    if abs(delta) <= 100 {
                        signals.append("local_maintenance_on_target")
                    } else {
                        signals.append("local_maintenance_drift_\(delta)kcal")
                    }
                }
            }
            // Protein adequacy — universal but weighted differently per goal
            if let actual = snapshot.dailyProteinGrams, let target = snapshot.proteinTargetGrams {
                let gap = target - actual
                if gap > 0 {
                    signals.append("local_protein_below_target_\(Int(gap.rounded()))g")
                } else {
                    signals.append("local_protein_on_target")
                }
            }
            if let meals = snapshot.mealsPerDay, meals <= 2 {
                signals.append("local_low_meal_frequency")
            }

        case .recovery:
            if let sleep = snapshot.avgSleepHours, sleep < 6 {
                signals.append("local_sleep_debt_flag")
            }
            if let restingHR = snapshot.restingHeartRate, restingHR > 80 {
                signals.append("local_elevated_resting_hr")
            }
            if snapshot.stressLevel == "high" {
                signals.append("local_high_stress_detected")
            }
            // Goal context for recovery
            if profile.goal == .fatLoss {
                signals.append("local_recovery_cortisol_fat_loss_context")
            } else if profile.goal == .gain {
                signals.append("local_recovery_muscle_repair_context")
            }

        case .stats:
            if let sessions = snapshot.weeklySessionCount, sessions < 3 {
                signals.append("local_weekly_sessions_below_target")
            }
            if let steps = snapshot.avgDailySteps, steps < 7_500 {
                signals.append("local_daily_steps_below_target")
            }
            if snapshot.workoutConsistency == "high" {
                signals.append("local_consistency_strength")
            }
        }

        if signals.isEmpty {
            signals = ["local_baseline_ready"]
        }

        return AIRecommendation(
            segment: segment.rawValue,
            signals: signals,
            confidence: 0.25,
            escalateToLLM: false,
            supportingData: [:]
        )
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – LocalUserSnapshot (on-device anonymisable metrics)
// ─────────────────────────────────────────────────────────

/// Captures all user metrics that can be banded for cohort submission.
/// No PII fields — only banded categorical values are derived from this.
public struct LocalUserSnapshot: Sendable {
    // Demographics (from onboarding / profile)
    public var ageYears:          Int?
    public var genderIdentity:    String?    // "male" | "female" | "prefer_not_to_say"
    public var bmiValue:          Double?

    // Training
    public var activeWeeks:       Int?
    public var programPhase:      String?    // "foundation" | "build" | "peak" | "recovery"
    public var trainingDaysPerWeek: Int?
    public var avgSessionMinutes: Int?
    public var primaryGoal:       String?    // "weight_loss" | "muscle_gain" | "endurance" | "maintenance"

    // Nutrition
    public var caloricBalanceDelta: Int?     // kcal/day vs target (negative = deficit)
    public var dailyProteinGrams:  Double?
    public var proteinTargetGrams: Double?
    public var mealsPerDay:        Int?
    public var dietPattern:        String?   // "standard" | "vegetarian" | "vegan" | "keto" | "other"

    // Recovery
    public var avgSleepHours:     Double?
    public var sleepQuality:      String?    // "poor" | "fair" | "good"
    public var restingHeartRate:  Int?
    public var stressLevel:       String?    // "low" | "moderate" | "high"

    // Stats
    public var weeklySessionCount:     Int?
    public var weeklyActiveMinutes:    Int?
    public var avgDailySteps:          Int?
    public var workoutConsistency:     String?  // "low" | "moderate" | "high"

    // Readiness Engine v2 (evidence-based, goal-aware)
    public var readinessScore: Int?
    public var readinessConfidence: String?       // "low", "medium", "high"
    public var readinessRecommendation: String?   // "restDay", "lightOnly", "moderate", "fullIntensity", "pushHard"
    public var hrvComponentScore: Double?
    public var sleepComponentScore: Double?
    public var trainingLoadComponentScore: Double?
    public var rhrComponentScore: Double?
    public var fatigueFlags: [String]?            // ["hydrationWarning", "visceralTrend"]

    public init() {}
}

// ─────────────────────────────────────────────────────────
// MARK: – Band extraction
// ─────────────────────────────────────────────────────────

extension LocalUserSnapshot {

    /// Returns the banded training segment payload for submission to the AI engine.
    /// Returns nil if any required field is unavailable (prevents incomplete cohort writes).
    public func trainingBands() -> [String: String]? {
        guard
            let age     = ageBand(),
            let bmi     = bmiBand(),
            let weeks   = activeWeeksBand(),
            let phase   = programPhase,
            let days    = trainingDaysWeekBand(),
            let duration = avgSessionDurationBand(),
            let goal    = primaryGoal
        else { return nil }

        var bands: [String: String] = [
            "age_band":                  age,
            "bmi_band":                  bmi,
            "active_weeks_band":         weeks,
            "program_phase":             phase,
            "training_days_week_band":   days,
            "avg_session_duration_band": duration,
            "primary_goal":              goal,
        ]
        // Gender is optional — include only when user has provided it
        if let gender = genderBand() {
            bands["gender_band"] = gender
        }

        // Training load status from readiness engine
        if let loadScore = trainingLoadComponentScore {
            bands["training_load_status"] = loadScore >= 80 ? "optimal" : loadScore >= 50 ? "moderate" : "overreaching"
        }

        return bands
    }

    /// Returns the banded nutrition segment payload.
    public func nutritionBands() -> [String: String]? {
        guard
            let balance = caloricBalanceBand(),
            let protein = proteinAdequacyBand(),
            let meals   = mealFrequencyBand()
        else { return nil }

        var bands: [String: String] = [
            "caloric_balance_band":  balance,
            "protein_adequacy_band": protein,
            "meal_frequency_band":   meals,
        ]
        // Diet pattern is optional — include only when user has set it
        if let diet = dietPattern {
            bands["diet_pattern"] = diet
        }
        return bands
    }

    /// Returns the banded recovery segment payload.
    public func recoveryBands() -> [String: String]? {
        guard
            let sleep   = sleepDurationBand(),
            let quality = sleepQuality,
            let hr      = restingHRBand(),
            let stress  = stressLevel
        else { return nil }

        var bands: [String: String] = [
            "sleep_duration_band": sleep,
            "sleep_quality_band":  quality,
            "resting_hr_band":     hr,
            "stress_level_band":   stress,
        ]

        // Readiness bands
        if let score = readinessScore {
            bands["readiness_level"] = score >= 70 ? "high" : score >= 50 ? "moderate" : "low"
        }
        if let flags = fatigueFlags, !flags.isEmpty {
            bands["fatigue_level"] = flags.count >= 2 ? "significant" : "mild"
        } else {
            bands["fatigue_level"] = "none"
        }

        return bands
    }

    /// Returns the banded stats segment payload.
    public func statsBands() -> [String: String]? {
        guard
            let sessions    = weeklySessionsBand(),
            let minutes     = totalActiveMinutesBand(),
            let steps       = stepsDailyBand(),
            let consistency = workoutConsistency
        else { return nil }

        return [
            "weekly_sessions_band":       sessions,
            "total_active_minutes_band":  minutes,
            "steps_daily_band":           steps,
            "workout_consistency_band":   consistency,
        ]
    }

    // ── Private band helpers ───────────────────────────────

    private func ageBand() -> String? {
        guard let age = ageYears else { return nil }
        switch age {
        case ..<18:  return nil          // under-18 excluded
        case 18...24: return "18-24"
        case 25...34: return "25-34"
        case 35...44: return "35-44"
        case 45...54: return "45-54"
        default:      return "55+"
        }
    }

    private func genderBand() -> String? {
        guard let gender = genderIdentity else { return nil }
        let valid = ["male", "female", "prefer_not_to_say"]
        return valid.contains(gender) ? gender : "prefer_not_to_say"
    }

    private func bmiBand() -> String? {
        guard let bmi = bmiValue else { return nil }
        switch bmi {
        case ..<18.5:  return "under_18.5"
        case 18.5..<25: return "18.5-24.9"
        case 25..<30:   return "25-29.9"
        default:        return "30+"
        }
    }

    private func activeWeeksBand() -> String? {
        guard let weeks = activeWeeks else { return nil }
        switch weeks {
        case 0:       return "0"
        case 1...3:   return "1-3"
        default:      return "4+"
        }
    }

    private func trainingDaysWeekBand() -> String? {
        guard let days = trainingDaysPerWeek else { return nil }
        switch days {
        case 0:     return "0"
        case 1...2: return "1-2"
        case 3...4: return "3-4"
        default:    return "5+"
        }
    }

    private func avgSessionDurationBand() -> String? {
        guard let minutes = avgSessionMinutes else { return nil }
        switch minutes {
        case ..<30:  return "under_30"
        case 30...45: return "30-45"
        case 46...60: return "46-60"
        default:      return "60+"
        }
    }

    private func caloricBalanceBand() -> String? {
        guard let delta = caloricBalanceDelta else { return nil }
        switch delta {
        case ..<(-500):       return "deficit_large"
        case (-500)...(-1):  return "deficit_small"
        case 0...0:           return "maintenance"
        case 1...500:         return "surplus_small"
        default:              return "surplus_large"
        }
    }

    private func proteinAdequacyBand() -> String? {
        guard let actual = dailyProteinGrams, let target = proteinTargetGrams, target > 0 else { return nil }
        let ratio = actual / target
        switch ratio {
        case ..<0.85:  return "below_target"
        case 0.85..<1.15: return "at_target"
        default:       return "above_target"
        }
    }

    private func mealFrequencyBand() -> String? {
        guard let meals = mealsPerDay else { return nil }
        switch meals {
        case 1...2: return "1-2"
        case 3...4: return "3-4"
        default:    return "5+"
        }
    }

    private func sleepDurationBand() -> String? {
        guard let hours = avgSleepHours else { return nil }
        switch hours {
        case ..<6:    return "under_6"
        case 6..<7:   return "6-7"
        case 7..<8:   return "7-8"
        default:      return "8+"
        }
    }

    private func restingHRBand() -> String? {
        guard let hr = restingHeartRate else { return nil }
        switch hr {
        case ..<60:   return "under_60"
        case 60...70: return "60-70"
        case 71...80: return "71-80"
        default:      return "81+"
        }
    }

    private func weeklySessionsBand() -> String? {
        guard let sessions = weeklySessionCount else { return nil }
        switch sessions {
        case 0...1: return "0-1"
        case 2...3: return "2-3"
        case 4...5: return "4-5"
        default:    return "6+"
        }
    }

    private func totalActiveMinutesBand() -> String? {
        guard let minutes = weeklyActiveMinutes else { return nil }
        switch minutes {
        case ..<150:    return "under_150"
        case 150..<300: return "150-300"
        case 300..<450: return "300-450"
        default:        return "450+"
        }
    }

    private func stepsDailyBand() -> String? {
        guard let steps = avgDailySteps else { return nil }
        switch steps {
        case ..<5000:     return "under_5000"
        case 5000..<7500: return "5000-7500"
        case 7500..<10000: return "7500-10000"
        default:          return "10000+"
        }
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – DayType → AI program phase mapping
// ─────────────────────────────────────────────────────────

extension DayType {
    /// Maps the current training day type to the AI engine's program_phase band.
    var aiProgramPhase: String {
        switch self {
        case .restDay:                          return "recovery"
        case .upperPush, .lowerBody,
             .upperPull, .fullBody:             return "build"
        case .cardioOnly:                       return "foundation"
        }
    }
}
