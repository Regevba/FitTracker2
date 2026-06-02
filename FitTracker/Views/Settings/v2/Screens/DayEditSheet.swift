// Views/Settings/v2/Screens/DayEditSheet.swift
// C6 training-program-customization (2026-06-02) — Surface 4.
//
// Sub-modal opened from the gear icon on a day section in the editor.
// Allows: rename day, change DayType, move to a different weekday, duplicate.
//
// Fires training_day_edited once per field changed on Save.

import SwiftUI

struct DayEditSheet: View {
    @Binding var day: CustomDay
    var onSave: () -> Void
    var onDuplicate: ((Int) -> Void)?

    @EnvironmentObject private var analytics: AnalyticsService
    @Environment(\.dismiss) private var dismiss

    @State private var draftName: String
    @State private var draftDayType: DayType
    @State private var draftWeekday: Int
    @State private var duplicateTargetWeekday: Int
    @State private var initialName: String
    @State private var initialDayType: DayType
    @State private var initialWeekday: Int

    init(
        day: Binding<CustomDay>,
        onSave: @escaping () -> Void,
        onDuplicate: ((Int) -> Void)? = nil
    ) {
        self._day = day
        self.onSave = onSave
        self.onDuplicate = onDuplicate
        self._draftName = State(initialValue: day.wrappedValue.name)
        self._draftDayType = State(initialValue: day.wrappedValue.dayType)
        self._draftWeekday = State(initialValue: day.wrappedValue.weekdayIndex)
        self._duplicateTargetWeekday = State(initialValue: (day.wrappedValue.weekdayIndex + 1) % 7)
        self._initialName = State(initialValue: day.wrappedValue.name)
        self._initialDayType = State(initialValue: day.wrappedValue.dayType)
        self._initialWeekday = State(initialValue: day.wrappedValue.weekdayIndex)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Day name", text: $draftName)
                        .autocorrectionDisabled(true)
                        .accessibilityLabel("Day name")
                }
                Section("Day Type") {
                    Picker("Day Type", selection: $draftDayType) {
                        ForEach(DayType.allCases, id: \.rawValue) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                }
                Section("Weekday") {
                    Picker("Weekday", selection: $draftWeekday) {
                        ForEach(0..<7, id: \.self) { idx in
                            Text(Self.weekdayName(idx)).tag(idx)
                        }
                    }
                    .pickerStyle(.menu)
                }
                if onDuplicate != nil {
                    Section("Duplicate To Weekday") {
                        Picker("Duplicate target", selection: $duplicateTargetWeekday) {
                            ForEach(0..<7, id: \.self) { idx in
                                Text(Self.weekdayName(idx)).tag(idx)
                            }
                        }
                        .pickerStyle(.menu)
                        Button("Duplicate") {
                            onDuplicate?(duplicateTargetWeekday)
                            dismiss()
                        }
                        .accessibilityLabel("Duplicate this day to \(Self.weekdayName(duplicateTargetWeekday))")
                    }
                }
            }
            .navigationTitle("Edit Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { handleSave() }
                        .disabled(draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    // MARK: - Helpers

    private static func weekdayName(_ index: Int) -> String {
        let symbols = Calendar.current.standaloneWeekdaySymbols
        guard index >= 0 && index < symbols.count else { return "?" }
        return symbols[index]
    }

    private func handleSave() {
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed != initialName {
            day.name = trimmed
            analytics.logTrainingDayEdited(dayId: day.id.uuidString, field: "name")
        }
        if draftDayType != initialDayType {
            day.dayType = draftDayType
            analytics.logTrainingDayEdited(dayId: day.id.uuidString, field: "day_type")
        }
        if draftWeekday != initialWeekday {
            day.weekdayIndex = draftWeekday
            analytics.logTrainingDayEdited(dayId: day.id.uuidString, field: "weekday")
        }
        onSave()
        dismiss()
    }
}
