// Views/Training/AddExerciseView.swift
// Add an exercise to a day's program
// Browse master library or create a custom exercise

import SwiftUI

struct AddExerciseView: View {

    let dayType: DayType
    @EnvironmentObject var programStore: TrainingProgramStore
    @Environment(\.dismiss) var dismiss

    @State private var searchText  = ""
    @State private var showCustom  = false
    @State private var selectedCategory: ExerciseCategory? = nil

    // Master exercise library (pull from static data + filter by those not already added)
    private var currentIDs: Set<String> {
        Set(programStore.exercises(for: dayType).map { $0.id })
    }

    private var filteredLibrary: [ExerciseDefinition] {
        var exercises = TrainingProgramData.allExercises
            .filter { !currentIDs.contains($0.id) }

        if let cat = selectedCategory {
            exercises = exercises.filter { $0.category == cat }
        }
        if !searchText.isEmpty {
            exercises = exercises.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.muscleGroups.map(\.rawValue).contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        return exercises.sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search exercises...", text: $searchText)
                }
                .padding(10)
                .background(Color(.systemFill), in: RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

                // Category filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        categoryChip(nil, label: "All")
                        ForEach(ExerciseCategory.allCases, id: \.self) { cat in
                            categoryChip(cat, label: cat.rawValue.capitalized)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }

                Divider()

                if filteredLibrary.isEmpty && !showCustom {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text("No exercises found.\nCreate a custom one below.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Create Custom Exercise") { showCustom = true }
                            .buttonStyle(.borderedProminent)
                        Spacer()
                    }
                } else {
                    List {
                        if !filteredLibrary.isEmpty {
                            Section("EXERCISE LIBRARY") {
                                ForEach(filteredLibrary) { ex in
                                    LibraryExerciseRow(exercise: ex) {
                                        addExercise(ex)
                                    }
                                    .listRowBackground(Color.clear)
                                }
                            }
                        }
                        Section {
                            Button {
                                showCustom = true
                            } label: {
                                Label("Create custom exercise", systemImage: "plus.circle")
                                    .foregroundStyle(.blue)
                            }
                            .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.grouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color.appOrange1.opacity(0.3).ignoresSafeArea())
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showCustom) {
                CustomExerciseForm(dayType: dayType)
                    .environmentObject(programStore)
                    .presentationDetents([.large])
            }
        }
    }

    private func addExercise(_ ex: ExerciseDefinition) {
        var updated = programStore.exercises(for: dayType)
        var newEx = ex
        newEx.dayType = dayType
        newEx.order = (updated.map(\.order).max() ?? 0) + 1
        updated.append(newEx)
        programStore.setExercises(updated, for: dayType)
        dismiss()
    }

    private func categoryChip(_ cat: ExerciseCategory?, label: String) -> some View {
        Button(label) { selectedCategory = cat }
            .font(.caption.weight(.semibold))
            .foregroundStyle(selectedCategory == cat ? .white : .secondary)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(selectedCategory == cat ? Color.blue.opacity(0.8) : Color(.systemFill),
                        in: Capsule())
            .buttonStyle(.plain)
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – Library Row
// ─────────────────────────────────────────────────────────

struct LibraryExerciseRow: View {
    let exercise: ExerciseDefinition
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.name)
                    .font(.subheadline.weight(.medium))
                HStack(spacing: 6) {
                    Text(exercise.category.rawValue.capitalized)
                        .font(.caption2)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(Color.blue.opacity(0.12), in: Capsule())
                        .foregroundStyle(.blue)
                    Text(exercise.muscleGroups.prefix(2).map(\.rawValue).joined(separator: ", "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(exercise.targetSets)×\(exercise.targetReps)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                Button { onAdd() } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – Custom Exercise Form
// ─────────────────────────────────────────────────────────

struct CustomExerciseForm: View {

    let dayType: DayType
    @EnvironmentObject var programStore: TrainingProgramStore
    @Environment(\.dismiss) var dismiss

    @State private var name        = ""
    @State private var category    = ExerciseCategory.freeWeight
    @State private var equipment   = Equipment.dumbbell
    @State private var targetSets  = "3"
    @State private var targetReps  = "8-12"
    @State private var restSeconds = "90"
    @State private var coachingCue = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("EXERCISE DETAILS") {
                    HStack {
                        Text("Name")
                        TextField("e.g. Cable Fly", text: $name)
                            .multilineTextAlignment(.trailing)
                    }
                    Picker("Category", selection: $category) {
                        ForEach(ExerciseCategory.allCases, id: \.self) { c in
                            Text(c.rawValue.capitalized).tag(c)
                        }
                    }
                    Picker("Equipment", selection: $equipment) {
                        ForEach(Equipment.allCases, id: \.self) { e in
                            Text(e.rawValue.capitalized).tag(e)
                        }
                    }
                }

                Section("TARGETS") {
                    HStack {
                        Text("Sets")
                        TextField("3", text: $targetSets)
                            .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Reps")
                        TextField("8-12", text: $targetReps)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Rest (sec)")
                        TextField("90", text: $restSeconds)
                            .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                    }
                }

                Section("COACHING CUE (optional)") {
                    TextField("e.g. Keep elbows slightly bent throughout", text: $coachingCue, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("Custom Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { saveAndDismiss() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func saveAndDismiss() {
        let existing = programStore.exercises(for: dayType)
        let newOrder = (existing.map(\.order).max() ?? 0) + 1
        let ex = ExerciseDefinition(
            id:             UUID().uuidString,
            name:           name.trimmingCharacters(in: .whitespaces),
            category:       category,
            equipment:      equipment,
            muscleGroups:   [],
            targetSets:     Int(targetSets) ?? 3,
            targetReps:     targetReps.isEmpty ? "8-12" : targetReps,
            restSeconds:    Int(restSeconds) ?? 90,
            coachingCue:    coachingCue,
            dayType:        dayType,
            order:          newOrder
        )
        programStore.setExercises(existing + [ex], for: dayType)
        dismiss()
    }
}
