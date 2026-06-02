# Exercise Search/Filter — Phase 0 Research

> **Feature type:** Feature (9-phase: Research → PRD → Tasks → UX/Integration → Implement → Test → Review → Merge → Docs)
> **RICE:** 8.0 (rank #4 on the 2026-05-31 refreshed Planned ranking after C2 + C4 + C5 shipped 2026-06-01)
> **Backlog source:** `docs/product/backlog.md` L347 row — "Exercise search/filter — 87 exercises in fixed order, no search"

## 1. Problem

The training program catalog (`Models/TrainingProgramData.swift`) holds ~50 curated exercises with rich metadata (category / equipment / muscle groups / coaching cue / sets / reps / rest). Today the **only consumer paths** are:

- `TrainingPlanView` (line 1886) — looks up an exercise by ID for display in the current day's session
- `SessionCompletionSheet` (line 260) — same lookup pattern

There is **no discovery surface**:
- No "browse all exercises" screen
- No search by name
- No filter by muscle group / equipment / category
- No way to inspect an exercise outside the day-locked context

A user wanting to know "what hamstring exercises does FitMe support?" has no answer in-app. Power users complain (per backlog L347 + 2026-04-16 v5.2 stress-test feedback). The data already exists; only the surface is missing.

## 2. What C3 ships

### 2.1 Surface — `ExerciseLibraryView` sheet

A modal sheet (presented from Training tab + Settings → Training & Nutrition) with:

```
┌─────────────────────────────────────────┐
│  Search exercises…                  [X] │  ← top text field
├─────────────────────────────────────────┤
│  [All] [Chest] [Back] [Legs] [Arms] →   │  ← muscle group chips
│  [All] [Machine] [DB] [Barbell] [BW] →  │  ← equipment chips
│  [All] [Strength] [Cardio] [Core] →     │  ← category chips
├─────────────────────────────────────────┤
│  ▶ Chest Press Machine                  │  ← row: name + muscle/equipment badges
│     Chest · Machine · 3×8-12            │
│  ▶ Pec Deck / Cable Fly                 │
│     Chest · Cable · 3×12-15             │
│  ...                                    │
└─────────────────────────────────────────┘
```

Selecting a row pushes `ExerciseDetailView` which shows:
- Full name + day-type assignment
- Sets × reps × rest seconds
- Coaching cue
- Progression note (if any)
- Muscle group + equipment badges

### 2.2 Search algorithm

Pure in-memory filter chain. No FTS, no Core Data, no async — a 50-element array scans in <1ms on iPhone 17.

```swift
func filteredExercises(query: String, muscle: MuscleGroup?, equipment: Equipment?, category: ExerciseCategory?) -> [ExerciseDefinition] {
    TrainingProgramData.allExercises.filter { ex in
        (query.isEmpty || ex.name.localizedCaseInsensitiveContains(query) ||
            ex.muscleGroups.contains { $0.displayName.localizedCaseInsensitiveContains(query) }) &&
        (muscle == nil || ex.muscleGroups.contains(muscle!)) &&
        (equipment == nil || ex.equipment == equipment!) &&
        (category == nil || ex.category == category!)
    }
}
```

### 2.3 Filter chip taxonomy

- **Muscle group:** chest / back / shoulders / arms (biceps + triceps) / legs (quads + hamstrings + glutes + calves) / core / cardiovascular
- **Equipment:** machine / cable / dumbbell / barbell / bodyweight / elliptical / rowingMachine / resistanceBand
- **Category:** strength (machine + freeWeight + calisthenics rolled up) / cardio / core

Chip selection is **mutually exclusive within each dimension** (one-of-N) but combined across dimensions (AND). Tap "All" or the already-selected chip to clear that dimension.

### 2.4 Entry points

- **Training tab** → new "Library" button (top-right toolbar) → opens sheet
- **Settings → Training & Nutrition** → new row "Browse Exercise Library" → opens same sheet
- Both call the same `ExerciseLibraryView` sheet with no state pre-population

## 3. Out of scope for C3

| Item | Reason | Track |
|---|---|---|
| "Add this exercise to today's session" | Requires mutable training program data model | C6 (training-program-customization) |
| "Add this exercise to a custom split" | Same — requires C6 | C6 |
| Custom user-added exercises (UGC) | Requires user-content storage + moderation considerations | post-launch |
| Image/video demonstrations | Asset pipeline + storage costs; not in catalog today | future |
| Exercise alternatives ("show me a chest exercise without a machine") | AI-powered recommendation; D1 territory | D1 |
| Favourites / saved exercises | Requires per-user persistence layer; not v1 | future |
| Sort options (alphabetical, by frequency in plan, by difficulty) | Default order from catalog suffices for ~50 items | future |
| Multi-select chips per dimension | Adds UX complexity for marginal value at 50-item scale | future |
| Recently-viewed exercises | Per-user persistence layer needed | future |

## 4. Three design decisions

**1. Sheet, not full screen.** A sheet preserves the user's context in Training or Settings — they can swipe down to dismiss and resume where they were. Full-screen browsing would push the user further down the navigation stack and require explicit back-out.

**2. In-memory filtering, no search backend.** ~50 exercises × 3 filter dimensions = O(150) checks per search. No need for FTS or Core Data or external index. If C6 expands the catalog to >500 user-defined exercises later, revisit.

**3. Read-only browsing in v1.** The "add to plan" affordance opens a Pandora's box (which plan? today's session? a custom split? a backup template?). C6 ships the customization data model that makes "add" sensible. C3 stays read-only — every exercise row is informational, like a museum catalog.

