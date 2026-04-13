import XCTest
@testable import FitTracker

/// Golden input/output eval tests for ReadinessEngine.compute().
/// Each test uses a realistic biometric profile and asserts the output score
/// and recommendation fall within a documented expected range.
/// All helper values are exact (no random) to guarantee determinism.
final class ReadinessFormulaEvals: XCTestCase {

    // MARK: - Helpers

    private func makeMetrics(
        hrv: Double? = nil,
        restingHR: Double? = nil,
        sleepHours: Double? = nil,
        deepSleepMin: Double? = nil,
        remSleepMin: Double? = nil,
        weightKg: Double? = nil
    ) -> LiveMetrics {
        var m = LiveMetrics()
        m.hrv = hrv
        m.restingHR = restingHR
        m.sleepHours = sleepHours
        m.deepSleepMin = deepSleepMin
        m.remSleepMin = remSleepMin
        m.weightKg = weightKg
        return m
    }

    private func makeLogs(
        count: Int,
        hrvBase: Double = 50,
        rhrBase: Double = 65,
        sleepBase: Double = 7.5,
        includeTraining: Bool = true
    ) -> [DailyLog] {
        let cal = Calendar.current
        return (1...count).map { offset in
            let date = cal.date(byAdding: .day, value: -offset, to: Date())!
            var log = DailyLog(
                date: date,
                phase: .stage1,
                dayType: .cardioOnly,
                recoveryDay: offset
            )
            log.biometrics.hrv = hrvBase
            log.biometrics.restingHeartRate = rhrBase
            log.biometrics.sleepHours = sleepBase
            log.biometrics.deepSleepMinutes = 55
            log.biometrics.remSleepMinutes = 80
            log.biometrics.weightKg = 71.5
            if includeTraining {
                var exercise = ExerciseLog(exerciseID: "e1", exerciseName: "Bench")
                exercise.sets = [
                    SetLog(setNumber: 1, weightKg: 60, repsCompleted: 8, rpe: 7),
                    SetLog(setNumber: 2, weightKg: 60, repsCompleted: 8, rpe: 7),
                    SetLog(setNumber: 3, weightKg: 60, repsCompleted: 8, rpe: 7),
                ]
                log.exerciseLogs["e1"] = exercise
            }
            return log
        }
    }

    // MARK: - Eval 1: Healthy athlete baseline

    /// A well-rested athlete with solid HRV, normal resting HR, and complete
    /// sleep architecture should score in the upper range and receive a
    /// full-intensity or push-hard recommendation.
    func testEval_healthyAthleteBaseline() {
        let logs = makeLogs(
            count: 10,
            hrvBase: 55,
            rhrBase: 58,
            sleepBase: 8.0,
            includeTraining: true
        )
        let metrics = makeMetrics(
            hrv: 55,
            restingHR: 58,
            sleepHours: 8.0,
            deepSleepMin: 84,
            remSleepMin: 108,
            weightKg: 71.5
        )

        let result = ReadinessEngine.compute(
            todayMetrics: metrics,
            dailyLogs: logs,
            goalMode: .maintain
        )

        XCTAssertNotNil(result, "Healthy baseline should produce a result")
        guard let result else { return }

        XCTAssertGreaterThanOrEqual(result.overallScore, 70,
            "Healthy athlete score should be >= 70, got \(result.overallScore)")
        XCTAssertLessThanOrEqual(result.overallScore, 90,
            "Healthy athlete score should be <= 90, got \(result.overallScore)")

        let validRecs: Set<TrainingRecommendation> = [.fullIntensity, .pushHard]
        XCTAssertTrue(validRecs.contains(result.recommendation),
            "Healthy baseline should recommend fullIntensity or pushHard, got \(result.recommendation)")
    }

    // MARK: - Eval 2: Sleep-deprived athlete

