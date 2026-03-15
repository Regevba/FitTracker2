// Models/DomainModels.swift
// All platform targets: iOS, iPadOS, macOS
// Every model is Codable for AES-256 storage + CloudKit + export

import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// ─────────────────────────────────────────────────────────
// MARK: – Program Phase
// ─────────────────────────────────────────────────────────

enum ProgramPhase: String, Codable, CaseIterable, Sendable {
    case recovery = "Recovery"
    case stage1   = "Stage 1"
    case stage2   = "Stage 2"

    var trainingCalories: Int { switch self { case .recovery: 1800; case .stage1: 1900; case .stage2: 2000 } }
    var restCalories: Int     { switch self { case .recovery: 1600; case .stage1: 1700; case .stage2: 1800 } }
    /// Intentionally uniform across all phases — protein target does not vary by phase.
    /// Used as a fallback when lean body mass is unavailable (see StatsView, spec).
    var proteinTargetG: ClosedRange<Double> { 125...135 }
}

// ─────────────────────────────────────────────────────────
// MARK: – Daily Log
// ─────────────────────────────────────────────────────────

struct DailyLog: Identifiable, Codable, Sendable {
    var id: UUID           = UUID()
    var date: Date
    var phase: ProgramPhase
    var dayType: DayType
    var recoveryDay: Int                            // Days since Jan 29 2026

    var taskStatuses:   [String: TaskStatus]        = [:]
    var exerciseLogs:   [String: ExerciseLog]       = [:]
    var cardioLogs:     [String: CardioLog]         = [:]
    var supplementLog:  SupplementLog               = SupplementLog()
    var nutritionLog:   NutritionLog                = NutritionLog()
    var biometrics:     DailyBiometrics             = DailyBiometrics()
    var notes:          String                      = ""
    var sessionStartTime: Date?                     // set on first set confirmation
    var mood:           Int?                        // 1–5
    var energyLevel:    Int?                        // 1–5
    var cravingLevel:   Int?                        // 1–5

    // CloudKit sync metadata
    var cloudRecordID: String?
    var lastModified:  Date = Date()
    var needsSync:     Bool = true

    var completionPct: Double {
        let all = taskStatuses.values
        guard !all.isEmpty else { return 0 }
        return Double(all.filter { $0 == .completed }.count) / Double(all.count) * 100
    }
}

extension DailyLog {
    init(date: Date, phase: ProgramPhase = .recovery) {
        self.date = date
        self.phase = phase
        self.dayType = .restDay
        self.recoveryDay = 0
    }
}

enum DayType: String, Codable, CaseIterable, Sendable {
    case restDay    = "Rest Day"
    case upperPush  = "Upper Push"
    case lowerBody  = "Lower Body"
    case upperPull  = "Upper Pull"
    case fullBody   = "Full Body"
    case cardioOnly = "Cardio Only"

    var isTrainingDay: Bool { self != .restDay }

    var weekday: Int {
        switch self {
        case .restDay: 4; case .upperPush: 2; case .lowerBody: 3
        case .upperPull: 5; case .fullBody: 6; case .cardioOnly: 7
        }
    }

    var icon: String {
        switch self {
        case .restDay: "bed.double.fill"
        case .upperPush: "arrow.up.circle.fill"
        case .lowerBody: "figure.walk"
        case .upperPull: "arrow.down.circle.fill"
        case .fullBody: "bolt.fill"
        case .cardioOnly: "heart.fill"
        }
    }
}

enum TaskStatus: String, Codable, Sendable {
    case pending = "pending", completed = "completed"
    case partial = "partial", missed = "missed"
}

// ─────────────────────────────────────────────────────────
// MARK: – Exercise Log
// ─────────────────────────────────────────────────────────

struct ExerciseLog: Identifiable, Codable, Sendable {
    var id:           UUID   = UUID()
    var exerciseID:   String
    var exerciseName: String
    var sets:         [SetLog] = []
    var notes:        String   = ""
    var timestamp:    Date     = Date()

