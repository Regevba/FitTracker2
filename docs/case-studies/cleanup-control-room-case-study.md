# Maintenance Cleanup + Operations Control Room

**Date written:** 2026-04-13

> **Work type:** Enhancement + cleanup program  
> **Status:** In progress  
> **Started:** 2026-04-11  
> **Primary artifact:** [`dashboard/src/components/ControlRoom.jsx`](../../dashboard/src/components/ControlRoom.jsx)  
> **Tracking issue:** `FIT-22`  
> **Companion spec:** Notion page `Operations Control Room — Product Spec`

---

## Why this case study exists

This cleanup is worth documenting because it is not a normal feature build. It is a system-level maintenance cycle where multiple truths had drifted apart:

- repo truth
- dashboard truth
- Notion truth
- Linear truth
- Vercel deployment truth
- design-system governance truth

The project needed a cleanup pass before more feature work could happen safely. That makes it a strong case study for the PM workflow framework itself: not just how the system ships new work, but how it repairs its own operating environment.

---

## PM-framework view

This cleanup used the hub-and-spoke model as an operating lens even where the work was not run as a single `/pm-workflow {feature}` execution.

| Skill | Role in this cleanup |
| --- | --- |
| `/pm-workflow` | Framed the work as a cross-domain cleanup with external sync and shared-layer truth |
| `/research` | Compared repo docs, shared JSON files, Notion, Linear, and Vercel behavior |
| `/ux` | Reviewed app and marketing surfaces from a product-UX perspective |
| `/design` | Reviewed token governance, visual consistency, and Figma handoff posture |
| `/dev` | Implemented the new dashboard control-room UI |
| `/qa` | Verified dashboard tests and build status |
| `/analytics` | Structured process monitoring and case-study instrumentation |
| `/cx` | Framed failure modes and future learning loops |
| `/marketing` | Reviewed website and launch-surface readiness |
| `/ops` | Reviewed deployment topology and source-health posture |
| `/release` | Evaluated launch blockers and readiness truth |

This is the core lesson already: the framework is useful not only for feature shipping, but also for maintenance programs that span product, design, code, docs, and operations. This cleanup now serves as the first explicit v4.3 operational case study — the moment the control room, case-study monitoring, and maintenance-program framing became part of the framework itself.

---

## What happened

### 1. Reality audit

The canonical repo was confirmed as `/Volumes/DevSSD/FitTracker2`. From there, the cleanup reviewed:

- app code and v2 screen structure
- design-system implementation and closure claims
- dashboard implementation and static data
- marketing website implementation
- README and product docs
- Notion Product Hub / Project Context
- Linear roadmap issues
- Vercel live project and deployment state

### 2. Cross-system sync

Where repo truth was unambiguous, external systems were updated:

- Linear issues for onboarding, analytics wrapper, and settings redesign were moved to Done
- a maintenance cleanup issue was created
- an operations control room issue was created
- Notion status pages were updated to stop overstating what is live
- a maintenance audit page and an operations-control-room spec page were created in Notion

### 3. Dashboard expansion

The existing Astro + React dashboard was expanded into a first-pass operations control room with dedicated sections for:

- system pulse
- source health
- delivery mix
- design + UX lab
- action zones for Claude research and Figma handoff
- product intelligence
- case-study tracking

### 4. Case-study instrumentation

Instead of leaving the cleanup as a narrative only, a structured data source was added:

- [`dashboard/src/data/caseStudies.json`](../../dashboard/src/data/caseStudies.json)

This starts making the process measurable and displayable inside the dashboard itself.

---

## What shipped in this cycle

### Repo artifacts

- [`dashboard/src/components/ControlRoom.jsx`](../../dashboard/src/components/ControlRoom.jsx)
- [`dashboard/src/data/caseStudies.json`](../../dashboard/src/data/caseStudies.json)
- [`.claude/shared/case-study-monitoring.json`](../../.claude/shared/case-study-monitoring.json)
- updates to [`dashboard/src/components/Dashboard.jsx`](../../dashboard/src/components/Dashboard.jsx)
- updates to [`dashboard/src/layouts/DashboardLayout.astro`](../../dashboard/src/layouts/DashboardLayout.astro)
- updates to [`dashboard/src/styles/global.css`](../../dashboard/src/styles/global.css)
- this case study document

### Planning / documentation artifacts

- Linear `FIT-21` — maintenance sync epic
- Linear `FIT-22` — operations control room feature
- Notion `Maintenance Audit — 2026-04-11`
- Notion `Operations Control Room — Product Spec`

---

## Metrics captured so far

These are the first measurable outputs of the cleanup itself:

- `3` stale Linear issues closed
- `2` new Linear issues created
- `3` Notion pages created in this cleanup sequence
- `2` Notion pages updated to better match repo truth
- `30/30` dashboard tests passing
- dashboard build verified successfully

The monitoring layer now exists in two places:

- dashboard-facing view model: [`dashboard/src/data/caseStudies.json`](../../dashboard/src/data/caseStudies.json)
- PM-framework shared layer: [`.claude/shared/case-study-monitoring.json`](../../.claude/shared/case-study-monitoring.json)

Those files are now the place to extend this with:

- cycle duration
- discrepancy count before vs after
- source-health score over time
- number of docs/pages/issues corrected
- feature health movement over time

---

## Success cases

1. **Cross-system truth moved closer to the codebase.** The cleanup reduced obvious drift by syncing Notion and Linear where code truth was clear.
2. **The dashboard gained a stronger operating surface.** The system now has a place to see delivery status, health, UX review, and learning loops together.
3. **The maintenance program became visible work.** Instead of a hidden support effort, it now exists in repo artifacts, Notion, Linear, and the dashboard.

---

## Failure cases

1. **Status drift became systemic.** The project was carrying contradictory claims across repo docs, dashboard data, Notion, Linear, and Vercel.
2. **Marketing truth lagged behind deployment truth.** Docs described the marketing site as live while Vercel production was still serving the dashboard.
3. **Governance claims outran implementation reality.** Some design-system closure language overstated how fully tokenized and resolved the visual layer actually was.

---

## What should happen next

### Immediate

- hydrate the control room with live Notion, Linear, GitHub, and analytics inputs
- keep logging cleanup progress in `caseStudies.json`
- use the dashboard as the primary operator surface for the maintenance program

### Next case-study milestone

The next strong before/after chapter is:

- production auth cleanup
- marketing deployment/domain cleanup
- dashboard live data hydration

That would create a measurable second chapter showing whether the control room actually improved execution, not just visibility.

---

## Lessons already visible

1. A mature PM workflow needs a maintenance mode, not just a feature-shipping mode.
2. Shared truth is a product surface in its own right. When it drifts, planning quality degrades even if code quality is still decent.
3. Case-study instrumentation should begin during the cleanup, not after it finishes, because the “how we fixed the system” narrative is itself a valuable asset.
