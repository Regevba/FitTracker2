// FitTracker/Views/Training/v2/FocusModeView.swift
// Distraction-free, full-screen focus on a single exercise.
// Shows current set, weight/reps inputs, coaching cue, and a done button.
import SwiftUI

struct FocusModeView: View {
    let exercise: ExerciseDefinition
    @Binding var exerciseLog: ExerciseLog
    let onExit: () -> Void

    @EnvironmentObject private var analytics: AnalyticsService

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var weightStr = ""
    @State private var repsStr = ""

    // MARK: - Derived State

    private var nextIncompleteSetIndex: Int? {
        exerciseLog.sets.indices.first {
            exerciseLog.sets[$0].weightKg == nil
                || exerciseLog.sets[$0].repsCompleted == nil
        }
    }

    private var allSetsDone: Bool { nextIncompleteSetIndex == nil }

    // MARK: - Body

    var body: some View {
        ZStack {
            AppColor.Surface.inverse
                .ignoresSafeArea()

            VStack(spacing: AppSpacing.xLarge) {
                exitButton
                Spacer()
                exerciseHeader
                setIndicator
                inputFields
                coachingCue
                doneButton
                Spacer()
            }
        }
        .persistentSystemOverlays(.hidden)
        .onAppear {
            analytics.logTrainingFocusModeEntered()
            prefillWeightFromLastSet()
        }
    }

    // MARK: - Exit Button

    private var exitButton: some View {
        HStack {
            Spacer()
            Button(action: onExit) {
                Image(systemName: "xmark.circle.fill")
                    .font(AppText.pageTitle)
                    .foregroundStyle(AppColor.Text.inverseTertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Exit focus mode")
        }
        .padding(.horizontal, AppSpacing.large)
        .padding(.top, AppSpacing.small)
    }

    // MARK: - Exercise Header

    private var exerciseHeader: some View {
        VStack(spacing: AppSpacing.xxSmall) {
            Text("Focus Mode")
                .font(AppText.monoCaption)
                .tracking(1.2)
                .foregroundStyle(AppColor.Text.inverseTertiary)
                .accessibilityAddTraits(.isHeader)

            Text(exercise.name)
                .font(AppText.metric)
                .foregroundStyle(AppColor.Text.inversePrimary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, AppSpacing.large)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Focus mode. Exercise: \(exercise.name)")
    }

    // MARK: - Set Indicator

    @ViewBuilder
    private var setIndicator: some View {
        if let idx = nextIncompleteSetIndex {
            VStack(spacing: AppSpacing.xxSmall) {
                Text("Set \(idx + 1)")
                    .font(AppText.monoMetric)
                    .foregroundStyle(AppColor.Text.inverseTertiary)
                    .accessibilityLabel("Set \(idx + 1) of \(exerciseLog.sets.count)")

                Text(exercise.targetReps)
                    .font(AppText.metricDisplay)
                    .foregroundStyle(AppColor.Text.inversePrimary)
                    .accessibilityLabel("Target: \(exercise.targetReps) reps")
            }
        } else {
            Text("All sets done")
                .font(AppText.pageTitle)
                .foregroundStyle(AppColor.Status.success)
                .accessibilityLabel("All sets completed")
        }
    }

    // MARK: - Weight / Reps Inputs

    private var inputFields: some View {
        HStack(spacing: AppSpacing.small) {
            focusField(placeholder: "kg", text: $weightStr)
                .accessibilityLabel("Weight in kilograms")

            Text("\u{00D7}")
                .font(AppText.metric)
                .foregroundStyle(AppColor.Text.inverseTertiary)
                .accessibilityHidden(true)

            focusField(placeholder: "reps", text: $repsStr)
                .accessibilityLabel("Repetitions completed")
        }
        .padding(.horizontal, AppSpacing.xLarge)
    }

    // MARK: - Coaching Cue

    private var coachingCue: some View {
        Group {
            if !exercise.coachingCue.isEmpty {
                Text(exercise.coachingCue)
                    .font(AppText.caption)
                    .foregroundStyle(AppColor.Text.inverseTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xLarge)
                    .accessibilityLabel("Coaching cue: \(exercise.coachingCue)")
            }
        }
    }

    // MARK: - Done Button

    private var doneButton: some View {
        Button {
            guard let idx = nextIncompleteSetIndex else {
                onExit()
                return
            }
            commitSet(at: idx)
        } label: {
            Text(allSetsDone ? "Finish" : "Done")
                .font(AppText.metricCompact)
                .foregroundStyle(AppColor.Surface.inverse)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.medium)
                .background(
                    AppColor.Status.success,
                    in: RoundedRectangle(cornerRadius: AppRadius.large)
                )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, AppSpacing.xLarge)
        .disabled(allSetsDone)
        .accessibilityLabel(allSetsDone ? "Finish exercise" : "Log current set")
    }

    // MARK: - Input Field

    private func focusField(
        placeholder: String,
        text: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {
            Text(placeholder.uppercased())
                .font(AppText.monoCaption)
                .foregroundStyle(AppColor.Text.inverseTertiary)

            TextField(placeholder, text: text)
                .font(AppText.metricDisplayMono)
                .foregroundStyle(AppColor.Text.inversePrimary)
                .multilineTextAlignment(.center)
                .keyboardType(.decimalPad)
                .padding(AppSpacing.small)
                .background(
                    AppColor.Surface.materialLight,
                    in: RoundedRectangle(cornerRadius: AppRadius.medium)
                )
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    private func commitSet(at idx: Int) {
        exerciseLog.sets[idx].weightKg = Double(
            weightStr.replacingOccurrences(of: ",", with: ".")
        )
        exerciseLog.sets[idx].repsCompleted = Int(repsStr)
        exerciseLog.sets[idx].timestamp = Date()

        let haptic = UIImpactFeedbackGenerator(style: .medium)
        haptic.prepare()
        haptic.impactOccurred()

        // Clear reps; prefill weight for the next set from the one just logged
        repsStr = ""
        if let kg = exerciseLog.sets[idx].weightKg {
            weightStr = kg.truncatingRemainder(dividingBy: 1) == 0
                ? String(Int(kg)) : String(kg)
        } else {
            weightStr = ""
        }
    }

    private func prefillWeightFromLastSet() {
        if let kg = exerciseLog.sets
            .last(where: { $0.weightKg != nil })?.weightKg {
            weightStr = kg.truncatingRemainder(dividingBy: 1) == 0
                ? String(Int(kg)) : String(kg)
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Focus Mode") {
    FocusModeView(
        exercise: ExerciseDefinition(
            id: "bench-press",
            name: "Bench Press",
            category: .freeWeight,
            equipment: .barbell,
            muscleGroups: [.chest, .triceps, .shoulders],
            targetSets: 4,
            targetReps: "8-10",
            restSeconds: 90,
            coachingCue: "Retract scapulae. Drive feet into the floor.",
            dayType: .upperPush,
            order: 1
        ),
        exerciseLog: .constant(ExerciseLog(
            exerciseID: "bench-press",
            exerciseName: "Bench Press",
            sets: (1...4).map { SetLog(setNumber: $0) }
        )),
        onExit: {}
    )
    .environmentObject(AnalyticsService.makeDefault())
}
#endif
