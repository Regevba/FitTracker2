# Tasks — unified-control-center

**Phase:** 2 (Tasks)
**Status:** Draft awaiting user approval
**Framework version:** v7.6
**Started:** 2026-04-26T09:30:00Z
**Author:** Claude Opus 4.7
**Source PRD:** [`prd.md`](prd.md)

---

## Task complexity classifier (v5.1 — ARM big.LITTLE)

Each task scored against `skill-routing.json` indicators (files_changed, new_model/service, token_budget, cross_feature_deps, requires_judgment) and tagged for **E-core (lightweight, parallel, sonnet)** or **P-core (heavyweight, serial, opus)**.

## Total estimate

- **35 tasks** across 9 work blocks
- **~5–7 weeks** wall time
- **CU estimate (T2):** 35 tasks × 1.0 (Feature work-type) × (1 + 0.2 cross-feature + 0.2 architectural-novelty + 0.45 has-UI-multi-view + 0.5 auth/external + 0.4 runtime-testing) = **35 × 1.0 × 2.75 ≈ 96.25 CU**
- **Velocity target (T2 forward-looking):** ≤8 min/CU = ~13 hours of focused work; padded ×3 for design+test+coordination = **~5–7 weeks calendar**

---

## Block A — Pre-migration baseline (DO FIRST, blocks everything else)

**Why first:** PRD §5.1 requires the TTC baseline measured on the current Astro dashboard before migration starts. Without this we ship a T2-only baseline and the case study has no "before" data.

| ID | Task | Skill | Type | Effort (d) | Lane | Depends on |
|---|---|---|---|---|---|---|
| **T1** | Instrument the current Astro dashboard with `dashboard_load` + `dashboard_blocker_acknowledged` GA4 events; deploy to fit-tracker2.vercel.app | dev | analytics+infra | 0.5 | E-core | — |
| **T2** | Capture 7 days of TTC data → write baseline JSON to `.claude/features/unified-control-center/baseline-ttc.json` | analytics | data | 0.25 (actual: 7 days wall, 0.25 active) | E-core | T1 |

**Gate:** Baseline measured before T3 starts. If gate is bypassed (e.g., we move forward without 7 days of data), the case study must explicitly tag the baseline as **T2 (Declared estimate)** instead of **T1 (Instrumented)**.

---

## Block B — Sync infrastructure (Pattern 4.b)

**Why second:** all dashboard rendering depends on data being available. Sync script + Vercel build setup is the foundation.

| ID | Task | Skill | Type | Effort (d) | Lane | Depends on |
|---|---|---|---|---|---|---|
| **T3** | Write `fitme-story/scripts/sync-from-fittracker2.ts` (inline, per Q2=A) + JSON schema validation post-sync; outputs to `src/data/shared/` + `src/data/features/`; writes `freshness.json` with sync timestamp | dev | infra | 1.0 | P-core | — |
| **T4** | Add `prebuild` hook in `fitme-story/package.json` that runs T3 | dev | infra | 0.1 | E-core | T3 |
| **T5** | Add `vercel.json` build command that clones FitTracker2 (shallow, deploy key) before `next build`; document the deploy-key setup procedure | ops | infra | 0.5 | P-core | T3, T4 |
| **T6** | Add unit test for sync script (mock filesystem, assert all expected files copied + freshness.json written) | qa | test | 0.25 | E-core | T3 |
| **T7** | Local-dev verification: `npm run prebuild && npm run dev` → all 11 shared JSONs + 43 feature state.jsons appear in `src/data/`; freshness.json is current | qa | test | 0.1 | E-core | T3, T4 |

---

## Block C — Visibility control (the blind-switch — PRD §6)

**Why third:** rendering anything sensitive requires the gate to exist first. We don't render the dashboard until the lock is in place.

