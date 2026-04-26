# UX Spec — unified-control-center

**Phase:** 3 (UX) — Step 2 of dispatch chain (`/ux spec`)
**Status:** Draft as part of Phase 3 awaiting user approval
**Author:** Claude Opus 4.7
**Started:** 2026-04-26T10:30:00Z
**Source PRD:** [`prd.md`](prd.md)
**UX research:** [`ux-research.md`](ux-research.md)

> Per CLAUDE.md "## UI Refactoring & V2 Rule", this is a `new_ui` feature (stack migration, not v2 in-place refactor). The Astro dashboard is decommissioned — not preserved as a `v1/` artifact in the new repo.

---

## 1. Problem framing (already done in PRD §2)

See `prd.md` §1–§3 for goal, background, and non-goals.

## 2. Behavior definition

### 2.1 Entry points

| Entry | URL | Auth | First load |
|---|---|---|---|
| Direct typed URL | `https://fitme-story.vercel.app/control-room` | Basic-auth via middleware (`DASHBOARD_PUBLIC=false` default) | Overview view |
| Dashboard nav tab | `/control-room/board`, `/control-room/table`, `/control-room/knowledge` | (auth already passed) | Selected view |
| Command palette | Cmd+K from anywhere in `/control-room/*` | (auth already passed) | Palette overlay |
| Old dashboard URL | `https://fit-tracker2.vercel.app` | Redirect 301 → `/control-room` | (after auth) |

### 2.2 Primary task flow (operator's daily 8s scan)

1. Operator opens `/control-room`
2. Browser auth prompt; operator enters creds (or browser remembers); page paints
3. Operator scans Hero → confirms framework version + last-sync age (1-2s)
4. Operator scans NumbersPanel → 6 KPIs (1-2s)
5. Operator scans AlertsBanner → if any red alert, click → drill-down
6. Operator scans current-phase summary → if any feature stuck, click → drill-down
7. Total time-to-confidence target: **≤6s p50** (PRD §5.1)

### 2.3 Secondary task flows

- **Drag a card to next phase:** `/control-room/board` → drag feature card → drop on next column → snap animation → `dashboard_kanban_drag` event fires → state.json `current_phase` updated via API call → on success, card stays in new column; on validation failure (e.g., invalid transition), tooltip + revert
- **Filter & sort:** `/control-room/table` → click column header to sort, click filter chip to filter → count animates, view persists via localStorage
- **Knowledge lookup:** `/control-room/knowledge` → expand a doc group → click a doc → opens in new tab (preserves dashboard context)
- **Command palette navigation:** Cmd+K anywhere → type query → ↑/↓ to highlight → Enter to execute → palette closes
- **Toggle dark mode:** Cmd+Shift+L OR ThemeToggle → smooth color transition (≤200ms motion preset)

### 2.4 Edge cases & states

| State | Trigger | UX |
|---|---|---|
| **Empty state — no features** | Edge case; framework just initialized | KPI shows "0", overview shows "No features yet — see [/case-studies](/case-studies) for the framework backstory" |
| **Empty state — no alerts** | Healthy steady state | AlertsBanner replaced with subtle "All clear ✓" pill in muted neutral |
| **Empty state — no recent activity** | Quiet day | RecentActivity shows "No changes in the last 24h" |
| **Loading state — first visit** | Cold cache | Skeleton placeholders matching the layout (Hero outline + 6 KPI rectangles + alert rectangle) |
| **Stale data warning** | Sync >6h ago | Red footer banner: "Data synced 7h ago — Vercel deploy may have failed". Click → opens Vercel dashboard URL |
| **Sync error** | freshness.json missing or sync script failed | Red toast at top: "Could not load latest data. Showing cached snapshot from {date}." |
| **Auth error** | Wrong creds | Browser shows native 401 prompt again; no custom UI |
| **Build excluded** | `DASHBOARD_BUILD=false` | 404 — Next.js native 404 page (no custom; this is the nuclear option) |
| **Validation failure on drag** | Invalid phase transition (e.g., prd → merge skipping tasks/implement) | Tooltip near drop target: "Cannot skip {phases}. Move through {next-phase} first." Card reverts. |

