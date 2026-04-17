import XCTest
@testable import FitTracker

final class ReadinessEngineTests: XCTestCase {

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
            // Deterministic offsets instead of random — prevents flaky tests
            let variation = Double(offset % 5) - 2.0  // cycles -2, -1, 0, 1, 2
            log.biometrics.hrv = hrvBase + variation
            log.biometrics.restingHeartRate = rhrBase + (variation * 0.6)
            log.biometrics.sleepHours = sleepBase + (variation * 0.2)
            log.biometrics.deepSleepMinutes = 55 + (variation * 2)
            log.biometrics.remSleepMinutes = 80 + (variation * 3)
            log.biometrics.weightKg = 71.5
            // Include basic training data so the ACWR component is computable
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

    // MARK: - Test 1: Layer 0, HRV + Sleep only

    func testLayer0_onlyHRVAndSleep() {
        let metrics = makeMetrics(hrv: 50, sleepHours: 7.5)
        let result = ReadinessEngine.compute(
            todayMetrics: metrics,
            dailyLogs: [],
            goalMode: .maintain
        )

        XCTAssertNotNil(result, "Should return a result when HRV and sleep are available")
        guard let result else { return }

        XCTAssertGreaterThanOrEqual(result.overallScore, 0, "Score must be >= 0")
        XCTAssertLessThanOrEqual(result.overallScore, 100, "Score must be <= 100")
        XCTAssertEqual(result.personalizationLayer, 0, "Zero logs should produce layer 0")
        XCTAssertEqual(result.confidence, .low, "Layer 0 should yield low confidence")
    }

    // MARK: - Test 2: All nil data returns nil

    func testMissingAllData_returnsNil() {
        let metrics = makeMetrics()
        let result = ReadinessEngine.compute(
            todayMetrics: metrics,
            dailyLogs: [],
            goalMode: .maintain
        )

        XCTAssertNil(result, "Should return nil when no usable data is available")
    }

    // MARK: - Test 3: Goal weights — fat loss

    func testGoalWeightShifts_fatLoss() {
        let metrics = makeMetrics(
            hrv: 50,
            restingHR: 65,
            sleepHours: 7.5,
            deepSleepMin: 90,
            remSleepMin: 110,
            weightKg: 71.5
        )
        let logs = makeLogs(count: 10)
        let result = ReadinessEngine.compute(
            todayMetrics: metrics,
            dailyLogs: logs,
            goalMode: .fatLoss
        )

        XCTAssertNotNil(result)
        guard let result else { return }

        let sleepWeight = result.appliedWeights["sleep"] ?? 0
        XCTAssertEqual(sleepWeight, 0.30, accuracy: 0.05,
                       "Fat-loss sleep weight should be ~0.30")

        let trainingWeight = result.appliedWeights["training"] ?? 0
        XCTAssertEqual(trainingWeight, 0.15, accuracy: 0.05,
                       "Fat-loss training weight should be ~0.15")
    }

    // MARK: - Test 4: Goal weights — gain

    func testGoalWeightShifts_gain() {
        let metrics = makeMetrics(
            hrv: 50,
            restingHR: 65,
            sleepHours: 7.5,
            deepSleepMin: 90,
            remSleepMin: 110,
            weightKg: 71.5
        )
        let logs = makeLogs(count: 10)
        let result = ReadinessEngine.compute(
            todayMetrics: metrics,
            dailyLogs: logs,
            goalMode: .gain
        )

        XCTAssertNotNil(result)
        guard let result else { return }

        let trainingWeight = result.appliedWeights["training"] ?? 0
        XCTAssertEqual(trainingWeight, 0.25, accuracy: 0.05,
                       "Gain training weight should be ~0.25")
    }

    // MARK: - Test 5: Elevated RHR suppresses score

    func testRHRDeviation_suppressesScore() {
        // Build 10 days of history with rhrBase = 65
        let logs = makeLogs(count: 10, rhrBase: 65)

        // Today RHR is 72 — +7 BPM above baseline
        let metrics = makeMetrics(restingHR: 72)
        let result = ReadinessEngine.compute(
            todayMetrics: metrics,
            dailyLogs: logs,
            goalMode: .maintain
        )

        XCTAssertNotNil(result)
        guard let result else { return }

        // rhrComponent: score = 80 - deviation * 10, deviation ~7 → score ~10
        // Allow a small window given the random noise in the baseline
        XCTAssertLessThan(result.rhrScore, 30,
                          "RHR score should be significantly suppressed when RHR is +7 above baseline")
    }

    // MARK: - Test 6: Hydration warning from overnight weight drop

