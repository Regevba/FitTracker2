# PRD: Case-Study Thread Visualization

> **Owner:** Regev
> **Date:** 2026-05-16
> **Phase:** 1 (PRD)
> **Status:** Draft
> **Framework version:** v7.8.6
> **Work type:** Feature

---

## Purpose

A visual timeline component on the fitme-story public site that renders multi-part case-study series as connected horizontal threads — making the progression from one part to the next visible at the listing surface (not just after click) so external readers can navigate a feature's full evolution arc as a single narrative.

## Business Objective

The fitme-story public site is the primary external showcase of the FitMe framework's evolution. Today, 72% of published case studies (63 of 87) belong to a multi-part series, but they render as a flat list with no connection cues. The framework's most narratively rich threads — UCC (6 parts), HADF (4 parts), framework-integrity-v7 (12 parts), ui-audit (8 parts), design-system-sweep (7 parts), framework-history (15 parts) — are currently invisible as threads. Making them discoverable signals depth and rigor to readers and lets practitioners trace how a feature actually evolved across framework versions.

## Target Persona(s)

| Persona | Relevance |
|---|---|
| **External operator / framework practitioner** | Reads case studies to understand HOW the framework evolved. Threading lets them follow a specific arc end-to-end without manually piecing together version numbers. |
| **Portfolio reader (recruiter, customer, partner)** | Browses fitme-story to evaluate the team's rigor. Visible threads communicate "this is a multi-month, multi-version commitment" without requiring deep reading. |
| **FitMe team member returning later** | Uses fitme-story as canonical record. Threading shortens "where did we ship UCC parts 1-6?" from a 3-minute search to a glance. |

## Has UI?

**Yes** — new horizontal timeline component rendered on listing + detail pages. Affects fitme-story repo only; FT2 changes are markdown frontmatter additions (no UI).

## Functional Requirements

| # | Requirement | Status | Details |
|---|---|---|---|
| 1 | Schema additive: `series_id: z.string().optional()` field in fitme-story `content-schema.ts` | Planned | Added next to existing unused `related[]` field |
| 2 | Typed series catalog at `src/lib/series-catalog.ts` | Planned | 10 series locked: ucc, hadf, framework-integrity-v7, ui-audit, design-system-sweep, framework-history, smart-reminders, training-plan, onboarding-v2, push-notifications. Each entry: `{id, title, member_slugs_ordered, era_start, era_end, summary}` |
| 3 | Helper lib at `src/lib/series.ts`: `getSeriesById`, `getStudiesBySeries`, `getSeriesPosition(slug)` | Planned | Returns `{series, index, total, prev, next}` for detail page; sorted by `timeline_position.order` |
| 4 | `SeriesTimeline` component (listing variant + detail variant) | Planned | Horizontal SVG/CSS, token-compliant, two variants distinguished by `currentSlug` prop |
| 5 | Listing page integration: new "Series" section in `src/app/case-studies/page.tsx` | Planned | Renders all 10 series above the existing v7-category accordions; reuses the v7-category bucketing pattern at L93-133 |
| 6 | Detail page integration: timeline at top of every MDX with `series_id` | Planned | Wherever case-study detail page renders the MDX content — likely `src/app/case-studies/[slug]/page.tsx` |
| 7 | Backfill 4 MDX showcases | Planned | `08b-onboarding-v2-retroactive.mdx`, `12a-hadf-hardware-aware-dispatch.mdx`, `23d-push-notifications-v1.mdx`, `27a-fitme-story-website-design-system-orig.mdx` (slot numbers final at Phase 4) |
| 8 | `series_id` frontmatter populated on ~50 MDX files | Planned | All members of the 10 locked series; one mechanical pass per series |
| 9 | CI drift check + unit tests | Planned | (a) Every populated `series_id` resolves to a series in the catalog; (b) Every catalogued series has ≥2 published members; (c) timeline component renders without console errors |
| 10 | Convention added to FitTracker2 `CLAUDE.md` "Case studies" section | Planned | Documents: if a case study has ≥1 follow-up, both must declare a shared `series_id`. Requires isolated worktree (Mode B advisory fires on CLAUDE.md edits) |
| 11 | Responsive layout for ≥8-node series | Planned | Phase 3 UX spec decides exact behavior — likely horizontal scroll on mobile + paginated nodes on tablet |
| 12 | GA4 analytics events (4 new) | Planned | See Analytics Spec below |

