# PRD: Framework Universe — 3D Interactive Framework Flow Diagram

> **Owner:** Regev (orchestrator: Claude Opus 4.7)
> **Date:** 2026-05-13
> **Last reconciled:** 2026-06-04 — v7.9.1 build window closed (8 ships, 14 PRs, 0 new gates); observed-patterns W1-W32 finalized; pattern↔skill preflight overlay operational
> **Phase:** 1 — PRD (v7.9.1 closure gate LIFTED 2026-06-04; Phase 2 advancement now pending OQ-1 + OQ-2 + OQ-3D-A resolution)
> **Status:** Draft — pause-compliant edits permitted (no Phase 1 → 2 advancement until OQs close)
> **Feature slug:** `3d-interactive-framework-flow-diagram`
> **Public name:** Framework Universe
> **Repo:** fitme-story (state_owner)
> **Framework version:** v7.8.3 (created); v7.9 promoted 2026-05-21 → Phase E PASSED 2026-06-04; **v7.9.1 CLOSED 2026-06-04** (8 ships, 0 new gates); ships under v7.9.x or v8.0

## CHANGELOG

### 2026-06-04 — v7.9.1 closure + pattern↔skill preflight overlay operationalization

- **Status:** Phase 1 pause gate LIFTED — v7.9.1 build window CLOSED 2026-06-04 (8 ships across 14 PRs: F16 try-repo harness + F17 last_fired_at index + F2 Phase 0 reality-check + Dev-env Track B + F-LAUNCHD-DRIFT-EXTENSION (b)+(c)+(a) + observed-patterns W29-W32 batch + F-PHASE-E-ADOPTION-FREEZE-DISCIPLINE + R9 Track B coverage aggregator + dev-env R11+R13+R14+R17+R18 hygiene batch + F-DEPLOYED-URL-PROBE FT2 substrate). **0 new enforcement gates** (Phase E exit discipline preserved). Synthesis case study: [`framework-v7-9-1-promotion-case-study.md`](../../../docs/case-studies/framework-v7-9-1-promotion-case-study.md).
- **Framework state finalized:** observed-patterns catalog at 55 work-blocking patterns (23 gate `#1`-`#23` + 32 workflow `W1`-`W32`) + 1 self-doc entry (W33 — overlay tool). CI workflows 8 → 14 (+6 warn-only). Mechanism letters unchanged at {A, B, C, D, E, F} (no G shipped).
- **NEW: pattern↔skill preflight overlay** — operational via PR #615 (this PR, rebased 2026-06-04). The catalog now ships with a **dual-purpose wiring**: (1) **dev-process preempt mechanism** — `make skill-preflight SKILL=<name>` runs the mechanized detectors + emits manual checklists for each skill's relevant patterns BEFORE work begins, instead of reactively when a gate fires mid-task; (2) **3D Universe overlay input** — `.claude/shared/pattern-skill-map.json` (55 entries) is the build-time source for FR-13 (Act III chamber annotations + Act IV gate-fire hover-reveals + LegoWall skill chips). The same map serves both purposes.
- **§3a NEW (inserted below)** — "Pattern↔skill preflight overlay dual-use case" documents the architecture choice (centralized JSON map + auto-generated SKILL.md blocks + warn-only `PATTERN_SKILL_UNMAPPED` advisory).
- **FR-13 NEW (inserted in §Functional Requirements):** "Pattern overlay on Acts III-V — display relevant observed-patterns entries as scene annotations, driven by `pattern-skill-map.json` and the `related_skills:` mapping."
- **Data input #5:** `.claude/integrity/observed-patterns.md` (markdown source) + `.claude/shared/pattern-skill-map.json` (typed JSON) → aggregated to `src/data/framework/observed-patterns.json` + `src/data/framework/skills-patterns-map.json` at fitme-story build time.
- **OQ status:**
  - **OQ-1** (acceptance criterion 10 deterministic phrasing) — still open; ~15 min operator work
  - **OQ-2** (`feature-roster.json` aggregator contract) — still open; ~30-45 min operator work
  - **OQ-3** (Alternatives Considered backfill) — deferred (parallel with Phase 2 tasks.md drafting)
  - **OQ-3D-A** (operator labels `related_skills:` frontmatter across 55 patterns) — **RESOLVED 2026-06-04** via this PR (`pattern-skill-map.json::skills[]` is the canonical mapping; per-pattern `related_skills:` frontmatter inside observed-patterns.md is the read-path; both kept in lockstep via `PATTERN_SKILL_UNMAPPED` advisory)
