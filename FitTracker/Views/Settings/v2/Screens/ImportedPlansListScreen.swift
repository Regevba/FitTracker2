// FitTracker/Views/Settings/v2/Screens/ImportedPlansListScreen.swift
// Imported Plans list — Settings → Data & Sync → Imported Plans (T13 of
// import-training-plan resume, 2026-05-06).
// 4 states: empty, populated-no-active, populated-with-active, loading.
// Toolbar `+` and empty-state CTA both present `ImportSourcePickerView`
// as a sheet. Row tap pushes `ImportPreviewView(detailPlanId:)` onto
// the navigation stack. Swipe-trailing actions: Delete + Activate/Deactivate.
// Long-press / context menu: Rename · Activate / Deactivate · Delete.
//
// First list-with-swipe-and-context-menu in Settings v2; both patterns are
// new for the codebase — see docs/design-system/feature-memory.md.

import SwiftUI

struct ImportedPlansListScreen: View {
    @EnvironmentObject private var dataStore: EncryptedDataStore
    @EnvironmentObject private var programStore: TrainingProgramStore
    @EnvironmentObject private var analytics: AnalyticsService

    @State private var showImportSheet = false
    @State private var renameTarget: ImportedTrainingPlan?
    @State private var renameDraft: String = ""
    @State private var deleteTarget: ImportedTrainingPlan?

    private var plans: [ImportedTrainingPlan] {
        dataStore.importedTrainingPlans.sorted { $0.lastModified > $1.lastModified }
    }

    var body: some View {
        Group {
            if plans.isEmpty {
                emptyState
            } else {
                populatedList
            }
        }
        .navigationTitle("Imported Plans")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    analytics.logImportStarted(entryPoint: .settingsData)
                    showImportSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(AppText.iconSmall)
                        .foregroundStyle(AppColor.Accent.primary)
                }
                .accessibilityLabel("Import a plan")
            }
        }
        .sheet(isPresented: $showImportSheet) {
            ImportSourcePickerView()
                .environmentObject(dataStore)
                .environmentObject(programStore)
                .environmentObject(analytics)
        }
        .alert("Rename plan", isPresented: Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        )) {
            TextField("Plan name", text: $renameDraft)
            Button("Save") { commitRename() }
            Button("Cancel", role: .cancel) { renameTarget = nil }
        }
        .alert("Delete '\(deleteTarget?.name ?? "plan")'?",
               isPresented: Binding(
                get: { deleteTarget != nil },
                set: { if !$0 { deleteTarget = nil } }
               )) {
            Button("Delete", role: .destructive) { commitDelete() }
            Button("Cancel", role: .cancel) { deleteTarget = nil }
        } message: {
            Text("This cannot be undone.")
        }
    }

    // ─────────────────────────────────────────────────────
    // MARK: – States
    // ─────────────────────────────────────────────────────

    private var emptyState: some View {
        ZStack {
            AppGradient.screenBackground.ignoresSafeArea()
            VStack(spacing: AppSpacing.medium) {
                Image(systemName: "square.and.arrow.down.on.square")
                    .font(.system(size: 88))
                    .foregroundStyle(AppColor.Text.tertiary.opacity(0.6))
                Text("No imported plans yet")
                    .font(AppText.sectionTitle)
                    .foregroundStyle(AppColor.Text.primary)
                    .multilineTextAlignment(.center)
                Text("Bring training plans from Hevy, Strong, AI assistants, or coach docs.")
                    .font(AppText.body)
                    .foregroundStyle(AppColor.Text.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: AppSize.centeredTextMaxWidth)
                Button {
                    analytics.logImportStarted(entryPoint: .settingsData)
                    showImportSheet = true
                } label: {
                    Text("Import a plan")
                        .font(AppText.button)
                        .foregroundStyle(AppColor.Text.inversePrimary)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: AppSize.ctaHeight)
                        .background(AppColor.Accent.primary,
                                    in: RoundedRectangle(cornerRadius: AppRadius.button))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Import a plan")
            }
            .padding(.horizontal, AppSpacing.large)
        }
    }

    private var populatedList: some View {
        List {
            Section {
                ForEach(plans) { plan in
                    NavigationLink {
                        ImportPreviewView(detailPlanId: plan.id)
                            .environmentObject(dataStore)
                            .environmentObject(programStore)
                            .environmentObject(analytics)
                    } label: {
                        ImportedPlanRow(plan: plan)
                    }
                    .accessibilityHint("Opens plan details and edit options")
                    .listRowBackground(rowBackground(for: plan))
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            deleteTarget = plan
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        Button {
                            Task { await toggleActive(plan) }
                        } label: {
                            Label(plan.isActive ? "Deactivate" : "Activate",
                                  systemImage: plan.isActive ? "pause.circle" : "play.circle")
                        }
                        .tint(AppColor.Accent.primary)
                    }
                    .contextMenu {
                        Button { startRename(plan) } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        Button {
                            Task { await toggleActive(plan) }
                        } label: {
                            Label(plan.isActive ? "Deactivate" : "Activate",
                                  systemImage: plan.isActive ? "pause.circle" : "play.circle")
                        }
                        Divider()
                        Button(role: .destructive) {
                            deleteTarget = plan
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            } header: {
                Text("Your imported plans · \(plans.count)")
                    .font(AppText.eyebrow)
                    .foregroundStyle(AppColor.Text.tertiary)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppGradient.screenBackground.ignoresSafeArea())
    }

    @ViewBuilder
    private func rowBackground(for plan: ImportedTrainingPlan) -> some View {
        if plan.isActive {
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .fill(AppColor.Surface.elevated)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                        .stroke(AppColor.Status.success, lineWidth: 2)
                )
        } else {
            AppColor.Surface.elevated
        }
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Actions
    // ─────────────────────────────────────────────────────

    private func toggleActive(_ plan: ImportedTrainingPlan) async {
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

    private func startRename(_ plan: ImportedTrainingPlan) {
        renameDraft = plan.name
        renameTarget = plan
    }

    private func commitRename() {
        guard let target = renameTarget else { return }
        let trimmed = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        defer { renameTarget = nil }
        guard !trimmed.isEmpty,
              let idx = dataStore.importedTrainingPlans.firstIndex(where: { $0.id == target.id }) else {
            return
        }
        dataStore.importedTrainingPlans[idx].name = trimmed
        dataStore.importedTrainingPlans[idx].lastModified = Date()
        Task { await dataStore.persistToDisk() }
    }

    private func commitDelete() {
        guard let target = deleteTarget,
              let idx = dataStore.importedTrainingPlans.firstIndex(where: { $0.id == target.id }) else {
            deleteTarget = nil
            return
        }
        let wasActive = dataStore.importedTrainingPlans[idx].isActive
        dataStore.importedTrainingPlans.remove(at: idx)
        if wasActive { programStore.activePlanId = nil }
        Task { await dataStore.persistToDisk() }
        deleteTarget = nil
    }
}
