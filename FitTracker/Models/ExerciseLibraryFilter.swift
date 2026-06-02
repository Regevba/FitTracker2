// Models/ExerciseLibraryFilter.swift
// C3 exercise-search-filter (2026-06-02)
//
// Pure-function filter chain for the Exercise Library sheet. No state.
// Filters `TrainingProgramData.allExercises` by query + chip selections per
// the PRD's frozen search algorithm.
//
// At ~50 items, this is an O(N) in-memory scan — sub-millisecond on iPhone
// 17. No FTS, no Core Data, no async. PRD §"Technical Approach".
//
// Picker mode (C6 dependency) reuses the same filter; only the row-tap
// callback differs.

import Foundation

enum ExerciseLibraryFilter {

    /// Filter the catalog by query + chip selections.
    /// - Parameters:
    ///   - query: free-text query; matched case-insensitively against
    ///     exercise name AND each muscle's display name.
    ///   - muscle: one-of-N muscle filter (nil = no muscle filter).
    ///   - equipment: one-of-N equipment filter (nil = no equipment filter).
    ///   - category: one-of-N category filter; "strength" is a rollup of
    ///     machine + freeWeight + calisthenics (see `matchesCategory`).
    ///   - catalog: injectable for tests; defaults to the live catalog.
    /// - Returns: matching exercises preserving the catalog's day-grouped
    ///   order (PRD §"Open Questions" OQ-5).
    static func filteredExercises(
        query: String,
        muscle: MuscleGroup?,
        equipment: Equipment?,
        category: ExerciseCategory?,
        catalog: [ExerciseDefinition] = TrainingProgramData.allExercises
    ) -> [ExerciseDefinition] {
        catalog.filter { ex in
            let queryMatch = query.isEmpty
                || ex.name.localizedCaseInsensitiveContains(query)
                || ex.muscleGroups.contains { $0.rawValue.localizedCaseInsensitiveContains(query) }

            let muscleMatch = muscle.map { ex.muscleGroups.contains($0) } ?? true
            let equipmentMatch = equipment.map { ex.equipment == $0 } ?? true
            let categoryMatch = category.map { matchesCategory(ex.category, $0) } ?? true

            return queryMatch && muscleMatch && equipmentMatch && categoryMatch
        }
    }

    /// Strength = machine ∪ freeWeight ∪ calisthenics rollup per PRD
    /// §"Chip dimension taxonomy". cardio + core are 1:1.
    static func matchesCategory(_ raw: ExerciseCategory, _ filter: ExerciseCategory) -> Bool {
        switch filter {
        case .machine, .freeWeight, .calisthenics:
            // If a "strength" filter is requested, accept any of the 3 strength categories.
            // Note: the chip taxonomy exposes a single "Strength" pill that maps to .machine
            // (canonical strength representative); the rollup happens here.
            return raw == .machine || raw == .freeWeight || raw == .calisthenics
        case .cardio:
            return raw == .cardio
        case .core:
            return raw == .core
        case .warmup:
            return raw == .warmup
        }
    }
}
