// Models/TrainingProgramTemplates.swift
// C6 training-program-customization (2026-06-02)
//
// fixedPPLDays() returns the current 6-day PPL split as a [CustomDay] array
// for the migration's first-customize "Start from current PPL" flow + the
// fallback resolver when activeProgramID is nil.
//
// starterTemplates exposes the 4 starter templates referenced in
// NewProgramSheet. Each template is materialized from the existing catalog
// so updates flow through automatically.

import Foundation

extension TrainingProgramData {

    // MARK: - Fixed PPL snapshot

    /// Snapshot of the existing fixed 6-day PPL split as a [CustomDay] array.
    /// Sun=Rest, Mon=Upper Push, Tue=Lower, Wed=Rest, Thu=Upper Pull,
    /// Fri=Full Body, Sat=Cardio Only.
    ///
    /// This is the default the user sees pre-customization AND the fallback
    /// when `activeProgramID == nil`.
    static func fixedPPLDays() -> [CustomDay] {
        let upperPushDay = makeDay(
            name: "Upper Push", dayType: .upperPush, weekdayIndex: 1
        )
        let lowerDay = makeDay(
            name: "Lower Body", dayType: .lowerBody, weekdayIndex: 2
        )
        let upperPullDay = makeDay(
            name: "Upper Pull", dayType: .upperPull, weekdayIndex: 4
        )
        let fullBodyDay = makeDay(
            name: "Full Body", dayType: .fullBody, weekdayIndex: 5
        )
        let cardioDay = makeDay(
            name: "Cardio Only", dayType: .cardioOnly, weekdayIndex: 6
        )

        return [
            CustomDay(name: "Rest Day", dayType: .restDay, weekdayIndex: 0, slots: []),
            upperPushDay,
            lowerDay,
            CustomDay(name: "Rest Day", dayType: .restDay, weekdayIndex: 3, slots: []),
            upperPullDay,
            fullBodyDay,
            cardioDay,
        ]
    }

    // MARK: - Starter templates

    /// 4 starter templates exposed in NewProgramSheet.
    /// Materialized lazily per call so each program save gets fresh UUIDs.
    static func template(_ id: TemplateID) -> CustomProgram {
        switch id {
        case .ppl6Day:
            return CustomProgram(
                name: id.defaultProgramName,
                days: fixedPPLDays()
            )
        case .upperLower4Day:
            return upperLowerTemplate()
        case .fullBody3Day:
            return fullBody3DayTemplate()
        case .empty:
            return emptyTemplate()
        }
    }

    // MARK: - Private template builders

    private static func makeDay(name: String, dayType: DayType, weekdayIndex: Int) -> CustomDay {
        let exercises = TrainingProgramData.exercises(for: dayType)
        let slots = exercises.enumerated().map { idx, ex in
            ExerciseSlot(exerciseID: ex.id, order: idx)
        }
        return CustomDay(name: name, dayType: dayType, weekdayIndex: weekdayIndex, slots: slots)
    }

    /// Upper/Lower 4-day split — Upper A / Lower A / Upper B / Lower B + 3 rest.
    /// Maps onto the existing 4 strength DayTypes:
    ///   Mon Upper A = upperPush, Tue Lower A = lowerBody,
    ///   Thu Upper B = upperPull, Fri Lower B = fullBody (as a "Lower B" variant).
    private static func upperLowerTemplate() -> CustomProgram {
        let upperA = makeDay(name: "Upper A", dayType: .upperPush, weekdayIndex: 1)
        let lowerA = makeDay(name: "Lower A", dayType: .lowerBody, weekdayIndex: 2)
        let upperB = makeDay(name: "Upper B", dayType: .upperPull, weekdayIndex: 4)
        let lowerB = makeDay(name: "Lower B", dayType: .fullBody, weekdayIndex: 5)
        return CustomProgram(
            name: TemplateID.upperLower4Day.defaultProgramName,
            days: [
                CustomDay(name: "Rest Day", dayType: .restDay, weekdayIndex: 0, slots: []),
                upperA,
                lowerA,
                CustomDay(name: "Rest Day", dayType: .restDay, weekdayIndex: 3, slots: []),
                upperB,
                lowerB,
                CustomDay(name: "Rest Day", dayType: .restDay, weekdayIndex: 6, slots: []),
            ]
        )
    }

    /// Full-body 3-day split — Mon/Wed/Fri full body + 4 rest.
    private static func fullBody3DayTemplate() -> CustomProgram {
        let mon = makeDay(name: "Full Body A", dayType: .fullBody, weekdayIndex: 1)
        let wed = makeDay(name: "Full Body B", dayType: .fullBody, weekdayIndex: 3)
        let fri = makeDay(name: "Full Body C", dayType: .fullBody, weekdayIndex: 5)
        return CustomProgram(
            name: TemplateID.fullBody3Day.defaultProgramName,
            days: [
                CustomDay(name: "Rest Day", dayType: .restDay, weekdayIndex: 0, slots: []),
                mon,
                CustomDay(name: "Rest Day", dayType: .restDay, weekdayIndex: 2, slots: []),
                wed,
                CustomDay(name: "Rest Day", dayType: .restDay, weekdayIndex: 4, slots: []),
                fri,
                CustomDay(name: "Rest Day", dayType: .restDay, weekdayIndex: 6, slots: []),
            ]
        )
    }

    /// Empty template — 7 days named "Day 1".."Day 7", all dayType .restDay,
    /// no exercise slots. User fills in per their plan (PRD OQ-1).
    private static func emptyTemplate() -> CustomProgram {
        let days = (0..<7).map { idx in
            CustomDay(
                name: "Day \(idx + 1)",
                dayType: .restDay,
                weekdayIndex: idx,
                slots: []
            )
        }
        return CustomProgram(
            name: TemplateID.empty.defaultProgramName,
            days: days
        )
    }
}
