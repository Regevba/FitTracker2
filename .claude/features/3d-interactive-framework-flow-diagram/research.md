# Research — 3D Interactive Framework Flow Diagram

> **Status:** Research only. No PRD, no tasks, no implementation. Backlog item lives in `docs/product/backlog.md` under "Medium Priority (UX Improvements)" → "fitme-story public site".
> **Audience:** PM workflow Phase 1 (Research) input for whenever this feature is started via `/pm-workflow 3d-interactive-framework-flow-diagram`.
> **Date:** 2026-05-11
> **Researcher:** Claude (Opus 4.7, 1M ctx) via `research` skill `feature` sub-command
> **Cross-repo scope:** fitme-story (public site) primary; FT2 (.claude/shared sync pipeline) secondary.

---

## 1. Goal & Framing

Build an interactive 3D flow diagram on the public fitme-story site (the case-study / portfolio surface) that visualizes the FitMe framework activating components as a real task moves through it. Premium/showcase tier — the diagram doubles as a hero piece for the framework section. The user requested "completely interactive with full advanced animation."

The diagram is a **third flagship visual** alongside the existing two:
- `DispatchReplay` — beat-by-beat 8-floor scroll-driven replay (flat DOM, Framer Motion)
- `LifecycleLoop` — 2D orbital SVG of the 10-phase PM lifecycle (Framer Motion)

