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
        sleepBase: Double = 7.5
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
            log.biometrics.hrv = hrvBase + Double.random(in: -5...5)
            log.biometrics.restingHeartRate = rhrBase + Double.random(in: -3...3)
            log.biometrics.sleepHours = sleepBase + Double.random(in: -1...1)
            log.biometrics.deepSleepMinutes = 55 + Double.random(in: -10...10)
            log.biometrics.remSleepMinutes = 80 + Double.random(in: -15...15)
            log.biometrics.weightKg = 71.5
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
}
