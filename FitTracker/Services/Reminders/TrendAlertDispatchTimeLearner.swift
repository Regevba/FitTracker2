// Services/Reminders/TrendAlertDispatchTimeLearner.swift
//
// C4 feature: trend-alerts-hrv.
//
// v1 stub — returns a fixed 08:00 local dispatch time. Future C4.c
// follow-on will learn the user's typical app-open time-of-day pattern
// and adapt. For PRD-1, the fixed advisory morning slot suffices.
//
// Stateless pure function. Caller combines the returned wall-clock
// components with the target date via Calendar.

import Foundation

@MainActor
enum TrendAlertDispatchTimeLearner {

    /// v1 fixed dispatch hour (24h clock).
    static let fixedHour = 8

    /// v1 fixed dispatch minute.
    static let fixedMinute = 0

    /// Returns wall-clock components for today's dispatch time.
    /// v1: always 08:00 local. Caller responsible for combining with
    /// today's date via Calendar.date(bySettingHour:...).
    static func dispatchTime() -> DateComponents {
        DateComponents(hour: fixedHour, minute: fixedMinute)
    }

    /// Combine the dispatch time-of-day with a target date to produce a
    /// Date at that wall-clock time on the target day. Returns the
    /// target date unchanged if components combining fails (impossible
    /// in practice).
    static func combined(
        on day: Date,
        calendar: Calendar = .current
    ) -> Date {
        let dayComponents = calendar.dateComponents([.year, .month, .day], from: day)
        var combined = DateComponents()
        combined.year   = dayComponents.year
        combined.month  = dayComponents.month
        combined.day    = dayComponents.day
        combined.hour   = fixedHour
        combined.minute = fixedMinute
        return calendar.date(from: combined) ?? day
    }
}