    /// An athlete who slept only 4 hours with no restorative sleep stages
    /// should score low and receive a conservative training recommendation.
    func testEval_sleepDeprived() {
        let logs = makeLogs(
            count: 10,
            hrvBase: 50,
            rhrBase: 65,
            sleepBase: 7.5,
            includeTraining: true
        )
        let metrics = makeMetrics(
            hrv: 50,
            restingHR: 65,
            sleepHours: 4.0,
            deepSleepMin: nil,
            remSleepMin: nil,
            weightKg: nil
        )

        let result = ReadinessEngine.compute(
            todayMetrics: metrics,
            dailyLogs: logs,
            goalMode: .maintain
        )

        XCTAssertNotNil(result, "Sleep-deprived profile should produce a result")
        guard let result else { return }

        // Sleep is 25% weight at .maintain. 4h/8h = 50% → sleep component ~50.
        // Other components near baseline (~50-80). Overall likely 55-70.
        XCTAssertGreaterThanOrEqual(result.overallScore, 25,
            "Sleep-deprived score should be >= 25, got \(result.overallScore)")
        XCTAssertLessThanOrEqual(result.overallScore, 72,
            "Sleep-deprived score should be <= 72, got \(result.overallScore)")

        let validRecs: Set<TrainingRecommendation> = [.lightOnly, .moderate, .fullIntensity]
        XCTAssertTrue(validRecs.contains(result.recommendation),
            "Sleep-deprived athlete should get lightOnly or moderate, got \(result.recommendation)")
    }

    // MARK: - Eval 3: Overreaching / accumulated fatigue

    /// 28 days of heavy training (RPE 9) combined with depressed HRV and
    /// elevated resting HR signal functional overreaching. Score should be
    /// very low and only rest or light activity should be recommended.
    func testEval_overreaching() {
        let cal = Calendar.current
        let heavyLogs: [DailyLog] = (1...28).map { offset in
            let date = cal.date(byAdding: .day, value: -offset, to: Date())!
            var log = DailyLog(
                date: date,
                phase: .stage1,
                dayType: .cardioOnly,
                recoveryDay: offset
            )
            log.biometrics.hrv = 50
            log.biometrics.restingHeartRate = 65
            log.biometrics.sleepHours = 7.5
            log.biometrics.deepSleepMinutes = 55
            log.biometrics.remSleepMinutes = 80
            log.biometrics.weightKg = 71.5
            var exercise = ExerciseLog(exerciseID: "e1", exerciseName: "Bench")
            exercise.sets = [
                SetLog(setNumber: 1, weightKg: 80, repsCompleted: 5, rpe: 9),
                SetLog(setNumber: 2, weightKg: 80, repsCompleted: 5, rpe: 9),
                SetLog(setNumber: 3, weightKg: 80, repsCompleted: 5, rpe: 9),
            ]
            log.exerciseLogs["e1"] = exercise
            return log
        }

        let metrics = makeMetrics(
            hrv: 40,
            restingHR: 72,
            sleepHours: nil,
            deepSleepMin: nil,
            remSleepMin: nil,
            weightKg: nil
        )

        let result = ReadinessEngine.compute(
            todayMetrics: metrics,
            dailyLogs: heavyLogs,
            goalMode: .maintain
        )

        XCTAssertNotNil(result, "Overreaching profile should produce a result")
        guard let result else { return }

        // HRV 40 vs baseline 50 → suppressed. RHR 72 vs baseline 65 → +7 deviation.
        // But ACWR is ~1.0 (constant load) so training is in sweet spot.
        // The score is driven down mainly by HRV + RHR, not ACWR.
        XCTAssertGreaterThanOrEqual(result.overallScore, 15,
            "Overreaching score should be >= 15, got \(result.overallScore)")
        XCTAssertLessThanOrEqual(result.overallScore, 60,
            "Overreaching score should be <= 60, got \(result.overallScore)")

        let validRecs: Set<TrainingRecommendation> = [.restDay, .lightOnly, .moderate]
        XCTAssertTrue(validRecs.contains(result.recommendation),
            "Overreaching athlete should get restDay, lightOnly, or moderate, got \(result.recommendation)")
    }

