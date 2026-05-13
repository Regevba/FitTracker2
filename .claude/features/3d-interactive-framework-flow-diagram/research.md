# 3D Interactive Framework Flow Diagram — Phase 0 Research Dossier

**Feature:** `3d-interactive-framework-flow-diagram`
**Phase:** 0 — Research (in progress)
**Author:** Claude Opus 4.7 (1M context) — orchestrator at /Volumes/DevSSD/FitTracker2
**Date:** 2026-05-12 (revised per user scope directive)
**state_owner:** fitme-story (inaugural fitme-story-native feature; certified the v7.8.3 cross-repo round-trip)
**Framework version:** v7.8.3 (created 2026-05-11)
**Linear:** [FIT-138](https://linear.app/fitme-project/issue/FIT-138)
**Notion:** [3D Interactive Framework Flow Diagram — Public-Site Flagship Visual](https://www.notion.so/35e0e7a0eace81b5ba12eb6e6950da5a)

## TL;DR

**Standalone new flagship visual.** A ~3:15-minute cinematic animation experience that follows ONE feature through the framework's full lifecycle — conception, parallel dispatch, gate enforcement, shipping, and post-launch calibration. The visitor is a fly-on-the-wall observer in a 3D-rendered "framework universe" (architectural complex). Set apart from existing 2D visuals: the LifecycleLoop (orbital reference diagram) and DispatchReplay (beat-by-beat 2D replay) continue to operate unchanged at their existing routes; the 3D diagram lives alongside them at `/framework`, doing a fundamentally different job.

**Dual purpose:** (1) external explainer — make the framework legible to first-time visitors; (2) **internal instrumentation surface** — the visual is wired to live framework state (`gate-coverage.jsonl`, `measurement-adoption-history.json`, recent state.json mutations), so visitor engagement also generates measurement data about which concepts are clear vs confusing, and operators can use the same 3D scene from `/control-room/framework` to observe live framework health.

**Recommended primary stack:** React Three Fiber + Drei + Theatre.js + glTF (Draco + Meshopt + KTX2), dynamically imported with `ssr: false`, gated behind IntersectionObserver, Three.js WebGPURenderer with WebGL2 fallback (zero-config since r171, Sep 2025).

**Mandatory fallback cascade:**
- Tier 2 (reduced-motion or low-RAM mobile): Rive state machine (~16 KB file, GPU-accelerated)
- Tier 3 (saved-data, no-JS, ancient browser): `next/image` poster frame

**House motion language:** *Calibrated Isometric* — Kurzgesagt restraint + Ciechanowski reader-controlled time + 3blue1brown substrate-as-explanation discipline. Near-isometric orthographic camera (30°×45°), default to stillness, binary semantic color, persistent traces, time-dilation on demand.

**6-act cinematic arc:** Threshold → Conception → Workshop Floor → Gate Chain → Shipping & Telemetry → Legacy / Calibration.

---

## 1. The brief (revised 2026-05-12)

Build a **new standalone flagship interactive 3D visual** on the fitme-story public site that delivers a full animation experience of how the FitMe framework operates end-to-end. The feature also serves as a measurement instrument for the framework itself.

### 1.1 What this is

A ~3:15-minute cinematic 3D experience set in a "framework universe" — a rendered architectural space that visualizes the framework's mechanisms (gates, phases, dispatch, telemetry) as physical phenomena. Visitors enter, follow one feature's life from conception to shipped-and-learned-from, and exit having seen everything the framework does on a real feature.

The experience is interactive (scrub, pause, hover, time-dilate) but its **default state is a guided cinematic** — visitors who do nothing get the full story in linear playback. Visitors who engage get deeper inspection layers.

### 1.2 What this is NOT

- **Not an extension** of LifecycleLoop (existing 2D radial visual at `/pm-flow`). LifecycleLoop is a reference diagram; the 3D experience is a narrative.
- **Not an extension** of DispatchReplay (existing 2D scroll-driven replay at `/framework/dispatch`). DispatchReplay is feature-trace playback; the 3D experience is a universe-walkthrough.
- **Not a tutorial.** It does not teach you how to USE the framework. It teaches what it IS and how it BEHAVES.
- **Not a game.** No win-state, no goal, no playable character. Reader controls camera and time; nothing else.

The existing 2D visuals stay as-is. **Per user directive: "the orbit stays as is for now."** This is additive, not replacement.

### 1.3 Dual purpose — external + internal

| Purpose | Audience | What they get |
|---|---|---|
| External explainer | First-time fitme-story visitors, prospective developers, framework-curious operators | Cinematic ~3:15 walkthrough of framework operation; legible without prior knowledge |
| **Internal instrumentation surface** | The FT2 team using this very feature as a data-collection vehicle | (a) Visitor analytics revealing which framework concepts are clear vs confusing; (b) Live framework telemetry surfaced inside the scene so visitors see the actual heartbeat; (c) Operator-facing view from `/control-room/framework` showing live framework health in 3D space |

The instrumentation angle is **not a follow-up.** It's a v1 requirement. Section 5.5 details the wiring.

### 1.4 Constraints

- Lighthouse Performance: ≥**95** sustained (current bar). Hard constraint.
- WCAG 2.3.3 compliance for `prefers-reduced-motion`.
- Mobile target: 60fps on iPhone 12 / Pixel 6 (2026 mid-tier baseline).
- First major 3D dependency add to fitme-story (currently framer-motion only).
- Live-data wiring: must consume telemetry from FT2's `gate-coverage.jsonl`, `measurement-adoption-history.json`, and recent state.json mutations across both repos without breaking the Lighthouse budget.

---

## 2. Ecosystem context — existing fitme-story visuals (the 3D experience operates alongside, not replaces)

Cataloged so the new feature respects established vocabulary, color palette, and glossary conventions. **The 3D experience inherits these but does not extend or replace them.**

### 2.1 Canonical framework models the 3D scene must honor

Two canonical models are encoded in fitme-story code. The 3D experience uses the same phase IDs and floor levels (so labels are consistent across all visuals) but renders them in a fundamentally different geometric form.

**Model A — 10-phase lifecycle** (`src/lib/lifecycle-phases.ts`):

| ID | Order | Name | Primary skill |
|---|---|---|---|
| P0 | 0 | Research | research |
| P1 | 1 | PRD | pm-workflow |
| P2 | 2 | Tasks | pm-workflow |
| P3 | 3 | UX/Design | design |
| P4 | 4 | Implement | dev |
| P5 | 5 | Test | qa |
| P6 | 6 | Review | dev |
| P7 | 7 | Merge | release |
| P8 | 8 | Release | release |
| P9 | 9 | Learn | cx |

Rendered today by LifecycleLoop (2D radial). The 3D experience renders the same 10 phases as **a procession through 10 chambers** (Act II + Act III + Act IV span them) — explicitly **not** a 3D radial loop, so it doesn't compete with LifecycleLoop's orbital metaphor.

**Model B — 8-floor framework blueprint** (`src/components/bespoke/blueprint-data.ts`):

| Floor | Version | Layer | Accent |
|---|---|---|---|
| 1 | — | Shared State | `#4F46E5` indigo |
| 2 | — | Skills + Cache | `#10B981` emerald |
| 3 | v5.0 | SoC-on-Software | `#F59E0B` amber |
| 4 | v5.1 | Adaptive Batch | `#F97066` coral |
| 5 | v5.2 | Dispatch Intelligence | `#EC4899` pink |
| 6 | v6.0 | Measurement | `#A855F7` purple |
| 7 | v7.7 | Validity Closure | `#0EA5E9` sky |
| 8 | v7.8 | Bridge to v7.9 | `#06B6D4` cyan |

Rendered today by DispatchReplay (2D vertical stack with beat states). The 3D experience uses the same **eight color accents** to colorize the appropriate regions of the framework universe — when visitors are in the Dispatch Intelligence region, ambient lighting is pink (Floor 5 accent); when in the Measurement region, ambient is purple (Floor 6). But the architecture itself is **not a literal 8-floor building** — that's DispatchReplay's job. The 3D experience uses the floors as **chromatic regions** within a larger universe.

### 2.2 Existing flagship visuals (the 3D adds to, not duplicates)

| Existing visual | Route | What it does | What the 3D experience does instead |
|---|---|---|---|
| LifecycleLoop | `/pm-flow` | Static 2D radial diagram of 10-phase lifecycle + work-item types + feedback sources | Different geometry (procession through chambers, not orbit); different time scale (cinematic narrative, not reference); different purpose (storytelling, not documentation) |
| DispatchReplay | `/framework/dispatch` | 2D scroll-driven replay of one feature's beats across 8 floors | Different perspective (universe walkthrough, not floor-by-floor); different scope (full lifecycle, not just dispatch); different interactivity (cinematic + scrub + hover, not scroll-locked) |
| BlueprintOverlay | various case studies | Static 8-floor diagram | 3D ambient color regions reference the 8 floors but never depict the literal building |
| CacheTiers | various | 2D L1/L2/L3 visualization | Referenced inside Act III (workshop floor) as part of agent equipment |
| EvolutionStrip | various | Framework version timeline | Could be displayed as a horizon-line on the universe's ground plane (subtle reference) |

### 2.3 Other relevant existing components

- `<Term slug="...">` MDX glossary component — the 3D experience's labels reuse this for hover-reveal definitions
- `case-study-visual-aid-catalog.md` — the 3D experience becomes a new catalog entry at the bespoke tier
- Brand color tokens (`--color-brand-coral`, `--color-brand-indigo`) — the 3D experience uses these, not new colors

### 2.4 Existing tech stack

| Library | Version | Used by 3D experience? |
|---|---|---|
| `framer-motion` | ^12.38.0 | No (3D library replaces) |
| `next` | 16 | Yes (App Router) |
| `react` | 19 | Yes |
| `three` | — | **NEW (to be added)** |
| `@react-three/fiber` | — | **NEW** |
| `@react-three/drei` | — | **NEW** |
| `@theatre/core` / `@theatre/r3f` | — | **NEW** |

This is the first major 3D dependency add to fitme-story. Bundle hygiene + deferred-load discipline matter from day 1 (§4 + §6).

---

## 3. Stream 1 — Animation studio inspiration (summary)

Full write-up: `/tmp/3d-research-stream1-animation-studios.md` (~1,950 words).

### 3.1 Cinematic studio references (7 with timestamps)

| Ref | Studio · Film · Timestamp | Technique demonstrated | Maps to 3D experience element |
|---|---|---|---|
| R1 | Pixar — *Inside Out* (2015) · ~0:08–0:13:30 (memory orb pneumatic tubes) | Color-coded data flow through transport tubes; eye locks onto individual particles | Act V telemetry ribbons (cross-repo state sync particles) |
| R2 | Pixar — *Inside Out* (2015) · ~0:54–0:55:30 (Abstract Thought zone) | Deliberate dimensional reduction as didactic device — same object, 4 visual stages | Act II–IV feature morph (same feature, 10 representations) |
| R3 | DreamWorks — *How to Train Your Dragon* (2010) · ~0:46:30–0:50 (First Flight) | Camera language carries emotional state — straight tracking → s-curves → orbits | Act VI calibration camera language (s-curves through soak, orbits at analysis) |
| R4 | Blur Studio — *Dragon Tattoo* (2011) · 2:48 opening titles | Viscous black-on-black morphing; no cuts, only melts between forms | Act IV gate chain (gates melt into each other, never cut) |
| R5 | Studio Ghibli — *Spirited Away* (2001) · ~0:30–0:33 (bathhouse vertical traversal) | Spatial stratification teaches hierarchy without dialogue | Universe geography — 8 chromatic ambient regions (per blueprint floors) |
| R6 | Encyclopedia Pictura — Björk *Wanderlust* (2008) · 8-min full | Layered parallax depth as cognitive depth | Act III workshop floor (parallel agents in parallax planes) |
| R7 | Buck — IBM *Datagrams* (2013) · live data viz | Abstract motion synced to literal data — never decorative | Act V telemetry ribbons driven by real ledger data (key for instrumentation §5.5) |

### 3.2 Technical-explainer studio references (7)

| Ref | Creator | Key technique | Maps to |
|---|---|---|---|
| E1 | Kurzgesagt | Stillness earns motion — restraint as the whole game | Universe **idle state** between visitor sessions |
| E2 | 3blue1brown | Substrate is part of the explanation — grid bends, not states tween | Act IV gate field (gates deform the field, not block it) |
| E3 | Bartosz Ciechanowski | Reader-controlled time + fixed orthographic camera + WebGL canvases with sliders | **Single strongest reference** — Act II–V scrubbable timeline |
| E4 | Veritasium | Persistent traces as memory — time becomes spatial | Universe ambient — past dispatches glow faintly on the workshop floor |
| E5 | Nicky Case | Agent-based motion + active-reader principle | Act III workshop agents |
| E6 | MinutePhysics | Maximum communication, minimum chrome | Inspection panel UI when visitor pauses + clicks a gate/phase |
| E7 | Smarter Every Day | Time as a knob — same event illegible at 1×, teaches at 0.01× | Act IV time-dilation on gate hover (200ms → 6s) |

### 3.3 House motion language: *Calibrated Isometric*

1. **Default to stillness.** Universe opens static with one or two ambient pulses. Motion is earned by user attention or live telemetry events.
2. **Near-isometric camera** (30° elevation, 45° azimuth). Orthographic where feasible.
3. **Substrate is meaningful.** Ground plane carries information (hex-grid colored by `state_owner`).
4. **Color is binary semantic.** Active or scaffolding. Never decorate.
5. **Reader-controlled time.** Scrubber for the full 3:15 experience.
6. **Persistent traces.** Past events glow on the substrate.
7. **Time-dilation on demand.** Hover a gate → dilate 200ms event to 6s.

### 3.4 Five reusable motion primitives (live in `fitme-story/src/lib/motion-3d/primitives.ts`)

| Primitive | Use case in 3D experience |
|---|---|
| `fanOut` | Act III parallel dispatch — 5 agents radial burst |
| `tubeFlow` | Act V telemetry ribbons — cross-repo state sync |
| `gateRing` | Act IV gate chain — 25+ rings, pass/fail visual grammar |
| `phaseMorph` | Acts II–IV — feature object morphs through 10 SDF shapes |
| `calibrationOrbit` | Act VI — camera orbits the analysis moment |

### 3.5 Color palette

6 hues + 3 signal colors. Cyan (#22d3ee) = FT2 state_owner, magenta (#e879f9) = fitme-story state_owner. Pass/fail/advisory: #34d399 / #f87171 / #fbbf24. Full palette in /tmp file.

---

## 4. Stream 2 — Vercel-adapted 3D tool survey (summary)

Full write-up: `/tmp/3d-research-stream2-tool-survey.md` (~3,200 words). 14 tools evaluated against 8 weighted criteria.

### 4.1 Top-5 weighted matrix (subset)

| Rank | Tool | Score / 90 | Disposition |
|---|---|---|---|
| 1 | Lottie (dotLottie) | 88 | 2.5D only — disqualified for true 3D brief |
| 2 | Rive | 86 | **Recommended Tier 2 fallback** (reduced-motion + low-RAM mobile) |
| 3 | GSAP (post-Webflow free) | 86 | Free license post-Webflow; pairs with R3F for camera tweens |
| 4 | **R3F + Drei + Theatre.js** | 82 | **RECOMMENDED PRIMARY** for true 3D on Next.js 16 |
| 5 | Blender → glTF → R3F pipeline | 80 | Production technique layered on R3F (asset shrink 70–90%) |

### 4.2 Disqualified

- **Unity WebGL** (5–10 MB builds; breaks LCP)
- **Babylon.js** (~1.4 MB gzipped vs Three.js 168 KB)
- **Raw WebGPU** (eng cost dwarfs ROI for marketing-page hero)
- **Houdini Engine for web** (does not exist as browser runtime)
- **Spline runtime** (300+ KB; Lighthouse hit not justified)
- **PlayCanvas** (smaller ecosystem than R3F)

### 4.3 Recommended fallback cascade

```
Tier 1 (modern desktop + modern mobile):
  R3F + Drei + Theatre.js + glTF (Draco + Meshopt + KTX2)
  Renderer: Three.js WebGPU + WebGL2 fallback (zero-config since r171)
  Deferred via next/dynamic ssr:false + IntersectionObserver

Tier 2 (prefers-reduced-motion OR low-RAM mobile):
  Rive .riv (state machine, ~16 KB, GPU-accelerated)
  Renders simplified versions of Acts I + III only

Tier 3 (saved-data, no-JS, ancient browser):
  Static <Image priority /> poster frame of Act I (the framework universe wide-shot)
```

### 4.4 Critical Vercel-specific constraints

1. Three.js + R3F + Drei MUST be in a Client Component dynamically loaded with `ssr: false`. Module-scope import = build crash.
2. Theatre.js Studio dev-only — gate `process.env.NODE_ENV === 'development'`.
3. Edge runtime is the wrong target for 3D.
4. IntersectionObserver gating — don't download chunk until hero approaches viewport.
5. glTF prebuild pipeline (`gltf-transform --transform`) shrinks 5 MB → 500 KB–1 MB.
6. DPR cap `[1, 2]` + `frameloop="demand"` for mobile.
7. `prefers-reduced-motion` swap is mandatory.

### 4.5 Lighthouse budget reality

The ≥95 target is sustainable **only with strict dynamic-import + IntersectionObserver discipline.** Any deviation regresses Lighthouse below 95.

---

## 5. The 3D experience — 6-act cinematic structure

The experience runs ~3:15 in default linear playback. Interactive layers extend it indefinitely. Visitors who do nothing get the full story; visitors who engage get deeper inspection.

### 5.1 Universe geography

The 3D scene is a single continuous space — **the framework universe** — divided into 8 chromatic regions matching the 8-floor blueprint colors (per §2.1 Model B). Regions are not separate scenes; they're zones within one continuous universe the camera traverses.

The geography is **architectural-organic**, not literal industrial. Think: an observatory complex set in a vast desert, or a cathedral-as-laboratory hybrid. Specific architectural language deferred to the PRD phase (open question #2).

**Universe permanent elements:**
- **Ground plane** — hex-grid substrate colored by `state_owner` (cyan FT2 / magenta fitme-story, meeting at a center seam)
- **Sky** — deep navy `#0a1020` with faint constellation pattern of past framework versions (subtle EvolutionStrip nod)
- **Ambient telemetry layer** — Veritasium-style persistent traces (E4) overlay the entire universe; every past gate firing, every cache hit, every state.json mutation in the last 24h is a faint glowing dot on the substrate (this is the live-data wire-in, §5.5)

### 5.2 Act I — The Threshold (~15s)

**Camera:** Slow descent from sky-above to ~30° elevation. Wide shot of the framework universe.
**Action:** A single point of light winks into existence over the FT2 half — a new feature idea is born. Subtle ambient pulse propagates outward.
**Substrate:** All 8 chromatic regions glow faintly at their accent colors; ambient telemetry shows the last 24h of activity as a soft starfield.
**Sound (optional):** Single sustained tone, very low.
**Maps to:** Kurzgesagt restraint (E1) — universe is established as quiet before motion begins; viewer's attention is earned.

### 5.3 Act II — Conception (~30s)

**Camera:** Continuous dolly to the Research region (Floor 0 / no version yet — the universe's "atrium").
**Action:** The point of light materializes into a Research chamber. A research dossier scrolls into existence, then a PRD takes shape next to it. Multiple paths fork visibly; one is chosen (the decision moment) and the unchosen paths fade. The feature object is now a labeled cube — first solid form.
**Substrate:** The local hex grid pulses cyan as a state.json file is created.
**Interactive layer:** Hover the feature cube → glossary popover with feature definition + research stage spec.
**Maps to:** Pixar Abstract Thought (R2) for the dimensional reduction — same future-feature object, different representation per phase.

### 5.4 Act III — Workshop Floor (~45s)

**Camera:** Lateral dolly to the Dispatch Intelligence region (Floor 5 accent — pink ambient lighting).
**Action:** The feature cube enters a vast workshop floor. The `fanOut` primitive fires: 5 agent spheres burst from a central dispatch hub, each carrying a piece of the feature spec. Each agent settles at a workstation around the central hub. Agents work in parallel — surface texture shimmer indicates active editing.
**Persistent traces:** Faint glowing trails on the floor — past dispatches from the last 24h (Veritasium E4). Visitors see "this workshop has been busy" without being told.
**Camera detail:** Encyclopedia Pictura parallax layers (R6) — foreground = nearest agent, midground = sibling agents, background = the dispatch coordinator + shared state slab.
**Interactive layer:** Click any agent sphere → MinutePhysics-style inspector panel (E6) with the agent's tool budget, complexity score, model tier (haiku/sonnet/opus), and current task. Hover the dispatch hub → ambient pulse expands showing fan-out=5 setting; visitors can adjust to fan-out=2 / 10 and watch the workshop re-stage.
**Maps to:** Nicky Case (E5) — agent-based motion as system explanation.

### 5.5 Act IV — The Gate Chain (~45s)

**Camera:** S-curve dolly (DreamWorks R3) from the workshop region eastward through Validity Closure (Floor 7 accent — sky blue) and Bridge regions (Floor 8 accent — cyan).
**Action:** The completed feature object enters a long chain of chrome rings (~25 visible rings representing the 25+ active gates). Each ring is a `gateRing` primitive:
- Idle = thin cyan, 40% opacity
- Pass = scale 1.2× + green flash, ease-out-back 300ms
- Fail = ±4px shake + lock red, halts the chain mid-traversal

The gates "melt" between each other per Blur Studio (R4) — no cuts.

**Live-data wire-in:** The first ~7 visible gates show the **most recently fired** gate names from `gate-coverage.jsonl`. If `BRANCH_ISOLATION_VIOLATION` fired today, that's the first ring. If `FEATURE_CLOSURE_COMPLETENESS` was the most recent advisory, that's the second. The visitor sees which gates have actually been firing in the wild.

**Substrate:** Below the gate chain, a Veritasium-style timeline (E4) shows last-24h gate firings as colored dots. Green clusters = passes, red clusters = fails. Hover the timeline → time-dilation cursor lets visitor scrub through which gates fired when.

**Time dilation:** Hover any gate ring → camera locks; the per-commit fan-out (which runs in ~200ms in reality) dilates to ~6s. Per-gate detail unfolds: hook trigger → check → emission → resolution. Borrows Smarter Every Day (E7).

**Interactive layer:** Click a gate ring → MinutePhysics-style inspector with plain-language gate name, last fire timestamp, pass/fail rate (last 7d), source path. Glossary integration via `<Term>`.

**Maps to:** 3blue1brown grid-bending (E2) — gates deform the field, not block it; Blur Studio (R4) for visual continuity; Veritasium (E4) for the persistent-trace timeline.

### 5.6 Act V — Shipping & Telemetry (~30s)

**Camera:** Wide pull-back to reveal **both halves** of the universe substrate (cyan FT2 / magenta fitme-story).
**Action:** The feature object reaches the shipping bay — merges into a trunk lattice. The merge ripples outward: `tubeFlow` primitive lights up across the universe — colored particles travel through luminous tubes from FT2 to fitme-story (and back, for reverse-sync), each particle one state.json mutation, color = state_owner.
**Live-data wire-in (KEY):** Particle spawn rate = real measurement from `measurement-adoption-history.json` and recent state.json mutations. When `fully_adopted` ticks up, a geometric particle shape grows by exactly that proportion. Per Buck IBM Datagrams (R7) — animation magnitude tied to actual ledger data so the diagram is **honest, not decorative**.
**Substrate detail:** The seam where cyan meets magenta is a gate ring — this is `STATE_OWNER_LOCATION_MISMATCH`. Particles either pass through (green flash) or get rejected (red, returned to source).
**Universe view:** Camera pulls back further to show **every feature ever shipped** as a constellation of bright points across the universe. The just-shipped feature joins them — its place in the story is now permanent. (This is the EvolutionStrip + framework-version ledger visualized as cosmic geography.)
**Interactive layer:** Click any constellation point → that case study's MDX page opens in a new tab (deep-link to `/case-studies/<slot>`).
**Maps to:** Pixar memory orb pneumatic tubes (R1) — color-coded data flow with eye-locking on individual particles; Buck Datagrams (R7) for honest data-driven motion.

### 5.7 Act VI — Legacy / Calibration (~30s)

**Camera:** Slow orbit around an Analysis chamber in the Validity Closure region (Floor 7 accent — sky blue). Camera language switches from straight-tracking to `calibrationOrbit` per DreamWorks R3.
**Action:** Two abstract figures observe the telemetry from Act V: an operator silhouette and an agent silhouette. They run a calibration protocol: data is reviewed (substrate hex-grid lights up showing recent gate-coverage data); judgment is made; gates flip from advisory to enforced — the corresponding chrome rings glow slightly brighter.
**Phase-A-through-E indicator:** Faint ribbon along the orbit shows where in the Calibration Protocol the figures are (Phase A instrumentation → Phase B soak → Phase C analysis → Phase D decision → Phase E post-promotion validation).
**Coda:** Camera ascends back to sky-elevation. The framework universe persists. Another point of light winks in over the FT2 half — the next feature begins. The loop is unending.
**Interactive layer:** Click the operator silhouette → show the Calibration Protocol's current state (which gates are currently in Phase A advisory vs Phase D promoted). Hover the agent silhouette → list active features in research/PRD/tasks/implement phases.
**Maps to:** DreamWorks (R3) for the camera language — orbit at the human-judgment moment; Kurzgesagt (E1) for the held-frame ending.

### 5.8 Total runtime

| Act | Duration | Cumulative |
|---|---|---|
| I — Threshold | ~15s | 0:15 |
| II — Conception | ~30s | 0:45 |
| III — Workshop Floor | ~45s | 1:30 |
| IV — Gate Chain | ~45s | 2:15 |
| V — Shipping & Telemetry | ~30s | 2:45 |
| VI — Legacy / Calibration | ~30s | 3:15 |

Visitors who explore interactive layers (hover, click, time-dilate) extend the experience indefinitely.

### 5.9 Continuity rule

**No cuts between acts.** All six acts share one continuous camera path with Bezier-eased dollies between regions (~1000–1500ms transitions, ease-in-out-quart). The viewer always knows where they are in the universe because the geography stays visible — even when zoomed on Act IV's gate chain, the workshop region (Act III) is in peripheral view, and the constellation sky (Act V eventual) is overhead.

---

## 5.5 Framework instrumentation surface — the data-collection layer

This is the user-directive-mandated piece: the 3D experience must enable additional data collection about the framework itself. Three concurrent data streams flow through the visual.

### 5.5.1 Stream A — Visitor analytics (what concepts confuse people)

Every interaction in the 3D experience emits a GA4 event. Pattern: `framework_3d_<verb>` with structured parameters.

| Event name | Parameters | What we learn |
|---|---|---|
| `framework_3d_session_start` | `referrer`, `viewport`, `reduced_motion`, `tier` (1/2/3) | How many visitors enter; tier distribution |
| `framework_3d_act_entered` | `act` (1–6), `entered_at_seconds` | Drop-off curve through the experience |
| `framework_3d_act_completed` | `act`, `duration_seconds`, `interactive_engagements` (count) | How long visitors linger per act |
| `framework_3d_paused` | `act`, `paused_at_seconds` | Where visitors stop to look — confusion or interest? |
| `framework_3d_scrubbed` | `act`, `from_seconds`, `to_seconds`, `direction` | Re-watches = "I didn't understand"; skip-forwards = "I get it" |
| `framework_3d_gate_hovered` | `gate_name`, `hover_duration_seconds`, `time_dilated` (bool) | Which gates confuse people |
| `framework_3d_agent_clicked` | `agent_position` (1–5), `act` | Which workshop agents draw attention |
| `framework_3d_constellation_clicked` | `case_study_slot`, `act` (always V) | Which historical features visitors explore |
| `framework_3d_session_completed` | `total_duration_seconds`, `acts_visited` (count), `interactions` (count), `reached_act_6` (bool) | Funnel completion |
| `framework_3d_reduced_motion_swap` | `from_tier`, `to_tier`, `trigger` | How many users hit accessibility fallback |

**Insight extraction (dashboard at `/control-room/framework`):**
- Histogram of `framework_3d_paused` by `act` and `paused_at_seconds` → reveals **confusion hotspots**
- Re-watch rate per act → maps to concept difficulty
- Gate hover dwell-time histogram → identifies the gates that need plain-language docs
- Constellation click distribution → which historical case studies have visual pull

### 5.5.2 Stream B — Live framework telemetry (the universe IS the framework)

The 3D experience is not a static diorama. It is wired to live framework state.

| Universe element | Live data source | Update cadence |
|---|---|---|
| Constellation sky (past framework versions) | `EvolutionStrip` data + `state.json` complete-phase aggregates | At build time (refreshed per fitme-story deploy) |
| Workshop traces (Act III persistent dispatches) | Last 24h `cache-hits.json` + dispatch logs (subagent invocations) | Refresh on session start; static within session |
| Gate chain order (Act IV first ~7 rings) | Last 24h `gate-coverage.jsonl` — top 7 most-fired gate names | Refresh on session start |
| Timeline below gate chain | `gate-coverage.jsonl` last 24h, dot-plotted | Refresh on session start |
| Telemetry ribbons (Act V particle spawn rate) | `measurement-adoption-history.json` deltas | Refresh on session start |
| Constellation point density | Total complete-phase features per framework version | At build time |
| Calibration scene (Act VI which gates highlighted) | Current Phase A advisory list (from `gate-coverage.jsonl` advisory-only filter) | Refresh on session start |

**Data flow:** A build-time data fetcher (`fitme-story/src/lib/framework-3d-data.ts`) reads from the synced `.claude/shared/*.json` files (already mirrored cross-repo per v7.8.3 sync). Optionally, a runtime API route polls last-24h diffs on session start — bounded to ≤30 KB per response so it doesn't move the LCP needle.

**Privacy/security:** All exposed data is already public (framework gates, version history, advisory counts). No state.json contents are surfaced verbatim; only aggregates.

### 5.5.3 Stream C — Operator-facing view at `/control-room/framework`

The same 3D scene component (`<FrameworkUniverse3D />`) supports two render modes:

```tsx
<FrameworkUniverse3D mode="visitor" />   // public site cinematic experience
<FrameworkUniverse3D mode="operator" />  // operator dashboard, always-live data
```

In operator mode:
- Static linear playback is disabled; the universe is "live" — gates pulse when they actually fire
- Constellation sky updates as features complete
- Inspector panels show current values, not snapshots
- Visitor analytics events are not emitted
- Accessible only via UCC passkey auth at `/control-room/framework`

This reuses ~80% of the visitor-mode rendering code while adding a real-time data subscription layer.

### 5.5.4 Why this matters — the closing-the-loop argument

The framework's stated purpose is to make software engineering measurable and traceable. The 3D experience instruments **itself** as a measurement experiment:

- We learn which framework concepts are clear vs confusing (Stream A)
- We surface live framework operation to visitors (Stream B)
- We give operators a richer health-monitoring surface (Stream C)

This is the framework eating its own dog food at the public-site layer. It is also the most concrete near-term answer to the question "how do we know the framework is teaching what we say it teaches?"

---

## 6. Provisional tech stack decision

### 6.1 Primary stack (Tier 1)

```
npm packages:
  @react-three/fiber       — declarative R3F over Three.js
  @react-three/drei        — helper components (Canvas, useGLTF, Preload, etc.)
  three                    — Three.js renderer (using 'three/webgpu' import path)
  @theatre/core            — animation timeline engine
  @theatre/r3f             — R3F adapter
  @theatre/studio          — dev-only editor (gated on NODE_ENV)
  @gltf-transform/cli      — devDep, prebuild pipeline step
```

**Bundle budget (gzipped, all deferred / NOT in first-load):**
- @react-three/fiber: ~50 KB
- three (webgpu + core): ~168 KB
- @react-three/drei: 30–50 KB tree-shaken
- @theatre/core + @theatre/r3f: ~100 KB
- Application code + 3D scene model: ~30 KB
- **Total deferred chunk: ~378–398 KB**

**First-load impact: 0 KB** — everything is dynamic-import gated.

### 6.2 Tier 2 fallback (Rive)

```
npm packages:
  @rive-app/react-canvas
```

A simplified `.riv` file (~16 KB) renders Acts I + III only with no camera moves, just glyph transitions. State machine wired to scroll position. Activated when `prefers-reduced-motion: reduce` OR `navigator.deviceMemory < 4` (with UA-string fallback).

### 6.3 Tier 3 fallback (static poster)

`next/image` with `priority` and blur placeholder. Image is a high-resolution render of Act I's wide-shot of the framework universe. "Static view — click to load interactive version" affordance for visitors who can opt up.

### 6.4 Deployment pattern

```tsx
// app/framework/page.tsx (Server Component)
import dynamic from 'next/dynamic';
import { FrameworkPoster } from '@/components/framework-3d/FrameworkPoster';

const FrameworkUniverse3D = dynamic(
  () => import('@/components/framework-3d/FrameworkUniverse3D'),
  { ssr: false, loading: () => <FrameworkPoster /> }
);

export default function FrameworkPage() {
  return (
    <main>
      <FrameworkUniverse3D mode="visitor" />
      {/* below-the-fold static framework documentation */}
    </main>
  );
}
```

IntersectionObserver-gated inside the client component so the chunk doesn't download until the visitor scrolls toward the canvas. Theatre.js Studio import gated on `process.env.NODE_ENV === 'development'`.

### 6.5 Live-data wiring (per §5.5)

Build-time data fetcher reads from already-synced `.claude/shared/*.json` files (per v7.8.3 cross-repo sync contract). Bundled into the route as a JSON payload (~10–30 KB) at build time:

```tsx
// fitme-story/src/lib/framework-3d-data.ts
export async function getFrameworkSnapshot(): Promise<FrameworkSnapshot> {
  return {
    versions: await readEvolutionStripData(),
    recentGateFirings: await readRecentGateCoverage(24 /* hours */),
    measurementAdoption: await readMeasurementAdoption(),
    completedFeatures: await readCompletedFeatures(),
  };
}
```

Optional runtime API route `app/api/framework-snapshot/route.ts` for live operator-mode updates.

### 6.6 Asset pipeline

- Scenes authored in Blender (designer) OR built procedurally in code (developer) — open question for PRD
- Export to .glb
- Prebuild step: `gltf-transform --transform` (Draco + Meshopt + KTX2 BasisU)
- Drei `useGLTF` consumes optimized .glb

### 6.7 Performance instrumentation

- Vercel Speed Insights enabled
- GA4 events per §5.5.1 (taxonomy: `framework_3d_*` per project naming rule)
- Lighthouse CI run on every PR touching `app/framework/*`

---

## 7. Open questions for the PRD phase

These decisions require user judgment and are deferred to PRD:

1. **Architectural language of the universe.** Observatory-in-desert? Cathedral-laboratory? Studio Ghibli organic? Pixar clean-tech? Bones of the look are deferred to design exploration.
2. **Authoring split.** Designer builds in Blender → code consumes .glb. Or code builds procedurally with R3F primitives. Or hybrid. Affects timeline.
3. **Performance budget hard limit.** Maximum first-load JS for the framework page = 0 KB (fully deferred). Confirm.
4. **Live-data refresh strategy.** Build-time snapshot only, runtime polling on session start, or live WebSocket subscription? Recommendation: build-time + on-session-start fetch for v1; live WebSocket only for operator mode.
5. **Reduced-motion contract.** Static poster (Tier 3), simplified Rive (Tier 2), or simplified R3F (no camera moves)? Recommendation: Rive Tier 2 for reduced-motion (still interactive), static Tier 3 for saved-data/no-JS.
6. **Mobile target.** 60fps on iPhone 12 + Pixel 6 hard requirement? Affects DPR cap and frameloop config.
7. **Glossary integration depth.** Every label hover-reveals a glossary definition, or only "framework vocabulary" terms? Recommendation: every label that has a glossary entry shows it.
8. **Live-data privacy.** All current sources (`gate-coverage.jsonl`, `measurement-adoption-history.json`, completed-features list) are public-safe. Confirm no future expansion surfaces sensitive state.
9. **Showcase slot.** What slot number in `fitme-story/content/04-case-studies/`? Likely slot 32 or 33 (v7.8.x → v7.9 era).
10. **Concurrency with framework version chain.** Recommendation: research/PRD/UX during v7.9 Phase E (2026-05-21 → 06-04); implement parallel to v7.9.1 build; ship before v8.0 build window (2026-06-18).
11. **Theatre.js Studio gating.** Confirm `process.env.NODE_ENV === 'development'` gating eliminates the ~150 KB editor bundle from prod.
12. **WebGPU opt-in timing.** Day-1 (perf headroom) or post-launch (de-risk)? Recommendation: day-1 since WebGL2 fallback is automatic.
13. **Operator-mode deployment.** Share component code with visitor mode (recommended) or separate package? Affects bundle.
14. **GA4 dashboard.** Should `/control-room/framework` include a new "Visitor Comprehension" panel summarizing Stream A analytics? Recommendation: yes, ship in same release.
15. **Naming.** "Framework Universe", "Framework Flow", "How the Framework Works", "The Framework in Motion" (already taken by /framework/dispatch)? Naming deferred to PRD + marketing.

### 7.A Pre-PRD blocker resolutions (locked 2026-05-13)

Resolved before Phase 0 → Phase 1 transition. Remaining 11 questions defer to PRD drafting per user direction.

| # | Question | Resolution | Downstream effect |
|---|---|---|---|
| Q1 | Architectural language of the universe | **Pixar clean-tech** — bright, minimalist, slightly playful. Smooth curves + matte plastics + accent colors. Reads as "approachable, modern, friendly tech." Closest peers: Inside Out HQ, WALL-E BnL surfaces. | Phase 3 design exploration anchors on this mood board. Pairs naturally with the existing 8-region blueprint accents (indigo / emerald / amber / coral / etc.) from `blueprint-data.ts`. Disqualifies cathedral / observatory / Ghibli explorations. |
| Q2 | Authoring split | **Hybrid** — procedural R3F primitives for the architectural shell (chambers, walls, terrain, signage); Blender → glTF (.glb with Draco + Meshopt + KTX2) for hero pieces (signature instruments, gate machinery, hero props). | Asset pipeline scope: tasks include a Blender export workflow + .glb loading harness. Bundle budget allocates room for ~3–6 hero .glb files (target ≤200 KB each after compression). Procedural shell keeps base bundle small. |
| Q15 | Public name | **"Framework Universe"** | Route name pending PRD finalization (likely `/framework` canonical OR `/framework/universe` sub-route — to be settled in PRD §1). Marketing copy, Notion page title, and Linear epic title align on this name. |
| Q10 | Launch window | **Track A** — Phase 1 (PRD) + Phase 2 (Tasks) + Phase 3 (UX) during v7.9 Phase E (2026-05-21 → 2026-06-04); Phase 4 (Implement) parallel to v7.9.1 build; ship before v8.0 build window opens 2026-06-18. | Kill criteria timing anchors on these dates. Dependency: v7.9 promotion decision 2026-05-21 (informational, not blocking). Implementation must avoid blocking on the HADF Phase 2-bis Block B sub-experiments (collection earliest 2026-05-23). |

---

## 8. Decision summary (revised)

| Question | Decision | Rationale |
|---|---|---|
| Standalone or extension of existing? | **Standalone** | Per user directive — the orbit (LifecycleLoop) stays as is; this is a new flagship doing a different job |
| Single visual or animation experience? | **Full ~3:15 cinematic animation experience** | Per user directive — cinematic narrative, not interactive doc |
| Instrumentation surface? | **Yes — Streams A/B/C** | Per user directive — feature must enable additional data collection about the framework |
| Primary tech stack | R3F + Drei + Theatre.js + glTF | Best Vercel/Next.js 16 fit for true 3D; §4 matrix |
| House motion language | Calibrated Isometric | Restraint + reader-controlled time + binary semantic color |
| Number of acts | 6 (Threshold → Conception → Workshop Floor → Gate Chain → Shipping & Telemetry → Legacy/Calibration) | One feature's full journey; ~3:15 total |
| Universe model | 8 chromatic regions matching blueprint floor accents | Inherits vocabulary without competing with DispatchReplay's literal 8-floor stack |
| Page location | `/framework` (new canonical landing) | Existing `/framework/dispatch` + `/framework/dev-guide` stay as sub-routes |
| Live data wiring | Build-time snapshot + on-session-start fetch (operator mode adds live subscription) | Bounded LCP impact; framework dogfood at public surface |
| Performance contract | Lighthouse ≥95 | Strictly enforced via deferred dynamic import + IntersectionObserver |
| Accessibility contract | WCAG 2.3.3 honored via Rive Tier 2 + static Tier 3 fallbacks | Mandatory |

---

## 9. Source documents

**Stream outputs:**
- Stream 1: `/tmp/3d-research-stream1-animation-studios.md` (227 lines, ~1,950 words)
- Stream 2: `/tmp/3d-research-stream2-tool-survey.md` (378 lines, ~3,200 words)

**Key external references:**
- [Bartosz Ciechanowski — Internal Combustion Engine](https://ciechanow.ski/internal-combustion-engine/) — single strongest analog
- [Manim on GitHub](https://github.com/3b1b/manim)
- [Nicky Case — Explorable Explanations](https://blog.ncase.me/explorable-explanations/)
- [React Three Fiber docs](https://r3f.docs.pmnd.rs/getting-started/installation)
- [Theatre.js + R3F docs](https://www.theatrejs.com/docs/latest/extensions/react-three-fiber)
- [Three.js WebGPURenderer](https://threejs.org/docs/pages/WebGPURenderer.html)
- [Rive React runtime docs](https://rive.app/docs/runtimes/react/react)
- [WCAG 2.3.3 Animation from Interactions](https://www.w3.org/WAI/WCAG21/Understanding/animation-from-interactions.html)
- [Next.js Lazy Loading guide](https://nextjs.org/docs/pages/guides/lazy-loading)

**Existing fitme-story canonical models (vocabulary-only inheritance):**
- [src/lib/lifecycle-phases.ts](https://github.com/Regevba/fitme-story/blob/main/src/lib/lifecycle-phases.ts) — 10-phase IDs
- [src/components/bespoke/blueprint-data.ts](https://github.com/Regevba/fitme-story/blob/main/src/components/bespoke/blueprint-data.ts) — 8-region color accents
- [src/components/pm-flow/LifecycleLoop.tsx](https://github.com/Regevba/fitme-story/blob/main/src/components/pm-flow/LifecycleLoop.tsx) — **STAYS AS IS** per user directive
- [src/components/bespoke/DispatchReplay.tsx](https://github.com/Regevba/fitme-story/blob/main/src/components/bespoke/DispatchReplay.tsx) — STAYS AS IS
- [src/lib/glossary.ts](https://github.com/Regevba/fitme-story/blob/main/src/lib/glossary.ts) — 50+ terms; new 3D scene reuses `<Term>` MDX component

---

## 10. Phase 0 exit criteria

This dossier satisfies pm-workflow Phase 0 exit criteria, revised per 2026-05-12 user scope directive:

- [x] Decision (Section 8 revised) — standalone flagship; full animation experience; instrumentation surface
- [x] Tech feasibility (Section 4 + 6) — dependencies, bundle budget, browser support, Lighthouse strategy
- [x] Cinematic + technical-explainer references (Section 3 — 14 references)
- [x] Ecosystem context audit (Section 2 — existing fitme-story visuals catalogued; the 3D operates alongside, not replaces)
- [x] Storyboard for full animation experience (Section 5 — 6 acts, ~3:15 cinematic arc)
- [x] **Instrumentation surface specification (Section 5.5 — Streams A/B/C for data collection)**
- [x] Tech stack with deployment pattern (Section 6 + live-data wiring)
- [x] Open questions captured (Section 7 — 15 PRD-phase decisions)
- [x] House motion language + 5 motion primitives + color palette (Section 3.3 + 3.4 + 3.5)

**Ready for user approval to advance to Phase 1 (PRD).**