## User Flows

### Flow 1 — Discover a series from the listing

1. Reader lands on `fitme-story.vercel.app/case-studies`
2. Sees the milestones strip (unchanged) at top
3. Below, sees a new "Series" section with 10 horizontal timelines, each labeled with series title + version range + part count
4. Identifies a series of interest (e.g., "UCC — v4.3 → v7.8.1 — 6 parts")
5. Clicks a node → lands on that part's detail page

### Flow 2 — Navigate within a series from a detail page

1. Reader is reading a case study detail page (e.g., `/case-studies/26-ucc-passkey-auth`)
2. At top of page: the same series timeline component appears with the current node visually highlighted ("you are here")
3. Reader clicks an earlier node (e.g., part 3 — "Unified Control Center migration")
4. Lands on that part's detail page; timeline updates to show new "you are here"

### Flow 3 — Solo case study unchanged

1. Reader lands on a case study with no `series_id` (e.g., `meta-analysis.mdx`)
2. No timeline renders at top
3. Page renders identically to today

### Flow 4 — Reader uses keyboard navigation

1. Reader focuses the timeline component via Tab
2. Left/Right arrow keys move focus between nodes
3. Enter activates the focused node
4. Screen reader announces "Part 2 of 6 in Unified Control Center series, currently viewing: cleanup control room. Next: control center alignment IA refresh"

## Current State & Gaps

| Gap | Priority | Notes |
|---|---|---|
| `series_id` field doesn't exist in schema | P0 | Schema-additive; non-breaking |
| `related[]` field exists but unused | P2 | Not removing — leave for potential v1.1 cross-series linking |
| Listing page has no series-aware grouping | P0 | Closes via FR-5 |
| Detail page has no prev/next within series | P0 | Closes via FR-6 |
| 4 FT2 case studies have no public counterpart in series-relevant clusters | P1 | Closes via FR-7 |
| `series_id` is a single string (no multi-membership) | P2 | Forward-compatible to array via codec; deferred to v1.1 if needed |

## Acceptance Criteria

- [ ] All 10 locked series render on the listing page as horizontal timelines, each with title + version range + part count
- [ ] Every detail page in a series shows the timeline at top with "you are here" marker on the current node
- [ ] 4 backfill MDXs published with proper frontmatter (≥5 required fields per `FEATURE_CLOSURE_COMPLETENESS`)
- [ ] ~50 existing MDX files have `series_id` populated
- [ ] Timeline is keyboard-navigable (Tab to focus, Left/Right to move between nodes, Enter to activate)
- [ ] Timeline has correct ARIA labels (`role="navigation"`, `aria-label="UCC series timeline"`, per-node `aria-label="Part N of M: <title>"`)
- [ ] Reduced-motion users get a static (non-animated) variant
- [ ] AXE score on listing page ≥ baseline (no new accessibility regressions)
- [ ] Vercel Speed Insights: LCP on listing page ≤ baseline + 100ms tolerance
- [ ] CI drift check: every populated `series_id` resolves to a series in `series-catalog.ts`
- [ ] CI drift check: every catalogued series has ≥2 published members in the MDX collection
- [ ] CI: timeline component unit tests pass (render, interaction, a11y)
- [ ] 4 GA4 events firing correctly (verified via Realtime view post-deploy)
- [ ] CLAUDE.md convention section updated

---

## Success Metrics & Measurement Plan

### Primary Metric

- **Metric:** Series navigation engagement rate = unique sessions that fire ≥1 `case_study_series_node_click` OR `case_study_series_nav_click` event ÷ unique sessions that view a case-study detail page with `series_id`
- **Baseline:** 0% (events don't exist today; series UI doesn't exist)
- **Target:** ≥5% within 30 days post-launch
- **Timeframe:** 30 days post-merge; first review 2026-06-26 (T+30d from estimated ship 2026-05-27)
- **Tier:** T1 (instrumented via GA4)

### Secondary Metrics

| Metric | Baseline | Target | Instrumentation | Tier |
|---|---|---|---|---|
| Avg # of case studies viewed per session | (read from GA4 pre-launch baseline) | +20% | GA4 `page_view` event count per session | T1 |
| Bounce rate on series-member detail pages | (read from GA4 pre-launch baseline) | -10% | GA4 `bounce_rate` filtered to slugs in series-catalog | T1 |
| # of series with ≥1 navigation event in first 30 days | 0 | ≥7 of 10 | GA4 custom report filtered by `series_id` param | T1 |
| Series-section impressions on listing page | 0 | ≥80% of listing-page sessions | GA4 `case_study_series_view` (fires on IntersectionObserver) | T1 |

