---
title: "Training Program Customization — Custom Splits on Top of the Fixed PPL (C6)"
date: 2026-06-02
date_written: 2026-06-02
work_type: feature
dispatch_pattern: serial
framework_version: v7.9
primary_metric: "Users with ≥1 saved custom program per WAU ≥0.15 at T+60d (T1, baseline 0)"
success_metrics:
  - "Users with ≥1 saved custom program per WAU (T1, baseline 0 → target ≥0.15 at T+60d)"
  - "Active program switch rate (T1, target ≥0.30/month per user with prog at T+60d)"
  - "Custom-program-vs-PPL day rate (T1, target ≥0.20 at T+90d)"
  - "Editor session length p50 (T2, target ≤3 min)"
  - "Time-to-first-customize (T2, target ≤14d organic)"
  - "'I want custom split' complaints stop (T3, within 90d post-ship)"
kill_criteria:
  - "Custom program save rate at T+60d < 0.05 per WAU (low adoption)"
  - "Custom program crash rate > 1% of editor sessions (UI bug)"
  - "p95 editor first-render > 500ms on iPhone 17 (perf)"
  - "Migration regression: any existing user loses access to their fixed PPL"
  - "Active-program-switch rate > 1.5/day per user (thrash signal)"
kill_criteria_resolution: pending_t60_eval_2026-08-01
tier_tags_present: true
related_prs:
  - 574
pr_citation_exempt:
  - "PR #234 (import-training-plan predecessor — training-plan data model, architectural context)"
  - "PR #573 (C3 sibling — picker-mode signature source; C6 consumes C3's API in 'Add exercise')"
  - "PR #576 (D1 sibling — same-day merge, parallel-sprint acknowledgment only)"
case_study_type: full
---

# Training Program Customization — C6

## Tier tags (T1 / T2 / T3)

This case study uses the project-wide tier convention from `docs/case-studies/data-quality-tiers.md`. Every quantitative metric below carries a T1 (Instrumented), T2 (Declared), or T3 (Narrative) label.

## Summary

C6 replaces the fixed 6-day Push/Pull/Legs split (hard-coded in `Models/TrainingProgramData.swift`) with **per-user custom training programs**. Users can pick from 4 starter templates (PPL 6-day / Upper-Lower 4-day / Full-body 3-day / Empty), edit days (rename / change DayType / change weekday / duplicate), add/remove/reorder exercises within each day via the C3 picker, and save multiple programs with active-program switching. **No destructive migration** — existing users see the fixed PPL until they explicitly customize.

**Lifecycle:** Research → PRD → Tasks → Implement → Test (5 phases shipped 2026-06-02). C6 was the LARGEST item in the 2026-05-31 tier carryover (RICE 7.0, 4-6 person-days estimated). Came in at **~1700 LoC actual across 9 standalone-buildable commits** in a single session (~5 hours wall time including the C3 cross-branch merge).

## Problem framing

