# Framework Health Dashboard — Design

**Date:** 2026-04-27
**Author:** brainstormed with Claude
**Work item:** Enhancement to `unified-control-center` (no new feature record)
**Parent record:** [`.claude/features/unified-control-center/state.json`](../../../.claude/features/unified-control-center/state.json) — UCC's PRD-equivalent (resolved open questions, tasks, metrics) lives in state.json; the eventual case study is the Phase 8 artifact
**Status:** Design approved 2026-04-27, awaiting spec-review gate before plan

## 1. Context

The v7.6 framework currently produces four authoritative status surfaces:

| Source | What it answers |
|---|---|
| `.claude/shared/measurement-adoption.json` + `measurement-adoption-history.json` | Tier 1.1 — are post-v6 features actually populating the v6.0 measurement fields? |
| `.claude/shared/documentation-debt.json` | Tier 3.2 — are case studies covering required structural fields? |
| `.claude/integrity/snapshots/*.json` | Tier 3.1 — are state.json + case studies passing the 12-code cycle integrity check? |
| Composed across the above | Status of the 9-tier ladder, mechanical limits, regression detection |

These run on cron (72h integrity cycle, weekly framework-status cron) and on every commit (pre-commit gates). Today the only way to read them is via terminal:

```sh
make measurement-adoption
make documentation-debt
make integrity-check
cat .claude/shared/measurement-adoption-history.json
```

That works for the operator (Regev) but it doesn't *track the data flow*. Trend lines exist for Tier 1.1 (2 snapshots so far) and the integrity-snapshots directory (1 snapshot so far) but they're not visualized anywhere. The user explicitly asked for a dashboard surface where this data is "presented, stored, reflected, and present so we can track on the data flow."

This is the work to do that.

## 2. Scope

**In scope:**
- Surface Tier 1.1 / 3.1 / 3.2 trend lines, plus a 9-tier scoreboard, plus per-feature adoption table, on a new `/control-room/framework` page inside fitme-story.
- Add history-writers for the two ledgers that don't have them yet (`documentation-debt-history.json`, `integrity-history.json`).
- Wire the existing FT2 GHAs (`integrity-cycle.yml`, `framework-status-weekly.yml`) to ping a Vercel deploy hook so the dashboard is fresh exactly when new data exists.
- **Automation map** (passive/reflection panel, added 2026-04-27 — see §16) — display-only inventory of every pre-commit gate, per-PR check, scheduled cycle, and operator dashboard, with active/online status, last-run timestamp, and next-run countdown.

**Out of scope (backlogged for follow-up):**
- Mechanical-limits panel (5 unclosable-gap status tiles).
- Recent-activity strip (last N pre-commit fires / cycle runs).
- Composite "framework health score" — explicitly avoided per the v7.6 case study warning against summarizing-over-truth.
- Public-facing trust surface at `fitme-story.vercel.app/framework/health` — separate decision; this page stays gated under `/control-room/*` basic-auth.
- Backfilling history from git log — schemas evolved (v7.5 → v7.6 added check codes); apples-to-oranges denominators.

## 3. Decisions captured during brainstorming

| # | Question | Decision | Reason |
|---|---|---|---|
| 1 | Where does this live? | Enhancement to `unified-control-center` | UCC's data layer, basic-auth, design tokens, sync infra, build pipeline are already shipped. |
| 2 | Primary lens? | Trend tracking | User phrasing "track on the data flow"; only the trend lens makes the existing history ledger a load-bearing asset. |
| 3 | Storage scope? | Medium — add 2 history writers + 1 indexer | Light leaves trend writers we paid for unrendered; Heavy backfills mix denominators across schema changes. |
| 4 | v1 page sections? | 6 sections (1 + 2 + 3 + 4 + 5 + 8) | Matches storage scope exactly; nice-to-haves go to backlog. |
| 5 | Refresh cadence? | After-CI Vercel deploy hook | Aligns with build-time-sync architecture (T3); makes staleness meaningful (dashboard updates iff framework produced new data). |

## 4. Architecture

