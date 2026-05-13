# PRD: Framework Universe — 3D Interactive Framework Flow Diagram

> **Owner:** Regev (orchestrator: Claude Opus 4.7)
> **Date:** 2026-05-13
> **Phase:** 1 — PRD (in progress)
> **Status:** Draft
> **Feature slug:** `3d-interactive-framework-flow-diagram`
> **Public name:** Framework Universe
> **Repo:** fitme-story (state_owner)
> **Framework version:** v7.8.3 (created); ships under v7.9.x
> **Linear:** [FIT-138](https://linear.app/fitme-project/issue/FIT-138)
> **Notion:** [3D Interactive Framework Flow Diagram — Public-Site Flagship Visual](https://www.notion.so/35e0e7a0eace81b5ba12eb6e6950da5a)
> **Research dossier:** [`research.md`](./research.md) (597 lines, shipped FT2 PR #324)

---

## Purpose

A standalone ~3:15-minute cinematic 3D walkthrough of how the FitMe framework operates end-to-end on a single feature's lifecycle — published on the fitme-story public site at `/framework` as the flagship explainer, and simultaneously wired as a **measurement instrument** that surfaces live framework telemetry to visitors and operators.

## Business Objective

The framework's complexity (60+ features, 25 gates + advisories, 4 cooperating enforcement layers, T1/T2/T3 data quality tiers) is hard to grasp from prose alone. Two existing 2D visuals — `LifecycleLoop` (orbital reference at `/pm-flow`) and `DispatchReplay` (scrollytelling at `/framework/dispatch`) — establish framework legibility but neither delivers a **narrative end-to-end view**.

The Framework Universe addresses three business needs simultaneously:

1. **External legibility** — give first-time fitme-story visitors a single ~3-minute experience that conveys what the framework IS and how it BEHAVES on real work.
2. **Internal dogfooding** — make the framework visible to its own operators in 3D space (`/control-room/framework`), so framework drift is felt before it appears in audits.
3. **Instrument the explainer** — the visual collects Stream A visitor analytics (which framework concepts are clear vs confusing), closing a measurement gap the framework has carried since v6.0 (we measure features, not the documentation that explains them).

## Target Persona(s)

| Persona | Relevance |
|---|---|
| First-time fitme-story visitor (curious developer / framework-curious operator) | The flagship explainer they land on; reads the framework without prior context |
| Returning fitme-story reader (existing framework user) | Reference scene; can scrub specific acts; deepens model of recent work |
| FT2 operator at `/control-room/framework` | Same 3D scene rendered with live telemetry overlays; ambient health monitor |
| Marketing / hiring audience (Linear, recruiting, talks) | Loop-able share-quality 60s clip extracts from Acts II + V |

## Has UI?

**Yes.** Public-facing 3D scene + operator-mode variant. `has_ui = true`.

## Requires Analytics?

**Yes.** Stream A is a core deliverable — without analytics instrumentation this is half the feature. `requires_analytics = true`.

---

## Functional Requirements

| # | Requirement | Status | Details |
|---|---|---|---|
| 1 | Cinematic 6-act 3D walkthrough at `/framework` | Planned | Acts I–VI per research §5.2–5.7. Default state is autoplay linear playback; visitor controls via scrub/pause/hover/time-dilation. Total ~3:15 ±0:15. |
| 2 | Pixar clean-tech visual mood | Planned | Bright, minimalist, slightly playful (Inside Out HQ / WALL-E BnL). Smooth curves, matte plastics, ambient lighting, soft shadows. Anchored on the 8-region color palette from `blueprint-data.ts`. |
| 3 | Hybrid asset pipeline | Planned | Procedural R3F primitives for architectural shell (chambers, walls, terrain, signage). Blender → glTF (.glb with Draco + Meshopt + KTX2) for ≤6 hero pieces (gate machinery, telemetry instruments, signature props). |
| 4 | Three primary stacks with cascading fallback | Planned | Tier 1: R3F + Drei + Theatre.js + Three.js WebGPURenderer (WebGL2 fallback automatic since r171). Tier 2: Rive state machine for reduced-motion + low-RAM mobile. Tier 3: `next/image` poster frame for saved-data / no-JS. |
| 5 | Interactive controls | Planned | Pause / scrub timeline / hover-to-label / time-dilation (slow current act 4×). No camera pan beyond rail-constrained orbit. Reader controls camera and time; no other state. |
| 6 | Live-data wiring (Stream B) | Planned | Build-time snapshot of `gate-coverage.jsonl` + `measurement-adoption-history.json` + last-N state.json mutations. On-session-start client fetch for freshness. Data surfaces in Acts IV–VI as visual phenomena (gate firings, ledger growth, completed-feature monuments). |
| 7 | Visitor analytics (Stream A) | Planned | GA4 events captured at act boundaries, label-hover, scrub seek, time-dilation, replay, fallback-tier activation. Feeds new "Visitor Comprehension" panel at `/control-room/framework`. |
| 8 | Operator-mode (Stream C) | Planned | Same component rendered at `/control-room/framework` with live WebSocket telemetry overlay, UCC-passkey gated. Shares 100% of scene code with visitor mode; only data subscription differs. |
| 9 | Glossary integration | Planned | Every label that has a `glossary.ts` entry shows the `<Term>` tooltip on hover. Vocabulary inherits from canonical models — 10 phase IDs from `lifecycle-phases.ts`, 8 region accents from `blueprint-data.ts`. |
| 10 | Performance contract | Planned | Lighthouse Performance ≥95 sustained. Initial JS = 0 KB (fully deferred dynamic import gated on IntersectionObserver). LCP unaffected. CLS = 0. |
| 11 | Accessibility contract | Planned | WCAG 2.3.3 (Animation from Interactions) honored. `prefers-reduced-motion` activates Tier 2 (Rive) automatically. Keyboard scrub via arrow keys + space. Each act has alt-text caption track. Focus ring on interactive overlays. |
| 12 | Mobile target | Planned | 60fps on iPhone 12 / Pixel 6 (2026 mid-tier baseline). DPR capped at 2.0. Frameloop "demand" when off-viewport. |

## User Flows

### Primary flow: First-time visitor, autoplay
1. Visitor lands on `/framework`
2. IntersectionObserver triggers dynamic import of 3D scene (deferred bundle ~120 KB hero + ~80 KB R3F core)
3. Scene fades in at the threshold (Act I)
4. Autoplay proceeds linearly through Acts I → VI (~3:15)
5. Visitor exits at any point; scrub position cached in sessionStorage for return visits

### Secondary flow: Engaged visitor, scrub + label-hover
1. Visitor pauses during Act IV (Gate Chain) — most info-dense act
2. Hovers a labeled gate; `<Term>` glossary tooltip appears with link to glossary entry
3. Scrubs back to Act II (Conception); replays without re-fetching scene
4. Toggles time-dilation; current act plays at 0.25× speed
5. Resumes linear playback

### Tertiary flow: Reduced-motion / low-RAM mobile
1. Visitor with `prefers-reduced-motion: reduce` lands on `/framework`
2. Component detects motion preference and CPU class; loads Tier 2 (Rive)
3. Rive scene plays a simplified ~45s static-camera version with reader-controlled scrub
4. Same labels, same glossary integration, no camera moves

### Quaternary flow: Operator mode
1. Operator authenticated via UCC passkey lands on `/control-room/framework`
2. Same 3D component renders with WebSocket subscription to live framework events
3. Recent gate firings appear as bursts of light in Act IV's chamber
4. New completed features materialize as monuments in Act VI's legacy gallery
5. Operator drags timeline cursor to inspect any state in the past 24h

## Current State & Gaps

| Gap | Priority | Notes |
|---|---|---|
| No end-to-end narrative explainer of the framework on the public site | P0 | Existing 2D visuals are reference + dispatch-trace; neither is a narrative |
| No measurement of explainer comprehension (do visitors understand?) | P0 | Stream A closes this gap |
| Operators have no ambient view of framework health beyond dashboard tables | P1 | `/control-room/framework` exists but is data-table-only; Stream C adds 3D heartbeat |
| fitme-story has no 3D capability — would need new dependencies (R3F, Three.js, Theatre.js, Drei, Rive) | P1 | All deps tree-shake well; total deferred bundle <250 KB before glTF assets |
| No Blender → glTF asset pipeline exists in fitme-story | P1 | Setup task: install `@gltf-transform/cli`, document Blender export preset (Draco + Meshopt + KTX2) |

## Acceptance Criteria

- [ ] `/framework` renders the autoplay 6-act cinematic in production on Vercel
- [ ] Lighthouse Performance score ≥95 on production `/framework` (mobile + desktop)
- [ ] 60fps measured on iPhone 12 + Pixel 6 (real device or BrowserStack proxy)
- [ ] WCAG 2.3.3 compliance verified: reduced-motion users get Tier 2 automatically
- [ ] All 6 acts have alt-text captions readable by screen readers
- [ ] All Stream A GA4 events fire on real user sessions (verified via DebugView)
- [ ] Operator mode at `/control-room/framework` shows live gate firings within 5s of event
- [ ] Tier 3 static fallback renders for `js: disabled` and saved-data
- [ ] Zero regression on existing `/framework/dispatch` and `/pm-flow` visuals
- [ ] At least one cross-repo PR-cite hover (Act IV) opens FT2's PR page on click

---

## Success Metrics & Measurement Plan

### Primary Metric

- **Metric:** Framework explainer comprehension rate — % of `/framework` visitors who (a) watch ≥80% of the cinematic AND (b) hover at least one labeled element AND (c) reach Act VI
- **Baseline:** 0% (feature doesn't exist; current `/framework/dispatch` has different success criteria)
- **Target:** ≥35% of sessions ≥30s reach the "engaged comprehension" threshold within 60 days of launch
- **Timeframe:** Measured starting day-of-launch; first review 7 days post-launch; full assessment at 60 days

**Why this metric:** The feature exists to make the framework legible. "Watched ≥80%" alone is passive consumption. "Hovered + reached final act" indicates active engagement with the content. The compound is a tractable proxy for comprehension. A T2 (Declared) metric pending Stream A instrumentation; once Stream A is wired and 30 days of data accrue, this becomes T1 (Instrumented).

### Secondary Metrics

| Metric | Baseline | Target | Instrumentation |
|---|---|---|---|
| Median session duration on `/framework` | 0s | ≥150s within 60 days | GA4 `engagement_time` on `framework_universe_session_end` |
| Cross-act hover diversity (avg unique labels hovered per engaged session) | 0 | ≥5 within 60 days | GA4 `framework_label_hover` event |
| Tier 2 / Tier 3 fallback rate (% of sessions degraded) | unknown | ≤8% target; alarm if >15% | GA4 `framework_tier_activated` event with tier parameter |
| `/control-room/framework` operator weekly engaged sessions | TBD baseline week 1 | +20% within 90 days | GA4 + UCC session telemetry |

### Guardrail Metrics

> These must NOT degrade when this feature ships.

| Metric | Current Value | Acceptable Range |
|---|---|---|
| Lighthouse Performance, `/framework` route | New route (N/A baseline) | Must score ≥95 on first prod build and remain ≥95 on every subsequent build (hard gate via `make verify-local` + CI lighthouse check) |
| Lighthouse Performance, sibling routes (`/`, `/pm-flow`, `/framework/dispatch`) | ≥95 today | Must stay ≥95 (no regression from shared bundle) |
| CLS, `/framework` | N/A | Must stay = 0 (3D scene mounts into fixed-height container) |
| LCP, `/framework` | N/A | Must stay ≤2.5s (3D is deferred; LCP is from non-3D hero section) |
| Existing visual regression on `/framework/dispatch` | 0 | 0 — scene must not affect or be affected by DispatchReplay |
| Server function invocation count on `/framework` (cost guardrail) | N/A | ≤2 per session (1 build-snapshot fetch + 1 optional live-subscribe init) |

### Leading Indicators

> Early signals measurable within 1 week of launch.

- ≥1000 unique `/framework` sessions in week 1 (validates routing + discoverability)
- ≥50% of sessions reach Act II within 1 week (validates Act I doesn't lose people)
- Tier 2 + Tier 3 fallback rate <15% in week 1 (validates Tier 1 device coverage)
- 0 Sentry errors with severity ≥warning attributable to 3D scene mount/unmount

### Lagging Indicators

> Long-term impact at 30/60/90 days.

- 30d: Primary comprehension metric ≥20% (interim target before 60d main target)
- 60d: Primary comprehension metric ≥35% (main target)
- 90d: ≥3 referrals in the wild (external blog / talk / hiring conversation that links to `/framework` as the "see how it works" explainer)
- 90d: Operator mode `/control-room/framework` has ≥10 weekly engaged operator sessions

### Instrumentation Plan

| Event/Metric | Method | Status |
|---|---|---|
| `framework_universe_session_start` | GA4 event on scene mount post-IntersectionObserver | Planned (Phase 5) |
| `framework_universe_act_reached` (param: `act_id` 1–6) | GA4 event per act boundary | Planned (Phase 5) |
| `framework_universe_session_end` (params: `final_act`, `engagement_time_ms`, `fallback_tier`) | GA4 event on unmount or page-hide | Planned (Phase 5) |
| `framework_label_hover` (params: `label_id`, `act_id`, `glossary_term`) | GA4 event with throttle (1 per label per session) | Planned (Phase 5) |
| `framework_scrub_seek` (params: `from_act`, `to_act`, `direction`) | GA4 event with debounce | Planned (Phase 5) |
| `framework_time_dilation_toggle` (param: `act_id`, `state`) | GA4 event | Planned (Phase 5) |
| `framework_replay_initiated` (param: `from_act`) | GA4 event | Planned (Phase 5) |
| `framework_tier_activated` (param: `tier` = 1 / 2 / 3, `reason`) | GA4 event on mount | Planned (Phase 5) |
| `framework_external_link_click` (param: `link_type` = pr / glossary / docs / commit, `href`) | GA4 event | Planned (Phase 5) |
| 60fps verification on iPhone 12 / Pixel 6 | Manual via BrowserStack / real device + WebVitals | Planned (Phase 5) |
| Build-time snapshot freshness | CI step + WebVitals on prod | Planned (Phase 5) |

### Analytics Spec (GA4 Event Definitions)

> Reference taxonomy: `fitme-story` does not have a Swift AnalyticsProvider (that's FT2). fitme-story uses Vercel Analytics + GA4 directly via `@vercel/analytics/next` and `@next/third-parties/google`. Event taxonomy lives in `fitme-story/src/lib/analytics-events.ts` (to be created if not present; otherwise extended).

**Naming convention reminder** (per FT2 CLAUDE.md "Analytics Naming Convention"): screen-scoped events MUST carry the screen prefix. All events below use `framework_` (the page is `/framework`).

#### New Events

| Event Name | Category | GA4 Type | Screen/Trigger | Parameters | Conversion? | Notes |
|---|---|---|---|---|---|---|
| `framework_universe_session_start` | Engagement | Custom | Scene mount post-IntersectionObserver on `/framework` | `tier_loaded` (1/2/3), `device_class` (mobile/tablet/desktop), `prefers_reduced_motion` (bool) | No | Fires once per page visit, after defer-loaded bundle has hydrated |
| `framework_universe_act_reached` | Engagement | Custom | Act boundary crossed during playback | `act_id` (1–6), `act_name` (string), `time_to_reach_ms` (int) | No | Throttled to once per act per session |
| `framework_universe_session_end` | Engagement | Custom | Component unmount or visibilitychange→hidden | `final_act` (1–6), `engagement_time_ms` (int), `fallback_tier` (1/2/3), `reached_engaged_comprehension` (bool) | Yes (Primary metric) | Conversion for the primary success metric |
| `framework_label_hover` | Engagement | Custom | Pointer or focus enters a labeled element | `label_id` (string ≤40 char), `act_id` (1–6), `glossary_term` (string or null) | No | Throttled: 1 per label_id per session to avoid hover spam |
| `framework_scrub_seek` | Engagement | Custom | User drags scrub bar or presses arrow keys | `from_act` (1–6), `to_act` (1–6), `direction` (forward/backward), `delta_seconds` (int) | No | Debounced 500ms to avoid drag-stream events |
| `framework_time_dilation_toggle` | Engagement | Custom | User presses time-dilation control | `act_id` (current act, 1–6), `state` (enabled/disabled) | No | |
| `framework_replay_initiated` | Engagement | Custom | User triggers "replay from start" | `from_act` (act they were in, 1–6) | No | |
| `framework_tier_activated` | Engagement | Custom | Component selects rendering tier on mount | `tier` (1/2/3), `reason` (default/reduced_motion/low_ram/saved_data/no_webgl/no_js) | No | Fires once per page visit |
| `framework_external_link_click` | Engagement | Custom | User clicks a contextual link from the scene | `link_type` (pr/glossary/docs/commit/case_study), `href` (string ≤100 char), `act_id` (1–6) | No | |

Total: 9 new events. All prefixed `framework_` per convention. All snake_case, all ≤40 chars.

#### New Parameters

| Parameter Name | Type | Allowed Values | Used By Events | Notes |
|---|---|---|---|---|
| `tier_loaded` | int | 1, 2, 3 | session_start | |
| `device_class` | string | mobile, tablet, desktop | session_start | Derived from viewport + UA |
| `prefers_reduced_motion` | bool | true, false | session_start | |
| `act_id` | int | 1–6 | act_reached, label_hover, scrub_seek (from/to), time_dilation, external_link_click | |
| `act_name` | string | threshold, conception, workshop_floor, gate_chain, shipping_telemetry, legacy_calibration | act_reached | snake_case act names ≤40 char |
| `time_to_reach_ms` | int | 0–600000 | act_reached | |
| `final_act` | int | 1–6 | session_end | |
| `engagement_time_ms` | int | 0–3600000 | session_end | Capped at 1h to avoid background-tab pollution |
| `fallback_tier` | int | 1, 2, 3 | session_end, tier_activated | |
| `reached_engaged_comprehension` | bool | true, false | session_end | Composite: ≥80% playback + ≥1 hover + final_act = 6 |
| `label_id` | string | ≤40 char identifier | label_hover | Stable IDs from scene metadata |
| `glossary_term` | string\|null | ≤40 char, matches glossary.ts key | label_hover | null if label has no glossary entry |
| `from_act` | int | 1–6 | scrub_seek, replay_initiated | |
| `to_act` | int | 1–6 | scrub_seek | |
| `direction` | string | forward, backward | scrub_seek | |
| `delta_seconds` | int | 0–600 | scrub_seek | |
| `state` | string | enabled, disabled | time_dilation_toggle | |
| `tier` | int | 1, 2, 3 | tier_activated | |
| `reason` | string | default, reduced_motion, low_ram, saved_data, no_webgl, no_js | tier_activated | |
| `link_type` | string | pr, glossary, docs, commit, case_study | external_link_click | |
| `href` | string | ≤100 char URL | external_link_click | |

Total: 21 new parameters.

#### New Screens (GA4 `screen_view` analog for fitme-story)

| Screen Name | View Name | Component | Category |
|---|---|---|---|
| `framework` (canonical) | Framework Universe | `<FrameworkUniverse>` from `src/components/bespoke/framework-universe/` | engagement |
| `control_room_framework` (existing — extended) | Control Room — Framework Health | extended to embed `<FrameworkUniverse mode="operator">` | operator |

#### New User Properties

| Property Name | Type | Values | Notes |
|---|---|---|---|
| `framework_universe_seen` | bool | true once after first session_end | Sticky cohort marker for retention analysis |
| `framework_universe_engaged_lifetime_count` | int | counter, cap at 50 | Heavy engagement cohort |

Total: 2 new user properties. fitme-story doesn't currently track custom user properties; this introduces the first two (well under the GA4 limit of 25).

#### Naming Validation Checklist
- [x] All event names: snake_case, ≤40 chars — all 9 verified
- [x] All parameter names: snake_case, ≤40 chars — all 21 verified
- [x] No reserved prefixes (ga_, firebase_, google_) — none used
- [x] No duplicate names — verified against `framework_*` namespace; no collision with existing `dispatch_*` or `lifecycle_*` events
- [x] No PII in any parameter — `href` is intentionally same-origin or known-external (PRs, glossary anchors); no user identifiers
- [x] ≤25 parameters per event — max event has 4 parameters
- [x] Total custom user properties still ≤25 — 0 → 2, well under limit
- [x] Parameter values spec'd to max 100 chars — `href` explicitly capped
- [x] Conversion event identified — `framework_universe_session_end` with `reached_engaged_comprehension: true`
- [x] Screen prefix convention followed — all events start with `framework_`

#### Files to Update During Implementation

- [ ] `fitme-story/src/lib/analytics-events.ts` — add 9 event names, 21 parameters, 2 user properties as typed const exports
- [ ] `fitme-story/src/lib/analytics.ts` (or equivalent) — add typed event-fire helpers
- [ ] `fitme-story/docs/analytics/taxonomy.md` (create if missing) — document new events + cross-reference with FT2 convention
- [ ] `fitme-story/src/app/control-room/framework/page.tsx` — embed `<FrameworkUniverse mode="operator">` + new "Visitor Comprehension" panel

### Review Cadence

- **First review:** 7 days post-launch (week-1 leading-indicator check)
- **Second review:** 30 days post-launch (interim primary metric, fallback-tier rate)
- **Third review:** 60 days post-launch (primary metric assessment vs target)
- **Ongoing:** Monthly through 90 days; then quarterly

### Kill Criteria

> When to revert or fundamentally rethink this feature.

1. **Performance kill:** Lighthouse Performance on `/framework` drops below 90 on any production build, OR sibling routes (`/`, `/pm-flow`, `/framework/dispatch`) regress below 95 because of shared bundle. Revert via `git revert` and serve Tier 3 static poster permanently while we diagnose.
2. **Adoption kill:** <100 unique sessions on `/framework` in the first 14 days post-launch (validates discoverability; if fewer, the route isn't reaching users at all — investigate routing/SEO before rebuilding).
3. **Comprehension kill:** Primary metric <15% at the 60-day review. Below half of target indicates the cinematic isn't actually building understanding — either content fails (re-script Acts II + IV) or 3D is wrong medium (consider re-skinning to Tier 2 Rive as canonical).
4. **Fallback-tier kill:** Tier 2 + Tier 3 fallback rate >25% sustained over 14 days. Indicates the Tier 1 device baseline (iPhone 12 / Pixel 6) is wrong for our actual visitor population — re-calibrate or invest in Tier 1 perf.
5. **Operator-mode disuse kill:** `/control-room/framework` 3D embed has <2 weekly operator sessions sustained for 4 weeks. Indicates dogfood angle doesn't land — keep public version, remove operator embed to reduce maintenance.

Kill criteria are independent: any one triggering forces a re-assessment, not an automatic revert. Kill 1 is the only hard-revert criterion; others trigger Phase 9 (Learn) reassessment.

---

## Key Files

| File | Purpose |
|---|---|
| `fitme-story/src/components/bespoke/framework-universe/FrameworkUniverse.tsx` | Main entry; mode prop = "visitor" \| "operator" |
| `fitme-story/src/components/bespoke/framework-universe/scenes/` | Per-act scene components (Act1-Threshold.tsx ... Act6-LegacyCalibration.tsx) |
| `fitme-story/src/components/bespoke/framework-universe/primitives/` | Procedural R3F primitives (chambers, terrain, signage, label-billboards) |
| `fitme-story/public/assets/3d/framework-universe/` | glTF hero pieces (`.glb` with Draco + Meshopt + KTX2) |
| `fitme-story/src/lib/motion-3d/primitives.ts` | Calibrated Isometric motion primitives (5 reusable, per research §3.4) |
| `fitme-story/src/lib/framework-snapshot.ts` | Build-time data layer (reads FT2 `.claude/shared/*.jsonl`) |
| `fitme-story/src/app/framework/page.tsx` | Route; lazy-loads `<FrameworkUniverse>` post-IntersectionObserver |
| `fitme-story/src/app/control-room/framework/page.tsx` | Operator mode; extends existing page |
| `fitme-story/src/lib/analytics-events.ts` | GA4 event + parameter typed exports |
| `fitme-story/scripts/sync-from-fittracker2.ts` | Extended to copy gate-coverage.jsonl + measurement-adoption-history.json into build snapshot |
| `fitme-story/scripts/check-bundle-size.ts` | New CI check; fails if `/framework` deferred bundle exceeds 350 KB compressed |

## Dependencies & Risks

| Dependency / Risk | Mitigation |
|---|---|
| First major 3D dependency add to fitme-story (R3F + Drei + Theatre.js + Three.js + Rive) | Tree-shake verified; all loaded via dynamic import; total deferred bundle <250 KB before assets |
| Three.js WebGPURenderer maturity | WebGL2 fallback is automatic since r171 (Sep 2025); no app code change required |
| Blender → glTF pipeline doesn't exist in fitme-story today | Phase 4 task: install `@gltf-transform/cli`; document Blender export preset; add CI lint for asset compression |
| Theatre.js Studio editor bundle (~150 KB) leaking into prod | Gated behind `process.env.NODE_ENV === 'development'` import; CI bundle-size check enforces |
| Live-data wiring breaking Lighthouse | Build-time snapshot is the default; client-side fetch is on-session-start fire-and-forget; no fetch blocks render |
| Visitor analytics privacy | All Stream A events are aggregate-only; no PII; opt-out via cookie consent banner (existing fitme-story mechanism) |
| Cross-repo coupling: requires FT2 `gate-coverage.jsonl` + `measurement-adoption-history.json` in build context | Already mirrored via existing `sync-from-fittracker2.ts` script; extend not introduce |
| Operator-mode duplicating scene code | Single component, `mode` prop branches data subscription only; scene code 100% shared |
| Launch window collision with HADF Phase 2-bis Block B sub-experiments (collection 2026-05-23 →) | Track A schedule explicitly avoids: PRD/Tasks/UX during v7.9 Phase E (2026-05-21 → 06-04); implement 06-04 → 06-15; ship pre-2026-06-18 |
| Reduced-motion users get a meaningfully different experience | By design per WCAG 2.3.3; Tier 2 (Rive) is a deliberate equal-information variant, not a degraded one |
| Scene complexity grows beyond what's tractable in one feature | Storyboard locked at 6 acts in research §5; expansion is a v2 feature, not in-scope |

## Estimated Effort

- **Total:** ~3 person-weeks of focused work (compatible with Track A window 2026-05-21 → 2026-06-18)
- **Breakdown:**
  - Phase 2 Tasks (~0.5d): finalize task list from PRD
  - Phase 3 UX + design preflight (~3–4d): mood board, scene composition, label inventory, motion choreography spec, glossary integration plan
  - Phase 4 Implementation (~8–10d):
    - 1d: dependency setup + dynamic import scaffolding + Tier 1/2/3 router
    - 2d: procedural shell primitives (chambers, terrain, signage) + Calibrated Isometric camera rig
    - 2–3d: Acts I–III scene composition (Threshold, Conception, Workshop Floor)
    - 2–3d: Acts IV–VI scene composition (Gate Chain, Shipping & Telemetry, Legacy / Calibration)
    - 1d: Theatre.js timeline authoring + scrub/time-dilation controls
    - 1d: Stream B live-data wiring (snapshot + client refresh)
    - 1d: Stream A GA4 instrumentation
    - 0.5d: Tier 2 Rive fallback authoring
    - 0.5d: Tier 3 static poster + caption track
  - Phase 5 Testing (~2d): Lighthouse runs, real-device 60fps verification, GA4 DebugView validation, regression on sibling routes
  - Phase 6 Review (~0.5d): pre-merge UX + design reviews
  - Phase 7 Merge + Phase 8 Documentation (~0.5d): showcase MDX, case study draft, taxonomy doc

### Hero glTF asset budget

- ≤6 hero pieces total across all 6 acts
- ≤200 KB each after Draco + Meshopt + KTX2 compression (target ≤150 KB ideal)
- Total compressed hero-asset budget: ≤1.2 MB (loaded lazily per act)

---

## Open questions deferred to subsequent phases

Captured in research dossier §7 (11 of 15 remain; 4 resolved in §7.A this phase). Listed here so they don't get lost:

| # | Question | Phase to resolve |
|---|---|---|
| Q3 | Performance budget hard limit = 0 KB initial JS (confirm). Recommendation in PRD: confirmed (§Acceptance Criteria #10). | Resolved here |
| Q4 | Live-data refresh strategy. Recommendation in PRD: build-time snapshot + on-session-start fetch (§Functional Req #6). | Resolved here |
| Q5 | Reduced-motion contract. Recommendation in PRD: Rive Tier 2 for reduced-motion, static Tier 3 for saved-data/no-JS (§Functional Req #4). | Resolved here |
| Q6 | Mobile target. Recommendation in PRD: 60fps iPhone 12 / Pixel 6 (§Functional Req #12). | Resolved here |
| Q7 | Glossary integration depth. Recommendation in PRD: every label with a glossary entry shows it (§Functional Req #9). | Resolved here |
| Q8 | Live-data privacy. Resolved: confirmed all sources public-safe; cookie-consent gate for Stream A. | Resolved here |
| Q9 | Showcase slot. Likely slot ~33 (v7.9 era). | Phase 8 Docs |
| Q11 | Theatre.js Studio gating. Resolved: `process.env.NODE_ENV === 'development'` import + CI bundle-size check. | Resolved here |
| Q12 | WebGPU opt-in timing. Resolved: day-1, since WebGL2 fallback is automatic. | Resolved here |
| Q13 | Operator-mode deployment. Resolved: share component code (§Functional Req #8). | Resolved here |
| Q14 | GA4 "Visitor Comprehension" panel at `/control-room/framework`. Resolved: yes, ship in same release. | Resolved here |
| Q3-route | Final route: `/framework` canonical OR `/framework/universe` sub-route? | Phase 3 UX |
| Q-extract | Should `<FrameworkUniverse>` be its own npm package eventually, for the Linear / hiring share-clip use case? | Phase 9 Learn (post-launch decision) |