    var totalVolume: Double {
        sets.compactMap { s in
            guard let w = s.weightKg, let r = s.repsCompleted else { return nil }
            return w * Double(r)
        }.reduce(0, +)
    }

    var bestSet: SetLog? { sets.max { ($0.weightKg ?? 0) < ($1.weightKg ?? 0) } }
}

struct SetLog: Identifiable, Codable, Sendable, Equatable {
    var id:             UUID    = UUID()
    var setNumber:      Int
    var weightKg:       Double?
    var repsCompleted:  Int?
    var rpe:            Double?      // 1–10
    var isWarmup:       Bool    = false
    var notes:          String  = ""
    var timestamp:      Date    = Date()
}

// ─────────────────────────────────────────────────────────
// MARK: – Cardio Log (Elliptical + Rowing)
// ─────────────────────────────────────────────────────────

struct CardioLog: Identifiable, Codable, Sendable {
    var id:              UUID       = UUID()
    var cardioType:      CardioType
    var durationMinutes: Double?
    var avgHeartRate:    Double?
    var maxHeartRate:    Double?
    var caloriesBurned:  Double?
    var notes:           String     = ""

    // Elliptical
    var resistance:  Int?
    var strideLevel: String?
    var distanceKm:  Double?

    // Rowing
    var pacePer500m:        String?
    var strokesPerMinute:   Int?
    var damperSetting:      Int?

    // Summary image (CloudKit asset reference)
    var summaryImageData:   Data?           // compressed JPEG stored encrypted
    var summaryImageCloudID: String?        // CloudKit CKAsset reference

    func wasInZone2(lower: Int, upper: Int) -> Bool? {
        guard let avg = avgHeartRate else { return nil }
        return avg >= Double(lower) && avg <= Double(upper)
    }
}

enum CardioType: String, Codable, CaseIterable, Sendable {
    case elliptical = "Elliptical"
    case rowing     = "Rowing"
    case walk       = "Walk"
    case other      = "Other"
}

// ─────────────────────────────────────────────────────────
// MARK: – Supplement Log
// ─────────────────────────────────────────────────────────

struct SupplementLog: Codable, Sendable {
    var morningStatus:  TaskStatus = .pending
    var eveningStatus:  TaskStatus = .pending
    var morningTime:    Date?
    var eveningTime:    Date?

    // Individual supplement override tracking
    var individualOverrides: [String: Bool] = [:]   // supplementID → taken
}

// ─────────────────────────────────────────────────────────
// MARK: – Nutrition Log
// ─────────────────────────────────────────────────────────

struct NutritionLog: Codable, Sendable {
    var meals:          [MealEntry]    = []
    var totalCalories:  Double?
    var totalProteinG:  Double?
    var totalCarbsG:    Double?
    var totalFatG:      Double?
    var waterML:        Double?
    var alluloseTaken:  Bool = false
}

extension NutritionLog {
    private func sum<T: BinaryFloatingPoint>(_ values: [T?]) -> Double? {
        let resolved = values.compactMap { $0.map(Double.init) }
        guard !resolved.isEmpty else { return nil }
        return resolved.reduce(0, +)
    }

    var mealCaloriesTotal: Double? { sum(meals.map(\.calories)) }
    var mealProteinTotal: Double? { sum(meals.map(\.proteinG)) }
    var mealCarbsTotal: Double? { sum(meals.map(\.carbsG)) }
    var mealFatTotal: Double? { sum(meals.map(\.fatG)) }

    var resolvedCalories: Double? { totalCalories ?? mealCaloriesTotal }
    var resolvedProteinG: Double? { totalProteinG ?? mealProteinTotal }
    var resolvedCarbsG: Double? { totalCarbsG ?? mealCarbsTotal }
    var resolvedFatG: Double? { totalFatG ?? mealFatTotal }
}

