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

    init() { detectToday() }

    func detectToday() {
        let wd = Calendar.current.component(.weekday, from: Date())
        todayDayType = switch wd {
        case 2: .upperPush
        case 3: .lowerBody
        case 5: .upperPull
        case 6: .fullBody
        case 7: .cardioOnly
        default: .restDay
        }
    }

    func exercises(for day: DayType) -> [ExerciseDefinition] {
        TrainingProgramData.exercises(for: day)
    }
}
