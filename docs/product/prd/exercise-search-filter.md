# PRD: Exercise Search/Filter (C3)

> **ID:** exercise-search-filter | **Status:** Phase 1 (PRD) — in flight
> **Priority:** MEDIUM-HIGH (RICE 8.0, rank #4 on 2026-05-31 Planned refresh)
> **Framework version:** v7.9 | **Branch:** `feature/exercise-search-filter`
> **Backlog source:** [`docs/product/backlog.md`](../backlog.md) L347 row + Planned RICE row 8.0
> **Phase 0 (Research):** [`.claude/features/exercise-search-filter/research.md`](../../.claude/features/exercise-search-filter/research.md) — 12 sections

---

## Purpose

Add a discoverable, searchable, filterable surface on top of `TrainingProgramData.allExercises` (~50 exercises today; ~87 unique post-import-training-plan v1 mapper). The catalog already carries rich metadata (category / equipment / muscle groups / coaching cue / sets / reps / rest) but **no UI surface exists** to browse it outside the day-locked `TrainingPlanView` consumer path.

C3 ships a **read-only browse + detail surface**. The "add this exercise to a session/program" affordance is gated on C6 (training-program-customization) — C3 explicitly does not own the writable surface.

## Problem Statement

A user wanting to know "what hamstring exercises does FitMe support?" has no in-app answer today. The catalog is consumed silently by `TrainingPlanView` (for the current day's session) and `SessionCompletionSheet` (for ID-to-name lookup). Power-user complaints have been filed (per backlog L347 + 2026-04-16 v5.2 stress-test feedback).

## Business Objective

Close the most-frequently-cited UX gap in the training surface. Provides discovery without requiring the user to enter a session. Sets up the foundation that C6 will write into when the customization data model lands.

---

## Success Metrics

Per 2026-04-21 Gemini Tier 2.3 convention.

| Metric | Tier | Baseline | Target | Window |
|---|---|---|---|---|
| Exercise library opens (`training_exercise_library_opened`) per WAU | T1 | 0 (feature didn't exist) | ≥ 0.30 at T+30d | 30d |
| Search-vs-browse rate (`training_exercise_search_query` count / library opens) | T1 | nil | ≥ 0.20 at T+30d | 30d |
| Filter-chip-tap session rate (sessions where ≥1 chip tapped) | T1 | nil | ≥ 40 percent of library sessions | 30d |
| Detail-tap-through (`training_exercise_detail_opened` / library opens) | T1 | nil | ≥ 0.40 at T+30d | 30d |
| Time-to-first-result (search input → filtered list render) | T2 | nil | ≤ 50ms p95 (operator observation on iPhone 17) | release |
| Power-user "no library" complaints in app feedback | T3 | filed multiple times | "no library" complaints stop within 30d post-ship | 30d |

## Kill Criteria

- Library-opened rate at T+14d < 0.05 per WAU (feature unused — clear failure)
- Detail-tap-through < 0.10 (browse-only, no engagement)
- p95 search latency > 100ms on iPhone 17 (perf regression — should never happen at 50 items)
- Crash rate on library sheet > 0.5% of opens

---

## Requirements

### User stories

- **US-1.** As a user curious about what training options exist, I can open a library from the Training tab and browse all ~50 exercises in one place.
- **US-2.** As a user looking for "chest exercises with a machine," I can tap two filter chips and see only the 3 matching results within 50ms.
- **US-3.** As a user wondering "what's the right form for Pec Deck?", I can tap an exercise row and see its coaching cue + sets/reps/rest target.
- **US-4.** As a user in Settings → Training & Nutrition, I can also open the same library via a row labeled "Browse Exercise Library."
- **US-5.** As any user, the search bar accepts partial matches (name or muscle keyword).

### FROZEN constants (changing requires re-Phase-1)

| Constant | Value | Rationale |
|---|---|---|
| `searchDebounceMs` | 0 (immediate) | At 50 items, immediate filter is faster than typing the next char; no debounce needed |
| `searchMatchMode` | `localizedCaseInsensitiveContains(query)` against `name` + `muscleGroups[].displayName` | Matches the existing `ExerciseMapper` lookup convention |
| `chipDimensions` | 3 — Muscle / Equipment / Category | Matches `ExerciseDefinition` schema; no more dimensions in v1 |
| `chipMutualExclusivity` | One-of-N within dimension, AND across dimensions | Avoids combinatorial explosion at 50-item scale |
| `sheetPresentationDetents` | `[.large]` only | Library sheet is content-heavy; medium height truncates the chip rows |
| `analyticsSearchTriggerThreshold` | 2 chars minimum | Avoids spamming GA4 with single-char-keypress noise |

### Chip dimension taxonomy

| Dimension | Values (one selectable) | Source |
|---|---|---|
| **Muscle** | All / chest / back / shoulders / arms (biceps∪triceps) / legs (quads∪hamstrings∪glutes∪calves) / core / cardiovascular | `MuscleGroup` enum + groupings |
| **Equipment** | All / machine / cable / dumbbell / barbell / bodyweight / elliptical / rowingMachine / resistanceBand | `Equipment` enum, raw |
| **Category** | All / strength (machine∪freeWeight∪calisthenics) / cardio / core | `ExerciseCategory` enum + groupings |

The "All" pill always appears first in each row + acts as a clear-this-dimension affordance.

### Three surfaces

#### Surface 1 — `ExerciseLibraryView` sheet (NEW)

A `.sheet` modal presented from 2 entry points (see Surface 3). Layout from top to bottom:

```text
┌──────────────────────────────────────┐
│  ◀ Exercise Library              ✕  │  ← navigation header
├──────────────────────────────────────┤
│  🔍 Search exercises…                │  ← AppSearchField (existing)
├──────────────────────────────────────┤
│  [All] [Chest] [Back] [Legs] →       │  ← AppFilterBar row 1: muscle
│  [All] [Machine] [DB] [BW] →         │  ← AppFilterBar row 2: equipment
│  [All] [Strength] [Cardio] →         │  ← AppFilterBar row 3: category
├──────────────────────────────────────┤
│  ▶ Chest Press Machine               │  ← ExerciseLibraryRow
│    Chest · Machine · 3×8-12          │
│  ▶ Pec Deck / Cable Fly              │
│    Chest · Cable · 3×12-15           │
│  …                                   │
└──────────────────────────────────────┘
```

Empty-result state: `"No exercises match {query} {chip selections}. Tap All in any row to clear that filter."` with secondary CTA `[Clear all filters]`.

#### Surface 2 — `ExerciseDetailView` push (NEW)

Tapping any row pushes a detail view (NavigationLink) showing:
- Full exercise name + day-type chip ("Upper Push" / "Lower Body" / etc.)
- Sets × reps × rest seconds (large + readable)
- Coaching cue (paragraph)
- Progression note (if non-empty)
- Muscle group badges + equipment badge

Detail view does NOT include "add to plan" — C6 ships that. The detail screen is informational-only in v1.

#### Surface 3 — Entry points (2 NEW)

- **Training tab toolbar** — new "Library" toolbar button at top-right of `TrainingPlanView` + v2 surface. Opens the sheet.
- **Settings → Training & Nutrition** — new `NavigationLink` row "Browse Exercise Library" → opens the same sheet (push-style — sheet adapts to navigation context).

Both call the same `ExerciseLibraryView`; analytics distinguishes via `source` param.

### Reused existing components (no new primitives needed)

| Component | Source | C3 use |
|---|---|---|
| `AppPickerChip` | `FitTracker/DesignSystem/AppComponents.swift` | Filter chip cell |
| `AppFilterBar` | Same | The 3 horizontal chip rows |
| `AppSheetShell` | Same | Sheet container with header + close affordance |
| `AppSearchField` | Existing (verify; if absent, use `TextField` + magnifying-glass icon) | Search input |
| Tokens: `AppSpacing`, `AppColor`, `AppText`, `AppMotion`, `AppIcon` | Same | Layout + styling |

**No new design-system primitives.** This is the "verify in Phase 1" question from Phase 0 §7 — resolved: existing `AppPickerChip` + `AppFilterBar` cover the chip row need.

### Search algorithm (FROZEN)

```swift
func filteredExercises(
    query: String,
    muscle: MuscleGroup?,
    equipment: Equipment?,
    category: ExerciseCategory?
) -> [ExerciseDefinition] {
    TrainingProgramData.allExercises.filter { ex in
        // Text match: name OR any muscle's display name
        let queryMatch = query.isEmpty
            || ex.name.localizedCaseInsensitiveContains(query)
            || ex.muscleGroups.contains { $0.displayName.localizedCaseInsensitiveContains(query) }

        // Chip filters: one-of-N within dimension
        let muscleMatch = muscle.map { ex.muscleGroups.contains($0) } ?? true
        let equipmentMatch = equipment.map { ex.equipment == $0 } ?? true
        let categoryMatch = category.map { matchesCategory(ex.category, $0) } ?? true

        return queryMatch && muscleMatch && equipmentMatch && categoryMatch
    }
}

private func matchesCategory(_ raw: ExerciseCategory, _ filter: ExerciseCategory) -> Bool {
    // Group .machine + .freeWeight + .calisthenics under "strength"
    switch filter {
    case .strength: return raw == .machine || raw == .freeWeight || raw == .calisthenics
    case .cardio:   return raw == .cardio
    case .core:     return raw == .core
    default:        return raw == filter  // shouldn't fire; defensive
    }
}
```

Pure in-memory at 50 items. No async. No Core Data. No FTS.

---

## Technical Approach

### New source files

- `FitTracker/Views/Training/v2/ExerciseLibraryView.swift` — Sheet container + search field + 3 filter rows + result list. ~180 LoC.
- `FitTracker/Views/Training/v2/ExerciseLibraryRow.swift` — Single result row with name + badges. ~70 LoC.
- `FitTracker/Views/Training/v2/ExerciseDetailView.swift` — Push-navigation detail. ~120 LoC.
- `FitTracker/Models/ExerciseLibraryFilter.swift` — Pure-function `filteredExercises(...)` + `matchesCategory(...)` helpers. Static methods; no state. ~50 LoC.

### Modified source files

- `FitTracker/Views/Training/v2/TrainingPlanView.swift` — Add "Library" toolbar button (~5 LoC)
- `FitTracker/Views/Settings/v2/Screens/TrainingNutritionSettingsScreen.swift` — Add "Browse Exercise Library" row (~10 LoC)
- `FitTracker/Services/Analytics/AnalyticsProvider.swift` — Add 4 event constants + 3 new param constants (`dimension`, `query_length`, `via_search` / `via_filter` — `exercise_id` exists per existing exercise_log event) (~25 LoC)
- `FitTracker/Services/Analytics/AnalyticsService.swift` — Add 4 `logTrainingExercise*` methods (~30 LoC)
- `FitTracker.xcodeproj/project.pbxproj` — Wire 4 new source files + 1 new test file group (~30 LoC)

### Branch isolation discipline

- All work on `feature/exercise-search-filter` (Mode C compliant)
- No infra-path edits — Mode B not triggered

---

## Analytics Events

4 new events screen-prefixed `training_` per 2026-04-08 project convention (Training-tab feature).

| Event | Trigger | Params |
|---|---|---|
| `training_exercise_library_opened` | Sheet presents | `source` (`"training_toolbar"` / `"settings_row"`) |
| `training_exercise_search_query` | User types ≥ 2 chars in search (fires on commit, not per-keypress) | `query_length` (int) |
| `training_exercise_filter_tapped` | User taps a chip in any of the 3 rows | `dimension` (`"muscle"` / `"equipment"` / `"category"`), `value` (chip rawValue) |
| `training_exercise_detail_opened` | User taps a row → detail view pushes | `exercise_id`, `via_search` (bool — query non-empty at tap), `via_filter` (bool — any chip non-default at tap) |

The `via_search` + `via_filter` booleans let us measure the discovery path (search-led vs filter-led vs pure-browse).

---

## Phased Rollout

Single-PR Feature ship. No phased rollout. Post-merge:

- T+7d: first metrics readout (library opens, search-vs-browse split)
- T+14d: kill-criteria evaluation
- T+30d: full review against success-metric targets

---

## Dependencies

All shipped at v7.9 baseline:

| Dependency | Source | Status |
|---|---|---|
| `ExerciseDefinition` schema (12 fields) | `Models/TrainingProgramData.swift` | ✅ shipped |
| `TrainingProgramData.allExercises` array (~50 entries) | Same | ✅ shipped |
| `MuscleGroup` / `Equipment` / `ExerciseCategory` enums | Same | ✅ shipped |
| `AppPickerChip` + `AppFilterBar` primitives | `FitTracker/DesignSystem/AppComponents.swift` | ✅ shipped |
| Settings v2 navigation patterns | PR #550+ | ✅ shipped |
| AnalyticsService event-firing infrastructure | C5 PR #572 (added 3 new constants 2026-06-02) | ✅ shipped |

**No new infrastructure required.**

---

## GDPR / Privacy

- **No new data collection.** Library reads from the static `TrainingProgramData.allExercises` constant — same data the app already consumes.
- **No PII in analytics.** Event params are exercise-IDs (canonical strings like `"chest_press_m"`), filter dimension/value enums, and integer query lengths.
- **No on-device persistence.** Filter state is in-memory only (resets on sheet dismiss); no SharedPreferences/UserDefaults touch.

---

## Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Empty-result state too jarring at strict filter combinations | Confusion | Empty-state copy explicitly tells user how to clear filters; secondary `[Clear all filters]` CTA |
| Toolbar button placement competes with existing Training tab UI | Discoverability | UX placement matches sibling "Settings" button pattern (top-right); audited via `/ux pre-merge-review` |
| Filter chip rows scroll horizontally — accessibility (VoiceOver) | A11y regression | Use `AppFilterBar` which already has VoiceOver labels per design system; verify via `make ui-audit` |
| Backlog L347 says "87 exercises" but catalog has ~50 today | Mismatch between docs and reality | C3 PRD reads from canonical `allExercises` count; 87 was the Import Training Plan v1 mapper coverage (different set) |
| C6 picker callback signature undefined at C3 ship | C6 cannot reuse C3's sheet | C3 PRD §"Surface 1" makes `ExerciseLibraryView` parameterizable: `ExerciseLibraryView(picker: ((ExerciseDefinition) -> Void)? = nil)`. When `picker` is nil → read-only (default). When non-nil → tapping a row calls `picker(exercise)` instead of pushing detail. C6 uses the picker-mode init. |

---

## Open Questions

| # | Question | Decision |
|---|---|---|
| OQ-1 | Should the sheet remember the last-used filter state across opens? | **No.** Each open starts fresh. Avoids surprising-state UX issue at low-frequency feature usage. |
| OQ-2 | Should search support multi-word AND ("incline dumbbell")? | **Yes — `localizedCaseInsensitiveContains` against the full query string.** "incline dumbbell" matches "DB Incline Press" because "incline" + "dumbbell"-via-equipment-badge join in the result-row context. Implementing AND across name+muscle is too complex for the result improvement at 50 items. |
| OQ-3 | Should the detail view link out to a video demonstration? | **No for v1.** Video assets are future scope. The coaching cue + sets/reps/rest is the v1 deliverable. |
| OQ-4 | Show count of matches as the user types ("23 of 50")? | **Yes.** Small UX win at low cost. Renders in the search-field area when query is non-empty OR any chip is non-default. |
| OQ-5 | Sort order — alphabetical or by catalog (day-grouped)? | **Catalog order.** Day-grouped (PUSH first → LEGS → PULL → FULL_BODY → CARDIO) matches the existing `TrainingPlanView` convention. Users see "today's exercises near the top of their day's tab." |
| OQ-6 | Should the library be accessible from the Home tab? | **No for v1.** Two entry points (Training + Settings) is enough. Home tab is action-first; library is discovery-second. |

---

## Phase transition criteria

| From → To | Criterion |
|---|---|
| research → prd | ✅ done (this PR) |
| prd → tasks | Operator approves PRD (frozen constants + 4 analytics events + chip taxonomy) |
| tasks → implement | Tasks broken into ~10 discrete units |
| implement → test | swiftc -parse + xcodebuild build green; new test suite (~15 tests) passes |
| test → review | `make ui-audit` P0=0; coverage ≥ 90% on new files |
| review → merge | `/ux pre-merge-review` + `/design pre-merge-review` both pass |
| merge → complete | PR merged; backlog L347 + Planned RICE row 8.0 struck; FEATURE_CLOSURE_COMPLETENESS gate passes |

---

## Cross-references

- Phase 0 research: [`.claude/features/exercise-search-filter/research.md`](../../.claude/features/exercise-search-filter/research.md)
- Catalog source: [`FitTracker/Models/TrainingProgramData.swift`](../../FitTracker/Models/TrainingProgramData.swift)
- Existing chip primitives: [`FitTracker/DesignSystem/AppComponents.swift`](../../FitTracker/DesignSystem/AppComponents.swift)
- Sibling C6 (training-program-customization) PRD: in flight; will use C3 picker-mode
- Sibling C5 (ai-user-feedback-loop) merged: PR #572 `ec5dff9` (provides AnalyticsService pattern + Settings v2 row precedent)
- Backlog: `docs/product/backlog.md` Planned RICE row 8.0 + L347
