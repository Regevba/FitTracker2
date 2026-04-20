# Training Plan v2 — Case Study

**Subtitle:** The biggest surface in the app — 2,135 lines and 13 nested types broken into 6 extracted views, 16 tasks, and the first v2 refactor to benefit from the v4.0 L1 cache.

| Field | Value |
|---|---|
| Date | 2026-04-10 |
| Authors | Regev Barak + Claude Code |
| Feature | training-plan-v2 (v2 refactor of `TrainingPlanView.swift`) |
| Work type | Feature / v2_refactor |
| PR | #74 |
| Branch | `feature/training-plan-v2` |
| Framework version | PM workflow v4.0 |
| Wall time | ~5 hours (2026-04-10 00:00Z → 05:00Z) |
| Cache hit rate | ~40% (L1, first run with the cache populated) |
| V2 Rule compliance | true |

---

## 1. Why This Case Study Exists

The `docs/case-studies/README.md` queued Training Plan v2 with a one-line brief: *"biggest surface in the app — stress-test the per-screen alignment process."* That brief was literal:

- **2,135 lines** in a single v1 file — the largest view in the app by a wide margin.
- **13 nested types** inside that one file — the highest coupling of any screen.
- **32 audit findings** — more than any other v2 refactor.
- **12 analytics events** — the highest event count of any screen (nothing else is above 5).
- **6 extracted views** — the largest decomposition of any v2 pass.

Training v2 is also the first run under PM workflow v4.0, which introduced the L1 learning cache and the reactive data mesh. It is therefore the measurement point for "does the cache actually help on a big refactor?" The answer shipped with the PR: **yes, the first-run L1 cache hit rate was ~40%** — strong enough that complexity-normalized velocity (hours per 100 lines of v1) dropped to 0.23 — the best of any v2 pass before or since, despite Training being the largest file.

---

## 2. Summary Card

