# PRD — unified-control-center

**Phase:** 1 (PRD)
**Status:** Draft awaiting user approval
**Framework version:** v7.6 (Mechanical Enforcement)
**Author:** Claude Opus 4.7
**Started:** 2026-04-26T07:30:00Z

> Per CLAUDE.md non-negotiable rule #2: every section below must be filled before the PRD is approved. Every quantitative claim is tagged T1 (Instrumented) / T2 (Declared) / T3 (Narrative) per the data-quality tiers convention.

---

## 1. Goal (one sentence)

Migrate the FitTracker2 dashboard into the fitme-story Next.js codebase as the `/control-room` route family so the framework + product state surface and the public showcase narrative live in **one design system, one Vercel project, one URL** — while preserving the dashboard's data-loading contract and adding a 3-layer visibility control so the dashboard becomes invisible to outside sources when the product goes live (and can later be cleanly extracted to a separate, internal-only deployment).

## 2. Background

- Today: dashboard is Astro 6 + React 19 at https://fit-tracker2.vercel.app, separate Vercel project, separate visual identity.
- Showcase: fitme-story is Next.js 16, mature design system, recently shipped v7.5/v7.6 audit response surfaces (`/case-studies/mechanical-enforcement-v7-6`, `/framework/dev-guide`, `/trust/audits/2026-04-21-gemini`).
- Phase 0 Research selected Arch A (route inside fitme-story) + Pattern 4.b (pre-build sync script) — full reasoning at [`research.md`](research.md).
- New requirement added during Research approval: **blind-switch + extraction-ready**.

## 3. Non-goals

- NOT a feature-set expansion of the dashboard (we are not adding new analytics, new external integrations, new MCP wirings beyond what the data layer already exposes).
- NOT a redesign of the fitme-story showcase pages (those stay exactly as they are).
- NOT a monorepo migration (Arch C was explicitly rejected — Pattern 4.b sync script is the boundary contract).
- NOT auth on the showcase pages (only the dashboard routes are gated).
- NOT (yet) a multi-operator dashboard — still single-operator UX.

## 4. Scope

### 4.1 In scope

| Item | Notes |
|---|---|
| New routes under fitme-story `src/app/control-room/*` | `/control-room` (overview), `/control-room/board`, `/control-room/table`, `/control-room/knowledge`, `/control-room/case-studies` (redirects to existing `/case-studies` to remove dup) |
| Component port: 8 keep + 5 redesign + 2 drop (per research §8) | Astro/JSX → Next.js / React 19 server components where possible |
| Pre-build sync script (Pattern 4.b) | `fitme-story/scripts/sync-from-fittracker2.ts` + `package.json prebuild` hook + `freshness.json` writer |
| Vercel build configuration update | Custom `vercel.json` build command that clones FitTracker2 (shallow, deploy key) before `next build`; or monorepo setup |
| Design token migration | Drop dashboard's `brand: { primary: #FA8F40 }`; inherit fitme-story's `--color-brand-indigo` + `--skill-{name}` palette via direct CSS-var consumption |
| **Blind-switch (3 layers — see §6)** | Route-level auth gate + sitemap/robots exclusion + build-time inclusion flag |
| **Extraction-ready code layout (see §7)** | All dashboard code prefixed with `control-room/`; no reverse imports from showcase; documented extraction recipe in the PRD final section |
| Tests | Unit (component render), integration (data sync end-to-end), e2e (Playwright on critical workflows) |
| Analytics instrumentation | Per Analytics Spec §10; events follow `dashboard_*` prefix per CLAUDE.md naming convention |
| Decommission plan for old Astro dashboard | Sunset `dashboard/` directory + redirect old Vercel domain to new URL during transition window; archive Astro code as historical reference |

### 4.2 Out of scope (explicit punts)

- Mobile dashboard (responsive but not mobile-first)
- Multi-tenant / multi-workspace
- New data sources beyond what `external-sync-status.json` already wires
- Real-time updates (WebSocket, SSE) — still build-time data; refresh = redeploy

## 5. Success metrics

> Per CLAUDE.md rule #2 every metric must have **primary metric + baseline + target + kill criteria** with explicit tier tags.

### 5.1 Primary metric