    func testBodyCompFlag_hydrationWarning() {
        let cal = Calendar.current
        let today = Date()

        // Build 2 logs: yesterday weight = 72.0, day before = 71.5
        var yesterdayLog = DailyLog(
            date: cal.date(byAdding: .day, value: -1, to: today)!,
            phase: .stage1,
            dayType: .restDay,
            recoveryDay: 1
        )
        yesterdayLog.biometrics.weightKg = 72.0

        var twoDaysAgoLog = DailyLog(
            date: cal.date(byAdding: .day, value: -2, to: today)!,
            phase: .stage1,
            dayType: .restDay,
            recoveryDay: 2
        )
        twoDaysAgoLog.biometrics.weightKg = 71.5

        // Today weight = 70.5: change = 1.5 / 72.0 = ~2.1%, exceeds 1% threshold
        let metrics = makeMetrics(weightKg: 70.5)
        let result = ReadinessEngine.compute(
            todayMetrics: metrics,
            dailyLogs: [yesterdayLog, twoDaysAgoLog],
            goalMode: .maintain,
            date: today
        )

        XCTAssertNotNil(result)
        guard let result else { return }

        XCTAssertTrue(
            result.bodyCompFlags.contains(.hydrationWarning),
            "Weight change >1% overnight should trigger hydrationWarning flag"
        )
    }

    // MARK: - Test 7: Personalization layer progression

    func testLayerProgression() {
        XCTAssertEqual(ReadinessEngine.personalizationLayer(logCount: 3), 0,
                       "3 logs should be layer 0")
        XCTAssertEqual(ReadinessEngine.personalizationLayer(logCount: 8), 1,
                       "8 logs should be layer 1")
        XCTAssertEqual(ReadinessEngine.personalizationLayer(logCount: 30), 2,
                       "30 logs should be layer 2")
        XCTAssertEqual(ReadinessEngine.personalizationLayer(logCount: 90), 3,
                       "90 logs should be layer 3")
    }

    // MARK: - Test 8: Recommendation enum mapping

    func testRecommendationMapping() {
        XCTAssertEqual(
            ReadinessEngine.recommendation(for: 90, flags: []),
            .pushHard,
            "Score 90 should map to pushHard"
        )
        XCTAssertEqual(
            ReadinessEngine.recommendation(for: 75, flags: []),
            .fullIntensity,
            "Score 75 should map to fullIntensity"
        )
        XCTAssertEqual(
            ReadinessEngine.recommendation(for: 55, flags: []),
            .moderate,
            "Score 55 should map to moderate"
        )
        XCTAssertEqual(
            ReadinessEngine.recommendation(for: 40, flags: []),
            .lightOnly,
            "Score 40 should map to lightOnly"
        )
        XCTAssertEqual(
            ReadinessEngine.recommendation(for: 20, flags: []),
            .restDay,
            "Score 20 should map to restDay"
        )
    }

    // MARK: - Test 9: Backward compatibility — score is in 0-100 range

    func testBackwardCompatibility() {
        let metrics = makeMetrics(
            hrv: 55,
            restingHR: 62,
            sleepHours: 8.0,
            deepSleepMin: 85,
            remSleepMin: 105,
            weightKg: 71.5
        )
        let logs = makeLogs(count: 14)
        let result = ReadinessEngine.compute(
            todayMetrics: metrics,
            dailyLogs: logs,
            goalMode: .maintain
        )

        XCTAssertNotNil(result, "Should produce a result with standard inputs")
        guard let result else { return }

        XCTAssertGreaterThanOrEqual(result.overallScore, 0,
                                    "Score must be within 0-100 range")
        XCTAssertLessThanOrEqual(result.overallScore, 100,
                                 "Score must be within 0-100 range")
    }

    // MARK: - HRV Formula Pinning (C1 regression tests)
    // These tests pin the exact score values the HRV component produces
    // for known inputs. They would have caught the pre-fix bug where
    // ratio*50 capped scores at ~65 for healthy users.

    func testHRVComponent_atBaseline_producesFifty() {
        // Build 7 days of baseline with HRV=50ms (stable baseline)
        let logs = (1...7).map { offset -> DailyLog in
            let cal = Calendar.current
            let date = cal.date(byAdding: .day, value: -offset, to: Date())!
            var log = DailyLog(date: date, phase: .stage1, dayType: .cardioOnly, recoveryDay: offset)
            log.biometrics.hrv = 50.0  // exact baseline, no noise
            return log
        }

        let score = ReadinessEngine.hrvComponent(todayHRV: 50.0, logs: logs, date: Date(), layer: 1)
        XCTAssertNotNil(score)
        XCTAssertEqual(score!, 50.0, accuracy: 1.0,
                       "At baseline (ratio=1.0), HRV score should be ~50")
    }

