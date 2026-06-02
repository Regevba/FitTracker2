// Models/CustomProgram.swift
// C6 training-program-customization (2026-06-02)
//
// User-defined custom training program data model. Lives in
// EncryptedDataStore.UserPreferences alongside existing fields. PII-free:
// only IDs, names, day types, weekday indices, and override numerics.
//
// Key decisions (PRD §"FROZEN constants"):
//   - exerciseID is a String reference to TrainingProgramData.allExercises.id
//     (NOT a copy) — catalog updates flow through to all custom programs.
//   - Override fields default nil — sparse storage; most users won't customize.
//   - schemaVersion future-proofs schema-breaking changes (current = 1).
//
// Migration: NO destructive migration. Fixed PPL stays as fallback constant.
// First-customize creates "My Program (was Default PPL)" editable snapshot.

import Foundation

// MARK: - Schema versioning

enum CustomProgramSchema {
    static let currentVersion: Int = 1
    static let maxSavedProgramsPerUser: Int = 10
}

// MARK: - CustomProgram

struct CustomProgram: Codable, Sendable, Identifiable, Equatable {
    let id: UUID
    var name: String
    let createdAt: Date
    var updatedAt: Date
    let schemaVersion: Int
    var days: [CustomDay]

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        schemaVersion: Int = CustomProgramSchema.currentVersion,
        days: [CustomDay]
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.schemaVersion = schemaVersion
        self.days = days
    }
}

// MARK: - CustomDay

struct CustomDay: Codable, Sendable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var dayType: DayType
    var weekdayIndex: Int   // 0..6 — Sun..Sat per Apple Calendar.component(.weekday) - 1
    var slots: [ExerciseSlot]

    init(
        id: UUID = UUID(),
        name: String,
        dayType: DayType,
        weekdayIndex: Int,
        slots: [ExerciseSlot] = []
    ) {
        self.id = id
        self.name = name
        self.dayType = dayType
        self.weekdayIndex = weekdayIndex
        self.slots = slots
    }
}

// MARK: - ExerciseSlot

struct ExerciseSlot: Codable, Sendable, Identifiable, Equatable {
    let id: UUID
    var exerciseID: String   // ref to TrainingProgramData.allExercises.id
    var targetSetsOverride: Int?
    var targetRepsOverride: String?
    var restSecondsOverride: Int?
    var order: Int           // 0-based position within day

    init(
        id: UUID = UUID(),
        exerciseID: String,
        targetSetsOverride: Int? = nil,
        targetRepsOverride: String? = nil,
        restSecondsOverride: Int? = nil,
        order: Int
    ) {
        self.id = id
        self.exerciseID = exerciseID
        self.targetSetsOverride = targetSetsOverride
        self.targetRepsOverride = targetRepsOverride
        self.restSecondsOverride = restSecondsOverride
        self.order = order
    }

    /// Number of non-nil override fields (0..3) — used by analytics.
    var overrideCount: Int {
        (targetSetsOverride == nil ? 0 : 1)
            + (targetRepsOverride == nil ? 0 : 1)
            + (restSecondsOverride == nil ? 0 : 1)
    }
}

// MARK: - TemplateID

/// Stable string IDs for the 4 starter templates exposed in NewProgramSheet.
/// Used as the analytics `template_id` param so GA4 dashboards can track
/// which templates dominate adoption.
enum TemplateID: String, Codable, Sendable, CaseIterable {
    case ppl6Day        = "ppl_6day"
    case upperLower4Day = "upper_lower_4day"
    case fullBody3Day   = "full_body_3day"
    case empty          = "empty"

    var displayName: String {
        switch self {
        case .ppl6Day:        return "PPL 6-day"
        case .upperLower4Day: return "Upper/Lower 4-day"
        case .fullBody3Day:   return "Full-body 3-day"
        case .empty:          return "Empty"
        }
    }

    var defaultProgramName: String {
        switch self {
        case .ppl6Day:        return "My PPL"
        case .upperLower4Day: return "My Upper/Lower"
        case .fullBody3Day:   return "My Full-Body"
        case .empty:          return "New program"
        }
    }

    var summary: String {
        switch self {
        case .ppl6Day:        return "Push / Pull / Legs / Full Body / Cardio + 1 rest"
        case .upperLower4Day: return "Upper A / Lower A / Upper B / Lower B + 3 rest"
        case .fullBody3Day:   return "Mon / Wed / Fri full body + 4 rest"
        case .empty:          return "Build from scratch — 7 unnamed rest days"
        }
    }
}