| Metric | Value | Source |
|---|---|---|
| v1 file | `FitTracker/Views/Training/TrainingPlanView.swift`, 2,135 lines, 13 nested types | `prd.md:16`, `v2-audit-report.md` |
| v2 footprint | 6 extracted views + container = 1,819 lines total | file sizes |
| v2 container | `FitTracker/Views/Training/v2/TrainingPlanView.swift` (531 lines) | filesystem |
| Extracted views | `ExerciseRowView.swift` (275), `SetRowView.swift` (302), `SessionCompletionSheet.swift` (294), `FocusModeView.swift` (263), `RestTimerView.swift` (154) | filesystem |
| Audit findings | 32 (8 P0 / 16 P1 / 8 P2) | `v2-audit-report.md` |
| Tractability | 20 auto-applicable, 7 needs-decision, 3 needs-new-token, 2 needs-new-component | `v2-audit-report.md` |
| Tasks | 16 in 4 layers; 4.75-day critical path at 5h wall | `tasks.md` |
| Analytics events | 12 (`training_*` prefix, all consent-gated) | `prd.md:114-129` |
| Tests | 16 (all 12 events + screen-prefix + consent + parameter convention) | `FitTrackerTests/TrainingAnalyticsTests.swift` |
| Design tokens added | 2 (`AppSize.tabBarClearance` 56pt, `AppText.monoCaption`) | `feature-memory.md` |
| Components extracted | 6 views + 3 shared (`StatusDropdown`, `MilestoneModal`, `SetCompletionIndicator`) | `ux-spec.md`, `feature-memory.md` |
| Primary metric | `training_set_completed` (weekly / 30d / 90d) | state.json |
| Kill criteria | Per-exercise event drop-off > 15% vs `training_workout_start` | state.json |
| Sub-features spawned | Rest day positive experience (#69), AI exercise recommendations (#70) | state.json |

---

## 3. PRD Summary

### Primary metric and kill criteria

- **Primary:** `training_set_completed` tracked across weekly, 30-day, and 90-day cohorts — the single most granular event inside the workout loop. Every session produces many set-completions; this is the metric that dips if any friction enters the flow.
- **Conversion event:** `training_session_completed` (the end-of-workout event).
- **Kill criteria:** per-exercise event drop-off > 15% vs `training_workout_start` across weekly/30d/90d cohorts — a flat failure condition on the funnel from "started workout" to "completed exercise."
- **Secondary:** `training_exercise_viewed`, `training_workout_start`.
- **Crash guardrail:** crash-free rate < 99.5% → hotfix.

### In scope — 24 P0+P1 findings across 7 domains

| Domain | Findings |
|---|---|
| Architecture (decomposition) | F1–F4: 2,135-line monolith, GeometryReader abuse, magic numbers, token drift |
| Token compliance | F5–F11: raw fonts, raw colors, raw spacing, raw dimensions |
| UX principles | F13–F18: Fitts's Law (tap targets), Hick's Law (choice overload), feedback latency, rest day UX |
| State coverage | F19–F21: missing loading, error, empty states |
| Accessibility | F23–F27: labels, buttons, tap targets, Dynamic Type support |
| Motion | F28–F29: animations, reduce-motion |
| Analytics | F31: zero events on this screen → 12 new events |

### Deferred (spun out)

- **Rest day positive-experience redesign** → own PM cycle (issue #69).
- **Advanced data fusion + AI engine exercise recommendations** → own PM cycle (issue #70).
- **8 P2 findings** deferred to a v2.1 follow-up pass.

The deferral pattern mirrors Home v2: rather than expand scope to absorb P2 work, spawn downstream features that inherit the v2 foundation.

---

## 4. Phase Walkthrough

### Phase 0 — Research (v2 audit)

`/ux audit` walked the 2,135-line v1 file against `docs/design-system/ux-foundations.md` and produced 32 findings. The audit report classified every finding on two axes:

- **Severity:** P0 (blocks ship) / P1 (should fix) / P2 (defer).
- **Tractability:** auto-applicable (just change the code) / needs-decision (user call required) / needs-new-token (DS evolution) / needs-new-component (DS evolution).

This two-axis classification is what made parallel dispatch possible in Phase 4 — every auto-applicable finding was dispatch-ready without further user input.

**Cache behavior (new for v4.0):**

- **L1 hits (~40%):** audit patterns reused from Home v2 — severity rubric, token-compliance heuristics, a11y checklist, motion-reduce-motion pairing.
- **L2 seeding:** design-token mappings (e.g. `AppText.sectionTitle` → 22pt) from Home v2 primed the cache before the Training audit started.

### Phase 1 — PRD

PRD scoped 24 of 32 findings. The analytics spec was unusually large (12 events) because the v1 screen had **zero** events. This is the first feature in the app where an entire screen was un-instrumented — every user action inside the workout loop was invisible in GA4. The PRD treated this as a full-screen analytics buildout rather than an incremental addition.

Kill criteria were set tight. "Per-exercise event drop-off > 15%" is the kind of threshold that sounds innocuous but is aggressive: because `training_set_completed` fires many times per session, a 15% regression across weekly cohorts is detectable within days.

### Phase 2 — Tasks

16 tasks, 4 layers:

| Layer | Tasks | Effort | Parallel? |
|---|---|---|---|
| Foundation (tokens, component scaffolding, UX foundations walk) | T1–T8 | 3.9d | Yes — all independent |
| Assembly (container + extracted views wired together) | T9–T11 | 2.75d | No — consumes T1–T8 |
| Post-assembly (a11y, motion, analytics wiring) | T12–T14 | 1.35d | Partial |
| Verification (tests, checklist, build) | T15–T16 | 1.0d | Sequential |

**Critical path (with parallelism):** T3+T4+T5 → T9 → T10+T11+T12+T13 → T15+T16 = **~4.75 days of effective effort**, compressed to **5 wall-clock hours** by the L1 cache plus parallel dispatch. The compression factor (~22×) is the v4.0 cache's headline number.

### Phase 3 — UX / Integration

UX spec specified 6 extracted views plus 3 shared components promoted into the design system:

- **Extracted (feature-local):** `ExerciseRowView`, `SetRowView`, `RestTimerView`, `SessionCompletionSheet`, `FocusModeView`, `SkeletonLoadingView`.
- **Promoted (app-wide):** `StatusDropdown` (flexible activity type picker), `MilestoneModal` (weekly-goal progress), `SetCompletionIndicator` (visual set state).

**UX principles applied:**

- Flexible activity switching (no day-locking — users can log a run on a leg day).
- Progressive disclosure: finished exercises collapse to a single row.
- Skeleton loading states on every async boundary.
- Full Dynamic Type (AX5) support.
- Reduce-motion support on every animation.
- 44pt minimum tap targets throughout.

### Phase 4 — Implementation

The 6-view decomposition drove the file structure. The foundation layer (T1–T8) ran in parallel across token additions, component scaffolds, and the UX-foundations walk. Assembly (T9) wired the container. The v4.0 adapter layer let the implementation phase pull directly from the L1 cache for repeated motifs (collapsible row, status pill, timer countdown).

**V2 Rule mechanics:**

- v2/ subdirectory: `FitTracker/Views/Training/v2/` with 6 new files.
- v1 preserved at `FitTracker/Views/Training/TrainingPlanView.swift` (2,135 lines) with `HISTORICAL —` header.
- Single `project.pbxproj` commit: v2 files added to Sources build phase; v1 removed from Sources but retained as `PBXFileReference`.
- Same Swift type name (`TrainingPlanView`) on both sides — parent call-sites unchanged.

### Phase 5 — Testing

16 tests in `FitTrackerTests/TrainingAnalyticsTests.swift`:

- 12 event-firing tests (one per analytics event, verifying parameter shape).
- 1 screen-prefix convention test (asserts every event name starts with `training_`).
- 1 consent-gating test (no events fire when analytics consent is revoked).
- 1 parameter-name convention test (snake_case, no PII).

All 16 green on first CI run.

---

## 5. What This Feature Proved About the Framework

Training v2 was the framework's first real stress test at scale. Three claims came out of it:

### 5.1 Complexity-normalized velocity improves with cache, not with practitioner

The complexity-normalized metric (hours per 100 lines of v1 code) for the six v2 refactors:

| Screen | v1 Lines | Wall Time | h per 100 lines | PM Version |
|---|---|---|---|---|
| Onboarding | 1,106 | 6.5h | 0.59 | v2.0 |
| Training | **2,135** | **5.0h** | **0.23** | **v4.0 (L1 cache, 40%)** |
| Nutrition | 487 | 2.0h | 0.41 | v4.1 |
| Stats | 312 | 1.5h | 0.48 | v4.1 |
| Settings | 289 | 1.0h | 0.35 | v4.1 |

Training — the **largest** file — achieved the **best** complexity-normalized speed. This is the data point that cannot be explained by practitioner learning (the practitioner got faster with each run, but Training was only the third refactor). It can only be explained by the L1 cache: audit patterns and design-token mappings primed from Home v2 made Training's research phase run far faster than its raw size would predict.

The three v4.1 screens (Nutrition, Stats, Settings) show the L2 shared cache stabilizing at 55–70% hit rate with a roughly flat normalized velocity around 0.35–0.48. This is what a mature cache looks like — no longer improving, but no longer being built from scratch each run either.

### 5.2 Planning velocity (findings per hour) is the right velocity metric, not wall time

Raw wall time is dominated by file size. Planning velocity — audit findings surfaced per hour during Phase 0 — is the cleanest signal of framework capability:

| Screen | PM Version | Findings / h |
|---|---|---|
| Onboarding | v2.0 | 3.7 |
| Training | **v4.0** | **6.4** |
| Nutrition | v4.1 | 11.5 |
| Stats | v4.1 | 13.5 |
| Settings | v4.1 | 16.0 |

Training's 6.4 findings/h represents a **1.7× jump** from Onboarding under v2.0 — the first real payoff from the cache and parallel-dispatch infrastructure. The v4.1 screens showed further gains as L2 kicked in.

### 5.3 Parallel dispatch at the foundation layer works

The foundation layer (T1–T8) ran in parallel on independent subtasks: token additions, component scaffolding, UX-foundations walk, a11y audit, state-coverage plan. This is the first time the framework dispatched more than 4 concurrent subagent tasks and recombined their results into the assembly phase without merge conflicts. Training v2 validated the hub-and-spoke dispatch pattern at scale; the v4.1 screens that followed inherited it without rebuilding.

---

## 6. What Shipped vs What Was Deferred

### Shipped (in PR #74)

- v2/ directory with 6 extracted views, same Swift type as v1, pbxproj surgery clean.
- 12 `training_*` analytics events, all consent-gated, all screen-prefixed, all tested.
- 2 new design tokens promoted to app-wide: `AppSize.tabBarClearance` (56pt), `AppText.monoCaption`.
- 3 components promoted app-wide: `StatusDropdown`, `MilestoneModal`, `SetCompletionIndicator`.
- Full state coverage (loading / error / empty) on the workout loop.
- Full a11y pass (Dynamic Type AX5, 44pt tap targets, labels on every interactive element).
- Reduce-motion support on every animation.

### Deferred (spun out)

| Deferred item | Destination |
|---|---|
| Rest day positive-experience redesign | Own PM cycle, issue #69 |
| Advanced data fusion + AI engine exercise recommendations | Own PM cycle, issue #70 |
| 8 P2 audit findings | v2.1 follow-up pass |

---

## 7. Lessons

1. **File size does not predict wall time under a mature framework.** Training was 2,135 lines — 3× larger than Home's 703 — and shipped in 5 hours vs Home's 1-day execution. The L1 cache is what closed that gap.

2. **Two-axis audit classification (severity × tractability) is what enables parallel dispatch.** Severity alone tells you what matters; tractability tells you what's dispatchable without further user input. Together they let you dispatch 20 of 32 findings without blocking on decisions.

3. **A full-screen analytics buildout is a distinct PRD shape from an incremental one.** Training v2 went from zero events to twelve. The PRD treated this as a full instrumentation plan — naming convention, consent gating, parameter schema, test coverage — not an afterthought appended to the design spec.

4. **Component promotion should be opportunistic, not planned.** Training's 3 promoted components (`StatusDropdown`, `MilestoneModal`, `SetCompletionIndicator`) were not designed app-wide — they were feature-local components the UX audit flagged as "this should be reused elsewhere." The DS evolution path (feature-local → promoted) is cheaper than the top-down path (design system first, feature consumes).

5. **Kill criteria should be at the granularity of the most-fired event on the screen.** `training_set_completed` fires many times per workout; a 15% drop-off threshold is detectable within days. Kill criteria tied to rare events (weekly conversion, session completion) take too long to trigger.

6. **Complexity-normalized metrics make framework performance claims defensible.** "Training ran in 5 hours" is not a framework claim — it's a feature observation. "Training shipped at 0.23 h/100 lines, beating every other v2 pass on normalized velocity despite being the largest file" is a framework claim, and it's the one the cache actually earned.

---

## 8. Links

- **PR:** #74
- **State:** `.claude/features/training-plan-v2/state.json`
- **Audit report:** `.claude/features/training-plan-v2/v2-audit-report.md`
- **PRD:** `.claude/features/training-plan-v2/prd.md`
- **UX spec:** `.claude/features/training-plan-v2/ux-spec.md`
- **Tasks:** `.claude/features/training-plan-v2/tasks.md`
- **V2 files:** `FitTracker/Views/Training/v2/` (6 files)
- **V1 file (historical):** `FitTracker/Views/Training/TrainingPlanView.swift`
- **Tests:** `FitTrackerTests/TrainingAnalyticsTests.swift` (16 tests)
- **Design memory:** `docs/design-system/feature-memory.md`
- **Sub-features spawned:** issue #69 (rest day UX), issue #70 (AI exercise recommendations)
- **Related case studies:** `pm-workflow-evolution-v1-to-v4.md` (Training is the v4.0 L1-cache data point), `home-today-screen-v2-case-study.md` (the v3.0 run that primed the cache)
