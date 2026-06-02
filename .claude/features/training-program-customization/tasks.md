# C6 — Training Program Customization — Phase 2 Task Breakdown

> **Status:** Phase 2 (Tasks) — in flight
> **PRD source:** [`docs/product/prd/training-program-customization.md`](../../docs/product/prd/training-program-customization.md)
> **Branch:** `feature/training-program-customization`

14 discrete tasks, ordered by dependency. LoC estimates per PRD §"Technical Approach".

---

## Dependency on C3

C6 Phase 4 calls into `ExerciseLibraryView(source: ..., picker: { ... })` from C3 PR #573. The picker-mode signature is live on disk in C3's branch (commit `693fc91`). **C6 Phase 4 implement starts after C3 #573 merges to main** so the signature is reachable from main.

**Fallback if C3 hasn't merged when C6 Phase 4 is ready:** stub the picker call with a `print()` placeholder + ship without working "+ Add exercise" affordance, then wire when C3 merges. PRD recommends waiting for C3 merge for clean UX. Operator decision at Phase 4 start.

---

## Task graph (dependency)

```
T1 (Data model — CustomProgram + CustomDay + ExerciseSlot)
   ↓
T2 (UserPreferences extension + Codable persistence)
   ↓
T3 (TrainingProgramData.fixedPPLDays + starterTemplates)
   ↓
T4 (CustomProgramMigration resolver — currentProgramDays)
   ↓
   ├──→ T5 (AnalyticsProvider constants + Service methods — 8 events)
   ↓
T6 (CustomProgramListScreen — Surface 1)
   ↓
T7 (NewProgramSheet — Surface 2)
   ↓
T8 (DayEditSheet — Surface 4)
   ↓
T9 (ExerciseSlotOverrideSheet — Surface 5)
   ↓
T10 (CustomProgramEditorScreen — Surface 3, composes T8/T9 + C3 picker)
   ↓
T11 (Settings → Training & Nutrition row + SettingsView routing — Surface 6)
   ↓
T12 (TrainingPlanView + v2 consumer update — read currentProgramDays())
   ↓
T13 (project.pbxproj wiring for 7 new source files + 5 test files)
   ↓
T14 (Test suite — 5 new test files, ~25 tests)
   ↓
T15 (Final verify-local + case study + state.json → testing)
```

T1-T5 can run in parallel (pure infrastructure). T6/T7/T8/T9 each depend on T5 (analytics + data model). T10 depends on T8 + T9 (sub-sheets) + C3 picker (cross-branch). T11 depends on T6 (list screen). T12 depends on T4 (resolver). T13 wires all new files. T14 lands after T1-T13 green. T15 wraps.

---

## T1 — Data model (CustomProgram + CustomDay + ExerciseSlot)

**File:** `FitTracker/Models/CustomProgram.swift` (NEW)

```swift
struct CustomProgram: Codable, Sendable, Identifiable {
    let id: UUID
    var name: String
    let createdAt: Date
    var updatedAt: Date
    let schemaVersion: Int  // = 1
    var days: [CustomDay]
}

struct CustomDay: Codable, Sendable, Identifiable {
    let id: UUID
    var name: String
    var dayType: DayType
    var weekdayIndex: Int   // 0..6
    var slots: [ExerciseSlot]
}

struct ExerciseSlot: Codable, Sendable, Identifiable {
    let id: UUID
    var exerciseID: String  // ref to TrainingProgramData.allExercises.id
    var targetSetsOverride: Int?
    var targetRepsOverride: String?
    var restSecondsOverride: Int?
    var order: Int
}

enum TemplateID: String, Codable, Sendable {
    case ppl6Day = "ppl_6day"
    case upperLower4Day = "upper_lower_4day"
    case fullBody3Day = "full_body_3day"
    case empty = "empty"
}
```

**LoC:** ~80
**Tests:** T14.A — Codable round-trip + forwards-compat (~30 LoC).

---

## T2 — `UserPreferences` extension + persistence

**File:** `FitTracker/Services/EncryptedDataStore.swift` (modify)

Add to `UserPreferences` codable:
```swift
var customPrograms: [CustomProgram] = []
var activeProgramID: UUID? = nil
```

Plus Codable migration handling for users with older `UserPreferences` JSON (decoder default-fills missing fields).

**LoC:** ~25
**Tests:** T14.B — round-trip with both fields + backward-compat (~30 LoC).

---

## T3 — `TrainingProgramData.fixedPPLDays` + `starterTemplates`

**File:** `FitTracker/Models/TrainingProgramData.swift` (modify)

Add 2 static helpers + 4 template constants:

```swift
extension TrainingProgramData {
    /// Snapshot of the fixed PPL split as a [CustomDay] array — used by C6
    /// migration's first-customize flow.
    static func fixedPPLDays() -> [CustomDay] { /* materializes the existing 6-day PPL */ }

    /// 4 starter templates exposed in NewProgramSheet.
    static let starterTemplates: [TemplateID: () -> CustomProgram] = [
        .ppl6Day:           { pplTemplate() },
        .upperLower4Day:    { upperLowerTemplate() },
        .fullBody3Day:      { fullBodyTemplate() },
        .empty:             { emptyTemplate() }
    ]

    private static func pplTemplate() -> CustomProgram { ... }
    private static func upperLowerTemplate() -> CustomProgram { ... }
    private static func fullBodyTemplate() -> CustomProgram { ... }
    private static func emptyTemplate() -> CustomProgram { ... }
}
```

Each template materializes a `CustomProgram` with appropriate days + slots populated from existing catalog entries.

**LoC:** ~140 (the 4 templates account for most)
**Tests:** T14.C — each template materializes without crash + day counts correct (~40 LoC).

---

## T4 — `CustomProgramMigration` resolver

**File:** `FitTracker/Models/CustomProgramMigration.swift` (NEW)

```swift
enum CustomProgramMigration {
    /// Returns the days the user is currently on — custom program if active,
    /// fixed PPL fallback otherwise. Called by TrainingPlanView every refresh.
    static func currentProgramDays(
        for preferences: UserPreferences,
        catalog: [ExerciseDefinition] = TrainingProgramData.allExercises
    ) -> [ResolvedDay] {
        if let activeID = preferences.activeProgramID,
           let program = preferences.customPrograms.first(where: { $0.id == activeID }) {
            return resolveCustomProgram(program, catalog: catalog)
        }
        return TrainingProgramData.fixedPPLDays().map { /* convert to ResolvedDay */ }
    }

    /// Resolves slots → ExerciseDefinitions with overrides applied.
    private static func resolveCustomProgram(...) -> [ResolvedDay] { ... }
}

struct ResolvedDay: Identifiable {
    let id: UUID
    let name: String
    let dayType: DayType
    let weekdayIndex: Int
    let exercises: [ExerciseDefinition]  // with overrides applied
}
```

**LoC:** ~100
**Tests:** T14.D — nil activeProgramID → fixed PPL, set activeProgramID → custom, invalid ID → fallback safe (~70 LoC).

---

## T5 — `AnalyticsProvider` constants + `AnalyticsService` methods

**Files:**
- `FitTracker/Services/Analytics/AnalyticsProvider.swift` (modify)
- `FitTracker/Services/Analytics/AnalyticsService.swift` (modify)

Add 8 new event constants + 5 new param constants (`count`, `template_id`, `day_count`, `total_exercise_count`, `override_count`, `field` — `program_id` + `day_id` + `exercise_id` reuse pattern from existing).

Add 8 `logTrainingCustomProgram*` + `logTrainingDay*` + `logTrainingExerciseSlot*` methods.

**LoC:** ~100 (30 in Provider + 70 in Service)
**Tests:** T14.E — 1 test confirming all 8 events fire with correct param shape via MockAnalyticsAdapter (~50 LoC).

---

## T6 — `CustomProgramListScreen` — Surface 1

**File:** `FitTracker/Views/Settings/v2/Screens/CustomProgramListScreen.swift` (NEW)

Sheet with:
- Active program row (highlighted with star badge + "Active" label)
- All other programs with last-modified date
- Tap → activate (fires `_activated`)
- Swipe-to-delete with confirmation dialog (fires `_deleted` on confirm; if deleting active, clear `activeProgramID`)
- "+ New program" → push `NewProgramSheet`
- gear icon on active row → push `CustomProgramEditorScreen`

Reads from `userPreferences.customPrograms` (@EnvironmentObject dataStore).

**LoC:** ~200
**Tests:** T14.F — list renders + activate + delete (~50 LoC; light view-level via fixture preferences).

---

## T7 — `NewProgramSheet` — Surface 2

**File:** `FitTracker/Views/Settings/v2/Screens/NewProgramSheet.swift` (NEW)

Modal sub-sheet:
- 4 template tiles (`TemplateID.allCases`) with name + summary
- TextField for program name (defaults from template)
- Save → creates `CustomProgram` from template + appends to `customPrograms` + sets `activeProgramID` + dismisses + pushes editor for the new program
- Fires `_template_selected` on tile tap + `_saved` on Save

**LoC:** ~130
**Tests:** T14.G — template-tile tap fires analytics; Save creates + activates (~40 LoC).

---

## T8 — `DayEditSheet` — Surface 4

**File:** `FitTracker/Views/Settings/v2/Screens/DayEditSheet.swift` (NEW)

