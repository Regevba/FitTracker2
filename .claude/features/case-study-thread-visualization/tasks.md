# Tasks — case-study-thread-visualization

> **Feature:** case-study-thread-visualization
> **Phase:** 2 (Tasks)
> **Total tasks:** 26
> **Total effort:** ~3.0 person-days for Phases 4-9 (after the 2026-05-22 calibration-pause resume)
> **PRD reference:** [`prd.md`](prd.md)
> **Research reference:** [`research.md`](research.md)
> **Branch:** `feature/case-study-thread-visualization`

---

## Phase 3 — UX / Integration (target: 2026-05-17 → 2026-05-20)

These tasks produce planning artifacts only (no code commits). Safe to run during the 2026-05-15→21 calibration window.

| ID | Title | Type | Skill | Priority | Effort (d) | Depends on | Complexity score | Lane |
|---|---|---|---|---|---|---|---|---|
| T1 | UX research — applicable UX principles + horizontal-timeline patterns + iOS HIG analogs | research | ux | high | 0.15 | — | 3 (judgment) | P-core |
| T2 | UX spec — `ux-spec.md` covering 5 states (default, hover, focused, no-series, reduced-motion), responsive breakpoints, a11y contract | design | ux | high | 0.20 | T1 | 5 (token_budget_high + judgment) | P-core |
| T3 | UX preflight — verify every token/component/pattern in ux-spec.md exists in fitme-story design system | infra | ux | high | 0.05 | T2 | 0 (mechanical) | E-core |
| T4 | Design preflight — fitme-story DS token compliance + Figma MCP liveness + Code Connect write-access | infra | design | high | 0.05 | T2 | 0 (mechanical) | E-core |
| T5 | Design audit — ux-spec.md against DS tokens, components, patterns, motion, a11y | design | design | high | 0.05 | T2 | 0 (mechanical) | E-core |
| T6 | UX prompt — auto-generated handoff at `docs/prompts/ux/2026-05-XX-case-study-thread-visualization-ux-build.md` | docs | ux | medium | 0.05 | T2 | 0 (mechanical) | E-core |
| T7 | Design prompt — auto-generated handoff at `docs/prompts/ui/2026-05-XX-case-study-thread-visualization-design-build.md` | docs | design | medium | 0.05 | T2 | 0 (mechanical) | E-core |
| T8 | Figma build — push `SeriesTimeline` component to FitMe DS Library via Figma MCP; populate `state.json.figma_node_ids` | design | design | high | 0.20 | T2, T5 | 4 (new_component + cross_feature_deps) | P-core |

**Phase 3 sub-total:** 0.80 person-days

---

## HARD PAUSE checkpoint (2026-05-21)

After T8 completes, Phase 3 transitions to "approved" and the feature **PAUSES** before Phase 4 per `state.json.scheduled_after.signal`. Implementation resumes 2026-05-22 (day after v7.9 promotion decision).

Resume protocol:
1. Confirm v7.9 promotion decision landed (2026-05-21)
2. Re-run `make preflight WORK_TYPE=feature FEATURE=case-study-thread-visualization`
3. Re-run `make integrity-diff` (should still report 0 regressions vs baseline)
4. Append `phase_started --phase implementation` Tier 2.2 log
5. Begin Phase 4

---

## Phase 4 — Implementation (target: 2026-05-22 → 2026-05-27)

