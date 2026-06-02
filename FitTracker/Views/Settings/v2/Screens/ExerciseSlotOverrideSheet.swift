// Views/Settings/v2/Screens/ExerciseSlotOverrideSheet.swift
// C6 training-program-customization (2026-06-02) — Surface 5.
//
// Modal opened by tapping an exercise row in the editor. Surfaces 3 nil-
// defaulted override fields (sets / reps / rest) with the catalog defaults
// shown as placeholders.
//
// Save persists overrides into the bound ExerciseSlot. "Reset to catalog
// defaults" clears all 3 overrides to nil.

import SwiftUI

struct ExerciseSlotOverrideSheet: View {
    @Binding var slot: ExerciseSlot
    let exercise: ExerciseDefinition  // canonical catalog entry (for default values)
    var onSave: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var setsText: String = ""
    @State private var repsText: String = ""
    @State private var restText: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise") {
                    Text(exercise.name)
                        .font(AppText.body)
                        .foregroundStyle(AppColor.Text.primary)
                }

                Section("Sets") {
                    TextField("\(exercise.targetSets)", text: $setsText)
                        .keyboardType(.numberPad)
                        .accessibilityLabel("Sets override")
                    if !setsText.isEmpty {
                        Text("Catalog default: \(exercise.targetSets)")
                            .font(AppText.caption)
                            .foregroundStyle(AppColor.Text.secondary)
                    }
                }

                Section("Reps") {
                    TextField(exercise.targetReps, text: $repsText)
                        .autocorrectionDisabled(true)
                        .accessibilityLabel("Reps override")
                    if !repsText.isEmpty {
                        Text("Catalog default: \(exercise.targetReps)")
                            .font(AppText.caption)
                            .foregroundStyle(AppColor.Text.secondary)
                    }
                }

                Section("Rest (seconds)") {
                    TextField("\(exercise.restSeconds)", text: $restText)
                        .keyboardType(.numberPad)
                        .accessibilityLabel("Rest seconds override")
                    if !restText.isEmpty {
                        Text("Catalog default: \(exercise.restSeconds)s")
                            .font(AppText.caption)
                            .foregroundStyle(AppColor.Text.secondary)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        resetAll()
                    } label: {
                        Text("Reset to catalog defaults")
                    }
                    .accessibilityLabel("Reset all overrides to catalog defaults")
                }
            }
            .navigationTitle("Override")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { handleSave() }
                }
            }
            .onAppear { loadFromSlot() }
        }
    }

    // MARK: - Helpers

    private func loadFromSlot() {
        setsText = slot.targetSetsOverride.map(String.init) ?? ""
        repsText = slot.targetRepsOverride ?? ""
        restText = slot.restSecondsOverride.map(String.init) ?? ""
    }

    private func resetAll() {
        setsText = ""
        repsText = ""
        restText = ""
    }

    private func handleSave() {
        slot.targetSetsOverride = Int(setsText.trimmingCharacters(in: .whitespaces))
        let trimmedReps = repsText.trimmingCharacters(in: .whitespacesAndNewlines)
        slot.targetRepsOverride = trimmedReps.isEmpty ? nil : trimmedReps
        slot.restSecondsOverride = Int(restText.trimmingCharacters(in: .whitespaces))
        onSave()
        dismiss()
    }
}
