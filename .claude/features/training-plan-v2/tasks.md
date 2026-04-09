# Training Plan v2 — Task Breakdown

> **Phase:** 2 (Tasks)
> **Source:** `.claude/features/training-plan-v2/prd.md` (24 P0+P1 findings)

---

## Dependency graph

```
T1 (new tokens) ──────────────────────┐
T2 (analytics enums — 12 events) ─────┤
T3 (RestTimerView redesign) ──────────┤
T4 (ExerciseRowView extract) ─────────┤
T5 (SetRowView extract) ──────────────┤──→ T9 (v2 TrainingPlanView main container)
T6 (SessionCompletionSheet extract) ──┤           │
T7 (FocusModeView extract) ───────────┤           ├──→ T12 (pbxproj swap)
T8 (loading/error/empty states) ──────┘           │        │
                                                  ├──→ T13 (a11y pass)
T10 (flexible activity switcher) ── depends T9    │        │
T11 (collapsed finished exercises) ── depends T9  ├──→ T14 (v1 HISTORICAL)
                                                  │
                                                  └──→ T15 (tests)
                                                       T16 (build verify)
```

---

## Tasks

### Foundation layer (parallel, no dependencies)

#### T1 — New tokens in AppTheme.swift
- **Type:** design | **Priority:** high | **Effort:** 0.15d
- **Depends on:** —
- Add `AppSize.tabBarClearance` (56pt)
- Verify all needed `AppText.*` mappings for `.caption2`, `.caption.monospaced` (may need `AppText.monoCaption`)
- **Findings:** F4, F5

#### T2 — Analytics enums + taxonomy (12 events)
- **Type:** analytics | **Priority:** high | **Effort:** 0.5d
- **Depends on:** —
- Add 12 `training_*` events to `AnalyticsEvent`
- Add params: `exerciseName`, `muscleGroup`, `setIndex`, `reps`, `weightKg`, `activityType`, `restDurationSeconds`, `sessionDurationSeconds`, `exerciseCount`, `totalSets`
- Add convenience methods to `AnalyticsService.swift`
- Update `analytics-taxonomy.csv`
- **Findings:** F31

#### T3 — RestTimerView (redesigned)
- **Type:** ui | **Priority:** critical | **Effort:** 1d
- **Depends on:** —
- New file: `FitTracker/Views/Training/v2/RestTimerView.swift`
- Replace GeometryReader floating overlay with `.safeAreaInset(edge: .bottom)` or inline timer bar
- Countdown display, skip button, haptic on complete
- Use `AppText.*`, `AppSpacing.*`, `AppColor.*` tokens
- Fire `training_rest_timer_started` / `training_rest_timer_skipped`
- **Findings:** F2, F14

#### T4 — ExerciseRowView (extract)
- **Type:** ui | **Priority:** critical | **Effort:** 0.75d
- **Depends on:** —
- New file: `FitTracker/Views/Training/v2/ExerciseRowView.swift`
- Extract from v1 (~lines 738-1114)
- Collapsible: collapsed when exercise marked finished (Q3 decision)
- Tap targets ≥44pt for exercise queue cards (F13)
- Use `Button` not `onTapGesture` (F24)
- All tokens, full a11y labels
- **Findings:** F1, F13, F24

#### T5 — SetRowView (extract)
- **Type:** ui | **Priority:** critical | **Effort:** 0.5d
- **Depends on:** —
- New file: `FitTracker/Views/Training/v2/SetRowView.swift`
- Extract from v1 (~lines 1115-1534)
- Delete button: expand tap target to ≥44pt (F26)
- Add persistent checkmark on set completion (F16)
- Copy Last button preserved (positive finding)
- Fire `training_set_logged`, `training_set_copied`, `training_weight_changed`
- **Findings:** F1, F16, F26

#### T6 — SessionCompletionSheet (extract)
- **Type:** ui | **Priority:** high | **Effort:** 0.25d
- **Depends on:** —
- New file: `FitTracker/Views/Training/v2/SessionCompletionSheet.swift`
- Extract from v1 (~244 lines)
- Fire `training_session_completed` with duration + exercise count + total sets
- All tokens
- **Findings:** F33

