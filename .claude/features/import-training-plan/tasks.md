# Import Training Plan — Task Breakdown (v2 — post-rollback 2026-05-06)

> Supersedes the 2026-04-15 13-task breakdown. v1 tasks (parsers, mapper, orchestrator, preview UI, unit tests) are **already shipped**; this v2 breakdown covers ONLY the gap closure that PRD v2 requires.
>
> **PRD:** [`docs/product/prd/import-training-plan.md`](../../../docs/product/prd/import-training-plan.md)
> **Research:** [`research-persistence-2026-05-06.md`](research-persistence-2026-05-06.md)
> **Estimated effort:** 3.5–5 days
> **Critical path:** T1 → T2 → T5 → T13 → T15 → T17 → T18 (7 hops)

## Tasks

| ID | Title | Type | Skill | Effort | Depends On | Complexity | Lane | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| T1 | Domain model: `ImportedTrainingPlan` + `ImportedDayAssignment` + `ImportedExerciseEntry` + `ImportSource` enum (new file) | model | dev | 0.25d | — | new_model(3) = 3 | E-core | pending |
| T2 | Extend `EncryptedDataStore` — `@Published var importedTrainingPlans` + `clearInMemory` + `deletePersistedData` file-sweep entry | service | dev | 0.25d | T1 | mechanical = 0 | E-core | pending |
| T3 | Extend `EncryptedDataStore.attemptPersist()` + `loadFromDisk()` for the 6th `.ftenc` (extends `writes:` array; rest of 2-phase commit unchanged) | service | dev | 0.25d | T2 | mechanical = 0 | E-core | pending |
| T4 | `EncryptedDataStorePersistenceTests` — 6-collection round-trip + clearInMemory wipe + GDPR Art-17 file-deletion regression | test | qa | 0.5d | T3 | mechanical = 0 | E-core | pending |
| T5 | `TrainingProgramStore` routing layer — `@Published var activePlanId: UUID?` + routing in `exercises(for:)` + `activate(planId:dataStore:)` + `ImportedExerciseEntry → ExerciseDefinition` adapter | service | dev | 0.75d | T2 | token_high(2)+judgment(3) = 5 | P-core | pending |
| T6 | `TrainingProgramStoreTests` — exercises(for:) routing both branches + activate mutual-exclusion + adapter | test | qa | 0.5d | T5 | mechanical = 0 | E-core | pending |
| T7 | Extend `ImportOrchestrator` — day-name → DayType heuristic + replace `confirmImport()` stub with persistence write to `EncryptedDataStore` + emit `import_completed` after `persistToDisk()` succeeds | service | dev | 0.5d | T1, T2, T5 | judgment(3) = 3 | E-core | pending |
| T8 | `ImportOrchestratorTests` — day-name heuristic 7 cases + confirmImport persistence regression + completed-only-after-persist test | test | qa | 0.5d | T7 | mechanical = 0 | E-core | pending |
| T9 | Extend `DataExportService.swift` — 3 touch points (counts list line 34, JSON dict line 62, new `encodeImportedTrainingPlans()` helper) | service | dev | 0.25d | T2 | mechanical = 0 | E-core | pending |
| T10 | `DataExportServiceTests` + `AccountDeletionTests` — GDPR Art-20 export-includes-imported-plans + Art-17 delete-removes-imported-plans-file regression | test | qa | 0.25d | T9 | mechanical = 0 | E-core | pending |
| T11 | Add 3 missing analytics constants (`import_parse_failed`, `import_plan_opened`, `import_plan_activated`) + 2 new screens (`imported_plans_list`, `imported_plan_detail`) to `AnalyticsProvider.swift` + update `docs/product/analytics-taxonomy.csv` | analytics | analytics | 0.25d | — | mechanical = 0 | E-core | pending |
| T12 | Wire all 9 events at trigger points (`import_started` × 2 entry points, `import_source_selected`, `import_parsed`, `import_parse_failed`, `import_mapping_confirmed`, `import_completed`, `import_failed`, `import_plan_opened`, `import_plan_activated`) | analytics | analytics | 0.5d | T7, T11, T13, T14, T15, T16 | mechanical = 0 | E-core | pending |
| T13 | New `ImportedPlansListScreen.swift` (Settings → Data → Imported Plans): empty state, list rows with Active badge, swipe actions (Rename / Activate / Deactivate / Delete), navbar "+" → sheet | ui | dev | 0.75d | T1, T5 | files(2)+new_screen(2)+token_high(2)+judgment(3) = 9 | P-core | pending |
| T14 | Extend `ImportPreviewView` with `mode: .preview / .detail` + day-assignment editor (user reviews the heuristic-assigned `assignedDayType`) | ui | dev | 0.5d | T1, T7 | token_high(2)+judgment(3) = 5 | P-core | pending |
| T15 | Wire `DataSyncSettingsScreen` → `ImportedPlansListScreen` (NavigationLink in new "Imported Plans" SettingsSectionCard) + sheet presentation of `ImportSourcePickerView` from list screen | ui | dev | 0.25d | T13 | mechanical = 0 | E-core | pending |
| T16 | Add `square.and.arrow.down` toolbar button to `TrainingPlanView` (`@State var showImportSheet`) + `.sheet` presentation of `ImportSourcePickerView` | ui | dev | 0.25d | — | mechanical = 0 | E-core | pending |
| T17 | Remove HISTORICAL headers from `ImportSourcePickerView.swift` + `ImportPreviewView.swift` | docs | dev | 0.1d | T15, T16 | mechanical = 0 | E-core | pending |
| T18 | `ImportSmokeUITests.testEntryPointFromSettings_opensSheet` + `xcodebuild build && xcodebuild test` green + state.json `analytics_verification_passed = true` | test | qa | 0.5d | all | mechanical = 0 | E-core | pending |

