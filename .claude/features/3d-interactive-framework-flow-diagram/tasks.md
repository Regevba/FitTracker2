# 3D Framework Universe — Phase 2 Tasks (Phase 4 implementation breakdown)

> Drafted 2026-06-05 during the 3D Phase 2 (Tasks) opening session.
> Predecessor: [`prd.md`](./prd.md) (Phase 1 closed 2026-06-04 via PR #630).
> Successor: Phase 4 (Implement) opens once this tasks.md is approved by operator.
> Pattern: reflects the 3 pre-seeded task seeds (T-aggregator, T-overlay-wiring,
> T-act-iv-pattern-hover) from §Data Contracts + §Acceptance Criteria, plus
> ~30 additional implementation tasks derived from the 12 FRs + 11 ACs.

## Implementation status (as of 2026-06-07)

**Shipped: 20 of 36 tasks**. The block descriptions below remain the authoritative scope spec; the table here is the rolling status overlay. For PR-level provenance, see `state.json::related_prs`.

| Task | Status | Shipping PR(s) |
|---|---|---|
| T-aggregator | ✅ shipped + extended | fitme-story #182 (base) + #203 (HADF Phase 3a hooks block) |
| T-versions-mirror, T-adoption-mirror, T-pattern-skill-mirror | ✅ shipped | fitme-story #183 |
| T-snapshot-loader | ✅ shipped | fitme-story #184 |
| T-primitive-chambers, T-primitive-terrain, T-primitive-signage, T-primitive-motion | ✅ shipped | fitme-story #185 (4.B pipeline) |
| T-act1-threshold, T-act2-emergence, T-act3-architecture, T-act4-gate-firings, T-act5-measurement, T-act6-legacy | ✅ shipped | fitme-story #186–#191 (Acts I–VI) |
| T-overlay-wiring | ✅ shipped | fitme-story #192 + #193 |
| T-act-iv-pattern-hover | ✅ shipped | fitme-story #194 (via HoverCard) |
| T-glossary-tooltips | ✅ shipped | fitme-story #195 |
| T-pr-link-click | ✅ shipped | fitme-story #194 (via HoverCard `prNumber` prop) |
| T-fallback-cascade | ✅ shipped | fitme-story #199 |
| T-route-framework, T-route-control-room | ✅ shipped | fitme-story #196 + #197 |
| T-bundle-size-check | ✅ shipped | fitme-story #197 |
| T-ga4-events | ✅ shipped (helpers + scene wiring) | fitme-story #198 (typed helpers) + #201 (ActSequencer wiring) + #202 (scene-side analytics props) |
| T-comprehension-panel | ✅ shipped | fitme-story #200 |
| T-hadf-sensing-layer-hooks (aggregator half) | ✅ shipped (path-agnostic) | fitme-story #203 |
| T-lighthouse-perf URL list | ✅ shipped | fitme-story #204 |
| T-hero-gate-machinery, T-hero-telemetry-instruments, T-hero-signature-props (×4) | ⏸️ deferred (D1) | post-launch polish — procedural scene ships without them |
| T-scrub-pause-timedilation | 🟡 unblocked (D2) | custom lightweight Controls.tsx (Theatre.js NOT adopted); in progress |
| T-rive-tier-2 | 🔴 re-launch blocker (D6) | operator Rive `.riv` asset — single gate to un-404 `/framework/universe` |
| T-poster-tier-3 | 🔒 gated | operator hero PNG/WebP capture |
| T-hadf-sensing-layer-hooks (scene consumer half) | 🟡 unblocked (D3) | **path 1 — Act III chambers** (aggregator half shipped #203); in progress |
| T-playwright-ac10, T-playwright-ac11, T-mobile-60fps | 🔒 gated | Playwright browser binary install approval (~200 MB) — D4 rec: approve |
| T-lighthouse-perf assertion promotion | 🔒 gated (D5) | keep `warn` @0.8 until re-launch + 1–2wk calibration, then flip ≥0.95 |

### Phase 4 operator decisions (2026-06-18)

Recorded in `state.json::phase_4_decisions`. **D1** hero assets → defer (procedural-only). **D2** scrub → custom lightweight. **D3** HADF → path 1 (Act III chambers). **D6** re-launch → keep 404 until Rive + full polish (⇒ `T-rive-tier-2` is the single re-launch blocker). **D4** Playwright → rec approve (pending confirm). **D5** lighthouse → keep warn until post-relaunch calibration. Now-buildable with no assets: `T-scrub-pause-timedilation` + `T-hadf-sensing-layer-hooks` (scene consumer, path 1).

### Production status (2026-06-06)

`/framework/universe` is **temporarily 404'd** in production pending animation polish (operator decision 2026-06-06, shipped via fitme-story PR #205). The R3F scene tree + every shipped task above stays on `main` for iteration; only the user-facing entry point is gated. Re-launch checklist captured inline at [`fitme-story/src/app/framework/universe/page.tsx`](../../../../fitme-story/src/app/framework/universe/page.tsx) (3 steps).

`/control-room/framework/universe` (operator route) stays mounted as the iteration surface.

## Task structure

Each task block carries:

| Field | Purpose |
|---|---|
| **ID** | Stable identifier; referenced across PRD + commit messages + PR titles |
| **What** | One-sentence deliverable |
| **Files touched** | Explicit list per PRD §Key Files |
| **Depends on** | Predecessor task IDs (resolves the dependency graph) |
| **Effort** | XS (≤30 min), S (≤2h), M (≤1 day), L (≤3 days), XL (≥1 week) |
| **AC anchor** | Which AC(s) from prd.md §Acceptance Criteria this task contributes to |
| **References** | PRD section / FR / external doc |

## Phase 4.A — Build-time data pipeline (foundation)

> Must ship first; all scene tasks depend on this layer producing typed snapshots.

### T-aggregator (pre-seeded — locked contract in prd.md §Data Contracts)

- **What:** Implement `fitme-story/scripts/sync-from-fittracker2.ts` extension that reads `FT2_REPO/.claude/features/*/state.json` and writes `fitme-story/src/data/framework/feature-roster.json` per the OQ-2 locked contract.
- **Files touched:** `fitme-story/scripts/sync-from-fittracker2.ts` (+~50 LOC); `fitme-story/src/data/framework/feature-roster.json` (generated).
- **Depends on:** none (foundation).
- **Effort:** S
- **AC anchor:** AC-6 (feature-roster surface), AC-12 (data-freshness within build window).
- **References:** prd.md §Data Contracts → "feature-roster.json aggregator contract (OQ-2 closure, locked 2026-06-04)" (this is the verbatim acceptance bar — input glob, output `FeatureRosterEntry` schema, sort key, stability guarantees, privacy posture).

### T-versions-mirror

- **What:** Mirror `FT2_REPO/docs/framework/versions.json` → `fitme-story/src/data/framework/versions.json` on each sync run. Pure file copy; no schema transformation.
- **Files touched:** `fitme-story/scripts/sync-from-fittracker2.ts`; `fitme-story/src/data/framework/versions.json`.
- **Depends on:** none.
- **Effort:** XS
- **AC anchor:** AC-5 (timeline accuracy), AC-12.
- **References:** prd.md §Key Files row 14 + FR-6.

### T-adoption-mirror

- **What:** Mirror `FT2_REPO/.claude/shared/measurement-adoption.json` → `fitme-story/src/data/framework/adoption-snapshot.json`. Plain copy.
- **Files touched:** `fitme-story/scripts/sync-from-fittracker2.ts`; `fitme-story/src/data/framework/adoption-snapshot.json`.
- **Depends on:** none.
- **Effort:** XS
- **AC anchor:** AC-7 (Act V adoption bars reflect live ledger), AC-12.

### T-pattern-skill-mirror

- **What:** Mirror `FT2_REPO/.claude/shared/pattern-skill-map.json` (shipped via PR #615, v7.9.1) → `fitme-story/src/data/framework/pattern-skill-map.json`. Plain copy.
- **Files touched:** `fitme-story/scripts/sync-from-fittracker2.ts`; `fitme-story/src/data/framework/pattern-skill-map.json`.
- **Depends on:** none.
- **Effort:** XS
- **AC anchor:** AC-11 (pattern overlay smoke).
- **References:** prd.md FR-13 (Pattern overlay on Acts III–V) + §3a pattern overlay framing.

### T-snapshot-loader

- **What:** Build `fitme-story/src/lib/framework-snapshot.ts` — typed loader that exposes the four data inputs (`versions`, `feature-roster`, `adoption-snapshot`, `pattern-skill-map`) plus `gate-coverage-ft2.jsonl` (already mirrored per v7.8.3 Phase 1) as TypeScript-typed exports for scene components to consume.
- **Files touched:** `fitme-story/src/lib/framework-snapshot.ts` (new); `fitme-story/src/types/framework.ts` (new — type definitions matching the locked contracts).
- **Depends on:** T-aggregator, T-versions-mirror, T-adoption-mirror, T-pattern-skill-mirror (the loader depends on the data files existing).
- **Effort:** S
- **AC anchor:** AC-12 (data-freshness).
- **References:** prd.md §Key Files row 6.

## Phase 4.B — Procedural primitives (Three.js / R3F building blocks)

> Reusable primitives for the architectural shell. No glTF here; pure code.

### T-primitive-chambers

- **What:** Procedural R3F `<Chamber>` primitive — parametric volume with bevels, ambient-light socket, label-billboard mount point. Used by Act III architecture scene.
- **Files touched:** `fitme-story/src/components/bespoke/framework-universe/primitives/Chamber.tsx`.
- **Depends on:** none.
- **Effort:** M
- **AC anchor:** AC-2 (Pixar clean-tech visual mood).
- **References:** prd.md FR-2 + FR-3.

### T-primitive-terrain

- **What:** Procedural terrain (matte plane with subtle displacement). Used as base for all acts.
- **Files touched:** `fitme-story/src/components/bespoke/framework-universe/primitives/Terrain.tsx`.
- **Depends on:** none.
- **Effort:** S
- **AC anchor:** AC-2.

### T-primitive-signage

- **What:** Procedural signage billboard — text + icon + glossary-term anchor (FR-9 integration point).
- **Files touched:** `fitme-story/src/components/bespoke/framework-universe/primitives/Signage.tsx`.
- **Depends on:** none.
- **Effort:** M
- **AC anchor:** AC-2, AC-13 (glossary tooltips).

### T-primitive-motion

- **What:** Calibrated Isometric motion primitives (5 reusable variants per research §3.4) — `fly-in`, `dolly-track`, `parallax-tilt`, `pulse-emit`, `iso-rotate`.
- **Files touched:** `fitme-story/src/lib/motion-3d/primitives.ts`.
- **Depends on:** none.
- **Effort:** M
- **AC anchor:** AC-2.
- **References:** prd.md FR-3 + research §3.4.

## Phase 4.C — Per-act scene composition

> Each act is one scene component composed from primitives + glTF hero pieces.

### T-act1-threshold

- **What:** Act I (Threshold) scene — framework v1.0 initial state. Procedural environment, no live data binding.
- **Files touched:** `fitme-story/src/components/bespoke/framework-universe/scenes/Act1-Threshold.tsx`.
- **Depends on:** T-primitive-chambers, T-primitive-terrain, T-primitive-motion.
- **Effort:** M
- **AC anchor:** AC-1 (6-act walkthrough exists).

### T-act2-emergence

- **What:** Act II (Emergence) — v5.0 SoC + Phase-discipline emergence. Glossary-tooltip-annotated phase IDs.
- **Files touched:** `fitme-story/src/components/bespoke/framework-universe/scenes/Act2-Emergence.tsx`.
- **Depends on:** T-act1-threshold, T-snapshot-loader.
- **Effort:** M
- **AC anchor:** AC-1.

### T-act3-architecture

- **What:** Act III (Architecture) — v6.0 → v7.5 architectural buildout. **Pattern overlay annotations** per FR-13 (each chamber displays its mapped pattern IDs from `pattern-skill-map.json`).
- **Files touched:** `fitme-story/src/components/bespoke/framework-universe/scenes/Act3-Architecture.tsx`.
- **Depends on:** T-primitive-chambers, T-snapshot-loader, T-pattern-skill-mirror.
- **Effort:** L
- **AC anchor:** AC-1, AC-8 (pattern overlay annotations), FR-13.

### T-act4-gate-firings

- **What:** Act IV (Gate Firings) — v7.6 → v7.9 gate firings with live `gate-coverage-ft2.jsonl` data. **Hover-reveal** per AC-10 (PR-ID) + AC-11 (pattern title from `pattern-skill-map.json`).
- **Files touched:** `fitme-story/src/components/bespoke/framework-universe/scenes/Act4-GateFirings.tsx`.
- **Depends on:** T-primitive-signage, T-snapshot-loader.
- **Effort:** L
- **AC anchor:** AC-1, AC-10, AC-11.
- **References:** prd.md AC-10 + AC-11 (Playwright assertions).

### T-act5-measurement

- **What:** Act V (Measurement) — v6.0 measurement framework with live adoption-snapshot bars (per-dimension cu_v2 / cache_hits / per_phase_timing / fully_adopted_post_v6).
- **Files touched:** `fitme-story/src/components/bespoke/framework-universe/scenes/Act5-Measurement.tsx`.
- **Depends on:** T-snapshot-loader, T-adoption-mirror.
- **Effort:** L
- **AC anchor:** AC-1, AC-7.

### T-act6-legacy

- **What:** Act VI (Legacy / Calibration) — v7.9.1+ closure scene with feature-roster grid (each feature is a monument). Driven by `feature-roster.json`.
- **Files touched:** `fitme-story/src/components/bespoke/framework-universe/scenes/Act6-LegacyCalibration.tsx`.
- **Depends on:** T-aggregator, T-snapshot-loader.
- **Effort:** L
- **AC anchor:** AC-1, AC-6.

## Phase 4.D — glTF hero pieces (≤6 per FR-3)

> Each hero piece authored in Blender → exported as `.glb` with Draco + Meshopt + KTX2.

### T-hero-gate-machinery

- **What:** Hero piece for Act IV — gate-machinery mechanism (procedurally-animated levers + telemetry-spike emitter).
- **Files touched:** `fitme-story/public/assets/3d/framework-universe/gate-machinery.glb` (new asset).
- **Depends on:** none (asset work).
- **Effort:** L
- **AC anchor:** AC-2, AC-3 (asset budget).
- **References:** prd.md §Hero glTF asset budget.

### T-hero-telemetry-instruments

- **What:** Hero piece for Act V — telemetry instruments (dial/gauge cluster).
- **Files touched:** `fitme-story/public/assets/3d/framework-universe/telemetry-instruments.glb`.
- **Depends on:** none.
- **Effort:** L
- **AC anchor:** AC-2, AC-3.

### T-hero-signature-props (×4)

- **What:** 4 remaining hero pieces (signature props for Acts I/II/III/VI). Subdivide into T-hero-prop-1 through T-hero-prop-4 once visual direction is locked.
- **Files touched:** 4× `.glb` files under the same hero-assets directory.
- **Depends on:** none.
- **Effort:** L (each)
- **AC anchor:** AC-2, AC-3.

## Phase 4.E — Interaction layer

### T-overlay-wiring (pre-seeded)

- **What:** Wire `pattern-skill-map.json` into Act III chamber annotations + Act IV gate-fire hover-cards. Same data; two surfaces.
- **Files touched:** `fitme-story/src/components/bespoke/framework-universe/scenes/Act3-Architecture.tsx`; `fitme-story/src/components/bespoke/framework-universe/scenes/Act4-GateFirings.tsx`; `fitme-story/src/components/bespoke/framework-universe/primitives/HoverCard.tsx` (new).
- **Depends on:** T-act3-architecture, T-act4-gate-firings, T-pattern-skill-mirror.
- **Effort:** M
- **AC anchor:** FR-13, AC-8, AC-11.
- **References:** prd.md §3a "The skills+patterns wiring dual-use case".

### T-act-iv-pattern-hover (pre-seeded)

- **What:** Implement the Act IV hover-card — when hovering a gate-fire signage element, display the linked PR ID + (if mapped) the pattern title + short remediation hint.
- **Files touched:** `fitme-story/src/components/bespoke/framework-universe/primitives/HoverCard.tsx`; `fitme-story/src/components/bespoke/framework-universe/scenes/Act4-GateFirings.tsx`.
- **Depends on:** T-overlay-wiring.
- **Effort:** S
- **AC anchor:** AC-10, AC-11.

### T-scrub-pause-timedilation

- **What:** Timeline controls — pause, scrub, time-dilation (4× slow current act), replay. Keyboard support per FR-11 (arrow keys + space).
- **Files touched:** `fitme-story/src/components/bespoke/framework-universe/Controls.tsx`.
- **Depends on:** none (UI-only).
- **Effort:** M
- **AC anchor:** AC-9 (interaction controls), AC-14 (keyboard a11y).

### T-glossary-tooltips

- **What:** Glossary integration per FR-9 — every label with a `glossary.ts` entry shows the `<Term>` tooltip on hover. Inherits vocabulary from `lifecycle-phases.ts` + `blueprint-data.ts`.
- **Files touched:** `fitme-story/src/components/bespoke/framework-universe/primitives/Signage.tsx`; `fitme-story/src/components/bespoke/framework-universe/scenes/*.tsx` (consume).
- **Depends on:** T-primitive-signage.
- **Effort:** S
- **AC anchor:** AC-13.

### T-pr-link-click

- **What:** Click handler on PR-ID hover-cards — opens GitHub PR page in new tab with `target="_blank" rel="noopener noreferrer"`. AC-10 implementation.
- **Files touched:** `fitme-story/src/components/bespoke/framework-universe/primitives/HoverCard.tsx`.
- **Depends on:** T-act-iv-pattern-hover.
- **Effort:** XS
- **AC anchor:** AC-10.

## Phase 4.F — Fallback tiers (FR-4)

### T-rive-tier-2

- **What:** Rive state machine for reduced-motion + low-RAM mobile fallback (FR-4 Tier 2). Activated by `prefers-reduced-motion` media query OR DeviceMemory API < 4GB.
- **Files touched:** `fitme-story/src/components/bespoke/framework-universe/fallbacks/RiveFallback.tsx`; `fitme-story/public/assets/3d/framework-universe/fallback.riv` (new asset).
- **Depends on:** none.
- **Effort:** L
- **AC anchor:** AC-14 (a11y), AC-15 (fallback graceful).

### T-poster-tier-3

- **What:** `next/image` poster frame for saved-data / no-JS (FR-4 Tier 3). PNG export of the Act III hero-shot at 1920×1080 + WebP variant.
- **Files touched:** `fitme-story/src/components/bespoke/framework-universe/fallbacks/PosterFallback.tsx`; `fitme-story/public/assets/3d/framework-universe/poster.png` + `.webp`.
- **Depends on:** none.
- **Effort:** S
- **AC anchor:** AC-15.

### T-fallback-cascade

- **What:** Stack-cascade detection logic — try Tier 1 (R3F + WebGPU), fall to Tier 2 (Rive) on reduced-motion / WebGPU unavailable / memory pressure, fall to Tier 3 (poster) on JS disabled / saved-data mode.
- **Files touched:** `fitme-story/src/components/bespoke/framework-universe/FrameworkUniverse.tsx` (the entry).
- **Depends on:** T-rive-tier-2, T-poster-tier-3.
- **Effort:** M
- **AC anchor:** AC-15.

## Phase 4.G — Routes + integration

### T-route-framework

- **What:** Lazy-loaded `/framework` page; IntersectionObserver-gated bundle import (initial JS = 0 KB per FR-10).
- **Files touched:** `fitme-story/src/app/framework/page.tsx`.
- **Depends on:** T-fallback-cascade (the entry component must exist).
- **Effort:** S
- **AC anchor:** AC-16 (performance contract — Lighthouse ≥95).
- **References:** prd.md FR-10 + AC performance contract.

### T-route-control-room

- **What:** Operator-mode `/control-room/framework` extends the existing page with the Universe component + live WebSocket telemetry overlay. UCC-passkey gated.
- **Files touched:** `fitme-story/src/app/control-room/framework/page.tsx` (modify).
- **Depends on:** T-route-framework.
- **Effort:** M
- **AC anchor:** FR-8.

### T-bundle-size-check

- **What:** New CI check `fitme-story/scripts/check-bundle-size.ts`. Fails if `/framework` deferred bundle exceeds 350 KB compressed.
- **Files touched:** `fitme-story/scripts/check-bundle-size.ts` (new); `fitme-story/.github/workflows/bundle-size.yml` (new).
- **Depends on:** T-route-framework.
- **Effort:** S
- **AC anchor:** AC-16.

## Phase 4.H — Analytics + Visitor Comprehension panel

### T-ga4-events

- **What:** Typed GA4 event exports per FR-7 — `framework_act_enter`, `framework_label_hover`, `framework_scrub_seek`, `framework_time_dilation`, `framework_replay`, `framework_fallback_tier_activated`.
- **Files touched:** `fitme-story/src/lib/analytics-events.ts` (extend).
- **Depends on:** none.
- **Effort:** S
- **AC anchor:** AC-17 (analytics coverage).
- **References:** prd.md §Analytics Spec (GA4 Event Definitions).

### T-comprehension-panel

- **What:** Visitor Comprehension panel at `/control-room/framework` — surfaces GA4 funnel: scene-by-scene completion + dwell-time + scrub interactions.
- **Files touched:** `fitme-story/src/components/control-room/VisitorComprehensionPanel.tsx`.
- **Depends on:** T-ga4-events.
- **Effort:** M
- **AC anchor:** FR-7, FR-8.

## Phase 4.I — Future-extensibility hooks

### T-hadf-sensing-layer-hooks (HADF Phase 3a integration — MERGED 2026-06-05)

> **Status update during this PR's open window**: the `hadf-phase3a-sensing` feature MERGED on main as PR #635 (`35fc32d`) while this tasks.md was being drafted. The integration is no longer a forward reservation — it's an actionable follow-up task with concrete dependencies. The companion HADF×ORCHID overlay research anchor closed in PR #634 (`8e1810f`) confirming dispatch behavior across all 4 Block-C sub-experiments.

- **What:** Integrate the now-shipped HADF Phase 3a sensing/observability layer (reference store + attestation + drift monitor — T1-T3 of PR #635) into the 3D Universe. Two integration paths to evaluate at Phase 4 start:
  1. **New chambers in Act III Architecture** — if framework integration treats sensing as new architectural layers (recommended if reference store + attestation feel like infrastructure additions to the existing 8-region blueprint)
  2. **A new sub-Act between Act III and Act IV** — if Phase 3a constitutes a distinct "Sensing" phase in the framework's evolution narrative (recommended if drift monitor feels like a temporal-gate stage with its own narrative beat)
- **Concrete deliverables:**
  - Extend the locked `feature-roster.json` aggregator contract with a `hadf_phase3a_hooks` block (optional field; default `null`). T-aggregator emits the block as `{reference_store_present, attestation_present, drift_monitor_present, gate_coverage_extras: [...]}` for the `hadf-phase3a-sensing` feature entry.
  - Scene components consume the block — Act III or new sub-Act renders the new chamber set when non-null.
  - Documentation pointer in prd.md §Functional Requirements (FR-14 NEW once Phase 4 decides path 1 vs 2).
- **Files touched:** `fitme-story/src/types/framework.ts` (extend `FeatureRosterEntry`); `fitme-story/scripts/sync-from-fittracker2.ts` (extend T-aggregator); decision pending — either `Act3-Architecture.tsx` (path 1) or a new `Act3a-Sensing.tsx` (path 2).
- **Depends on:** T-aggregator (contract extension lives there) + operator decision on integration path 1 vs 2 (Phase 2 exit gate question #3 → now actionable, no longer hypothetical).
- **Effort:** S (contract extension + aggregator emit), M (Act III chamber addition — path 1), L (new sub-Act creation — path 2).
- **AC anchor:** none yet — Phase 4 may add AC-19 once path is locked.
- **References:** FT2 PR #635 (`35fc32d`); FT2 PR #634 HADF×ORCHID overlay anchor (`8e1810f`); FT2 `.claude/features/hadf-phase3a-sensing/state.json`.

## Phase 4.J — Tests + verification

### T-playwright-ac10

- **What:** Playwright spec asserting AC-10 — hover any Act IV gate-fire signage → tooltip contains `#NNN` → click → new tab URL matches `https://github.com/<owner>/<repo>/pull/NNN`.
- **Files touched:** `fitme-story/e2e/framework/ac-10-pr-link.spec.ts`.
- **Depends on:** T-pr-link-click.
- **Effort:** S
- **AC anchor:** AC-10.

### T-playwright-ac11

- **What:** Playwright spec asserting AC-11 — hover any Act IV gate-fire signage with a `data-pattern-id` → tooltip contains pattern title from `skills-patterns-map.json`.
- **Files touched:** `fitme-story/e2e/framework/ac-11-pattern-overlay.spec.ts`.
- **Depends on:** T-act-iv-pattern-hover.
- **Effort:** S
- **AC anchor:** AC-11.

### T-lighthouse-perf

- **What:** Lighthouse CI assertion — Performance ≥95 sustained on `/framework`. Initial JS = 0 KB validated separately by T-bundle-size-check.
- **Files touched:** `fitme-story/.github/workflows/lighthouse.yml` (new).
- **Depends on:** T-route-framework.
- **Effort:** S
- **AC anchor:** AC-16.

### T-mobile-60fps

- **What:** WebVitals 60fps assertion on iPhone 12 / Pixel 6 emulation. Frameloop="demand" off-viewport verified.
- **Files touched:** `fitme-story/e2e/framework/mobile-perf.spec.ts`.
- **Depends on:** T-route-framework.
- **Effort:** M
- **AC anchor:** AC-18 (mobile 60fps).

## Dependency graph (high-level)

```text
T-aggregator ┐
T-versions-mirror ┼─→ T-snapshot-loader ─┐
T-adoption-mirror ┤                      │
T-pattern-skill-mirror ─┴────────────────┤
                                         │
T-primitive-chambers ┐                   │
T-primitive-terrain ─┼──────────────────┐│
T-primitive-signage ─┤                  ││
T-primitive-motion ──┘                  ││
                                        ││
                          ┌─→ T-act1 ←─┴┴
                          ├─→ T-act2
                          ├─→ T-act3 ←─ T-pattern-skill-mirror
                          ├─→ T-act4 ←─ T-pattern-skill-mirror
                          ├─→ T-act5
                          └─→ T-act6 ←─ T-aggregator

T-act3 + T-act4 + T-pattern-skill-mirror → T-overlay-wiring → T-act-iv-pattern-hover → T-pr-link-click

[T-act1..T-act6] + [T-rive-tier-2 + T-poster-tier-3] → T-fallback-cascade → T-route-framework → T-route-control-room
                                                                                              ↘
                                                                                                T-bundle-size-check
                                                                                                T-lighthouse-perf
                                                                                                T-mobile-60fps
T-pr-link-click → T-playwright-ac10
T-act-iv-pattern-hover → T-playwright-ac11
```

## Estimated effort summary

| Phase 4 group | Tasks | Estimated wall time |
|---|---|---|
| 4.A Data pipeline | 5 | ~3–4 sessions |
| 4.B Primitives | 4 | ~3–4 sessions |
| 4.C Per-act scenes | 6 | ~6–8 sessions |
| 4.D Hero glTF | 2+4 | ~6–10 sessions (asset-author dependent) |
| 4.E Interaction | 5 | ~2–3 sessions |
| 4.F Fallback tiers | 3 | ~2–3 sessions |
| 4.G Routes | 3 | ~1–2 sessions |
| 4.H Analytics | 2 | ~1 session |
| 4.I HADF hooks | 1 (reservation) | ~XS (full integration deferred) |
| 4.J Tests | 4 | ~2 sessions |
| **Total** | **~36 tasks** | **~25–35 sessions** |

Phase 4 ships in increments — each Phase 4.X group can land on its own feature branch + PR if scope feels large. The first PR should land 4.A + 4.B + at least one act of 4.C as a vertical slice to validate the architecture.

## Acceptance criteria mapping (forward to prd.md §Acceptance Criteria)

| AC | Tasks contributing |
|---|---|
| AC-1 6-act walkthrough | T-act1..T-act6 |
| AC-2 Pixar mood | T-primitive-* + T-hero-* + visual review |
| AC-3 Asset budget | T-hero-* (≤6 hero pieces enforced by review) |
| AC-5 Timeline accuracy | T-versions-mirror |
| AC-6 Feature-roster | T-aggregator + T-act6 |
| AC-7 Adoption bars live | T-adoption-mirror + T-act5 |
| AC-8 Pattern overlay | T-pattern-skill-mirror + T-act3 + T-overlay-wiring |
| AC-9 Interaction controls | T-scrub-pause-timedilation |
| AC-10 PR-ID link | T-act-iv-pattern-hover + T-pr-link-click + T-playwright-ac10 |
| AC-11 Pattern overlay smoke | T-overlay-wiring + T-act-iv-pattern-hover + T-playwright-ac11 |
| AC-12 Data freshness | T-snapshot-loader + all mirror tasks |
| AC-13 Glossary tooltips | T-glossary-tooltips |
| AC-14 a11y / keyboard | T-scrub-pause-timedilation + T-rive-tier-2 |
| AC-15 Fallback graceful | T-rive-tier-2 + T-poster-tier-3 + T-fallback-cascade |
| AC-16 Performance ≥95 | T-route-framework + T-bundle-size-check + T-lighthouse-perf |
| AC-17 Analytics coverage | T-ga4-events |
| AC-18 Mobile 60fps | T-mobile-60fps |

All 17 ACs from prd.md §Acceptance Criteria covered by Phase 4 tasks. Phase 4 closure criterion: all 17 ACs pass + 36 tasks at `status: complete`.

## Open questions for operator approval (Phase 2 exit gate)

1. **Hero-asset authoring** — Phase 4.D assumes Blender-authored glTF (~6 pieces). Operator confirms direction OR substitutes alternative source (e.g., commission, library purchase, fully-procedural)?
2. **Visual direction lock** — T-hero-signature-props subdivision (×4) requires a locked visual-direction reference before tasks can be authored. Operator approves a single-PR visual-direction lock (mood board + 3 reference shots) as a Phase 4.D prerequisite?
3. **HADF Phase 3a integration path** — `hadf-phase3a-sensing` MERGED via PR #635 (`35fc32d`) during this PR's open window — the reservation is now actionable. T-hadf-sensing-layer-hooks documents two paths: (1) new chambers in Act III Architecture vs (2) new sub-Act between III and IV. Phase 4 needs an operator pick on (1) vs (2) before T-act3-architecture / T-act4-gate-firings can be authored in detail. Both paths have ~equal effort estimates; choice is narrative/aesthetic.

Phase 2 exits when operator answers 1–3 + approves the task list shape. Phase 4 then opens on the first Phase 4.A task.
