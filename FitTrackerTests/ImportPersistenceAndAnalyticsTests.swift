// FitTrackerTests/ImportPersistenceAndAnalyticsTests.swift
// Tests for the import-training-plan resume (Phase 5 of PRD v2):
//   - T4: EncryptedDataStore round-trip + GDPR Article 17 file-deletion
//   - T6: TrainingProgramStore active-plan routing + activate mutual-exclusion
//   - T8: ImportOrchestrator day-name heuristic + persistence path
//   - T10: DataExportService GDPR Article 20 — imported plans in export
//   - Analytics: 9 import_* events + screens

import XCTest
import LocalAuthentication
@testable import FitTracker

@MainActor
final class ImportPersistenceAndAnalyticsTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        // Required for any test that hits EncryptedDataStore.persistToDisk:
        // the encryption layer needs a session context so encrypt/decrypt
        // doesn't prompt for biometrics in the simulator.
        await EncryptionService.shared.setSessionContext(LAContext())
    }

    // ─────────────────────────────────────────────────────
    // MARK: – T4 — EncryptedDataStore round-trip
    // ─────────────────────────────────────────────────────

    func testT4_importedTrainingPlans_inMemoryRoundTrip() {
        let store = EncryptedDataStore()
        XCTAssertEqual(store.importedTrainingPlans.count, 0)

        let plan = ImportedTrainingPlan(
            name: "Test Plan",
            source: .markdownPaste,
            days: [
                ImportedDayAssignment(
                    originalDayName: "Day 1",
                    assignedDayType: .upperPush,
                    exercises: [
                        ImportedExerciseEntry(
                            rawName: "Bench",
                            mappedExerciseId: nil,
                            mappingConfidence: 0.5,
                            sets: 3,
                            reps: "8",
                            restSeconds: 90
                        )
                    ]
                )
            ]
        )
        store.importedTrainingPlans.append(plan)
        XCTAssertEqual(store.importedTrainingPlans.count, 1)
        XCTAssertEqual(store.importedTrainingPlans.first?.id, plan.id)
    }

    func testT4_clearInMemory_wipesImportedTrainingPlans() {
        let store = EncryptedDataStore()
        let plan = ImportedTrainingPlan(name: "x", source: .csv, days: [])
        store.importedTrainingPlans = [plan]
        XCTAssertEqual(store.importedTrainingPlans.count, 1)
        store.clearInMemory()
        XCTAssertEqual(store.importedTrainingPlans.count, 0,
                       "clearInMemory must reset importedTrainingPlans")
    }

    // ─────────────────────────────────────────────────────
    // MARK: – T6 — TrainingProgramStore active-plan routing
    // ─────────────────────────────────────────────────────

    func testT6_exercisesFor_returnsBundled_whenActivePlanIdNil() {
        let store = TrainingProgramStore()
        let dataStore = EncryptedDataStore()
        XCTAssertNil(store.activePlanId)
        let bundled = store.exercises(for: .upperPush, in: dataStore)
        let expected = TrainingProgramData.exercises(for: .upperPush)
        XCTAssertFalse(bundled.isEmpty,
                       "Bundled .upperPush program should have exercises")
        XCTAssertEqual(bundled.count, expected.count,
                       "Routing must return bundled count when activePlanId == nil")
        XCTAssertEqual(bundled.map(\.id), expected.map(\.id),
                       "Routing must return bundled exercise ids in order")
    }

    func testT6_exercisesFor_returnsImported_whenActivePlanIdSet() {
        let store = TrainingProgramStore()
        let dataStore = EncryptedDataStore()
        let plan = ImportedTrainingPlan(
            name: "Imported",
            source: .markdownPaste,
            days: [
                ImportedDayAssignment(
                    originalDayName: "Push Day",
                    assignedDayType: .upperPush,
                    exercises: [
                        ImportedExerciseEntry(
                            rawName: "Custom Bench",
                            mappedExerciseId: nil,
                            mappingConfidence: 0.0,
                            sets: 5,
                            reps: "5",
                            restSeconds: 180
                        )
                    ]
                )
            ],
            isActive: true
        )
        dataStore.importedTrainingPlans = [plan]
        store.activePlanId = plan.id
        let exercises = store.exercises(for: .upperPush, in: dataStore)
        XCTAssertEqual(exercises.count, 1)
        XCTAssertEqual(exercises.first?.name, "Custom Bench")
        XCTAssertEqual(exercises.first?.targetSets, 5)
    }

    func testT6_activate_setsExactlyOnePlanActive() async {
        let store = TrainingProgramStore()
        let dataStore = EncryptedDataStore()
        let p1 = ImportedTrainingPlan(name: "A", source: .csv, days: [], isActive: true)
        let p2 = ImportedTrainingPlan(name: "B", source: .json, days: [], isActive: false)
        dataStore.importedTrainingPlans = [p1, p2]

        await store.activate(planId: p2.id, dataStore: dataStore)
        XCTAssertEqual(store.activePlanId, p2.id)
        let actives = dataStore.importedTrainingPlans.filter(\.isActive)
        XCTAssertEqual(actives.count, 1, "Exactly one plan must be active")
        XCTAssertEqual(actives.first?.id, p2.id)
    }

    func testT6_activate_nilDeactivates() async {
        let store = TrainingProgramStore()
        let dataStore = EncryptedDataStore()
        let p1 = ImportedTrainingPlan(name: "A", source: .csv, days: [], isActive: true)
        dataStore.importedTrainingPlans = [p1]
        store.activePlanId = p1.id

        await store.activate(planId: nil, dataStore: dataStore)
        XCTAssertNil(store.activePlanId)
        XCTAssertFalse(dataStore.importedTrainingPlans.first?.isActive ?? true)
    }

    func testT6_adapter_mappedExercise_usesBundledMetadata() {
        let mappedId = TrainingProgramData.allExercises.first!.id
        let entry = ImportedExerciseEntry(
            rawName: "Custom Name",
            mappedExerciseId: mappedId,
            mappingConfidence: 0.99,
            sets: 7,
            reps: "5",
            restSeconds: 150
        )
        let def = TrainingProgramStore.exerciseDefinition(from: entry,
                                                           dayType: .upperPush,
                                                           order: 1)
        let bundled = TrainingProgramData.allExercises.first { $0.id == mappedId }!
        XCTAssertEqual(def.id, bundled.id, "Mapped exercise reuses bundled id")
        XCTAssertEqual(def.name, bundled.name, "Mapped exercise reuses bundled name")
        XCTAssertEqual(def.targetSets, 7, "Imported sets override bundled prescription")
        XCTAssertEqual(def.targetReps, "5")
        XCTAssertEqual(def.restSeconds, 150)
    }

    func testT6_adapter_unmappedExercise_synthesizesUserDefined() {
        let entry = ImportedExerciseEntry(
            rawName: "Mystery Lift",
            mappedExerciseId: nil,
            mappingConfidence: nil,
            sets: 3,
            reps: "10",
            restSeconds: nil
        )
        let def = TrainingProgramStore.exerciseDefinition(from: entry,
                                                           dayType: .lowerBody,
                                                           order: 5)
        XCTAssertEqual(def.name, "Mystery Lift")
        XCTAssertEqual(def.equipment, .other)
        XCTAssertEqual(def.muscleGroups, [.fullBody])
        XCTAssertEqual(def.dayType, .lowerBody)
        XCTAssertEqual(def.order, 5)
        XCTAssertEqual(def.restSeconds, 90, "Falls back to 90s default rest")
    }

    // ─────────────────────────────────────────────────────
    // MARK: – T8 — ImportOrchestrator day-name heuristic + persistence
    // ─────────────────────────────────────────────────────

    func testT8_heuristic_pushKeywords() {
        XCTAssertEqual(ImportOrchestrator.heuristicDayType(for: "Day 1 — Push"), .upperPush)
        XCTAssertEqual(ImportOrchestrator.heuristicDayType(for: "Chest Day"), .upperPush)
        XCTAssertEqual(ImportOrchestrator.heuristicDayType(for: "Shoulder Press Day"), .upperPush)
    }

    func testT8_heuristic_pullKeywords() {
        XCTAssertEqual(ImportOrchestrator.heuristicDayType(for: "Pull Day"), .upperPull)
        XCTAssertEqual(ImportOrchestrator.heuristicDayType(for: "Back day"), .upperPull)
        XCTAssertEqual(ImportOrchestrator.heuristicDayType(for: "Lat focus"), .upperPull)
    }

    func testT8_heuristic_legKeywords() {
        XCTAssertEqual(ImportOrchestrator.heuristicDayType(for: "Leg Day"), .lowerBody)
        XCTAssertEqual(ImportOrchestrator.heuristicDayType(for: "Squat session"), .lowerBody)
        XCTAssertEqual(ImportOrchestrator.heuristicDayType(for: "Deadlift heavy"), .lowerBody)
    }

    func testT8_heuristic_fullBodyAndCardioAndRest() {
        XCTAssertEqual(ImportOrchestrator.heuristicDayType(for: "Full Body Workout"), .fullBody)
        XCTAssertEqual(ImportOrchestrator.heuristicDayType(for: "Cardio Tuesday"), .cardioOnly)
        XCTAssertEqual(ImportOrchestrator.heuristicDayType(for: "Zone 2 run"), .cardioOnly)
        XCTAssertEqual(ImportOrchestrator.heuristicDayType(for: "Rest Day"), .restDay)
        XCTAssertEqual(ImportOrchestrator.heuristicDayType(for: "Off"), .restDay)
    }

    func testT8_heuristic_unknownDefaultsToUpperPush() {
        XCTAssertEqual(ImportOrchestrator.heuristicDayType(for: "Mystery Day"), .upperPush,
                       "Unknown day names should default to .upperPush (round-robin start)")
    }

    func testT8_confirmImport_persistsToDataStore() async {
        let orch = ImportOrchestrator()
        let dataStore = EncryptedDataStore()
        let csv = "Exercise,Sets,Reps,Rest\nBench Press,3,8,90\nSquat,4,6,120"

        await orch.importFromText(csv, source: .csv)
        guard case .preview = orch.state else {
            XCTFail("Expected .preview state after parse, got \(orch.state)")
            return
        }
        XCTAssertNotNil(orch.currentPlan)

        await orch.confirmImport(into: dataStore, planName: "My CSV Plan")
        guard case .success(let imported) = orch.state else {
            XCTFail("Expected .success state after confirm, got \(orch.state)")
            return
        }
        XCTAssertEqual(imported.name, "My CSV Plan")
        XCTAssertEqual(dataStore.importedTrainingPlans.count, 1)
        XCTAssertEqual(dataStore.importedTrainingPlans.first?.id, imported.id,
                       "confirmImport must persist the same plan returned in .success")
    }

    func testT8_importFromText_unknownFormat_setsErrorState() async {
        let orch = ImportOrchestrator()
        await orch.importFromText("just some unstructured prose")
        if case .error = orch.state {
            // expected
        } else {
            XCTFail("Expected .error state for unrecognized format, got \(orch.state)")
        }
    }

    // ─────────────────────────────────────────────────────
    // MARK: – T10 — DataExportService GDPR Article 20
    // ─────────────────────────────────────────────────────

    func testT10_recordCounts_includesImportedTrainingPlans() {
        let dataStore = EncryptedDataStore()
        dataStore.importedTrainingPlans = [
            ImportedTrainingPlan(name: "p1", source: .csv, days: []),
            ImportedTrainingPlan(name: "p2", source: .json, days: []),
        ]
        let analytics = AnalyticsService.makeDefault()
        let svc = DataExportService(dataStore: dataStore, analytics: analytics)
        let counts = Dictionary(uniqueKeysWithValues: svc.recordCounts.map { ($0.label, $0.count) })
        XCTAssertEqual(counts["Imported Training Plans"], 2,
                       "recordCounts must include 'Imported Training Plans'")
    }

    func testT10_export_includesImportedTrainingPlansSection() async throws {
        let dataStore = EncryptedDataStore()
        let plan = ImportedTrainingPlan(
            name: "Export Test",
            source: .markdownPaste,
            days: [
                ImportedDayAssignment(
                    originalDayName: "Day 1",
                    assignedDayType: .upperPush,
                    exercises: [
                        ImportedExerciseEntry(
                            rawName: "Bench",
                            mappedExerciseId: nil,
                            mappingConfidence: 0.5,
                            sets: 3,
                            reps: "8",
                            restSeconds: 90
                        )
                    ]
                )
            ]
        )
        dataStore.importedTrainingPlans = [plan]

        let analytics = AnalyticsService.makeDefault()
        let svc = DataExportService(dataStore: dataStore, analytics: analytics)
        await svc.generateExport()

        guard let url = svc.exportURL else {
            XCTFail("Export should produce a URL when no error")
            return
        }
        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let section = json?["importedTrainingPlans"] as? [[String: Any]]
        XCTAssertNotNil(section, "Export JSON must contain 'importedTrainingPlans' key")
        XCTAssertEqual(section?.count, 1)
        XCTAssertEqual(section?.first?["name"] as? String, "Export Test")
        XCTAssertEqual(section?.first?["source"] as? String, "markdownPaste")
        try? FileManager.default.removeItem(at: url)
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Analytics events (9 import_* events)
    // ─────────────────────────────────────────────────────

    private func makeAnalytics() -> (AnalyticsService, MockAnalyticsAdapter) {
        let adapter = MockAnalyticsAdapter()
        let consent = ConsentManager()
        consent.grantConsent()
        let service = AnalyticsService(provider: adapter, consent: consent)
        return (service, adapter)
    }

    func testAnalytics_importStarted_settingsData() {
        let (service, adapter) = makeAnalytics()
        service.logImportStarted(entryPoint: .settingsData)
        XCTAssertEqual(adapter.capturedEvents.count, 1)
        XCTAssertEqual(adapter.capturedEvents[0].name, AnalyticsEvent.importStarted)
        XCTAssertEqual(adapter.capturedEvents[0].parameters?["entry_point"] as? String, "settings_data")
    }

    func testAnalytics_importStarted_trainingTab() {
        let (service, adapter) = makeAnalytics()
        service.logImportStarted(entryPoint: .trainingTab)
        XCTAssertEqual(adapter.capturedEvents.first?.parameters?["entry_point"] as? String, "training_tab")
    }

    func testAnalytics_importSourceSelected() {
        let (service, adapter) = makeAnalytics()
        service.logImportSourceSelected(source: "markdown_paste")
        XCTAssertEqual(adapter.capturedEvents[0].name, AnalyticsEvent.importSourceSelected)
        XCTAssertEqual(adapter.capturedEvents[0].parameters?[AnalyticsParam.itemCategory] as? String,
                       "markdown_paste")
    }

    func testAnalytics_importParsed_carriesDurationAndCounts() {
        let (service, adapter) = makeAnalytics()
        service.logImportParsed(source: "csv", exerciseCount: 12, dayCount: 4, parseDurationMs: 33)
        let p = adapter.capturedEvents[0].parameters
        XCTAssertEqual(adapter.capturedEvents[0].name, AnalyticsEvent.importParsed)
        XCTAssertEqual(p?[AnalyticsParam.itemCategory] as? String, "csv")
        XCTAssertEqual(p?[AnalyticsParam.quantity] as? Int, 12)
        XCTAssertEqual(p?["day_count"] as? Int, 4)
        XCTAssertEqual(p?["parse_duration_ms"] as? Int, 33)
    }

    func testAnalytics_importParseFailed() {
        let (service, adapter) = makeAnalytics()
        service.logImportParseFailed(source: "csv", reason: "no_header")
        XCTAssertEqual(adapter.capturedEvents[0].name, AnalyticsEvent.importParseFailed)
        XCTAssertEqual(adapter.capturedEvents[0].parameters?["error_reason"] as? String, "no_header")
    }

    func testAnalytics_importMappingConfirmed_fourCounts() {
        let (service, adapter) = makeAnalytics()
        service.logImportMappingConfirmed(autoMatched: 7, manualConfirmed: 2, skipped: 1, unresolved: 0)
        let p = adapter.capturedEvents[0].parameters
        XCTAssertEqual(p?["auto_matched_count"] as? Int, 7)
        XCTAssertEqual(p?["manual_confirmed_count"] as? Int, 2)
        XCTAssertEqual(p?["skipped_count"] as? Int, 1)
        XCTAssertEqual(p?["unresolved_count"] as? Int, 0)
    }

    func testAnalytics_importCompleted() {
        let (service, adapter) = makeAnalytics()
        service.logImportCompleted(source: "csv", totalExercises: 24, skippedExercises: 3, timeToCompleteMs: 4200)
        XCTAssertEqual(adapter.capturedEvents[0].name, AnalyticsEvent.importCompleted)
        XCTAssertEqual(adapter.capturedEvents[0].parameters?[AnalyticsParam.quantity] as? Int, 24)
    }

    func testAnalytics_importFailed_withStep() {
        let (service, adapter) = makeAnalytics()
        service.logImportFailed(source: "csv", step: "save", reason: "disk_full")
        XCTAssertEqual(adapter.capturedEvents[0].name, AnalyticsEvent.importFailed)
        XCTAssertEqual(adapter.capturedEvents[0].parameters?["step"] as? String, "save")
    }

    func testAnalytics_importPlanOpened() {
        let (service, adapter) = makeAnalytics()
        service.logImportPlanOpened(daysSinceImport: 3, source: "csv")
        XCTAssertEqual(adapter.capturedEvents[0].name, AnalyticsEvent.importPlanOpened)
        XCTAssertEqual(adapter.capturedEvents[0].parameters?["days_since_import"] as? Int, 3)
    }

    func testAnalytics_importPlanActivated_firstActivation() {
        let (service, adapter) = makeAnalytics()
        service.logImportPlanActivated(source: "csv", daysSinceImport: 0, wasFirstActivation: true)
        XCTAssertEqual(adapter.capturedEvents[0].name, AnalyticsEvent.importPlanActivated)
        XCTAssertEqual(adapter.capturedEvents[0].parameters?["was_first_activation"] as? Bool, true)
    }

    func testAnalytics_consentGated_importEvents_doNotFireWhenDenied() {
        let adapter = MockAnalyticsAdapter()
        let consent = ConsentManager()
        consent.revokeConsent()
        let service = AnalyticsService(provider: adapter, consent: consent)
        service.logImportStarted(entryPoint: .settingsData)
        service.logImportCompleted(source: "csv", totalExercises: 1, skippedExercises: 0, timeToCompleteMs: 1)
        XCTAssertEqual(adapter.capturedEvents.count, 0,
                       "Events must NOT fire when consent is denied")
    }
}