| | Value | Tier |
|---|---|---|
| **Name** | **Time-to-Confidence (TTC)** | — |
| **Definition** | Seconds from `/control-room` page paint to operator identifying the next high-priority blocker or bottleneck. Measured by analytics: `dashboard_load → dashboard_blocker_acknowledged` event sequence | — |
| **Baseline (current Astro dashboard)** | **MUST be measured before migration starts** as a real number, not an estimate. PRD acceptance gate: instrument the current Astro dashboard with the same event pair and capture 7 days of data. Provisional estimate: ~8s | T2 (Declared) at PRD draft, MUST become T1 (Instrumented) before merge |
| **Target** | ≤6s p50 in steady state (1 month post-launch) | T2 (Declared, 2026-04-26) |
| **Kill criteria** | TTC p50 sustained > 15s for any 2 consecutive weeks → revert to Astro dashboard via the rollback plan in §13 | T2 (Declared, 2026-04-26) |

### 5.2 Secondary metrics (target each)

| Metric | Target | Tier (at launch) |
|---|---|---|
| Data freshness (age of newest sync) | ≤2h; alert if ≥6h | T1 (Instrumented — read from `freshness.json`) |
| Feature-state accuracy (% match between dashboard display vs ground truth in state.json + GitHub + Linear) | ≥98% | T2 (Declared sample-audit each weekly cron) |
| Knowledge Hub bounce rate | <20% (high bounce = content gaps) | T1 (Instrumented via GA4) |
| Dark-mode WCAG contrast | All components pass AA (4.5:1) on dark mode | T1 (Instrumented via axe MCP CI check) |

### 5.3 Guardrail metrics (must NOT degrade)

| Metric | Threshold | Tier |
|---|---|---|
| Vercel build time | Must not exceed current fitme-story build by >30s | T1 (Vercel API) |
| Dashboard JS bundle | Must not exceed 250KB gzipped on initial paint | T1 (Next.js build output) |
| Sync script runtime | <5s locally, <20s on Vercel | T1 (Instrumented in script itself) |
| Showcase pages rendering | No regression in Lighthouse score on `/`, `/case-studies`, `/framework/dev-guide`, `/trust/*` | T1 (Lighthouse CI) |
| FitTracker2 git clone latency on Vercel | <30s p95 | T1 (Vercel build logs) |

### 5.4 Leading indicators (within 1 week)

- Dashboard loads under 2s p95 on Vercel edge (T1 — Vercel Speed Insights)
- 0 console errors under React 19 strict mode on `/control-room` (T1 — automated test)
- All 8 kept components render without regression (T1 — Playwright e2e)
- Sync script runs successfully on every push to main (T1 — Vercel build status)

### 5.5 Lagging indicators (30 / 60 / 90 day)

- 30 day: TTC baseline stabilized at ≤6s p50 (T1 — GA4)
- 60 day: 0 production data-staleness incidents (operator-reported) (T1 — log)
- 90 day: blind-switch verified working — toggling `DASHBOARD_PUBLIC=false` immediately removes all 4 visibility surfaces (route, sitemap, robots, build) (T1 — verification script in `scripts/verify-blind-switch.sh`)

### 5.6 Instrumentation plan

- GA4 events fire from the Next.js dashboard via the existing fitme-story `@next/third-parties/google` integration
- Event naming follows the screen-prefix convention from CLAUDE.md analytics section: `dashboard_*` prefix
- Internal log → `dashboard/freshness.json` written by sync script + read by dashboard footer
- Build-time metrics → captured by Vercel webhook → posted to `.claude/shared/measurement-adoption.json` weekly cron

### 5.7 Review cadence

- **First review:** 2026-05-26 (30 days post-merge) — TTC baseline + freshness uptime + zero-staleness incident count
- **Subsequent:** monthly with the framework-status weekly cron (rollup at month boundary)

### 5.8 Kill criteria (recap, single source of truth)

The dashboard rebuild is **rolled back** if ANY of these are sustained for 2+ consecutive weeks post-launch:

1. TTC p50 > 15s
2. Data freshness > 24h on a normal weekday
3. Vercel build time > current + 60s p95
4. WCAG AA contrast violations on any control-room route
5. Showcase pages regress on Lighthouse (any score drops > 5 points)

Rollback plan: §13.

## 6. Visibility Control Spec (the blind-switch — NEW per user requirement 2026-04-26)

