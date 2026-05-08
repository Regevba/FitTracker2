# FitMe Operations Control Room

> ## ⚠️ HISTORICAL — superseded by fitme-story `/control-room/*`
>
> This Astro dashboard is the **legacy implementation** of the operator control room. As of the UCC migration (Wave 2 shipped 2026-05-05), the canonical live surface is the Next.js port at `fitme-story.vercel.app/control-room/*`, with code under [`fitme-story/src/{app,components,lib}/control-room/`](https://github.com/Regevba/fitme-story/tree/main/src/components/control-room).
>
> **Don't ship new features here.** All dashboard work goes to fitme-story. This directory remains in the repo as a reviewable git-history reference until the UCC retention review (≥30 days post-launch — see PRD §13 rollback plan).
>
> **Migration provenance:**
> - Feature: [`unified-control-center`](../.claude/features/unified-control-center/) (`current_phase: implementation` → `complete` after Block H + T42)
> - PRD: [`prd.md`](../.claude/features/unified-control-center/prd.md) — see §13 (rollback) for the conditions under which this directory could be re-promoted to active
> - Token map (Astro → fitme-story): [`token-map.md`](../.claude/features/unified-control-center/token-map.md)
> - Extraction recipe (if dashboard ever needs to leave fitme-story): [`fitme-story/EXTRACTION-RECIPE.md`](https://github.com/Regevba/fitme-story/blob/main/EXTRACTION-RECIPE.md)
>
> **Retention policy** (matches the V2 Rule's HISTORICAL retention codified 2026-05-08): retained indefinitely by default. The first scheduled review point for any prune policy is the UCC anniversary or the post-launch decommission decision specified in PRD §13. Until then, this directory stays in the repo as on-disk reviewable reference.
>
> **Live URL retired:** the original `fit-tracker2.vercel.app` host redirects to `fitme-story.vercel.app/control-room` after T35 ships (per [state.json](../.claude/features/unified-control-center/state.json) Block G).

---

## (Historical context follows)

Internal PM dashboard, originally hosted at [fit-tracker2.vercel.app](https://fit-tracker2.vercel.app) prior to the UCC migration.

## Stack (legacy)

- **Framework:** Astro 6 + React 19
- **Styling:** Tailwind CSS v4
- **Hosting:** Vercel (static output)
- **Analytics:** Vercel Web Analytics + Speed Insights

## Features

- **Control Room** — Delivery pipeline, source health, framework pulse, case study monitoring
- **Board** — Kanban view with drag-drop across phases
- **Table** — Sortable/filterable feature list
- **Tasks** — Skill-based swim lanes from PM workflow state files
- **Knowledge Hub** — Repo docs, shared state, external references, case studies
- **Research Consoles** — Claude + Codex research workspaces with prompt starters
- **Figma Handoff Lab** — Design review and handoff staging

## Data Sources

The dashboard reads from multiple sources at build time:

| Source | File | Mode |
|---|---|---|
| Feature registry | `.claude/shared/feature-registry.json` | Shared layer |
| Task queue | `.claude/shared/task-queue.json` | Shared layer |
| Framework manifest | `.claude/shared/framework-manifest.json` | Shared layer |
| External sync | `.claude/shared/external-sync-status.json` | Shared layer |
| Case study monitoring | `.claude/shared/case-study-monitoring.json` | Shared layer |
| Static features | `src/data/features.json` | Repo fallback |
| Static case studies | `src/data/caseStudies.json` | Repo fallback |
| PM state files | `.claude/features/*/state.json` | Repo fallback |
| GitHub issues | GitHub API (requires `GITHUB_TOKEN`) | Live (optional) |
| Repo docs | `docs/**/*.md` | Repo fallback |

## Development

```bash
npm install
npm run dev      # Start dev server
npm test         # Run 35 tests (vitest)
npm run build    # Production build
```

## Tests

35 tests across 5 suites:

- `control-center-builders.test.js` — Data pipeline builders
- `dashboard-nav.test.jsx` — Tab navigation and workspace routing
- `reconcile.test.js` — Cross-source reconciliation engine
- `case-studies.test.js` — Case study feed builder
- `parsers.test.js` — State file parsers