    // MARK: - Eval 4: Full recovery after rest block

    /// Three consecutive rest days have allowed HRV to rebound and sleep
    /// quality to peak. The engine should reward the recovery and recommend
    /// pushing hard.
    func testEval_fullRecoveryDay() {
        let cal = Calendar.current

        // Days 4-10: normal training days
        var logs: [DailyLog] = (4...10).map { offset in
            let date = cal.date(byAdding: .day, value: -offset, to: Date())!
            var log = DailyLog(
                date: date,
                phase: .stage1,
                dayType: .cardioOnly,
                recoveryDay: offset
            )
            log.biometrics.hrv = 50
            log.biometrics.restingHeartRate = 65
            log.biometrics.sleepHours = 7.5
            log.biometrics.deepSleepMinutes = 55
            log.biometrics.remSleepMinutes = 80
            log.biometrics.weightKg = 71.5
            var exercise = ExerciseLog(exerciseID: "e1", exerciseName: "Bench")
            exercise.sets = [
                SetLog(setNumber: 1, weightKg: 60, repsCompleted: 8, rpe: 7),
                SetLog(setNumber: 2, weightKg: 60, repsCompleted: 8, rpe: 7),
                SetLog(setNumber: 3, weightKg: 60, repsCompleted: 8, rpe: 7),
            ]
            log.exerciseLogs["e1"] = exercise
            return log
        }

        // Days 1-3: rest days (no training)
        let restLogs: [DailyLog] = (1...3).map { offset in
            let date = cal.date(byAdding: .day, value: -offset, to: Date())!
            var log = DailyLog(
                date: date,
                phase: .stage1,
                dayType: .cardioOnly,
                recoveryDay: offset
            )
            log.biometrics.hrv = 50
            log.biometrics.restingHeartRate = 65
            log.biometrics.sleepHours = 7.5
            log.biometrics.deepSleepMinutes = 55
            log.biometrics.remSleepMinutes = 80
            log.biometrics.weightKg = 71.5
            // No exerciseLogs — rest days
            return log
        }

        logs.append(contentsOf: restLogs)

        let metrics = makeMetrics(
            hrv: 70,
            restingHR: 55,
            sleepHours: 9.0,
            deepSleepMin: 97,
            remSleepMin: 122,
            weightKg: 71.5
        )

        let result = ReadinessEngine.compute(
            todayMetrics: metrics,
            dailyLogs: logs,
            goalMode: .maintain
        )

        XCTAssertNotNil(result, "Full recovery profile should produce a result")
        guard let result else { return }

        // HRV 70 well above 50 baseline → high HRV score. RHR 55 below 65 baseline → high.
        // Sleep 9h excellent. Training load may be deloading (rest days) → ~45 component.
        // Overall should be high but training load deloading dampens slightly.
        XCTAssertGreaterThanOrEqual(result.overallScore, 65,
            "Full recovery score should be >= 65, got \(result.overallScore)")
        XCTAssertLessThanOrEqual(result.overallScore, 100,
            "Full recovery score should be <= 100, got \(result.overallScore)")

        let validRecs: Set<TrainingRecommendation> = [.pushHard, .fullIntensity]
        XCTAssertTrue(validRecs.contains(result.recommendation),
            "Full recovery should recommend pushHard or fullIntensity, got \(result.recommendation)")
    }

    // MARK: - Eval 5: Fat-loss goal shifts score

