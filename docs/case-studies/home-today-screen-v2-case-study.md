# Home Today Screen v2 — Case Study
<!-- doc-debt-backfill: fields added by scripts/backfill-case-study-fields.py -->

| Field | Value |
|---|---|
| Dispatch Pattern | serial |


**Subtitle:** The V2 Rule pilot — first deliberate UX Foundations alignment pass on the Home screen, and the project where the `home_*` screen-prefixed analytics naming convention was born.

| Field | Value |
|---|---|
| Date | 2026-04-09 |
| Authors | Regev Barak + Claude Code |
| Feature | home-today-screen (v2 refactor) |
| Work type | Feature / v2_refactor |
| PR | #61 (merged to `main` as bf3bd67) |
| Branch | `feature/home-today-screen-v2` |
| Framework version | PM workflow v3.0 |
| Wall time (execution) | ~1 day (Phase 1–4 compressed on 2026-04-09 after Phase 0 backfill) |

---

## 1. Why This Case Study Exists

Home was the **second** screen to go through a full UX Foundations alignment pass (after Onboarding v2), but it is the **first** that did so under the now-codified V2 Rule:

1. A `v2/` subdirectory created next to the v1 file.
2. Same Swift type name on both sides (`MainScreenView`) so imports and parent call-sites are untouched.
3. A single `project.pbxproj` commit that removes v1 from the Sources build phase while keeping it as a file reference for history.
4. v1 annotated as `HISTORICAL —` in a header comment.

