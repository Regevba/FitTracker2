// FitTracker/Views/Import/ImportPreviewView.swift
// Two-mode preview screen for imported training plans.
// `.preview` mode: post-parse confirmation (Confirm & Import); used during the
//   import flow from `ImportSourcePickerView`. Includes the day-assignment
//   editor (T14) so the user can review + override the heuristic-suggested
//   DayType for each imported day before persisting.
// `.detail` mode: viewing a saved imported plan (rename / activate / delete);
//   navigated to from `ImportedPlansListScreen`. Day-assignment editor is
//   editable; exercise mapping review is frozen at confirm time.

import SwiftUI

struct ImportPreviewView: View {
    enum Mode {
        /// Post-parse confirmation flow (Confirm & Import bottom CTA).
        case preview(plan: ImportedPlan, orchestrator: ImportOrchestrator)
        /// Viewing a saved plan (Activate/Deactivate/Delete toolbar actions).
        case detail(planId: UUID)
    }

    let mode: Mode
    var onConfirm: (() -> Void)? = nil
    var onCancel: (() -> Void)? = nil

    /// Convenience initializer for the legacy preview-only call site (used by
    /// `ImportSourcePickerView` until T15 wires the new flow). Builds a stub
    /// orchestrator so the day-assignment edits flow back through the same
    /// path as the new flow.
    init(plan: ImportedPlan, orchestrator: ImportOrchestrator? = nil, onConfirm: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.mode = .preview(plan: plan, orchestrator: orchestrator ?? ImportOrchestrator())
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }

    init(detailPlanId: UUID) {
        self.mode = .detail(planId: detailPlanId)
    }

    @EnvironmentObject private var dataStore: EncryptedDataStore
    @EnvironmentObject private var programStore: TrainingProgramStore
    @EnvironmentObject private var analytics: AnalyticsService
    @Environment(\.dismiss) private var dismiss
    @State private var renameDraft: String = ""
    @State private var isRenaming: Bool = false
    @State private var showDeleteConfirm: Bool = false

    private var navigationTitle: String {
        switch mode {
        case .preview: return "Preview Import"
        case .detail(let id):
            return dataStore.importedTrainingPlans.first(where: { $0.id == id })?.name ?? "Plan"
        }
    }

    private var planForDetailMode: ImportedTrainingPlan? {
        if case .detail(let id) = mode {
            return dataStore.importedTrainingPlans.first(where: { $0.id == id })
        }
        return nil
    }

    var body: some View {
        Group {
            switch mode {
            case .preview(let plan, let orch):
                NavigationStack {
                    previewBody(plan: plan, orchestrator: orch)
                        .navigationTitle("Preview Import")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar { previewToolbar }
                }
            case .detail:
                detailBody
                    .navigationTitle(navigationTitle)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { detailToolbar }
                    .alert("Delete '\(planForDetailMode?.name ?? "plan")'?",
                           isPresented: $showDeleteConfirm) {
                        Button("Delete", role: .destructive, action: deletePlan)
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This cannot be undone.")
                    }
                    .onAppear {
                        if let p = planForDetailMode {
                            renameDraft = p.name
                            let days = max(0, Calendar.current.dateComponents(
                                [.day], from: p.createdAt, to: Date()).day ?? 0)
                            analytics.logImportPlanOpened(daysSinceImport: days,
                                                          source: p.source.rawValue)
                        }
                    }
            }
        }
    }

    // ─────────────────────────────────────────────────────
    // MARK: – .preview mode body
    // ─────────────────────────────────────────────────────

