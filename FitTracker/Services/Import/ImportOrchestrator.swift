import Foundation

@MainActor
final class ImportOrchestrator: ObservableObject {

    @Published var state: ImportState = .idle
    @Published var currentPlan: ImportedPlan?

    private let parsers: [ImportParser] = [CSVImportParser()]
    private let mapper = ExerciseMapper()

    enum ImportState {
        case idle
        case parsing
        case mapping
        case preview(ImportedPlan)
        case success(ImportedPlan)
        case error(String)
    }

    func importFromText(_ input: String) async {
        state = .parsing

        // Find a parser that can handle this input
        guard let parser = parsers.first(where: { $0.canParse(input) }) else {
            state = .error("Couldn't recognize this format. Try pasting as CSV with a header row.")
            return
        }

        do {
            var plan = try parser.parse(input)
            state = .mapping

            // Map exercises
            for dayIndex in plan.days.indices {
                for exIndex in plan.days[dayIndex].exercises.indices {
                    let raw = plan.days[dayIndex].exercises[exIndex].rawName
                    let result = mapper.map(raw)
                    plan.days[dayIndex].exercises[exIndex].mappedExerciseId = result.exerciseId
                    plan.days[dayIndex].exercises[exIndex].mappingConfidence = result.confidence
                }
            }

            currentPlan = plan
            state = .preview(plan)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func confirmImport() {
        guard let plan = currentPlan else { return }
        state = .success(plan)
    }

    func reset() {
        state = .idle
        currentPlan = nil
    }
}
