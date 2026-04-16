// Services/Reminders/ReminderTriggers.swift
// Evaluates app-state conditions and fires the appropriate smart reminders.
// Implements T3 (nutrition gap), T4 (training/rest day), T5 (HealthKit connect),
// T6 (account registration), and T7 (engagement).
// See the UX spec at .claude/features/smart-reminders/ux-spec.md for timing details.

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

    // MARK: - T5: HealthKit connect reminder
    // Fires on days 2, 5, and 10 post-onboarding if HealthKit is not yet authorised.

    func evaluateHealthKitConnect(isAuthorized: Bool, daysSinceOnboarding: Int) async {
        guard !isAuthorized else { return }
        guard [2, 5, 10].contains(daysSinceOnboarding) else { return }

        await scheduler.scheduleIfAllowed(
            type: .healthKitConnect,
            body: "Connect Apple Health to see your readiness score and recovery data."
        )
    }

    // MARK: - T6: Account registration reminder
    // Fires on days 3, 7, and 14 post-onboarding if the user has not signed in.

    func evaluateAccountRegistration(isSignedIn: Bool, daysSinceOnboarding: Int) async {
        guard !isSignedIn else { return }
        guard [3, 7, 14].contains(daysSinceOnboarding) else { return }

        await scheduler.scheduleIfAllowed(
            type: .accountRegistration,
            body: "Create your FitMe account to sync across devices and unlock AI coaching."
        )
    }

    // MARK: - T7: Engagement reminder
    // Fires when the user has not opened the app for 3 or more days.

    func evaluateEngagement(daysSinceLastOpen: Int) async {
        guard daysSinceLastOpen >= 3 else { return }

        let body: String
        if daysSinceLastOpen <= 4 {
            body = "Haven't seen you in a bit. Your streak is waiting."
        } else {
            body = "Your body composition goals need consistency. Quick check-in?"
        }

        await scheduler.scheduleIfAllowed(type: .engagement, body: body)
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
        daysSinceLastOpen: Int,
        daysSinceOnboarding: Int
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

        // Phase 2: HealthKit + registration
        await evaluateHealthKitConnect(isAuthorized: isHealthKitAuthorized, daysSinceOnboarding: daysSinceOnboarding)
        await evaluateAccountRegistration(isSignedIn: isSignedIn, daysSinceOnboarding: daysSinceOnboarding)

        // Phase 3: engagement
        await evaluateEngagement(daysSinceLastOpen: daysSinceLastOpen)
    }
}
