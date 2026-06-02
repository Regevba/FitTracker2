# Training Program Customization — Phase 0 Research

> **Feature type:** Feature (9-phase) — LARGEST item in 2026-05-31 tier carryover (RICE 7.0, est. 4-6 person-days)
> **Backlog source:** `docs/product/backlog.md` L348 + Planned RICE row 7.0
> **Sequence position:** C6 (after C2/C4/C5 shipped 2026-06-01, after C3 draft 2026-06-01)

## 1. Problem

Today every user follows the same fixed 6-day Push/Pull/Legs split hard-coded in `Models/TrainingProgramData.swift`. `TrainingProgramData.exercises(for: DayType)` returns the same array for every user, every day, every device. There is no:

- Way to switch to a 3-day full-body program
- Way to swap "Pec Deck" for "Cable Crossover" within a day
- Way to add a new exercise to the Friday Full-Body day
- Way to save and switch between multiple programs (e.g., a 6-week cut block + a 12-week growth block)

The 2026-04-16 v5.2 stress test logged this gap (per feature-memory). The Import Training Plan v1 (PR #234, 2026-05-06) shipped IMPORT-from-external but not in-app CREATE/EDIT. C6 closes the in-app create/edit gap on top of the persistence layer Import shipped.

## 2. Scope decision tree (Phase 0 boundaries)

C6 is large enough that Phase 0 must explicitly bound scope. Each sub-decision below is locked in this research; Phase 1 PRD freezes the precise schema and copy.

### 2.1 Data model

Per-user `customPrograms: [CustomProgram]` array in `EncryptedDataStore.UserPreferences`. Active program identified by `activeProgramID: UUID?`. New types:

```swift
struct CustomProgram: Codable, Sendable, Identifiable {
    let id: UUID
    var name: String           // "My PPL" / "12-week growth"
    var createdAt: Date
    var updatedAt: Date
    var days: [CustomDay]
}

struct CustomDay: Codable, Sendable, Identifiable {
    let id: UUID
    var name: String           // "Upper Push" / "Push Day A"
    var dayType: DayType       // governs DayType-aware AI/HealthKit logic
    var weekdayIndex: Int      // 0..6 — Sun..Sat assignment in the calendar view
    var slots: [ExerciseSlot]
}

struct ExerciseSlot: Codable, Sendable, Identifiable {
    let id: UUID
    var exerciseID: String     // refers to TrainingProgramData.allExercises.id
    var targetSetsOverride: Int?      // nil → use catalog default
    var targetRepsOverride: String?
    var restSecondsOverride: Int?
    var order: Int
}
```

Reasoning:
- `exerciseID` is a string reference, not a copy of the full `ExerciseDefinition`, so catalog updates (new coaching cues, fixed typos) flow through to existing custom programs.
- Override fields default nil — most users won't change set/rep targets; only power users will.
- `weekdayIndex` lets the program show on the right day of the week in TrainingPlanView's calendar header.

### 2.2 Migration of existing users

**No destructive migration.** Existing users see the fixed PPL until they tap "Customize my program" in Settings. First customize creates a snapshot:

```swift
CustomProgram(
  name: "My Program (was Default PPL)",
  days: TrainingProgramData.fixed_PPL_days_snapshot,
  ...
)
```

The fixed PPL constant in `TrainingProgramData` stays as the fallback for users who never customize.

### 2.3 Templates gallery

4 starter templates surfaced when creating a new program:

1. **PPL 6-day** — current default (Push/Pull/Legs/FullBody/Cardio/RestDay)
2. **Upper/Lower 4-day** — Upper A / Lower A / Upper B / Lower B + 3 rest days
3. **Full-body 3-day** — Mon/Wed/Fri full body + 4 rest days
4. **Empty** — build from scratch (7 unnamed rest days; user fills in)

Each template is a constant in code (`TrainingProgramData.starterTemplates`).

### 2.4 What users can edit in v1

- Day names (rename "Upper Push" → "Push Day A")
- DayType assignment (set Wednesday from `cardioOnly` → `upperPush`)
- Weekday slot (move "Upper Push" from Monday to Tuesday)
- Add exercises to a day (from the C3 library sheet — pick exercises)
- Remove exercises from a day
- Reorder exercises within a day
- Override sets/reps/rest for individual exercise slots (sheet form)
- Save multiple programs + switch active program

### 2.5 What's explicitly out of scope for C6 v1

| Item | Reason | Track |
|---|---|---|
| Per-day target progression curves | Periodization is its own feature surface | future |
| Periodization phase blocks (deload weeks, intensity cycling) | Same | future |
| AI-suggested exercise replacements ("you dismissed Pec Deck — try Cable Crossover") | Belongs to D1 reinforcement layer | D1 |
| Shared community programs (export/import via QR/link) | Privacy + moderation considerations | future |
| Mid-week swap warnings ("you just moved leg day — your RDL load is still scheduled") | Edge-case UX needs research | future |
| Bulk exercise replacement ("swap all dumbbell rows for barbell rows in this program") | Power-user feature, low frequency | future |
| Program sharing between users | Out of solo-mode scope | future |
| Time-blocked exercises (cardio for 25 min, not 3 sets) | DayType already handles cardio days; per-slot time-target is overscope | future |
| Supersets / circuits / drop-sets | Big UX surface; separate feature | future |

## 3. Surface design

### 3.1 Entry points

- **Settings → Training & Nutrition → Customize Program** — new row, opens program list
- **TrainingPlanView header** — "Edit" affordance when an editable program is active

### 3.2 Program list screen

Sheet showing:
- Active program highlighted
- All saved programs with last-edited date
- "+" button → "New program" sheet (template picker → name entry → editor)
- Per-row: tap to activate, swipe to delete (with confirmation), edit affordance to open editor

### 3.3 Program editor screen

Push navigation from program list:
- Day-by-day expand/collapse (7 sections, one per weekday)
- Each section shows day name (editable inline) + DayType picker + exercise list
- Per exercise row: drag handle + sets×reps×rest + remove button
- "+ Add exercise" at bottom of each day's section → opens C3 library sheet
- "Save" applies changes + bumps `updatedAt`

### 3.4 Day customization sheet (sub-modal)

When user taps a day's gear icon:
- Rename day
- Change DayType (drives readiness alert + AI segment routing)
- Move to different weekday
- Duplicate day to another weekday

## 4. Dependency chain

```
Import Training Plan v1 (PR #234, shipped 2026-05-06)
  └─ established persistence + dataStore.userPreferences for plans
        └─ C6 extends with customPrograms[] alongside the imported-plans list
              ↓
TrainingProgramData (shipped, v1.0)
  └─ provides ExerciseDefinition catalog + DayType + fixed PPL fallback
        ↓
C3 Exercise Library (PR #573 in flight)
  └─ provides ExerciseLibraryView sheet
        └─ C6 "Add exercise" reuses this surface — opens it in PICKER mode
              (the sheet returns a selected exerciseID via closure)
        ↓
C6 (this feature)
  └─ writes custom programs into dataStore
  └─ TrainingPlanView reads activeProgram (custom OR fallback PPL)
  └─ Settings → Training & Nutrition gains "Customize Program" row
```

**C3 should ship before C6.** If C3 ships only as a sheet (Phase 0/1/2 today), C6 can ship at minimum after C3 reaches `implementation` complete. C3 + C6 do not need to land in the same release — C6 can call C3's existing sheet API with a picker callback.

## 5. Success metrics

Per the 2026-04-21 Gemini Tier 2.3 convention.

| Metric | Tier | Baseline | Target | Window |
|---|---|---|---|---|
| Users with ≥1 saved custom program (`training_custom_program_saved`) per WAU | T1 | 0 | ≥ 0.15 at T+60d | 60d |
| Active program switch rate (`training_active_program_changed` per user with ≥1 custom prog) | T1 | nil | ≥ 0.30 per month per user with prog | 60d |
| Custom-program-vs-PPL rate (custom-program-day-completed events / total day-completed events) | T1 | 0 | ≥ 0.20 at T+90d | 90d |
| Time-to-first-customize (from C6 ship to first user save) | T2 | nil | ≤ 14d (organic) | 60d |
| Editor session length p50 | T2 | nil | ≤ 3min (lower = better — UI is fast) | 60d |
| User-reported "I want custom split" complaints | T3 | filed several times | stop | 90d |

## 6. Kill criteria

- Custom program save rate at T+60d < 0.05 per WAU (low adoption)
- Custom program crash rate > 1% of editor sessions (UI bug)
- p95 editor render time > 500ms (perf)
- Migration regression: any existing user loses their PPL during C6 ship

## 7. Risks

| Risk | Mitigation |
|---|---|
| Data model migration breaks existing users | No destructive migration; fixed PPL stays as fallback constant; first-customize is opt-in |
| Editor UX overwhelms users | Phase 0 starter templates absorb 90% of users; "Empty" is opt-in for advanced users |
| Per-slot override fields drift from catalog updates | exerciseID is a reference, not a copy — catalog updates flow through |
| C3 not shipped → "Add exercise" picker has no surface | Block C6 Phase 4 (Implement) on C3 reaching `implementation` complete |
| Custom day's DayType mismatches the cardio/strength assumptions of AI/HealthKit code | DayType is the data model's contract; Phase 4 audits every consumer of `TrainingProgramData.exercises(for:)` |
| Performance: editor view re-renders on every drag | SwiftUI List with `.onMove()` handles this natively; benchmark in Phase 5 |

## 8. New analytics events (8)

Per 2026-04-08 project convention. Training-tab feature → `training_` prefix.

| Event | Trigger | Params |
|---|---|---|
| `training_custom_program_list_opened` | Settings → Customize Program tap | `count` (existing programs) |
| `training_custom_program_template_selected` | Picks a template in "New program" sheet | `template_id` (ppl / upper_lower / full_body / empty) |
| `training_custom_program_saved` | "Save" tap in editor | `program_id`, `day_count`, `total_exercise_count` |
| `training_custom_program_activated` | Sets a saved program as active | `program_id` |
| `training_custom_program_deleted` | Swipe-to-delete with confirmation | `program_id`, `day_count` |
| `training_day_edited` | Day rename / DayType change / weekday move saved | `day_id`, `field` (name/dayType/weekday) |
| `training_exercise_slot_added` | "Add exercise" picker returns a selection | `exercise_id`, `day_id`, `override_count` (sets/reps/rest overrides if any) |
| `training_exercise_slot_removed` | Exercise removed from a day | `exercise_id`, `day_id` |

## 9. Phase E discipline

C6 ships during or after the v7.9 Phase E 14-day soak window (2026-05-21 → ~2026-06-04). **No new enforcement gates.** No new schema fields beyond the program data model (under `EncryptedDataStore.UserPreferences`). All deps shipped at v7.9 baseline.

## 10. Estimated Phase 4 (Implement) scope

(For Phase 2 Tasks breakdown reference — high-level estimate at Phase 0.)

| Surface | New files | Modified files | LoC est |
|---|---|---|---|
| Data model + persistence | `CustomProgram.swift` + `CustomDay.swift` + `ExerciseSlot.swift` + migration helpers | `EncryptedDataStore.swift`, `UserPreferences.swift` | ~250 |
| Program list screen | `CustomProgramListScreen.swift` | `SettingsView.swift` (new row), `TrainingNutritionSettingsScreen.swift` | ~200 |
| Program editor | `CustomProgramEditorScreen.swift` + `CustomDaySection.swift` | — | ~350 |
| Day customization sheet | `CustomDayEditSheet.swift` | — | ~120 |
| Exercise picker mode for C3 | — | `ExerciseLibraryView.swift` (add picker init + closure callback) | ~30 |
| TrainingPlanView consumer update | — | `TrainingPlanView.swift` + `TrainingPlanView v2` | ~80 |
| Templates constants | `TrainingProgramData.swift` extension (`starterTemplates` static) | — | ~100 |
| AnalyticsService + Provider | — | `AnalyticsService.swift` + `AnalyticsProvider.swift` | ~80 |
| Tests | 6 new test files | — | ~500 |

**Total estimate:** ~1700 LoC actual implementation + tests. PRD estimate at 4-6 person-days holds.

## 11. Phase 0 → Phase 1 transition criteria

- Operator approves this research.md (scope decisions §2 + 8 analytics events + 8 out-of-scope guards + migration approach)
- C3 (exercise-search-filter) reaches at least Phase 1 (PRD) — its sheet API must be defined so C6 PRD can spec the picker callback

## 12. Cross-references

- Backlog row: `docs/product/backlog.md` L348 (RICE 7.0)
- Companion C3 research: `.claude/features/exercise-search-filter/research.md`
- Existing catalog: `FitTracker/Models/TrainingProgramData.swift`
- Existing persistence: `FitTracker/Services/EncryptedDataStore.swift` (UserPreferences)
- Sibling shipped feature: Import Training Plan v1 (PR #234, `docs/case-studies/import-training-plan-case-study.md`)
- Sibling sheet pattern: `FitTracker/Views/Settings/v2/Screens/ImportedPlansListScreen.swift`
- Tier carryover plan: `~/.claude/projects/-Volumes-DevSSD-FitTracker2/memory/project_session_2026_05_31_tier_carryover_plan.md`