```
FT2 repo (canonical data source)
├── .claude/shared/
│   ├── measurement-adoption.json          [exists]
│   ├── measurement-adoption-history.json  [exists, append-only]
│   ├── documentation-debt.json            [exists]
│   ├── documentation-debt-history.json    [NEW, append-only]
│   └── integrity-history.json             [NEW, indexed flat ledger]
├── .claude/integrity/snapshots/*.json     [exists, append-only directory]
└── .github/workflows/
    ├── integrity-cycle.yml                [existing — extend]
    └── framework-status-weekly.yml        [existing — extend]
                  │
                  │  (after JSON commit, NEW: ping Vercel deploy hook)
                  ▼
fitme-story (presentation layer)
├── scripts/sync-from-fittracker2.ts       [existing — extend for 4 new JSONs + schema validation]
├── .synced/framework-health/              [NEW namespace]
│   ├── measurement-adoption.json
│   ├── measurement-adoption-history.json
│   ├── documentation-debt.json
│   ├── documentation-debt-history.json
│   └── integrity-history.json
└── src/app/control-room/framework/page.tsx [NEW, Server Component, build-time static]
```

### Why no Cache Components / `use cache`

fitme-story is on Next.js 16, which supports Cache Components opt-in. This page deliberately does not use them:

- The page reads JSON files synced into the repo at build time. There is no per-request, per-user, or runtime data.
- A Server Component with synchronous file reads is fully prerendered to static HTML by default — exactly the behavior we want.
- `'use cache'` with `cacheTag` + `revalidateTag` would be appropriate if we wanted incremental cache invalidation without a rebuild. We chose deploy-hook rebuild instead, because the data lives in FT2 (not fitme-story) and the sync step needs to re-run to pull new JSONs into the build artifact. `revalidateTag` alone wouldn't re-run the sync.
- If future iterations introduce per-user views or live runtime data, revisit Cache Components then.

## 5. Component decomposition

Each component takes typed props and renders. Only `<FrameworkPage>` touches the filesystem (at build time). This keeps the chart components unit-testable with fixture data and decoupled from the data layer.

| Component | Path | Inputs | Output |
|---|---|---|---|
| `<FrameworkPage>` | `src/app/control-room/framework/page.tsx` | reads `.synced/framework-health/*` at build | composes the 6 sections |
| `<TierScoreboard>` | `src/components/control-room/framework/TierScoreboard.tsx` | `tiers: TierStatus[]` (composed in page) | 9-tile grid, status badge per tile |
| `<MeasurementTrendChart>` | `.../MeasurementTrendChart.tsx` | `history: AdoptionSnapshot[]` | Recharts line chart, 4 dimensions |
| `<FeatureAdoptionTable>` | `.../FeatureAdoptionTable.tsx` | `current: AdoptionReport`, `previous?: AdoptionReport` | 9 post-v6 rows × 4 dim chips + Δ arrows |
| `<IntegrityTrendChart>` | `.../IntegrityTrendChart.tsx` | `history: IntegritySnapshot[]` | Recharts stacked area, findings by code |
| `<DocDebtTrendChart>` | `.../DocDebtTrendChart.tsx` | `history: DocDebtSnapshot[]` | Recharts dual-axis: open items + coverage % |
| `<FreshnessFooter>` | `.../FreshnessFooter.tsx` | existing `freshness.json` schema | "Last sync: X ago · source SHA · snapshot date" |

**Type contracts** live in `src/lib/control-room/framework/types.ts` and are derived from the JSON schemas added in T44.

### Trend mode unlock pattern

For ledgers with fewer than 3 snapshots, the corresponding chart renders an empty-state: *"Trend mode unlocks at 3 snapshots (currently N). Next scheduled cycle: <date>"*. This mirrors the existing Tier 1.1 `trend_ready: false` convention and prevents misleading 1-point line graphs.

## 6. Data layer changes (FT2 side)

### 6.1 New history writers

**`scripts/documentation-debt-report.py`** — append a `documentation-debt-history.json` writer step. Mirror the exact pattern in `measurement-adoption-report.py`:

- Dedup-by-date: at most one snapshot per calendar day.
- Append-only: `snapshots[]` array grows monotonically.
- Schema: `{date, generated_at, trigger, summary, coverage}` per snapshot.

**New script `scripts/index-integrity-snapshots.py`** — walk `.claude/integrity/snapshots/*.json`, produce a flat `integrity-history.json` with one entry per snapshot file:

- `{date, generated_at, source_file, summary, findings_by_code: {code: count}}` per entry.
- Idempotent — recomputed from the directory on every invocation.
- Hooked into the 72h integrity cycle GHA so it runs after each new snapshot lands.

### 6.2 GHA deploy-hook step (added to both)

After the existing integrity-check + commit-back steps, add a final gated step that pings a Vercel deploy hook only when JSON changed in this run. Pseudocode:

```yaml
- name: Detect framework-status JSON changes
  id: detect_changes
  run: |
    if git diff --quiet HEAD~1 -- .claude/shared/measurement-adoption-history.json \
                                   .claude/shared/documentation-debt-history.json \
                                   .claude/shared/integrity-history.json \
                                   .claude/integrity/snapshots/; then
      echo "changed=false" >> "$GITHUB_OUTPUT"
    else
      echo "changed=true" >> "$GITHUB_OUTPUT"
    fi

- name: Trigger fitme-story rebuild
  if: steps.detect_changes.outputs.changed == 'true'
  run: curl -fsS -X POST "${{ secrets.FITME_STORY_DEPLOY_HOOK }}"
```

Exact wiring is finalized at task time — the existing workflows have their own commit/push pattern and the diff-base may need adjustment (e.g., `git diff HEAD^ HEAD` vs. workflow-specific refs).

The deploy hook URL is created in Vercel's fitme-story project settings (Project Settings → Git → Deploy Hooks) and stored as a repo secret `FITME_STORY_DEPLOY_HOOK` in FT2. Manual setup; recipe goes in `EXTRACTION-RECIPE.md` (T46).

The change-gate avoids spurious rebuilds when integrity-check's output is byte-identical to last run.

## 7. Data layer changes (fitme-story side)

### 7.1 Sync extension

**`scripts/sync-from-fittracker2.ts`** — add 4 new entries to the source manifest:

```ts
{
  src: '.claude/shared/measurement-adoption.json',
  dst: '.synced/framework-health/measurement-adoption.json',
  schema: 'schemas/measurement-adoption.schema.json',
},
// + 3 more for measurement-adoption-history, documentation-debt-history, integrity-history
```

JSON schemas live in `fitme-story/scripts/schemas/`. Sync fails the build with a loud error if a source JSON doesn't match — same pattern T6 already established for the existing sources.

### 7.2 Page rendering

`src/app/control-room/framework/page.tsx` is a default-static Server Component:

```tsx
import path from 'node:path'
import fs from 'node:fs/promises'

export default async function FrameworkPage() {
  const root = path.join(process.cwd(), '.synced/framework-health')
  const [adoption, adoptionHistory, debt, debtHistory, integrityHistory] =
    await Promise.all([
      readJson(path.join(root, 'measurement-adoption.json')),
      readJson(path.join(root, 'measurement-adoption-history.json')),
      readJson(path.join(root, 'documentation-debt.json')),
      readJson(path.join(root, 'documentation-debt-history.json')),
      readJson(path.join(root, 'integrity-history.json')),
    ])

  const tiers = composeTierStatus({ adoption, debt, integrityHistory })

  return (
    <main>
      <TierScoreboard tiers={tiers} />
      <MeasurementTrendChart history={adoptionHistory.snapshots} />
      <FeatureAdoptionTable current={adoption} />
      <IntegrityTrendChart history={integrityHistory.snapshots} />
      <DocDebtTrendChart history={debtHistory.snapshots} />
      <FreshnessFooter />
    </main>
  )
}
```

The `composeTierStatus()` helper lives in `src/lib/control-room/framework/compose.ts` and is the single source of truth for which tier maps to which JSON field — unit-tested.

## 8. Error handling