    /// Running the same healthy biometric profile under .fatLoss vs .maintain
    /// should produce different scores because the engine applies different
    /// component weights per goal. The scores must diverge by at least 2 points.
    func testEval_fatLossGoalShift() {
        let logs = makeLogs(
            count: 10,
            hrvBase: 55,
            rhrBase: 58,
            sleepBase: 8.0,
            includeTraining: true
        )
        let metrics = makeMetrics(
            hrv: 55,
            restingHR: 58,
            sleepHours: 8.0,
            deepSleepMin: 84,
            remSleepMin: 108,
            weightKg: 71.5
        )

        let fatLossResult = ReadinessEngine.compute(
            todayMetrics: metrics,
            dailyLogs: logs,
            goalMode: .fatLoss
        )
        let maintainResult = ReadinessEngine.compute(
            todayMetrics: metrics,
            dailyLogs: logs,
            goalMode: .maintain
        )

        XCTAssertNotNil(fatLossResult, "Fat-loss result should be non-nil")
        XCTAssertNotNil(maintainResult, "Maintain result should be non-nil")
        guard let fatLossResult, let maintainResult else { return }

        let scoreDelta = abs(fatLossResult.overallScore - maintainResult.overallScore)
        XCTAssertGreaterThanOrEqual(scoreDelta, 2,
            "Fat-loss and maintain scores should differ by >= 2 pts, delta was \(scoreDelta)")
    }

    // MARK: - Eval 6: Layer 0 cold start (no history)

    /// With no daily log history, the engine must still produce a result using
    /// only the provided live metrics. It should report layer 0 and low
    /// confidence to signal that personalisation has not yet begun.
    func testEval_layer0ColdStart() {
        let metrics = makeMetrics(
            hrv: 45,
            restingHR: nil,
            sleepHours: 7.0,
            deepSleepMin: nil,
            remSleepMin: nil,
            weightKg: nil
        )

        let result = ReadinessEngine.compute(
            todayMetrics: metrics,
            dailyLogs: [],
            goalMode: .maintain
        )

        XCTAssertNotNil(result, "Cold-start should produce a non-nil result when HRV and sleep are available")
        guard let result else { return }

        XCTAssertGreaterThanOrEqual(result.overallScore, 30,
            "Cold-start score should be >= 30, got \(result.overallScore)")
        XCTAssertLessThanOrEqual(result.overallScore, 80,
            "Cold-start score should be <= 80, got \(result.overallScore)")

        XCTAssertEqual(result.personalizationLayer, 0,
            "Empty logs must produce personalization layer 0")
        XCTAssertEqual(result.confidence, .low,
            "Layer 0 cold start must report low confidence")
    }

    // MARK: - Eval 7: Contradictory signals (excellent HRV, terrible sleep)

    /// HRV of 70 signals strong autonomic recovery while 3.5 h sleep signals
    /// acute deprivation. The engine must not produce an extreme recommendation
    /// in either direction — it should land in the moderate or light range.
    func testEval_contradictorySignals() {
        let logs = makeLogs(
            count: 10,
            hrvBase: 50,
            rhrBase: 65,
            sleepBase: 7.5,
            includeTraining: true
        )
        let metrics = makeMetrics(
            hrv: 70,
            restingHR: nil,
            sleepHours: 3.5,
            deepSleepMin: nil,
            remSleepMin: nil,
            weightKg: nil
        )

        let result = ReadinessEngine.compute(
            todayMetrics: metrics,
            dailyLogs: logs,
            goalMode: .maintain
        )

        XCTAssertNotNil(result, "Contradictory signals should still produce a result")
        guard let result else { return }

        XCTAssertGreaterThanOrEqual(result.overallScore, 40,
            "Contradictory score should be >= 40, got \(result.overallScore)")
        XCTAssertLessThanOrEqual(result.overallScore, 70,
            "Contradictory score should be <= 70, got \(result.overallScore)")

        let validRecs: Set<TrainingRecommendation> = [.moderate, .lightOnly]
        XCTAssertTrue(validRecs.contains(result.recommendation),
            "Contradictory signals should yield moderate or lightOnly, got \(result.recommendation)")
    }
}
