// Services/Reminders/ReminderTriggers.swift
// Evaluates app-state conditions and fires the appropriate smart reminders.
// Currently implements T3 (nutrition gap) and T4 (training/rest day).
// T1 (HealthKit), T2 (registration), and T5 (engagement) are stubbed as
// Phase 2 / Phase 3 — see the UX spec at
// .claude/features/smart-reminders/ux-spec.md for timing details.

import Foundation

@MainActor
final class ReminderTriggerEvaluator {

    private let scheduler = ReminderScheduler.shared

    // MARK: - T3: Goal-gap nutrition reminder
    // Fires at 4 PM if protein intake < 50 % of the daily target.

    func evaluateNutritionGap(currentProtein: Double, targetProtein: Double) async {
        let hour = Calendar.current.component(.hour, from: Date())
        guard hour >= 16 else { return } // Only after 4 PM
        guard currentProtein < targetProtein * 0.5 else { return }

        let body = "You're at \(Int(currentProtein))g / \(Int(targetProtein))g protein today. A quick meal could close the gap."
        await scheduler.scheduleIfAllowed(type: .nutritionGap, body: body)
    }

    // MARK: - T4: Training / rest day reminder
    // Training: fires at 10 AM if no workout has been logged yet.
    // Rest:     fires any time readiness drops below 40.

    func evaluateTrainingDay(
        isTrainingDay: Bool,
        hasLoggedWorkout: Bool,
        readinessScore: Int?,
        dayType: String,
        exerciseCount: Int,
        durationMinutes: Int
    ) async {
        let hour = Calendar.current.component(.hour, from: Date())

        if isTrainingDay && !hasLoggedWorkout && hour >= 10 {
            let body = "\(dayType) · \(exerciseCount) exercises · ~\(durationMinutes)m. Ready when you are."
            await scheduler.scheduleIfAllowed(type: .trainingDay, body: body)
        }

        if let score = readinessScore, score < 40 {
            let body = "Your readiness is \(score)/100. Take it easy — rest is part of progress."
            await scheduler.scheduleIfAllowed(type: .restDay, body: body)
        }
    }

    // MARK: - Evaluate all triggers (called from app lifecycle)

    func evaluateAll(
        currentProtein: Double,
        targetProtein: Double,
        isTrainingDay: Bool,
        hasLoggedWorkout: Bool,
        readinessScore: Int?,
        dayType: String,
        exerciseCount: Int,
        durationMinutes: Int,
        isHealthKitAuthorized: Bool,
        isSignedIn: Bool,
        daysSinceLastOpen: Int
    ) async {
        // Phase 1: nutrition + training (highest value)
        await evaluateNutritionGap(currentProtein: currentProtein, targetProtein: targetProtein)
        await evaluateTrainingDay(
            isTrainingDay: isTrainingDay,
            hasLoggedWorkout: hasLoggedWorkout,
            readinessScore: readinessScore,
            dayType: dayType,
            exerciseCount: exerciseCount,
            durationMinutes: durationMinutes
        )

        // Phase 2: HealthKit + registration (future)
        // Phase 3: engagement (future)
    }
}