### 2.5 Accessibility states

- All interactive elements have keyboard focus rings (browser default + 2px `--color-brand-indigo`)
- All button labels and icon buttons have `aria-label`
- All status pills have `role="status"` + accessible text alongside color
- All drag-drop on KanbanBoard has keyboard alternative (focus card → Space to lift → arrow keys to choose target → Space to drop)
- Tab order is logical: top nav → main view → side drill-down → footer
- No motion-only feedback (every animation has a corresponding text/color change)
- `prefers-reduced-motion` honored on all transitions

## 3. Screens (full spec for each)

### 3.1 `/control-room` — Overview

**Layout (top-to-bottom, mobile-first responsive):**

```
┌────────────────────────────────────────────────────┐
│ SiteHeader (existing fitme-story, ~64px)           │
├────────────────────────────────────────────────────┤
│ ControlRoomTabNav (~40px tabs, sticky)             │
│   Overview | Board | Table | Knowledge | (Cmd+K)   │
├────────────────────────────────────────────────────┤
│                                                    │
│  Hero (verbatim from fitme-story)                  │
│    Title:    "Control Room"                        │
│    Subtitle: "v7.6 Mechanical Enforcement —        │
│               60 features — last sync 2h ago"      │
│                                                    │
│  NumbersPanel (verbatim from fitme-story)          │
│    [framework] [features] [findings]               │
│    [linear:✓] [notion:✓] [vercel:✓]                │
│                                                    │
│  AlertsBanner (kept from current dashboard)        │
│    {N alerts OR "All clear ✓"}                     │
│                                                    │
│  CurrentPhaseSummary (new — replaces ControlRoom)  │
│    Phase blocks for: implement, testing, review    │
│    Each block: "{N} features • {sample names}"     │
│                                                    │
│  RecentActivity (lifted from change-log.json)      │
│    Last 10 entries, newest first                   │
│                                                    │
│  EnforcementLayers (new — v7.6 specific)           │
│    4 layers shown: write-time / per-PR /           │
│    72h cycle / weekly. Last fired timestamps.      │
│                                                    │
│  ClassBGaps (new — v7.6 specific)                  │
│    5 documented Class B gaps + status              │
│                                                    │
├────────────────────────────────────────────────────┤
│ DataFreshnessFooter (new — reads freshness.json)   │
│   "Data synced 2h ago" OR "⚠️ stale 7h ago"        │
└────────────────────────────────────────────────────┘
```

**Components:**
- `Hero` — fitme-story `src/components/home/Hero.tsx` **verbatim, no fork** (per Phase 3 Q2 answer)
- `NumbersPanel` — fitme-story `src/components/home/NumbersPanel.tsx` verbatim; data source replaced with control-room data builder
- `AlertsBanner` — port from `dashboard/src/components/AlertsBanner.jsx` (~40 LOC); restyle with fitme-story tokens
- `CurrentPhaseSummary` — new component (~80 LOC), uses MetricsCard pattern from `src/components/mdx/MetricsCard.tsx`
- `RecentActivity` — new component (~60 LOC), reads `change-log.json` events, renders as Disclosure-collapsed list
- `EnforcementLayers` — new component (~80 LOC), 4 cards (write-time, per-PR, 72h, weekly) with last-fired timestamp + status dot
- `ClassBGaps` — new component (~60 LOC), reads `unclosable-gaps.md` via parsed metadata; renders 5 cards with gap title + tracking link
- `DataFreshnessFooter` — new component (~30 LOC), reads `freshness.json`, color-codes age

**Skill principles applied:**
- Hick's Law: 8 sections max on this page; nothing else
- Recognition over recall: every status uses color-coded pill
- Progressive disclosure: RecentActivity collapsed by default to 3 items; click to expand to 10
- Feedback: stale-data footer turns red >6h, yellow >2h
- Consistency (internal): Hero + NumbersPanel verbatim from fitme-story

