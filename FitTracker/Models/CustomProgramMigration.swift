// Models/CustomProgramMigration.swift
// C6 training-program-customization (2026-06-02)
//
// The non-destructive migration resolver. Reads userPreferences and returns
// the days the user is currently on — custom program if activeProgramID is
// set + valid, fixed PPL fallback otherwise.
//
// Called by TrainingPlanView every refresh. Pure function; no side effects.
//
// PRD §"Migration logic":
//   if activeProgramID == nil → fixed PPL fallback (no behavior change)
//   if activeProgramID set + program found → resolve custom
//   if activeProgramID set + program missing → fallback safe (returns PPL)

import Foundation

// MARK: - ResolvedDay

/// View-layer-ready output. Carries ExerciseDefinitions with overrides
/// applied so consumers (TrainingPlanView) don't need to know whether
/// they're reading custom or fixed PPL.
struct ResolvedDay: Identifiable, Sendable {
    let id: UUID
    let name: String
    let dayType: DayType
    let weekdayIndex: Int
    let exercises: [ExerciseDefinition]
}

// MARK: - CustomProgramMigration

enum CustomProgramMigration {

    /// Returns the days the user is currently on. Resolution order:
    ///   1. activeProgramID set + program in customPrograms → custom
    ///   2. activeProgramID set + program NOT found → fallback to fixed PPL
    ///   3. activeProgramID nil → fixed PPL (default for legacy users)
    ///
    /// Catalog defaults to TrainingProgramData.allExercises but is injectable
    /// for tests (deterministic + small fixtures).
    static func currentProgramDays(
        for preferences: UserPreferences,
        catalog: [ExerciseDefinition] = TrainingProgramData.allExercises
    ) -> [ResolvedDay] {
        if let activeID = preferences.activeProgramID,
           let program = preferences.customPrograms.first(where: { $0.id == activeID }) {
            return resolveCustomProgram(program, catalog: catalog)
        }
        return fixedPPLFallback(catalog: catalog)
    }

    /// Convenience method for consumer call sites that currently call
    /// `TrainingProgramData.exercises(for: dayType)`. Resolves through
    /// `currentProgramDays(for:)` + filters to the requested DayType.
    /// Returns the fixed PPL fallback's day if no matching day exists in
    /// the active program (e.g., user customized to only 3 days + the
    /// view is asking for cardioOnly which isn't in the custom program).
    static func exercisesForDay(
        _ dayType: DayType,
        in preferences: UserPreferences,
        catalog: [ExerciseDefinition] = TrainingProgramData.allExercises
    ) -> [ExerciseDefinition] {
        let days = currentProgramDays(for: preferences, catalog: catalog)
        if let match = days.first(where: { $0.dayType == dayType }) {
            return match.exercises
        }
        // Fallback to fixed PPL when the custom program doesn't have that
        // DayType — preserves pre-C6 behavior for unmapped days.
        return TrainingProgramData.exercises(for: dayType)
    }

    /// True iff the user has a valid custom program active. Used by
    /// Settings UI to show "Customize Program · Active: <name>" subtitle.
    static func hasActiveCustomProgram(_ preferences: UserPreferences) -> Bool {
        guard let activeID = preferences.activeProgramID else { return false }
        return preferences.customPrograms.contains { $0.id == activeID }
    }

    /// Display name for the active program (or "Fixed PPL" fallback).
    static func activeProgramDisplayName(_ preferences: UserPreferences) -> String {
        if let activeID = preferences.activeProgramID,
           let program = preferences.customPrograms.first(where: { $0.id == activeID }) {
            return program.name
        }
        return "Fixed PPL"
    }

    // MARK: - Private resolution

    private static func resolveCustomProgram(
        _ program: CustomProgram,
        catalog: [ExerciseDefinition]
    ) -> [ResolvedDay] {
        program.days.map { day in
            let resolved = day.slots
                .sorted { $0.order < $1.order }
                .compactMap { slot -> ExerciseDefinition? in
                    resolveSlot(slot, catalog: catalog)
                }
            return ResolvedDay(
                id: day.id,
                name: day.name,
                dayType: day.dayType,
                weekdayIndex: day.weekdayIndex,
                exercises: resolved
            )
        }
    }

    /// Resolves a single slot — looks up the exercise by ID + applies overrides.
    /// Returns nil if the exerciseID doesn't exist (catalog churn safety;
    /// the slot is silently dropped from the day).
    private static func resolveSlot(
        _ slot: ExerciseSlot,
        catalog: [ExerciseDefinition]
    ) -> ExerciseDefinition? {
        guard var base = catalog.first(where: { $0.id == slot.exerciseID }) else {
            return nil
        }
        if let setsOverride = slot.targetSetsOverride {
            base.targetSets = setsOverride
        }
        if let repsOverride = slot.targetRepsOverride {
            base.targetReps = repsOverride
        }
        if let restOverride = slot.restSecondsOverride {
            base.restSeconds = restOverride
        }
        return base
    }

    /// Fixed PPL fallback — materializes via TrainingProgramTemplates.
    private static func fixedPPLFallback(catalog: [ExerciseDefinition]) -> [ResolvedDay] {
        TrainingProgramData.fixedPPLDays().map { day in
            let resolved = day.slots
                .sorted { $0.order < $1.order }
                .compactMap { slot -> ExerciseDefinition? in
                    catalog.first { $0.id == slot.exerciseID }
                }
            return ResolvedDay(
                id: day.id,
                name: day.name,
                dayType: day.dayType,
                weekdayIndex: day.weekdayIndex,
                exercises: resolved
            )
        }
    }
}