The dashboard MUST become invisible to outside sources when the product goes live, AND must be controllable independently of code deploys. **Three independent layers** — each can be flipped without code changes via Vercel env vars.

### 6.1 Layer 1 — Route-level auth gate (Next.js middleware)

**Mechanism:** `fitme-story/src/middleware.ts` intercepts every request to `/control-room/*`. Reads `DASHBOARD_PUBLIC` env var.

```typescript
// src/middleware.ts (sketch)
import { NextResponse, type NextRequest } from 'next/server';

export function middleware(req: NextRequest) {
  if (!req.nextUrl.pathname.startsWith('/control-room')) return NextResponse.next();

  const dashboardPublic = process.env.DASHBOARD_PUBLIC === 'true';
  if (dashboardPublic) return NextResponse.next();

  // Gated: require basic auth via env-vars (DASHBOARD_USER + DASHBOARD_PASS)
  // OR Vercel Preview password protection at the project level
  // OR Clerk/NextAuth (deferred to v2 if needed)
  const auth = req.headers.get('authorization');
  if (!isValidBasicAuth(auth)) {
    return new NextResponse('Unauthorized', {
      status: 401,
      headers: { 'WWW-Authenticate': 'Basic realm="control-room"' },
    });
  }
  return NextResponse.next();
}

export const config = { matcher: '/control-room/:path*' };
```

**Toggle:** flip `DASHBOARD_PUBLIC=true` ↔ `false` in Vercel project settings; takes effect on next request (no rebuild needed). For v1 we ship with `false` AND basic-auth credentials in env vars (`DASHBOARD_USER` + `DASHBOARD_PASS`); the operator hits the URL, browser prompts, operator authenticates.

### 6.2 Layer 2 — Sitemap + robots exclusion (always)

**Mechanism:**

```typescript
// src/app/sitemap.ts — exclude /control-room/* unconditionally
export default function sitemap() {
  return showcaseRoutes; // never includes control-room routes, regardless of DASHBOARD_PUBLIC
}

// src/app/robots.ts
export default function robots() {
  return {
    rules: [{ userAgent: '*', disallow: '/control-room' }],
  };
}
```

**Why unconditional:** even during private staging access, we don't want crawlers to index dashboard URLs. The robots.txt + sitemap omission means the dashboard is **never discoverable**, even if the auth gate is temporarily disabled.

### 6.3 Layer 3 — Build-time inclusion flag (nuclear option)

**Mechanism:** `next.config.ts` reads `DASHBOARD_BUILD` env var. If `false`, dashboard route handlers + components are excluded from the build entirely (the `/control-room/*` routes return 404, no JS bundle shipped).

```typescript
// next.config.ts (sketch)
const includeDashboard = process.env.DASHBOARD_BUILD !== 'false';
const nextConfig = {
  // ... existing config
  ...(includeDashboard
    ? {}
    : {
        async rewrites() {
          return [{ source: '/control-room/:path*', destination: '/404' }];
        },
      }),
};
```

Plus webpack `IgnorePlugin` to drop dashboard bundles when `DASHBOARD_BUILD=false`.

**When to use:** product launch readiness review. If we want the dashboard temporarily completely off the public site (and saving build time), flip `DASHBOARD_BUILD=false` and the next deploy contains zero dashboard code. Can re-enable with one env-var flip + redeploy.

### 6.4 Defaults at launch