Onboarding v2 (PR #59) shipped the spirit of the rule but predates its codification — it patched v1 in place. Home v2 is the first feature where the rule existed on paper **and** was the exit criterion for the refactor.

Home is also the feature that produced two project-wide rules as side effects:

- **Screen-prefixed analytics naming** (`home_action_tap`, `home_empty_state_shown`, etc.). Established during OQ-9 of the audit Decisions Log and now enforced by `/analytics spec` across the whole app. Documented in `CLAUDE.md` under "Analytics Naming Convention".
- **Status+Goal as a merged card** and **metric-tile deep-linking** were spun out as their own PM cycles — Home v2 validated the pattern of deferring a P1 concern into a dedicated downstream feature rather than expanding scope mid-flight.

---

## 2. Summary Card

| Metric | Value | Source |
|---|---|---|
| v1 file | `FitTracker/Views/Main/MainScreenView.swift`, 1,029 lines | state.json |
| v2 file | `FitTracker/Views/Main/v2/MainScreenView.swift`, ~703 lines | state.json |
| Audit findings | 27 (8 P0 / 14 P1 / 4 P2 / 1 positive) | `v2-audit-report.md` |
| Tasks | 17 (T1–T17) in 4 layers (Foundation / Assembly / Post-Assembly / Verification) | `tasks.md` |
| Parallel group | T1–T7 dispatched in parallel (foundation layer) | `tasks.md` |
| Analytics events | 3 shipped (`home_action_tap`, `home_action_completed`, `home_empty_state_shown`) + 1 deferred (`home_metric_tile_tap`) | `prd.md` |
| Tests | 21 (11 behavior + 10 analytics) | state.json |
| Design tokens added | 4 shipped: `AppText.metricM` (25pt), `AppText.iconXL` (32pt), `AppSize.indicatorDot` (8pt), `AppColor.Chart.{weight,hrv,heartRate,activity}` | `feature-memory.md` |
| Components promoted | 2 (`AppMetricColumn`, `AppMetricTile` → `AppComponents.swift`) | `feature-memory.md` |
| Sub-features spawned | 3 (Onboarding v2 retroactive, Status+Goal merged card, Metric Tile Deep Linking) | state.json |
| V2 Rule compliance | true | state.json |
| Build result | `BUILD SUCCEEDED` (iPhone 17 Pro, iOS 26.4) | state.json |
| Primary metric | `sessions_per_day` (baseline 0 → target 1.5) | `prd.md` |

---

## 3. PRD Summary

### Primary metric and targets

- **Primary:** `sessions_per_day` (baseline 0, target 1.5) — Home is the entry point to every other flow; sessions per day is the proxy for "users come back".
- **Secondary:**
  - `home_action_tap_rate` > 30%
  - `home_action_completion_rate` > 50%
  - `readiness_checkin_rate` > 40% of daily active users
  - `empty_state_rate` < 20%

### Kill criteria

> "Core screen — always active. v2 alignment only ships if no readiness or biometric flow regresses."

This is deliberately narrow. Home is non-optional; the kill criterion is regression-only, not a growth threshold. A screen that every user sees on every launch cannot be killed on a metrics miss — it can only be rolled back.

### In scope (22 P0+P1 findings)

- **Hierarchy fix:** Readiness promoted to hero, no-scroll constraint lifted (F1/F2/F9).
- **Side-by-side Start Workout + Log Meal CTAs** in a unified "Training & Nutrition" card (F12).
- **Full state coverage** — empty, loading, error (F15).
- **Accessibility:** ~30+ interactive elements correctly labeled (v1 had 4), Dynamic Type fixed, tap targets ≥ 44pt (F17–F19).
- **Motion:** reduce-motion support on all animations (F22).
- **Analytics:** 3 new `home_*` events (F24).
- **Token compliance:** 12 raw fonts, 7 raw paddings, 11 raw frames, raw colors all replaced with semantic tokens (F5–F8).

### Deferred (spun out as their own features)

- **F11 goal drill-down** — folded into the Status+Goal merged card feature.
- **F13 macro strip** — Nutrition v2 scope.
- **`home_metric_tile_tap` event** — ships with Metric Tile Deep Linking feature.
- **Status+Goal merged card** — own PM cycle.
- **Metric tile deep-linking** — own PM cycle.

---

## 4. Phase Walkthrough

### Phase 0 — Research (v2 audit)

The research phase was a `/ux audit` run — the second ever, after Onboarding v2. The auditor (`/ux` skill) walked `MainScreenView.swift` line-by-line against `docs/design-system/ux-foundations.md` and produced 27 findings.

**Output artifacts:**

- `.claude/features/home-today-screen/v2-audit-report.md` — 27 findings, severity-rated, with Decisions Log.
- `.claude/features/home-today-screen/research.md` — principle-level readiness assessment.

**Decisions Log (22 Open Questions):** The Decisions Log was the forcing function for the PRD. Every audit finding that required a product decision (copy direction, component choice, deferral decision) was lifted into an OQ and handed to the user for an explicit answer. This turned what would otherwise be ambiguous implementation questions into documented decisions with a paper trail.

OQ-9 is the most historically significant: it asked "how should we name the analytics events for this screen so they're obvious in GA4 without opening source?" — the answer was "prefix with the screen name." That decision ended up in `CLAUDE.md` as a project-wide rule three days later.

### Phase 1 — PRD

PRD was written against the Decisions Log. Every OQ answer became a scoped PRD line. 22 findings scoped in; 5 spun out as sub-features or deferrals.

Primary metric (`sessions_per_day`) was picked from the existing app-level metrics framework rather than inventing a new Home-specific funnel — Home is the entry point so its success metric is the global return metric.

### Phase 2 — Tasks

17 tasks were generated, structured in 4 layers:

| Layer | Tasks | Parallel? |
|---|---|---|
| Foundation (tokens, components, principles) | T1–T7 | Yes — all independent |
| Assembly (the v2 MainScreenView container) | T8 | No — consumes T1–T7 |
| Post-assembly (a11y, motion, analytics, pbxproj swap) | T9–T13 | T9–T10 parallel; T11–T13 sequential |
| Verification (tests, snapshot, checklist, build) | T14–T17 | Mostly sequential |

The 9-parallel-foundation layer is the shape that repeats on every subsequent v2 refactor (Training, Nutrition, Stats, Settings). Home v2 is where that pattern was discovered — but Home ran under v3.0 which did not yet have the L1 cache, so the pattern was serialized rather than dispatched.

### Phase 3 — UX / Integration

`/ux spec` produced the 7-section stack:

1. Toolbar
2. LiveInfoStrip — modified to be static (no auto-rotation)
3. ReadinessCard — promoted to hero
4. TrainingNutritionCard — **new**, side-by-side Start Workout + Log Meal CTAs
5. StatusCard — v1 carry-over with token compliance pass
6. GoalCard — v1 carry-over
7. MetricsRow — 4× `AppMetricTile`

Compliance gateway: 5/5 pass (motion tokens classified as DS evolution, not deviation). Heuristic validation: 12/12 pass.

### Phase 4 — Implementation

Six commits in Phase 4: `8b5fdf2`, `136efe3`, `f266932`, `ec95eaa`, `73df335`, plus the merge. Foundation tokens and component promotions landed first, then the v2 `MainScreenView` assembly, then the a11y pass, then the pbxproj swap, then tests.

**The pbxproj swap** was a single atomic commit: v2 file added as `PBXBuildFile`, v1 removed from `PBXSourcesBuildPhase` but retained as `PBXFileReference` so the git history and navigator entry survive. Because both files define `MainScreenView`, the call-site in `RootTabView.swift` did not change — the symbol resolution flipped at the build graph layer.

### Phase 5 — Testing

21 tests shipped (11 behavior + 10 analytics). All 12 test runs green. Snapshot tests (T16) were deferred to manual Phase 5 — the only task that didn't land inside Phase 4.

CI: `BUILD SUCCEEDED` on iPhone 17 Pro, iOS 26.4.

---

## 5. Decisions That Ended Up as Project-Wide Rules

Two outputs of this feature became permanent framework artifacts:

### 5.1 The V2 Rule

Home v2 is the feature that took the idea of "new directory for the refactored version" and turned it into a codified contract:

- `v2/` subdirectory with same filename → no call-site churn.
- Same Swift type name on both sides → same symbol, flipped by pbxproj.
- v1 retained as historical reference with `HISTORICAL —` header comment.
- One pbxproj commit to do the swap.
- Verification via `docs/design-system/v2-refactor-checklist.md`.

The rule now lives in `CLAUDE.md` under "UI Refactoring & V2 Rule" and has been applied by five subsequent screens (Training, Nutrition, Stats, Settings, and — retroactively — Onboarding).

### 5.2 Screen-prefixed analytics naming

OQ-9 of the audit Decisions Log asked whether the new Home events should be named like `tap_start_workout` or `home_action_tap`. The user chose the screen-prefix form — rationale in the decision log was "when looking at GA4 I want the source screen obvious without opening source."

Three days later that answer was lifted into `CLAUDE.md` as a project-wide rule with a backwards-compatibility plan for older events. `/analytics spec` now refuses to write a spec that contains a screen-scoped event without the prefix.

---

## 6. What Shipped vs What Was Deferred

### Shipped (in PR #61)

- 7-section v2 container with hierarchy fix (Readiness hero, side-by-side CTAs, empty/loading/error, full a11y, reduce-motion).
- 3 `home_*` analytics events with 21 tests.
- 4 new design tokens and 2 component promotions, all pushed into the main design system (not feature-local).
- Full V2 Rule compliance — v1 retained as historical, v2 wired via pbxproj.

### Deferred (spun out)

| Deferred item | Outcome |
|---|---|
| Status+Goal merged card | Own PM cycle (parent = Home v2) |
| Metric tile deep-linking | Own PM cycle (parent = Home v2) |
| Onboarding v2 retroactive refactor | Own PM cycle — applies the V2 Rule back to Onboarding which predates it |
| `home_metric_tile_tap` event | Ships with Metric Tile Deep Linking |
| F11 goal drill-down, F13 macro strip | Rolled into downstream features (Status+Goal, Nutrition v2) |
| Snapshot tests (T16) | Deferred to manual Phase 5 |

The deferral pattern is notable: rather than expanding Home v2 scope to absorb adjacent P1 work, the framework spawned three sub-features, each with its own state.json, PRD, and tests. This is the pattern the framework later formalized as "sub-feature queue management" in v3.0.

---

## 7. Lessons

1. **The V2 Rule needs a pilot that is deliberate about the project.pbxproj step.** Onboarding v2 showed the idea worked; Home v2 showed the mechanics. Later screens only needed to follow the recipe.

2. **Decisions Logs are the right way to bridge audits to PRDs.** Every audit finding that requires a product call becomes an OQ; every OQ becomes a PRD line. No judgment calls get lost between the research and PRD phases.

3. **OQ answers can become project-wide rules.** The screen-prefixed analytics convention was a byproduct of one feature's audit. This is now a standing question inside the `/ux audit` template: "does any OQ answer generalize beyond this screen?"

4. **Spawn sub-features rather than expanding scope.** Status+Goal and metric-tile deep-linking each became their own PM cycle with their own PRDs. Home v2 shipped clean; the deferred work didn't stall the pilot.

5. **Kill criteria for core screens are regression-only.** Home cannot be killed on a growth threshold because there's no version-off state — every user sees it on every launch. The kill criterion is "no readiness/biometric flow regresses."

6. **V3.0 did not yet parallelize.** The 9-parallel-task foundation layer was designed in Home v2 but executed serially. The L1 cache and parallel dispatcher landed in v4.0 (Training v2) and compressed the same shape from hours to minutes.

---

## 8. Links

- **PR:** #61 (merged bf3bd67 on 2026-04-09)
- **State:** `.claude/features/home-today-screen/state.json`
- **Audit report:** `.claude/features/home-today-screen/v2-audit-report.md`
- **PRD:** `.claude/features/home-today-screen/prd.md`
- **UX spec:** `.claude/features/home-today-screen/ux-spec.md`
- **Tasks:** `.claude/features/home-today-screen/tasks.md`
- **V2 files:** `FitTracker/Views/Main/v2/MainScreenView.swift`
- **V1 files (historical):** `FitTracker/Views/Main/MainScreenView.swift`
- **Design memory:** `docs/design-system/feature-memory.md` (2026-04-09 entry)
- **Project-wide rules born here:** V2 Rule (`CLAUDE.md`), screen-prefixed analytics (`CLAUDE.md`)
- **Sub-features spawned:** `onboarding-v2-retroactive`, `home-status-goal-card`, `metric-tile-deep-linking`
- **Related case studies:** `pm-workflow-evolution-v1-to-v4.md` (Home is the v3.0 data point), `pm-workflow-showcase-onboarding.md` (the Onboarding v2 pilot that preceded this)
