// FitTracker/Models/Stats/StatsFocusMetric.swift
import SwiftUI

enum StatsFocusMetric: String, CaseIterable, Identifiable {
    case weight
    case bodyFat
    case readiness
    case sleep
    case hrv
    case restingHeartRate
    case trainingVolume
    case zone2
    case steps
    case activeCalories
    case vo2Max
    case leanMass
    case muscleMass
    case bodyWater
    case visceralFat
    case protein
    case calories
    case supplementAdherence

    var id: String { rawValue }

    var title: String {
        switch self {
        case .weight:
            return "Weight"
        case .bodyFat:
            return "Body Fat %"
        case .readiness:
            return "Readiness"
        case .sleep:
            return "Sleep"
        case .hrv:
            return "HRV"
        case .restingHeartRate:
            return "Resting HR"
        case .trainingVolume:
            return "Training Volume"
        case .zone2:
            return "Zone 2"
        case .steps:
            return "Steps"
        case .activeCalories:
            return "Active Calories"
        case .vo2Max:
            return "VO2 Max"
        case .leanMass:
            return "Lean Mass"
        case .muscleMass:
            return "Muscle Mass"
        case .bodyWater:
            return "Body Water"
        case .visceralFat:
            return "Visceral Fat"
        case .protein:
            return "Protein"
        case .calories:
            return "Calories"
        case .supplementAdherence:
            return "Supplement Adherence"
        }
    }

    var icon: String {
        switch self {
        case .weight:
            return "scalemass.fill"
        case .bodyFat:
            return "drop.fill"
        case .readiness:
            return "sparkles"
        case .sleep:
            return "bed.double.fill"
        case .hrv:
            return "waveform.path.ecg"
        case .restingHeartRate:
            return "heart.fill"
        case .trainingVolume:
            return "dumbbell.fill"
        case .zone2:
            return "heart.circle.fill"
        case .steps:
            return "figure.walk"
        case .activeCalories:
            return "flame.fill"
        case .vo2Max:
            return "lungs.fill"
        case .leanMass:
            return "figure.arms.open"
        case .muscleMass:
            return "figure.strengthtraining.traditional"
        case .bodyWater:
            return "drop.circle.fill"
        case .visceralFat:
            return "dot.scope"
        case .protein:
            return "fork.knife"
        case .calories:
            return "flame.circle.fill"
        case .supplementAdherence:
            return "pill.fill"
        }
    }

    var tint: Color {
        switch self {
        case .weight:
            return AppColor.Brand.warm
        case .bodyFat:
            return AppColor.Status.warning
        case .readiness:
            return AppColor.Accent.recovery
        case .sleep:
            return AppColor.Accent.sleep
        case .hrv:
            return AppColor.Accent.recovery
        case .restingHeartRate:
            return AppColor.Status.error
        case .trainingVolume:
            return AppColor.Accent.recovery
        case .zone2:
            return AppColor.Status.success
        case .steps:
            return AppColor.Brand.secondary
        case .activeCalories:
            return AppColor.Brand.warmSoft
        case .vo2Max:
            return AppColor.Status.success
        case .leanMass:
            return AppColor.Accent.recovery
        case .muscleMass:
            return AppColor.Status.success
        case .bodyWater:
            return AppColor.Brand.secondary
        case .visceralFat:
            return AppColor.Accent.sleep
        case .protein:
            return AppColor.Status.success
        case .calories:
            return AppColor.Brand.warmSoft
        case .supplementAdherence:
            return AppColor.Accent.achievement
        }
    }

    var positiveIsGood: Bool {
        switch self {
        case .weight, .bodyFat, .restingHeartRate, .visceralFat:
            return false
        case .calories:
            return true
        default:
            return true
        }
    }

    var usesBars: Bool {
        switch self {
        case .trainingVolume, .zone2, .steps, .activeCalories, .supplementAdherence:
            return true
        default:
            return false
        }
    }

    var isPermanent: Bool {
        self == .weight || self == .bodyFat
    }

    var emptyStateTitle: String {
        "No \(title.lowercased()) data"
    }

    var emptyStateSubtitle: String {
        switch self {
        case .weight, .bodyFat, .leanMass, .muscleMass, .bodyWater, .visceralFat:
            return "Log body metrics or sync a smart scale to populate this chart."
        case .readiness, .sleep, .hrv, .restingHeartRate, .steps, .activeCalories, .vo2Max:
            return "Apple Health and Apple Watch data will show here once available."
        case .trainingVolume, .zone2:
            return "Log workouts and cardio sessions to populate this chart."
        case .protein, .calories, .supplementAdherence:
            return "Log nutrition and supplements to populate this chart."
        }
    }

    var category: String {
        switch self {
        case .weight, .bodyFat, .leanMass, .muscleMass, .bodyWater, .visceralFat:
            return "body"
        case .readiness, .sleep, .hrv, .restingHeartRate:
            return "recovery"
        case .trainingVolume, .zone2:
            return "training"
        case .steps, .activeCalories, .vo2Max:
            return "activity"
        case .protein, .calories, .supplementAdherence:
            return "nutrition"
        }
    }
}
