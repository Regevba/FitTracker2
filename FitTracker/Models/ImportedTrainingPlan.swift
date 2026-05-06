// FitTracker/Models/ImportedTrainingPlan.swift
// On-disk model for user-imported training plans (T1 of import-training-plan resume).
// Distinct from `ImportedPlan` in Services/Import/ImportParser.swift, which is the
// parser-output transient. This wrapper carries identity, provenance, and the
// post-confirm day assignment, and is what `EncryptedDataStore.importedTrainingPlans`
// persists.

import Foundation

/// A user-imported training plan, persisted via EncryptedDataStore.
struct ImportedTrainingPlan: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    let createdAt: Date
    var lastModified: Date
    let source: ImportSource
    /// Raw input retained for audit / future AI prompt regeneration. Opt-in at
    /// import time; stored on-device only, encrypted at rest with the rest of
    /// the EncryptedDataStore payload.
    let sourceText: String?
    var days: [ImportedDayAssignment]
    /// Exactly one ImportedTrainingPlan can be active at a time; mutual exclusion
    /// is enforced by `TrainingProgramStore.activate(planId:dataStore:)`.
    var isActive: Bool
    /// Phase 2 sync flag; unused in Phase 1 (no CloudKit/Supabase wiring yet).
    var needsSync: Bool

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        lastModified: Date? = nil,
        source: ImportSource,
        sourceText: String? = nil,
        days: [ImportedDayAssignment],
        isActive: Bool = false,
        needsSync: Bool = true
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.lastModified = lastModified ?? createdAt
        self.source = source
        self.sourceText = sourceText
        self.days = days
        self.isActive = isActive
        self.needsSync = needsSync
    }
}

/// Maps a parser-output day name (e.g. "Day 1 — Push") to a FitMe DayType.
/// The heuristic in ImportOrchestrator picks the suggested DayType; the user
/// reviews and edits in the import preview before confirm.
struct ImportedDayAssignment: Codable, Equatable {
    let originalDayName: String
    var assignedDayType: DayType
    var exercises: [ImportedExerciseEntry]
}

/// On-disk exercise entry. mappedExerciseId is set when ExerciseMapper found a
/// confidence ≥ 0.70 match against the bundled 87-exercise library.
/// Unmapped entries surface their rawName via the Training tab adapter.
struct ImportedExerciseEntry: Codable, Equatable {
    let rawName: String
    var mappedExerciseId: String?
    var mappingConfidence: Double?
    var sets: Int
    var reps: String
    var restSeconds: Int?
}

/// Source of the imported plan. Phase 1 supports csv / json / markdownPaste.
/// pdf / photo / share are reserved for Phase 2.
enum ImportSource: String, Codable, CaseIterable {
    case csv
    case json
    case markdownPaste
    case pdf
    case photo
    case share

    /// Human-readable label for UI surfaces.
    var displayLabel: String {
        switch self {
        case .csv:           return "CSV"
        case .json:          return "JSON"
        case .markdownPaste: return "Pasted Text"
        case .pdf:           return "PDF"
        case .photo:         return "Photo"
        case .share:         return "Shared from app"
        }
    }

    /// SF Symbol for the source icon shown in list rows.
    var iconName: String {
        switch self {
        case .csv:           return "tablecells"
        case .json:          return "curlybraces"
        case .markdownPaste: return "doc.text"
        case .pdf:           return "doc.richtext"
        case .photo:         return "photo"
        case .share:         return "square.and.arrow.down"
        }
    }
}