| ID | Title | Type | Skill | Priority | Effort (d) | Depends on | Complexity score | Lane |
|---|---|---|---|---|---|---|---|---|
| T9 | Schema additive — `series_id: z.string().optional()` in `fitme-story/src/lib/content-schema.ts` | backend | dev | critical | 0.10 | — | 0 (single file, mechanical) | E-core |
| T10 | Series catalog — typed catalog at `fitme-story/src/lib/series-catalog.ts` with 10 series + member ordering | backend | dev | critical | 0.20 | T9 | 3 (judgment on member order + metadata) | P-core |
| T11 | Helper lib — `fitme-story/src/lib/series.ts` exposing `getSeriesById`, `getStudiesBySeries`, `getSeriesPosition` | backend | dev | critical | 0.10 | T9, T10 | 0 (mechanical) | E-core |
| T12 | `SeriesTimeline` component — listing variant (no current node) | ui | dev | critical | 0.50 | T11, T2 (UX spec), T8 (Figma) | 5 (new_component + judgment + cross_feature) | P-core |
| T13 | `SeriesTimeline` component — detail variant ("you are here" marker) | ui | dev | high | 0.20 | T12 | 2 (extends T12) | E-core |
| T14 | Listing page integration — new "Series" section in `fitme-story/src/app/case-studies/page.tsx` | ui | dev | critical | 0.20 | T11, T12 | 4 (multiple files + judgment on placement) | P-core |
| T15 | Detail page integration — timeline at top of every MDX with `series_id` | ui | dev | critical | 0.20 | T11, T13 | 4 (multiple files) | P-core |
| T16 | Backfill MDX — `12a-hadf-hardware-aware-dispatch.mdx` (hadf series Phase 1) | docs | dev | high | 0.10 | T9, T10 | 0 (single MDX) | E-core |
| T17 | Backfill MDX — `08b-onboarding-v2-retroactive.mdx` (onboarding-v2 series part 2) | docs | dev | high | 0.10 | T9, T10 | 0 | E-core |
| T18 | Backfill MDX — `23d-push-notifications-v1.mdx` (push-notifications series part 1) | docs | dev | high | 0.10 | T9, T10 | 0 | E-core |
| T19 | Backfill MDX — `27a-fitme-story-website-design-system-orig.mdx` (design-system-sweep series part 1) | docs | dev | high | 0.10 | T9, T10 | 0 | E-core |
| T20 | Frontmatter sweep — populate `series_id` on ~46 existing MDX files (mechanical, one PR-sized commit) | backend | dev | critical | 0.30 | T9, T10, T16-T19 | 2 (many files but mechanical) | E-core (parallel via batch-dispatch) |
| T21 | GA4 instrumentation — wire 4 new events in fitme-story analytics helper | analytics | analytics | critical | 0.20 | T12, T13 | 3 (event spec + IntersectionObserver) | P-core |
| T22 | Responsive layout — handle 8+ node timelines on mobile (horizontal scroll or paging) | ui | dev | high | 0.20 | T12 | 3 (judgment on breakpoints) | P-core |
| T23 | A11y — keyboard nav (Tab/Arrow/Enter), ARIA labels, reduced-motion fallback | ui | dev | critical | 0.20 | T12, T13 | 3 (judgment on a11y patterns) | P-core |
| T24 | CLAUDE.md convention — add series-naming + series_id contract to Case-Studies section (REQUIRES isolated worktree per Mode B advisory) | docs | dev | medium | 0.10 | — | 0 (single file, but infra-glob triggers Mode B) | E-core (with isolation) |

**Phase 4 sub-total:** 2.90 person-days

---

## Phase 5 — Testing & Measurement (target: 2026-05-27 → 2026-05-28)

| ID | Title | Type | Skill | Priority | Effort (d) | Depends on | Complexity score | Lane |
|---|---|---|---|---|---|---|---|---|
| T25 | Unit tests — series-catalog (every series ≥2 members; every series_id in MDX resolves) + helper lib (getSeriesPosition returns correct prev/next + boundary cases) | test | qa | critical | 0.10 | T10, T11, T20 | 0 (mechanical TDD) | E-core |
| T26 | Unit tests — `SeriesTimeline` component (renders nodes, click handlers fire correct events, keyboard nav, "you are here" marker correct) | test | qa | critical | 0.20 | T12, T13, T21, T23 | 3 (multiple interaction paths) | P-core |
| T27 | CI drift check — new script `scripts/check-series-drift.ts` invoked from fitme-story `ci.yml`; asserts every populated `series_id` resolves + every series has ≥2 members | infra | qa | high | 0.20 | T10, T20 | 2 (new CI step) | E-core |
| T28 | GA4 verification — manual test on preview deployment: trigger each of 4 events, confirm Realtime view shows them with correct params | test | analytics | critical | 0.10 | T21 | 0 (manual verification) | E-core (operator) |
| T29 | Performance baseline + verification — capture LCP/CLS on preview before merge; compare post-deploy; flag if guardrail fires | test | ops | high | 0.10 | T14, T15 | 0 (Vercel Speed Insights) | E-core |
| T30 | A11y verification — AXE-core CI run + manual keyboard/screen-reader test on preview | test | qa | high | 0.10 | T23 | 0 (existing AXE wired) | E-core |