    func testHRVComponent_above30PercentBaseline_reachesHundred() {
        // At +30% deviation in ln-space, score should reach 100
        // ln(50)=3.912, +30% = 5.085, e^5.085 ≈ 161.6ms
        let logs = (1...7).map { offset -> DailyLog in
            let cal = Calendar.current
            let date = cal.date(byAdding: .day, value: -offset, to: Date())!
            var log = DailyLog(date: date, phase: .stage1, dayType: .cardioOnly, recoveryDay: offset)
            log.biometrics.hrv = 50.0
            return log
        }

        let score = ReadinessEngine.hrvComponent(todayHRV: 161.6, logs: logs, date: Date(), layer: 1)
        XCTAssertNotNil(score)
        XCTAssertGreaterThanOrEqual(score!, 95.0,
                                    "At +30% deviation in ln-space, HRV score should reach ~100 (was capped at ~65 pre-fix)")
    }

    func testHRVComponent_healthyDeviation_producesRealisticScore() {
        // Real-world case: user's HRV is 10% higher than baseline
        // Should produce a meaningfully positive score (not stuck near 50)
        let logs = (1...7).map { offset -> DailyLog in
            let cal = Calendar.current
            let date = cal.date(byAdding: .day, value: -offset, to: Date())!
            var log = DailyLog(date: date, phase: .stage1, dayType: .cardioOnly, recoveryDay: offset)
            log.biometrics.hrv = 50.0
            return log
        }

        let score = ReadinessEngine.hrvComponent(todayHRV: 55.0, logs: logs, date: Date(), layer: 1)
        XCTAssertNotNil(score)
        // +10% in raw HRV ≈ +2.4% in ln-space / 0.3 * 50 ≈ 4 points above 50
        XCTAssertGreaterThan(score!, 52.0,
                             "Healthy HRV deviation should produce score >50")
        XCTAssertLessThan(score!, 70.0,
                          "Small deviation should not produce score near 100")
    }

    // MARK: - Sleep Component Composite Arithmetic (T5)

    func testSleepComponent_targetValues_produceHundred() {
        // 8h sleep, 84min deep (17.5% of 480min), 108min REM (22.5% of 480min)
        // All at target values → should produce 100
        let score = ReadinessEngine.sleepComponent(
            totalHours: 8.0,
            deepMin: 84.0,   // 17.5% of 480
            remMin: 108.0,   // 22.5% of 480
            goalHours: 8.0
        )
        XCTAssertNotNil(score)
        XCTAssertEqual(score!, 100.0, accuracy: 1.0,
                       "Target sleep values should score 100")
    }

    func testSleepComponent_durationOnly_fallsBackGracefully() {
        // No deep/REM data — should use duration for all sub-scores
        let score = ReadinessEngine.sleepComponent(
            totalHours: 8.0,
            deepMin: nil,
            remMin: nil,
            goalHours: 8.0
        )
        XCTAssertNotNil(score)
        XCTAssertEqual(score!, 100.0, accuracy: 1.0,
                       "Duration at goal with no stage data should score 100")
    }

    func testSleepComponent_halfSleep_producesFifty() {
        // 4h sleep, no stage data — should score 50
        let score = ReadinessEngine.sleepComponent(
            totalHours: 4.0,
            deepMin: nil,
            remMin: nil,
            goalHours: 8.0
        )
        XCTAssertNotNil(score)
        XCTAssertEqual(score!, 50.0, accuracy: 1.0,
                       "Half the goal sleep should score ~50")
    }

    // MARK: - Training Load ACWR Scoring Bands (T2)

    func testTrainingLoad_sweetSpotACWR_producesHighScore() {
        // Consistent daily training for 28 days → ACWR ≈ 1.0, sweet spot
        // Each day: 1 exercise, 3 sets @ RPE 7, so load = 3*7*2 = 42
        let cal = Calendar.current
        let logs = (1...28).map { offset -> DailyLog in
            let date = cal.date(byAdding: .day, value: -offset, to: Date())!
            var log = DailyLog(date: date, phase: .stage1, dayType: .upperPush, recoveryDay: offset)
            var exercise = ExerciseLog(exerciseID: "e1", exerciseName: "Bench")
            exercise.sets = [
                SetLog(setNumber: 1, weightKg: 60, repsCompleted: 8, rpe: 7),
                SetLog(setNumber: 2, weightKg: 60, repsCompleted: 8, rpe: 7),
                SetLog(setNumber: 3, weightKg: 60, repsCompleted: 8, rpe: 7),
            ]
            log.exerciseLogs["e1"] = exercise
            return log
        }

        let score = ReadinessEngine.trainingLoadComponent(logs: logs, date: Date())
        XCTAssertNotNil(score)
        XCTAssertGreaterThanOrEqual(score!, 80.0,
                                    "Consistent ACWR~1.0 should be in sweet spot (80-100)")
    }