### Guardrail Metrics

| Metric | Current Value | Acceptable Range |
|---|---|---|
| Crash-free rate (FitMe iOS app) | >99.5% | Not applicable — web-only feature |
| Cold start time (FitMe iOS) | <2s | Not applicable |
| Sync success rate (FitMe iOS) | >99% | Not applicable |
| fitme-story listing page LCP | (baseline TBC at Phase 5; read from Vercel Speed Insights) | ≤ baseline + 100ms |
| fitme-story listing page CLS | (baseline TBC) | ≤ baseline + 0.01 |
| AXE-core a11y violations on listing page | (baseline TBC; ideally 0) | No new violations introduced |
| Lighthouse a11y score on listing page | (baseline TBC) | ≥ baseline |

### Leading Indicators (≤1 week post-launch)

- ≥50% of listing-page sessions trigger ≥1 `case_study_series_view` event (series sections are seen)
- ≥2% of those sessions trigger ≥1 `case_study_series_node_click` (early click-through signal)
- At least 1 detail page in a series receives a `case_study_series_nav_click` event (prev/next works in production)

### Lagging Indicators (30 / 60 / 90 days)

- D30: primary metric (engagement rate) hits ≥5%
- D60: median series viewed per session ≥1.5 (readers exploring multiple series)
- D90: series listing-section impression rate stable ≥75% (no scroll-fatigue regression)

### Instrumentation Plan

| Event/Metric | Method | Status |
|---|---|---|
| `case_study_series_view` | GA4 + IntersectionObserver | Not started |
| `case_study_series_node_click` | GA4 + onClick handler | Not started |
| `case_study_series_nav_click` | GA4 + prev/next click handler | Not started |
| `case_study_detail_view_with_series` | extend existing GA4 `page_view` with custom param `series_id` | Not started |
| LCP / CLS | Vercel Speed Insights (already wired) | Available now |
| AXE-core a11y | existing CI workflow (already wired) | Available now |

### Analytics Spec (GA4 Event Definitions)

> **Web context** — fitme-story site, not iOS app. Naming convention: kebab-case events are not GA4-friendly; using `snake_case` per GA4 rules.

#### New Events

| Event Name | Category | GA4 Type | Screen/Trigger | Parameters | Conversion? | Notes |
|---|---|---|---|---|---|---|
| `case_study_series_view` | Engagement | Custom | Listing page; IntersectionObserver fires when a series section enters viewport (50% threshold) | `series_id`, `member_count`, `position_in_list` | No | Throttled to once per session per series |
| `case_study_series_node_click` | Engagement | Custom | Listing page OR Detail page; reader clicks a node in the timeline | `series_id`, `from_slug` (current page slug or "listing"), `to_slug`, `position_clicked` (1-indexed) | Yes | Conversion event — proves discoverability hypothesis |
| `case_study_series_nav_click` | Engagement | Custom | Detail page; reader clicks prev/next nav embedded in timeline | `series_id`, `from_slug`, `to_slug`, `direction` (prev / next) | Yes | Conversion event |
| `case_study_series_keyboard_nav` | Engagement | Custom | Listing OR Detail page; reader uses keyboard to traverse timeline (Tab + arrow + Enter) | `series_id`, `interaction_type` (focus / activate) | No | Engagement signal for a11y users |

#### New Parameters

| Parameter Name | Type | Allowed Values | Used By Events | Notes |
|---|---|---|---|---|
| `series_id` | string | Enumerated from `series-catalog.ts` keys (ucc, hadf, framework-integrity-v7, ui-audit, design-system-sweep, framework-history, smart-reminders, training-plan, onboarding-v2, push-notifications) | All 4 new events + extended `page_view` | Max 40 chars |
| `member_count` | int | 3-15 (range of cluster sizes per catalog) | `case_study_series_view` | Validates which clusters get attention |
| `from_slug` | string | MDX file slug (e.g., `23a-unified-control-center`) | node_click + nav_click | Max 100 chars |
| `to_slug` | string | MDX file slug | node_click + nav_click | Max 100 chars |
| `position_in_list` | int | 1-10 | `case_study_series_view` | Did readers see series at the top, middle, or bottom? |
| `position_clicked` | int | 1-15 | `case_study_series_node_click` | Which node position drives most engagement? |
| `direction` | string | `prev` / `next` | `case_study_series_nav_click` | Are readers going forward or back? |
| `interaction_type` | string | `focus` / `activate` | `case_study_series_keyboard_nav` | Distinguishes browsing from action |