| Failure mode | Behavior |
|---|---|
| Source JSON malformed (schema violation at sync time) | Sync fails the build loudly. T44 includes the schema. |
| Source JSON missing entirely (FT2 GHA hasn't run yet) | Sync writes a placeholder; page renders the section with `<EmptyState reason="awaiting first run" />`. |
| History ledger has < 3 snapshots | Corresponding chart renders trend-mode-unlock empty-state with snapshot count + next scheduled cycle date. |
| Stale data (last sync > 14 days ago) | Freshness footer renders in red. Page still renders; staleness is information, not a failure. |
| Deploy hook ping fails (network, secret missing) | GHA logs warning but does not fail the cycle run. Dashboard stays at last-good-data; freshness footer makes staleness visible. |

No page-level error boundaries needed — every section degrades to a useful empty state independently.

## 9. Testing

| Layer | Test type | Tool | Path |
|---|---|---|---|
| Sync schemas | Schema validation against fixtures (valid + 3 malformed cases) | vitest | `scripts/__tests__/sync.framework-health.test.ts` |
| `composeTierStatus()` | Unit, deterministic input → expected tier map | vitest | `src/lib/control-room/framework/__tests__/compose.test.ts` |
| Each chart component | Snapshot test with 1, 3, 10-snapshot fixtures + regression case | vitest + RTL | `src/components/.../__tests__/*.test.tsx` |
| Trend math (Δ vs last) | Unit | vitest | `src/lib/control-room/framework/__tests__/delta.test.ts` |
| FT2 history writer (Python) | Pytest, dedup-by-date + monotonic append | pytest | `scripts/__tests__/test_documentation_debt_history.py` |
| FT2 integrity indexer (Python) | Pytest, idempotency on identical input | pytest | `scripts/__tests__/test_index_integrity_snapshots.py` |
| Page route is gated | Already covered by existing `verify-blind-switch.sh` (T11) | bash | n/a |

No e2e for the page — gating is already enforced upstream and the sections are decomposed enough to test in isolation.

## 10. New tasks to append to UCC backlog

**12 new tasks (T43–T54)** get added to `.claude/features/unified-control-center/state.json` `tasks[]` when this design moves to the writing-plans phase. UCC stays in `phase: implementation` — no phase change. T43–T49 cover the trend-chart core; T50–T54 cover the automation-map addition (§16).

**Serial dependency on existing UCC tasks:** T47 + T53 (page composition + automation-map component) require T18 (port `Dashboard.jsx → layout.tsx`) and T19 (port `controlCenterPrimitives → primitives.tsx`) to be done first, since both establish the `/control-room/*` page-shell + design-token foundation. All FT2-side tasks (T43, T44, T46, T50, T51) can run in parallel with T18/T19. Sync extensions (T45, T52) depend on T3 (existing sync infra, shipped).

| ID | Title | Skill | Type | Effort | Lane | Depends |
|---|---|---|---|---|---|---|
| T43 | FT2: `documentation-debt-history.json` writer in `documentation-debt-report.py` | dev | data | 0.25d | E-core | — |
| T44 | FT2: `index-integrity-snapshots.py` script + GHA wiring | dev | data | 0.25d | E-core | — |
| T45 | fitme-story: extend sync for 4 new framework-status JSONs + JSON schemas | dev | infra | 0.5d | P-core | T3 |
| T46 | FT2: Vercel deploy-hook step in both GHAs + `EXTRACTION-RECIPE.md` entry | ops | infra | 0.25d | E-core | T44 |
| T47 | fitme-story: build `/control-room/framework` page core (6 trend/table sections + footer, Recharts) | dev | ui | 1.5d | P-core | T18, T19, T45 |
| T48 | Tests: sync schema, compose, charts (snapshot), Δ math, history writers, indexer | qa | test | 0.5d | E-core | T43, T44, T45, T47 |
| T49 | Analytics: 5 `dashboard_framework_*` events (incl. automation-map click) + 5 rows in `analytics-taxonomy.csv` | analytics | analytics | 0.25d | E-core | T47, T53 |
| T50 | FT2: `scripts/audit-automation.py` → `automation-manifest.json` (static audit of workflows + hooks + Makefile) | dev | data | 0.5d | E-core | — |
| T51 | FT2: `scripts/fetch-recent-runs.py` → `automation-runs.json` (4× `gh run list` calls, sync-time) | dev | data | 0.25d | E-core | T50 |
| T52 | fitme-story: extend sync for 2 automation JSONs + schemas | dev | infra | 0.25d | E-core | T45, T50, T51 |
| T53 | fitme-story: `<AutomationMap>` component (4 grouped subsections, status dots, countdown) | dev | ui | 0.75d | P-core | T18, T19, T52 |
| T54 | Tests: status-semantics fixtures + countdown math + audit-automation snapshot tests | qa | test | 0.25d | E-core | T50, T51, T53 |

**Total effort: ~5.5 days.** (Trend-chart core: 3.5d. Automation-map addition: 2.0d.) Fits within the existing UCC sprint. All new tasks are E-core or P-core; none change the existing critical path (T18 → T20 → T34).

## 11. Analytics events (taxonomy preview)

Per the project-wide analytics naming convention (CLAUDE.md), screen-scoped events get screen-name prefix. The dashboard's existing screen prefix is `dashboard_` (per T1's `dashboard_load`/`dashboard_blocker_acknowledged`). The framework page is a sub-route under it, so events nest:

| Event | When | Params |
|---|---|---|
| `dashboard_framework_view` | Page load | `referrer_path`, `total_tiers_green` |
| `dashboard_framework_tier_click` | User clicks a tier tile | `tier_id`, `tier_status` |
| `dashboard_framework_chart_hover` | User hovers a trend chart point | `chart_id`, `snapshot_date` |
| `dashboard_framework_feature_click` | User clicks a row in adoption table | `feature_id`, `adoption_status` |
| `dashboard_framework_automation_click` | User clicks an automation row in §16 map | `automation_id`, `automation_status` |

Full spec finalized in T49 against `docs/product/analytics-taxonomy.csv`. (5 events total — 4 trend-chart + 1 automation-map.)

## 12. Library additions

- `recharts` — chart library. Pin the latest stable release that supports React 19 (Recharts 3.x at design time, but verify at task time before pinning). ~50KB gzipped. Justified: nothing in fitme-story currently does charts; hand-rolled SVG would duplicate axis/tooltip/responsive logic and add weeks of work.

## 13. Open questions

None. All five brainstorming questions resolved. The remaining decisions (chart-color palette, exact date range default) are visual-design choices best made during T47 against fitme-story's existing tokens — not blocking spec approval.

## 14. Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| Vercel deploy-hook secret leaks in workflow logs | low | use `${{ secrets.* }}`; never `echo` the URL |
| Schema drift between FT2 writers and fitme-story consumers | medium | JSON schemas in T45 + sync-time validation; build fails loudly on drift |
| `documentation-debt-history.json` ledger never accumulates 3 snapshots (no cron writes it) | medium | T43 wires history-write into `documentation-debt-report.py`; weekly cron runs the script Mondays |
| Recharts bundle size grows the dashboard build | low | Recharts is ~50KB gz; bundle budget for `/control-room/*` is internal-only, not a public-perf concern |
| Per-feature table reveals incomplete adoption to viewers who'd see it as "FitMe is broken" | low | Page is behind basic-auth gate (T8); only operator sees it |

## 15. Out of scope (explicit)

These would be valuable but are deferred per scope decision in §3:

- Mechanical-limits panel (5 unclosable-gap tiles with status + issue links).
- Recent-activity strip from `change-log.json`.
- Composite "framework health score" — actively avoided.
- Public `/framework/health` trust-surface variant.
- Historical backfill from git log.

If any of these become urgent, they're additive to this design — no rework required.

## 16. Automation Map — passive/reflection panel (added 2026-04-27)

A display-only inventory of every automated check + cycle in the system, surfaced as a new section on the same `/control-room/framework` page. Renders as the second-to-last section (just above the freshness footer). Fully passive — no triggers, no actions, no live API calls at request time.

### 16.1 Why this exists

The trend charts (§4) answer *"is the framework producing healthy data?"*. They do not answer *"is the framework itself running?"*. A green trend chart with no recent snapshots could mean either "stable system" or "the cron stopped firing 3 weeks ago and we don't know." This section closes that gap by surfacing the cadence + last-run state of every automated mechanism — pre-commit gates, per-PR checks, scheduled cycles, and operator dashboards — so a stalled cycle becomes visible as a red row rather than as a static (but outdated) chart.

### 16.2 Inventory in scope (12 automations)

Cross-referenced from a full audit of `.github/workflows/`, `.githooks/`, and `Makefile` on 2026-04-27:

**A. Pre-commit gates (write-time, 6 checks, all in one hook):**

