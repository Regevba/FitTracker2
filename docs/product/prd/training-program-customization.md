# PRD: Training Program Customization (C6)

> **ID:** training-program-customization | **Status:** Phase 1 (PRD) — in flight
> **Priority:** MEDIUM (RICE 7.0; LARGEST of the 2026-05-31 tier carryover)
> **Framework version:** v7.9 | **Branch:** `feature/training-program-customization`
> **Backlog source:** [`docs/product/backlog.md`](../backlog.md) L348 + Planned RICE row 7.0
> **Phase 0 (Research):** [`.claude/features/training-program-customization/research.md`](../../.claude/features/training-program-customization/research.md) — 12 sections, ~360 lines
> **Depends on:** C3 (`exercise-search-filter`) — picker-mode init signature defined in [`docs/product/prd/exercise-search-filter.md`](exercise-search-filter.md) §"Surface 1"

---

## Purpose

Replace the fixed 6-day Push/Pull/Legs split (hard-coded in `Models/TrainingProgramData.swift`) with **per-user custom training programs**. Users can:

- Pick a starter template from a 4-template gallery
- Edit days (rename, change DayType, change weekday)
- Add/remove/reorder exercises within each day (reusing C3's `ExerciseLibraryView` in picker mode)
- Save multiple programs + switch between them

**Existing users see the fixed PPL until they explicitly create a custom program.** No destructive migration — first-customize creates a snapshot. The fixed PPL stays as a fallback constant.

## Problem Statement

Today every user follows the same fixed 6-day PPL split. There is no way to:

- Switch to a 3-day full-body program
- Swap "Pec Deck" for "Cable Crossover" within a day
- Add new exercises to a day
- Save + switch between multiple programs (e.g., 6-week cut block + 12-week growth block)

The 2026-04-16 v5.2 stress test logged this gap. Import Training Plan v1 (PR #234, 2026-05-06) shipped IMPORT-from-external but not in-app CREATE/EDIT.

## Business Objective

Close the in-app create/edit gap on top of the persistence layer Import shipped. Targets the same power-user surface where Import landed but with full curated-library backing (no external CSV/JSON/Markdown parse needed). Largest single-feature scope in the post-v7.9 sequence; sets up the cohort-of-power-users that future Smart Reminders behavioral-learning + D1 cohort priors will calibrate against.

---

## Success Metrics

Per 2026-04-21 Gemini Tier 2.3 convention.

| Metric | Tier | Baseline | Target | Window |
|---|---|---|---|---|
| Users with ≥1 saved custom program (`training_custom_program_saved` unique-users) per WAU | T1 | 0 | ≥ 0.15 at T+60d | 60d |
| Active program switch rate (`training_active_program_changed` per user with ≥1 saved program) | T1 | nil | ≥ 0.30 per month per user with prog | 60d |
| Custom-program-vs-PPL day rate (custom-program day-completed events / total day-completed events) | T1 | 0 | ≥ 0.20 at T+90d | 90d |
| Editor session length p50 (open → save) | T2 | nil | ≤ 3min (lower = better) | 60d |
| User-reported "I want custom split" complaints | T3 | filed several times | stop within 90d post-ship | 90d |
| Time-to-first-customize (D+0 ship → first user save) | T2 | nil | ≤ 14d organic | 60d |

## Kill Criteria

- Custom-program save rate at T+60d < 0.05 per WAU (low adoption)
- Custom-program crash rate > 1% of editor sessions (UI bug)
- p95 editor first-render > 500ms on iPhone 17 (perf)
- **Migration regression**: any existing user loses access to their fixed PPL during C6 ship
- Active-program-switch rate > 1.5/day per user (thrash signal — UX confusing)

---

## Requirements

### User stories

- **US-1.** As an existing user, I open the app on C6-ship day and my training plan is unchanged (fixed PPL still shown).
- **US-2.** As a user who wants to switch to Upper/Lower, I tap Settings → Training & Nutrition → Customize Program → New → "Upper/Lower 4-day" template → name "My U/L block" → Save.
- **US-3.** As a user editing my program, I tap a day's gear icon to rename it, change its DayType, or move it to a different weekday.
- **US-4.** As a user editing a day, I tap "+ Add exercise" to open the C3 `ExerciseLibraryView` in picker mode — tapping a row returns the exercise to my day instead of pushing detail.
- **US-5.** As a user with 3 saved programs, I tap one in the list to activate it; `TrainingPlanView` reads the activated program from `activeProgramID` on next refresh.
- **US-6.** As a power user, I override per-exercise sets/reps/rest within a custom day without modifying the catalog defaults.
- **US-7.** As any user, I can delete a saved program via swipe-to-delete (confirmation dialog protects against accidental loss).

### FROZEN constants (changing requires re-Phase-1)

| Constant | Value | Rationale |
|---|---|---|
| `customProgramSchemaVersion` | `1` | First version; bump on schema-breaking change |
| `maxSavedProgramsPerUser` | 10 | Soft cap; prevents UserDefaults bloat. Phase 4 review may raise. |
| `templateGalleryCount` | 4 (PPL 6-day / Upper-Lower 4-day / Full-body 3-day / Empty) | Covers ~95% of mainstream splits; "Empty" is the from-scratch path |
| `migrationStrategy` | `opt-in snapshot, fallback to fixed PPL` | NO destructive migration; existing users untouched until they explicitly customize |
| `exerciseSlotOverrideFields` | `targetSetsOverride: Int?`, `targetRepsOverride: String?`, `restSecondsOverride: Int?` | Three override fields; nil → use catalog default. NO override on `coachingCue` / `progressionNote` (catalog stays canonical for those). |
| `dayCount` | 7 days per program (one per weekday) | Matches the calendar-week mental model |
| `pickerModeInitSignature` | `ExerciseLibraryView(picker: ((ExerciseDefinition) -> Void)? = nil)` | Defined in C3 PRD §"Surface 1"; C6 calls with non-nil picker |

### Data model (FROZEN)

`EncryptedDataStore.UserPreferences` gains two new persisted fields:

```swift
struct CustomProgram: Codable, Sendable, Identifiable {
    let id: UUID
    var name: String                          // "My PPL" / "12-week growth"
    let createdAt: Date
    var updatedAt: Date
    let schemaVersion: Int                    // = customProgramSchemaVersion
    var days: [CustomDay]                     // 7 entries, indexed Sun..Sat
}

struct CustomDay: Codable, Sendable, Identifiable {
    let id: UUID
    var name: String                          // "Upper Push" / "Push Day A"
    var dayType: DayType                      // drives DayType-aware AI/HealthKit logic
    var weekdayIndex: Int                     // 0..6 — Sun..Sat
    var slots: [ExerciseSlot]                 // ordered list
}

struct ExerciseSlot: Codable, Sendable, Identifiable {
    let id: UUID
    var exerciseID: String                    // reference to TrainingProgramData.allExercises.id
    var targetSetsOverride: Int?
    var targetRepsOverride: String?
    var restSecondsOverride: Int?
    var order: Int                            // 0-based position within day
}

extension UserPreferences {
    var customPrograms: [CustomProgram] { get set }    // default: []
    var activeProgramID: UUID? { get set }             // default: nil (use fixed PPL)
}
```

Key decisions:
- **`exerciseID` is a String reference, not a copy.** Catalog updates (new coaching cues, fixed typos) flow through to all custom programs.
- **Override fields default nil.** Most users won't change sets/reps; only power users will. Storage is sparse.
- **`weekdayIndex` lets the program show on the right day** in TrainingPlanView's calendar header.
- **`schemaVersion` field** future-proofs against schema-breaking changes.

### Migration logic (FROZEN — NO destructive migration)

```swift
func currentProgramDays() -> [(name: String, dayType: DayType, weekdayIndex: Int, slots: [ResolvedSlot])] {
    if let activeID = userPreferences.activeProgramID,
       let activeProgram = userPreferences.customPrograms.first(where: { $0.id == activeID }) {
        return resolveCustomProgram(activeProgram)
    }
    // Fallback: fixed PPL — UNCHANGED from pre-C6 behavior
    return TrainingProgramData.fixedPPLDays()
}
```

The fixed PPL constant in `TrainingProgramData` stays put, exposed via the new `fixedPPLDays()` static. The "first customize" flow creates a snapshot:

```swift
// Settings → Customize Program → "Start from current PPL" → Save
let snapshot = CustomProgram(
    name: "My Program (was Default PPL)",
    days: TrainingProgramData.fixedPPLDays().map { /* convert to CustomDay */ }
)
userPreferences.customPrograms.append(snapshot)
userPreferences.activeProgramID = snapshot.id
```

Until the user takes the "start from current PPL" action, `activeProgramID` stays nil → fixed PPL fallback → no behavior change.

### Four starter templates

Each is a `let template: CustomProgram` static constant in code (`TrainingProgramData.starterTemplates`):

1. **PPL 6-day** — current default (Push/Pull/Legs/FullBody/Cardio/RestDay). Default name: `"My PPL"`.
2. **Upper/Lower 4-day** — Upper A / Lower A / Upper B / Lower B + 3 rest days. Default name: `"My Upper/Lower"`.
3. **Full-body 3-day** — Mon/Wed/Fri full body + 4 rest days. Default name: `"My Full-Body"`.
4. **Empty** — 7 unnamed rest days; user fills in. Default name: `"New program"`.

Templates are read-only constants; users save mutable copies.

### Six surfaces

#### Surface 1 — `CustomProgramListScreen` (NEW)

Sheet presented from Settings → Training & Nutrition → "Customize Program" row. Layout:

```text
┌──────────────────────────────────────┐
│  ◀ My Programs                  ✕   │
├──────────────────────────────────────┤
│  ⭐ My PPL                            │  ← active, larger badge
│    Modified 2 days ago               │
│  My Upper/Lower                      │
│    Modified 1 week ago               │
│  My Cut Block                        │
│    Modified 3 weeks ago              │
├──────────────────────────────────────┤
│            [ + New program ]         │
└──────────────────────────────────────┘
```

- Tap row → activate (sets `activeProgramID`)
- Swipe row → delete (confirmation dialog)
- "+ New program" → opens `NewProgramSheet` (template picker)
- Tap active-row gear → opens `CustomProgramEditorScreen` for that program

#### Surface 2 — `NewProgramSheet` (NEW)

Modal sub-sheet over the list screen:

```text
┌──────────────────────────────────────┐
│  Pick a template                  ✕  │
├──────────────────────────────────────┤
│  📅 PPL 6-day                        │
│    Push / Pull / Legs / Full / …     │
│  📅 Upper/Lower 4-day                │
│    Upper A / Lower A / Upper B / …   │
│  📅 Full-body 3-day                  │
│    Mon / Wed / Fri full              │
│  📅 Empty                            │
│    Build from scratch                │
├──────────────────────────────────────┤
│  Name: [My PPL                  ]    │
│            [ Save ]                  │
└──────────────────────────────────────┘
```

Save creates a `CustomProgram` from the template + appends to `customPrograms` + sets `activeProgramID`. Pushes the editor for the just-created program.

#### Surface 3 — `CustomProgramEditorScreen` (NEW)

Push navigation from list screen. The main editor:

```text
┌──────────────────────────────────────┐
│  ◀ My PPL              [✏️ Rename]  │
├──────────────────────────────────────┤
│  ▼ Sun · Rest Day              [⚙️]  │
│    No exercises                      │
│  ▼ Mon · Upper Push            [⚙️]  │
│    Chest Press Machine 3×8-12        │
│    Pec Deck/Cable Fly 3×12-15        │
│    + Add exercise                    │
│  ▶ Tue · Lower Body            [⚙️]  │
│  ▶ Wed · Rest Day              [⚙️]  │
│  ▶ Thu · Upper Pull            [⚙️]  │
│  ▶ Fri · Full Body             [⚙️]  │
│  ▶ Sat · Cardio Only           [⚙️]  │
├──────────────────────────────────────┤
│            [ Save ]                  │
└──────────────────────────────────────┘
```

- Each day section: collapsible (chevron ▶/▼)
- Day gear icon → opens `DayEditSheet`
- Exercise rows draggable for reorder (`.onMove`)
- Per-row swipe → remove
- "+ Add exercise" → opens C3 `ExerciseLibraryView(picker: { exercise in addSlot(exercise) })`
- Tap exercise row → opens `ExerciseSlotOverrideSheet` for override fields
- Bottom "Save" applies changes + bumps `updatedAt` + dismisses

#### Surface 4 — `DayEditSheet` (NEW)

Sub-modal opened from day gear icon:

- Rename day (TextField)
- DayType picker (Picker with all `DayType` cases)
- Move to different weekday (Picker Sun..Sat — fires conflict warning if target weekday already has exercises)
- Duplicate day to another weekday (creates a copy at target slot)
- Save dismisses + applies to parent editor

#### Surface 5 — `ExerciseSlotOverrideSheet` (NEW)

Modal opened from tapping an exercise row in the editor:

```text
┌──────────────────────────────────────┐
│  Chest Press Machine             ✕   │
├──────────────────────────────────────┤
│  Sets    [ 3 ] (catalog: 3)         │
│  Reps    [ 8-12 ] (catalog: 8-12)   │
│  Rest    [ 90 ] sec (catalog: 90)   │
│                                      │
│  [Reset to catalog defaults]         │
│                  [ Save ]            │
└──────────────────────────────────────┘
```

Save persists overrides into the `ExerciseSlot`. Reset clears all 3 override fields to nil.

#### Surface 6 — Settings → Training & Nutrition row (NEW entry point)

`NavigationLink` row labeled "Customize Program" with subtitle showing the active program name (or "Fixed PPL" if none). Pushes `CustomProgramListScreen`.

### Branch isolation discipline

- All work on `feature/training-program-customization` (Mode C compliant)
- No infra-path edits — Mode B not triggered

---

## Analytics Events

8 new events screen-prefixed `training_` per 2026-04-08 project convention.

| Event | Trigger | Params |
|---|---|---|
| `training_custom_program_list_opened` | Settings → Customize Program tap | `count` (existing programs) |
| `training_custom_program_template_selected` | Picks a template in NewProgramSheet | `template_id` (`"ppl_6day"` / `"upper_lower_4day"` / `"full_body_3day"` / `"empty"`) |
| `training_custom_program_saved` | "Save" tap in editor | `program_id`, `day_count`, `total_exercise_count` |
| `training_custom_program_activated` | Sets a saved program as active | `program_id` |
| `training_custom_program_deleted` | Swipe-to-delete with confirmation | `program_id`, `day_count` |
| `training_day_edited` | Day rename / DayType change / weekday move saved | `day_id`, `field` (`"name"` / `"day_type"` / `"weekday"`) |
| `training_exercise_slot_added` | C3 picker callback fires + slot persists | `exercise_id`, `day_id`, `override_count` (0..3) |
| `training_exercise_slot_removed` | Exercise removed from a day | `exercise_id`, `day_id` |

---

## Technical Approach

### New source files (7)

- `FitTracker/Models/CustomProgram.swift` — `CustomProgram` + `CustomDay` + `ExerciseSlot` structs (~80 LoC)
- `FitTracker/Models/CustomProgramMigration.swift` — `currentProgramDays()` resolver + `fixedPPLDays()` extension on `TrainingProgramData` (~80 LoC)
- `FitTracker/Views/Settings/v2/Screens/CustomProgramListScreen.swift` — Surface 1 (~200 LoC)
- `FitTracker/Views/Settings/v2/Screens/NewProgramSheet.swift` — Surface 2 (~130 LoC)
- `FitTracker/Views/Settings/v2/Screens/CustomProgramEditorScreen.swift` — Surface 3 (~280 LoC)
- `FitTracker/Views/Settings/v2/Screens/DayEditSheet.swift` — Surface 4 (~120 LoC)
- `FitTracker/Views/Settings/v2/Screens/ExerciseSlotOverrideSheet.swift` — Surface 5 (~120 LoC)

### Modified source files (8)

- `FitTracker/Services/EncryptedDataStore.swift` — add `customPrograms` + `activeProgramID` to `UserPreferences` codable (~20 LoC)
- `FitTracker/Models/TrainingProgramData.swift` — add `fixedPPLDays()` + `starterTemplates` static constants (~120 LoC for the 4 templates)
- `FitTracker/Views/Training/TrainingPlanView.swift` + `v2/TrainingPlanView.swift` — read from `currentProgramDays()` resolver instead of `exercises(for: DayType)` directly (~80 LoC across both)
- `FitTracker/Views/Settings/v2/Screens/TrainingNutritionSettingsScreen.swift` — Surface 6 entry-point row (~10 LoC)
- `FitTracker/Views/Settings/v2/SettingsView.swift` — `navigationDestination` cases for the 5 new screens (~30 LoC)
- `FitTracker/Services/Analytics/AnalyticsService.swift` — 8 new `logTrainingCustomProgram*` + `logTrainingDay*` + `logTrainingExerciseSlot*` methods (~70 LoC)
- `FitTracker/Services/Analytics/AnalyticsProvider.swift` — 8 new event constants + 5 new param constants (`count`, `template_id`, `day_count`, `total_exercise_count`, `override_count` — `program_id` + `day_id` + `field` reuse pattern) (~30 LoC)
- `FitTracker.xcodeproj/project.pbxproj` — wire 7 new source files + 5 new test file group (~60 LoC)

### Tests (~500 LoC across 5 new files)

- `CustomProgramMigrationTests` — `currentProgramDays()` returns fixed PPL when activeProgramID nil; returns custom when set; fallback safe on invalid ID (~80 LoC)
- `CustomProgramEditorTests` — append slot / remove slot / reorder / override fields / save bumps updatedAt (~150 LoC)
- `StarterTemplatesTests` — each template materializes without crash; day counts correct (~60 LoC)
- `CustomProgramSchemaTests` — Codable round-trip / forwards-compat / schemaVersion handling (~80 LoC)
- `AnalyticsCustomProgramEventsTests` — all 8 events fire with correct param shape (~130 LoC)

---

## Phased Rollout

Single-PR Feature ship. Phase 4 lands all 7 new + 8 modified + 5 test files. Post-merge:

- T+7d: first metrics readout (template-picker rate, save count)
- T+14d: kill-criteria evaluation #1 (crash rate, perf p95)
- T+30d: T+30d adoption review
- T+60d: full success-metric review (custom-vs-PPL day rate target ≥0.20 at T+90d)
- T+90d: final adoption review

---

## Dependencies

| Dependency | Source | Status |
|---|---|---|
| **C3 picker-mode signature** — `ExerciseLibraryView(picker: ((ExerciseDefinition) -> Void)? = nil)` | C3 PR #573 PRD §"Surface 1" | ✅ DEFINED 2026-06-02 (Phase 1 PRD complete) |
| Import Training Plan v1 (persistence pattern) | PR #234 | ✅ shipped 2026-05-06 |
| `TrainingProgramData` catalog + `ExerciseDefinition` schema | Existing | ✅ shipped |
| `DayType` enum | Existing | ✅ shipped |
| Settings v2 navigation patterns | Existing | ✅ shipped |
| AnalyticsService event-firing infrastructure | C5 PR #572 | ✅ shipped 2026-06-02 |
| EncryptedDataStore UserPreferences codable | Existing | ✅ shipped |

**No new platform infrastructure required.** All deps shipped at v7.9 baseline.

**Phase 4 (Implement) sequencing constraint:** C6 Phase 4 cannot begin until C3 (`feature/exercise-search-filter`) reaches Phase 4 (Implement) at minimum — C6's editor "Add exercise" flow calls into C3's `ExerciseLibraryView` picker mode. If C3 isn't merged by C6 Phase 4 start, C6 can either:
1. Stub the picker call with a `print()` placeholder + ship without working "+ Add exercise" affordance, OR
2. Wait for C3 to merge

PRD recommends **option 2** for clean UX. Phase 2 (Tasks) breakdown can defer this decision to operator approval.

---

## GDPR / Privacy

- **All new data stays on-device.** `customPrograms` + `activeProgramID` are `UserPreferences` fields encrypted at rest via existing `EncryptedDataStore`.
- **No server-side state.** No sync to backend. User's custom programs stay on the user's device(s).
- **CloudKit sync inheritance:** existing CloudKit user-preferences sync covers the new fields automatically (same Codable contract).
- **GDPR clearAll:** existing `EncryptedDataStore.wipeUserPreferences()` clears the new fields alongside existing ones.
- **No PII in analytics.** Event params are UUIDs, enum values, counts.

---

## Risks

| Risk | Impact | Mitigation |
|---|---|---|
| **Data model migration breaks existing users** | Loss of training plan | NO destructive migration; fixed PPL stays as fallback constant; first-customize is opt-in. Test: `CustomProgramMigrationTests` covers nil-activeProgramID path explicitly. |
| **Editor UX overwhelms users** | Low adoption | 4 starter templates absorb ~95% of mainstream splits; "Empty" is opt-in for advanced users. Phase 5 (Test) includes operator simulator walkthrough. |
| **Per-slot override drift from catalog updates** | Stale data | `exerciseID` is a reference (not copy); catalog updates flow through. Override fields only affect 3 numeric fields. |
| **C3 not merged when C6 Phase 4 begins** | "+ Add exercise" affordance non-functional | Phase 4 blocks on C3 merge OR ships stubbed picker call with TODO; operator decision at Phase 2 (Tasks) approval. |
| **Custom day's DayType mismatches AI/HealthKit consumers** | Wrong AI recommendations / readiness signals | DayType is the data model contract; Phase 4 audits all consumers of `TrainingProgramData.exercises(for:)` for resolver call-site updates. List of consumers: `TrainingPlanView` × 2 + `SessionCompletionSheet` + `ReadinessEngine` (verify) + `AIOrchestrator` (verify) |
| **Performance: editor re-renders on every drag** | UI jank | SwiftUI List with `.onMove()` handles natively; benchmark in Phase 5 (Test) on iPhone 17. |
| **Picker callback closure-retain cycle** | Memory leak | Use `[weak self]` capture in editor's `picker:` closure passed into `ExerciseLibraryView`. Unit test verifies via `XCTAssertNil(weak ref)` pattern. |
| **maxSavedProgramsPerUser=10 too restrictive** | User hits cap | Soft cap; Phase 4 review may raise to 20 or remove. UI shows "10/10" indicator when at cap; further "+ New" disabled with explanatory tooltip. |

---

## Open Questions

| # | Question | Decision |
|---|---|---|
| OQ-1 | Should the "Empty" template create 7 named-rest-day days or 7 blank days? | **7 days named "Day 1" through "Day 7" + dayType `.restDay`.** Users rename + reassign dayType per their plan. |
| OQ-2 | If user activates a program then deletes it, what happens to `activeProgramID`? | **Auto-reset to nil → fixed PPL fallback.** Delete flow checks `if activeProgramID == deleted.id { activeProgramID = nil }`. |
| OQ-3 | Should the editor warn about empty days (no exercises) on Save? | **Yes — non-blocking advisory only.** Toast: "Day Mon · Upper Push has no exercises. Save anyway?" with [Save / Cancel]. User can save empty days. |
| OQ-4 | Should there be a "Reset to template defaults" affordance in the editor? | **No for v1.** User can delete + re-create from template. Adds UI complexity. Revisit if frequent ask. |
| OQ-5 | Active-program switching — should TrainingPlanView refresh immediately or wait for next day? | **Immediately.** `activeProgramID` change triggers `currentProgramDays()` resolver on next `TrainingPlanView.onAppear`. No staleness window. |
| OQ-6 | Should custom programs be exportable (share with friends)? | **No for v1.** Sharing has privacy + moderation considerations; defer to future. |
| OQ-7 | Should I show a per-program "RICE score" or "popularity badge"? | **No.** Adds gamification noise; the user's own choice is the right signal. |
| OQ-8 | Should the editor support undo? | **No for v1.** Save-or-cancel is the existing pattern; undo would add state complexity. Cancel = discard changes. |

---

## Phase transition criteria

| From → To | Criterion |
|---|---|
| research → prd | ✅ done (this PR) |
| prd → tasks | Operator approves PRD (data model + 8 analytics events + migration approach) |
| tasks → implement | Tasks broken into ~14 discrete units |
| implement → test | C3 Phase 4 reaches implement-complete (picker mode usable) OR Phase 4 ships stubbed picker call; swiftc-parse + xcodebuild build green |
| test → review | New tests pass (~25 across 5 files); coverage ≥ 90% on new files; `make ui-audit` P0=0 |
| review → merge | `/ux pre-merge-review` + `/design pre-merge-review` both pass |
| merge → complete | PR merged; backlog L348 + Planned RICE row 7.0 struck; FEATURE_CLOSURE_COMPLETENESS gate passes |

---

## Cross-references

- Phase 0 research: [`.claude/features/training-program-customization/research.md`](../../.claude/features/training-program-customization/research.md)
- C3 picker-mode dependency: [`docs/product/prd/exercise-search-filter.md`](exercise-search-filter.md) §"Surface 1" — defines `ExerciseLibraryView(picker: ((ExerciseDefinition) -> Void)? = nil)`
- Import Training Plan v1 predecessor: [`docs/case-studies/import-training-plan-case-study.md`](../case-studies/import-training-plan-case-study.md)
- Backlog: `docs/product/backlog.md` L348 + Planned RICE row 7.0
- Catalog: [`FitTracker/Models/TrainingProgramData.swift`](../../FitTracker/Models/TrainingProgramData.swift)
- Sibling C5 (ai-user-feedback-loop) merged: PR #572 `ec5dff9` (provides AnalyticsService pattern + Settings v2 row precedent + Analytics taxonomy convention)
- Sibling D1 (adaptive-intelligence-next-pass) PRD: in flight; consumes the cohort-of-power-users that C6 will attract
