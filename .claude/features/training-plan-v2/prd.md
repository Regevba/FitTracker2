# PRD: Training Plan — v2 UX Alignment

> **Owner:** Regev
> **Date:** 2026-04-10
> **Phase:** Phase 1 — PRD
> **Status:** Draft for approval
> **Parent:** v1 PRD `docs/product/prd/` (shipped pre-PM-workflow)
> **Tracking:** [regevba/fittracker2#68](https://github.com/Regevba/FitTracker2/issues/68)
> **Branch:** `feature/training-plan-v2`
> **Audit:** `.claude/features/training-plan-v2/v2-audit-report.md` (32 findings)

---

## v2 Purpose

Rewrite `TrainingPlanView.swift` (2,135 lines, 13 nested types) as a decomposed set of files under `FitTracker/Views/Training/v2/`, building bottom-up from `ux-foundations.md` principles. The v1 functional intent (exercise logging with sets/reps/weight tracking) is preserved. What changes:

1. **Architecture:** Monolith → container + 5-6 extracted views
2. **Flexibility:** Activity types (Full Body, Upper Push, etc.) are NOT locked to specific days — user can switch freely
3. **Token compliance:** 27+ raw literals → design system tokens
4. **Accessibility:** 12 labels → 50+ (full coverage), all targets ≥44pt, full AX5 Dynamic Type
5. **State coverage:** Add explicit loading (skeleton), error, and empty states
6. **Motion:** 7 raw animations → tokenized + reduce-motion support
7. **Analytics:** 0 events → 12+ per-exercise events with `training_*` prefix
8. **Rest timer:** Redesigned (not floating GeometryReader overlay)

## v2 Scope (P0 + P1 — 24 findings)

### Architecture (4 findings)

| # | Finding | Action | Priority |
|---|---------|--------|----------|
| F1 | 2,135-line monolith with 13 nested types | Decompose: main container + ExerciseRowView + SetRowView + SessionCompletionSheet + FocusModeView + RestTimerView + CameraView | P0 |
| F2 | GeometryReader for floating timer | Replace with `.safeAreaInset` or overlay design | P1 |
| F4 | Magic number 56pt (tab bar clearance) | New `AppSize.tabBarClearance` token | P1 |
| F33/F34 | SessionCompletionSheet (244 lines) + FocusModeView (134 lines) inline | Extract to own files | P1 |

### Token compliance (7 findings)

| # | Finding | Action | Priority |
|---|---------|--------|----------|
| F5 | 17+ raw `.font(.caption2)` / `.caption.monospaced()` calls | Map to `AppText.*` tokens | P1 |
| F6 | 3x raw `Color.black` | Map to `AppColor.Text.inversePrimary` | P1 |
| F7 | 5x raw `.white` | Map to `AppColor.Text.inversePrimary` | P1 |
| F8 | Raw `padding(40)` | Map to `AppSpacing.xxLarge` | P1 |
| F10 | 2x raw `padding(.leading, 14)` | Map to `AppSpacing.xSmall` or `.small` | P1 |
| F11 | 11+ raw `.frame()` dimensions | Map to `AppSize.*` tokens or `@ScaledMetric` | P1 |

### UX principles (4 findings)

| # | Finding | Action | Priority |
|---|---------|--------|----------|
| F13 | Fitts's Law: exercise queue cards too compact | Increase vertical padding to ≥44pt tap targets | P1 |
| F14 | Hick's Law: session overview too dense | Progressive disclosure — collapse detail behind taps | P1 |
| F16 | Feedback: no persistent set completion indicator | Add checkmark + haptic on set complete | P1 |
| F18 | Celebration Not Guilt: rest day lacks positive framing | Defer to own feature (#69) — keep current for v2 | P1 (deferred) |

### State coverage (3 findings)

| # | Finding | Action | Priority |
|---|---------|--------|----------|
| F19 | Missing loading state | Add skeleton placeholders during data fetch | P0 |
| F20 | Missing error state | Add inline error banner for save failures | P0 |
| F21 | Rest day empty state | Add dedicated card (basic — full redesign in #69) | P1 |

### Accessibility (4 findings)

| # | Finding | Action | Priority |
|---|---------|--------|----------|
| F23 | 12 labels for 50+ interactive elements | Label every element, add hints + values | P0 |
| F24 | Week strip days use `onTapGesture` not `Button` | Convert to `Button` with proper a11y | P0 |
| F26 | Delete button tap target ~20pt | Expand to ≥44pt via frame + `.contentShape` | P0 |
| F25 | Session type picker: no a11y labels | Add labels + selected value | P1 |
| F27 | Dynamic Type: fixed widths break at AX5 | Replace fixed widths with flexible layout | P1 |

### Motion (2 findings)

| # | Finding | Action | Priority |
|---|---------|--------|----------|
| F28 | 7 raw `.spring()` / `.easeOut()` calls | Map to `AppSpring.*` / `AppEasing.*` | P1 |
| F29 | Zero reduce-motion support | Wrap all animations in `motionSafe` | P0 |

### Analytics (1 finding)

| # | Finding | Action | Priority |
|---|---------|--------|----------|
| F31 | Zero analytics events in 2,135 lines | Add `.analyticsScreen` + 12 per-exercise events | P0 |

## v2 Non-Scope (deferred)

| Item | Deferred to | GH |
|---|---|---|
| Rest day positive experience redesign | Own PM cycle | [#69](https://github.com/Regevba/FitTracker2/issues/69) |
| Advanced data fusion + AI exercise recommendations | Own PM cycle (needs data first) | [#70](https://github.com/Regevba/FitTracker2/issues/70) |
| P2 findings (8 items) | v2.1 follow-up or individual enhancements | — |

## Key Design Decisions (from Phase 0)

1. **Flexible activity switching:** Day types NOT locked to calendar days. User can pick any activity (Full Body, Upper Push, Lower Body, Cardio, Recovery) at any time. The "suggested" day type comes from the program but is overridable.
2. **Rest timer redesign:** Replace floating GeometryReader overlay with a cleaner `.safeAreaInset(edge: .bottom)` or inline timer bar.
3. **Collapsed finished exercises:** Once an exercise is marked complete, it collapses by default. Tappable to re-expand.
4. **Skeleton loading:** Skeleton placeholders during initial data load (consistent with Home v2 pattern).
5. **Full AX5 Dynamic Type:** All text scales, no fixed widths that break at large sizes.
6. **Per-exercise analytics:** Granular events per exercise action (start, complete, set logged, weight changed, etc.). Weekly/30d/90d aggregation happens in analytics dashboards, not in-app.

---

## Analytics Spec

### Screen-prefix rule

All events use `training_` prefix per project-wide naming convention.

### New events (12)

| Event Name | GA4 Type | Trigger | Conversion? |
|---|---|---|---|
| `training_session_viewed` | Custom | Training Plan screen appears | No |
| `training_exercise_started` | Custom | User taps an exercise to begin | No |
| `training_exercise_completed` | Custom | All sets for an exercise marked done | No |
| `training_set_logged` | Custom | User logs a single set (reps + weight) | No |
| `training_set_copied` | Custom | User taps "Copy Last" on a set | No |
| `training_weight_changed` | Custom | User modifies weight on a set | No |
| `training_rest_timer_started` | Custom | Rest timer begins | No |
| `training_rest_timer_skipped` | Custom | User skips rest timer | No |
| `training_activity_switched` | Custom | User switches day type / activity | No |
| `training_session_completed` | Custom | User completes full session | Yes |
| `training_focus_mode_entered` | Custom | User enters focus mode | No |
| `training_camera_opened` | Custom | User opens form check camera | No |

### Key parameters

| Parameter | Type | Used by |
|---|---|---|
| `exercise_name` | string | exercise_started/completed, set_logged/copied, weight_changed |
| `muscle_group` | string | exercise_started/completed |
| `set_index` | int | set_logged, set_copied, weight_changed |
| `reps` | int | set_logged |
| `weight_kg` | float | set_logged, weight_changed |
| `activity_type` | string | activity_switched, session_completed |
| `rest_duration_seconds` | int | rest_timer_started, rest_timer_skipped |
| `session_duration_seconds` | int | session_completed |
| `exercise_count` | int | session_completed |
| `total_sets` | int | session_completed |

### Naming validation

- [x] All `training_*` prefixed, snake_case, <40 chars
- [x] No reserved prefixes, no duplicates with existing 37 events
- [x] No PII, ≤25 params per event
- [x] `training_session_completed` marked as conversion

---

## Success Metrics

### Primary

| Metric | Baseline | Target |
|---|---|---|
| Training sessions completed per week | Current (from `workout_complete` event) | +20% increase |

### Secondary

| Metric | Baseline | Target |
|---|---|---|
| Sets logged per session | N/A (new event) | Establish baseline, track trend |
| "Copy Last" usage rate | N/A | >30% of sets use Copy Last |
| Rest timer skip rate | N/A | <50% (users are using rest timers) |
| Activity switch rate | N/A | Establish baseline (measures flexibility adoption) |

### Guardrails

| Metric | Acceptable Range |
|---|---|
| Crash-free rate | >99.5% |
| Cold start time | <2s |
| Existing `workout_start` / `workout_complete` events | Must not regress |

---

## Acceptance Criteria

### Architecture
- [ ] v2 files at `FitTracker/Views/Training/v2/` (5-7 files)
- [ ] Main container ≤500 lines, extracted views in own files
- [ ] `project.pbxproj` updated: v2 in Sources, v1 removed
- [ ] v1 marked HISTORICAL
- [ ] Activity type freely switchable (not calendar-locked)

### Token compliance
- [ ] Zero raw font literals — all `AppText.*`
- [ ] Zero raw color literals — all `AppColor.*`
- [ ] Zero raw padding/spacing — all `AppSpacing.*`
- [ ] Zero raw frame sizes (except `@ScaledMetric`) — all `AppSize.*`
- [ ] New tokens: `AppSize.tabBarClearance` + any needed for timer

### Accessibility
- [ ] Every interactive element has `.accessibilityLabel`
- [ ] Week strip days are `Button` (not `onTapGesture`)
- [ ] All tap targets ≥44pt
- [ ] Full AX5 Dynamic Type (no fixed widths that clip)
- [ ] Reduce-motion: all animations wrapped

### State coverage
- [ ] Skeleton loading state on initial data fetch
- [ ] Error banner on save failure
- [ ] Rest day: basic card (full redesign deferred to #69)
- [ ] Completed exercises: collapsed by default

### Analytics
- [ ] `.analyticsScreen(.trainingPlan)` in v2 root
- [ ] 12 `training_*` events fire correctly
- [ ] All events consent-gated
- [ ] `analytics-taxonomy.csv` updated

---

## Kill Criteria

School project, loose thresholds:
- Crash-free < 99.5% → hotfix
- `workout_complete` event regresses → investigate
- Otherwise: iterate

## Review Cadence

1 week post-merge. School project — relax to 30-day if no signal.

---

## Estimated Effort

| Phase | Effort |
|---|---|
| PRD (this) | 0.5 day |
| Tasks | 0.25 day |
| UX Spec | 1 day |
| Implementation | 5-6 days |
| Testing | 1 day |
| Review + Merge + Docs | 0.5 day |
| **Total** | **~8-9 days** |

---

## Key Files

| File | Action |
|---|---|
| `FitTracker/Views/Training/TrainingPlanView.swift` | v1 — becomes HISTORICAL |
| `FitTracker/Views/Training/v2/TrainingPlanView.swift` | **New** — main container |
| `FitTracker/Views/Training/v2/ExerciseRowView.swift` | **New** — extracted |
| `FitTracker/Views/Training/v2/SetRowView.swift` | **New** — extracted |
| `FitTracker/Views/Training/v2/RestTimerView.swift` | **New** — redesigned timer |
| `FitTracker/Views/Training/v2/SessionCompletionSheet.swift` | **New** — extracted |
| `FitTracker/Views/Training/v2/FocusModeView.swift` | **New** — extracted |
| `FitTracker/Services/AppTheme.swift` | **Modify** — new tokens |
| `FitTracker/Services/Analytics/AnalyticsProvider.swift` | **Modify** — 12 events + params |
| `FitTracker.xcodeproj/project.pbxproj` | **Modify** — v2 group + Sources swap |

---

## Dependencies & Risks

| Risk | Impact | Mitigation |
|---|---|---|
| File decomposition may surface hidden type dependencies | Medium | Read v1 carefully; extract one type at a time |
| Rest timer redesign changes muscle memory | Low | Keep timer behavior identical, just change presentation |
| Per-exercise analytics may be too noisy | Low | Dashboard-level aggregation; events are cheap |
| `project.pbxproj` surgery on 7+ files | Medium | Single commit; revertible per V2 Rule |
| Existing `workout_start`/`workout_complete` must keep working | High | Don't modify existing event wiring — add new events alongside |
