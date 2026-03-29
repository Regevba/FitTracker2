import XCTest
@testable import FitTracker

private actor CountingAIEngineClient: AIEngineClientProtocol {
    private(set) var callCount = 0

    func fetchInsight(
        segment: AISegment,
        payload: [String : String],
        jwt: String
    ) async throws -> AIRecommendation {
        callCount += 1
        return AIRecommendation(
            segment: segment.rawValue,
            signals: ["cloud_signal"],
            confidence: 0.9,
            escalateToLLM: false,
            supportingData: [:]
        )
    }
}

private struct PassthroughFoundationModel: FoundationModelProtocol {
    var isAvailable: Bool { true }

    func adapt(
        recommendation: AIRecommendation,
        snapshot: LocalUserSnapshot
    ) async throws -> (recommendation: AIRecommendation, confidence: Double) {
        (recommendation, 1.0)
    }
}

@MainActor
final class FitTrackerCoreTests: XCTestCase {
    func testMergedAppleSessionPreservesExistingProfileDataWhenCredentialOmitsThem() {
        let existing = UserSession(
            provider: .apple,
            userID: "apple-user",
            displayName: "Regev Barak",
            email: "regev@example.com",
            phone: "+972500000000",
            sessionToken: "old-user-id",
            backendAccessToken: nil
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
            sessionToken: "old-user-id",
            backendAccessToken: nil
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

    func testPasswordRuleEvaluatorRejectsMissingRequirements() {
        let result = PasswordRuleEvaluator.validate("abc123")

        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.issues.contains("Include at least 1 capital letter."))
        XCTAssertTrue(result.issues.contains("Include at least 1 special character."))
    }

    func testPasswordRuleEvaluatorAcceptsValidPassword() {
        let result = PasswordRuleEvaluator.validate("T3st_0nly!")

        XCTAssertTrue(result.isValid)
        XCTAssertTrue(result.issues.isEmpty)
    }

    func testEmailRegistrationResendRefreshesChallengeExpiry() async throws {
        let service = SignInService()
        let draft = PendingEmailRegistration(
            firstName: "Test",
            lastName: "User",
            birthday: Date(),
            email: "test@example.com",
            password: "T3st_0nly!"
        )

        await service.startEmailRegistration(draft)
        let initialExpiry = try XCTUnwrap(service.pendingEmailChallenge?.expiresAt)

        await service.resendEmailRegistrationCode()
        let refreshedExpiry = try XCTUnwrap(service.pendingEmailChallenge?.expiresAt)

        XCTAssertGreaterThan(refreshedExpiry, initialExpiry)
        XCTAssertEqual(service.navigationPath, [.registerMethods, .emailVerification])
    }

    func testPasswordResetRequestUsesGenericSuccessMessage() async throws {
        let service = SignInService()

        await service.requestPasswordReset(email: "test@example.com")

        XCTAssertNil(service.authErrorMessage)
        XCTAssertEqual(service.statusMessage, "If that email is registered, a password reset link is on the way.")
    }

    func testUserSessionBackendAccessTokenOnlyExistsForJWTShape() {
        let localSession = UserSession(
            provider: .email,
            userID: "test@example.com",
            displayName: "Test User",
            email: "test@example.com",
            sessionToken: UUID().uuidString,
            backendAccessToken: nil
        )
        let backendSession = UserSession(
            provider: .email,
            userID: "test@example.com",
            displayName: "Test User",
            email: "test@example.com",
            sessionToken: UUID().uuidString,
            backendAccessToken: "header.payload.signature"
        )

        XCTAssertFalse(localSession.hasBackendAccessToken)
        XCTAssertTrue(backendSession.hasBackendAccessToken)
    }

    func testAISnapshotBuilderPopulatesCoreBandsFromExistingData() {
        let now = Date()
        let profile = UserProfile()
        let preferences = UserPreferences(nutritionGoalMode: .fatLoss)
        let liveMetrics = LiveMetrics(
            restingHR: 58,
            weightKg: 69.5,
            bodyFatPct: 0.19,
            stepCount: 8200,
            sleepHours: 7.4
        )
        var today = DailyLog.scheduled(for: now, profile: profile, dayType: .upperPush)
        today.nutritionLog.meals = [
            MealEntry(mealNumber: 1, name: "Breakfast", calories: 550, proteinG: 40, carbsG: 45, fatG: 15, eatenAt: now, status: .completed),
            MealEntry(mealNumber: 2, name: "Lunch", calories: 650, proteinG: 50, carbsG: 55, fatG: 20, eatenAt: now, status: .completed),
            MealEntry(mealNumber: 3, name: "Dinner", calories: 500, proteinG: 35, carbsG: 35, fatG: 18, eatenAt: now, status: .completed),
        ]
        today.exerciseLogs = [
            "bench": ExerciseLog(exerciseID: "bench", exerciseName: "Bench Press")
        ]
        today.biometrics.restingHeartRate = 58
        today.biometrics.sleepHours = 7.2
        today.biometrics.stepCount = 8400
        today.mood = 4
        today.energyLevel = 4

        let snapshot = AISnapshotBuilder.build(
            profile: profile,
            preferences: preferences,
            liveMetrics: liveMetrics,
            dailyLogs: [today],
            todayDayType: .upperPush,
            now: now
        )

        XCTAssertNotNil(snapshot.trainingBands())
        XCTAssertNotNil(snapshot.nutritionBands())
        XCTAssertNotNil(snapshot.recoveryBands())
        XCTAssertNotNil(snapshot.statsBands())
    }

    func testSupplementStreakStopsAtMissingDay() {
        let store = EncryptedDataStore()
        let calendar = Calendar.current

        var today = DailyLog.scheduled(for: Date(), profile: store.userProfile, dayType: .restDay)
        today.supplementLog.morningStatus = .completed
        today.supplementLog.eveningStatus = .completed

        let twoDaysAgoDate = calendar.date(byAdding: .day, value: -2, to: Date())!
        var twoDaysAgo = DailyLog.scheduled(for: twoDaysAgoDate, profile: store.userProfile, dayType: .restDay)
        twoDaysAgo.supplementLog.morningStatus = .completed
        twoDaysAgo.supplementLog.eveningStatus = .completed

        store.dailyLogs = [today, twoDaysAgo]

        XCTAssertEqual(store.supplementStreak, 1)
    }

    func testBuildExportUsesNewestFirstTrendDirection() {
        let store = EncryptedDataStore()
        let calendar = Calendar.current

        var newest = DailyLog.scheduled(for: Date(), profile: store.userProfile, dayType: .restDay)
        newest.biometrics.weightKg = 68
        newest.biometrics.hrv = 40

        let olderDate = calendar.date(byAdding: .day, value: -1, to: Date())!
        var older = DailyLog.scheduled(for: olderDate, profile: store.userProfile, dayType: .restDay)
        older.biometrics.weightKg = 70
        older.biometrics.hrv = 35

        store.dailyLogs = [newest, older]

        let export = store.buildExport()

        XCTAssertEqual(export.aiHints.weightTrend, "decreasing")
        XCTAssertEqual(export.aiHints.hrvTrend, "increasing")
    }

    func testAIOrchestratorFallsBackLocallyWhenBandsAreIncomplete() async {
        let engine = CountingAIEngineClient()
        let orchestrator = AIOrchestrator(
            engineClient: engine,
            foundationModel: PassthroughFoundationModel(),
            snapshot: { LocalUserSnapshot() }
        )

        await orchestrator.process(
            segment: .training,
            jwt: "header.payload.signature",
            overrideSnapshot: LocalUserSnapshot()
        )

        let callCount = await engine.callCount
        XCTAssertEqual(callCount, 0)
        XCTAssertEqual(orchestrator.latestRecommendations[.training]?.segment, AISegment.training.rawValue)
    }
}
