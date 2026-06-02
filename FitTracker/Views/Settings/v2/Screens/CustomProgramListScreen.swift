// Views/Settings/v2/Screens/CustomProgramListScreen.swift
// C6 training-program-customization (2026-06-02) — Surface 1.
//
// Sheet showing all saved CustomPrograms. Active program shown first with
// a star badge. Other programs listed below with last-modified date.
// Swipe-to-delete with confirmation. "+ New program" pushes NewProgramSheet
// (sub-modal). Tap row → activate. Active row's gear → editor.

import SwiftUI

struct CustomProgramListScreen: View {
    @EnvironmentObject private var dataStore: EncryptedDataStore
    @EnvironmentObject private var analytics: AnalyticsService

    @State private var showNewProgramSheet = false
    @State private var editingProgram: CustomProgram?
    @State private var programToDelete: CustomProgram?

    var body: some View {
        SettingsDetailScaffold(
            title: "My Programs",
            subtitle: "Tap a program to activate. Swipe a program to delete. The fallback Fixed PPL is always available."
        ) {
            if dataStore.userPreferences.customPrograms.isEmpty {
                emptyState
            } else {
                programListSection
            }
            controlsSection
        }
        .navigationTitle("My Programs")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            analytics.logTrainingCustomProgramListOpened(
                count: dataStore.userPreferences.customPrograms.count
            )
        }
        .sheet(isPresented: $showNewProgramSheet) {
            NewProgramSheet { newProgram in
                createAndActivate(newProgram)
            }
            .environmentObject(dataStore)
            .environmentObject(analytics)
        }
        .sheet(item: $editingProgram) { program in
            CustomProgramEditorScreen(program: program) { saved in
                save(saved)
            }
            .environmentObject(dataStore)
            .environmentObject(analytics)
        }
        .confirmationDialog(
            "Delete program?",
            isPresented: deleteConfirmationBinding,
            presenting: programToDelete
        ) { program in
            Button("Delete \(program.name)", role: .destructive) {
                delete(program)
            }
            Button("Cancel", role: .cancel) {
                programToDelete = nil
            }
        } message: { _ in
            Text("This program will be permanently removed. If it's active, the app will fall back to the Fixed PPL.")
        }
    }

    // MARK: - Sections

    private var emptyState: some View {
        SettingsSectionCard(title: "No custom programs yet", eyebrow: "Empty") {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                Text("You're following the Fixed PPL split. Tap **+ New program** below to start a custom plan from a template or build from scratch.")
                    .font(AppText.body)
                    .foregroundStyle(AppColor.Text.secondary)
            }
        }
    }

    private var programListSection: some View {
        SettingsSectionCard(title: "Saved Programs", eyebrow: "Tap to activate") {
            VStack(spacing: AppSpacing.xSmall) {
                ForEach(sortedPrograms, id: \.id) { program in
                    programRow(program)
                }
            }
        }
    }

    private func programRow(_ program: CustomProgram) -> some View {
        let isActive = dataStore.userPreferences.activeProgramID == program.id
        return HStack(spacing: AppSpacing.small) {
            if isActive {
                Image(systemName: "star.fill")
                    .foregroundStyle(AppColor.Accent.achievement)
            } else {
                Image(systemName: "circle")
                    .foregroundStyle(AppColor.Text.tertiary)
            }
            VStack(alignment: .leading, spacing: AppSpacing.micro) {
                Text(program.name)
                    .font(AppText.body)
                    .foregroundStyle(AppColor.Text.primary)
                Text("\(isActive ? "Active · " : "")\(formattedDate(program.updatedAt))")
                    .font(AppText.caption)
                    .foregroundStyle(AppColor.Text.secondary)
            }
            Spacer()
            Button {
                editingProgram = program
            } label: {
                Image(systemName: "pencil.circle")
                    .font(AppText.body)
                    .foregroundStyle(AppColor.Accent.primary)
            }
            .accessibilityLabel("Edit \(program.name)")
            Button(role: .destructive) {
                programToDelete = program
            } label: {
                Image(systemName: "trash")
                    .font(AppText.body)
                    .foregroundStyle(AppColor.Status.warning)
            }
            .accessibilityLabel("Delete \(program.name)")
        }
        .padding(.vertical, AppSpacing.xSmall)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isActive {
                activate(program)
            }
        }
        .accessibilityLabel("\(program.name)\(isActive ? ", active" : ""), modified \(formattedDate(program.updatedAt))")
    }

    private var controlsSection: some View {
        SettingsSectionCard(title: "New Program", eyebrow: "Create") {
            Button {
                showNewProgramSheet = true
            } label: {
                HStack(spacing: AppSpacing.xSmall) {
                    Image(systemName: AppIcon.add)
                    Text("New program")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColor.Accent.primary)
            .disabled(dataStore.userPreferences.customPrograms.count >= CustomProgramSchema.maxSavedProgramsPerUser)
            if dataStore.userPreferences.customPrograms.count >= CustomProgramSchema.maxSavedProgramsPerUser {
                Text("Maximum \(CustomProgramSchema.maxSavedProgramsPerUser) programs reached. Delete one to create another.")
                    .font(AppText.caption)
                    .foregroundStyle(AppColor.Text.secondary)
            }
        }
    }

    // MARK: - Helpers

    private var sortedPrograms: [CustomProgram] {
        // Active first, then by updatedAt desc
        let prefs = dataStore.userPreferences
        return prefs.customPrograms.sorted { lhs, rhs in
            if lhs.id == prefs.activeProgramID { return true }
            if rhs.id == prefs.activeProgramID { return false }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    private var deleteConfirmationBinding: Binding<Bool> {
        Binding(
            get: { programToDelete != nil },
            set: { newValue in
                if !newValue { programToDelete = nil }
            }
        )
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - Mutations

    private func createAndActivate(_ program: CustomProgram) {
        dataStore.userPreferences.customPrograms.append(program)
        dataStore.userPreferences.activeProgramID = program.id
        Task { await dataStore.persistToDisk() }
        analytics.logTrainingCustomProgramSaved(
            programId: program.id.uuidString,
            dayCount: program.days.filter { !$0.slots.isEmpty }.count,
            totalExerciseCount: program.days.reduce(0) { $0 + $1.slots.count }
        )
        analytics.logTrainingCustomProgramActivated(programId: program.id.uuidString)
    }

    private func activate(_ program: CustomProgram) {
        dataStore.userPreferences.activeProgramID = program.id
        Task { await dataStore.persistToDisk() }
        analytics.logTrainingCustomProgramActivated(programId: program.id.uuidString)
    }

    private func save(_ updated: CustomProgram) {
        guard let index = dataStore.userPreferences.customPrograms.firstIndex(where: { $0.id == updated.id }) else {
            return
        }
        var withBumpedTimestamp = updated
        withBumpedTimestamp.updatedAt = Date()
        dataStore.userPreferences.customPrograms[index] = withBumpedTimestamp
        Task { await dataStore.persistToDisk() }
        analytics.logTrainingCustomProgramSaved(
            programId: withBumpedTimestamp.id.uuidString,
            dayCount: withBumpedTimestamp.days.filter { !$0.slots.isEmpty }.count,
            totalExerciseCount: withBumpedTimestamp.days.reduce(0) { $0 + $1.slots.count }
        )
    }

    private func delete(_ program: CustomProgram) {
        dataStore.userPreferences.customPrograms.removeAll { $0.id == program.id }
        if dataStore.userPreferences.activeProgramID == program.id {
            dataStore.userPreferences.activeProgramID = nil  // PRD OQ-2: auto-reset to fallback
        }
        Task { await dataStore.persistToDisk() }
        analytics.logTrainingCustomProgramDeleted(
            programId: program.id.uuidString,
            dayCount: program.days.count
        )
        programToDelete = nil
    }
}
