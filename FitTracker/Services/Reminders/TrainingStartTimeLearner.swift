// Services/Reminders/TrainingStartTimeLearner.swift
//
// C2 feature: readiness-aware-training-alert (parent: smart-reminders).
//
// Learns the user's typical training start time-of-day from recent workout
// history. The C2 observer fires its push notification 30 minutes BEFORE
// this learned time. If no history exists or the user's pattern is too
// noisy, falls back to 18:00 local (the prevailing post-work default in
// FitMe's WAU cohort — see master plan §1.4).
//
// Pure function over an array of DailyLog with `sessionStartTime` populated.
// Stateless — caller provides the history slice (typically last 30 days).
//
// Algorithm: median time-of-day extracted from sessionStartTime entries. The
// median is preferred over mean to resist outliers (one Sunday 9am session
// shouldn't shift a Tue/Thu 18:00 routine).
//
// Time-of-day is computed via Calendar components (hour + minute), not raw
// UNIX seconds — so the result is wall-clock 18:00 regardless of date.

import Foundation

@MainActor
enum TrainingStartTimeLearner {

    /// Fallback time-of-day when history is empty or below quorum.
    /// 18:00 local — chosen against FitMe's WAU cohort default workout window.
    private static let fallbackHour = 18
    private static let fallbackMinute = 0

    /// Minimum number of non-rest training entries within the lookback window
    /// required before we trust the learned median. Below this, fallback.
    static let quorum = 5

    /// Learn the user's typical training start time from recent history.
    /// Returns wall-clock components (hour + minute) on a reference date the
    /// caller is responsible for combining with today's date.
    ///
    /// - Parameters:
    ///   - history: recent DailyLog entries. Empty array returns fallback.
    ///   - calendar: injected for testability. Defaults to `.current`.
    /// - Returns: a DateComponents containing `hour` + `minute`.
    static func learn(
        history: [DailyLog],
        calendar: Calendar = .current
    ) -> DateComponents {

        let sessionStartTimes = history.compactMap(\.sessionStartTime)

        guard sessionStartTimes.count >= quorum else {
            return fallback()
        }

        let minutesSinceMidnight = sessionStartTimes.map {
            let components = calendar.dateComponents([.hour, .minute], from: $0)
            return (components.hour ?? 0) * 60 + (components.minute ?? 0)
        }.sorted()

        let medianMinutes = minutesSinceMidnight[minutesSinceMidnight.count / 2]
        return DateComponents(
            hour: medianMinutes / 60,
            minute: medianMinutes % 60
        )
    }

    /// Combine a learned time-of-day with a target date to produce a Date
    /// at that wall-clock time on the target day. If components combining
    /// fails (impossible in practice), returns the target date unchanged.
    static func combined(
        timeOfDay: DateComponents,
        on day: Date,
        calendar: Calendar = .current
    ) -> Date {
        let dayComponents = calendar.dateComponents([.year, .month, .day], from: day)
        var combined = DateComponents()
        combined.year   = dayComponents.year
        combined.month  = dayComponents.month
        combined.day    = dayComponents.day
        combined.hour   = timeOfDay.hour
        combined.minute = timeOfDay.minute
        return calendar.date(from: combined) ?? day
    }

    private static func fallback() -> DateComponents {
        DateComponents(hour: fallbackHour, minute: fallbackMinute)
    }
}