- **PRD sections modified by this changelog:** Header (above), §Data Contracts (around line 330), §Functional Requirements, §Key Files, §Acceptance Criteria, §Open Questions.
- **Remaining Phase 2 unblocker:** OQ-1 + OQ-2 (~45-60 min total operator work)
> **Live framework data:** [`docs/framework/versions.json`](../../../docs/framework/versions.json) — single source of truth for gate counts, mechanism list, version timeline (see §Data Contracts & Modularity)
> **Linear:** [FIT-138](https://linear.app/fitme-project/issue/FIT-138)
> **Notion:** [3D Interactive Framework Flow Diagram — Public-Site Flagship Visual](https://www.notion.so/35e0e7a0eace81b5ba12eb6e6950da5a)
> **Research dossier:** [`research.md`](./research.md) (597 lines, shipped FT2 PR #324)

---

## Purpose

A standalone ~3:15-minute cinematic 3D walkthrough of how the FitMe framework operates end-to-end on a single feature's lifecycle — published on the fitme-story public site at `/framework` as the flagship explainer, and simultaneously wired as a **measurement instrument** that surfaces live framework telemetry to visitors and operators.

## Business Objective

The framework's complexity (60+ features, ~36+ gates and advisories across write-time + cycle-time + permanent-advisory layers, 6 cooperating Mechanisms A–F, T1/T2/T3 data quality tiers, 10-phase lifecycle) is hard to grasp from prose alone. Live counts in [`docs/framework/versions.json`](../../../docs/framework/versions.json) (the Universe reads from this — see §Data Contracts & Modularity). Two existing 2D visuals — `LifecycleLoop` (orbital reference at `/pm-flow`) and `DispatchReplay` (scrollytelling at `/framework/dispatch`) — establish framework legibility but neither delivers a **narrative end-to-end view**.

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
| 6 | Live-data wiring (Stream B) | Planned | Build-time snapshot of **four typed data inputs** (see §Data Contracts & Modularity for the full contract): `docs/framework/versions.json` (timeline + counts), `.claude/features/*/state.json` (feature roster → Act VI monuments), `.claude/shared/measurement-adoption.json` (Act V adoption bars), `.claude/logs/gate-coverage.jsonl` (Act IV gate firings, operator mode only). On-session-start client fetch for freshness. |
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
| `fitme-story/src/lib/framework-snapshot.ts` | Build-time data layer; reads the four mirrored inputs from `src/data/framework/` |
| `fitme-story/src/data/framework/versions.json` | Build-time mirror of FT2 `docs/framework/versions.json` (see §Data Contracts & Modularity) |
| `fitme-story/src/data/framework/feature-roster.json` | Build-time aggregate of FT2 `.claude/features/*/state.json` (slug + status + phase + version) |
| `fitme-story/src/data/framework/adoption-snapshot.json` | Build-time mirror of FT2 `.claude/shared/measurement-adoption.json` |
| `fitme-story/src/data/integrity/gate-coverage-ft2.jsonl` | Build-time mirror of FT2 `.claude/logs/gate-coverage.jsonl` (already exists per v7.8.3 Phase 1) |
| `fitme-story/src/app/framework/page.tsx` | Route; lazy-loads `<FrameworkUniverse>` post-IntersectionObserver |
| `fitme-story/src/app/control-room/framework/page.tsx` | Operator mode; extends existing page |
| `fitme-story/src/lib/analytics-events.ts` | GA4 event + parameter typed exports |
| `fitme-story/scripts/sync-from-fittracker2.ts` | Extended (Phase 4 task) to mirror versions.json + aggregate feature-roster.json + copy adoption-snapshot.json |
| `fitme-story/scripts/check-bundle-size.ts` | New CI check; fails if `/framework` deferred bundle exceeds 350 KB compressed |
| `FT2:docs/framework/versions.json` | **Canonical framework timeline + gate counts + mechanism list + phase IDs.** Read by every consumer; updated in every framework-version-ship PR. |

## Data Contracts & Modularity

> **Added 2026-05-28** as part of the v7.9 → v7.9.1 reconciliation pass.
> Resolves operator requirement: "every time the framework advances, the
> feature should reflect the changes without rebuilding from scratch."

This feature visualizes the framework itself. The framework changes — new
gates ship, mechanisms get promoted from advisory to enforced, features
graduate from `paused` to `complete`, mechanism letters extend past F.
To avoid rebuilding the Universe each time the framework advances, every
scene element that depends on framework state reads from a **typed data
contract**, never from hand-coded constants.

### ⚠️ Pre-Phase-2 data-aggregation gate (added 2026-06-03)

**Phase 1 → Phase 2 advancement is gated on a fresh re-inspection of every data input below.** The 2026-05-28 schema sketch is correct in *shape* but the data it references will move materially between now (2026-06-03, Phase E day 13) and Phase 2 start. The framework state ⇒ Universe scene mapping cannot be locked until the snapshots below are re-captured against the actually-shipped post-Phase-E + v7.9.1 platform.

**Three things must be inspected + aggregated BEFORE Phase 2 begins:**

#### 1. Post-Phase-E framework state (snapshot trigger: ~2026-06-04 Phase E exit)

The 2026-05-12 → 2026-06-04 calibration window will close. The Universe's Act II timeline (version chain) + Act IV (gate firings) + Act V (adoption %) + Act VI (feature monuments) all depend on data that's still in motion:

| What needs re-inspection | Why it shifts at Phase E exit |
|---|---|
| `docs/framework/versions.json` (canonical timeline) | v7.9 promotion outcome documented; v7.9.1 build window opens; mechanism list bumps from {A, B, C, D, E, F} possibly to {A–G} or with promotion deltas |
| `.claude/features/*/state.json` (feature roster, currently 85) | D1 + C2 + C3 + C5 + C6 closed today (+5 complete); trend-alerts-hrv may complete; HADF Sub-exp 1B v2 + 3 verdicts may land. Roster count + status mix changes by ≥5–10 features |
| `.claude/shared/measurement-adoption.json` (Act V bars) | The denominator-dilution issue documented in framework-v7-9-promotion §99.2 (process regressions in `adoption_pct_post_v6`, `timing_wall_time_pct_post_v6`, `cache_hits_pct_post_v6` observed 2026-05-28 are denominator effects from +9 features added during Phase E without adoption metrics backfilled). v7.9.1 backfill is a queued follow-up; the Universe should not freeze on the dilution baseline |
| `.claude/logs/gate-coverage.jsonl` (Act IV live stream) | Promoted gates (BRANCH_ISOLATION_VIOLATION Mode B + Mode C + FEATURE_CLOSURE_COMPLETENESS) start producing real enforcement firings post-promotion. Pre-Phase-E telemetry is advisory-mode only; Universe rendering needs the enforced-mode firings for Act IV's gravity to be accurate |

**Operator action when Phase E exits:** run `make daily-checkpoint --force` + `make integrity-diff` + `make measurement-adoption` + `make documentation-debt` on the day Phase E officially ends; commit the snapshot deltas; only then re-open this PRD for Phase 1 → 2 advancement.

#### 2. Post-v7.9.1 framework state (snapshot trigger: v7.9.1 ship)

v7.9.1 (Test Discipline Foundation per Notion page, ships 2026-06-04 → 06-11 window) introduces F-candidates that the Universe must visualize correctly:

- Promoted advisories (the v7.9.1 docket per `docs/master-plan/post-v7-9-candidate-plan-2026-05-20.md`)
- Per-skill gate-coverage telemetry (new keys land in `gate-coverage.jsonl`)
- Possible new mechanism letter (G, if shipped)
- The pm-workflow three-option auto-dispatch heuristic (PR #600, shipped 2026-06-03) will produce its own gate-coverage events: `pm_workflow.three_option_auto_dispatch` — the Universe should surface this in Act IV alongside the other gate firings

**Operator action when v7.9.1 ships:** re-aggregate `versions.json` against the v7.9.1 release notes; verify the data contract still holds (new gates / mechanisms don't require schema-changes to the input files, only data additions).

#### 3. NEW input — Observed Patterns Catalog → skill overlay

The Universe's Act IV (gate firings) and Act III (chambers / skill phases) currently model "skill X owns phase Y" + "gate Z fires when conditions met." **What's missing:** the catalog of *patterns* that operators use to interpret gate firings — `.claude/integrity/observed-patterns.md` (23 gate patterns `#1..#23` + 28 workflow patterns `W1..W28+` as of 2026-06-03). This catalog is what closes the loop between "a gate fired" and "what the operator does about it."

The new 5th data input the Universe must consume:

| Input file (FT2 source) | What the Universe reads from it | Mirror destination (fitme-story) |
|---|---|---|
| `.claude/integrity/observed-patterns.md` | Per-pattern remediation overlay on Act IV gate firings: when a gate fires in operator mode, hover surfaces the matching catalog entry (#N gate-pattern or Wn workflow-pattern) with its short description + cross-link to the catalog. Provides the "what to do about it" layer the existing scene shape doesn't model. | `src/data/framework/observed-patterns.json` (build-time aggregate — parse the markdown into a typed JSON: `{ id, kind: "gate" \| "workflow", code?, title, gist, fixed_in?, severity, ucc_correlation }[]`) |

This is a substantive scene addition, not a one-line overlay. Implication for the existing scenes:

- **Act III (Chambers):** each phase chamber currently shows the skill that owns the phase; should ALSO surface the patterns that fire most often in that phase (e.g. Phase 9 chamber shows `#1 BRANCH_ISOLATION_HISTORICAL` + `#15 PARTIAL_SHIP_TERMINAL` as "common patterns observed at this phase")
- **Act IV (Gate firings):** each gate-fire bubble currently has gate code + commit ref + timestamp; should ALSO display the matching `#N` catalog entry as a hover-revealed annotation, with a Tier-2 fallback (text-only annotation if 3D label-billboard exceeds budget)
- **Act V (Adoption bars):** the W-pattern workflow catalog should drive a parallel rendering — workflow patterns are NOT gate firings; they're operator process patterns (`W1` ssh-agent unloaded, `W9` branch-drift, `W18` og-image 404, `W28` CoreSim env-flake). These are emerging signals; Act V should show their cumulative count alongside adoption % to indicate "framework maturity comes from W-pattern accumulation, not just gate firings"
- **Skill chips on the LegoWall (cross-Act):** each skill (per `fitme-story/src/lib/skill-ecosystem.ts`) should surface its 2–4 most relevant observed patterns as a hover-revealed list. This closes the loop from skill description → typical failure modes the skill watches for. Highest-leverage examples:
  - `/pm-workflow` → `W1 ssh-agent unloaded`, `W2 publish verbatim then remediate`, `W6 measurement case-study impartiality`, `#15 PARTIAL_SHIP_TERMINAL`
  - `/brainstorm-pm` → `W2`, `W6`, `#17 CU_V2_INVALID`
  - `/dev` + `/qa` → `#1`, `#3`, `#4`, `#11`
  - `/cx` → `#16`, `#18`, `W2`
  - `/release` → `#15`, `W4` (Vercel build cache stale), `W7` (Lighthouse SEO false-positive)

**Aggregator contract for `observed-patterns.json`** (defines the new sync step in `fitme-story/scripts/sync-from-fittracker2.ts` Phase 4 task):

- **Input:** `.claude/integrity/observed-patterns.md` (markdown source on FT2 main)
- **Parser:** regex extraction of `### #N <CODE> — <title>` (gate patterns) + `### Wn <CODE> — <title>` (workflow patterns) → flat array; preserves the order in the source markdown so the Universe can use array index as render priority
- **Output schema:** `{ schema_version: "1.0.0", patterns: [ { id: "#1" \| "W9" \| ..., kind: "gate" \| "workflow", code?: "BRANCH_ISOLATION_HISTORICAL", title: "...", gist: "first sentence of the body", fixed_in?: "PR #317" \| "v7.7 honesty fixes" \| null, severity: "advisory" \| "blocking" \| "narrowed" \| "informational", related_skill_slugs: [ "pm-workflow", "dev", ... ] (derived heuristically — operator review required at lock) }, ... ] }`
- **Stability guarantee:** array order is stable across runs (source-markdown order); deltas detected via field-by-field diff
- **Privacy:** no operator commit SHAs leak (the catalog body cites commits; the JSON aggregate strips them to keep the build artifact pseudo-public)
- **Build trigger:** any modification to `observed-patterns.md` triggers re-aggregation; the existing pre-build sync detects this via mtime comparison

**Open question for the aggregator** (must close before Phase 2 task drafting): the `related_skill_slugs[]` field is partly subjective (e.g. is `W1` ssh-agent related to `/pm-workflow` or to `/dev`?). Two paths:

- Path A: operator manually labels each pattern with `related_skills:` frontmatter directly in `observed-patterns.md` — single source of truth, deterministic. Requires a one-time backfill pass against the current 23 + 28 patterns.
- Path B: aggregator infers from pattern context (regex match on gate code → skill that owns the gate). Less labor but more brittle.

Recommend Path A for the v1 (forward stability matters more than the one-time backfill cost). Locked in PRD §"Open Questions" as **OQ-3D-A: Operator labels `related_skills:` frontmatter in observed-patterns.md before Phase 2 advances**.

### After all 3 aggregations land

Re-run [`prd-review-2026-06-03.md`](prd-review-2026-06-03.md)'s dimension assessment with the fresh snapshots; close OQ-1 + OQ-2 + OQ-3 + OQ-3D-A; THEN advance Phase 1 → Phase 2.

### Source-of-truth → consumer flow

```
FT2 source files                       fitme-story sync                       Universe scene
─────────────────                      ──────────────────                     ──────────────
docs/framework/versions.json ──┐                                              versions.ts
.claude/features/*/state.json ─┼──► scripts/sync-from-fittracker2.ts ──┬──► framework-snapshot.ts
.claude/shared/                │                                       │      (typed module)
  measurement-adoption.json ───┤                                       │
.claude/logs/                  │                                       └──► gate-coverage.ts
  gate-coverage.jsonl ─────────┘                                              (operator stream)
```

### The four data inputs

| Input file (FT2 source) | What the Universe reads from it | Mirror destination (fitme-story) |
|---|---|---|
| `docs/framework/versions.json` | Version timeline (Act II), mechanism list (Act IV), gate counts (Act IV signage), phase IDs (Act III chambers), data-quality tiers (Act V), work-type funnel widths | `src/data/framework/versions.json` (build-time copy) |
| `.claude/features/*/state.json` (62 files) | Feature monuments in Act VI; status (`complete`/`paused`/`in_progress`) drives monument material; framework_version drives placement on Act II timeline | `src/data/framework/feature-roster.json` (build-time aggregate) |
| `.claude/shared/measurement-adoption.json` | Adoption % bars in Act V; per-dimension trend lines (`cache_hits`, `cu_v2`, `fully_adopted_post_v6`) | `src/data/framework/adoption-snapshot.json` (build-time copy) |
| `.claude/logs/gate-coverage.jsonl` | Live gate-firing bursts in Act IV (operator mode only); attribution to specific commits | `src/data/integrity/gate-coverage-ft2.jsonl` (already mirrored per v7.8.3 Phase 1) |

### `docs/framework/versions.json` schema (v1.0.0)

The canonical machine-readable framework timeline. Lives in FT2; mirrored
to fitme-story at build. Schema versioned via the top-level `schema_version`
field — consumers MUST check it before reading.

Top-level keys:

- `schema_version` (semver) — bump major on breaking changes
- `last_reconciled` (ISO date) — when a human last walked the file
- `reconciled_by` (string) — name the PR or process that last touched it
- `current` — `{ version, shipped_at, status, phase_e_started, phase_e_ends, case_study_path, pr_number }`
- `next` — `{ version, status, candidates[], expected_ship_window, v8_window_opens }`
- `stats` — `{ write_time_gates, cycle_time_gates, advisory_gates, mechanisms[], lifecycle_phases, data_quality_tiers, active_features_with_phase, complete_features }`
- `timeline[]` — every version `{ version, ship_date, label, status, pr_number?, case_study_path? }`
- `gates_flipped_at_v7_9[]` — record of v7.9-specific advisory→enforced promotions
- `gates_already_enforced_pre_v7_9[]` — context for the timeline
- `gates_intentionally_advisory_permanent[]` — semantic distinction (matters in Act IV mood)
- `mechanisms[]` — `{ id, label, introduced_at, status, advisory_window_ends?, extended_at? }`
- `phases[]` — `{ id, name }` (the lifecycle funnel — drives Act III chamber count)
- `work_types[]` — `{ id, phases[], label }` (Feature / Enhancement / Fix / Chore — drives funnel-width variants)
- `data_quality_tiers[]` — `{ tier, label }` (T1/T2/T3)
- `consumers[]` — every place that reads from this file; adding a consumer requires updating this list (forces architectural awareness)
- `source_of_truth_pointers` — paths back to the FT2 source files this JSON is derived from (audit trail)
- `update_protocol` — when/what/how to update this file when the framework advances

### What happens when the framework advances

| Framework change | What must be edited | What auto-propagates |
|---|---|---|
| New gate ships | `versions.json`: `stats.{write_time,cycle_time,advisory}_gates` + `timeline[]` entry | All Universe signage, gate-count overlays, version pill, glossary chip |
| Mechanism G ships | `versions.json`: `mechanisms[]` + `stats.mechanisms[]` | Act IV mechanism markers, dev-guide page, dropdown filter on /control-room |
| New version ships | `versions.json`: `current` block + `timeline[]` entry + `next` block updated | Version timeline scene, latest-version overlay, all version pills site-wide |
| Feature graduates `paused` → `complete` | Nothing — `state.json` is the source; sync picks it up | Act VI monument materializes; feature-count stats update |
| Adoption % moves | Nothing — `measurement-adoption.json` is the source; sync picks it up | Act V adoption bars |
| Gate fires in production | Nothing — `gate-coverage.jsonl` appends; live stream picks it up | Operator-mode bursts of light (Stream C) |

> Only the first three rows require a manual edit. Authors of any v7.9.2 /
> v8.0 / v9.0 framework change MUST update `versions.json` as part of their
> ship checklist — this becomes a checklist item in
> [`docs/architecture/feature-lifecycle-event-catalog.md`](../../../docs/architecture/feature-lifecycle-event-catalog.md)
> Phase 8 Documentation.

### Build-pipeline extension (Phase 4 task)

`fitme-story/scripts/sync-from-fittracker2.ts` already mirrors
`.claude/shared/*.json` and `state.json` files (per v7.8.3 Phase 1). Phase 4
of this feature extends the script with four additional steps:

1. Copy `FT2/docs/framework/versions.json` → `fitme-story/src/data/framework/versions.json`
2. Aggregate every FT2 `state.json` into `fitme-story/src/data/framework/feature-roster.json` (just `{slug, name, status, current_phase, framework_version, state_owner, has_case_study}`)
3. Copy `FT2/.claude/shared/measurement-adoption.json` → `fitme-story/src/data/framework/adoption-snapshot.json`
4. Generate TypeScript types from `versions.json` schema and compile-time-validate the synced data (errors abort the build)

A 5th step adds a CI gate: a fitme-story PR cannot merge if `versions.json`
references a version not present in `.claude/shared/measurement-adoption.json`
or `docs/case-studies/`. Prevents the most likely modularity failure: timeline
entry added, supporting evidence missing.

### Anti-pattern: hand-coded gate counts in MDX

The current `/framework/dev-guide` page and several case study showcases
hand-code numbers like "25 gates" or "16 cycle-time checks". As part of this
feature's Phase 4, those literals get replaced with `<GateCount kind="write_time" />`
React components that read from `versions.json`. The value shown is always
whatever the synced JSON says on last build — no drift between docs and reality.

The PRD's own Business Objective section (above) already uses parameterized
phrasing ("~36+ gates and advisories ... live counts in versions.json") as
a deliberate example of the pattern.

### Future modularity (v2 considerations, out of scope here)

- A version-history *content* field per timeline entry (markdown blob explaining what changed) — would let the Universe surface inline tooltips. Deferred to v2 because case studies already serve this role and re-encoding them in JSON is duplicative.
- Live WebSocket subscription on `versions.json` changes — overkill; rebuilds-on-deploy are enough.
- A formal RFC process for breaking schema changes — defer until first breaking change is needed.
- Cross-repo write path (fitme-story-authored versions.json edits propagating back to FT2) — explicitly not supported; versions.json is FT2-authoritative per the v7.8.2 cross-repo asymmetry policy.

### Compliance with pause rule

Adding this section advances PRD *content* but does not transition
`state.json::current_phase` from `prd`. Operator pause decision 2026-05-19
forbids Phase 1 → Phase 2 advancement until v7.9.1 closes (~2026-06-04).
This edit is pause-compliant. No `current_phase` mutation; PRD approval gate
remains held.

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
| Launch window collision with HADF Phase 2-bis Block B sub-experiments (Sub-exp 1A launched 2026-05-25; Sub-exps 2 + 3 prereg shipped 2026-05-27) | **Superseded 2026-05-19:** entire feature paused at Phase 1 PRD-draft until v7.9.1 closes (~2026-06-04). Original Track A (PRD/Tasks/UX during Phase E, implement 06-04 → 06-15) collapsed into post-v7.9.1 compressed timeline. Ship target remains pre-2026-06-18 v8.0 window; tradeoff accepted for v7.9 calibration purity. |
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