#### New Screens

| Screen Name | View Name | Component | Category |
|---|---|---|---|
| `case_studies_listing` | (existing) | `src/app/case-studies/page.tsx` | engagement |
| `case_study_detail` | (existing) | `src/app/case-studies/[slug]/page.tsx` | engagement |

No new screens — both events fire on existing case-study screens; only adds new event types + a custom param to existing `page_view`.

#### New User Properties

None. The feature doesn't profile users; it tracks navigation events.

#### Naming Validation Checklist

- [x] All event names: snake_case, <40 chars (`case_study_series_view` = 22 chars)
- [x] All parameter names: snake_case, <40 chars
- [x] No reserved prefixes (`ga_`, `firebase_`, `google_`)
- [x] No duplicate names — checked against existing fitme-story GA4 events (none start with `case_study_series_`)
- [x] No PII in any parameter (slugs are public; series_id is public enum)
- [x] ≤25 parameters per event (max is 7 on `case_study_series_view`)
- [x] Total custom user properties unchanged (no new properties)
- [x] Parameter values spec'd to max 100 chars
- [x] Conversion events identified: `case_study_series_node_click`, `case_study_series_nav_click`

#### Files to Update During Implementation

- [ ] `fitme-story/src/lib/analytics.ts` (or wherever GA4 wiring lives) — add typed event helpers
- [ ] fitme-story analytics taxonomy doc (if one exists; otherwise inline)
- [ ] GA4 console: register new events + conversions (operator step post-merge)

### Review Cadence

- **First review:** 2026-06-26 (T+30d from estimated ship 2026-05-27)
- **Subsequent:** Weekly for 4 weeks (2026-07-03, 2026-07-10, 2026-07-17, 2026-07-24), then monthly

### Kill Criteria

> When to revert or fundamentally rethink this feature.

1. **Zero engagement (primary kill):** If by 30 days post-ship ZERO `case_study_series_node_click` OR `case_study_series_nav_click` events fire across ALL 10 series, the feature is not solving the discoverability problem. Action: rollback to Option 3 (footer `related[]` only) — see brainstorm alternatives.
2. **Performance regression:** If listing-page LCP regresses >200ms vs baseline at 7 days post-ship AND can't be optimized in <1 day, rollback the timeline component (keep `series_id` schema for future use).
3. **A11y regression:** If AXE-core finds ≥1 new accessibility violation introduced by the timeline that can't be fixed in <1 day, rollback the component.
4. **Catalog drift collapse:** If CI drift check finds >3 catalog inconsistencies (orphan series_ids, missing members) within 60 days post-ship, freeze new MDX authoring until a stricter schema enforcement (e.g., automated catalog generation) ships.

**`kill_criteria_resolution` field placeholder:** to be filled at Phase 9 (Docs) — likely "not_fired" if metrics pass, or specific resolution if any kill criterion triggers.

---

## Key Files

| File | Purpose |
|---|---|
| `fitme-story/src/lib/content-schema.ts` | Schema additive: `series_id` field |
| `fitme-story/src/lib/series-catalog.ts` | NEW — typed catalog of 10 series |
| `fitme-story/src/lib/series.ts` | NEW — helper lib (getSeriesById, getStudiesBySeries, getSeriesPosition) |
| `fitme-story/src/components/SeriesTimeline.tsx` | NEW — timeline component (listing + detail variants) |
| `fitme-story/src/app/case-studies/page.tsx` | MODIFY — listing page integration |
| `fitme-story/src/app/case-studies/[slug]/page.tsx` | MODIFY — detail page integration |
| `fitme-story/content/04-case-studies/*.mdx` | MODIFY — ~46 MDX frontmatter edits to add `series_id` |
| `fitme-story/content/04-case-studies/08b-onboarding-v2-retroactive.mdx` | NEW — backfill MDX |
| `fitme-story/content/04-case-studies/12a-hadf-hardware-aware-dispatch.mdx` | NEW — backfill MDX |
| `fitme-story/content/04-case-studies/23d-push-notifications-v1.mdx` | NEW — backfill MDX |
| `fitme-story/content/04-case-studies/27a-fitme-story-website-design-system-orig.mdx` | NEW — backfill MDX |
| `fitme-story/src/__tests__/series-catalog.test.ts` | NEW — unit tests for catalog integrity |
| `fitme-story/src/__tests__/SeriesTimeline.test.tsx` | NEW — unit tests for component |
| `fitme-story/scripts/check-series-drift.ts` (or similar) | NEW — CI drift check |
| `fitme-story/.github/workflows/ci.yml` | MODIFY — add drift check step |
| `FitTracker2/CLAUDE.md` | MODIFY — add series convention to Case-Studies section (REQUIRES isolated worktree per Mode B advisory) |
| `FitTracker2/.claude/features/case-study-thread-visualization/` | THIS — state.json + research.md + prd.md + tasks.md + ux-spec.md + case study at close |