## Lane summary (v5.1 task complexity classifier)

```text
E-core lane (lightweight, sonnet, parallel where deps allow):
  T1, T2, T3, T4, T6, T7, T8, T9, T10, T11, T12, T15, T16, T17, T18  (15 tasks)

P-core lane (heavyweight, opus, serial):
  T5, T13, T14  (3 tasks)
```

## Critical path (7 hops, ~3 days minimum if no parallelism is hit)

```text
T1 (domain model)
 → T2 (EncryptedDataStore field)
 → T5 (TrainingProgramStore routing — P-core)
 → T13 (ImportedPlansListScreen — P-core)
 → T15 (wire from Settings)
 → T17 (un-HISTORICAL)
 → T18 (build + test + green)
```

## Parallelism opportunities

- T11 (analytics constants) is unblocked from start — can run in parallel with T1 setup
- T16 (Training tab toolbar) is unblocked from start — can run in parallel with T1
- After T2 lands: T9 (DataExportService) and T5 (P-core) can run in parallel
- After T7 lands: T8 + T14 can run in parallel
- After T13 lands: T15 unblocks, T18's UI smoke prerequisite is ready

## Definition of Done per task

- Code compiles (`xcodebuild build`)
- Unit tests added where listed (T4, T6, T8, T10) and passing
- No new lint warnings (`make ui-audit` clean per CLAUDE.md fix-as-you-touch policy)
- For UI tasks (T13, T14, T15, T16): no raw literals (DS-RAW-* rules); semantic tokens only
- For analytics tasks (T11, T12): naming validation checklist re-run; CSV taxonomy synced

## Definition of Done for the feature (Phase 5 gate)

- All 18 tasks `done`
- `xcodebuild test` green (full suite)
- `make ui-audit` 0 P0 (current baseline)
- `make tokens-check` green
- `analytics_verification_passed = true` in state.json
- All 9 analytics events have at least 1 unit test
- 6-collection persistence round-trip test passes
- GDPR Art-17 file-deletion regression test passes
- GDPR Art-20 export-includes test passes
- HISTORICAL headers removed