| ID | Check code | Script | Active iff |
|---|---|---|---|
| pc.1 | `SCHEMA_DRIFT` | `check-state-schema.py` | `make install-hooks` was run |
| pc.2 | `PR_NUMBER_UNRESOLVED` | `check-state-schema.py` | same |
| pc.3 | `PHASE_TRANSITION_NO_LOG` (v7.6) | `check-state-schema.py` | same |
| pc.4 | `PHASE_TRANSITION_NO_TIMING` (v7.6) | `check-state-schema.py` | same |
| pc.5 | `BROKEN_PR_CITATION` (v7.6) | `check-case-study-preflight.py` | same |
| pc.6 | `CASE_STUDY_MISSING_TIER_TAGS` (v7.6) | `check-case-study-preflight.py` | same |

**B. Per-PR gates:**

| ID | Workflow | File | Triggers on |
|---|---|---|---|
| pr.1 | PR Integrity Check | `.github/workflows/pr-integrity-check.yml` | every PR opened/synchronized |
| pr.2 | CI | `.github/workflows/ci.yml` | every PR + push to main + manual |

**C. Scheduled cycles (cron):**

| ID | Workflow | Cron | Cadence |
|---|---|---|---|
| cy.1 | Integrity Cycle | `.github/workflows/integrity-cycle.yml` | `0 4 */3 * *` (every 72h) |
| cy.2 | Framework Status Weekly | `.github/workflows/framework-status-weekly.yml` | `0 5 * * 1` (Mon 05:00 UTC) |

**D. Operator dashboards (no schedule, on-disk JSON timestamps):**

| ID | Make target | Script | Output JSON |
|---|---|---|---|
| op.1 | `make measurement-adoption` | `measurement-adoption-report.py` | `measurement-adoption.json` |
| op.2 | `make documentation-debt` | `documentation-debt-report.py` | `documentation-debt.json` |
| op.3 | `make integrity-snapshot` | `integrity-check.py --snapshot` | `.claude/integrity/snapshots/<ts>.json` |
| op.4 | `make runtime-smoke PROFILE=sign_in_surface` | `runtime-smoke-gate.py` | `runtime-smoke-staging-sign-in-surface.json` |

(Operator targets that produce no JSON — `make tokens-check`, `make ui-audit`, `make schema-check`, `make framework-status`, `make advancement-report`, `make verify-local` composites — are listed in the manifest as "gate-only, no last-run state" and rendered without a timestamp.)

### 16.3 Status semantics

Each row gets a colored status dot computed deterministically from the manifest + last-run data:

| Color | Means | Computed how |
|---|---|---|
| 🟢 Active / on-time | Active and within expected cadence | last_run_age < expected_cadence × 1.0 (cron rows); "enabled" (pre-commit rows); always green for binary "exists" rows |
| 🟡 Stale | Active but overdue | expected_cadence × 1.0 ≤ last_run_age < × 2.0 |
| 🔴 Stalled | >2× overdue, or last result was failure | last_run_age ≥ expected_cadence × 2.0 OR last_run.conclusion == "failure" |
| ⚪ Manual / on-demand | No expected cadence | shows last-run as info only, no color gating |

For pre-commit rows: status is "enabled" iff the FT2 audit script confirms the hook is registered (`git config core.hooksPath` resolves to `.githooks/`). The audit script writes this boolean into the manifest at sync time. There is no "last fired" data because pre-commit hooks don't keep history — only "is it installed" is observable. Documented as a known limit.

### 16.4 Data sources (passive — two new files)

Both written into `.synced/framework-health/` by extending T45 → T52 sync:

**1. `automation-manifest.json`** *(NEW, written by T50 audit script in FT2)*

```jsonc
{
  "version": "1.0",
  "generated_at": "2026-04-27T05:30:00Z",
  "pre_commit": {
    "installed": true,
    "git_hooks_path": ".githooks/",
    "checks": [
      { "id": "pc.1", "code": "SCHEMA_DRIFT", "script": "check-state-schema.py", "v": "7.5" },
      // ... 5 more
    ]
  },
  "workflows": [
    { "id": "pr.1", "name": "PR Integrity Check", "file": ".github/workflows/pr-integrity-check.yml", "trigger": "pull_request", "schedule": null },
    { "id": "cy.1", "name": "Integrity Cycle", "file": ".github/workflows/integrity-cycle.yml", "trigger": "schedule", "schedule": "0 4 */3 * *", "expected_cadence_hours": 72 },
    // ... 2 more
  ],
  "operator_dashboards": [
    { "id": "op.1", "make_target": "measurement-adoption", "output_path": ".claude/shared/measurement-adoption.json" },
    // ... 3 more
  ]
}
```

