// FitTracker/Views/Training/v2/SetRowView.swift
// v2 — UX Foundations-aligned rewrite of SetRowView.
// Design-system compliant: zero raw literals, semantic tokens only.
// Fixes: F26 (44pt delete tap target), F16 (persistent logged checkmark).
import SwiftUI

struct SetRowView: View {
    // MARK: - Parameters

    let setIndex: Int
    let previousWeight: Double?
    let previousReps: Int?
    @Binding var currentWeight: Double?
    @Binding var currentReps: Int?
    let isLogged: Bool
    let onLog: () -> Void
    let onCopyLast: () -> Void
    let onDelete: () -> Void

    // MARK: - Local State

    @State private var weightText: String = ""
    @State private var repsText: String = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Derived

    private var hasPreviousData: Bool {
        previousWeight != nil || previousReps != nil
    }

    private var previousWeightFormatted: String? {
        previousWeight.map(formatWeight)
    }

    private var previousRepsFormatted: String? {
        previousReps.map(String.init)
    }

    // MARK: - Body

    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.xxSmall) {
            setLabel

            weightField

            separator

            repsField

            Spacer(minLength: AppSpacing.xxxSmall)

            actionArea

            deleteButton
        }
        .padding(.horizontal, AppSpacing.xSmall)
        .padding(.vertical, AppSpacing.xxSmall)
        .frame(minHeight: 44)
        .background(
            isLogged
                ? AppColor.Status.success.opacity(0.08)
                : AppColor.Surface.materialLight,
            in: RoundedRectangle(cornerRadius: AppRadius.xSmall)
        )
        .onAppear { syncLocalState() }
        .onChange(of: currentWeight) { _, _ in syncLocalState() }
        .onChange(of: currentReps) { _, _ in syncLocalState() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Set \(setIndex)")
        .accessibilityValue(accessibilityValueText)
    }

    // MARK: - Set Label

    private var setLabel: some View {
        Text("Set \(setIndex)")
            .font(AppText.captionStrong)
            .foregroundStyle(AppColor.Text.secondary)
            .frame(minWidth: 44, alignment: .leading)
    }

    // MARK: - Weight Field

    private var weightField: some View {
        VStack(alignment: .leading, spacing: AppSpacing.micro) {
            TextField("0", text: $weightText)
                .font(AppText.monoMetric)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .padding(.vertical, AppSpacing.xxxSmall)
                .padding(.horizontal, AppSpacing.xxSmall)
                .background(
                    AppColor.Surface.secondary,
                    in: RoundedRectangle(cornerRadius: AppRadius.xSmall)
                )
                .frame(minWidth: 56)
                .onChange(of: weightText) { _, newValue in
                    currentWeight = Double(newValue)
                }
                .accessibilityLabel("Weight in kilograms")
                .accessibilityValue(weightText.isEmpty ? "empty" : "\(weightText) kg")

            if let prev = previousWeightFormatted, weightText.isEmpty {
                quickFillHint("Last \(prev) kg")
            }
        }
    }

    // MARK: - Separator

    private var separator: some View {
        Text("×")
            .font(AppText.captionStrong)
            .foregroundStyle(AppColor.Text.tertiary)
    }

    // MARK: - Reps Field

    private var repsField: some View {
        VStack(alignment: .leading, spacing: AppSpacing.micro) {
            TextField("0", text: $repsText)
                .font(AppText.monoMetric)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .padding(.vertical, AppSpacing.xxxSmall)
                .padding(.horizontal, AppSpacing.xxSmall)
                .background(
                    AppColor.Surface.secondary,
                    in: RoundedRectangle(cornerRadius: AppRadius.xSmall)
                )
                .frame(minWidth: 44)
                .onChange(of: repsText) { _, newValue in
                    currentReps = Int(newValue)
                }
                .accessibilityLabel("Repetitions")
                .accessibilityValue(repsText.isEmpty ? "empty" : "\(repsText) reps")

            if let prev = previousRepsFormatted, repsText.isEmpty {
                quickFillHint("Last \(prev)")
            }
        }
    }

    // MARK: - Quick-Fill Hint

    private func quickFillHint(_ text: String) -> some View {
        Text(text)
            .font(AppText.caption)
            .foregroundStyle(AppColor.Accent.recovery)
            .lineLimit(1)
    }

    // MARK: - Action Area (Checkmark or Buttons)

    @ViewBuilder
    private var actionArea: some View {
        if isLogged {
            // F16 fix: persistent checkmark on logged sets
            Image(systemName: "checkmark.circle.fill")
                .font(AppText.iconMedium)
                .foregroundStyle(AppColor.Status.success)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel("Set logged")
        } else {
            HStack(spacing: AppSpacing.xxSmall) {
                if hasPreviousData {
                    Button(action: {
                        copyLastValues()
                        onCopyLast()
                    }) {
                        Text("Copy Last")
                            .font(AppText.captionStrong)
                            .foregroundStyle(AppColor.Accent.recovery)
                            .padding(.horizontal, AppSpacing.xxSmall)
                            .padding(.vertical, AppSpacing.xxxSmall)
                            .background(
                                AppColor.Accent.recovery.opacity(0.14),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                    .frame(minHeight: 44)
                    .accessibilityLabel("Copy last session values")
                    .accessibilityHint("Fills weight and reps from previous session")
                }

                Button(action: onLog) {
                    Text("Log")
                        .font(AppText.captionStrong)
                        .foregroundStyle(AppColor.Brand.warm)
                        .padding(.horizontal, AppSpacing.xSmall)
                        .padding(.vertical, AppSpacing.xxxSmall)
                        .background(
                            AppColor.Brand.warm.opacity(0.14),
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
                .frame(minHeight: 44)
                .accessibilityLabel("Log set \(setIndex)")
                .accessibilityHint("Records the current weight and reps")
            }
        }
    }

    // MARK: - Delete Button (F26: ≥44pt tap target)

    private var deleteButton: some View {
        Button(action: onDelete) {
            Image(systemName: "xmark.circle.fill")
                .font(AppText.iconSmall)
                .foregroundStyle(AppColor.Status.error)
        }
        .buttonStyle(.plain)
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel("Delete set \(setIndex)")
        .accessibilityHint("Removes this set from the exercise")
    }

    // MARK: - Helpers

    private func syncLocalState() {
        weightText = currentWeight.map(formatWeight) ?? ""
        repsText = currentReps.map(String.init) ?? ""
    }

    private func formatWeight(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(value))
            : String(format: "%.1f", value)
    }

    private func copyLastValues() {
        if let prevWeight = previousWeight {
            weightText = formatWeight(prevWeight)
            currentWeight = prevWeight
        }
        if let prevReps = previousReps {
            repsText = String(prevReps)
            currentReps = prevReps
        }
    }

    private var accessibilityValueText: String {
        if isLogged, let w = currentWeight, let r = currentReps {
            return "\(formatWeight(w)) kg, \(r) reps"
        }
        return "Not logged"
    }
}

// MARK: - Preview

#if DEBUG
#Preview("SetRowView – Not Logged") {
    VStack(spacing: AppSpacing.xSmall) {
        SetRowView(
            setIndex: 1,
            previousWeight: 80.0,
            previousReps: 10,
            currentWeight: .constant(nil),
            currentReps: .constant(nil),
            isLogged: false,
            onLog: {},
            onCopyLast: {},
            onDelete: {}
        )

        SetRowView(
            setIndex: 2,
            previousWeight: nil,
            previousReps: nil,
            currentWeight: .constant(nil),
            currentReps: .constant(nil),
            isLogged: false,
            onLog: {},
            onCopyLast: {},
            onDelete: {}
        )
    }
    .padding()
    .background(AppGradient.screenBackground)
}

#Preview("SetRowView – Logged") {
    SetRowView(
        setIndex: 1,
        previousWeight: 80.0,
        previousReps: 10,
        currentWeight: .constant(82.5),
        currentReps: .constant(10),
        isLogged: true,
        onLog: {},
        onCopyLast: {},
        onDelete: {}
    )
    .padding()
    .background(AppGradient.screenBackground)
}
#endif