**Data sources (read at build time from synced `src/data/`):**
- `framework-manifest.json` → Hero subtitle (version, ship date)
- `feature-registry.json` → KPI counts + CurrentPhaseSummary
- `external-sync-status.json` → 4 source-health KPIs + sync timestamps
- `change-log.json` → RecentActivity
- `framework-manifest.json.v7_6_mechanical_enforcement` → EnforcementLayers
- (Parsed) `docs/case-studies/meta-analysis/unclosable-gaps.md` → ClassBGaps
- `freshness.json` → DataFreshnessFooter

### 3.2 `/control-room/board` — Kanban (full UX spec, not straight port)

**Layout:**

```
┌────────────────────────────────────────────────────┐
│ ControlRoomTabNav (sticky)                         │
│   Overview | [Board] | Table | Knowledge | (Cmd+K) │
├────────────────────────────────────────────────────┤
│ FilterBar (sticky):                                │
│   [Phase: all ▼] [Skill: all ▼] [Search: ___]      │
│   Showing 42 of 43 features                        │
├────────────────────────────────────────────────────┤
│                                                    │
│  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐      │
│  │ Research│ │  PRD   │ │ Tasks  │ │   UX   │ ...  │
│  │  (3)   │ │  (1)   │ │  (5)   │ │  (2)   │      │
│  ├────────┤ ├────────┤ ├────────┤ ├────────┤      │
│  │ feat-X │ │ feat-Y │ │ feat-Z │ │ feat-A │      │
│  │ feat-W │ │        │ │ feat-V │ │ feat-B │      │
│  │ feat-U │ │        │ │ feat-T │ │        │      │
│  └────────┘ └────────┘ └────────┘ └────────┘      │
│                                                    │
│  (Horizontal scroll for 10+ columns)               │
└────────────────────────────────────────────────────┘
```

