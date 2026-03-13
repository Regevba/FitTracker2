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
}