| Layer | Pre-launch | Production launch |
|---|---|---|
| `DASHBOARD_PUBLIC` | `true` (we're operating it) | `false` (basic-auth gate active) |
| Sitemap/robots | always exclude | always exclude |
| `DASHBOARD_BUILD` | `true` | `true` (kept available, just gated) |

### 6.5 Verification (acceptance test)

`scripts/verify-blind-switch.sh` runs in CI on every PR touching control-room/middleware/sitemap files. Asserts:

1. `curl -s ${SITE}/sitemap.xml | grep control-room` returns nothing
2. `curl -s ${SITE}/robots.txt | grep -i 'disallow.*control-room'` returns the disallow line
3. With `DASHBOARD_PUBLIC=false`: `curl -I ${SITE}/control-room` returns 401
4. With `DASHBOARD_PUBLIC=true` and valid basic-auth: returns 200
5. With `DASHBOARD_BUILD=false`: `curl -I ${SITE}/control-room` returns 404

## 7. Future-extraction architecture

The user explicitly asked: "in a way that in the future the dashboard could be separated from the fitme-story website for internal access only." Architecture commits:

### 7.1 Co-location rule (CRITICAL — enforced by code review)

ALL dashboard code lives under one of these prefixes:

```
fitme-story/
├── src/
│   ├── app/control-room/         ← all routes
│   ├── components/control-room/  ← all dashboard-only components
│   └── lib/control-room/         ← data parsers, builders, sync
├── scripts/
│   └── sync-from-fittracker2.ts  ← data ingest (control-room only)
└── src/middleware.ts             ← visibility gate (touches control-room only)
```

### 7.2 No reverse imports

Dashboard MAY import shared design tokens (`globals.css`) and select shared components from `fitme-story/src/components/{home,mdx,ui}/` (read-only consumption).

Showcase MUST NOT import anything from `control-room/*` — verified by ESLint rule:

```js
// eslint.config.mjs (sketch)
{
  files: ['src/components/**/*', 'src/app/!(control-room)/**/*'],
  rules: {
    'no-restricted-imports': ['error', {
      patterns: [{ group: ['*/control-room/*'], message: 'Showcase code must not import dashboard code (extraction-ready rule).' }],
    }],
  },
}
```

### 7.3 Documented extraction recipe

PRD ships with `EXTRACTION-RECIPE.md` documenting the 5-step process to extract the dashboard back to a standalone Next.js app:

1. `git mv fitme-story/src/app/control-room/ new-dashboard-repo/src/app/`
2. Copy `src/components/control-room/`, `src/lib/control-room/`, `scripts/sync-from-fittracker2.ts`, `src/middleware.ts` to new repo
3. Copy `globals.css` (or extract minimal token subset) to new repo
4. Set up new Vercel project with `DASHBOARD_*` env vars only (no fitme-story env vars needed)
5. Update FitTracker2 deploy key on the new project; remove from fitme-story project
6. Update `vercel.json` build command in new project; remove sync hook from fitme-story
7. Verify: blind-switch verification script still passes on the extracted dashboard

The recipe is testable: a CI job (manual trigger only, not on every PR) runs the extraction in a scratch directory and asserts the extracted dashboard builds + verify-blind-switch.sh passes.

## 8. Functional requirements

| # | Requirement | Priority |
|---|---|---|
| FR-1 | `/control-room` overview renders 5 sections (Hero with framework state + last-sync, NumbersPanel with 6 KPIs, AlertsBanner, RecentActivity from change-log, OpenWork from In-Progress features) | P0 |
| FR-2 | `/control-room/board` shows KanbanBoard with drag-drop preserved (post-migration parity test) | P0 |
| FR-3 | `/control-room/table` shows TableView (sortable, filterable per phase + priority + skill) | P0 |
| FR-4 | `/control-room/knowledge` shows KnowledgeHub with same DOC_GROUP_META structure | P1 |
| FR-5 | All 4 sources (GitHub / Linear / Notion / Vercel) have a status indicator with last-sync timestamp + healthy/warning/error state | P0 |
| FR-6 | Blind-switch 3 layers fully implemented + verification script passes | P0 |
| FR-7 | Sync script runs successfully on local dev (`npm run prebuild`) AND on Vercel build | P0 |
| FR-8 | Dashboard footer shows data freshness (e.g., "data synced 2h ago" or red "data stale 6h+") | P0 |
| FR-9 | All visible numbers carry their tier tag (T1/T2/T3) per data-quality convention | P1 |
| FR-10 | Dark mode works on all control-room routes; WCAG AA contrast on every component | P0 |
| FR-11 | Old Astro dashboard at fit-tracker2.vercel.app redirects to new URL during transition; can be decommissioned 30 days post-launch | P1 |

## 9. Non-functional requirements

| # | NFR | Threshold |
|---|---|---|
| NFR-1 | Performance: TTC p50 ≤6s (see §5.1) | T2 declared, T1 measured at 30d review |
| NFR-2 | Performance: control-room page JS bundle ≤250KB gzipped | T1 (build output) |
| NFR-3 | Reliability: data freshness ≤2h on normal operating weekday | T1 (freshness.json) |
| NFR-4 | Security: basic-auth on dashboard routes when `DASHBOARD_PUBLIC=false`; 0 leaked secrets in dashboard bundle | T1 (Lighthouse + bundle scan) |
| NFR-5 | Accessibility: WCAG AA on all components in light + dark mode | T1 (axe CI check) |
| NFR-6 | Maintainability: 0 reverse imports from showcase to dashboard | T1 (ESLint rule) |
| NFR-7 | Operability: blind-switch verification script passes in CI | T1 (CI job) |
| NFR-8 | Observability: every dashboard page emits `dashboard_*` events to GA4 | T1 (event count) |

## 10. Analytics Spec (requires_analytics = true → mandatory section)

Read existing taxonomy: `FitTracker/Services/Analytics/AnalyticsProvider.swift` is iOS-only. The dashboard runs in the browser — events go through the existing fitme-story `@next/third-parties/google` GA4 integration. Web-side taxonomy tracker: `docs/product/analytics-taxonomy.csv` (the same source-of-truth file).

### 10.1 New events

All dashboard events use the `dashboard_` prefix per CLAUDE.md analytics naming convention.

| Event | Trigger | Parameters | Conversion? |
|---|---|---|---|
| `dashboard_load` | `/control-room` page-view fires after first paint | `route` (overview\|board\|table\|knowledge), `data_freshness_minutes`, `auth_method` (basic\|public\|extracted) | No |
| `dashboard_blocker_acknowledged` | Operator clicks/hovers on a high-priority alert in AlertsBanner | `feature_id`, `alert_severity`, `time_since_load_ms` | Yes (TTC measurement) |
| `dashboard_view_change` | Operator switches between views (overview/board/table/knowledge) | `from_view`, `to_view` | No |
| `dashboard_filter_apply` | Operator applies a filter on TableView | `filter_field`, `filter_value_count` | No |
| `dashboard_kanban_drag` | Operator drags a feature card to a different phase column | `feature_id`, `from_phase`, `to_phase` | No |
| `dashboard_knowledge_open` | Operator clicks a doc in KnowledgeHub | `doc_path`, `doc_group` | No |
| `dashboard_external_link` | Operator clicks an external link (GitHub issue, Linear issue, Notion page) | `link_type` (github\|linear\|notion\|vercel), `target_id` | No |
| `dashboard_sync_warning_shown` | Footer surfaces a stale-data warning | `staleness_hours`, `source` | No |

### 10.2 New parameters

(All listed inline above; types: string for IDs/types, number for durations/counts, no PII)

### 10.3 New screens (`AnalyticsScreen` equivalent for web — tracked via `route` param)

`control_room_overview`, `control_room_board`, `control_room_table`, `control_room_knowledge`

### 10.4 GA4 naming validation checklist (CLAUDE.md analytics section)

- [x] All event names snake_case + lowercase
- [x] All event names ≤ 40 characters
- [x] No reserved prefixes (`ga_`, `firebase_`, `google_`)
- [x] No duplicates with existing fitme-story events
- [x] No PII in any parameter
- [x] All parameter values ≤ 100 characters
- [x] All events ≤ 25 parameters
- [x] All event names use the `dashboard_` screen prefix per CLAUDE.md "Analytics Naming Convention"
- [x] One conversion event flagged (`dashboard_blocker_acknowledged` — primary metric)

### 10.5 CSV update

`docs/product/analytics-taxonomy.csv` will get 8 new rows in Phase 5 (Test). Validation gate: `make analytics-validate` (or equivalent) must pass before Phase 5 advances.

## 11. UX requirements (handed to Phase 3)

- Inherit fitme-story design tokens via direct CSS variable consumption (`bg-[var(--color-brand-indigo)]` etc.)
- Page layout: `--measure-wide` (72ch) for tables, `--measure-body` (65ch) for narrative
- Hero pattern: replicate fitme-story `Hero` component shape (display-lg title + subtitle + breadcrumb back-link if any)
- NumbersPanel pattern: lift directly from fitme-story
- Cards: warm neutrals, no aggressive shadows, follow editorial restraint
- Dark mode: inherits fitme-story behavior; verify on every component
- Accessibility: 44pt minimum tap targets (translate to ~44px for mouse), VoiceOver labels on all interactive elements, Dynamic Type support

## 12. Dependencies

| Dependency | Type | Notes |
|---|---|---|
| fitme-story repo state | Hard | Latest commit must be `467f8c1` or newer |
| FitTracker2 `.claude/shared/*.json` schema stability | Hard | Sync script depends on schema; any breaking change in v7.7+ requires sync script update |
| Vercel build env vars (`DASHBOARD_PUBLIC`, `DASHBOARD_USER`, `DASHBOARD_PASS`, `DASHBOARD_BUILD`, FitTracker2 git deploy key) | Hard | Must be set before first deploy |
| GA4 property ID (already wired in fitme-story `NEXT_PUBLIC_GA_ID`) | Hard | Reuse existing |
| Existing fitme-story showcase routes | Soft | Must not regress (guardrail metric) |

## 13. Rollback plan

If any kill criterion in §5.8 is hit:

1. **Immediate:** flip `DASHBOARD_BUILD=false` in Vercel; redeploy. Dashboard returns 404 on fitme-story; old Astro dashboard at fit-tracker2.vercel.app is restored to active by reversing the redirect.
2. **Within 24h:** post-mortem. Determine if rollback is permanent (extract dashboard back to standalone via `EXTRACTION-RECIPE.md`) or temporary fix-then-redeploy.
3. **Astro dashboard NOT decommissioned until** 30 days of stable post-launch operation. Prevents irreversible loss.

## 14. Risks (carried from research §10 + new ones from blind-switch + extraction)

| # | Risk | Impact | Likelihood | Mitigation |
|---|---|---|---|---|
| R-1 | Data sync fails silently on Vercel | HIGH | HIGH | Sync script writes `freshness.json` + dashboard footer surfaces age; CI alerts if sync fails |
| R-2 | Component port regression | HIGH | MEDIUM | Tests + parallel-run + feature flags |
| R-3 | Design token contrast fails dark mode | MEDIUM | MEDIUM | Pre-migration token audit + axe CI |
| R-4 | Vercel build-time bloat | MEDIUM | MEDIUM | Remove old Astro early; build cache; shallow git clone |
| R-5 | FitTracker2 git clone latency on Vercel | MEDIUM | LOW | Shallow clone + cache `.claude/` between builds + skip on no-change |
| R-6 (NEW) | Blind-switch leaks: someone hard-codes a control-room link in showcase nav | HIGH (privacy) | MEDIUM | ESLint rule (no reverse imports) + verify-blind-switch.sh CI job |
| R-7 (NEW) | Auth bypass: basic-auth credentials leaked or middleware bug | HIGH (privacy) | LOW | Vercel env-var rotation procedure documented; middleware unit-tested |
| R-8 (NEW) | Extraction recipe rots over time as dashboard depends on more showcase code | MEDIUM | MEDIUM | ESLint rule enforces no reverse imports; quarterly manual extraction-recipe verification (CI job) |

## 15. Open questions for Phase 2 (Tasks)

- Use Vercel password protection (project-level) instead of basic-auth middleware? (Pro: no code; Con: less granular)
- Extract sync script as a published package (`@fitme/dashboard-sync`)? (Defer until extraction is actually triggered)
- Implement view persistence (operator's last view + filter state) via localStorage? (Yes — small effort, big UX win)
- Add a `/control-room/preview` route for testing without auth gate? (No — security smell)

## 16. Acceptance criteria (PRD approval gate)

- [x] All sections filled (rule #2 enforcement)
- [x] Primary metric + baseline + target + kill criteria explicit
- [x] T1/T2/T3 tags on every quantitative claim
- [x] Analytics Spec naming validation checklist all checked
- [x] Visibility Control Spec covers 3 layers + verification
- [x] Future-extraction architecture documented
- [x] Risks + mitigations listed
- [x] Rollback plan defined

---

## Approval gate

User must explicitly approve this PRD before Phase 2 (Tasks) opens. On approval the framework will:
1. Set `phases.prd.status = "approved"` + `phases.prd.approved_at` + `phases.prd.duration_minutes`
2. Set `phases.prd.analytics_spec_complete = true`
3. Auto-emit `phase_approved` event to `.claude/logs/unified-control-center.log.json`
4. Set `current_phase = "tasks"` + open Phase 2 (Tasks)
5. Tasks phase will break this PRD into ordered, dependency-aware subtasks per CLAUDE.md task structure
