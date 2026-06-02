// Views/Settings/v2/Screens/CustomProgramEditorScreen.swift
// C6 training-program-customization (2026-06-02) — Surface 3 (THE HEADLINE).
//
// Push-navigation editor for a single CustomProgram. Day-by-day expand/
// collapse. Per-day affordances: rename (inline TextField), gear icon
// (DayEditSheet), drag-handle reorder of slots, swipe-to-remove, tap-row
// (ExerciseSlotOverrideSheet), "+ Add exercise" → C3
// ExerciseLibraryView(source:picker:).
//
// Operates on a LOCAL @State draft copy of the program — cancel discards;
// Save calls onSave(...) which the parent (list screen) persists.
//
// PRD OQ-3: empty-day Save WARNING is non-blocking; user can Save anyway.

import SwiftUI

struct CustomProgramEditorScreen: View {
    let program: CustomProgram
    var onSave: (CustomProgram) -> Void

    @EnvironmentObject private var analytics: AnalyticsService
    @Environment(\.dismiss) private var dismiss

    @State private var draft: CustomProgram
    @State private var expandedDayIDs: Set<UUID> = []

    // Day editor sheet state
    @State private var editingDayIndex: Int?
    // Slot override sheet state
    @State private var overrideTarget: SlotOverrideTarget?
    // Exercise library picker (C3) state
    @State private var pickerTargetDayIndex: Int?
    // Empty-day Save warning (PRD OQ-3)
    @State private var showEmptyDayWarning = false
    @State private var pendingSaveAfterWarning = false