**Behavior:**
- 10 columns total (1 per phase): Research, PRD, Tasks, UX, Implement, Testing, Review, Merge, Docs, Done
- Each column has: header (phase name + count + skill icon), card list, "+" add button (placeholder; v1 doesn't create features from UI)
- Cards: full-width, 64px tall minimum (Fitts's Law), draggable + keyboard-accessible (focus → Space → arrows → Space)
- Drag with @dnd-kit; on drop, validate phase transition (e.g., can't go prd → merge directly)
- Card content: feature display name + skill badge + priority pill + last-updated relative time
- Click card → side panel slides in from right with full feature detail (state.json contents, recent commits, Linear issue link, Notion page link)

**States:**
- Empty column: "No features in this phase" centered placeholder
- Filter applied: column counts update, "Showing N of M" updates
- Drag in progress: card lifts (~2deg rotation, scale 1.02), other columns dim slightly
- Drop on valid: snap-in animation (~150ms ease-out), `dashboard_kanban_drag` event fires
- Drop on invalid: card returns with tooltip "Cannot skip {phases}"

**Accessibility:**
- Keyboard drag: Tab to focus card, Space to lift (announces "Lifted: feature-X"), Arrow keys to navigate columns (announces "Target: Implement column"), Space to drop (announces "Moved to Implement"), Esc to cancel
- Screen reader announces each column header + count
- Color is NOT the only differentiator — every column header has a phase name + skill icon
- Reduced-motion: drag uses opacity change instead of rotation/scale

**Component:**
- `Kanban` — port from `dashboard/src/components/KanbanBoard.jsx` (~200 LOC); rebuild on @dnd-kit; restyle with tokens; add keyboard drag pattern

### 3.3 `/control-room/table` — Table (full UX spec)

**Layout:**

```
┌────────────────────────────────────────────────────┐
│ ControlRoomTabNav (sticky)                         │
├────────────────────────────────────────────────────┤
│ FilterBar (sticky):                                │
│   [Phase: ▼] [Skill: ▼] [Priority: ▼]              │
│   [Has alert: ☐] [Stale: ☐] [Search: ___]          │
│   ┌──────────────────────────────┐                 │
│   │ Showing 28 of 43 features  ↻ │                 │
│   └──────────────────────────────┘                 │
├────────────────────────────────────────────────────┤
│ ┌──────┬──────────┬───────┬───────┬──────┬──────┐ │
│ │ Name │ Phase    │ Skill │ Prior │ Updated│ ⋮   │ │
│ ├──────┼──────────┼───────┼───────┼──────┼──────┤ │
│ │ ...  │ ...      │ ...   │ ...   │ ...  │ ...  │ │
│ └──────┴──────────┴───────┴───────┴──────┴──────┘ │
│ (Sortable headers; row click → side panel)         │
└────────────────────────────────────────────────────┘
```

**Behavior:**
- TanStack Table (preserved from current dashboard)
- Sortable: every column except Actions (⋮)
- Filterable: Phase, Skill, Priority via dropdowns; Has-alert + Stale via checkboxes; Search by name (fuzzy)
- Row click → same side panel as Board view
- Right-click row → context menu (open Linear issue, open Notion page, copy slug)
- Keyboard: Tab through cells, Enter on row → side panel
- localStorage persistence: filters + sort + column visibility (per Q3=A)
- Pagination: virtualized scroll (no page chrome); ~20 rows per viewport

**States:**
- Empty filter result: "No features match these filters" + "Reset filters" button
- Loading: skeleton 5-row table
- Sync error: row-level "Could not refresh" indicator on stale rows

**Accessibility:**
- Table has proper `<th scope="col">` markup
- Sort state announced (`aria-sort="ascending"`)
- Filter changes announce row count change
- Side panel opens with focus trap; Esc to close

**Component:**
- `FeatureTable` — port from `dashboard/src/components/TableView.jsx` (~100 LOC); rebuild with TanStack Table v8; tokens

### 3.4 `/control-room/knowledge` — KnowledgeHub

**Layout:**

```
┌────────────────────────────────────────────────────┐
│ ControlRoomTabNav (sticky)                         │
├────────────────────────────────────────────────────┤
│ Group: Core Docs (3 items) ▼                       │
│   ├─ CLAUDE.md                                     │
│   ├─ README.md                                     │
│   └─ docs/skills/architecture.md                   │
│                                                    │
│ Group: Product & Planning (5 items) ▼              │
│   ├─ docs/product/PRD.md                           │
│   ├─ ...                                           │
│                                                    │
│ Group: Case Studies (24 items) ▶                   │
│ Group: Master Plan (6 items) ▶                     │
│ ...                                                │
└────────────────────────────────────────────────────┘
```

**Behavior:**
- DOC_GROUP_META preserved verbatim from `dashboard/src/scripts/builders/controlCenter.js`
- Each group: header + count + expand chevron; collapsed by default except "Core Docs"
- Each doc: title + truncated description; click → opens in new tab
- Search across all docs at top: filter as you type
- localStorage persists "expanded groups" state

**Component:**
- `KnowledgeHub` — port from `dashboard/src/components/KnowledgeHub.jsx` (~120 LOC); reuses fitme-story `Disclosure.tsx` for expand/collapse

### 3.5 `/control-room/_palette` (overlay, not a route — Cmd+K)

**Layout:** Centered modal, ~480px wide, ~360px tall

```
┌──────────────────────────────────────────┐
│  🔍 Search commands or features...       │
├──────────────────────────────────────────┤
│  RECENT                                  │
│   ↳ Switch to Board                      │
│   ↳ Filter by phase: implement           │
│   ↳ Open feature: data-integrity-v7-6    │
│                                          │
│  COMMANDS                                │
│   ↳ Switch to Overview     g o           │
│   ↳ Switch to Board        g b           │
│   ↳ Switch to Table        g t           │
│   ↳ Switch to Knowledge    g k           │
│   ↳ Toggle dark mode       Cmd+Shift+L   │
│   ↳ Reset filters          Cmd+Shift+R   │
│   ↳ Show alerts only                     │
│   ↳ Show stale data sources              │
│                                          │
│  FEATURES (43)                           │
│   ↳ ai-engine-v2                         │
│   ↳ adaptive-intelligence                │
│   ...                                    │
│                                          │
│  LINEAR ISSUES (48)                      │
│   ↳ FIT-44 — v7.5 Data Integrity         │
│   ↳ FIT-45 — v7.6 Mechanical Enforcement │
│   ...                                    │
└──────────────────────────────────────────┘
```

**Behavior:**
- Open: Cmd+K from anywhere in `/control-room/*`
- Close: Esc, click outside, or Enter (after action)
- Sections: Recent (last 5), Commands, Features (fuzzy match), Linear Issues (fuzzy match)
- ↑/↓ arrows navigate; Enter executes
- Each command/item shows its keyboard shortcut on the right (recognition)
- Linear-style fuzzy match (matches characters in order, not exact substring)
- Recents stored in localStorage (`control-room:palette:recents`)

**Component:**
- `CommandPalette` — new (~200 LOC), uses Radix Dialog + cmdk library; styled with fitme-story tokens

**Accessibility:**
- Focus trap inside palette
- `aria-live="polite"` announces filter result count
- Arrow keys + Enter as expected; standard ARIA combobox pattern

## 4. Component inventory

### 4.1 Reused from fitme-story (verbatim, no fork)

- `Hero` (`src/components/home/Hero.tsx`) — used in `/control-room` overview
- `NumbersPanel` (`src/components/home/NumbersPanel.tsx`) — used in `/control-room` overview
- `MetricsCard` (`src/components/mdx/MetricsCard.tsx`) — used in CurrentPhaseSummary, EnforcementLayers, ClassBGaps
- `Disclosure` (`src/components/ui/Disclosure.tsx`) — used in KnowledgeHub, RecentActivity
- `SiteHeader` (`src/components/SiteHeader.tsx`) — top of every page
- `SiteFooter` (`src/components/SiteFooter.tsx`) — bottom of every page

### 4.2 Ported from current dashboard (rebuilt, restyled)

- `AlertsBanner` (~40 LOC)
- `Kanban` (~200 LOC, was `KanbanBoard.jsx`)
- `FeatureTable` (~100 LOC, was `TableView.jsx`)
- `KnowledgeHubGroups` (~120 LOC, was `KnowledgeHub.jsx`)
- `SourceHealth` (~60 LOC) — moved into `/control-room` overview as KPI grid item
- `FeatureCard` (~40 LOC) — used in Kanban + side panel
- `TaskCard` (~40 LOC) — used in side panel
- `ThemeToggle` (~20 LOC) — uses fitme-story dark-mode pattern (system + manual)
- `controlCenterPrimitives` → `src/components/control-room/primitives.tsx` — Panel, MetricList, etc.

### 4.3 New components

- `ControlRoomTabNav` (~50 LOC) — top tab nav for the 4 views
- `CurrentPhaseSummary` (~80 LOC) — overview's phase rollup
- `RecentActivity` (~60 LOC) — change-log feed
- `EnforcementLayers` (~80 LOC) — v7.6 4-layer status
- `ClassBGaps` (~60 LOC) — 5 documented gaps
- `DataFreshnessFooter` (~30 LOC) — freshness indicator
- `CommandPalette` (~200 LOC) — Cmd+K palette
- `FeatureSidePanel` (~150 LOC) — side panel for feature drill-down

**Total new code:** ~1,140 LOC (component code, excluding sync script + middleware)

### 4.4 Dropped (from current dashboard)

- `ResearchConsole.jsx` — drop entirely (per PRD §6)
- `FigmaHandoffLab.jsx` — drop entirely
- `Dashboard.jsx` — replaced by `/control-room/layout.tsx`
- `TaskBoard.jsx` — folded into Board view's drill-down side panel
- `PipelineOverview.jsx` — folded into RecentActivity + EnforcementLayers
- `CaseStudiesView.jsx` — replaced by nav link to `/case-studies` showcase route
- `DependencyGraph.jsx` — folded into FeatureSidePanel as inline task tree (compact form)

## 5. Design tokens (mapping table — to be locked at T15)

See `ux-research.md` §3.3 for the full mapping. Resolution committed below; T15 implements:

```css
/* fitme-story/src/app/globals.css already defines these. We CONSUME them in /control-room components. */

/* Phase color mapping (T15 deliverable, draft here) */
.control-room [data-phase="research"]   { color: var(--skill-research); }
.control-room [data-phase="prd"]        { color: var(--skill-pm-workflow); }
.control-room [data-phase="tasks"]      { color: var(--skill-pm-workflow); opacity: 0.85; }
.control-room [data-phase="ux"]         { color: var(--skill-ux); }
.control-room [data-phase="integration"]{ color: var(--skill-design); }
.control-room [data-phase="implement"]  { color: var(--skill-dev); }
.control-room [data-phase="testing"]    { color: var(--skill-qa); }
.control-room [data-phase="review"]     { color: var(--skill-design); }
.control-room [data-phase="merge"]      { color: var(--skill-release); }
.control-room [data-phase="docs"]       { color: var(--skill-marketing); }
.control-room [data-phase="done"]       { color: var(--color-brand-indigo); }
```

## 6. Motion

- All transitions use a single `--motion-fast: 150ms ease-out` token (defined in dashboard `globals.css` extension)
- Kanban drag: 150ms snap-in, ~2° rotation lift
- Side panel slide-in from right: 200ms ease-out
- Dark mode toggle: 200ms color transition
- Filter changes: 100ms count animation
- Reduced motion: all transitions become instant; opacity changes only

## 7. Accessibility (WCAG AA mandatory)

- **Color contrast:** every text/background pair ≥4.5:1 in light AND dark mode (audit at T16)
- **Tap targets:** minimum 32px (mouse-equivalent of mobile 44pt)
- **Keyboard navigation:** every interactive element reachable via Tab; logical order
- **Focus rings:** browser default + 2px `--color-brand-indigo` outline
- **Screen reader:** all icons + status pills have accessible labels
- **Skip-to-content link** at top of every route
- **Dynamic content:** `aria-live="polite"` for filter counts, `aria-live="assertive"` for sync errors
- **Reduced motion:** honor `prefers-reduced-motion`
- **Color-not-only:** every status/phase encoded in BOTH color AND text/icon

## 8. References

- `ux-research.md` (§1 principles, §3 patterns, §4 sources)
- `prd.md` (§6 visibility, §10 analytics, §11 UX requirements)
- fitme-story `src/components/home/Hero.tsx`, `NumbersPanel.tsx`, `MetricsCard.tsx`, `Disclosure.tsx`
- fitme-story `src/app/globals.css` (token source-of-truth)
- `docs/design-system/v2-refactor-checklist.md` (referenced for accessibility + motion bars)

## 9. Acceptance criteria (Phase 3 spec gate)

- [x] All 4 routes specified with layout sketch + behavior + states
- [x] Hero + NumbersPanel reused verbatim from fitme-story (per Q2)
- [x] KanbanBoard + TableView get full UX spec (per Q1) — not straight ports
- [x] Command palette specified with sections + bindings + accessibility (per Q3)
- [x] Empty/loading/error states covered for every screen
- [x] Accessibility specified at WCAG AA on every component
- [x] Motion tokens specified
- [x] Color mapping table draft ready for T15 implementation

---

**Next:** `/ux validate` (Step 3d) inline below + `/design audit` (Step 3e) inline below = Design System Compliance Gateway report.