Generated by `scripts/audit-automation.py` (T50). Pure static parse of `.github/workflows/*.yml` (extract name, on, schedule), `.githooks/pre-commit` (list of check codes from the embedded comment block + the two checker scripts), and a hand-curated list of operator dashboards (the 4 that produce JSON). Recomputed on every sync run.

**2. `automation-runs.json`** *(NEW, written by T51 fetcher in FT2)*

```jsonc
{
  "version": "1.0",
  "generated_at": "2026-04-27T05:30:00Z",
  "runs": [
    { "id": "pr.1", "last_run_at": "2026-04-25T12:38:00Z", "conclusion": "success", "url": "https://github.com/.../actions/runs/12345", "run_number": 87 },
    { "id": "pr.2", "last_run_at": "2026-04-25T12:00:00Z", "conclusion": "success", "url": "...", "run_number": 142 },
    { "id": "cy.1", "last_run_at": "2026-04-20T20:45:00Z", "conclusion": "success", "url": "...", "run_number": 12 },
    { "id": "cy.2", "last_run_at": "2026-04-22T05:00:00Z", "conclusion": "success", "url": "...", "run_number": 7 }
  ]
}
```

Generated by `scripts/fetch-recent-runs.py` (T51). Calls `gh run list --workflow <name> --limit 1 --json conclusion,createdAt,url,number` for each of the 4 workflows. Runs in FT2 context where `gh` is already authenticated. 4 API calls per sync — well under any rate limit. **Operator dashboard rows derive last-run from the existing JSONs we're already syncing** (`measurement-adoption.json.updated`, etc.) — no new fetches needed.

### 16.5 Component decomposition (extends §5)

| Component | Path | Inputs | Output |
|---|---|---|---|
| `<AutomationMap>` | `src/components/control-room/framework/AutomationMap.tsx` | `manifest`, `runs`, `operatorDashboards` | the 4 grouped subsections |
| `<AutomationGroup>` | `.../AutomationGroup.tsx` | `title`, `rows: AutomationRow[]` | grouped section header + row list |
| `<AutomationRow>` | `.../AutomationRow.tsx` | one row: id, label, status, lastRun, nextRun?, runUrl? | dot + label + timestamps + click → external link |
| `<NextRunCountdown>` | `.../NextRunCountdown.tsx` | `cron: string`, `lastRun: Date` | "in 14h ████░" (computed at build with `cron-parser`) |
| `<StatusDot>` | `.../StatusDot.tsx` | `status: 'green' \| 'amber' \| 'red' \| 'manual'` | 8px colored dot, semantic |

`<NextRunCountdown>` uses the `cron-parser` library to compute the next firing time from a cron expression at build time. Tiny library (~10KB); idiomatic for this use case.

### 16.6 Rendering inside `<FrameworkPage>` (extends §7.2)

```tsx
const [adoption, adoptionHistory, debt, debtHistory, integrityHistory, manifest, runs] =
  await Promise.all([
    // ... 5 existing reads
    readJson(path.join(root, 'automation-manifest.json')),
    readJson(path.join(root, 'automation-runs.json')),
  ])

const operatorDashboards = computeOperatorRunStatus({
  manifest: manifest.operator_dashboards,
  jsonTimestamps: { adoption, debt, integrityHistory },
})

return (
  <main>
    <TierScoreboard tiers={tiers} />
    <MeasurementTrendChart history={adoptionHistory.snapshots} />
    <FeatureAdoptionTable current={adoption} />
    <IntegrityTrendChart history={integrityHistory.snapshots} />
    <DocDebtTrendChart history={debtHistory.snapshots} />
    <AutomationMap manifest={manifest} runs={runs} operatorDashboards={operatorDashboards} />
    <FreshnessFooter />
  </main>
)
```

