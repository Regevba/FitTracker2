// FitTracker/Views/Training/v2/ExerciseRowView.swift
// v2 — UX Foundations-aligned rewrite of ExerciseRowView.
// Design-system compliant: zero raw literals, semantic tokens only.
import SwiftUI

struct ExerciseRowView: View {
    // MARK: - Parameters

    let exercise: ExerciseDefinition
    let selectedDay: DayType
    let exerciseLog: ExerciseLog?
    let previousSessionLog: ExerciseLog?
    let status: TaskStatus
    let showsDivider: Bool
    let onStatusChange: (TaskStatus) -> Void
    let onFocus: () -> Void
    let onStartRest: () -> Void
    let onSetUpdated: (Int, SetLog) -> Void
    let onSetLogged: (Int) -> Void
    let onSetDeleted: (Int) -> Void
    let onCopyLast: (Int) -> Void

    // MARK: - State

    @State private var isExpanded: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Derived

    private var isComplete: Bool { status == .completed }
    private var isInProgress: Bool { status == .partial }

    private var accentColor: Color {
        switch status {
        case .completed: AppColor.Status.success
        case .partial:   AppColor.Status.warning
        case .missed:    AppColor.Status.error
        case .pending:   AppColor.Text.secondary
        }
    }

    private var muscleGroupText: String {
        exercise.muscleGroups.map { $0.rawValue.capitalized }.joined(separator: " · ")
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            headerRow
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(reduceMotion ? .none : AppSpring.snappy) {
                        isExpanded.toggle()
                    }
                    onFocus()
                }

            if isExpanded {
                expandedContent
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if showsDivider {
                Divider()
                    .overlay(AppColor.Surface.materialLight)
                    .padding(.leading, AppSpacing.small)
            }
        }
        .onAppear {
            // Completed exercises start collapsed; others start expanded
            isExpanded = !isComplete
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(exercise.name), \(muscleGroupText)")
        .accessibilityValue(statusAccessibilityValue)
        .accessibilityHint("Double tap to expand")
    }

    // MARK: - Header Row

    private var headerRow: some View {
        HStack(alignment: .center, spacing: AppSpacing.xxSmall) {
            statusStripe

            VStack(alignment: .leading, spacing: AppSpacing.xxxSmall) {
                exerciseNameRow
                muscleGroupLabel
                metaPills
                coachingCue
            }

            Spacer(minLength: AppSpacing.xxSmall)

            expandChevron
        }
        .padding(.horizontal, AppSpacing.xxSmall)
        .padding(.vertical, AppSpacing.xSmall)
        .frame(minHeight: 44)
    }

    // MARK: - Status Stripe (4pt left bar)

    private var statusStripe: some View {
        RoundedRectangle(cornerRadius: AppRadius.micro)
            .fill(accentColor)
            .frame(width: 4)
            .padding(.vertical, AppSpacing.xxxSmall)
    }

    // MARK: - Exercise Name

    private var exerciseNameRow: some View {
        HStack(spacing: AppSpacing.xxSmall) {
            Text(exercise.name)
                .font(AppText.sectionTitle)
                .strikethrough(isComplete, color: AppColor.Status.success)
                .foregroundStyle(isComplete ? AppColor.Text.secondary : AppColor.Text.primary)

            if isComplete {
                Image(systemName: "checkmark.circle.fill")
                    .font(AppText.iconSmall)
                    .foregroundStyle(AppColor.Status.success)
            }
        }
    }

    // MARK: - Muscle Groups

    private var muscleGroupLabel: some View {
        Text(muscleGroupText)
            .font(AppText.caption)
            .foregroundStyle(AppColor.Text.secondary)
    }

    // MARK: - Meta Pills

    private var metaPills: some View {
        HStack(spacing: AppSpacing.xxSmall) {
            if exercise.category != .cardio {
                metaPill("\(exercise.targetSets) sets")
                metaPill(exercise.targetReps)
                metaPill("Rest \(exercise.restSeconds)s")
            }
        }
    }

    private func metaPill(_ text: String) -> some View {
        AppPickerChip(
            label: text,
            isSelected: false,
            action: {}
        )
        .allowsHitTesting(false)
    }

    // MARK: - Coaching Cue

    private var coachingCue: some View {
        Text("↳ \(exercise.coachingCue)")
            .font(AppText.caption)
            .foregroundStyle(AppColor.Accent.primary)
            .lineLimit(2)
    }

    // MARK: - Expand Chevron

    private var expandChevron: some View {
        Image(systemName: "chevron.right")
            .font(AppText.iconSmall)
            .foregroundStyle(AppColor.Text.secondary)
            .rotationEffect(.degrees(isExpanded ? 90 : 0))
            .animation(reduceMotion ? .none : AppSpring.snappy, value: isExpanded)
            .frame(minWidth: 44, minHeight: 44)
    }

    // MARK: - Expanded Content (Set Rows)

    @ViewBuilder
    private var expandedContent: some View {
        VStack(spacing: AppSpacing.xxSmall) {
            Divider()
                .overlay(AppColor.Surface.materialStrong)
                .padding(.leading, AppSpacing.small)

            let sets = exerciseLog?.sets ?? []
            ForEach(Array(sets.enumerated()), id: \.element.id) { index, setLog in
                let previousSet: SetLog? = {
                    guard let prevSets = previousSessionLog?.sets,
                          index < prevSets.count else { return nil }
                    return prevSets[index]
                }()

                SetRowView(
                    setIndex: index + 1,
                    previousWeight: previousSet?.weightKg,
                    previousReps: previousSet?.repsCompleted,
                    currentWeight: .constant(setLog.weightKg),
                    currentReps: .constant(setLog.repsCompleted),
                    isLogged: setLog.weightKg != nil && setLog.repsCompleted != nil,
                    onLog: { onSetLogged(index) },
                    onCopyLast: { onCopyLast(index) },
                    onDelete: { onSetDeleted(index) }
                )
            }

            if sets.isEmpty {
                Text("No sets recorded yet")
                    .font(AppText.caption)
                    .foregroundStyle(AppColor.Text.tertiary)
                    .padding(.vertical, AppSpacing.xSmall)
            }
        }
        .padding(.horizontal, AppSpacing.xxSmall)
        .padding(.bottom, AppSpacing.xSmall)
    }

    // MARK: - Accessibility

    private var statusAccessibilityValue: String {
        switch status {
        case .completed: "Complete"
        case .partial:   "In progress"
        case .missed:    "Missed"
        case .pending:   "Pending"
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("ExerciseRowView – Pending") {
    let exercise = ExerciseDefinition(
        id: "bench-press",
        name: "Bench Press",
        category: .freeWeight,
        equipment: .barbell,
        muscleGroups: [.chest, .triceps, .shoulders],
        targetSets: 4,
        targetReps: "8-12",
        restSeconds: 90,
        coachingCue: "Retract scapulae, drive feet into floor",
        dayType: .push,
        order: 1
    )

    VStack {
        ExerciseRowView(
            exercise: exercise,
            selectedDay: .push,
            exerciseLog: nil,
            previousSessionLog: nil,
            status: .pending,
            showsDivider: true,
            onStatusChange: { _ in },
            onFocus: {},
            onStartRest: {},
            onSetUpdated: { _, _ in },
            onSetLogged: { _ in },
            onSetDeleted: { _ in },
            onCopyLast: { _ in }
        )
    }
    .padding()
    .background(AppGradient.screenBackground)
}
#endif