#### T7 — FocusModeView (extract)
- **Type:** ui | **Priority:** high | **Effort:** 0.25d
- **Depends on:** —
- New file: `FitTracker/Views/Training/v2/FocusModeView.swift`
- Extract from v1 (~134 lines)
- Fire `training_focus_mode_entered`
- **Findings:** F34

#### T8 — Loading / Error / Empty state views
- **Type:** ui | **Priority:** critical | **Effort:** 0.5d
- **Depends on:** —
- Skeleton loading state (consistent with Home v2 pattern)
- Inline error banner for save failures
- Rest day basic card (minimal — full redesign in #69)
- **Findings:** F19, F20, F21

### Assembly (depends on foundation)

#### T9 — v2 TrainingPlanView.swift (main container)
- **Type:** ui | **Priority:** critical | **Effort:** 2d
- **Depends on:** T1, T2, T3, T4, T5, T6, T7, T8
- New file: `FitTracker/Views/Training/v2/TrainingPlanView.swift`
- Build bottom-up from design system — do NOT copy v1
- Compose extracted views: ExerciseRowView, SetRowView, RestTimerView
- Present SessionCompletionSheet, FocusModeView as sheets
- `.analyticsScreen(.trainingPlan)` in view body
- All token compliance, zero raw literals
- Fire `training_session_viewed` on appear, `training_exercise_started/completed`
- ≤500 lines target
- **Findings:** All architecture + token + state

#### T10 — Flexible activity switcher
- **Type:** ui | **Priority:** critical | **Effort:** 0.5d
- **Depends on:** T9
- Activity type picker (Full Body, Upper Push, Lower Body, Cardio, Recovery)
- NOT calendar-locked — user can switch at will
- "Suggested" badge on the program-recommended type
- Fire `training_activity_switched`
- **Key decision Q1**

#### T11 — Collapsed finished exercises
- **Type:** ui | **Priority:** high | **Effort:** 0.25d
- **Depends on:** T9
- Exercises auto-collapse when all sets marked done
- Tappable to re-expand
- Smooth animation via `AppSpring.snappy`
- **Key decision Q3**

### Post-assembly

#### T12 — Update project.pbxproj (v2 swap)
- **Type:** infra | **Priority:** critical | **Effort:** 0.25d
- **Depends on:** T9
- Add PBXGroup for `v2/` under Training
- Add 7 PBXFileReferences + PBXBuildFiles
- Add to Sources build phase
- Remove v1 from Sources (keep PBXFileReference)

#### T13 — Accessibility pass
- **Type:** ui | **Priority:** critical | **Effort:** 1d
- **Depends on:** T9, T10
- Label all 50+ interactive elements
- Hints on non-trivial actions
- Values with units on all metrics
- `.isHeader` on section titles
- Week strip days as `Button` with labels
- Dynamic Type: verify at AX5, replace fixed widths
- **Findings:** F23, F24, F25, F26, F27

#### T14 — Mark v1 as HISTORICAL
- **Type:** docs | **Priority:** medium | **Effort:** 0.1d
- **Depends on:** T12

### Verification

#### T15 — Tests (analytics + behavior)
- **Type:** test | **Priority:** high | **Effort:** 0.75d
- **Depends on:** T2, T9
- Analytics tests: 12 events fire correctly, consent-gated
- Reduce-motion: animations degrade gracefully
- Build verification

#### T16 — Full build + CI verification
- **Type:** test | **Priority:** critical | **Effort:** 0.25d
- **Depends on:** T12, T13, T15
- `xcodebuild build` green
- `xcodebuild test` all suites green
- Diff review against main

---

## Summary

| Category | Tasks | Effort |
|---|---|---|
| Foundation (parallel) | T1-T8 | 3.9d |
| Assembly | T9, T10, T11 | 2.75d |
| Post-assembly | T12, T13, T14 | 1.35d |
| Verification | T15, T16 | 1d |
| **Total** | **16 tasks** | **~9 days** |

**Critical path with parallelism:** T3+T4+T5 (parallel, 1d) → T9 (2d) → T10+T11+T12+T13 (parallel, 1d) → T15+T16 (0.75d) = **~4.75 days effective**