| ID | Task | Skill | Type | Effort (d) | Lane | Depends on |
|---|---|---|---|---|---|---|
| **T8** | Implement `fitme-story/src/middleware.ts` Layer 1: read `DASHBOARD_PUBLIC` env var + basic-auth via `DASHBOARD_USER`/`DASHBOARD_PASS`; matcher = `/control-room/:path*` only (showcase stays public — Q1=B) | dev | infra | 0.5 | P-core | — |
| **T9** | Layer 2: update `src/app/sitemap.ts` to exclude `/control-room/*` unconditionally; update `src/app/robots.ts` with `Disallow: /control-room` rule | dev | infra | 0.25 | E-core | — |
| **T10** | Layer 3: `next.config.ts` reads `DASHBOARD_BUILD` env var; if `false`, `/control-room/*` returns 404 + dashboard bundles dropped via webpack `IgnorePlugin` | dev | infra | 0.5 | P-core | — |
| **T11** | Write `scripts/verify-blind-switch.sh` per PRD §6.5 (5 acceptance assertions: sitemap excludes, robots.txt disallow, 401 on auth-gated, 200 with valid auth, 404 with `DASHBOARD_BUILD=false`) | qa | test+infra | 0.5 | P-core | T8, T9, T10 |
| **T12** | Add CI job that runs `verify-blind-switch.sh` on every PR touching control-room/middleware/sitemap files | ops | infra | 0.25 | E-core | T11 |
| **T13** | Add ESLint rule: showcase code must not import from `*/control-room/*` (per PRD §7.2 no-reverse-imports) — enforces extraction-readiness | dev | infra | 0.25 | E-core | — |
| **T14** | Document Vercel env-var setup procedure in `EXTRACTION-RECIPE.md` (DASHBOARD_PUBLIC, DASHBOARD_USER, DASHBOARD_PASS, DASHBOARD_BUILD, FT2 deploy key) | research | docs | 0.25 | E-core | T8, T10 |

---

## Block D — Design system token mapping

**Why fourth:** before component port, we settle the visual contract.

| ID | Task | Skill | Type | Effort (d) | Lane | Depends on |
|---|---|---|---|---|---|---|
| **T15** | Map dashboard `tailwind.config.mjs` brand/status/priority palette → fitme-story `--color-brand-indigo` + `--skill-{name}` palette; produce mapping table doc | design | docs | 0.5 | P-core | — |
| **T16** | Pre-migration WCAG audit: every dashboard color on every fitme-story background; produce contrast report (axe MCP) | design | test | 0.5 | E-core | T15 |
| **T17** | Resolve any contrast failures from T16 (either pick alternate skill color, or define a one-off override in dashboard scope only) | design | infra | 0.5 | P-core | T16 |

---

## Block E — Component port (8 keep + 5 redesign + 2 drop)

**Why fifth:** with sync + auth + tokens in place, port + redesign components.

### Keep (8)

| ID | Task | Skill | Type | Effort (d) | Lane | Depends on |
|---|---|---|---|---|---|---|
| **T18** | Port `Dashboard.jsx` (root orchestrator) → `src/app/control-room/layout.tsx` + view router | dev | ui | 0.5 | P-core | T7, T15 |
| **T19** | Port `controlCenterPrimitives.jsx` (Panel, MetricList, MetricCard, InfoTile) → `src/components/control-room/primitives.tsx` using fitme-story tokens | dev | ui | 1.0 | P-core | T15 |
| **T20** | Port `ControlRoom.jsx` (overview + alerts + critical features) → `src/app/control-room/page.tsx`; integrate fitme-story `Hero` + `NumbersPanel` patterns | dev | ui | 1.5 | P-core | T18, T19 |
| **T21** | Port `KanbanBoard.jsx` (@dnd-kit drag-drop) → `src/app/control-room/board/page.tsx` | dev | ui | 1.5 | P-core | T18, T19 |
| **T22** | Port `TableView.jsx` (@tanstack/react-table) → `src/app/control-room/table/page.tsx` | dev | ui | 1.0 | P-core | T18, T19 |
| **T23** | Port `KnowledgeHub.jsx` → `src/app/control-room/knowledge/page.tsx`; preserve DOC_GROUP_META structure | dev | ui | 1.0 | P-core | T18, T19 |
| **T24** | Port `AlertsBanner.jsx`, `SourceHealth.jsx`, `FeatureCard.jsx`, `TaskCard.jsx`, `ThemeToggle.jsx` (reuse fitme-story dark-mode pattern) | dev | ui | 1.0 | P-core | T18, T19 |
| **T25** | Add data-freshness footer reading `src/data/shared/freshness.json` (PRD FR-8) — staleness >6h → red warning | dev | ui | 0.25 | E-core | T7, T19 |

### Redesign (5)

| ID | Task | Skill | Type | Effort (d) | Lane | Depends on |
|---|---|---|---|---|---|---|
| **T26** | Replace `TaskBoard.jsx` with a flat TaskCard grid component (drop redundancy with KanbanBoard) | dev | ui | 0.5 | P-core | T19, T21 |
| **T27** | Replace `PipelineOverview.jsx` with a simple phase legend + recent-activity strip (lifted from change-log.json) | dev | ui | 0.5 | E-core | T19 |
| **T28** | Remove `CaseStudiesView.jsx` from dashboard; add a "Case studies →" link in dashboard nav that points to `/case-studies` (the existing showcase route) | dev | ui | 0.25 | E-core | T18 |
| **T29** | Replace `DependencyGraph.jsx` with a simple task-tree component (or omit; decide in T29.5 below) | dev | ui | 0.5 | E-core | T19, T21 |
| **T30** | Add view-persistence via localStorage (Q3=A): `useEffect` reads/writes `control-room:view` + `control-room:filters`; `?reset=true` URL param clears | dev | ui | 0.25 | E-core | T22 |