Sub-modal opened from a day's gear icon in the editor:
- Rename day (TextField bound to day.name)
- DayType picker (Picker with all `DayType.allCases`)
- Weekday picker (Sun..Sat; warns if target weekday non-empty)
- "Duplicate to weekday" Picker — creates a new day at target slot
- Save fires `_day_edited` per field changed (multiple events if multiple fields changed in one session)

Operates on a `Binding<CustomDay>` from parent editor.

**LoC:** ~120
**Tests:** T14.H — rename + DayType + weekday move + each fires analytics with correct `field` value (~50 LoC).

---

## T9 — `ExerciseSlotOverrideSheet` — Surface 5

**File:** `FitTracker/Views/Settings/v2/Screens/ExerciseSlotOverrideSheet.swift` (NEW)

Modal opened from tapping an exercise row in the editor:
- 3 TextField/Stepper inputs for sets / reps / rest (defaults from catalog if nil overrides)
- "Reset to catalog defaults" button → all 3 to nil
- Save persists overrides into `Binding<ExerciseSlot>`
- Fires `_exercise_slot_added` with `override_count` (0..3) on Save when called from initial add OR re-edit

**LoC:** ~120
**Tests:** T14.I — set override + clear + reset → fires correct `override_count` (~40 LoC).

---

## T10 — `CustomProgramEditorScreen` — Surface 3 (the headline)

**File:** `FitTracker/Views/Settings/v2/Screens/CustomProgramEditorScreen.swift` (NEW)

Push navigation from list screen. Day-by-day expand/collapse:
- Each day section: chevron expand/collapse + day name (inline-editable) + gear icon (opens `DayEditSheet`)
- Exercise rows draggable for reorder (`.onMove`)
- Per-row swipe-to-remove → fires `_exercise_slot_removed`
- Tap exercise row → opens `ExerciseSlotOverrideSheet`
- "+ Add exercise" at bottom of each day → opens `ExerciseLibraryView(source: "picker:c6_editor", picker: { exercise in addSlot(exercise, to: day) })`
- Bottom Save → bumps `updatedAt` + persists + fires `_saved`

**Operates on a draft `CustomProgram` (local @State copy)** so cancel discards changes.

**Empty-day Save warning (PRD OQ-3):** non-blocking toast "Day X has no exercises. Save anyway?" with [Save / Cancel].

**LoC:** ~300
**Tests:** T14.J — add slot via picker callback / remove slot / reorder / save bumps updatedAt + persists (~80 LoC).

---

## T11 — Settings → Training & Nutrition row + SettingsView routing

**Files:**
- `FitTracker/Views/Settings/v2/Screens/TrainingNutritionSettingsScreen.swift` (modify)
- `FitTracker/Views/Settings/v2/SettingsView.swift` (modify for navigationDestination routing)

Add a `Button { showCustomProgramList = true }` row in `TrainingNutritionSettingsScreen` with title `"Customize Program"` and subtitle showing the active program name (or `"Fixed PPL"`). Sheet presents `CustomProgramListScreen`.

If `SettingsView` uses a `navigationDestination(for:)` approach, register the routing case for the 4 new sub-screens.

**LoC:** ~40 (entry row 15 + routing 25)
**Tests:** T14.K — row renders + active-program name shown (~30 LoC).

---

## T12 — `TrainingPlanView` + v2 consumer update

**Files:**
- `FitTracker/Views/Training/TrainingPlanView.swift` (modify — v1)
- `FitTracker/Views/Training/v2/TrainingPlanView.swift` (modify — v2)

Replace calls to `TrainingProgramData.exercises(for: DayType)` with `CustomProgramMigration.currentProgramDays(for: dataStore.userPreferences)` resolver. The resolver returns `[ResolvedDay]` carrying ExerciseDefinitions with overrides applied — the view code doesn't need to know whether it's reading custom or fixed PPL.

**LoC:** ~80 across both surfaces
**Tests:** T14.L — switching `activeProgramID` reflects in TrainingPlanView on next refresh (~50 LoC; integration test).

---

## T13 — `project.pbxproj` wiring

**File:** `FitTracker.xcodeproj/project.pbxproj` (modify)

Register 7 new source files (T1, T4, T6-T10) + 5 new test files (T14.A-T14.E and consolidated test groupings).

**LoC:** ~70

---

## T14 — Test suite

**Files (NEW — 5 test files):**

- `FitTrackerTests/CustomProgramCodableTests.swift` (T14.A) — Codable round-trip + forwards-compat (~30)
- `FitTrackerTests/UserPreferencesCustomProgramsTests.swift` (T14.B) — persistence + backward-compat (~30)
- `FitTrackerTests/StarterTemplatesTests.swift` (T14.C) — all 4 templates materialize correctly (~40)
- `FitTrackerTests/CustomProgramMigrationTests.swift` (T14.D) — resolver paths (nil / custom / invalid) (~70)
- `FitTrackerTests/AnalyticsTrainingCustomProgramEventsTests.swift` (T14.E) — 8 events fire with correct param shape (~50)

