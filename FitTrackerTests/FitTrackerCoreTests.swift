import XCTest
@testable import FitTracker

@MainActor
final class FitTrackerCoreTests: XCTestCase {
    func testMergedAppleSessionPreservesExistingProfileDataWhenCredentialOmitsThem() {
        let existing = UserSession(
            provider: .apple,
            userID: "apple-user",
            displayName: "Regev Barak",
            email: "regev@example.com",
            phone: "+972500000000",
            sessionToken: "old-user-id"
        )

        let merged = SignInService.mergedAppleSession(
            userID: "apple-user",
            incomingName: "",
            incomingEmail: nil,
            existingAppleSession: existing
        )

        XCTAssertEqual(merged.displayName, "Regev Barak")
        XCTAssertEqual(merged.email, "regev@example.com")
        XCTAssertEqual(merged.phone, "+972500000000")
        XCTAssertEqual(merged.sessionToken, "apple-user")
    }

    func testMergedAppleSessionUsesFreshCredentialDataWhenPresent() {
        let existing = UserSession(
            provider: .apple,
            userID: "apple-user",
            displayName: "Old Name",
            email: "old@example.com",
            sessionToken: "old-user-id"
        )

        let merged = SignInService.mergedAppleSession(
            userID: "apple-user",
            incomingName: "New Name",
            incomingEmail: "new@example.com",
            existingAppleSession: existing
        )

        XCTAssertEqual(merged.displayName, "New Name")
        XCTAssertEqual(merged.email, "new@example.com")
        XCTAssertEqual(merged.sessionToken, "apple-user")
    }

    func testTrainingProgramStoreWeekdayMapping() {
        XCTAssertEqual(TrainingProgramStore.dayType(forWeekday: 2), .upperPush)
        XCTAssertEqual(TrainingProgramStore.dayType(forWeekday: 3), .lowerBody)
        XCTAssertEqual(TrainingProgramStore.dayType(forWeekday: 5), .upperPull)
        XCTAssertEqual(TrainingProgramStore.dayType(forWeekday: 6), .fullBody)
        XCTAssertEqual(TrainingProgramStore.dayType(forWeekday: 7), .cardioOnly)
        XCTAssertEqual(TrainingProgramStore.dayType(forWeekday: 1), .restDay)
        XCTAssertEqual(TrainingProgramStore.dayType(forWeekday: 4), .restDay)
    }

    func testDailyLogCompletionPercentageCountsCompletedTasksOnly() {
        var log = DailyLog(
            date: Date(),
            phase: .recovery,
            dayType: .restDay,
            recoveryDay: 1
        )
        log.taskStatuses = [
            "a": .completed,
            "b": .completed,
            "c": .partial,
            "d": .missed,
        ]

        XCTAssertEqual(log.completionPct, 50, accuracy: 0.001)
    }

    func testUserProfileOverallProgressAveragesWeightAndBodyFat() {
        let profile = UserProfile(
            name: "Regev",
            age: 43,
            heightCm: 175,
            recoveryStart: Date(),
            currentPhase: .recovery,
            targetWeightMin: 65,
            targetWeightMax: 68,
            targetBFMin: 13,
            targetBFMax: 15,
            startWeightKg: 70,
            startBodyFatPct: 20
        )

        let progress = profile.overallProgress(currentWeight: 69, currentBF: 18)

        XCTAssertGreaterThan(progress, 0)
        XCTAssertLessThan(progress, 1)
    }

    func testNutritionAdherencePointsFallBackToMealEntriesWhenTotalsAreMissing() {
        let store = EncryptedDataStore()
        var log = DailyLog(
            date: Date(),
            phase: .recovery,
            dayType: .restDay,
            recoveryDay: 1
        )
        log.nutritionLog.meals = [
            MealEntry(mealNumber: 1, name: "Breakfast", calories: 400, proteinG: 30, carbsG: 20, fatG: 10, eatenAt: Date(), status: .completed),
            MealEntry(mealNumber: 2, name: "Lunch", calories: 600, proteinG: 45, carbsG: 50, fatG: 15, eatenAt: Date(), status: .completed),
        ]
        store.dailyLogs = [log]

        let points = store.nutritionAdherencePoints(from: .distantPast, to: .distantFuture)

        XCTAssertEqual(points.count, 1)
        XCTAssertEqual(points[0].calories ?? 0, 1000, accuracy: 0.001)
        XCTAssertEqual(points[0].proteinG ?? 0, 75, accuracy: 0.001)
    }

    func testRecoveryDayUsesStartOfDayBoundaries() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let profile = UserProfile(recoveryStart: formatter.date(from: "2026-01-29")!)

        let sameDayLate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 29, hour: 23, minute: 59))!
        let nextDayEarly = calendar.date(from: DateComponents(year: 2026, month: 1, day: 30, hour: 0, minute: 1))!

        XCTAssertEqual(profile.recoveryDay(for: sameDayLate, calendar: calendar), 0)
        XCTAssertEqual(profile.recoveryDay(for: nextDayEarly, calendar: calendar), 1)
    }
}
