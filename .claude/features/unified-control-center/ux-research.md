# UX Research — unified-control-center

**Phase:** 3 (UX) — Step 1 of dispatch chain (`/ux research`)
**Status:** Draft as part of Phase 3 awaiting user approval
**Author:** Claude Opus 4.7
**Started:** 2026-04-26T10:30:00Z

---

## Context

The unified-control-center is an internal operator dashboard rendered as `/control-room/*` routes inside the public fitme-story Next.js site, gated by a 3-layer blind-switch. **Single user (Regev)** is the only operator. Daily workflow: log in → load `/control-room` → identify next blocker or shipping decision → act. Target: Time-to-Confidence (TTC) ≤6s p50 (PRD §5.1).

This document identifies the UX principles that govern the design.

---

## 1. Applicable UX principles

### 1.1 Hick's Law — minimize choices per screen

The dashboard surfaces dozens of features × 9 phases × 3+ external systems. Without ruthless filtering, every load is cognitive overload.

**Application:**
- `/control-room` overview shows ONLY: hero, 6 KPIs, alerts, current-phase summary, source health. NOT every feature card.
- Detail views (`/board`, `/table`, `/knowledge`) are explicit drill-downs the operator opens deliberately.
- Filters in TableView default to "show only active" — past data hidden until requested.
- Command palette (Cmd+K) hides 90%+ of actions until the operator types a query — radical Hick's Law application.

### 1.2 Recognition over recall

The operator should never have to remember a phase name, a Linear issue ID, or a feature slug. Everything visible.

**Application:**
- Phase badges colored per fitme-story `--skill-{name}` palette — operator recognizes "blue = implement" by color, not by reading.
- KPI cards use icons + numbers + label — operator scans icons first (recognition), reads labels only on uncertainty.
- Command palette autocomplete shows recent commands first — recognition memory dominant over typed recall.

### 1.3 Progressive disclosure

A single operator does not need every metric every load. Surface 6 KPIs; hide 30 supporting metrics behind drill-downs.

**Application:**
- Overview: 6 hand-picked KPIs (framework version, integrity findings, features in flight, last sync age, alerts count, weekly velocity)
- Drill-downs: clicking a KPI opens a detail panel with the full underlying data
- KnowledgeHub: collapsed by group; operator expands what's relevant
- Disclosure pattern from fitme-story (`Disclosure.tsx`) used for any optional context

### 1.4 Feedback (every action gets a response)

Operator drags a card across columns, types in command palette, toggles dark mode — every action confirms.

**Application:**
- KanbanBoard: card visibly snaps to the new column with motion preset (~150ms ease-out)
- Command palette: typing shows live filter; pressing Enter shows ghost confirmation before navigation
- Filter changes in TableView: row count updates with subtle counter animation
- Dark mode toggle: smooth color transition (motion preset, ≤200ms)

### 1.5 Consistency (internal — match fitme-story; external — match operator's mental model)

Internal: same Hero, NumbersPanel, Disclosure components as showcase. Same `--measure-body`, same neutrals.
External: operator uses Linear daily — Cmd+K command palette matches Linear's pattern (search-as-you-type, recents at top, ↑/↓ navigation, Enter to execute, Esc to close).

### 1.6 Error prevention

Operator should not accidentally drag a feature into an invalid phase or click "decommission Astro dashboard" without confirmation.

**Application:**
- KanbanBoard validates phase transitions: dropping `prd` directly onto `merge` is rejected with a tooltip explaining why
- Destructive actions (decommission, force-resync) require Cmd+Enter confirmation, not single click
- Stale-data warning is yellow-warning, not red-error — distinguishes "info" from "blocker"

### 1.7 Fitts's Law — target size and distance

Mouse-driven dashboard. Tap targets minimum 32px (mouse equivalent of mobile 44pt).

**Application:**
- KPI cards are 200×120px, click anywhere to drill down
- KanbanBoard cards full-width clickable, minimum 64px tall
- Command palette hit zone large + always reachable (Cmd+K shortcut from any view)

---

## 2. iOS HIG / Web equivalents

While the dashboard is web (no iOS HIG strictly), Apple's HIG has cross-platform principles worth importing:

- **Modal patterns:** Drill-downs use side panels (slide-in from right) like iOS context menus, not full-page modals — preserves user's place
- **Feedback:** Use opacity + scale + color transitions, not flash/blink
- **Empty states:** Every list/table has a friendly empty state ("No active features in this phase") with the next-best action (e.g., "Create one")
- **Loading states:** Skeleton placeholders match the layout shape, not generic spinners

---

## 3. UX best practices for the feature type (internal PM dashboards)

Researched patterns from Linear, Vercel, GitHub Projects, Plane.io, and shadcn dashboard examples:

### 3.1 Keep the chrome thin