`computeOperatorRunStatus()` derives the operator-dashboard last-run timestamps from the JSON files we're already reading — no extra disk I/O. Lives in `src/lib/control-room/framework/automation.ts`.

### 16.7 Error handling additions (extends §8)

| Failure mode | Behavior |
|---|---|
| `automation-manifest.json` missing | Section renders as `<EmptyState reason="audit script hasn't run yet" />`. Other sections unaffected. |
| `automation-runs.json` missing or stale | Per-PR + cycle rows render with "(no run data)" instead of timestamp. Pre-commit + operator rows still show. |
| `gh run list` rate-limited at sync time | T51 logs warning, exits 0, leaves the previous `automation-runs.json` in place. Sync still succeeds. Freshness shows staleness. |
| `cron-parser` can't parse a cron expression (typo in workflow) | Row renders without a countdown; status falls back to "manual" treatment. T54 includes a parser-fixture test. |
| Pre-commit hook isn't installed on the dev box | Manifest shows `installed: false`; all 6 pre-commit rows render with red dots and "not installed (run `make install-hooks`)" hint. |

### 16.8 Testing additions (extends §9)

| Layer | Test type | Tool | Path |
|---|---|---|---|
| `audit-automation.py` static parse | Pytest, fixtures for sample workflow + hook + Makefile | pytest | `scripts/__tests__/test_audit_automation.py` |
| `fetch-recent-runs.py` | Pytest, mock `gh run list` output | pytest | `scripts/__tests__/test_fetch_recent_runs.py` |
| Status semantics | Unit, deterministic input → expected color | vitest | `src/lib/control-room/framework/__tests__/automation-status.test.ts` |
| Cron countdown math | Unit, fixture cron + lastRun → expected nextRun | vitest | `.../__tests__/countdown.test.ts` |
| `<AutomationMap>` snapshot | RTL snapshot test, 3 fixtures (all green / mixed / all red) | vitest + RTL | `src/components/.../__tests__/AutomationMap.test.tsx` |

### 16.9 Out of scope for §16 (explicit)

- **Live status (no polling, no SSR fetch)** — the page is fully build-time static. If a workflow status changes between syncs, the dashboard won't reflect it until the next sync. This is intentional; matches the architecture decision in §4 (no Cache Components, no runtime fetch).
- **Pre-commit firing history** — git pre-commit hooks don't keep history. We can only show "installed" / "not installed". Adding a logger to the hook (e.g., write each fire to `.claude/logs/pre-commit-fires.json`) is feasible but out of scope here — would be a separate enhancement to the hook script itself, not the dashboard.
- **Editing automation from the dashboard** — strictly display-only. No "trigger workflow" buttons, no "run cron now" actions. Reflection mode by definition.
- **Webhook-driven live updates** — would require a webhook receiver in fitme-story + secret management. Not justified at this scale.
- **Per-pre-commit-check fire counts** — would need an instrumented hook (see above bullet); out of scope for the visualization work.

### 16.10 Library additions (extends §12)

- `cron-parser` — pin latest stable, ~10KB, used at build time only inside `<NextRunCountdown>` to convert cron expressions to next firing dates. Pure JS, no runtime deps. Justified: writing cron arithmetic by hand is bug-prone (DST, leap seconds, day-of-week semantics) and `cron-parser` has been the standard JS implementation for ~10 years.

### 16.11 Risk additions (extends §14)

| Risk | Likelihood | Mitigation |
|---|---|---|
| Audit script falls out of sync with reality (e.g., new workflow added to FT2 but T50 doesn't pick it up) | medium | Audit script parses `.github/workflows/*.yml` directory listing — additive workflows surface automatically. Hard-coded operator-dashboard list is the only manual-update vector; documented in the script header. |
| `gh` auth missing in FT2 GHA context where T51 runs | low | T51 runs in CI workflows that already use `gh` (integrity-cycle, framework-status-weekly). Same `${{ secrets.GITHUB_TOKEN }}` available. |
| Operator confused by "🔴 Stalled" on a cycle that's expected to be paused | low | Cycle rows include a "paused" boolean derived from workflow file (`on.schedule` removed or commented out) that overrides the red dot to ⚪ "manual". |