    init(program: CustomProgram, onSave: @escaping (CustomProgram) -> Void) {
        self.program = program
        self.onSave = onSave
        self._draft = State(initialValue: program)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.medium) {
                    nameSection
                    daySections
                }
                .padding(AppSpacing.medium)
            }
            .background(AppGradient.screenBackground.ignoresSafeArea())
            .navigationTitle(draft.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { handleSaveTap() }
                }
            }
            .sheet(item: Binding(
                get: { editingDayIndex.map { IndexBox(value: $0) } },
                set: { editingDayIndex = $0?.value }
            )) { box in
                DayEditSheet(
                    day: $draft.days[box.value],
                    onSave: {},
                    onDuplicate: { targetWeekday in
                        duplicateDay(at: box.value, to: targetWeekday)
                    }
                )
                .environmentObject(analytics)
            }
            .sheet(item: $overrideTarget) { target in
                if let catalog = catalogEntry(forID: draft.days[target.dayIndex].slots[target.slotIndex].exerciseID) {
                    ExerciseSlotOverrideSheet(
                        slot: $draft.days[target.dayIndex].slots[target.slotIndex],
                        exercise: catalog
                    ) {
                        // Re-fire slot_added with refreshed overrideCount for
                        // analytics consistency on edits.
                        let s = draft.days[target.dayIndex].slots[target.slotIndex]
                        analytics.logTrainingExerciseSlotAdded(
                            exerciseId: s.exerciseID,
                            dayId: draft.days[target.dayIndex].id.uuidString,
                            overrideCount: s.overrideCount
                        )
                    }
                }
            }
            .sheet(item: Binding(
                get: { pickerTargetDayIndex.map { IndexBox(value: $0) } },
                set: { pickerTargetDayIndex = $0?.value }
            )) { box in
                ExerciseLibraryView(source: "picker:c6_editor") { picked in
                    addSlot(picked, toDayIndex: box.value)
                }
                .environmentObject(analytics)
            }
            .confirmationDialog(
                "Empty days",
                isPresented: $showEmptyDayWarning,
                titleVisibility: .visible
            ) {
                Button("Save anyway") {
                    pendingSaveAfterWarning = false
                    commitSave()
                }
                Button("Cancel", role: .cancel) {
                    pendingSaveAfterWarning = false
                }
            } message: {
                Text("Some days have no exercises. The fixed PPL fallback will run on those weekdays. Save anyway?")
            }
        }
    }

    // MARK: - Sections

    private var nameSection: some View {
        SettingsSectionCard(title: "Program", eyebrow: "Name") {
            TextField("Program name", text: $draft.name)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled(true)
                .accessibilityLabel("Program name")
        }
    }

    private var daySections: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            ForEach(Array(draft.days.enumerated()), id: \.element.id) { idx, day in
                daySection(index: idx, day: day)
            }
        }
    }

    private func daySection(index: Int, day: CustomDay) -> some View {
        let isExpanded = expandedDayIDs.contains(day.id)
        return SettingsSectionCard(
            title: dayHeaderTitle(day),
            eyebrow: weekdayLabel(day.weekdayIndex)
        ) {
            VStack(spacing: AppSpacing.xSmall) {
                HStack(spacing: AppSpacing.xSmall) {
                    Button {
                        toggleExpanded(day.id)
                    } label: {
                        Image(systemName: isExpanded ? AppIcon.chevronDown : AppIcon.chevronUp)
                            .foregroundStyle(AppColor.Text.secondary)
                    }
                    .accessibilityLabel(isExpanded ? "Collapse \(day.name)" : "Expand \(day.name)")
                    Text(day.dayType.rawValue)
                        .font(AppText.caption)
                        .foregroundStyle(AppColor.Text.secondary)
                    Spacer()
                    Button {
                        editingDayIndex = index
                    } label: {
                        Image(systemName: "gear")
                            .foregroundStyle(AppColor.Accent.primary)
                    }
                    .accessibilityLabel("Edit day settings")
                }

                if isExpanded {
                    slotsList(dayIndex: index)
                    Button {
                        pickerTargetDayIndex = index
                    } label: {
                        HStack(spacing: AppSpacing.xSmall) {
                            Image(systemName: AppIcon.add)
                            Text("Add exercise")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.xSmall)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Add exercise to \(day.name)")
                }
            }
        }
    }

    @ViewBuilder
    private func slotsList(dayIndex: Int) -> some View {
        if draft.days[dayIndex].slots.isEmpty {
            Text("No exercises yet. Tap **Add exercise** below.")
                .font(AppText.caption)
                .foregroundStyle(AppColor.Text.secondary)
                .padding(.vertical, AppSpacing.xSmall)
        } else {
            ForEach(Array(draft.days[dayIndex].slots.enumerated()), id: \.element.id) { slotIdx, slot in
                slotRow(dayIndex: dayIndex, slotIndex: slotIdx, slot: slot)
            }
        }
    }

    private func slotRow(dayIndex: Int, slotIndex: Int, slot: ExerciseSlot) -> some View {
        let catalog = catalogEntry(forID: slot.exerciseID)
        let displayName = catalog?.name ?? slot.exerciseID
        let sets = slot.targetSetsOverride ?? catalog?.targetSets ?? 0
        let reps = slot.targetRepsOverride ?? catalog?.targetReps ?? "—"
        return HStack(spacing: AppSpacing.small) {
            Button {
                overrideTarget = SlotOverrideTarget(dayIndex: dayIndex, slotIndex: slotIndex)
            } label: {
                VStack(alignment: .leading, spacing: AppSpacing.micro) {
                    Text(displayName)
                        .font(AppText.body)
                        .foregroundStyle(AppColor.Text.primary)
                    Text("\(sets)×\(reps)\(slot.overrideCount > 0 ? " · custom" : "")")
                        .font(AppText.caption)
                        .foregroundStyle(AppColor.Text.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Button(role: .destructive) {
                removeSlot(dayIndex: dayIndex, slotIndex: slotIndex)
            } label: {
                Image(systemName: AppIcon.delete)
                    .foregroundStyle(AppColor.Status.warning)
            }
            .accessibilityLabel("Remove \(displayName)")
        }
        .padding(.vertical, AppSpacing.micro)
    }

    // MARK: - Helpers

    private func dayHeaderTitle(_ day: CustomDay) -> String {
        day.name
    }

    private func weekdayLabel(_ index: Int) -> String {
        let symbols = Calendar.current.standaloneWeekdaySymbols
        guard index >= 0 && index < symbols.count else { return "?" }
        return symbols[index]
    }

    private func toggleExpanded(_ id: UUID) {
        if expandedDayIDs.contains(id) {
            expandedDayIDs.remove(id)
        } else {
            expandedDayIDs.insert(id)
        }
    }

    private func catalogEntry(forID id: String) -> ExerciseDefinition? {
        TrainingProgramData.allExercises.first { $0.id == id }
    }

    // MARK: - Mutations

    private func addSlot(_ exercise: ExerciseDefinition, toDayIndex idx: Int) {
        let order = draft.days[idx].slots.count
        let slot = ExerciseSlot(exerciseID: exercise.id, order: order)
        draft.days[idx].slots.append(slot)
        analytics.logTrainingExerciseSlotAdded(
            exerciseId: exercise.id,
            dayId: draft.days[idx].id.uuidString,
            overrideCount: 0
        )
    }

    private func removeSlot(dayIndex: Int, slotIndex: Int) {
        let slot = draft.days[dayIndex].slots[slotIndex]
        let dayID = draft.days[dayIndex].id
        draft.days[dayIndex].slots.remove(at: slotIndex)
        // Re-flow order indices
        for i in 0..<draft.days[dayIndex].slots.count {
            draft.days[dayIndex].slots[i].order = i
        }
        analytics.logTrainingExerciseSlotRemoved(
            exerciseId: slot.exerciseID,
            dayId: dayID.uuidString
        )
    }

    private func duplicateDay(at sourceIndex: Int, to targetWeekday: Int) {
        let source = draft.days[sourceIndex]
        var copy = source
        copy.weekdayIndex = targetWeekday
        // Generate fresh UUIDs so the new day + slots are independent.
        let newDayID = UUID()
        copy = CustomDay(
            id: newDayID,
            name: source.name + " (copy)",
            dayType: source.dayType,
            weekdayIndex: targetWeekday,
            slots: source.slots.map { s in
                ExerciseSlot(
                    exerciseID: s.exerciseID,
                    targetSetsOverride: s.targetSetsOverride,
                    targetRepsOverride: s.targetRepsOverride,
                    restSecondsOverride: s.restSecondsOverride,
                    order: s.order
                )
            }
        )
        // Replace the day already at targetWeekday (if any) with the copy.
        if let existingIdx = draft.days.firstIndex(where: { $0.weekdayIndex == targetWeekday && $0.id != source.id }) {
            draft.days[existingIdx] = copy
        } else {
            draft.days.append(copy)
        }
    }

    private func handleSaveTap() {
        let anyEmpty = draft.days.contains { $0.dayType != .restDay && $0.slots.isEmpty }
        if anyEmpty {
            pendingSaveAfterWarning = true
            showEmptyDayWarning = true
        } else {
            commitSave()
        }
    }

    private func commitSave() {
        onSave(draft)
        dismiss()
    }

    // MARK: - Local types

    private struct IndexBox: Identifiable {
        let value: Int
        var id: Int { value }
    }

    private struct SlotOverrideTarget: Identifiable {
        let dayIndex: Int
        let slotIndex: Int
        var id: String { "\(dayIndex)-\(slotIndex)" }
    }
}
