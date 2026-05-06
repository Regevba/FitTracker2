# PRD: Import Training Plan

> **ID:** import-training-plan | **Status:** Phase 1 (rewritten 2026-05-06) | **Priority:** HIGH
> **Last Updated:** 2026-05-06 | **Branch:** feature/import-training-plan-resume (pending)
> **Predecessor PRD:** v1 of this file (2026-04-15) — superseded after audit UI-015 surfaced a structural persistence gap. Original v1 archived in git history (commit `0f9b4be` baseline). Honest disclosure: v1 claimed `ImportOrchestrator` writes to `TrainingProgramData`, which was structurally impossible — `TrainingProgramData` is a `struct` with only `static let` fields. v2 closes that gap.
> **Research basis:** [`.claude/features/import-training-plan/research.md`](../../../.claude/features/import-training-plan/research.md) (2026-04-12, market + competitive) + [`.claude/features/import-training-plan/research-persistence-2026-05-06.md`](../../../.claude/features/import-training-plan/research-persistence-2026-05-06.md) (persistence + active-plan + GDPR + sync architecture)

---

## Purpose

Allow users to bring training plans from external sources — CSV/JSON exports, spreadsheets, coach PDFs, AI-generated programs, and pasted text — into FitMe as **persisted, activatable** plans, eliminating migration friction and removing a major adoption barrier.

## Problem Statement

FitMe has a strong training experience, but it assumes users start fresh. The reality is that a large portion of motivated fitness users already have a plan:

- Athletes migrating from Hevy or Strong have CSV/JSON exports they cannot use
- Coach clients receive plans as spreadsheets, PDFs, or WhatsApp messages
- AI-native users generate training programs via ChatGPT, Claude, or Gemini and want to run them in a tracking app
- Manual re-entry is so tedious that many users choose to stay in the app they know rather than migrate to a better one

The gap is not missing exercises or features — it is that every new FitMe user with an existing plan has to throw it away. Import removes that barrier.

## Business Objective

Reduce new-user churn caused by plan re-entry friction. Convert users who already have a coach or AI-generated plan into active FitMe plan followers within their first session. A user who imports a plan AND activates it on day one has a tracking commitment to FitMe; activation (not just import) is the conversion signal.

---

## Scope: Phase 1 vs Phase 2

This PRD scopes **Phase 1 only**. Phase 2 is enumerated for clarity and tracked as a separate follow-up PRD.

### Phase 1 (this resume)

| Capability | In scope |
|---|---|
| 3 parsers (CSV, JSON, Markdown) | ✅ (already shipped pre-audit) |
| Exercise alias mapping (87-exercise library) | ✅ (already shipped pre-audit) |
| Source picker + Preview UI | ✅ (already shipped, **un-HISTORICAL** + wire) |
| **Persistence to `EncryptedDataStore`** | ✅ NEW |
| **Active-plan switching (Training tab read fan-out)** | ✅ NEW |
| **Imported Plans list view (Settings → Data)** | ✅ NEW |
| **Imported Plan Detail view (rename / activate / delete)** | ✅ NEW |
| **GDPR Article 17 (delete) + Article 20 (export) integration** | ✅ NEW |
| **8 analytics events instrumented** (6 existing constants + 2 new) | ✅ NEW |
| **Two entry points** (Settings → Data → Imported Plans + Training tab toolbar) | ✅ NEW |
| On-device only (no CloudKit/Supabase sync wiring) | ✅ (Phase 1 boundary) |

### Phase 2 (deferred to a follow-up PRD)

| Capability | Reason for deferral |
|---|---|
| CloudKit per-record sync for imported plans | Sync semantics for "is the same plan on two devices one record or two" warrants its own PRD |
| Supabase `imported_training_plans` table | Same |
| Per-day editor for unmapped exercises | Phase 1 surfaces unmapped via raw name + warning; per-day editor is polish, not blocker |
| AI prompt regeneration via `AIOrchestrator` | "Same plan but dumbbell substitutions" is its own UX flow |
| PDF text extraction (image-PDF support) | Phase 1 supports text-PDF only; image-only PDFs require OCR pass |
| Photo / handwritten OCR via Vision | Standalone scope |
| iOS Share Extension | Separate extension target; significant scope |
| Phase/mesocycle structure (accumulation, intensification, deload) | Requires extending TrainingPlan model |
| RPE-based progression | Requires RPE field in ExerciseSet model |