### Drop (2 — no port task; just decommission)

`ResearchConsole.jsx` and `FigmaHandoffLab.jsx` are dropped — covered by T34 below.

---

## Block F — Data layer port

| ID | Task | Skill | Type | Effort (d) | Lane | Depends on |
|---|---|---|---|---|---|---|
| **T31** | Port `dashboard/src/scripts/builders/controlCenter.js` + 7 parsers → `fitme-story/src/lib/control-room/builder.ts` (TypeScript). Read from `src/data/shared/` + `src/data/features/` (synced by T3); GitHub fetch stays optional via `GITHUB_TOKEN` | dev | data | 2.0 | P-core | T7, T18 |
| **T32** | Port `dashboard/src/scripts/github.js` → `src/lib/control-room/github.ts` (TS), preserve existing fetch logic | dev | data | 0.5 | E-core | T31 |
| **T33** | Port dashboard tests (`dashboard/tests/*.test.js`, 5 files / 390 LOC) → vitest suite under `src/lib/control-room/__tests__/` | qa | test | 1.0 | P-core | T31 |

---

## Block G — Decommission Astro dashboard

| ID | Task | Skill | Type | Effort (d) | Lane | Depends on |
|---|---|---|---|---|---|---|
| **T34** | Mark `dashboard/` directory as historical with a top-level README.md note + git history reference; leave code in repo for 30-day rollback window per PRD §13 | release | docs | 0.25 | E-core | T20 (new dashboard works) |
| **T35** | Configure fit-tracker2.vercel.app to redirect → `https://fitme-story.vercel.app/control-room` after T20 verified working in production | ops | infra | 0.25 | E-core | T34 |

---

## Block H — Analytics instrumentation (PRD §10)

| ID | Task | Skill | Type | Effort (d) | Lane | Depends on |
|---|---|---|---|---|---|---|
| **T36** | Wire 8 new GA4 events (`dashboard_load`, `dashboard_blocker_acknowledged`, `dashboard_view_change`, `dashboard_filter_apply`, `dashboard_kanban_drag`, `dashboard_knowledge_open`, `dashboard_external_link`, `dashboard_sync_warning_shown`) via existing `@next/third-parties/google` integration | analytics | analytics | 0.75 | E-core | T20, T21, T22, T23 |
| **T37** | Add 8 new rows to `docs/product/analytics-taxonomy.csv` with full metadata per the CSV schema | analytics | data | 0.25 | E-core | T36 |
| **T38** | Write analytics unit tests asserting each event fires correctly with expected parameters (`MockAnalyticsAdapter` pattern) | qa | test | 0.5 | E-core | T36 |

---

## Block I — Documentation + extraction recipe

| ID | Task | Skill | Type | Effort (d) | Lane | Depends on |
|---|---|---|---|---|---|---|
| **T39** | Write `EXTRACTION-RECIPE.md` per PRD §7.3 — 7-step playbook for future split + manual-trigger CI job that runs the extraction in a scratch directory and verifies blind-switch still passes | research | docs | 0.5 | P-core | T8–T14 |
| **T40** | Update `CLAUDE.md` "## Key Paths > Skills ecosystem" section to reference the new `/control-room` route + extraction recipe + `.claude/features/unified-control-center/` | release | docs | 0.25 | E-core | T39 |
| **T41** | Update fitme-story `README.md` to mention the `/control-room` private dashboard + how the blind-switch works (1 paragraph, no creds disclosed) | release | docs | 0.25 | E-core | T39 |
| **T42** | Write feature case study: `docs/case-studies/unified-control-center-case-study.md` per the feedback memory rule "every feature gets a case study" + the v7.6 outlier-flag pattern (single-author + dogfooded measurement); honest tier-tagging | research | docs | 1.5 | P-core | (Phase 8) all above |

> Note on case study: **the case study is monitored from day one** per `state.json.case_study.monitored_from_day_one = true`. Phase 8 just produces the polished narrative; the contemporaneous log + state.json metrics are the data source.

---

## Lane summary (for v5.1 task-complexity-gate dispatch)