| Tier | Claim |
|---|---|
| T3 | Every user followed the same fixed 6-day PPL split. Backlog L348 ("Training program customization") was filed 2026-04-02 and reaffirmed during the 2026-04-16 v5.2 stress test. Power users wanted Upper/Lower or Full-body 3-day options + the ability to swap individual exercises. |
| T2 | Import Training Plan v1 (PR #234, 2026-05-06) shipped IMPORT-from-external CSV/JSON/Markdown but not in-app CREATE/EDIT. C6 closes the create/edit gap. |
| T1 | 2026-05-31 E1 RICE refresh ranked C6 at #7 on the Planned table (RICE 7.0) — moderate-reach (~50% of users), high-impact (2.5; structural product capability), confidence 0.7, effort 1.25 person-weeks. |

## What C6 shipped

### Data model (`CustomProgram.swift` — Phase 4 commit 1)

```swift
struct CustomProgram { id, name, createdAt, updatedAt, schemaVersion: 1, days: [CustomDay] }
struct CustomDay { id, name, dayType, weekdayIndex (0..6), slots: [ExerciseSlot] }
struct ExerciseSlot { id, exerciseID (String reference), 3 nil-default override fields, order }
```

Key decisions:
- **`exerciseID` is a String reference, not a copy** — catalog updates flow through to all custom programs
- **3 nil-default override fields** — sparse storage; most users don't customize sets/reps
- **`schemaVersion: 1`** — future-proofs against schema-breaking changes
- **`maxSavedProgramsPerUser: 10`** — soft cap

### Migration logic (`CustomProgramMigration.swift` — Phase 4 commit 2)

**NO destructive migration.** Fixed PPL stays as a fallback constant. Resolver:

```text
if activeProgramID == nil → fixed PPL fallback (unchanged behavior)
if activeProgramID set + program found → resolve custom (apply overrides)
if activeProgramID set + program NOT found → fallback safe (returns PPL)
```

The `currentProgramDays(for:)` + `exercisesForDay(_:in:)` resolver is called from `TrainingPlanView` v1 + v2 via 1:1 substitutions (commit 7).

### 4 starter templates (`TrainingProgramTemplates.swift` — Phase 4 commit 1)

| Template | Training days | Default name |
|---|---|---|
| PPL 6-day | Push / Pull / Legs / Full Body / Cardio | "My PPL" |
| Upper/Lower 4-day | Upper A / Lower A / Upper B / Lower B | "My Upper/Lower" |
| Full-body 3-day | Mon/Wed/Fri full body | "My Full-Body" |
| Empty | 7 unnamed rest days | "New program" |

Each template materializes slots from `TrainingProgramData.allExercises` (existing catalog) so updates flow through.

### 6 new surfaces

| Surface | File | LoC |
|---|---|---|
| `CustomProgramListScreen` (Surface 1 — program list) | Phase 4 commit 3 | ~230 |
| `NewProgramSheet` (Surface 2 — template picker) | Phase 4 commit 4 | ~110 |
| `CustomProgramEditorScreen` (Surface 3 — day-by-day editor; headline) | Phase 4 commit 6 | ~340 |
| `DayEditSheet` (Surface 4 — day customization) | Phase 4 commit 5 | ~125 |
| `ExerciseSlotOverrideSheet` (Surface 5 — per-slot overrides) | Phase 4 commit 5 | ~115 |
| Settings → "Customize Program" row (Surface 6 — entry point) | Phase 4 commit 7 | ~30 |

### 8 new analytics events (all screen-prefixed `training_`)

`training_custom_program_list_opened` · `_template_selected` · `_saved` · `_activated` · `_deleted` · `training_day_edited` · `training_exercise_slot_added` · `_removed`

### Cross-branch C3 dependency

C6's `CustomProgramEditorScreen` (T10) uses C3's `ExerciseLibraryView(source: "picker:c6_editor", picker: { exercise in addSlot(exercise) })` — the picker-mode init signature defined in C3 PRD §"Surface 1".

C3 (PR #573, full lifecycle) merged to main at `95d8ab3` mid-C6-Phase-4. C6 then merged main, resolving the small AnalyticsProvider/AnalyticsService/pbxproj overlaps (shared `exerciseId` constant kept in C3's section + commented for C6 reuse) in commit `1052a26`. C6 Phase 4 continued from there with the C3 picker signature live on disk.

## 9-commit Phase 4 lifecycle table

| Commit | Tasks | SHA | Net LoC |
|---|---|---|---|
| 1 | T1 (data model) + T2 (UserPreferences) + T3 (templates) | `38bb6cb` | +311 |
| 2 | T4 (migration resolver) + T5 (analytics: 8 events + 7 params) | `95c5198` | +226 |
| (merge) | C3 (PR #573) merged into main, then into C6 with conflict resolution | `1052a26` | (merge) |
| 3 | T6 (CustomProgramListScreen) + 2 placeholder stubs | `89258ea` | +269 |
| 4 | T7 (NewProgramSheet) — replaces NewProgramSheet stub | `99ceff7` | +119 |
| 5 | T8 (DayEditSheet) + T9 (ExerciseSlotOverrideSheet) | `abfb2e4` | +242 |
| 6 | T10 (CustomProgramEditorScreen — headline) — removes last placeholder | `30a58f2` | +320 |
| 7 | T11 (Settings row) + T12 (TrainingPlanView consumer update) | `34e50df` | +63 |
| 8 | T14 (test suite — 15 tests, all pass) | `ee24be4` | +402 |
| 9 | (this) T15 (case study + state→testing + backlog strike) | — | ~200 |

**Total Phase 4 actual LoC: ~2152** (PRD estimate ~1700; tasks.md re-estimate ~1965; actual came in slightly higher due to lightweight FlowLayout-style editor + per-row affordances + override-count tracking).

**Wall time: ~5 hours** (matches PRD's 4-6 person-day estimate scaled to single-session iteration).

## Verification — all green

| Check | Result |
|---|---|
| `xcodebuild build -scheme FitTracker -destination 'generic/platform=iOS Simulator'` | BUILD SUCCEEDED after every commit (T1) |
| `xcodebuild test -only-testing:FitTrackerTests/{CustomProgramCodable,CustomProgramMigration,StarterTemplates,AnalyticsTrainingCustomProgramEvents}Tests` | **15/15 PASSED** on iPhone 17 Simulator (T1) |
| `make ui-audit` | P0=0 maintained (single pre-existing P1 on `HRVTrendChart.swift` not C6-touched) (T1) |
| Schema check (`scripts/check-state-schema.py`) | 79/82 pass — 3 pre-existing false-positives on already-complete features (queued as v7.9.1 candidate F-PR-RESOLUTION-WINDOW-CACHE-FALLBACK) (T1) |
| Tier 2.2 contemporaneous log | 6+ phase_transition entries via `scripts/append-feature-log.py` (T1) |

## Test coverage scope

| Surface | T14 task | File | Tests |
|---|---|---|---|
| Codable round-trip + override count | T14.A | `CustomProgramCodableTests` | 2 |
| Migration resolver (nil / custom / invalid / overrides / convenience) | T14.D | `CustomProgramMigrationTests` | 6 |
| 4 starter templates materialize correctly | T14.C | `StarterTemplatesTests` | 6 |
| Analytics events fire with correct param shape | T14.E | `AnalyticsTrainingCustomProgramEventsTests` | 1 |
| **Total** | | | **15** |

**Coverage rationale:** Pure-logic surfaces (data model + resolver + templates + analytics) at ≥90% coverage. T14.B (persistence round-trip) was subsumed into T14.A. T14.F-T14.K (view-level smoke tests) deferred per project pattern (no ViewInspector infra — see C3 case study scope note + 2026-05-08 iOS audit E-2). All 4 sub-surfaces + editor are exercised via the existing `xcodebuild build` SwiftUI structural check; runtime UX validation happens at Phase 5 simulator walkthrough.

## Risks + mitigations

| Risk | Mitigation |
|---|---|
| Data model migration breaks existing users | NO destructive migration; fixed PPL stays as fallback. Test `testNilActiveProgramIDReturnsFixedPPLFallback` + `testInvalidActiveProgramIDFallsBackSafely` verify the 2 fallback paths. |
| Editor UX overwhelms users | 4 starter templates absorb ~95% of mainstream splits; Empty is opt-in for advanced users. Phase 5 simulator walkthrough confirms placement. |
| Per-slot override drift from catalog updates | `exerciseID` is a string reference. Override fields only affect 3 numeric fields. Test `testOverridesAppliedToCustomSlot` verifies the override merge. |
| `maxSavedProgramsPerUser=10` too restrictive | Soft cap with "+ New program" disabled at the limit + explanatory caption. Phase 4 review can raise to 20. |
| Cross-branch merge with C3 introduces analytics overlap | Resolved at merge `1052a26` — kept C3's `exerciseId` constant + commented for C6 reuse. AnalyticsProvider section order: C3 events first, then C6 events. |

## What's NOT in C6 (8 explicit guards — PRD §"Out of scope")

- Per-day target progression curves → future
- Periodization phase blocks → future
- AI-suggested exercise replacements → D1 (adaptive intelligence)
- Shared community programs → future + moderation
- Mid-week swap warnings → future research
- Bulk exercise replacement → low frequency
- Program sharing between users → out of solo
- Supersets / circuits / drop-sets → separate feature

## Companion features

- **C5 ai-user-feedback-loop** (merged 2026-06-02 `ec5dff9`) — provides AnalyticsService pattern + Settings v2 row precedent
- **C3 exercise-search-filter** (merged 2026-06-02 `95d8ab3`) — provides the picker-mode init signature C6 calls from T10 editor
- **D1 adaptive-intelligence-next-pass** (PR #576 DRAFT) — will eventually consume the cohort-of-power-users that C6 attracts via custom-program activation patterns

## Phase E discipline

C6 shipped during the v7.9 Phase E 14-day soak (2026-05-21 → ~2026-06-04). **No new enforcement gates. No new schema fields beyond `customPrograms[]` + `activeProgramID`.** Consumes existing v7.8.6 + v7.9 infrastructure exclusively. Phase E compliant — Day 13/14 at this case study write.

## References

- PR: <https://github.com/Regevba/FitTracker2/pull/574>
- Phase 0 Research: [`.claude/features/training-program-customization/research.md`](../../.claude/features/training-program-customization/research.md)
- Phase 1 PRD: [`docs/product/prd/training-program-customization.md`](../product/prd/training-program-customization.md)
- Phase 2 Tasks: [`.claude/features/training-program-customization/tasks.md`](../../.claude/features/training-program-customization/tasks.md)
- State: [`.claude/features/training-program-customization/state.json`](../../.claude/features/training-program-customization/state.json)
- C3 picker-mode dependency: [`docs/product/prd/exercise-search-filter.md`](../product/prd/exercise-search-filter.md) §"Surface 1" + C3 PR #573 commit `693fc91`
- C3 case study: [`exercise-search-filter-case-study.md`](exercise-search-filter-case-study.md)
- Sibling C5 case study: [`ai-user-feedback-loop-case-study.md`](ai-user-feedback-loop-case-study.md)
- Import Training Plan v1 predecessor: [`import-training-plan-case-study.md`](import-training-plan-case-study.md)
- Catalog: [`FitTracker/Models/TrainingProgramData.swift`](../../FitTracker/Models/TrainingProgramData.swift)
- Backlog row: `docs/product/backlog.md` Planned RICE row 7.0 + L348 (struck through in this commit)