    @ViewBuilder
    private func previewBody(plan: ImportedPlan, orchestrator: ImportOrchestrator) -> some View {
        ZStack {
            AppGradient.screenBackground.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.medium) {
                    summaryBar(plan: plan)
                    dayAssignmentEditor(orchestrator: orchestrator)
                    ForEach(plan.days.indices, id: \.self) { dayIndex in
                        dayCard(plan.days[dayIndex])
                    }
                }
                .padding(.horizontal, AppSpacing.medium)
                .padding(.vertical, AppSpacing.small)
            }
        }
    }

    @ToolbarContentBuilder
    private var previewToolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { onCancel?() }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Confirm & Import") { onConfirm?() }
                .font(AppText.button)
                .foregroundStyle(AppColor.Status.success)
        }
    }

    // ─────────────────────────────────────────────────────
    // MARK: – .detail mode body
    // ─────────────────────────────────────────────────────

    @ViewBuilder
    private var detailBody: some View {
        if let plan = planForDetailMode {
            ZStack {
                AppGradient.screenBackground.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.medium) {
                        if plan.isActive {
                            activeBadgeRow
                        }
                        renameRow(plan: plan)
                        detailDayAssignmentList(plan: plan)
                        ForEach(plan.days.indices, id: \.self) { dayIndex in
                            detailDayCard(plan.days[dayIndex])
                        }
                    }
                    .padding(.horizontal, AppSpacing.medium)
                    .padding(.vertical, AppSpacing.small)
                }
            }
        } else {
            ContentUnavailableView("Plan unavailable",
                                   systemImage: "exclamationmark.triangle",
                                   description: Text("This imported plan may have been deleted."))
        }
    }

    @ToolbarContentBuilder
    private var detailToolbar: some ToolbarContent {
        if let plan = planForDetailMode {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await toggleActive(plan: plan) }
                } label: {
                    Image(systemName: plan.isActive ? "pause.circle" : "play.circle")
                        .font(AppText.iconSmall)
                        .foregroundStyle(AppColor.Accent.primary)
                }
                .accessibilityLabel(plan.isActive ? "Deactivate this plan" : "Activate this plan")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(AppText.iconSmall)
                        .foregroundStyle(AppColor.Text.secondary)
                }
                .accessibilityLabel("More actions")
            }
        }
    }

    private var activeBadgeRow: some View {
        HStack(spacing: AppSpacing.xxSmall) {
            Text("ACTIVE")
                .font(AppText.monoCaption)
                .foregroundStyle(AppColor.Text.inversePrimary)
                .padding(.horizontal, AppSpacing.xxSmall)
                .padding(.vertical, AppSpacing.micro)
                .background(AppColor.Status.success, in: Capsule())
            Text("Currently your active training plan")
                .font(AppText.caption)
                .foregroundStyle(AppColor.Text.secondary)
            Spacer()
        }
    }

    private func renameRow(plan: ImportedTrainingPlan) -> some View {
        HStack(spacing: AppSpacing.xSmall) {
            if isRenaming {
                TextField("Plan name", text: $renameDraft)
                    .font(AppText.body)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { commitRename(plan: plan) }
                Button("Done") { commitRename(plan: plan) }
                    .font(AppText.button)
            } else {
                Button {
                    isRenaming = true
                    renameDraft = plan.name
                } label: {
                    HStack {
                        Text(plan.name)
                            .font(AppText.sectionTitle)
                            .foregroundStyle(AppColor.Text.primary)
                        Image(systemName: "pencil")
                            .font(AppText.caption)
                            .foregroundStyle(AppColor.Text.tertiary)
                    }
                }
                .buttonStyle(.plain)
                Spacer()
            }
        }
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Day-assignment editor (preview mode)
    // ─────────────────────────────────────────────────────

    @ViewBuilder
    private func dayAssignmentEditor(orchestrator: ImportOrchestrator) -> some View {
        if !orchestrator.currentDayAssignments.isEmpty {
            VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {
                Text("Day Assignment")
                    .font(AppText.sectionTitle)
                    .foregroundStyle(AppColor.Text.primary)
                Text("Map each imported day to your week")
                    .font(AppText.caption)
                    .foregroundStyle(AppColor.Text.secondary)

                VStack(spacing: 0) {
                    ForEach(orchestrator.currentDayAssignments.indices, id: \.self) { i in
                        let assignment = orchestrator.currentDayAssignments[i]
                        HStack {
                            Text(assignment.originalDayName)
                                .font(AppText.body)
                                .foregroundStyle(AppColor.Text.primary)
                            Spacer()
                            Picker(assignment.assignedDayType.rawValue, selection: Binding(
                                get: { orchestrator.currentDayAssignments[i].assignedDayType },
                                set: { orchestrator.currentDayAssignments[i].assignedDayType = $0 }
                            )) {
                                ForEach(DayType.allCases, id: \.self) { type in
                                    Text(type.rawValue).tag(type)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        .padding(.vertical, AppSpacing.xxSmall)
                        if i < orchestrator.currentDayAssignments.count - 1 {
                            Divider()
                        }
                    }
                }
                .padding(AppSpacing.small)
                .background(AppColor.Surface.primary, in: RoundedRectangle(cornerRadius: AppRadius.card))

                if let collisionNote = collisionWarning(for: orchestrator.currentDayAssignments) {
                    Label(collisionNote, systemImage: "exclamationmark.triangle.fill")
                        .font(AppText.caption)
                        .foregroundStyle(AppColor.Status.warning)
                        .padding(AppSpacing.small)
                        .background(AppColor.Status.warning.opacity(0.10),
                                    in: RoundedRectangle(cornerRadius: AppRadius.medium))
                }
            }
        }
    }

    @ViewBuilder
    private func detailDayAssignmentList(plan: ImportedTrainingPlan) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {
            Text("Day Assignment")
                .font(AppText.sectionTitle)
                .foregroundStyle(AppColor.Text.primary)
            VStack(spacing: 0) {
                ForEach(plan.days.indices, id: \.self) { i in
                    let assignment = plan.days[i]
                    HStack {
                        Text(assignment.originalDayName)
                            .font(AppText.body)
                            .foregroundStyle(AppColor.Text.primary)
                        Spacer()
                        Text(assignment.assignedDayType.rawValue)
                            .font(AppText.caption)
                            .foregroundStyle(AppColor.Text.secondary)
                    }
                    .padding(.vertical, AppSpacing.xxSmall)
                    if i < plan.days.count - 1 { Divider() }
                }
            }
            .padding(AppSpacing.small)
            .background(AppColor.Surface.primary, in: RoundedRectangle(cornerRadius: AppRadius.card))
        }
    }

    private func collisionWarning(for assignments: [ImportedDayAssignment]) -> String? {
        var counts: [DayType: Int] = [:]
        for a in assignments { counts[a.assignedDayType, default: 0] += 1 }
        let collisions = counts.filter { (key, value) in value > 1 && key != .restDay }
        if let first = collisions.first {
            return "\(first.value) days will share \(first.key.rawValue). Both will appear when you switch to that day in the Training tab."
        }
        return nil
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Shared sub-views
    // ─────────────────────────────────────────────────────

    private func summaryBar(plan: ImportedPlan) -> some View {
        let exercises = plan.days.flatMap(\.exercises)
        let autoMatched = exercises.filter { ($0.mappingConfidence ?? 0) >= ExerciseMapper.autoAcceptThreshold }.count
        let needsReview = exercises.filter {
            let c = $0.mappingConfidence ?? 0
            return c >= ExerciseMapper.reviewThreshold && c < ExerciseMapper.autoAcceptThreshold
        }.count
        let unmatched = exercises.count - autoMatched - needsReview

        return HStack(spacing: AppSpacing.small) {
            Label("\(exercises.count) exercises", systemImage: "list.bullet")
            Spacer()
            if autoMatched > 0 {
                Label("\(autoMatched)", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(AppColor.Status.success)
            }
            if needsReview > 0 {
                Label("\(needsReview)", systemImage: "pencil.circle.fill")
                    .foregroundStyle(AppColor.Status.warning)
            }
            if unmatched > 0 {
                Label("\(unmatched)", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(AppColor.Status.error)
            }
        }
        .font(AppText.caption)
        .padding(AppSpacing.small)
        .background(AppColor.Surface.primary, in: RoundedRectangle(cornerRadius: AppRadius.medium))
    }

    private func dayCard(_ day: ImportedDay) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
            Text(day.name)
                .font(AppText.sectionTitle)
                .foregroundStyle(AppColor.Text.primary)

            ForEach(day.exercises.indices, id: \.self) { i in
                exerciseRow(day.exercises[i])
                if i < day.exercises.count - 1 {
                    Divider()
                }
            }
        }
        .padding(AppSpacing.small)
        .background(AppColor.Surface.primary, in: RoundedRectangle(cornerRadius: AppRadius.card))
    }

    private func detailDayCard(_ day: ImportedDayAssignment) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
            HStack {
                Text(day.originalDayName)
                    .font(AppText.sectionTitle)
                    .foregroundStyle(AppColor.Text.primary)
                Text("· \(day.assignedDayType.rawValue)")
                    .font(AppText.caption)
                    .foregroundStyle(AppColor.Text.secondary)
            }
            ForEach(day.exercises.indices, id: \.self) { i in
                detailExerciseRow(day.exercises[i])
                if i < day.exercises.count - 1 {
                    Divider()
                }
            }
        }
        .padding(AppSpacing.small)
        .background(AppColor.Surface.primary, in: RoundedRectangle(cornerRadius: AppRadius.card))
    }

    private func exerciseRow(_ exercise: ImportedExercise) -> some View {
        HStack {
            confidenceIcon(exercise.mappingConfidence ?? 0)
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.rawName)
                    .font(AppText.body)
                    .foregroundStyle(AppColor.Text.primary)
                if let mapped = exercise.mappedExerciseId {
                    Text("→ \(mapped.replacingOccurrences(of: "_", with: " ").capitalized)")
                        .font(AppText.caption)
                        .foregroundStyle(AppColor.Text.secondary)
                }
            }
            Spacer()
            Text("\(exercise.sets) × \(exercise.reps)")
                .font(AppText.monoCaption)
                .foregroundStyle(AppColor.Text.tertiary)
        }
    }

    private func detailExerciseRow(_ entry: ImportedExerciseEntry) -> some View {
        HStack {
            confidenceIcon(entry.mappingConfidence ?? 0)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.rawName)
                    .font(AppText.body)
                    .foregroundStyle(AppColor.Text.primary)
                if let mapped = entry.mappedExerciseId {
                    Text("→ \(mapped.replacingOccurrences(of: "_", with: " ").capitalized)")
                        .font(AppText.caption)
                        .foregroundStyle(AppColor.Text.secondary)
                }
            }
            Spacer()
            Text("\(entry.sets) × \(entry.reps)")
                .font(AppText.monoCaption)
                .foregroundStyle(AppColor.Text.tertiary)
        }
    }

    private func confidenceIcon(_ confidence: Double) -> some View {
        Group {
            if confidence >= ExerciseMapper.autoAcceptThreshold {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AppColor.Status.success)
            } else if confidence >= ExerciseMapper.reviewThreshold {
                Image(systemName: "pencil.circle.fill")
                    .foregroundStyle(AppColor.Status.warning)
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(AppColor.Status.error)
            }
        }
        .font(AppText.body)
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Detail mode actions
    // ─────────────────────────────────────────────────────

    private func commitRename(plan: ImportedTrainingPlan) {
        let trimmed = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let idx = dataStore.importedTrainingPlans.firstIndex(where: { $0.id == plan.id }) else {
            isRenaming = false
            return
        }
        dataStore.importedTrainingPlans[idx].name = trimmed
        dataStore.importedTrainingPlans[idx].lastModified = Date()
        Task { await dataStore.persistToDisk() }
        isRenaming = false
    }

    private func toggleActive(plan: ImportedTrainingPlan) async {
        let wasFirstActivation = !plan.isActive && plan.lastModified == plan.createdAt
        let newActiveId = plan.isActive ? nil : plan.id
        await programStore.activate(planId: newActiveId, dataStore: dataStore)
        if newActiveId != nil {
            let days = max(0, Calendar.current.dateComponents(
                [.day], from: plan.createdAt, to: Date()).day ?? 0)
            analytics.logImportPlanActivated(source: plan.source.rawValue,
                                             daysSinceImport: days,
                                             wasFirstActivation: wasFirstActivation)
        }
    }

    private func deletePlan() {
        guard case .detail(let id) = mode,
              let idx = dataStore.importedTrainingPlans.firstIndex(where: { $0.id == id }) else {
            return
        }
        let wasActive = dataStore.importedTrainingPlans[idx].isActive
        dataStore.importedTrainingPlans.remove(at: idx)
        if wasActive { programStore.activePlanId = nil }
        Task { await dataStore.persistToDisk() }
        dismiss()
    }
}