struct MealEntry: Identifiable, Codable, Sendable {
    var id:        UUID   = UUID()
    var mealNumber: Int
    var name:      String = ""
    var calories:  Double?
    var proteinG:  Double?
    var carbsG:    Double?
    var fatG:      Double?
    var eatenAt:   Date?
    var status:    TaskStatus = .pending
}

struct MealTemplate: Identifiable, Codable, Sendable {
    var id:        UUID   = UUID()
    var name:      String = ""
    var calories:  Double?
    var proteinG:  Double?
    var carbsG:    Double?
    var fatG:      Double?
}

// ─────────────────────────────────────────────────────────
// MARK: – Daily Biometrics
// ─────────────────────────────────────────────────────────

struct DailyBiometrics: Codable, Sendable {
    // Xiaomi S400 (manual)
    var weightKg:           Double?
    var bodyFatPercent:     Double?
    var leanBodyMassKg:     Double?
    var muscleMassKg:       Double?
    var boneMassKg:         Double?
    var visceralFatRating:  Int?
    var bodyWaterPercent:   Double?
    var bmi:                Double?
    var metabolicAge:       Int?
    var basalMetabolicRate: Double?

    // Apple Watch / HealthKit (auto)
    var restingHeartRate:   Double?
    var hrv:                Double?
    var vo2Max:             Double?
    var activeCalories:     Double?
    var stepCount:          Int?
    var sleepHours:         Double?
    var deepSleepMinutes:   Double?
    var remSleepMinutes:    Double?

    // Manual fallback
    var manualRestingHR:    Double?
    var manualHRV:          Double?
    var manualSleepHours:   Double?

    var effectiveRestingHR: Double? { restingHeartRate ?? manualRestingHR }
    var effectiveHRV:       Double? { hrv ?? manualHRV }
    var effectiveSleep:     Double? { sleepHours ?? manualSleepHours }
}

// ─────────────────────────────────────────────────────────
// MARK: – Exercise Definition (static)
// ─────────────────────────────────────────────────────────

struct ExerciseDefinition: Identifiable, Codable, Sendable {
    var id:             String
    var name:           String
    var category:       ExerciseCategory
    var equipment:      Equipment
    var muscleGroups:   [MuscleGroup]
    var targetSets:     Int
    var targetReps:     String
    var restSeconds:    Int
    var coachingCue:    String
    var dayType:        DayType
    var order:          Int
    var progressionNote: String = ""
}

enum ExerciseCategory: String, Codable, CaseIterable, Sendable {
    case machine, freeWeight = "Free Weight", calisthenics = "Calisthenics"
    case cardio, warmup, core
}

enum Equipment: String, Codable, CaseIterable, Sendable {
    case machine, barbell, dumbbell, cable, bodyweight
    case resistanceBand = "Resistance Band", elliptical, rowingMachine = "Rowing Machine", other
}

enum MuscleGroup: String, Codable, CaseIterable, Sendable {
    case chest, shoulders, triceps, back, biceps, rearDelt
    case quads, hamstrings, glutes, calves, core
    case fullBody, posterior, cardiovascular
}

// ─────────────────────────────────────────────────────────
// MARK: – Supplement Definition (static)
// ─────────────────────────────────────────────────────────

struct SupplementDefinition: Identifiable, Codable, Sendable {
    var id:       String
    var name:     String
    var dose:     String
    var timing:   SupplementTiming
    var benefit:  String
    var notes:    String
    var isActive: Bool = true
}

enum SupplementTiming: String, Codable, CaseIterable, Sendable {
    case morning, preWorkout = "Pre-Workout", withMeal = "With Meal"
    case evening, preBed = "Pre-Bed"
}

// ─────────────────────────────────────────────────────────
// MARK: – User Profile
// ─────────────────────────────────────────────────────────