Linear: top bar is ~40px, sidebar ~180px. **Total chrome ≤220px** so content area is ≥80% of viewport.

**Application:** fitme-story's existing SiteHeader (~64px) + a new minimal control-room sub-nav (~40px tabs). NO sidebar in control-room — view switching via top tabs + Cmd+K.

### 3.2 Same data, multiple views

GitHub Projects + Linear both pioneered the "table view + board view + roadmap view" pattern. Operators want flexibility; views must be pluggable.

**Application:** Control-room offers 4 views over the same feature data:
- `/control-room` — narrative overview (Hero + KPIs + alerts)
- `/control-room/board` — Kanban
- `/control-room/table` — TanStack Table
- `/control-room/knowledge` — Documentation index

Switch via top tabs OR Cmd+K → "switch view".

### 3.3 Color = information

Linear assigns each issue priority/status a color. The operator scans color before reading text. fitme-story's `--skill-{name}` palette gives us 9 distinct colors mapped to skills/phases.

**Application:** mapping table (locked in design compliance gateway below):

| Phase | fitme-story token | Hex (light) | Hex (dark) |
|---|---|---|---|
| backlog | `--color-neutral-500` | #78716C | #A8A29E |
| research | `--skill-research` | (TBD - read from globals.css) | (TBD) |
| prd | `--skill-pm-workflow` | (TBD) | (TBD) |
| tasks | `--skill-pm-workflow` (lighter) | (TBD) | (TBD) |
| ux/integration | `--skill-ux` or `--skill-design` | (TBD) | (TBD) |
| implement | `--skill-dev` | (TBD) | (TBD) |
| testing | `--skill-qa` | (TBD) | (TBD) |
| review | `--skill-design` | (TBD) | (TBD) |
| merge | `--skill-release` | (TBD) | (TBD) |
| docs | `--skill-marketing` (or neutral-700) | (TBD) | (TBD) |
| done/complete | `--color-brand-indigo` (achievement) | #4F46E5 | #818CF8 |

Resolution: this table will be locked at T15 (mapping table task). All entries become T1 instrumented post-implementation.

### 3.4 Keyboard-first

Linear's superpower: every action has a keyboard shortcut. Cmd+K command palette is the universal entry point.

**Application:** Cmd+K palette (T30.5) commands at v1:
- "Switch to overview/board/table/knowledge" (`g o`, `g b`, `g t`, `g k`)
- "Filter by phase: {phase}"
- "Filter by skill: {skill}"
- "Show alerts only"
- "Show stale data sources"
- "Open feature: {fuzzy-search}"
- "Open Linear issue: {fuzzy-search}"
- "Toggle dark mode" (`Cmd+Shift+L`)
- "Reset filters" (`?reset=true` URL param OR `Cmd+Shift+R`)

### 3.5 Persistent state where it matters

Linear remembers your filter + view per workspace. Per Q3=A, we use localStorage for `control-room:view` + `control-room:filters`.

---

## 4. External UX research sources

| Source | Lesson |
|---|---|
| [Linear's "How we built our command palette" engineering post](https://linear.app/blog/command-palette) | Recents at top + fuzzy search + ↑/↓ Enter Esc — operator never breaks flow |
| Vercel Dashboard observed Mar 2026 | Card-based density; status pills are the reading anchor; minimal nav chrome |
| GitHub Projects (Beta) | Multiple views over same data is the right primitive; custom fields scale |
| [shadcn/ui dashboard examples](https://ui.shadcn.com/examples/dashboard) | Sidebar + topbar + main grid is overkill for single-operator; we drop the sidebar |
| [NN/g — Dashboard Design](https://www.nngroup.com/articles/dashboards-preattentive/) | Pre-attentive attributes (color, position, size) carry meaning faster than text — drives our color-as-information rule |

---

## 5. Recommended patterns (summary)

| Pattern | Source | Application |
|---|---|---|
| Hero + NumbersPanel | fitme-story (verbatim) | `/control-room` overview lead |
| Tab nav (no sidebar) | Linear, GitHub Projects | Top-of-content view switcher |
| Cmd+K command palette | Linear | Global keyboard navigation |
| Disclosure | fitme-story | Progressive disclosure of optional context |
| MetricsCard | fitme-story | Each KPI rendered as MetricsCard |
| Status pills (color-as-info) | Linear, Vercel | Phase + priority + skill badges everywhere |
| Skeleton loaders | iOS HIG / Linear | Match layout shape, never spinner |
| Side-panel drill-down | iOS context menu | Click KPI → side panel slides from right |
| Live filter counter | TanStack Table | Subtle row count animation on filter change |
| Validated drag (KanbanBoard) | Linear | Reject invalid phase transitions with tooltip |

---

**Approval gate:** UX research is the foundation for the spec. The spec (next file: `ux-spec.md`) cites this doc for every principle it applies.