---

## Success Metrics

| Metric | Tier | Baseline | Target | Kill Criteria |
| --- | --- | --- | --- | --- |
| Import success rate (parser + mapping produces a usable plan, no manual fix required) | T1 (Instrumented post-launch via `import_completed / import_started`) | 0% (no system today) | ≥ 80% | < 30% after 30 days → simplify to CSV-only |
| Exercise mapping accuracy (% exercises auto-matched at ≥ 0.95 confidence) | T1 (Instrumented via `import_mapping_confirmed.auto_matched_count / total`) | 0% | ≥ 90% | < 70% (trust broken) |
| Time to first usable imported workout (from `import_started` to first `training_workout_start` against the imported plan) | T1 (computed from event sequence) | N/A | < 5 min end-to-end | > 15 min median |
| **Plan activation rate** (% of `import_completed` that flip a plan to `isActive=true` within session) | T1 (instrumented via new `import_plan_activated` event — see Analytics Spec below) | 0% | ≥ 80% of completed imports | < 40% at 30 days (means users import but don't trust enough to activate) |
| **Plan adoption rate** (imported plan opened or trained against within 7 days of import) | T1 (instrumented via `import_plan_opened` + `training_workout_start` cross-ref) | 0% | ≥ 60% of importers | < 25% at 30 days |
| User satisfaction rating on import experience (in-app rating prompt 7d post-import) | T2 (Declared — survey, n=50 minimum) | N/A | ≥ 4/5 in-app rating | ≤ 3/5 median |

**North Star:** import-attributed WAU trending up; mapping accuracy stable or improving over time as alias dictionary grows.

**Post-launch review cadence:** First review 7 days after first 50 imports, then monthly.

**Note vs v1 PRD:** v1 had no "Plan activation rate" metric. v1's "Plan adoption rate" presupposed a way for the user to *open* an imported plan, but no such surface existed. v2 adds the activation metric (the actual conversion signal) and grounds adoption in the new Imported Plans list view.

---

## Persistence + Active-Plan Switching (NEW SECTION — closes audit UI-015 gap)

This section grounds every persistence claim in actual file:line touch points. Phase 6 review **must** spot-check that the implementation matches each row of this table.

### Domain model

```swift
struct ImportedTrainingPlan: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    let createdAt: Date
    var lastModified: Date
    let source: ImportSource
    let sourceText: String?         // raw input — opt-in for AI regenerate (Phase 2)
    var days: [ImportedDayAssignment]
    var isActive: Bool              // exactly one plan can be active at a time (enforced in store)
    var needsSync: Bool             // CloudKit/Supabase sync flag (Phase 2)
}

struct ImportedDayAssignment: Codable, Equatable {
    let originalDayName: String     // "Day 1 — Push" from parser
    var assignedDayType: DayType    // .upperPush / .lowerBody / etc. (heuristic + user-editable)
    var exercises: [ImportedExerciseEntry]
}

struct ImportedExerciseEntry: Codable, Equatable {
    let rawName: String
    var mappedExerciseId: String?
    var mappingConfidence: Double?
    var sets: Int
    var reps: String
    var restSeconds: Int?
}

enum ImportSource: String, Codable {
    case csv, json, markdownPaste, pdf, photo, share
}
```

### Persistence touch points

| File | Line(s) | Change |
|---|---|---|
| `FitTracker/Models/ImportedTrainingPlan.swift` | (new) | Define the 4 types above. Standalone file. |
| `FitTracker/Services/Encryption/EncryptionService.swift` | 779–792 | + `@Published var importedTrainingPlans: [ImportedTrainingPlan] = []` |
| `FitTracker/Services/Encryption/EncryptionService.swift` | 803–812 | + `importedTrainingPlans = []` in `clearInMemory()` |
| `FitTracker/Services/Encryption/EncryptionService.swift` | 814–827 | + `"importedTrainingPlans"` to the file-name list in `deletePersistedData()` |
| `FitTracker/Services/Encryption/EncryptionService.swift` | 971–1025 | + encrypt + write `importedTrainingPlans` to `importedTrainingPlans.ftenc` (extends `writes:` array; rest of two-phase commit unchanged) |
| `FitTracker/Services/Encryption/EncryptionService.swift` | 1027–1062 | + decrypt + restore `importedTrainingPlans` in `loadFromDisk()` |

### Active-plan switching touch points

| File | Line(s) | Change |
|---|---|---|
| `FitTracker/Services/TrainingProgramStore.swift` | 13 (class) | + `@Published var activePlanId: UUID?` |
| `FitTracker/Services/TrainingProgramStore.swift` | 27 (`exercises(for:)`) | Becomes the routing layer: if `activePlanId == nil` → existing `TrainingProgramData.exercises(for:)`; else → look up plan in `EncryptedDataStore.importedTrainingPlans`, find `ImportedDayAssignment` matching `day`, convert each `ImportedExerciseEntry` to an `ExerciseDefinition` view, return |
| `FitTracker/Services/TrainingProgramStore.swift` | (new method) | + `func activate(planId: UUID?, dataStore: EncryptedDataStore)` — flips all `isActive=true` to `false`, sets the chosen one to `true`, persists via `dataStore.persistToDisk()` |
| `FitTracker/Views/Training/v2/TrainingPlanView.swift` | 34 (`exercisesForSelectedDay`) | Switch from `TrainingProgramData.exercises(for: selectedDay)` to `programStore.exercises(for: selectedDay)` (already injected as `@EnvironmentObject`) |

### `ImportedExerciseEntry → ExerciseDefinition` adapter

For `mappedExerciseId != nil` entries (high-confidence library match): direct lookup; use the bundled exercise's full metadata (equipment type, muscle groups, instruction text). For unmapped entries: synthesize a `userImported` exercise definition with `rawName`, sets/reps/rest from the import, blank instruction text, equipment type `.unknown`, muscle groups `[.unknown]`. The adapter is internal to `TrainingProgramStore`; no public API change for callers.

### Day-name → DayType heuristic

Applied at parse time in `ImportOrchestrator`:

```
"push" / "chest" / "shoulder press"   → .upperPush
"pull" / "back" / "row"               → .upperPull
"leg" / "squat" / "deadlift"          → .lowerBody
"full body" / "total body"            → .fullBody
"cardio" / "run" / "bike"             → .cardioOnly
"rest" / "off"                        → .restDay
otherwise                             → round-robin assignment
```

User reviews the assignment in the import preview before confirming. Heuristic is a starting point, not authoritative. Confirmed assignment is persisted as `assignedDayType`.

---

## GDPR Integration (NEW SECTION — closes audit UI-015 gap)

### Article 17 (right to erasure)

`AccountDeletionService.swift:151` already calls `dataStore.deletePersistedData()`. Once `importedTrainingPlans.ftenc` is in that function's file-sweep list (see Persistence touch points above), Article 17 is satisfied transitively. No additional surface change needed in `AccountDeletionService`.

**Test contract (Phase 5):** `AccountDeletionTests` must include a regression that imports a plan, calls `deletePersistedData()`, and asserts both the in-memory `importedTrainingPlans` array AND the on-disk `importedTrainingPlans.ftenc` file are gone.

### Article 20 (data portability)

| File | Line(s) | Change |
|---|---|---|
| `FitTracker/Services/DataExportService.swift` | 34 (counts list) | + `("Imported Plans", dataStore.importedTrainingPlans.count)` |
| `FitTracker/Services/DataExportService.swift` | 62 (JSON encoder dict) | + `"importedTrainingPlans": encodeImportedTrainingPlans()` |
| `FitTracker/Services/DataExportService.swift` | (new private method) | `encodeImportedTrainingPlans() -> [[String: Any]]` mirroring `encodeDailyLogs()` shape; emits `id`, `name`, `createdAt` ISO-8601, `source`, `isActive`, `days[]` (with day name + assigned day type + exercise list) |

**Test contract (Phase 5):** `DataExportServiceTests` must include a regression that imports a plan and asserts the exported JSON contains an `importedTrainingPlans` key with the expected structure.

---

## Sync Semantics: Deferred to Phase 2

`needsSync: Bool` field exists on the `ImportedTrainingPlan` model from day one (so Phase 2 can opt records in without a schema migration), but **no sync wiring runs in Phase 1**:

- `CloudKitSyncService.swift` is **not modified**
- `SupabaseSyncService.swift` is **not modified**

Phase 2 follow-up PRD (out of scope) will design:

- CloudKit record schema (per-record vs digest)
- Supabase `imported_training_plans` table + RLS policy
- Conflict resolution: same-name-different-content; cross-device imports

This deferral is documented in the case study so it doesn't get lost.

---

## Requirements

### P0 — Phase 1 must-ship

| ID | Requirement | Ground in code |
|---|---|---|
| IT-1 | `ImportedTrainingPlan` domain model + supporting types | `FitTracker/Models/ImportedTrainingPlan.swift` (new) |
| IT-2 | `EncryptedDataStore.importedTrainingPlans` persisted via 6th `.ftenc` file using existing 2-phase commit | `EncryptionService.swift:779-1062` (5 touch points) |
| IT-3 | `TrainingProgramStore.activePlanId` + routing-layer `exercises(for:)` + `activate(planId:dataStore:)` | `TrainingProgramStore.swift:13-29` + new method |
| IT-4 | `TrainingPlanView` reads from `programStore.exercises(for:)`, not the static lookup | `TrainingPlanView.swift:34` |
| IT-5 | Day-name → DayType heuristic in `ImportOrchestrator`; user-editable `assignedDayType` in preview | `ImportOrchestrator.swift` (extend) + `ImportPreviewView.swift` (add day-assignment editor) |
| IT-6 | `confirmImport()` persists to `EncryptedDataStore.importedTrainingPlans` and triggers `persistToDisk()` | `ImportOrchestrator.swift:51-54` (replace stub) |
| IT-7 | "Imported Plans" list view at Settings → Data → Imported Plans (entry point + active badge + activate/deactivate/delete actions) | `FitTracker/Views/Settings/v2/Screens/ImportedPlansListScreen.swift` (new) + wire into `DataSyncSettingsScreen.swift` |
| IT-8 | Imported Plan Detail view (reuse `ImportPreviewView` in view-mode with rename/activate/deactivate/delete) | `ImportPreviewView.swift` (extend with `mode: .preview / .detail`) |
| IT-9 | Training tab toolbar `square.and.arrow.down` button → presents `ImportSourcePickerView` as a sheet | `TrainingPlanView.swift` toolbar (~ line 361) + new `@State` for sheet |
| IT-10 | Settings → Data → Imported Plans entry presents `ImportSourcePickerView` as a sheet from the empty-state CTA + a "+" button in the navigation bar | `ImportedPlansListScreen.swift` |
| IT-11 | GDPR Article 17 free via `deletePersistedData()` extension | `EncryptionService.swift:814-827` |
| IT-12 | GDPR Article 20 via `DataExportService.swift` extension (3 touch points) | `DataExportService.swift:34, 62, new method` |
| IT-13 | All 8 analytics events instrumented (6 existing constants + 2 new + 1 new `import_plan_activated`) | `AnalyticsProvider.swift` extension + call sites |
| IT-14 | Remove HISTORICAL headers from `ImportSourcePickerView` + `ImportPreviewView` once wired | `Views/Import/*.swift` |

### P1 — out of Phase 1 (carry to backlog)

The original v1 PRD's P1 items (markdown parser, AI conversation paste, prompt preservation, progressive mapping, PDF text extraction, ImportParser protocol decomposition, parser unit tests) are all **shipped** in the existing infra (parsers + tests are 23 unit tests already passing). Carry forward as-is — no work.

### P2 — out of scope (Phase 2 PRD)

Photo OCR, iOS Share Extension, AI prompt re-run, phase/mesocycle, RPE — all deferred. Tracked in §"Scope: Phase 1 vs Phase 2".

---

## UI Surfaces (input to Phase 3 UX spec re-validation)

### Two entry points (per user direction 2026-05-06)

1. **Settings → Data & Sync → Imported Plans** — list-view tile in `DataSyncSettingsScreen` that navigates into the new `ImportedPlansListScreen`. The list screen has an empty state + "Import a plan" CTA + a "+" toolbar button. Both trigger `ImportSourcePickerView` as a sheet.
2. **Training tab toolbar** — `square.and.arrow.down` icon button next to the existing focus-mode eye. Tapping presents `ImportSourcePickerView` as a sheet directly.

### One new list surface

- **Imported Plans List** at `Settings → Data → Imported Plans` (`ImportedPlansListScreen.swift`):
  - Empty state: "No imported plans yet" + "Import a plan" CTA
  - Active plan shown with badge ("ACTIVE")
  - Each row: name, source icon, day count, exercise count, "Active" badge if applicable
  - Row tap → Imported Plan Detail
  - Swipe / context-menu actions: Rename, Activate / Deactivate, Delete

### One new detail surface

- **Imported Plan Detail** — `ImportPreviewView.swift` extended with a `mode` enum:
  - `.preview` — current behavior (Confirm/Cancel CTAs at top)
  - `.detail` — viewing an existing imported plan (Rename / Activate / Deactivate / Delete actions; no Confirm CTA)

These surfaces are **input** to Phase 3 UX spec re-validation. Phase 3 owns full state coverage (loading/empty/error/success), accessibility, motion.

---

## Analytics Spec (rewritten — gate per skill instructions)

`requires_analytics: true`. All events use the `import_` prefix per project naming convention. Consent-gated via `ConsentManager`.

### Existing constants (already in `AnalyticsProvider.swift:254-264`)

| Event | Trigger | Key Parameters |
|---|---|---|
| `import_started` | User opens any import entry point | `entry_point` (training_tab / settings_data) |
| `import_source_selected` | User picks an import source | `source` (csv / json / markdown_paste / pdf / photo / share) |
| `import_parsed` | Parser completes successfully | `source`, `exercise_count`, `day_count`, `parse_duration_ms` |
| `import_mapping_confirmed` | User taps Confirm on the preview screen | `auto_matched_count`, `manual_confirmed_count`, `skipped_count`, `unresolved_count` |
| `import_completed` | Plan persisted to `EncryptedDataStore.importedTrainingPlans` and `persistToDisk()` returns success | `source`, `total_exercises`, `skipped_exercises`, `time_to_complete_ms` |
| `import_failed` | Import aborted (user cancelled or unrecoverable error) | `source`, `step` (parse / mapping / save), `reason` |

### New constants (add to `AnalyticsProvider.swift` in Phase 4)

| Event | Trigger | Key Parameters | Naming validation |
|---|---|---|---|
| `import_parse_failed` | Parser throws or returns empty result | `source`, `error_reason` | snake_case ✅, ≤40 chars ✅, no PII ✅, no duplicate ✅ |
| `import_plan_opened` | User opens an imported plan from the Imported Plans list within 7d of import | `days_since_import`, `source` | snake_case ✅, ≤40 chars ✅, no PII ✅, no duplicate ✅ |
| `import_plan_activated` | User flips an imported plan to `isActive = true` | `source`, `days_since_import`, `was_first_activation` (bool) | snake_case ✅, ≤40 chars ✅, no PII ✅, no duplicate ✅ |

### New screens (add to `AnalyticsScreen` enum in Phase 4)

| Screen | SwiftUI view | Category |
|---|---|---|
| `imported_plans_list` | `ImportedPlansListScreen` | settings |
| `imported_plan_detail` | `ImportPreviewView` (in `.detail` mode) | settings |

### Naming validation checklist

- [x] All event names snake_case, lowercase only
- [x] All event names ≤ 40 characters
- [x] No reserved prefixes (`ga_`, `firebase_`, `google_`)
- [x] No duplicate names against existing `AnalyticsEvent` constants
- [x] No PII in any parameter
- [x] All parameter values ≤ 100 characters (counts, durations, enums only)
- [x] No event has more than 25 parameters (max in this PRD: 4)
- [x] Total custom user properties unchanged (no new user props)
- [x] Total user-property count ≤ 25 (unchanged)
- [x] GA4 recommended events not applicable (no `login`/`sign_up`/`share` etc. mapping)

### Conversion + funnel

- **Primary conversion signal:** `import_plan_activated` (not `import_completed`). Activation is the action that puts the imported plan into the user's training routine.
- **Funnel:** `import_started` → `import_source_selected` → `import_parsed` → `import_mapping_confirmed` → `import_completed` → `import_plan_activated`
- **Plan activation rate** = `import_plan_activated / import_completed`
- **Plan adoption rate** = `import_plan_opened (within 7d) / import_completed`

---

## Privacy & Data

- Imported files are parsed in-memory; file contents are not sent to any server
- Original import payload (`sourceText`) is stored on-device only, encrypted at rest via `EncryptedDataStore`. Storage is opt-in at import time (checkbox in source-picker; default off for Phase 1; can be flipped to default on in Phase 2 once AI regenerate ships).
- All `import_*` analytics events are consent-gated via `ConsentManager`
- No exercise or plan data is included in analytics payloads — only counts, durations, and source enum
- No CloudKit / Supabase upload in Phase 1 — imported plans are device-local only

---

## Test & Eval Requirements

### Unit tests (extend existing 23 import tests)

| Test | Surface |
|---|---|
| `EncryptedDataStorePersistenceTests.test_importedTrainingPlans_persistAndLoad_roundTrip` | NEW — verifies 6-collection persistence round-trip via 2-phase commit |
| `EncryptedDataStorePersistenceTests.test_importedTrainingPlans_clearInMemory_wipes` | NEW |
| `EncryptedDataStorePersistenceTests.test_deletePersistedData_removesImportedTrainingPlansFile` | NEW — GDPR Article 17 regression |
| `TrainingProgramStoreTests.test_exercisesFor_returnsBundled_whenActivePlanIdNil` | NEW |
| `TrainingProgramStoreTests.test_exercisesFor_returnsImported_whenActivePlanIdSet` | NEW |
| `TrainingProgramStoreTests.test_activate_setsExactlyOnePlanActive` | NEW |
| `ImportOrchestratorTests.test_confirmImport_persistsToEncryptedDataStore` | NEW (replaces existing stub test) |
| `ImportOrchestratorTests.test_dayNameHeuristic_assignsCorrectDayType` | NEW — covers all 7 heuristic cases + round-robin fallback |
| `DataExportServiceTests.test_export_includesImportedTrainingPlansSection` | NEW — GDPR Article 20 regression |

### Analytics tests (`FitTrackerTests/AnalyticsTests.swift`)

| Test | Verifies |
|---|---|
| `test_importStarted_fires_withEntryPointParam` | NEW |
| `test_importSourceSelected_fires_withSourceParam` | NEW |
| `test_importParsed_fires_withParseDurationMs` | NEW |
| `test_importParseFailed_fires_onParserThrow` | NEW (new event) |
| `test_importMappingConfirmed_fires_withFourCounts` | NEW |
| `test_importCompleted_fires_onlyAfterPersistSucceeds` | NEW |
| `test_importFailed_fires_onUserCancel` | NEW |
| `test_importPlanOpened_fires_onListTap_within7d` | NEW (new event) |
| `test_importPlanActivated_fires_onActivate_withFirstActivationFlag` | NEW (new event) |
| `test_consentGated_importEvents_doNotFire_whenConsentDenied` | NEW — at least 1 representative event under consent gate |

### UI smoke tests

UI tests are intentionally thin per the [parallel-clone simulator hang policy](../../docs/case-studies/meta-analysis/ci-env-flake-research-2026-05-05.md). One smoke test:

| Test                                                       | Verifies                                                |
| ---------------------------------------------------------- | ------------------------------------------------------- |
| `ImportSmokeUITests.testEntryPointFromSettings_opensSheet` | Settings → Data → Imported Plans → "+" → sheet appears  |

### Coverage gate

- Unit tests + analytics tests must pass on `xcodebuild test`
- `analytics_verification_passed` set in state.json after Phase 5
- Each new event has at least 1 unit test

### AI behaviors

This feature does **not** touch `AIOrchestrator` / `ReadinessEngine` / `NutritionRecommender`. `min_eval_coverage_met` auto-passes per the eval coverage gate.

---

## Risk Register

(Sourced from research note §10. Repeated here so PR review references the PRD.)

| Risk | Likelihood | Mitigation |
|---|---|---|
| Adding a 6th `.ftenc` file breaks two-phase commit semantics | Low | Pattern is loop-driven; isomorphic to existing 5. New unit test covers 6-collection round-trip. |
| `TrainingProgramStore.exercises(for:)` becomes a hot path with new conditional | Low | `activePlanId == nil` short-circuit; bundled path identical to today. Imported path is `O(days)` lookup. Negligible. |
| Unmapped `ImportedExerciseEntry` shows synthesized "user-defined" entry without instruction text or muscle metadata | Medium | Phase 1 surfaces bare entries; warning at confirm. Per-day editor → Phase 2. |
| Imported plan day count ≠ 6 (bundled `DayType` enum size) | Medium | Day-name → DayType mapping allows collisions (two days both → `.upperPush`). User reviews assignment in preview. |
| GDPR delete leaves orphaned `importedTrainingPlans.ftenc` if developer forgets to extend `deletePersistedData()` | High if forgotten | `DataExportServiceTests.test_deletePersistedData_removesImportedTrainingPlansFile` regression. Pre-merge checklist forces both touch points. |
| Silent-pass on phase resume (this very feature's history) | High if not careful | This rewritten PRD references each touch-point file:line. Phase 6 review must spot-check the implementation matches the §Persistence + Active-Plan Switching table. |
| User imports CSV with thousands of rows; persistence pass slows scenePhase becomes background | Low | `EncryptedDataStore.persistToDisk()` is async, fire-and-forget. The new collection adds ~1 encrypt + 1 file write per persist. Negligible vs existing 5 collections. |

---

## Open Questions

| # | Question | Owner | Resolution |
|---|---|---|---|
| OQ-1 | (Closed) Should imported plans replace the active plan or be added alongside it? | PM | Closed: persisted alongside; active flag (`isActive`) is per-plan; exactly one plan can be active at a time (enforced in `TrainingProgramStore.activate`). |
| OQ-2 | (Closed) What is the max import file size to accept before showing a warning? | Eng | Closed: 1 MB cap on raw input string in `ImportOrchestrator.importFromText`; warning above. |
| OQ-3 | (Closed) Should the alias dictionary be seeded from a remote source or bundled? | Eng | Closed: bundled; remote update path → Phase 2. |
| OQ-4 | (Carried forward) Should `sourceText` storage default off or on? | Privacy | Default OFF in Phase 1 (privacy-first; user can opt in). Phase 2 may flip to ON when AI regenerate ships. |
| OQ-5 | (Carried forward) Per-day editor for unmapped exercises — when does this ship? | PM | Deferred to Phase 2 polish; Phase 1 surfaces unmapped via warning + raw name. |
| OQ-6 | (NEW) Day-name heuristic edge case: imported plan has 4 days; how do we map 4 days to 6 `DayType` enum values? | UX | Phase 3 spec decision: user reviews + edits assignment in preview; collisions (multiple imported days → same `DayType`) are allowed. The unused `DayType` slots fall back to bundled exercises (`.upperPush` becomes the imported plan's "Day 1" exercises if assigned; if not, becomes the bundled push day). |

---

## Lessons (for honest disclosure in case study)

1. **Audit-driven PRD rewrites are sometimes necessary.** v1 of this PRD claimed `ImportOrchestrator` writes to `TrainingProgramData` — structurally impossible because `TrainingProgramData` is a static struct. Audit UI-015 caught the partial ship; the resume attempt 2026-05-06 caught the structural gap. The honest path was to roll back to research and rewrite. Cost: ~1 day extra. Benefit: Phase 1 is now actually shippable.
2. **PRDs that name persistence targets must reference the actual write path.** The fix going forward: persistence claims in any future PRD must link to file:line in the codebase, not just type names. Phase 6 review check.
3. **Active-plan switching is its own architecture decision.** The original PRD treated "save the imported plan" and "use the imported plan in Training tab" as a single requirement. They are two: persistence + read fan-out. v2 separates them.