struct UserProfile: Codable, Sendable {
    var name:               String          = "Regev"
    var age:                Int             = 43
    var heightCm:           Double          = 175
    var recoveryStart:      Date            = iso("2026-01-29")
    var currentPhase:       ProgramPhase    = .recovery
    var targetWeightMin:    Double          = 65
    var targetWeightMax:    Double          = 68
    var targetBFMin:        Double          = 13
    var targetBFMax:        Double          = 15
    var startWeightKg:      Double          = 70.95
    var startBodyFatPct:    Double          = 21.0
    var mealSlotNames:      [String]        = ["Breakfast", "Lunch", "Dinner", "Snacks"]

    func recoveryDay(for date: Date, calendar: Calendar = .current) -> Int {
        let start = calendar.startOfDay(for: recoveryStart)
        let current = calendar.startOfDay(for: date)
        return max(0, calendar.dateComponents([.day], from: start, to: current).day ?? 0)
    }

    var daysSinceStart: Int { recoveryDay(for: Date()) }

    // Goal progress: 0.0 – 1.0
    func weightProgress(current: Double?) -> Double {
        guard let w = current else { return 0 }
        let total = startWeightKg - targetWeightMax     // e.g. 70.95 - 65 = 5.95
        let done  = startWeightKg - w
        return max(0, min(1, done / max(total, 0.01)))
    }

    func bfProgress(current: Double?) -> Double {
        guard let b = current else { return 0 }
        let total = startBodyFatPct - targetBFMax
        let done  = startBodyFatPct - b
        return max(0, min(1, done / max(total, 0.01)))
    }

    // Combined goal progress (average of weight + BF)
    func overallProgress(currentWeight: Double?, currentBF: Double?) -> Double {
        let wp = weightProgress(current: currentWeight)
        let bp = bfProgress(current: currentBF)
        return (wp + bp) / 2.0
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – User Preferences
// ─────────────────────────────────────────────────────────

struct UserPreferences: Codable, Equatable, Sendable {
    var zone2LowerHR: Int     = 106
    var zone2UpperHR: Int     = 124
    var hrReadyThreshold: Int = 60
    var hrvReadyThreshold: Double = 28.0
}

private func iso(_ s: String) -> Date {
    let f = ISO8601DateFormatter(); f.formatOptions = [.withFullDate]
    return f.date(from: s) ?? Date()
}

// ─────────────────────────────────────────────────────────
// MARK: – Weekly Snapshot
// ─────────────────────────────────────────────────────────

struct WeeklySnapshot: Identifiable, Codable, Sendable {
    var id:                 UUID    = UUID()
    var weekStart:          Date
    var weekNumber:         Int
    var avgWeightKg:        Double?
    var avgBodyFatPct:      Double?
    var avgRestingHR:       Double?
    var avgHRV:             Double?
    var avgSleepHours:      Double?
    var avgProteinG:        Double?
    var totalTrainingDays:  Int     = 0
    var totalVolume:        Double  = 0
    var totalCardioMinutes: Double  = 0
    var taskAdherence:      Double  = 0     // 0–100
    var weightChange:       Double?
    var bfChange:           Double?
    var cloudRecordID:      String?
    var needsSync:          Bool    = true
}

// ─────────────────────────────────────────────────────────
// MARK: – Export Package
// ─────────────────────────────────────────────────────────

struct ExportPackage: Codable, Sendable {
    var exportDate:          Date           = Date()
    var exportVersion:       String         = "3.0"
    var profile:             UserProfile
    var phase:               ProgramPhase
    var recoveryDay:         Int
    var recentLogs:          [DailyLog]
    var weeklySnapshots:     [WeeklySnapshot]
    var exercises:           [ExerciseDefinition]
    var supplements:         [SupplementDefinition]
    var aiHints:             AIHints

    struct AIHints: Codable, Sendable {
        var hrvTrend:            String
        var weightTrend:         String
        var bfTrend:             String
        var avgAdherence:        Double
        var zone2MinPerWeek:     Double
        var proteinAdherence:    Double
        var suppAdherence:       Double
        var flags:               [String]
        var positives:           [String]
        var overallGoalProgress: Double
    }
}
