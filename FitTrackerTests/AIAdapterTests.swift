// FitTrackerTests/AIAdapterTests.swift
// Golden I/O tests for the AI adapter layer (TEST-006).
// Asserts that every adapter returns nil for missing data instead of fabricating,
// and that present data produces the expected snapshot fields.

import XCTest
@testable import FitTracker

final class AIAdapterTests: XCTestCase {

    // MARK: - ProfileAdapter

    func testProfileAdapter_populatesFieldsFromProfile() {
        var profile = UserProfile()
        profile.age = 32
        profile.trainingDaysPerWeek = 4
        let preferences = UserPreferences(nutritionGoalMode: .fatLoss)

        var snapshot = LocalUserSnapshot()
        let adapter = ProfileAdapter(profile: profile, preferences: preferences, todayDayType: .upperPush)
        adapter.contribute(to: &snapshot)

        XCTAssertEqual(snapshot.ageYears, 32)
        XCTAssertEqual(snapshot.trainingDaysPerWeek, 4)
        XCTAssertEqual(snapshot.primaryGoal, "weight_loss")
    }

    func testProfileAdapter_nilFieldsWhenAbsent() {
        // No gender/diet fields exist on UserProfile/UserPreferences — must be nil, not fabricated
        let profile = UserProfile()  // trainingDaysPerWeek defaults to nil
        let preferences = UserPreferences(nutritionGoalMode: .maintain)

        var snapshot = LocalUserSnapshot()
        ProfileAdapter(profile: profile, preferences: preferences, todayDayType: .restDay)
            .contribute(to: &snapshot)

        XCTAssertNil(snapshot.genderIdentity, "Must not fabricate gender")
        XCTAssertNil(snapshot.dietPattern, "Must not fabricate diet pattern")
        XCTAssertNil(snapshot.trainingDaysPerWeek, "Must not fabricate training days")
        XCTAssertEqual(snapshot.primaryGoal, "maintenance")
    }

    func testProfileAdapter_primaryGoalMapping() {
        let scenarios: [(NutritionGoalMode, String)] = [
            (.fatLoss, "weight_loss"),
            (.maintain, "maintenance"),
            (.gain, "muscle_gain"),
        ]

        for (mode, expected) in scenarios {
            var snapshot = LocalUserSnapshot()
            let prefs = UserPreferences(nutritionGoalMode: mode)
            ProfileAdapter(profile: UserProfile(), preferences: prefs, todayDayType: .upperPush)
                .contribute(to: &snapshot)
            XCTAssertEqual(snapshot.primaryGoal, expected, "\(mode) should map to \(expected)")
        }
    }

    // MARK: - NutritionAdapter

    func testNutritionAdapter_zeroCompletedMeals_returnsNil() {
        // Even if meals exist but none are completed, mealsPerDay must be nil
        var log = DailyLog(date: Date(), phase: .recovery, dayType: .restDay, recoveryDay: 0)
        log.nutritionLog.meals = [
            MealEntry(mealNumber: 1, name: "Planned", calories: 500, proteinG: 30, carbsG: 50, fatG: 15, status: .pending),
            MealEntry(mealNumber: 2, name: "Planned2", calories: 600, proteinG: 40, carbsG: 60, fatG: 20, status: .pending),
        ]

        var snapshot = LocalUserSnapshot()
        let adapter = NutritionAdapter(
            latestLog: log,
            goalPlan: NutritionGoalPlan(calories: 2000, proteinG: 150, carbsG: 200, fatG: 60, title: "", summary: "", emphasis: ""),
            liveMetrics: LiveMetrics(),
            profile: UserProfile()
        )
        adapter.contribute(to: &snapshot)

        XCTAssertNil(snapshot.mealsPerDay, "Zero completed meals must return nil, not inflate from planned count")
    }

    func testNutritionAdapter_completedMealsCounted() {
        var log = DailyLog(date: Date(), phase: .recovery, dayType: .restDay, recoveryDay: 0)
        log.nutritionLog.meals = [
            MealEntry(mealNumber: 1, name: "Breakfast", calories: 500, proteinG: 30, carbsG: 50, fatG: 15, status: .completed),
            MealEntry(mealNumber: 2, name: "Lunch", calories: 600, proteinG: 40, carbsG: 60, fatG: 20, status: .completed),
            MealEntry(mealNumber: 3, name: "Planned", calories: 700, proteinG: 50, carbsG: 70, fatG: 25, status: .pending),
        ]

        var snapshot = LocalUserSnapshot()
        NutritionAdapter(
            latestLog: log,
            goalPlan: NutritionGoalPlan(calories: 2000, proteinG: 150, carbsG: 200, fatG: 60, title: "", summary: "", emphasis: ""),
            liveMetrics: LiveMetrics(),
            profile: UserProfile()
        ).contribute(to: &snapshot)

        XCTAssertEqual(snapshot.mealsPerDay, 2, "Only completed meals should count, not planned")
    }