## 5. Success metrics

Per the 2026-04-21 Gemini Tier 2.3 convention, all metrics carry T1/T2/T3 tier labels.

| Metric | Tier | Baseline | Target | Window |
|---|---|---|---|---|
| Exercise library opens (`exercise_library_opened` event) per WAU | T1 | 0 (feature didn't exist) | ≥ 0.30 at T+30d | 30d |
| Search-vs-browse rate (`exercise_search_query` count / `exercise_library_opened` count) | T1 | nil | ≥ 0.20 at T+30d | 30d |
| Filter chip taps per session (sessions where ≥1 chip tapped) | T1 | nil | ≥ 40% of library sessions use chips | 30d |
| Exercise detail-tap-through rate (`exercise_detail_opened` / `exercise_library_opened`) | T1 | nil | ≥ 0.40 at T+30d | 30d |
| Time-to-first-result (search input → filtered list render) | T2 | nil | ≤ 50ms p95 (operator observation) | release |
| Power-user complaints in feedback (qualitative) | T3 | "no library" filed multiple times | "no library" complaints stop | 30d post-ship |

## 6. Kill criteria

If any fires during the 30-day window:

- Library-opened rate at T+14d < 0.05 per WAU (feature unused — clear failure)
- Detail-tap-through < 0.10 (browse-only, no engagement)
- p95 search latency > 100ms on iPhone 17 (perf regression — should never happen at 50 items)
- Crash rate on library sheet > 0.5% of opens (UI bug)

## 7. Mechanical dependencies

| Dependency | Status |
|---|---|
| `ExerciseDefinition` struct | ✅ shipped — `Models/TrainingProgramData.swift` (12 fields) |
| `TrainingProgramData.allExercises` array | ✅ shipped (~50 exercises) |
| `MuscleGroup` / `Equipment` / `ExerciseCategory` enums | ✅ shipped |
| Settings v2 navigation pattern (`SettingsDetailScaffold` / `SettingsSectionCard`) | ✅ shipped (used in C5 work) |
| `AppSpacing` / `AppColor` / `AppText` design tokens | ✅ shipped |
| `AppChip` / chip-row component | **❓ verify in Phase 1 PRD** — may need a small new primitive |
| `AnalyticsService` event-firing infrastructure | ✅ shipped |
| `AnalyticsProvider` event-name constants pattern | ✅ shipped (C5 added 3 new constants 2026-06-01) |

**No new infrastructure required.** All deps shipped at v7.9 baseline.

## 8. Phase E discipline

C3 ships during the v7.9 Phase E 14-day soak (2026-05-21 → ~2026-06-04). **No new enforcement gates.** No new schema fields. No new observability surfaces. All consumption of existing v7.8.6 + v7.9 infrastructure. Phase E compliant — same pattern as C2/C4/C5 shipped 2026-06-01.

## 9. New analytics events (4 — all screen-prefixed `home_` or `training_`)

Per 2026-04-08 project convention. Library lives on the Training tab → `training_` prefix.

| Event | Trigger | Params |
|---|---|---|
| `training_exercise_library_opened` | Sheet presents | `source` (training_toolbar / settings_row) |
| `training_exercise_search_query` | User types ≥ 2 chars in search field | `query_length` (int) |
| `training_exercise_filter_tapped` | User taps a filter chip | `dimension` (muscle/equipment/category) + `value` |
| `training_exercise_detail_opened` | User taps a row → detail view | `exercise_id`, `via_search` (bool), `via_filter` (bool) |

The "via_search" + "via_filter" booleans let us measure the discovery path (search-led vs filter-led vs browse-led).

## 10. C3 vs C2 vs C4 vs C5 vs C6

| Feature | What it adds |
|---|---|
| C2 readiness-aware-training-alert (PR #560) | When training, fires home banner with adapt/swap/continue CTAs |
| C4 trend-alerts-hrv (PR #564) | Sustained-low HRV trend banner |
| C5 ai-user-feedback-loop (PR #572 in flight) | Thumbs up/down + RecommendationMemory wire |
| **C3 exercise-search-filter (this feature)** | **Discovery surface for the static exercise catalog** |
| C6 training-program-customization (next) | Mutable custom splits + day-type assignment (depends on C3 surface for picking exercises) |

C3 is a **read-only foundation** for C6's eventual writable surface. Shipping C3 first lets users see what's available before C6 lets them rearrange it.

## 11. Phase 0 → Phase 1 transition criteria

- Operator approves this research.md (scope + 3 design decisions + 4 analytics events + out-of-scope guards)
- PRD authoring begins on operator go-ahead
- Phase 1 (PRD) freezes: chip dimension ordering, search debounce, sheet-vs-fullscreen, "All" affordance copy, analytics event param shapes, success-metric thresholds

## 12. Cross-references

- Backlog row: `docs/product/backlog.md` L347 (RICE 8.0)
- Catalog source: `FitTracker/Models/TrainingProgramData.swift`
- Sibling C2 case study: `docs/case-studies/readiness-aware-training-alert-case-study.md`
- Sibling C4 case study: `docs/case-studies/trend-alerts-hrv-case-study.md`
- Sibling C5 case study: `docs/case-studies/ai-user-feedback-loop-case-study.md`
- Tier carryover plan: `~/.claude/projects/-Volumes-DevSSD-FitTracker2/memory/project_session_2026_05_31_tier_carryover_plan.md`
- Next-in-sequence: C6 (training-program-customization)