## Dependencies & Risks

| Dependency / Risk | Mitigation |
|---|---|
| **Calibration window 2026-05-15 → 2026-05-21** — Phases 0-3 fine; Phase 4+ generates gate fires from MDX edits + state.json transitions | HARD PAUSE before Phase 4; resume 2026-05-22 (post v7.9 promotion decision) per cadence-followups C1 precedent |
| **CLAUDE.md edit fires `BRANCH_ISOLATION_VIOLATION` Mode B advisory** | Edit happens in an isolated worktree via `scripts/create-isolated-worktree.py` per v7.8.1 standard pattern |
| **fitme-story GA4 wiring** — events depend on existing analytics setup | GA4 already wired (per FIT-142 + GA4 MCP connection 2026-05-14); just add new event helpers |
| **`framework-integrity-v7` 12-node timeline visual density on mobile** | Phase 3 UX spec must address responsive layout (horizontal scroll + paging at ≤480px viewport) |
| **Backfill MDX frontmatter drift** — new MDXs prone to inconsistency with FT2 source | Each backfill MDX links its FT2 source in frontmatter; CI drift check validates basic schema |
| **`HADF` cluster split decision** — flipped earlier "single chain" choice mid-research | Decision tracked in state.json transition note + research.md §11 D9; the new layout fits Phase 3 better |
| **B8 UCC kill-criteria checkpoint 2026-05-23** | Don't touch UCC source case study before B8 resolves `kill_criteria_resolution`; UCC-specific MDX edits sequenced after 2026-05-23 |
| **Vercel preview CI cost** for 10+ commits across Phases 4-7 | Squash-merge final PR; preview deploys are gated on PR push (not commit) so cost stays bounded |
| **Tier 3.2 doc-debt** — 4 new MDXs must meet `FEATURE_CLOSURE_COMPLETENESS` 7 required fields | Reuse a recent showcase MDX (e.g., 26-ucc-passkey-auth.mdx) as template; verify each new MDX manually before commit |

## Estimated Effort

- **Total:** 3.5 person-days (across Phases 0-9; ~1.5 days remaining for Phases 4-9 after the 2026-05-22 resume)
- **Breakdown:**
  - Phase 0 Research: 0.5d (~13 min actual measured)
  - Phase 1 PRD: 0.25d
  - Phase 2 Tasks: 0.25d
  - Phase 3 UX/Integration: 0.5d
  - Phase 4 Implementation: 1.5d (component + helpers + frontmatter backfill + 4 new MDXs)
  - Phase 5 Testing: 0.25d
  - Phase 6 Review: 0.1d
  - Phase 7 Merge: 0.05d
  - Phase 8 Docs: 0.1d
  - Phase 9 Learn: 0.1d (case study authoring)

**Calendar effort:** 2 wall-clock weeks (5 days planning 2026-05-16 → 21; pause 2026-05-21 → 22; 5-7 days implementation 2026-05-22 → 28).

---

## Notes on AI-touching status

This feature does NOT touch AIOrchestrator, ReadinessEngine, NutritionRecommender, TrainingRecommender, or CohortIntelligence. No views in this feature display AI-generated content. **`min_eval_coverage_met` auto-set to `true`; eval gate skipped.**

## Notes on iOS test surface

This feature is **web-only** (fitme-story). No iOS code changes. Standard iOS CI gates (`make tokens-check`, `xcodebuild build`, `xcodebuild test`, `make ui-audit`) are not affected by this feature's commits. fitme-story has its own CI (currently no JS test gate on PR per test-coverage T6 backlog item).