**Plus 6 view-level test stubs** (T14.F-T14.K) consolidated into 1 file: `CustomProgramViewSmokeTests.swift` (~150 LoC) — verifies each view constructs without crash with fixture preferences. Full ViewInspector-based behavior tests deferred per project pattern (see C3 case study scope note).

**Total:** ~370 LoC across 6 test files; ~25 tests.

**Coverage target:** ≥ 90% on new production files (T1, T4, T6-T10).

---

## T15 — Final verify-local + case study

**Files:**
- `docs/case-studies/training-program-customization-case-study.md` (NEW)
- `.claude/features/training-program-customization/state.json` (modify — advance `current_phase: testing`)
- `.claude/logs/training-program-customization.log.json` (auto-append)

**Checks:**
- xcodebuild build → BUILD SUCCEEDED
- xcodebuild test (C6 test classes) → 25/25 PASS
- `make ui-audit` → P0=0 maintained
- `python3 scripts/check-state-schema.py` → state pass
- Backlog L348 + RICE 7.0 row struck in same commit (drift-pattern rule)

**LoC:** ~180 case study + ~10 state.json edit

---

## Out-of-scope guards (from PRD §"Out of scope")

8 explicit deferrals:
- Per-day target progression curves → future
- Periodization phase blocks → future
- AI-suggested replacements → D1
- Shared community programs → future + moderation
- Mid-week swap warnings → future research
- Bulk exercise replacement → low frequency
- Program sharing between users → out of solo
- Supersets / circuits / drop-sets → separate feature

---

## Phase 4 (Implement) ordering

Recommended landing order (8-9 standalone-buildable commits):

1. **T1 + T2 + T3** — Data model + UserPreferences + templates. Single commit. ~245 LoC.
2. **T4 + T5** — Migration resolver + analytics infra. Single commit. ~200 LoC.
3. **T6** — `CustomProgramListScreen`. Standalone. ~200 LoC.
4. **T7** — `NewProgramSheet`. Standalone. ~130 LoC.
5. **T8 + T9** — Sub-sheets (DayEdit + SlotOverride). Single commit. ~240 LoC.
6. **T10** — `CustomProgramEditorScreen` (composes 8/9 + C3 picker). Standalone. ~300 LoC.
7. **T11 + T12** — Settings row + TrainingPlanView consumer update. Single commit. ~120 LoC.
8. **T13 + T14** — pbxproj wiring + test suite. Single commit. ~440 LoC.
9. **T15** — Final verify-local + case study + state→testing + backlog strike. ~190 LoC.

**Estimated total LoC:** ~1965 (PRD estimated ~1700; tasks.md re-estimate up to ~1965 for ~25 tests + 4 templates + 6 surfaces).

**Estimated wall time:** ~5-7h (matches PRD's 4-6 person-day estimate scaled to single-session iteration).

**C3 dependency gate:** Phase 4 starts after C3 PR #573 merges to main (commits `e79c431` through `9f22def`). Until then, C6 Phase 4 sits at "tasks_phase complete; awaiting C3 merge."

---

## Phase transition criteria

| From → To | Criterion |
|---|---|
| tasks → implement | Operator approves this tasks.md AND C3 PR #573 merged to main (or operator approves picker-stub workaround) |
| implement → test | All 14 tasks complete; project.pbxproj wires all 7 new source + 5 test; xcodebuild build green |
| test → review | All ~25 tests pass; coverage ≥ 90% on new files; ui-audit P0=0 |
| review → merge | /ux + /design pre-merge-review pass |
| merge → complete | PR merged; backlog L348 + Planned RICE row 7.0 struck; FEATURE_CLOSURE_COMPLETENESS gate passes |

---

## Cross-references

- PRD: `docs/product/prd/training-program-customization.md`
- Research: `.claude/features/training-program-customization/research.md`
- State.json: `.claude/features/training-program-customization/state.json`
- C3 dependency (picker signature): `docs/product/prd/exercise-search-filter.md` §"Surface 1" + C3 PR #573 commit `693fc91`
- Import Training Plan v1 precedent: `docs/case-studies/import-training-plan-case-study.md`
- Sibling C5 commit pattern reference: PR #572 `ec5dff9` — 7 standalone-buildable commits in Phase 4
- Sibling C3 commit pattern reference: PR #573 `9f22def` — 6 standalone-buildable commits in Phase 4
- EncryptedDataStore + UserPreferences: existing
- TrainingProgramData catalog: `FitTracker/Models/TrainingProgramData.swift`
