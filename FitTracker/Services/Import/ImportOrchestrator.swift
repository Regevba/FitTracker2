import Foundation

@MainActor
final class ImportOrchestrator: ObservableObject {

    @Published var state: ImportState = .idle
    @Published var currentPlan: ImportedPlan?
    @Published var currentDayAssignments: [ImportedDayAssignment] = []
    /// Source-of-truth for the active import attempt. Set when parsing
    /// completes; consumed by `confirmImport(into:)`.
    @Published var sourceUsed: ImportSource = .markdownPaste
    @Published var rawSourceTextSnapshot: String?
    @Published var startedAt: Date = Date()

    private let parsers: [ImportParser] = [JSONImportParser(), CSVImportParser(), MarkdownImportParser()]
    private let mapper = ExerciseMapper()

    enum ImportState {
        case idle
        case parsing
        case mapping
        case preview(ImportedPlan)
        case persisting
        case success(ImportedTrainingPlan)
        case error(String)
    }

    /// Parses input + maps exercises + assigns days via the heuristic. Sets
    /// `state = .preview(plan)` on success; user reviews + can edit the day
    /// assignments before calling `confirmImport(into:)`.
    func importFromText(_ input: String, source: ImportSource = .markdownPaste, retainSourceText: Bool = false) async {
        startedAt = Date()
        sourceUsed = source
        rawSourceTextSnapshot = retainSourceText ? input : nil
        state = .parsing

        guard let parser = parsers.first(where: { $0.canParse(input) }) else {
            state = .error("Couldn't recognize this format. Try pasting as CSV with a header row.")
            return
        }

        do {
            var plan = try parser.parse(input)
            state = .mapping

            for dayIndex in plan.days.indices {
                for exIndex in plan.days[dayIndex].exercises.indices {
                    let raw = plan.days[dayIndex].exercises[exIndex].rawName
                    let result = mapper.map(raw)
                    plan.days[dayIndex].exercises[exIndex].mappedExerciseId = result.exerciseId
                    plan.days[dayIndex].exercises[exIndex].mappingConfidence = result.confidence
                }
            }

            currentPlan = plan
            currentDayAssignments = plan.days.map { day in
                ImportedDayAssignment(
                    originalDayName: day.name,
                    assignedDayType: Self.heuristicDayType(for: day.name),
                    exercises: day.exercises.map { entry in
                        ImportedExerciseEntry(
                            rawName: entry.rawName,
                            mappedExerciseId: entry.mappedExerciseId,
                            mappingConfidence: entry.mappingConfidence,
                            sets: entry.sets,
                            reps: entry.reps,
                            restSeconds: entry.restSeconds
                        )
                    }
                )
            }
            state = .preview(plan)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    /// Persists the parsed + mapped plan as an ImportedTrainingPlan into
    /// `EncryptedDataStore`. Sets `state = .success(plan)` only after
    /// `persistToDisk()` returns successfully.
    func confirmImport(into dataStore: EncryptedDataStore, planName: String? = nil) async {
        guard let plan = currentPlan else { return }
        state = .persisting

        let imported = ImportedTrainingPlan(
            name: planName ?? plan.name,
            source: sourceUsed,
            sourceText: rawSourceTextSnapshot,
            days: currentDayAssignments,
            isActive: false,
            needsSync: true
        )
        dataStore.importedTrainingPlans.append(imported)
        await dataStore.persistToDisk()

        if dataStore.persistenceFailed {
            state = .error("Couldn't save your imported plan. Try again, or contact support if it persists.")
            // Roll back the optimistic append so the next attempt doesn't duplicate.
            if let last = dataStore.importedTrainingPlans.last, last.id == imported.id {
                dataStore.importedTrainingPlans.removeLast()
            }
            return
        }

        state = .success(imported)
    }

    func reset() {
        state = .idle
        currentPlan = nil
        currentDayAssignments = []
        rawSourceTextSnapshot = nil
    }

    /// Maps a parser-output day name (e.g. "Day 1 — Push", "Pull Day", "Legs",
    /// "Cardio Tuesday") to a FitMe `DayType` via keyword matching. Falls back
    /// to round-robin assignment over training days when no keyword matches.
    /// User reviews + edits the assignment in the import preview screen.
    static func heuristicDayType(for dayName: String) -> DayType {
        let lower = dayName.lowercased()

        if lower.contains("rest") || lower.contains("off") || lower.contains("recovery") {
            return .restDay
        }
        if lower.contains("full body") || lower.contains("total body") || lower.contains("whole body") {
            return .fullBody
        }
        if lower.contains("cardio") || lower.contains("zone 2") || lower.contains("hiit") ||
           lower.contains("run") || lower.contains("bike") || lower.contains("rowing") ||
           lower.contains("elliptical") {
            return .cardioOnly
        }
        if lower.contains("push") || lower.contains("chest") || lower.contains("shoulder") {
            return .upperPush
        }
        if lower.contains("pull") || lower.contains("back") || lower.contains("lat") {
            return .upperPull
        }
        if lower.contains("leg") || lower.contains("squat") || lower.contains("deadlift") ||
           lower.contains("lower") {
            return .lowerBody
        }
        return .upperPush
    }
}
