// Views/Training/v2/ExerciseLibraryView.swift
// C3 exercise-search-filter (2026-06-02)
//
// The Exercise Library sheet — the headline component.
//
// Two modes via the `picker` init param:
//   - nil (default)  → read-only browse; row tap pushes ExerciseDetailView
//   - non-nil        → C6 picker mode; row tap calls picker(exercise) + dismisses
//
// The picker-mode init signature is the C6 dependency contract (per
// PRD §"FROZEN constants"):
//   ExerciseLibraryView(source: ..., picker: { exercise in ... })
//
// Composition:
//   - Search field (TextField with magnifying-glass icon, .submitLabel(.search))
//   - 3 filter chip rows (AppFilterBar) — muscle / equipment / category
//   - Result list with ExerciseLibraryRow + count badge ("23 of 50")
//   - Empty state with [Clear all filters] CTA
//
// Filtering is in-memory via ExerciseLibraryFilter at ~50 items.

import SwiftUI

struct ExerciseLibraryView: View {

    // MARK: - Init parameters

    /// nil → read-only browse mode (default). non-nil → C6 picker mode.
    let picker: ((ExerciseDefinition) -> Void)?

    /// Analytics `source` param: "training_toolbar" / "settings_row" / "picker:<feature>".
    let source: String

    // MARK: - State

    @EnvironmentObject private var analytics: AnalyticsService
    @Environment(\.dismiss) private var dismiss

    @State private var query: String = ""
    @State private var selectedMuscle: String = Self.muscleAll
    @State private var selectedEquipment: String = Self.equipmentAll
    @State private var selectedCategory: String = Self.categoryAll

    // MARK: - Initializers (read-only + picker-mode dual init)

    init(source: String) {
        self.source = source
        self.picker = nil
    }