The new piece is **3D, scrubbable, and component-resolution** (today's surfaces are floor-level at best).

---

## 2. Baseline — what fitme-story already shows

| Surface | File | Tech | Granularity | Gap |
|---|---|---|---|---|
| `/framework` (BlueprintOverlay) | `src/app/framework/page.tsx` | DOM + Framer Motion hover | 8 floors (static) | No flow, no activation |
| `/framework/dispatch` (DispatchReplay) | `src/components/bespoke/DispatchReplay.tsx` | DOM + Framer Motion glow/scale | Floor state changes per beat | Flat, no component-level, no 3D, scroll-only |
| `/pm-flow` (LifecycleLoop) | `src/components/pm-flow/LifecycleLoop.tsx` | SVG + Framer Motion arc reveal | 10 phases (orbital) | 2D, no data flow between phases |
| `/framework/dev-guide` | MDX prose | rehype-pretty-code | Text only | No visual |
| Case-study `FlowDiagram` | `src/components/case-study/FlowDiagram.tsx` | Static SVG | Generic node row | Static |

**Animation stack on the site today:** Framer Motion v12.38.0 only. **No** Three.js / R3F / Babylon / Spline / Rive / Lottie / GSAP / Theatre installed. All visuals are DOM + SVG + CSS.

---

## 3. Tooling decision

**Primary recommendation:** **React Three Fiber + drei + Theatre.js + GSAP**, lazy-loaded behind a `next/dynamic({ ssr: false })` route boundary.

| Layer | Library | Why | Bundle (gz) |
|---|---|---|---|
| Renderer | three.js | Industry standard, MIT, mature | ~155 KB |
| React binding | @react-three/fiber | Declarative scene-as-JSX, fits Next.js + Tailwind workflow | ~30 KB |
| Helpers | @react-three/drei | `<Html>`, `<Line>`, `<Float>`, `<OrbitControls>`, `<Bvh>` cover 80% of primitives | ~20–60 KB tree-shaken |
| Timeline | @theatre/core + @theatre/r3f | Scrub-a-task-through-pipeline → sequence playhead. Studio UI for keyframe authoring; runtime is headless. | ~40 KB |
| DOM choreography | GSAP (free under Webflow ownership since 2025) | HUD, labels, scrubber, edge glows | ~30 KB |

**Total budget:** ~250–350 KB gzipped on a lazy-loaded route boundary. Acceptable for ONE hero piece, not for global.

**Rejected:**
- **Spline** — proprietary, ~544 KB gzipped runtime, harder to make accessible, weak for state-driven node activation
- **Babylon.js** — full engine overkill for a node graph (~600 KB gz core)
- **Framer Motion 3D** — `framer-motion-3d` is unmaintained and not React 19 compatible; use `motion/react-three` if any Motion integration is needed inside R3F
- **PixiJS** — 2D-only; viable as a 2.5D fallback if profiling shows true 3D isn't earning its weight

---

## 4. Reference implementations to study

| # | URL | Tech | Pattern to borrow |
|---|---|---|---|
| 1 | stripe.com/blog/globe | Three.js (3-layer: ocean + dot sphere + arcs) | Arcs as data flows; "alive but not crashing" balance |
| 2 | github.com/janarosmonaliev/github-globe | Three.js + custom shaders | Real-time events as motes traveling between coords |
| 3 | bruno-simon.com | Three.js + Cannon.js | Discovery gating — hint, try, reward |
| 4 | Apple M-series product pages (`apple.com/macbook-pro/`) | R3F + GLTF rigged to scroll | **Scroll-as-scrubber** — cleanest narrative model |
| 5 | lusion.co (v3) | Three.js + custom GLSL + post-processing | Cinematic timing; warning: post-processing can obscure information in a system-explainer |
| 6 | linear.app (hero) | Canvas + Framer Motion | A premium hero doesn't *require* WebGL if choreography is tight |
| 7 | radar.cloudflare.com | D3 + Sankey + map | Color-coded data classes |
| 8 | Vercel homepage edge-network panel | CSS/Canvas hybrid | System-explainer can be lightweight |

---

## 5. Design / animation studios

For sourcing inspiration, freelance contractors, or framing the visual language:

| Studio | URL | Hallmark technique |
|---|---|---|
| Active Theory | activetheory.net | WebGL + bespoke shaders, in-house tooling, NBA/Google/Nike work |
| Lusion | lusion.co | Three.js + custom GLSL, Edan Kwan, Awwwards regular |
| Resn | resn.co.nz | Cinematic motion, brand films, immersive 3D |
| Immersive Garden | immersive-g.com | Paris; design + 3D + WebGL |
| Unseen Studio | unseenstudio.com | Liquid deformations, fluid post-processing, audio sync |
| Hello Monday / DEPT | hellomonday.com | Long-running interactive shop (LEGO, Stripe, Google) |
| Locomotive | locomotive.ca | Montreal; ships Lenis (smooth-scroll lib) |
| Akufen | akufen.ca | Montreal; brand storytelling with WebGL accents |
| B-Reel | b-reel.com | Larger production house (Google, Apple, Netflix) |
| Plus Plus | plus-plus.studio | Boutique Stockholm; minimalist 3D |
| Antinomy | antinomy.studio | Type-first interactive identities |
| Cassie Evans (solo) | cassie.codes | Best-in-class SVG + GSAP; consider for the 2D HUD/scrubber layer |

---

## 6. Patterns & anti-patterns

**Works**

- Camera framed slightly above and angled — never pure orthogonal — so depth reads instantly
- Staggered node activation, ~150–250 ms between nodes, so the eye can follow
- Color-coded data flows with no more than 3–4 categories (map to the 11 skill colors carefully — group by skill family, not 11 distinct hues)
- Progressive disclosure — auto-play a 5–8 s establishing run, then expose the scrubber
- **Scrub-to-explore beats autoplay-loop** for pedagogical scenes (user owns the pace)
- `prefers-reduced-motion` → static labeled diagram fallback, not "less motion" hand-waving (WCAG 2.3.3)
- Mobile fallback — annotated still or 2D Rive loop below 768 px; do NOT ship 350 KB of WebGL on mobile data plans
- Skip-to-text link above the canvas pointing to a text equivalent for screen readers
- Pause button always visible (web.dev animation guidance)

**Kills it**

- More than ~20 simultaneously animating nodes (Stripe globe team's hardest tradeoff)
- FPS drops below 50 — judder is felt before it's seen
- No paragraph entry point explaining what the user is about to see
- Mystery-meat hover targets (nodes that "do something" without an affordance)
- Autoplay audio of any kind
- Locked camera with no escape (always provide a "reset view" button)
- Bloom and depth-of-field cranked to demo-reel levels — they obscure information in a system-explainer
- Loading 2 MB of GLTF on first paint instead of route-gating it

---

## 7. Design-system consumption — what the diagram MUST reuse

The fitme-story design system is mature; the diagram lives inside it, not next to it.

| Token / primitive | Source | How the diagram uses it |
|---|---|---|
| Skill palette (11 colors) | `src/app/globals.css` lines 12–38 | Node accent color per component's owning skill (pm-workflow, research, ux, design, dev, qa, analytics, cx, marketing, ops, release). Group into ≤4 categories for the flow-arrow color coding. |
| Motion durations (fast 120, standard 200, slow 320) | `globals.css` lines 52–59 + `src/lib/design-tokens.ts` lines 92–99 | Map Theatre.js sequence beats to these durations. Don't invent new timings. |
| Easings (standard / decelerate / emphasized cubic-béziers) | Same | Use for camera moves, label fades, node-glow easings. |
| Elevation (4-level shadow system, light + dark) | `globals.css` lines 61–65 | HUD cards, control bar, info panels float above the canvas using these shadows — not Three.js shadow-mapping. |
| Z-index ladder (base 0 / elevated 10 / header 100 / modal 1000 / toast 10000) | `globals.css` lines 67–72 | Canvas at `elevated`; HUD at `header`; info modal at `modal`. |
| Type scale (Display XL/LG/MD clamp + Body 1.0625rem/1.7) | `design-tokens.ts` lines 65–70 | HUD labels and node tooltips use the same scale — no canvas-baked text at arbitrary sizes. |
| `useReducedMotion()` (Framer Motion hook) | Used in 5+ existing components | Top-level switch: full scene → static labeled diagram fallback. |
| Dark mode (`[data-theme]` + `html.dark` + CSS custom property overrides) | `globals.css` lines 80–96 | Three.js scene re-reads CSS vars on theme change (subscribe via `matchMedia` or a context). Don't bake light-mode colors into GLTF. |
| UI primitives — Card, Tag, Button, Callout, Tooltip | `src/components/ui/*` (with Figma Code Connect mappings) | HUD chrome and info panels MUST reuse these — no bespoke `<div className="rounded-xl bg-white shadow-md">`. |
| `/design-system` route | `src/app/design-system/page.tsx` | The diagram registers as a new bespoke component in the manifest at `src/lib/design-system.ts` with its own swatch. |

---

## 8. Infrastructure gaps — what's missing to ship this

Effort: S = 0.5–1 d, M = 1–3 d, L = 3+ d.

### G1 — Heavy-library lazy-load convention `[S]`
**Gap:** No `next/dynamic({ ssr: false })` pattern in the codebase. `DispatchReplay` and `ChipAffinityMap` are imported directly in `src/mdx-components.tsx` lines 17–18.
**Need:** Establish a `lazyClient(() => import('./Foo'))` helper or convention. The 3D diagram must hydrate only on its route, not bloat every MDX page.

### G2 — Asset pipeline for 3D `[M]`
**Gap:** No `.glb` / `.gltf` / `.hdr` / draco-compressed files in `/public/`. `next.config.*` is not configured to serve them. No CDN guidance.
**Need:** Decide `/public/models/` vs Vercel Blob, configure proper `Content-Type` + long-cache headers, document draco encoding step. If we author scenes purely in code (procedural meshes, no GLTF), this gap collapses to "nothing to do" — viable for a node-graph that doesn't need realistic models.

### G3 — Component-level trace data `[M]`
**Gap:** `src/components/bespoke/dispatch-traces.ts` is hardcoded TypeScript and floor-level only (`floorStates: idle | firing | done | dormant`). The 3D diagram needs per-component activation: skill load, cache hit, dispatch decision, write-back.
**Need:** Two options:
  - (a) Extend `dispatch-traces.ts` schema with `activations: Array<{componentId, t_start, t_end, status, dataIn?, dataOut?}>` and hand-author the richer beats for 1–2 traces.
  - (b) Sync from FT2's `.claude/logs/<feature>.log.json` (Tier 2.2 contemporaneous logs already capture per-phase events) via the existing `scripts/sync-from-fittracker2.ts` script. The sync script currently mirrors `.claude/shared/*.json` and `state.json` files; per-feature logs are NOT in scope today. **Recommendation:** start with (a) for a single hand-curated trace; promote to (b) only if more traces are needed.

### G4 — Accessibility fallback scaffolding `[M]`
**Gap:** No shared "interactive piece with text fallback" component. No live-region instrumentation for state changes. The site has a global reduced-motion `@media` blanket but no per-piece reduced-motion alternative component.
**Need:** A `<InteractiveWithFallback interactive={<3DDiagram />} fallback={<StaticDiagram />} aria-label="..." />` primitive. Place it in `src/components/ui/`. Reuse for future interactive pieces.

### G5 — Performance budget + measurement `[M]`
**Gap:** SpeedInsights is mounted (`src/app/layout.tsx` line 31) but there's no explicit LCP/FID budget gate. No `next/bundle-analyzer` or per-route budget assertion. A 350 KB WebGL chunk on the wrong route is invisible until production.
**Need:** Add `@next/bundle-analyzer` to `package.json` dev deps + a CI step (`npm run analyze` → assert per-route JS budget). Define a budget for the 3D route ≤ 400 KB gz, all other routes unchanged.

### G6 — Analytics event taxonomy `[S]`
**Gap:** Control-room has its own `analytics.ts` (`dashboard_*` naming) but the public site has no `src/lib/analytics.ts`. Interactive components are not instrumented in GA4 today.
**Need:** Create `src/lib/analytics.ts` for the public site. Per the FT2 analytics naming convention (CLAUDE.md "Analytics Naming Convention"), screen-scoped events get a prefix. For a piece living at `/framework/dispatch-3d` (or wherever), prefix `framework_diagram3d_*`: `framework_diagram3d_load`, `framework_diagram3d_play`, `framework_diagram3d_pause`, `framework_diagram3d_scrub`, `framework_diagram3d_component_focus`, `framework_diagram3d_reset_view`, `framework_diagram3d_skip_to_text`.

### G7 — SSR / no-JS fallback `[M]`
**Gap:** Neither `DispatchReplay` nor `ChipAffinityMap` ships a `<noscript>` fallback. Pre-hydration HTML is empty for those slots.
**Need:** SSR a static `<figure><img src="diagram-3d-static.svg" alt="..." /><figcaption>...</figcaption></figure>` placeholder; client hydration swaps to the canvas. The static SVG doubles as the Open Graph image for the route.

### G8 — Testing strategy `[L]`
**Gap:** Tests run via `tsx --test`; no Vitest, Playwright, Storybook, or Chromatic. No visual-regression infra.
**Need:** Decide. Options:
  - (a) **Manual QA + curated screenshots** — pragmatic for a single hero piece.
  - (b) **Playwright + screenshot diff** — captures regressions at the cost of new infra (Playwright config, baseline images, CI runner with WebGL — non-trivial on hosted CI).
  - (c) **Unit-test the deterministic parts** — trace data, Theatre sequence math, reduced-motion branching — and leave the canvas itself to manual QA.
  - **Recommendation:** (a) at launch, (c) added during stabilization, (b) only if regressions actually happen.

### G9 — Content pipeline `[S]`
**Gap:** Annotations per beat live in `dispatch-traces.ts` as hardcoded strings today. MDX integration (`src/mdx-components.tsx`) supports interactive blocks, including `DispatchReplay`.
**Need:** Embed the new diagram as an MDX block: `<Diagram3D traceId="ucc-passkey-auth" />`. Prose annotations remain in the trace data file; surrounding case-study prose stays in MDX. **No precedent breach.**

### G10 — Dependency footprint `[S]`
**Gap:** None of `three`, `@react-three/fiber`, `@react-three/drei`, `@theatre/core`, `@theatre/r3f`, `gsap` installed today.
**Need:** Add to `package.json` deps. Pin major versions. Document the bundle-budget impact in the same PR.

### Gap-effort summary

| Gap | Effort | Blocking? |
|---|---|---|
| G1 Lazy-load convention | S | Yes (architectural decision) |
| G2 Asset pipeline | M | Soft (avoidable if procedural) |
| G3 Component-level trace data | M | Yes (no data → no diagram) |
| G4 A11y fallback scaffold | M | Yes (WCAG 2.3.3) |
| G5 Perf budget + measurement | M | Soft (catches regressions, not launch-blocking) |
| G6 Analytics taxonomy | S | No |
| G7 SSR / no-JS fallback | M | Yes (SEO + accessibility) |
| G8 Testing strategy | L | No (decide at planning) |
| G9 Content pipeline | S | No (precedent exists) |
| G10 Dependencies | S | Yes (everything depends on this) |

Total infra effort before any 3D code: ~5–8 days. Diagram authoring on top of that: a separate estimate — defer to PRD.

---

## 9. Open questions for PRD phase

1. **Surface placement.** New route `/framework/dispatch-3d`, or replace `/framework/dispatch` (the current DispatchReplay), or embed inside an existing case study? Recommendation: NEW route — preserve DispatchReplay as the lightweight default; 3D as the opt-in deep-dive.
2. **First trace to render.** Which feature's lifecycle gets the inaugural 3D treatment? Candidates: `ucc-passkey-auth` (recent, rich Tier 2.2 log), `framework-v7-8-branch-isolation` (recent, framework-meta), or a synthetic/composite trace. Trade-off: real trace = honest; synthetic = clean narrative.
3. **Camera model.** Free-orbit, rail-on-scroll, or both (orbit when paused, rail when scrubbing)? Apple-style scroll-rail is the cleanest pedagogically.
4. **Component count ceiling.** How many components light up in the scene at once? Tier 1: ≤12 (one floor's worth). Tier 2: ≤24 (cross-floor flow). Hard ceiling: 20 simultaneously animating (per §6 anti-pattern).
5. **Static fallback authoring.** Hand-drawn SVG, exported still from a Theatre.js "frame 0" snapshot, or auto-generated at build time from the trace data?
6. **Sound design.** Default off, opt-in via HUD? Or no audio at all? Recommendation: no audio — the diagram lives in the same page as text the user might be reading.

---

## 10. Suggested PM-workflow shape

When this comes off backlog and into `/pm-workflow 3d-interactive-framework-flow-diagram`:

- **Work type:** Feature (full 10-phase lifecycle). Justification: new public surface, new dependency layer (~250 KB), accessibility + SSR contracts, new analytics taxonomy.
- **Branching:** `feature/3d-framework-flow-diagram` on fitme-story; isolated worktree mandatory under v7.8.1 branch-isolation rules (infra-touching: package.json + next.config + new asset pipeline).
- **Phase 1 (Research):** this dossier covers most of it. PRD-stage research should focus on: chosen trace's exact event log, accessibility user testing with at least one screen-reader user, mobile-device perf testing on a mid-range Android.
- **Phase 2 (PRD):** must define primary success metric (suggestion: time-on-page on `/framework/dispatch-3d` vs `/framework/dispatch` baseline, with bounce-rate guardrail), kill criteria (suggestion: LCP regression > 300 ms on the route ANY device class kills the launch).
- **Phase 4 (UX) gateway:** the `/ux preflight` step will need extending — the existing tokens-and-symbols check doesn't validate `.glb`/Theatre.js asset references. May surface a new check code candidate for v7.9.
- **Phase 6 (Review):** `/design pre-merge-review` parity check against the design system manifest at `src/lib/design-system.ts` — the diagram registers itself there with a Figma node ID for the static fallback.

---

## 11. Cache / shared-layer writes from this research

- **Adds to `.claude/cache/research/`:** L1 entry for "interactive 3D web visualization" — tooling stack, studio list, anti-patterns. Cross-skill applicable; flag for L2 promotion if used by `/design` or `/marketing` next.
- **Does not yet write to `.claude/shared/context.json`:** the competitive landscape there is product-vs-product (MyFitnessPal, Strava); 3D framework diagrams are a website-craft concern, not product competition. Skip.
- **Cross-references:**
  - DispatchReplay current implementation: `fitme-story/src/components/bespoke/DispatchReplay.tsx`
  - LifecycleLoop current implementation: `fitme-story/src/components/pm-flow/LifecycleLoop.tsx`
  - Design-system manifest: `fitme-story/src/lib/design-system.ts`
  - Tokens: `fitme-story/src/app/globals.css` + `fitme-story/src/lib/design-tokens.ts`
  - Trace data: `fitme-story/src/components/bespoke/dispatch-traces.ts`
  - Sync script: `fitme-story/scripts/sync-from-fittracker2.ts`
  - Tier 2.2 logs candidate source: `FT2 .claude/logs/<feature>.log.json`

---

*End of research dossier.*