    func testTrainingLoad_noHistory_returnsNil() {
        // Empty logs → nil (insufficient data)
        let score = ReadinessEngine.trainingLoadComponent(logs: [], date: Date())
        XCTAssertNil(score, "No history should return nil")
    }

    // MARK: - RHR Component Deviation Scoring

    func testRHRComponent_atBaseline_producesEighty() {
        // RHR at baseline (7 logs with RHR=65)
        let logs = (1...7).map { offset -> DailyLog in
            let cal = Calendar.current
            let date = cal.date(byAdding: .day, value: -offset, to: Date())!
            var log = DailyLog(date: date, phase: .stage1, dayType: .cardioOnly, recoveryDay: offset)
            log.biometrics.restingHeartRate = 65.0
            return log
        }

        let score = ReadinessEngine.rhrComponent(todayRHR: 65.0, logs: logs, date: Date())
        XCTAssertNotNil(score)
        XCTAssertEqual(score!, 80.0, accuracy: 1.0,
                       "RHR at baseline should score 80 (comment states '80 at baseline')")
    }

    func testRHRComponent_fivePBMAbove_scoresThirty() {
        // +5 BPM should produce score = 80 - 50 = 30
        let logs = (1...7).map { offset -> DailyLog in
            let cal = Calendar.current
            let date = cal.date(byAdding: .day, value: -offset, to: Date())!
            var log = DailyLog(date: date, phase: .stage1, dayType: .cardioOnly, recoveryDay: offset)
            log.biometrics.restingHeartRate = 65.0
            return log
        }

        let score = ReadinessEngine.rhrComponent(todayRHR: 70.0, logs: logs, date: Date())
        XCTAssertNotNil(score)
        XCTAssertEqual(score!, 30.0, accuracy: 1.0,
                       "+5 BPM above baseline should score exactly 30 (triggers warning at <= 30)")
    }

    // MARK: - Body Comp Flags (H1 regression test)

    func testOverallScore_withBodyCompFlag_notDoublePenalized() {
        // Control: no hydration flag. Treatment: hydration flag.
        // The delta must equal ONE penalty hit, not two.
        // Pre-fix: flag caused both a component reduction AND an external
        // 5pt suppression, so the delta was ~7.5 (2.5 from component + 5
        // from external). Post-fix: delta should be ~2.5 only.
        let controlLogs = makeLogs(count: 10, includeTraining: false)
            .map { log -> DailyLog in
                var copy = log
                copy.biometrics.weightKg = 72.0  // stable weight — no flag
                return copy
            }

        let controlMetrics = makeMetrics(
            hrv: 50.0, restingHR: 65.0, sleepHours: 8.0,
            deepSleepMin: 84, remSleepMin: 108,
            weightKg: 72.0  // matches yesterday → no flag
        )

        let treatmentMetrics = makeMetrics(
            hrv: 50.0, restingHR: 65.0, sleepHours: 8.0,
            deepSleepMin: 84, remSleepMin: 108,
            weightKg: 70.5  // 1.5% drop → hydration flag
        )

        let controlResult = ReadinessEngine.compute(
            todayMetrics: controlMetrics, dailyLogs: controlLogs, goalMode: .maintain
        )
        let treatmentResult = ReadinessEngine.compute(
            todayMetrics: treatmentMetrics, dailyLogs: controlLogs, goalMode: .maintain
        )

        XCTAssertNotNil(controlResult)
        XCTAssertNotNil(treatmentResult)
        guard let control = controlResult, let treatment = treatmentResult else { return }

        XCTAssertFalse(control.bodyCompFlags.contains(.hydrationWarning),
                       "Control should have no hydration flag")
        XCTAssertTrue(treatment.bodyCompFlags.contains(.hydrationWarning),
                      "Treatment should have hydration flag")

        // The delta should be small — only the body comp component weight * 50
        // (because the component score drops from 100 to 50, and body comp
        // has 5% weight in maintain mode, that's 0.05 * 50 = 2.5 points).
        // Pre-fix, the external suppression would have added another 5pts,
        // for a total delta of ~7.5 points.
        let delta = control.overallScore - treatment.overallScore
        XCTAssertLessThanOrEqual(delta, 5,
                                 "Flag should cause ~2.5pt drop, not 7.5pt (would indicate double-penalty)")
        XCTAssertGreaterThanOrEqual(delta, 1,
                                    "Flag should cause some penalty (at least 1pt)")
    }
}
