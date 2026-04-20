> ⚠️ Historical document. References to `docs/project/` paths are from before the April 2026 reorganization. See `docs/master-plan/`, `docs/setup/`, and `docs/case-studies/` for current locations.

# Control Center Alignment + IA Refresh

## Why this case study exists

The first operations control room proved that the dashboard could act as a real PM-flow operator surface, but it still mixed too many jobs into one long page. Knowledge reading, case-study browsing, future research zones, and operational monitoring all lived together, which made the system harder to scan and easier to misread.

This case study tracks the next v4.3 step: turning the control center into a clearer multi-workspace surface while also tightening current-truth alignment across README, roadmap parsing, and the shared PM layer.

## What changed

- Shared control-center builders were extracted from the single large page assembly path.
- The dashboard moved to a clearer workspace model:
  - top-level tabs for `Control Room`, `Board`, `Table`, `Tasks`, and `Knowledge`
  - dropdown destinations for `Case Studies`, `Claude Research`, `Codex Research`, and `Figma Handoff`
- Case studies became available both:
  - inside the Knowledge tab
  - on a dedicated `/case-studies` route
- The control room itself was narrowed to operational concerns:
  - executive health
  - blockers
  - source drift
  - planning sync
  - system pulse
- Stale roadmap references were corrected to the canonical `docs/master-plan/master-backlog-roadmap.md` path.

## Why it matters

This is not just a UI polish pass. It is a framework-operability pass:

- **Knowledge becomes navigable.** Repo docs, shared PM data, and external references are easier to open intentionally.
- **Workspaces become explicit.** Research and handoff are no longer “future idea cards” inside the control room body.
- **Truth gets clearer.** The dashboard can show `live`, `shared-layer`, `repo fallback`, and `archive` instead of flattening every source into one trust level.
- **Case-study capture improves.** The reorganization itself is now measured as part of the PM-flow operating model.

## Before / after framing

### Before

- One large page builder in `dashboard/src/pages/index.astro`
- Knowledge hub embedded inside the control room
- Case-study browsing embedded in the control room
- No dedicated route for case studies
- Research and Figma zones presented as cards, not as workspace surfaces
- Roadmap parser still pointed at the stale `docs/project/...` path

### After

- Shared builder module for control-center data
- Routed workspace model with primary tabs + secondary dropdown
- Dedicated Knowledge tab
- Dedicated `/case-studies` route
- Claude/Codex/Figma action surfaces with real linked artifacts
- Current-truth roadmap references aligned to `docs/master-plan/...`

## PM-flow layer

This run is still a **cleanup program** in PM-flow terms, but it behaves like a mini product initiative:

- `/pm-workflow` provides orchestration and truth rules
- `/research` maps stale references and authority drift
- `/design` and `/ux` inform the new IA and workspace separation
- `/dev` implements the routed surfaces and builder split
- `/qa` validates route, data, and build behavior
- `/analytics` frames measurable before/after signals for the case study

## What to measure next

- Source truth score before and after the IA refresh deploy
- Alert count before and after the new workspace split
- Time-to-open canonical docs from the dashboard
- Whether routed workspaces reduce repeated audit/setup work in later cleanup chapters
- Whether the case-studies route becomes the preferred reading surface for framework showcases

## Related artifacts

- `dashboard/src/scripts/builders/controlCenter.js`
- `dashboard/src/components/Dashboard.jsx`
- `dashboard/src/components/ControlRoom.jsx`
- `dashboard/src/components/KnowledgeHub.jsx`
- `dashboard/src/components/ResearchConsole.jsx`
- `dashboard/src/components/FigmaHandoffLab.jsx`
- `dashboard/src/components/CaseStudiesView.jsx`
- `dashboard/src/pages/case-studies.astro`
- `.claude/shared/case-study-monitoring.json`
- `.claude/shared/change-log.json`
