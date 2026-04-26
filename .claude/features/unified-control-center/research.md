# Research — unified-control-center

**Phase:** 0 (Research)
**Started:** 2026-04-26T05:30:00Z
**Status:** awaiting user approval to advance to Phase 1 (PRD)
**Framework version:** v7.6 (Mechanical Enforcement)
**Author:** Claude Opus 4.7 (with Explore subagent)

---

## 1. What is this solution?

Migrate the FitTracker2 dashboard (currently at `/Volumes/DevSSD/FitTracker2/dashboard/`, Astro 6 + React 19, deployed to https://fit-tracker2.vercel.app) into the fitme-story showcase site (`/Volumes/DevSSD/fitme-story/`, Next.js 16). Share design tokens and select components between dashboard surfaces and showcase narrative pages so the operator (Regev) and any external reader see ONE cohesive product family — not two visually unrelated sites.

The dashboard's data layer (read-time access to `.claude/shared/*.json` and `.claude/features/*/state.json`) must be preserved end-to-end across the repo boundary.

## 2. Why this approach?

**Pain points addressed:**

| Pain | Today | After |
|---|---|---|
| Two visual identities (Astro dashboard vs Next.js showcase) | Same operator switches between two designs | One design system, immediate cohesion |
| Two separate Vercel projects | Two URLs, two deploys, two env-var sets | One URL, one deploy |
| Dashboard accumulated noise across sessions (17 React components, some over-engineered for a one-operator dashboard) | All preserved without curation | Drop low-signal panels, redesign with fitme-story patterns |
| Showcase narrative + live framework data are disconnected | Reader cannot see live state from a case study | Embed live `MetricsCard` / `Timeline` reading the same data on both surfaces |
| Design tokens duplicated and out of sync | Dashboard has its own `brand: { primary: #FA8F40 }`; showcase has `--color-brand-indigo: #4F46E5` | One token source of truth |

## 3. Why this over alternatives?

Per the user's brainstorm pick (Option C — full unification), the agent evaluated 3 concrete migration architectures.

| Approach | Pros | Cons | Effort | Chosen? |
|---|---|---|---|---|
| **Arch A — Dashboard as Route in fitme-story** (`fitme-story/src/app/control-room/page.tsx`, pre-build sync script for FitTracker2 data) | Single codebase + single Vercel project + design system inherited by default + can lift KanbanBoard/MetricsCard into shared components incrementally + Vercel-native | Requires sync script to be reliable on Vercel; FitTracker2 stops being a standalone dashboard project | 5–7 weeks | ✅ **CHOSEN** |
| Arch B — Sibling Next.js, shared design tokens via npm workspace or git submodule | FitTracker2 stays independent; clear ownership | Two Vercel projects + monorepo overhead OR submodule pain; design-token sync is manual; no shared component library | 4–6 weeks | ✗ |
| Arch C — Monorepo with `fitme-story/apps/dashboard/` + vendored components via build script or path aliases | Best long-term for shared component libraries (turbo/nx) | Monorepo tooling complexity; build pipeline coupling; if showcase build breaks, dashboard cascades | 7–10 weeks | ✗ |

**Why Arch A wins:** lowest maintainability debt for our scale (one operator, one engineer). No monorepo overhead, no submodule pain. The pre-build sync script (Pattern 4.b below) is an explicit, repeatable contract — not a hidden coupling. We can lift dashboard components into `fitme-story/src/components/shared/` incrementally as the case for sharing each one becomes obvious.

## 4. External sources + market examples

### Internal/dev dashboard precedents (well-designed)

- **Vercel Dashboard** (vercel.com/dashboard) — clean card-based layout for projects + deployments, real-time green/yellow/red status, minimal chrome. *Lesson: information hierarchy matters more than feature count.*
- **Linear.app workspace view** — table + board + sprint views over the same data, filter/search bar always visible, inline quick actions. *Lesson: multiple views on same data reduce context-switching for power users.*
- **GitHub Projects (Beta)** — kanban + table + roadmap views, custom fields, label/assignee/status filters. *Lesson: operators want pluggable views, not a single fixed layout.*

### Cross-repo design-token sharing patterns

- **shadcn/ui** — copy-paste components per project, customize locally; not a monorepo. *Lesson: works for small teams; doesn't scale for tight sync. Doesn't fit our use case (we want sync, not divergence).*
- **Vercel's internal `@vercel/geist`** — npm workspace + monorepo, both consumed by Vercel dashboard, marketing site, docs. *Lesson: gold standard, but requires monorepo tooling — overkill for two-surface project.*

### Cautionary tale

- **Lyft's dashboard rebuild (2018-2020)** — rebuilt in React from Ember, lost real-time sync with the data layer, broke critical operator workflows. *Lesson: never rip-and-replace; migrate incrementally, preserve data flow contracts. The dashboard MUST keep working through every step of the migration.*

## 5. Design references (Phase 0 visual research)

The fitme-story design system gives us a strong starting palette and pattern library. From `globals.css`:

- **Brand:** `--color-brand-indigo: #4F46E5` (primary CTAs), `--color-brand-coral: #F97066` (warnings/alerts)
- **Skill palette (9 colors):** `--skill-{pm-workflow,research,ux,design,dev,qa,analytics,marketing,release}` — natural fit for v7.6's per-phase color coding (replaces dashboard's existing `status.{phase}` palette which is duplicated 1:1 in concept but uses different hex values)
- **Neutrals:** warm grayscale `--color-neutral-{50→900}`, dark-mode aware
- **Editorial typography:** `--measure-{narrow,body,wide}` (58/65/72ch) + clamped display sizes
- **Existing components ready to lift or pattern-match:** `Hero`, `NumbersPanel`, `Timeline`, `MetricsCard`, `FindingsTable`, `Pullquote`, `Disclosure`, `BlueprintOverlay`, `LegoWall`, `LifecycleLoop`

