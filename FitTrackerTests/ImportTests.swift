import XCTest
@testable import FitTracker

// MARK: - Import Training Plan Tests
// T11: CSV parser, JSON parser, ExerciseMapper, ImportOrchestrator state machine.

final class ImportTests: XCTestCase {

    // MARK: - T11-1: CSV parser detects CSV format

    func testCSVParserCanParse() {
        let parser = CSVImportParser()
        let csv = "Exercise,Sets,Reps,Rest\nBench Press,3,8,90"
        XCTAssertTrue(parser.canParse(csv))
    }

    // MARK: - T11-2: CSV parser rejects non-CSV

    func testCSVParserRejectsNonCSV() {
        let parser = CSVImportParser()
        XCTAssertFalse(parser.canParse("just some text"))
        XCTAssertFalse(parser.canParse(""))
        // Single line with commas but no "exercise" keyword
        XCTAssertFalse(parser.canParse("Name,Count,Duration"))
    }

    // MARK: - T11-3: CSV parser extracts exercises

    func testCSVParserParsesExercises() throws {
        let parser = CSVImportParser()
        let csv = "Exercise,Sets,Reps,Rest\nBench Press,3,8,90\nSquat,4,6,120"
        let plan = try parser.parse(csv)
        XCTAssertEqual(plan.days.first?.exercises.count, 2)
        XCTAssertEqual(plan.days.first?.exercises[0].rawName, "Bench Press")
        XCTAssertEqual(plan.days.first?.exercises[0].sets, 3)
        XCTAssertEqual(plan.days.first?.exercises[0].reps, "8")
        XCTAssertEqual(plan.days.first?.exercises[0].restSeconds, 90)
        XCTAssertEqual(plan.days.first?.exercises[1].rawName, "Squat")
        XCTAssertEqual(plan.days.first?.exercises[1].sets, 4)
    }

    // MARK: - T11-4: JSON parser detects JSON

    func testJSONParserCanParse() {
        let parser = JSONImportParser()
        let json = "{\"name\":\"Test Plan\",\"days\":[]}"
        XCTAssertTrue(parser.canParse(json))
    }

    // MARK: - T11-5: JSON parser rejects non-JSON

    func testJSONParserRejectsNonJSON() {
        let parser = JSONImportParser()
        XCTAssertFalse(parser.canParse("not json at all"))
        XCTAssertFalse(parser.canParse("Exercise,Sets,Reps\nBench Press,3,8"))
    }

    // MARK: - T11-6: JSON parser parses ImportedPlan structure

    func testJSONParserParsesImportedPlan() throws {
        let parser = JSONImportParser()
        let json = """
        {
          "name": "Push Pull Legs",
          "days": [
            {
              "name": "Day 1 — Push",
              "exercises": [
                { "rawName": "Bench Press", "sets": 4, "reps": "8-10", "restSeconds": 90 }
              ]
            }
          ]
        }
        """
        let plan = try parser.parse(json)
        XCTAssertEqual(plan.name, "Push Pull Legs")
        XCTAssertEqual(plan.days.count, 1)
        XCTAssertEqual(plan.days[0].exercises.count, 1)
        XCTAssertEqual(plan.days[0].exercises[0].rawName, "Bench Press")
        XCTAssertEqual(plan.days[0].exercises[0].sets, 4)
        XCTAssertEqual(plan.days[0].exercises[0].reps, "8-10")
    }

    // MARK: - T11-7: ExerciseMapper exact match

    func testExerciseMapperExactMatch() {
        let mapper = ExerciseMapper()
        let result = mapper.map("bench press")
        XCTAssertEqual(result.exerciseId, "bench_press")
        XCTAssertEqual(result.confidence, 1.0)
    }

    // MARK: - T11-8: ExerciseMapper fuzzy match (substring containment)