    init(source: String, picker: @escaping (ExerciseDefinition) -> Void) {
        self.source = source
        self.picker = picker
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchField
                Divider()
                filterChipRows
                Divider()
                resultsHeader
                resultList
            }
            .navigationTitle("Exercise Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .onAppear {
            analytics.logTrainingExerciseLibraryOpened(source: source)
        }
    }

    // MARK: - Subviews

    private var searchField: some View {
        HStack(spacing: AppSpacing.xSmall) {
            Image(systemName: AppIcon.search)
                .foregroundStyle(AppColor.Text.secondary)
            TextField("Search exercises…", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .submitLabel(.search)
                .onSubmit {
                    if query.count >= 2 {
                        analytics.logTrainingExerciseSearchQuery(queryLength: query.count)
                    }
                }
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: AppIcon.closeCircle)
                        .foregroundStyle(AppColor.Text.secondary)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, AppSpacing.medium)
        .padding(.vertical, AppSpacing.small)
        .background(AppColor.Surface.secondary)
    }

    private var filterChipRows: some View {
        VStack(spacing: AppSpacing.xSmall) {
            AppFilterBar(
                options: Self.muscleOptions,
                selection: Binding(
                    get: { selectedMuscle },
                    set: { newValue in
                        let old = selectedMuscle
                        selectedMuscle = newValue
                        if newValue != old {
                            analytics.logTrainingExerciseFilterTapped(dimension: "muscle", value: newValue)
                        }
                    }
                ),
                accessibilityLabel: "Filter by muscle"
            )
            AppFilterBar(
                options: Self.equipmentOptions,
                selection: Binding(
                    get: { selectedEquipment },
                    set: { newValue in
                        let old = selectedEquipment
                        selectedEquipment = newValue
                        if newValue != old {
                            analytics.logTrainingExerciseFilterTapped(dimension: "equipment", value: newValue)
                        }
                    }
                ),
                accessibilityLabel: "Filter by equipment"
            )
            AppFilterBar(
                options: Self.categoryOptions,
                selection: Binding(
                    get: { selectedCategory },
                    set: { newValue in
                        let old = selectedCategory
                        selectedCategory = newValue
                        if newValue != old {
                            analytics.logTrainingExerciseFilterTapped(dimension: "category", value: newValue)
                        }
                    }
                ),
                accessibilityLabel: "Filter by category"
            )
        }
        .padding(.vertical, AppSpacing.xSmall)
    }

    @ViewBuilder
    private var resultsHeader: some View {
        if !query.isEmpty || hasAnyChip {
            HStack {
                Text("\(filteredResults.count) of \(TrainingProgramData.allExercises.count) exercises")
                    .font(AppText.caption)
                    .foregroundStyle(AppColor.Text.secondary)
                Spacer()
            }
            .padding(.horizontal, AppSpacing.medium)
            .padding(.vertical, AppSpacing.xSmall)
        }
    }

    @ViewBuilder
    private var resultList: some View {
        if filteredResults.isEmpty {
            emptyState
        } else {
            List(filteredResults, id: \.id) { exercise in
                if picker != nil {
                    ExerciseLibraryRow(exercise: exercise) {
                        handleRowTap(exercise)
                    }
                } else {
                    ZStack {
                        NavigationLink {
                            ExerciseDetailView(exercise: exercise)
                                .onAppear { handleRowTap(exercise) }
                        } label: {
                            EmptyView()
                        }
                        .opacity(0)
                        ExerciseLibraryRow(exercise: exercise) {}
                            .allowsHitTesting(false)
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.medium) {
            Spacer()
            Image(systemName: AppIcon.search)
                .font(AppText.metric)
                .foregroundStyle(AppColor.Text.secondary)
            Text(emptyStateMessage)
                .font(AppText.body)
                .foregroundStyle(AppColor.Text.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.large)
            Button("Clear all filters") {
                query = ""
                selectedMuscle = Self.muscleAll
                selectedEquipment = Self.equipmentAll
                selectedCategory = Self.categoryAll
            }
            .buttonStyle(.bordered)
            Spacer()
        }
    }

    private var emptyStateMessage: String {
        if query.isEmpty {
            return "No exercises match your filters. Tap All in any row to clear that filter."
        } else {
            return "No exercises match \"\(query)\". Tap All in any row to clear a filter, or clear the search."
        }
    }

    // MARK: - Filter resolution

    private var filteredResults: [ExerciseDefinition] {
        ExerciseLibraryFilter.filteredExercises(
            query: query,
            muscle: muscleEnumValue,
            equipment: equipmentEnumValue,
            category: categoryEnumValue
        )
    }

    private var muscleEnumValue: MuscleGroup? {
        selectedMuscle == Self.muscleAll ? nil : MuscleGroup(rawValue: selectedMuscle.lowercased().replacingOccurrences(of: " ", with: ""))
    }

    private var equipmentEnumValue: Equipment? {
        if selectedEquipment == Self.equipmentAll { return nil }
        let normalized = selectedEquipment
        return Equipment.allCases.first { $0.rawValue == normalized }
    }

    private var categoryEnumValue: ExerciseCategory? {
        if selectedCategory == Self.categoryAll { return nil }
        // "Strength" maps to .machine — the rollup happens in
        // ExerciseLibraryFilter.matchesCategory which expands machine/freeWeight/calisthenics.
        switch selectedCategory {
        case "Strength": return .machine
        case "Cardio":   return .cardio
        case "Core":     return .core
        default:         return nil
        }
    }

    private var hasAnyChip: Bool {
        selectedMuscle != Self.muscleAll
            || selectedEquipment != Self.equipmentAll
            || selectedCategory != Self.categoryAll
    }

    private func handleRowTap(_ exercise: ExerciseDefinition) {
        analytics.logTrainingExerciseDetailOpened(
            exerciseId: exercise.id,
            viaSearch: !query.isEmpty,
            viaFilter: hasAnyChip
        )
        if let picker {
            picker(exercise)
            dismiss()
        }
    }

    // MARK: - Static chip taxonomies

    private static let muscleAll = "All"
    private static let equipmentAll = "All"
    private static let categoryAll = "All"

    /// PRD §"Chip dimension taxonomy" — muscle row.
    /// Displayed strings; mapped back to MuscleGroup via lowercasing.
    private static let muscleOptions: [String] = [
        muscleAll, "Chest", "Back", "Shoulders", "Triceps", "Biceps",
        "Quads", "Hamstrings", "Glutes", "Calves", "Core", "Cardiovascular"
    ]

    /// PRD §"Chip dimension taxonomy" — equipment row.
    /// Strings match Equipment.rawValue exactly so direct lookup works.
    private static let equipmentOptions: [String] = [
        equipmentAll, "machine", "barbell", "dumbbell", "cable", "bodyweight",
        "Resistance Band", "elliptical", "Rowing Machine"
    ]

    /// PRD §"Chip dimension taxonomy" — category row.
    /// Strength is the user-facing rollup of machine/freeWeight/calisthenics.
    private static let categoryOptions: [String] = [
        categoryAll, "Strength", "Cardio", "Core"
    ]
}