**Phase 5 sub-total:** 0.80 person-days

---

## Phase 6 — Code Review + UI Review (target: 2026-05-28)

| ID | Title | Type | Skill | Priority | Effort (d) | Depends on | Complexity score | Lane |
|---|---|---|---|---|---|---|---|---|
| T31 | Code review — diff feature vs main, identify risks (any high-risk-area touches? Per CLAUDE.md: no — fitme-story-only) | review | dev | critical | 0.05 | T25-T30 | 0 | E-core |
| T32 | `/ux pre-merge-review` — heuristic re-check of shipped code vs `ux-spec.md`; verdict: passed / passed_with_notes / blocked | review | ux | critical | 0.05 | T25-T30 | 0 (mechanical) | E-core |
| T33 | `/design pre-merge-review` — `make ui-audit` N/A (web); fitme-story-specific DS audit + `figma_node_ids` populated + PR description references those IDs + spec ↔ build parity | review | design | critical | 0.05 | T25-T30 | 0 (mechanical) | E-core |
| T34 | CI gate verification — both feature branch and `main` green before approving merge | review | ops | critical | 0.05 | T31-T33 | 0 | E-core |

**Phase 6 sub-total:** 0.20 person-days

---

## Phase 7 — Merge (target: 2026-05-28)

| ID | Title | Type | Skill | Priority | Effort (d) | Depends on | Complexity score | Lane |
|---|---|---|---|---|---|---|---|---|
| T35 | Create PR, squash-merge to main, delete feature branch, record PR # in state.json | merge | dev | critical | 0.05 | T34 | 0 (mechanical) | E-core |
| T36 | Post-merge GA4 regression — verify all 4 new events still fire on prod after merge; check existing case-study events not broken | test | analytics | critical | 0.05 | T35 | 0 | E-core |

**Phase 7 sub-total:** 0.10 person-days

---

## Phase 8 — Documentation (target: 2026-05-28 → 2026-05-29)

| ID | Title | Type | Skill | Priority | Effort (d) | Depends on | Complexity score | Lane |
|---|---|---|---|---|---|---|---|---|
| T37 | Update PRD with final implementation state (any FR descope/scope-creep recorded) | docs | dev | medium | 0.05 | T35 | 0 | E-core |
| T38 | Update `docs/product/backlog.md` — move feature from Planned → Done | docs | dev | medium | 0.05 | T35 | 0 | E-core |
| T39 | Record baseline metric values in `state.json.phases.metrics` (LCP, CLS, AXE score from pre-merge capture) | docs | dev | medium | 0.05 | T29, T30, T35 | 0 | E-core |
| T40 | Set `first_review_date = 2026-06-26` (already in PRD; confirm state.json) | docs | dev | low | 0.02 | T35 | 0 | E-core |

**Phase 8 sub-total:** 0.17 person-days

---

## Phase 9 — Learn (case study) (target: 2026-05-29)

| ID | Title | Type | Skill | Priority | Effort (d) | Depends on | Complexity score | Lane |
|---|---|---|---|---|---|---|---|---|
| T41 | Author source case study at `docs/case-studies/case-study-thread-visualization-case-study.md` with 7 required frontmatter fields + 4 kill_criteria_resolution placeholders (to fill at T+30d review) | docs | dev | critical | 0.10 | T35-T40 | 2 (judgment on narrative) | E-core |
| T42 | Author fitme-story showcase MDX at `content/04-case-studies/<slot>-case-study-thread-visualization.mdx`; chronologically slot after the most-recent v7.8.6+ entry; set `series_id = framework-history` (or new series if it justifies one) | docs | dev | critical | 0.10 | T41 | 2 (slot decision) | E-core |
| T43 | Append final cache_hits[] count + Tier 2.2 phase_approved + complete event to feature log; transition `current_phase: complete` | infra | dev | critical | 0.05 | T41, T42 | 0 | E-core |
| T44 | Update memory file at `memory/project_case_study_thread_visualization_shipped.md` with final outcome | docs | dev | low | 0.05 | T43 | 0 | E-core |