Visual mood for the new control center: editorial + restrained. Less "dev tool" (no neon, no over-decoration), more "ops console for an AI-orchestrated framework." Information hierarchy first, decoration second.

## 6. Data & demand signals

This rebuild is justified by:

- **One operator** (Regev) uses both surfaces daily → cohesion has direct UX value
- **17 dashboard components** built incrementally over many sessions → there is documented over-engineering (Codex's 2026-04-19 SSD audit flagged some of this; user just spent a session asking for "true, useful, effective" data which means CURATION is needed, not preservation)
- **Recently shipped framework v7.6** added new surfaces (`/framework/dev-guide`, trust page §11 audit response, case study slot 21) — the dashboard's role of surfacing PM state needs to evolve to also link to those narratives
- **Linear and Notion MCPs are now wired** in this session (live read/write) — the dashboard can now show real Linear/Notion sync status as a first-class signal
- **The 4-source truth** (GitHub repo, Linear, Notion, Vercel) is now stable and reflected in `external-sync-status.json` v7.6 schema — there is a clean data layer to render against

## 7. Technical feasibility — the data-loading constraint

The hardest constraint is that dashboard data lives in FitTracker2 but the new dashboard renders inside fitme-story (a different git repo). Vercel only clones one repo per project.

Four data-loading patterns evaluated:

| Pattern | Verdict |
|---|---|
| 4.a Relative filesystem read at build (`../../FitTracker2/.claude/...`) | ❌ Breaks on Vercel; works only locally |
| **4.b Pre-build sync script** copies `.claude/shared/*.json` + per-feature state into `fitme-story/src/data/shared/` before `next build` | ✅ **CHOSEN** — explicit, self-contained, works on Vercel via build-command hook |
| 4.c GitHub API + CDN — store snapshots in GH releases, fetch at build | ❌ Over-engineered |
| 4.d Environment variables — pass JSON as `process.env.DASHBOARD_DATA` | ❌ 32KB env size limit; bad DX for 11+ files |

### Pattern 4.b sketch (recommended)

```typescript
// fitme-story/scripts/sync-from-fittracker2.ts
import { copySync, readdirSync, existsSync } from 'fs-extra';
import { resolve } from 'path';

const FT2_SHARED = resolve(__dirname, '../../FitTracker2/.claude/shared');
const FT2_FEATURES = resolve(__dirname, '../../FitTracker2/.claude/features');
const LOCAL = resolve(__dirname, '../src/data/shared');

for (const file of readdirSync(FT2_SHARED)) {
  if (file.endsWith('.json')) {
    copySync(resolve(FT2_SHARED, file), resolve(LOCAL, file));
  }
}
for (const feature of readdirSync(FT2_FEATURES)) {
  const state = resolve(FT2_FEATURES, feature, 'state.json');
  if (existsSync(state)) {
    copySync(state, resolve(LOCAL, 'features', `${feature}.json`));
  }
}
```

```json
// fitme-story/package.json
"scripts": {
  "prebuild": "tsx scripts/sync-from-fittracker2.ts",
  "build": "next build"
}
```

**On Vercel** the build pipeline will need to clone FitTracker2 first. Two options:
- **Option 1:** Vercel monorepo setup with both repos under one root `package.json` → npm workspace handles it
- **Option 2 (preferred for v1):** custom `vercel.json` build command that clones FitTracker2 from a git URL with read-only deploy key, runs sync, then `next build`

The sync script also writes a `freshness.json` with sync timestamp — the dashboard footer will surface it so stale-data scenarios are visible to the operator.

## 8. What to drop, keep, redesign (curation pass)

From the agent's component-by-component analysis:

| Verdict | Components |
|---|---|
| **Keep** (8) | Dashboard.jsx (root), ControlRoom.jsx, KanbanBoard.jsx, TableView.jsx, KnowledgeHub.jsx, AlertsBanner.jsx, SourceHealth.jsx, FeatureCard.jsx + TaskCard.jsx + ThemeToggle.jsx + controlCenterPrimitives.jsx |
| **Redesign** (5) | TaskBoard (flatten into TaskCard grid; redundant w/ Kanban), PipelineOverview (low-value timeline; replace with simple legend), CaseStudiesView (integrate into fitme-story `/case-studies` instead of duplicating), DependencyGraph (too complex; replace with task-tree view) |
| **Drop** (2) | ResearchConsole (Claude/Codex research — low signal for operator), FigmaHandoffLab (belongs in design tool, not dashboard) |

**Load-bearing data flows that MUST survive:**
1. Feature-state aggregation (`state.js → controlCenter.js → ControlRoom.jsx`)
2. Task dependency parsing + drag-drop state (`tasks.js → KanbanBoard.jsx`)
3. GitHub issue sync (`github.js → unified.js`)
4. Documentation grouping (`controlCenter.js DOC_GROUP_META → KnowledgeHub.jsx`)
5. **NEW (post-v7.6):** Linear MCP sync state + Notion MCP sync state + change-log timeline + 5 Class B gaps + measurement-adoption + integrity findings

## 9. Proposed success metrics (draft for Phase 1 PRD)

| | Value | Tier |
|---|---|---|
| **Primary metric** | **Time-to-Confidence (TTC)** — seconds from dashboard load to operator identifying the next high-priority blocker or bottleneck | T2 (Declared) |
| Baseline (current Astro) | ~8s (load + scan ControlRoom + read alerts + scan critical features) | T2 (Declared, observed estimate) |
| Target | ≤6s (Next.js + edge cache + curated layout) | T2 (Declared) |
| Kill criteria | >15s sustained (= regression; data-load lag or UX friction) | T2 (Declared) |

| Secondary metrics | Target |
|---|---|
| Data freshness | Age of newest sync ≤2h; alert if ≥6h |
| Feature-state accuracy | ≥98% match between dashboard display vs ground truth (state.json + GitHub + Linear) |
| Knowledge Hub bounce rate | <20% (high bounce = content gaps) |
| Dark-mode parity | All components pass WCAG AA on dark backgrounds (4.5:1 contrast) |

| Guardrail metrics | Threshold |
|---|---|
| Vercel build time | Must not exceed current fitme-story build by >30s |
| Dashboard JS bundle | Must not exceed 250KB gzipped on initial paint |
| Sync script runtime | Must complete in <5s locally, <20s on Vercel |

## 10. Top 5 technical risks + mitigations

| Risk | Impact | Likelihood | Mitigation |
|---|---|---|---|
| Data sync fails silently on Vercel | Dashboard shows stale data; operator could ship wrong feature | HIGH | Pre-build sync script + monitoring + freshness.json + alert in dashboard if data >6h old; fallback to last successful copy |
| Component port regression (KanbanBoard or ControlRoom breaks during Astro→Next port) | Operator workflows blocked | MEDIUM | Comprehensive tests before migration; parallel-run old + new for 1 sprint; feature flag for risky components |
| Design token mismatch (dashboard inherits fitme-story tokens, contrast fails on dark) | WCAG A11y failure | MEDIUM | Pre-migration token audit (all colors on all backgrounds); automated contrast check in CI; manual review of critical workflows |
| Vercel build-time bloat | Build time spikes 50%+ | MEDIUM | Remove old Astro dashboard early; optimize build cache; split projects temporarily if needed |
| FitTracker2 git clone latency on Vercel | Build minutes balloon | LOW | Shallow clone (`--depth 1`) of FitTracker2; cache `.claude/` between builds; skip clone if data hasn't changed |

## 11. Decision (recommendation)

**Architecture:** Arch A — Dashboard as a route inside fitme-story
**Data pattern:** Pattern 4.b — Pre-build sync script copies FitTracker2 `.claude/shared/*.json` + per-feature `state.json` into `fitme-story/src/data/shared/` before `next build`
**Design tokens:** Direct inheritance of fitme-story `globals.css` tokens; dashboard's existing brand palette (`#FA8F40` orange, etc.) is dropped in favor of `--color-brand-indigo` + skill palette
**Component strategy:** Keep 8, redesign 5, drop 2 (per §8)
**Effort:** 5–7 weeks (~7 phases of PM workflow)

### Phase 1 PRD verification checklist

The PRD must explicitly answer / commit to these before approval:

- [ ] Sync script (Pattern 4.b) sketched + JSON schema validation post-sync
- [ ] Vercel build configuration: how does FitTracker2 get cloned? (deploy key vs monorepo vs build-step git clone)
- [ ] Design-token mapping table: dashboard `status.{phase}` → fitme-story `--skill-{name}` for all 10 phases
- [ ] All dashboard colors pass WCAG AA on dark mode
- [ ] ControlRoom + KanbanBoard render without console errors under React 19 strict mode
- [ ] Data freshness age visible in dashboard footer
- [ ] Time-to-Confidence baseline measured on current Astro dashboard before migration starts (so we have a real T1 number, not a T2 estimate)
- [ ] Kill criteria: rollback plan if TTC regresses

### What this case study will measure (since case study is tracked from day one)

Per CLAUDE.md and the v7.6 framework rules, every feature now has a case study from inception. This one's hook will be:

> **"How do you migrate a dashboard between two stacks (Astro → Next.js) AND across two repos (FitTracker2 → fitme-story) without losing the data contract that makes it useful?"**

The case study will report against the PRD metrics + document the actual cross-repo data-loading pattern that worked + cite the v7.6 framework's Class B gap inventory (one of which — the "true useful effective dashboard" — is partially addressed by this rebuild).

---

## Sources

- Explore subagent research output (2026-04-26, ~1900 words, 98% completeness, source-audit of both repos)
- `dashboard/package.json`, `dashboard/src/components/*` (current dashboard inventory)
- `fitme-story/src/app/globals.css` (design tokens)
- `fitme-story/src/components/**/*.tsx` (existing components inventory)
- `fitme-story/src/lib/content.ts` (filesystem-based data loader pattern)
- `.claude/shared/external-sync-status.json` (post-v7.6 sync schema)
- v7.6 case study (`docs/case-studies/mechanical-enforcement-v7-6-case-study.md`) §10 Outlier Limitations + §11 CU/workload analysis (precedent for explicit-tier reporting in this rebuild's case study)

## Approval gate

User must explicitly approve this Research deliverable before Phase 1 (PRD) opens. On approval, the framework will:
1. Set `phases.research.status = "approved"` + `phases.research.ended_at`
2. Auto-emit `phase_approved` event to `.claude/logs/unified-control-center.log.json`
3. Set `current_phase = "prd"` + `phases.prd.status = "in_progress"` + `phases.prd.started_at`
4. Compute and write `phases.research.duration_minutes`
5. Open the Phase 1 PRD draft per the v7.6 mandatory PRD sections (primary metric, baseline, target, kill criteria, secondary, guardrails — all T1/T2/T3 tagged per data-quality convention)
