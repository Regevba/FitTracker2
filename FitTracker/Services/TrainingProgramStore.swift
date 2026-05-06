// Services/TrainingProgramStore.swift
// Training program store — detects today's day type and provides exercises.
// Extracted from AuthManager.swift for cleaner separation of concerns.
//
// As of T5 (import-training-plan resume, 2026-05-06) this is also the routing
// layer for active-plan switching. When `activePlanId == nil` (default),
// `exercises(for:)` returns the bundled 6-day program from TrainingProgramData.
// When non-nil, it resolves the active ImportedTrainingPlan from the
// EncryptedDataStore and synthesizes ExerciseDefinitions from its
// ImportedExerciseEntry rows.

import Foundation
import SwiftUI

// ─────────────────────────────────────────────────────────
// MARK: – Training Program Store
// ─────────────────────────────────────────────────────────

@MainActor
final class TrainingProgramStore: ObservableObject {

    @Published var todayDayType: DayType = .restDay

    /// When non-nil, `exercises(for:)` returns exercises from the active
    /// ImportedTrainingPlan instead of the bundled program. Mutually
    /// exclusive — exactly one ImportedTrainingPlan can be active at a time;
    /// `activate(planId:dataStore:)` enforces this.
    @Published var activePlanId: UUID?

    /// Calendar weekday indices (1=Sunday, 4=Wednesday) that are rest days by default.
    static let restWeekdays: Set<Int> = [1, 4]

    init() { detectToday() }

    func detectToday() {
        let wd = Calendar.current.component(.weekday, from: Date())
        todayDayType = Self.dayType(forWeekday: wd)
    }

    /// Returns the exercises for `day`. Routes through the active imported plan
    /// when `activePlanId != nil`; otherwise returns the bundled program.
    /// Read-only on the data store — does not mutate.
    func exercises(for day: DayType, in dataStore: EncryptedDataStore? = nil) -> [ExerciseDefinition] {
        if let activeId = activePlanId,
           let store = dataStore,
           let plan = store.importedTrainingPlans.first(where: { $0.id == activeId }),
           let assignment = plan.days.first(where: { $0.assignedDayType == day }) {
            return assignment.exercises.enumerated().map { index, entry in
                Self.exerciseDefinition(from: entry, dayType: day, order: index + 1)
            }
        }
        return TrainingProgramData.exercises(for: day)
    }

    /// Convenience overload — kept for callers that don't have a dataStore in
    /// scope (e.g. preview targets, lightweight call sites). Returns the
    /// bundled program regardless of `activePlanId`.
    func exercises(for day: DayType) -> [ExerciseDefinition] {
        TrainingProgramData.exercises(for: day)
    }

    /// Switch the active training plan. Pass `nil` to deactivate (revert to
    /// bundled). Setting a non-nil `planId`:
    ///   1. Flips all `isActive: true` to false in `dataStore.importedTrainingPlans`
    ///   2. Sets the chosen plan's `isActive: true`
    ///   3. Updates `lastModified` on every plan whose isActive flipped
    ///   4. Persists via `dataStore.persistToDisk()`
    /// Sets `self.activePlanId` last so observers see a coherent state.
    func activate(planId: UUID?, dataStore: EncryptedDataStore) async {
        let now = Date()
        for index in dataStore.importedTrainingPlans.indices {
            let wasActive = dataStore.importedTrainingPlans[index].isActive
            let shouldBeActive = (dataStore.importedTrainingPlans[index].id == planId)
            if wasActive != shouldBeActive {
                dataStore.importedTrainingPlans[index].isActive = shouldBeActive
                dataStore.importedTrainingPlans[index].lastModified = now
                dataStore.importedTrainingPlans[index].needsSync = true
            }
        }
        activePlanId = planId
        await dataStore.persistToDisk()
    }

    static func dayType(forWeekday weekday: Int) -> DayType {
        switch weekday {
        case 2: .upperPush
        case 3: .lowerBody
        case 5: .upperPull
        case 6: .fullBody
        case 7: .cardioOnly
        default: .restDay
        }
    }

    // ─────────────────────────────────────────────────────
    // MARK: – ImportedExerciseEntry → ExerciseDefinition adapter
    // ─────────────────────────────────────────────────────

    /// Builds an ExerciseDefinition view of an ImportedExerciseEntry. For
    /// entries with a high-confidence library match (`mappedExerciseId != nil`),
    /// the bundled exercise's full metadata (category, equipment, muscle
    /// groups, coachingCue) is preserved while the user-imported sets/reps/
    /// rest override the bundled prescription.
    /// For unmapped entries, synthesizes a minimal definition using `.other`
    /// equipment + `.fullBody` muscle group as catch-all fallbacks.
    static func exerciseDefinition(
        from entry: ImportedExerciseEntry,
        dayType: DayType,
        order: Int
    ) -> ExerciseDefinition {
        if let mappedId = entry.mappedExerciseId,
           let bundled = TrainingProgramData.allExercises.first(where: { $0.id == mappedId }) {
            return ExerciseDefinition(
                id: bundled.id,
                name: bundled.name,
                category: bundled.category,
                equipment: bundled.equipment,
                muscleGroups: bundled.muscleGroups,
                targetSets: entry.sets,
                targetReps: entry.reps,
                restSeconds: entry.restSeconds ?? bundled.restSeconds,
                coachingCue: bundled.coachingCue,
                dayType: dayType,
                order: order,
                progressionNote: bundled.progressionNote
            )
        }

        return ExerciseDefinition(
            id: "imported_\(entry.rawName.lowercased().replacingOccurrences(of: " ", with: "_"))_\(order)",
            name: entry.rawName,
            category: .freeWeight,
            equipment: .other,
            muscleGroups: [.fullBody],
            targetSets: entry.sets,
            targetReps: entry.reps,
            restSeconds: entry.restSeconds ?? 90,
            coachingCue: "User-imported exercise. Edit mapping to link to FitMe library.",
            dayType: dayType,
            order: order,
            progressionNote: ""
        )
    }
}