**Phase 9 sub-total:** 0.30 person-days

---

## Totals

| Phase | Tasks | Effort (d) |
|---|---|---|
| 3 (UX/Integration) | 8 | 0.80 |
| 4 (Implementation) | 16 | 2.90 |
| 5 (Testing) | 6 | 0.80 |
| 6 (Review) | 4 | 0.20 |
| 7 (Merge) | 2 | 0.10 |
| 8 (Documentation) | 4 | 0.17 |
| 9 (Learn) | 4 | 0.30 |
| **TOTAL** | **44** | **5.27d** |

> Note: PRD §"Estimated Effort" had 3.5d total. Task-level breakdown shows ~5.3d due to per-task explicit a11y / responsive / test sub-tasks. Difference is granularity, not scope creep — the headline tasks (component, integration, backfill, tests) match. Total wall-clock should fit 2026-05-22 → 2026-05-29 with focused work; 2026-05-30 buffer for review + merge if needed.

## Dependency graph (high-level)

```
Phase 3 (planning artifacts only):
  T1 -> T2 -> T3, T4, T5, T6, T7
  T2, T5 -> T8

HARD PAUSE @ 2026-05-21 ───────────────────

Phase 4 (implementation):
  T9 (schema) -> T10 (catalog) -> T11 (helper)
  T9, T10 -> T16, T17, T18, T19 (backfill MDXs) -> T20 (frontmatter sweep)
  T11, T2, T8 -> T12 (component listing variant)
  T12 -> T13 (detail variant)
  T11, T12 -> T14 (listing integration)
  T11, T13 -> T15 (detail integration)
  T12, T13 -> T21 (GA4)
  T12 -> T22 (responsive)
  T12, T13 -> T23 (a11y)
  T24 (CLAUDE.md, independent — needs isolated worktree)

Phase 5 (testing):
  T10, T11, T20 -> T25 (catalog tests)
  T12, T13, T21, T23 -> T26 (component tests)
  T10, T20 -> T27 (CI drift)
  T21 -> T28 (GA4 verify)
  T14, T15 -> T29 (perf baseline)
  T23 -> T30 (a11y verify)

Phase 6 -> 7 -> 8 -> 9 sequential (T31...T44)
```

## Skill routing

- **`/dev`** (Phase 4 implementation): T9, T10, T11, T12, T13, T14, T15, T16-T19, T20, T22, T23, T24, T35, T37-T40
- **`/ux`** (Phase 3 + Phase 6): T1, T2, T3, T6, T32
- **`/design`** (Phase 3 + Phase 6): T4, T5, T7, T8, T33
- **`/analytics`** (Phase 4 + Phase 5 + Phase 7): T21, T28, T36
- **`/qa`** (Phase 5 + Phase 6): T25, T26, T27, T30
- **`/ops`** (Phase 5 + Phase 6): T29, T34
- **`/release` + docs writing** (Phase 8 + Phase 9): T41, T42, T43, T44

## Cross-feature dependencies

None. This feature is fully self-contained in the fitme-story repo + 1 FT2 CLAUDE.md edit + state.json. No HADF/UCC/framework-v7.9 dependency.

## Calendar gates

- **2026-05-22:** Phase 4 unblocks (post v7.9 promotion decision)
- **2026-05-23:** B8 UCC kill-criteria checkpoint — if any UCC-source case study needs an edit (T20 frontmatter sweep), wait until after this date
- **2026-06-04:** Phase E v7.9 post-promotion validation closes — full freedom thereafter
