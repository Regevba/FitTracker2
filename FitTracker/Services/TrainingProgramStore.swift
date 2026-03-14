// Services/TrainingProgramStore.swift
// Training program store — detects today's day type and provides exercises.
// Extracted from AuthManager.swift for cleaner separation of concerns.

import Foundation
import SwiftUI

// ─────────────────────────────────────────────────────────
// MARK: – Training Program Store
// ─────────────────────────────────────────────────────────

@MainActor
final class TrainingProgramStore: ObservableObject {

    @Published var todayDayType: DayType = .restDay

    /// Custom overrides per day type. If nil for a given day, falls back to static default.
    @Published var customExercises: [DayType: [ExerciseDefinition]] = [:] {
        didSet { saveCustomProgram() }
    }

    private let defaultsKey = "ft.customProgram"

    init() {
        detectToday()
        loadCustomProgram()
    }

    func detectToday() {
        let wd = Calendar.current.component(.weekday, from: Date())
        todayDayType = Self.dayType(forWeekday: wd)
    }

    /// Returns custom exercises for a day if set, otherwise the static default.
    func exercises(for day: DayType) -> [ExerciseDefinition] {
        customExercises[day] ?? TrainingProgramData.exercises(for: day)
    }

    /// Set custom exercises for a day (overrides static default).
    func setExercises(_ exercises: [ExerciseDefinition], for day: DayType) {
        customExercises[day] = exercises
    }

    /// Reset a day back to the static default program.
    func resetToDefault(for day: DayType) {
        customExercises.removeValue(forKey: day)
    }

    /// Returns true if the given day has been customised.
    func isCustomised(for day: DayType) -> Bool {
        customExercises[day] != nil
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

    // ── Persistence (UserDefaults — program structure, not health data) ───

    private func saveCustomProgram() {
        guard let data = try? JSONEncoder().encode(customExercises) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    private func loadCustomProgram() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([DayType: [ExerciseDefinition]].self, from: data) else { return }
        customExercises = decoded
    }
}
