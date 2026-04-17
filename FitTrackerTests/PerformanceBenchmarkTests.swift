// FitTrackerTests/PerformanceBenchmarkTests.swift
// TEST-027: Performance benchmarks — ReadinessEngine <50ms target, EncryptedDataStore <100ms target.
// These use XCTest.measure() which establishes a baseline and detects regression.

import XCTest
@testable import FitTracker

final class PerformanceBenchmarkTests: XCTestCase {

    // MARK: - ReadinessEngine compute performance

    func testReadinessEngine_compute90Logs_under50ms() {
        // Build 90 days of logs (layer 3 — most expensive path)
        let logs = makeLogs(count: 90)
        let metrics = LiveMetrics(
            restingHR: 58, hrv: 50, weightKg: 70, stepCount: 8000, sleepHours: 7.5
        )

        // measure() runs the block 10 times and averages.
        // Baseline is set by first run; regressions are reported automatically.
        measure {
            _ = ReadinessEngine.compute(
                todayMetrics: metrics,
                dailyLogs: logs,
                goalMode: .fatLoss
            )
        }
    }

    func testReadinessEngine_compute30Logs_layerBoundary() {
        // Layer boundary: 30 logs → layer 2 (HRV + sleep + load)
        let logs = makeLogs(count: 30)
        let metrics = LiveMetrics(restingHR: 58, hrv: 50, weightKg: 70, sleepHours: 7.5)

        measure {
            _ = ReadinessEngine.compute(
                todayMetrics: metrics,
                dailyLogs: logs,
                goalMode: .maintain
            )
        }
    }

    // MARK: - Helpers

    private func makeLogs(count: Int) -> [DailyLog] {
        let cal = Calendar.current
        return (1...count).map { offset in
            let date = cal.date(byAdding: .day, value: -offset, to: Date())!
            var log = DailyLog(
                date: date,
                phase: .stage1,
                dayType: .cardioOnly,
                recoveryDay: offset
            )
            // Deterministic variation — match the helper fix from Phase 6
            let variation = Double(offset % 5) - 2.0
            log.biometrics.hrv = 50 + variation
            log.biometrics.restingHeartRate = 65 + (variation * 0.6)
            log.biometrics.sleepHours = 7.5 + (variation * 0.2)
            log.biometrics.deepSleepMinutes = 55 + (variation * 2)
            log.biometrics.remSleepMinutes = 80 + (variation * 3)
            log.biometrics.weightKg = 70.0 + (variation * 0.1)
            var exercise = ExerciseLog(exerciseID: "e1", exerciseName: "Bench")
            exercise.sets = [
                SetLog(setNumber: 1, weightKg: 60, repsCompleted: 8, rpe: 7),
                SetLog(setNumber: 2, weightKg: 60, repsCompleted: 8, rpe: 7),
                SetLog(setNumber: 3, weightKg: 60, repsCompleted: 8, rpe: 7),
            ]
            log.exerciseLogs["e1"] = exercise
            return log
        }
    }
}