    // MARK: - TrainingAdapter

    func testTrainingAdapter_noWorkoutData_returnsNilNotFallback() {
        // No exercises, no cardio — avgSessionMinutes must be nil, not fabricated 30/45
        let logs: [DailyLog] = []
        var snapshot = LocalUserSnapshot()
        TrainingAdapter(recentLogs: logs, todayDayType: .restDay).contribute(to: &snapshot)

        XCTAssertNil(snapshot.avgSessionMinutes, "No workout data must produce nil, not fabricated fallback")
        XCTAssertEqual(snapshot.weeklySessionCount, 0)
    }

    func testTrainingAdapter_usesExerciseCountForDuration() {
        // 3 exercises → max(20, 3 * 15) = 45 min estimate
        var log = DailyLog(date: Date(), phase: .recovery, dayType: .upperPush, recoveryDay: 0)
        log.exerciseLogs = [
            "e1": ExerciseLog(exerciseID: "e1", exerciseName: "Bench"),
            "e2": ExerciseLog(exerciseID: "e2", exerciseName: "OHP"),
            "e3": ExerciseLog(exerciseID: "e3", exerciseName: "Fly"),
        ]

        var snapshot = LocalUserSnapshot()
        TrainingAdapter(recentLogs: [log], todayDayType: .upperPush).contribute(to: &snapshot)

        XCTAssertEqual(snapshot.avgSessionMinutes, 45, "3 exercises × 15min = 45min")
    }

    // MARK: - HealthKitAdapter

    func testHealthKitAdapter_bmiBoundsRejection() {
        // Weight of 500kg is implausible — BMI must be nil
        var live = LiveMetrics()
        live.weightKg = 500
        var profile = UserProfile()
        profile.heightCm = 175

        var snapshot = LocalUserSnapshot()
        HealthKitAdapter(liveMetrics: live, recentLogs: [], profile: profile, readiness: nil)
            .contribute(to: &snapshot)

        XCTAssertNil(snapshot.bmiValue, "Implausible weight must produce nil BMI")
    }

    func testHealthKitAdapter_bmiPlausibleWeight() {
        var live = LiveMetrics()
        live.weightKg = 70
        var profile = UserProfile()
        profile.heightCm = 175

        var snapshot = LocalUserSnapshot()
        HealthKitAdapter(liveMetrics: live, recentLogs: [], profile: profile, readiness: nil)
            .contribute(to: &snapshot)

        XCTAssertNotNil(snapshot.bmiValue)
        if let bmi = snapshot.bmiValue {
            XCTAssertEqual(bmi, 70.0 / (1.75 * 1.75), accuracy: 0.01)
        }
    }

    func testHealthKitAdapter_stressNilWhenNoSubjectiveSignals() {
        // Log exists but no mood/energy/craving set — stress must be nil
        let log = DailyLog(date: Date(), phase: .recovery, dayType: .restDay, recoveryDay: 0)

        var snapshot = LocalUserSnapshot()
        HealthKitAdapter(liveMetrics: LiveMetrics(), recentLogs: [log], profile: UserProfile(), readiness: nil)
            .contribute(to: &snapshot)

        XCTAssertNil(snapshot.stressLevel, "Must not fabricate 'moderate' stress when no subjective signals present")
    }

    func testHealthKitAdapter_stressInferredFromMoodEnergy() {
        var log = DailyLog(date: Date(), phase: .recovery, dayType: .restDay, recoveryDay: 0)
        log.mood = 5
        log.energyLevel = 5

        var snapshot = LocalUserSnapshot()
        HealthKitAdapter(liveMetrics: LiveMetrics(), recentLogs: [log], profile: UserProfile(), readiness: nil)
            .contribute(to: &snapshot)

        XCTAssertEqual(snapshot.stressLevel, "low", "High mood + energy should infer low stress")
    }
}
