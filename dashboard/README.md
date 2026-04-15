# FitMe Operations Control Room

Internal PM dashboard and canonical live web surface at [fit-tracker2.vercel.app](https://fit-tracker2.vercel.app).

## Stack

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
