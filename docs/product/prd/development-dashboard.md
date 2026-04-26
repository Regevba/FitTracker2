# PRD: Development Dashboard

> **ID:** Dashboard | **Status:** Shipped | **Priority:** HIGH
> **Last Updated:** 2026-04-04 | **Branch:** feature/development-dashboard (merged to main)

---

## Purpose

Custom web-based development dashboard that tracks all FitMe features across the PM lifecycle — providing a real-time view of feature status, priority, and health across multiple data sources.

## Business Objective

Replace manual tracking (markdown files, GitHub issues) with a unified dashboard that auto-syncs from state.json, GitHub Issues, and markdown docs. Reduces context-switching and makes the PM workflow visible.

## What Was Built

### Views
| View | Description |
|------|-------------|
| KanbanBoard | 8-column board (Research → PRD → Tasks → UX → Implement → Test → Review → Done) with drag-drop via dnd-kit |
| TableView | @tanstack/react-table with sorting, filtering, search across all features |
| PipelineOverview | Stacked bar chart showing feature distribution across phases |
| AlertsBanner | Reconciliation alerts (state.json vs GitHub discrepancies) |
| SourceHealth | Per-source health indicators (markdown, state.json, GitHub) |

### Tech Stack
- **Astro** (static site generator) + **React** (interactive components)
- **Tailwind v4** with FitMe brand tokens
- **dnd-kit** for drag-drop kanban
- **@tanstack/react-table** for table view
- **Vercel** deployment

### Data Sources
- 6 markdown parsers (backlog, roadmap, PRD, metrics, state, unified)
- GitHub API client for issue sync
- Reconciliation engine (detects drift between sources)
- 37 features tracked (11 shipped, 11 planned, 15 backlog)

### Key Features
- Dark mode toggle (localStorage + system preference)
- Responsive layout (desktop/tablet/mobile)
- Drag-drop with undo toast
- Source-aware feature cards (shows data origin)
- Alert severity levels (critical, warning, info)
- Server-only guard on GitHub API client

## Key Files
| File | Purpose |
|------|---------|
| `dashboard/src/pages/index.astro` | Main page |
| `dashboard/src/components/KanbanBoard.tsx` | Drag-drop kanban |
| `dashboard/src/components/TableView.tsx` | Sortable/filterable table |
| `dashboard/src/components/PipelineOverview.tsx` | Bar chart |
| `dashboard/src/lib/parsers/` | 6 markdown parsers |
| `dashboard/src/lib/github.js` | GitHub API client |
| `dashboard/src/lib/reconciliation.js` | Data source reconciliation |

## Success Metrics

| Metric | Baseline | Target | Status |
|--------|----------|--------|--------|
| All features tracked | 0 (no instrumentation existed before) (T2 — Declared, 2026-04-26) | 37/37 (T2 — Declared) | Shipped |
| Data source reconciliation | N/A — pre-launch (T2 — Declared, 2026-04-26) | Working (T2 — Declared) | Shipped |
| Responsive layout | N/A — pre-launch (T2 — Declared, 2026-04-26) | 3 breakpoints (T2 — Declared) | Shipped |
| 9 reconciliation tests | 0/9 (T2 — Declared, 2026-04-26) | 9/9 pass (T2 — Declared) | Shipped |
| Kill criteria | Dashboard usage <1 visit/week by the maintainer for 30 days OR data source reconciliation drift >25% sustained 30 days OR build broken >7 days → dashboard is considered failed and the feature-status surface is folded back into local CLI commands (T2 — Declared, 2026-04-26) | — | Vercel analytics + reconciliation engine logs |