    func testExerciseMapperFuzzyMatch() {
        let mapper = ExerciseMapper()
        // "flat bench press exercise" contains alias "flat bench" → 0.85
        let result = mapper.map("flat bench press exercise")
        XCTAssertNotNil(result.exerciseId)
        XCTAssertGreaterThan(result.confidence, 0.5)
    }

    // MARK: - T11-9: ExerciseMapper no match for unknown input

    func testExerciseMapperNoMatch() {
        let mapper = ExerciseMapper()
        let result = mapper.map("quantum yoga fusion")
        XCTAssertNil(result.exerciseId)
        XCTAssertEqual(result.confidence, 0)
    }

    // MARK: - T11-10: ExerciseMapper common aliases

    func testExerciseMapperCommonAliases() {
        let mapper = ExerciseMapper()
        XCTAssertEqual(mapper.map("ohp").exerciseId, "overhead_press")
        XCTAssertEqual(mapper.map("rdl").exerciseId, "romanian_deadlift")
        XCTAssertEqual(mapper.map("pull-up").exerciseId, "pull_ups")
        XCTAssertEqual(mapper.map("deadlift").exerciseId, "deadlift")
        XCTAssertEqual(mapper.map("squat").exerciseId, "barbell_squat")
    }

    // MARK: - T11-11: CSV parser throws ImportError on empty input

    func testCSVParserEmptyInput() {
        let parser = CSVImportParser()
        XCTAssertThrowsError(try parser.parse("")) { error in
            XCTAssertTrue(error is ImportError)
        }
    }

    // MARK: - T11-12: ImportOrchestrator transitions to .error for unsupported format

    @MainActor
    func testOrchestratorErrorOnUnsupportedFormat() async {
        let orchestrator = ImportOrchestrator()
        await orchestrator.importFromText("this is not csv or json")
        if case .error(let msg) = orchestrator.state {
            XCTAssertFalse(msg.isEmpty)
        } else {
            XCTFail("Expected .error state, got \(orchestrator.state)")
        }
    }

    // MARK: - T11-13: ImportOrchestrator transitions to .preview after valid CSV

    @MainActor
    func testOrchestratorPreviewAfterValidCSV() async {
        let orchestrator = ImportOrchestrator()
        let csv = "Exercise,Sets,Reps,Rest\nBench Press,3,8,90"
        await orchestrator.importFromText(csv)
        if case .preview(let plan) = orchestrator.state {
            XCTAssertFalse(plan.days.isEmpty)
            XCTAssertEqual(plan.days.first?.exercises.first?.rawName, "Bench Press")
            // Mapper should have populated exerciseId and confidence
            XCTAssertNotNil(plan.days.first?.exercises.first?.mappedExerciseId)
            XCTAssertNotNil(plan.days.first?.exercises.first?.mappingConfidence)
        } else {
            XCTFail("Expected .preview state, got \(orchestrator.state)")
        }
    }

    // MARK: - T11-14: ImportOrchestrator confirmImport transitions to .success

    @MainActor
    func testOrchestratorConfirmImport() async {
        let orchestrator = ImportOrchestrator()
        let csv = "Exercise,Sets,Reps,Rest\nSquat,4,6,120"
        await orchestrator.importFromText(csv)
        orchestrator.confirmImport()
        if case .success(let plan) = orchestrator.state {
            XCTAssertFalse(plan.days.isEmpty)
        } else {
            XCTFail("Expected .success state, got \(orchestrator.state)")
        }
    }

    // MARK: - T11-15: ImportOrchestrator reset returns to .idle

    @MainActor
    func testOrchestratorReset() async {
        let orchestrator = ImportOrchestrator()
        let csv = "Exercise,Sets,Reps,Rest\nDeadlift,3,5,180"
        await orchestrator.importFromText(csv)
        orchestrator.reset()
        if case .idle = orchestrator.state {
            XCTAssertNil(orchestrator.currentPlan)
        } else {
            XCTFail("Expected .idle state after reset, got \(orchestrator.state)")
        }
    }
}