| Lane | Count | Tasks | Sum effort (d) |
|---|---|---|---|
| **E-core (lightweight, parallel, sonnet)** | 14 | T1, T2, T4, T6, T7, T9, T12, T13, T14, T16, T25, T27, T28, T29, T30, T32, T34, T35, T36, T37, T38, T40, T41 | 5.6 |
| **P-core (heavyweight, serial, opus)** | 18 | T3, T5, T8, T10, T11, T15, T17, T18, T19, T20, T21, T22, T23, T24, T26, T31, T33, T39, T42 | 13.5 |

> Wait — totals: 14+18 = 32, but I listed 42 IDs. Let me recount: T1, T2, T4, T6, T7, T9, T12, T13, T14, T16, T25, T27, T28, T29, T30, T32, T34, T35, T36, T37, T38, T40, T41 = 23 E-core. T3, T5, T8, T10, T11, T15, T17, T18, T19, T20, T21, T22, T23, T24, T26, T31, T33, T39, T42 = 19 P-core. 23+19 = 42. ✓

| Lane | Count | Sum effort (d) |
|---|---|---|
| **E-core** | 23 | ~6.5 |
| **P-core** | 19 | ~14.5 |
| **Total active work** | 42 | ~21 dev-days |

Plus 7 wall-clock days for T2 baseline capture. **Total: ~5 calendar weeks** with P-core serial bottleneck.

---

## Dependency graph (compressed)

```
T1 (instrument) → T2 (baseline)
                                              ┌──> T18..T25 (component port keep)
T3 (sync script) → T4, T6, T7 (sync infra) ───┼──> T26..T30 (component port redesign)
                          │                   └──> T31 (data layer)
                          │                            └──> T32 (github), T33 (tests)
T5 (vercel build) ────────┘
T8, T9, T10 (visibility 3 layers) → T11, T12 (verification + CI)
T13 (eslint reverse-imports rule)
T14 (env vars docs)
T15 (token map) → T16 (contrast audit) → T17 (resolve)
                          │
                          └────> T18..T25 (component port consumes tokens)

T20 (new dashboard works) → T34 (mark Astro historical) → T35 (redirect)

T36..T38 (analytics) depends on T20..T23

T39 (extraction recipe) depends on T8..T14 (visibility shape)
T40, T41 (docs) depends on T39
T42 (case study) depends on Phase 8 (everything else done)
```

**Critical path:** T3 → T18 → T20 → T34 → T35 (≈8 dev-days) + T2 baseline wall-clock (7 days). Total: ~3 calendar weeks if P-core lane runs without blockers.

---

## state.json.tasks[] (machine-readable mirror)

> Will be written into state.json on PRD approval (Phase 2 transition). Truncated here for readability — see state.json.tasks for full structured form.

```json
[
  {"id": "T1", "title": "Instrument current Astro dashboard with TTC events", "skill": "dev", "type": "ui", "lane": "E-core", "effort_days": 0.5, "depends_on": [], "status": "pending", "priority": "critical"},
  {"id": "T2", "title": "Capture 7 days of TTC baseline data", "skill": "analytics", "type": "data", "lane": "E-core", "effort_days": 0.25, "depends_on": ["T1"], "status": "pending", "priority": "critical"},
  ...
]
```

---

## Acceptance criteria (Phase 2 approval gate)

- [x] Every task has skill + type + lane + effort + dependencies
- [x] Dependency graph is acyclic (verified mentally; will be auto-checked by Phase 4 dispatcher)
- [x] Critical path identified
- [x] Block A (baseline) gates the rest of the work — explicit
- [x] All PRD §6 (visibility), §7 (extraction), §10 (analytics), §13 (rollback prep) requirements covered by tasks
- [x] All open-question defaults from §15 reflected (Q1=B → T8 middleware-only matcher; Q2=A → T3 inline; Q3=A → T30 localStorage; Q4=A → no preview-route task)

## Approval gate

User must explicitly approve this task breakdown before Phase 3 (UX) opens. On approval the framework will:
1. Set `phases.tasks.status = "approved"` + `count = 42`
2. Write the full `state.json.tasks[]` array
3. Auto-emit `phase_approved` event
4. Open Phase 3 (UX) — produces ux-spec.md against the design system compliance gateway, plus auto-generated handoff prompts in `docs/prompts/`

## Open questions for Phase 3

- Are KanbanBoard view + TableView view considered "screens" requiring full UX-spec treatment, or are they straight ports (just re-themed)?
- Should the Hero on `/control-room` reuse the fitme-story `Hero` component verbatim, or get a "control-room-flavored" variant?
- Does the operator want a global keyboard shortcut for "jump to alerts" (e.g., `g a`) — Linear-style command palette consideration?
