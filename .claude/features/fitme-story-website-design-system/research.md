# Research — fitme-story-website-design-system

**Phase:** 0 (Research)
**Framework:** v7.8.2
**Work type:** Feature (full 9-phase lifecycle)
**Created:** 2026-05-10
**Predecessor:** `fitme-story-public-enhancements` (closed) + `ios-code-connect` (closed) + `code-connect-automation` (closed)
**Backlog item:** [`docs/product/backlog.md`](../../docs/product/backlog.md) line ~169 — "fitme-story website design system — ongoing build-out (added 2026-05-09)"

---

## §1 What is this solution?

A **6-deliverable next-phase evolution** of the fitme-story website's design system, transforming it from a "foundation laid in code + 17 Figma node IDs captured" state (post-rollup-feature foundation) into a **living, publicly-documented, drift-protected, dark-mode-complete, contribution-friendly** system.

The 6 deliverables (per the backlog item):

1. **Public `/design-system` showcase route** rendering every component variant + token swatch + type-scale step in browser, sourced from a typed manifest (`src/lib/design-system.ts`)
2. **Component coverage expansion** beyond the 17 captured in T20 — control-room components (Panel, MetricList, AlertsBanner, TrackedDocLink, AuthPasskeyForm, DevicesTable, AuditEventRow, AuditLogPanel) + home/case-study components (MetricsCard, PersonaBar, PersonaIndicator, PersonaLens, TaskCard, FeatureCard) — total 14 additional components
3. **Drift detection** — `make figma-drift` (or fitme-story-side script) comparing `figma_node_ids` declarations across all features against the live Figma file via Figma MCP, reporting unresolved IDs + code/Figma asymmetries
4. **Dark-mode parity audit** — Light + Dark Figma frames per component variant; matrix doc `docs/design-system/fitme-story-dark-mode-coverage.md`
5. **Motion + elevation + z-index token additions** to the Figma variables collection (extending T19's color/spacing/type pattern); these tokens exist in code but not yet in Figma
6. **Component contribution guidelines** — CONTRIBUTING-style doc covering when to add/reuse/retire, the React + Figma + Code Connect mapping checklist, and how to migrate deprecated components without breaking case-study MDX

Together these establish the fitme-story website's design system as **operationally living** (drift checked, dark-mode complete, tokens fully extracted) and **publicly observable** (showcase route + contribution doc).

---

## §2 Why this approach?

### Problem statement

The rollup feature `fitme-story-public-enhancements` shipped 17 component node IDs + 4 primitive components + a Figma file with 33 token variables — a solid foundation. But:

- **The website has 30+ React components**, only 17 are mapped (~57% coverage). The remaining 13+ (control-room + home + case-study) are unmapped to Figma.
- **No public surface** exists for designers/contributors to see what's available. Components live as Figma nodes (only visible to designers with file access) and React TSX (only visible to developers reading source).
- **Drift is invisible**: code can deprecate a component without removing the Figma node, and vice versa. We have no detection mechanism.
- **Dark-mode parity is incomplete**: Figma's design tokens exist in Light + Dark variants for color/typography (33 vars), but we don't audit per-component whether each variant has been DESIGNED in dark mode (vs. derived auto from token swap).
- **Motion + elevation tokens are code-only**: durations, easings, shadow scales, z-index ladder all exist in `globals.css` and component patterns but aren't extracted as Figma variables — designers can't reference them.
- **Contribution friction**: no CONTRIBUTING doc means new components added to the codebase have inconsistent Code Connect mapping habits. The Layer B `/design build` skill auto-scaffolds, but the contributor pattern (when to add a primitive vs. reuse, naming, file location) isn't written down.

### User pain points addressed

- **Designers** open Figma, see 17 components in the library, wonder "is that everything? Where do these map in code?" → public showcase route surfaces the answer publicly with code links.
- **Developers** open the React codebase, see 30+ components, can't tell which are "blessed primitives" vs. ad-hoc — contribution guidelines clarify.
- **Maintainers** discover one day the live Figma file has 5 abandoned components nobody updates → drift detection surfaces this within 24h instead of 6 months.
- **Mode-aware reviewers** can't tell if a component has been intentionally designed in dark mode vs. just relies on token swap → matrix doc makes this verifiable per-component.

---

## §3 Why this over alternatives?

| Approach | Pros | Cons | Effort | Chosen? |
|---|---|---|---|---|
| **A. Build it in fitme-story (this proposal)** | Zero new tooling; reuses existing `/glossary` pattern; drift detection via Figma MCP we already use; CI-friendly; same auth model as Code Connect (`FIGMA_ACCESS_TOKEN`) | Custom build = ~1-2 weeks; we own maintenance; does not auto-render variants like Storybook | 1-2 weeks | ✅ |
| **B. Adopt Storybook for the design system** | Industry standard; Chromatic visual regression; HMR for variants; well-known | Major dependency add (Storybook 8 + plugins); separate build pipeline; redirect / iframe / subdomain logistics; doesn't natively integrate Figma; we'd still need #3 drift detection separately | 2-3 weeks | ❌ — adds tooling complexity for marginal gain over option A; doesn't solve the Figma drift problem we already have |
| **C. Use Figma's own "Library Inspector" + Notion docs** | Leverages Figma-native tooling; no code to maintain | Library Inspector is Figma-internal (designer-only); Notion is private (not public); no code links; no drift detection; not what the backlog item asked for | <1 day | ❌ — wrong audience (we want PUBLIC docs that link both code + Figma) |
| **D. Defer everything; ship just MVP showcase route** | Fastest visible win | Doesn't solve drift, dark-mode, motion tokens, contribution friction; ships incomplete value | 1-2 days | ❌ rejected at scope-check |

**Approach A wins** because:
1. We already use Figma MCP (`mcp__claude_ai_Figma__get_metadata`, `get_design_context`) — drift detection is a thin wrapper
2. The `/glossary` route's pattern (typed `src/lib/glossary.ts` → `/glossary` page) generalizes directly to `src/lib/design-system.ts` → `/design-system`
3. Code Connect mappings (already shipped in v4.X+CC) provide the bidirectional Figma↔code link the showcase needs
4. No new external dependencies; no auth/billing surprises like the Code Connect Write scope blocker
5. Contribution doc + dark-mode matrix can ship as plain markdown + a small script — no infrastructure investment

---

## §4 External sources

Public design systems we've studied as references:

- **Vercel/Geist** — <https://vercel.com/geist> — closest tech-stack match (Next.js + Tailwind v4 + dark mode); minimal/editorial aesthetic; component cards with copy-to-clipboard React snippets
- **Linear's design system** — <https://linear.app/method> + the linear.app/changelog component patterns — best-in-class for "developer-friendly minimalism"
- **GitHub Primer** — <https://primer.style/> — comprehensive accessibility coverage; per-component "Status: Stable / Experimental / Deprecated" labels we should adopt
- **Shopify Polaris** — <https://polaris.shopify.com/> — gold standard for component variant exposure; we don't need this much depth but their information architecture is reference-worthy
- **Atlassian Design System** — <https://atlassian.design/> — strong component contribution guidelines (we'll model our CONTRIBUTING doc on this)

Drift detection patterns:

- **Figma Code Connect docs** — <https://developers.figma.com/docs/code-connect/quickstart-guide/> — the publish step inherently surfaces drift (when a `.figma.tsx` references a deleted Figma node, publish fails). We extend with a proactive scan
- **Chromatic** (Storybook-based) — visual regression — overkill for our needs but the principle applies
- **`@figma/restapi` library** — Node SDK for the Figma API — useful for the drift detection script's Figma-side query

Dark-mode token references:

- **Tailwind Dark Mode docs** — <https://tailwindcss.com/docs/dark-mode> — confirmation that `@variant dark` (already in our globals.css) is the canonical pattern
- **WCAG 2.2 AA contrast** — 4.5:1 for body text, 3.0:1 for large text — already enforced in our existing dark-mode overrides per `--color-neutral-500: #A8A29E` etc.

Motion token references:

- **Material Design 3 motion** — <https://m3.material.io/styles/motion/easing-and-duration/tokens-specs> — easing curve naming convention we'll mirror (`emphasized`, `standard`, `decelerate`)
- **Apple Human Interface Guidelines — Motion** — durations standardized at 0.2s/0.3s/0.5s tiers

---

## §5 Market examples (how others solve this)

**Vercel / Geist showcase pattern** is the closest match to what we'd build:

| Section | Vercel implementation | Our adaptation |
|---|---|---|
| Top-level navigation | Sidebar listing component categories | `/design-system` page with anchor sections per category (similar to our `/glossary` page's category headers) |
| Component preview | Live React render in a card with copy-able snippet | Same — render the actual component, link to source on GitHub |
| Variant matrix | Tabs + interactive controls | Inline grid of variants (we have small enough surface to skip interactive controls) |
| Token reference | Dedicated tokens page with swatch grid | Same approach, integrated in the showcase page (top section) |
| Dark mode | System-level toggle | Re-use site-wide theme toggle |
| Code Connect | Each component links to GitHub source | Each component links to BOTH GitHub source AND Figma node URL |

**Linear's "Method" page** style: editorial, principle-led, sparse. We borrow the EDITORIAL voice (sparse copy, type-led layout) but the INFORMATION DENSITY is closer to Vercel/Geist.

**GitHub Primer's "Status" labels** — Stable / Experimental / Deprecated / Internal — we'll add a `status` field to `src/lib/design-system.ts` so designers can see component maturity at a glance.

---

## §6 Design inspiration & UI patterns (since has_ui = true)

For the public `/design-system` route, the page structure mirrors our existing `/glossary` page (proven pattern in this repo):

```
┌─────────────────────────────────────────┐
│  Hero — "fitme-story design system"     │
│  brief + token count + component count  │
├─────────────────────────────────────────┤
│  Section anchor nav (sticky):            │
│  Tokens · Primitives · Layout · Cards   │
│  · Callouts · Search · Bespoke          │
├─────────────────────────────────────────┤
│  §1 Tokens                               │
│   • Color swatches (Light + Dark grid)   │
│   • Type scale (display-xl through body) │
│   • Spacing ladder                       │
│   • Motion + elevation (NEW per #5)      │
├─────────────────────────────────────────┤
│  §2 Primitives                           │
│   • Button × 3 variants (rendered live)  │
│   • Tag × 3 variants                     │
│   • For each: Status badge, GitHub link, │
│     Figma node link, code snippet        │
├─────────────────────────────────────────┤
│  §3 Layout                               │
│   • SiteHeader, SiteFooter, MobileNav,   │
│     SearchInput                          │
├─────────────────────────────────────────┤
│  §4–7 Cards / Callouts / Bespoke         │
│   (CaseStudyCard, FrameworkVersionCard,  │
│   5 callouts, control-room components)   │
└─────────────────────────────────────────┘
```

UX principles applied:
- **Recognition over recall** (Nielsen) — every component visible at a glance; designers don't need to remember names
- **Progressive disclosure** — top-level shows component name + 1 variant; click to expand to all variants + props
- **Consistency** — page structure mirrors `/glossary` so users carry mental model across both
- **Feedback** — copy-to-clipboard buttons on code snippets; visual confirmation on click

Dark-mode handling: every preview area renders in BOTH Light and Dark side-by-side (or a small mode toggle per section) so designers can verify parity at a glance.

---

## §7 Data & demand signals

Why now? Three signals:

1. **Just-shipped foundation** — Code Connect for both web (17 mappings, deferred publish) + iOS (6 mappings, deferred publish) closed 2026-05-10. Now the right time to build the OBSERVABILITY layer (showcase + drift detection) before the next round of UI features lands and entropy grows
2. **Backlog item velocity** — added 2026-05-09 via PR #274; 1 day between addition and prioritization signals strong intent
3. **Code Connect publish blocker** — even though publish is gated by Figma plan-tier scope (per `code-connect-automation` closure), the SHOWCASE ROUTE works WITHOUT publish — it reads the same `figma_node_ids` data + renders our React components directly. Decoupling lets us ship visible value while waiting on the Figma scope unblock

Quantitative: today the website has **0 public design-system surfaces**. After this feature: **1 (the `/design-system` route)** + **1 drift report cadence** + **1 dark-mode matrix** + **1 contribution doc**.

---

## §8 Technical feasibility

| Layer | Risk | Mitigation |
|---|---|---|
| Public `/design-system` route on Next.js 16 | None — pattern exists for `/glossary` | Direct port |
| Component live-render | Components must be server-render-safe (no hooks-in-effects breakage) | Most components already are; primitives (Button/Tag/CaseStudyCard/FrameworkVersionCard) are confirmed server-friendly per PR #80 |
| Drift detection script | Figma API rate limits | Run script on-demand or daily (not per-PR); cache the Figma API response; respect rate limits per Figma's documented thresholds |
| Dark-mode matrix doc | Manual verification per component | Yes manual — but small surface (~30 components), one-time pass + maintenance per new component (~5 min each) |
| Motion + elevation tokens | Already exist in code; just need extraction | Use existing `figma:figma-use` skill + `figma-generate-library` skill (loaded earlier this session for ios-code-connect work) |
| Contribution guidelines | None | Pure markdown |

**Existing infrastructure we benefit from:**

- `/glossary` route + `src/lib/glossary.ts` typed manifest pattern (proven, shipped)
- Figma MCP (`mcp__claude_ai_Figma__*`) for the drift detection script
- Code Connect mappings (12 .figma.tsx files) — showcase route reads these to generate the Figma-link side
- `@figma/code-connect@1.4.4` already in devDeps
- Tailwind v4 `@theme` block with 33 tokens — straightforward to extend with motion/elevation
- Existing case-study-audit script + audit-frontmatter.mjs as patterns for the drift detection script

**Unknowns:**
- Will the drift detection script find ANY drift on first run? (Empirical — we don't know yet; if it finds many findings, that's data; if it finds zero, the system is healthier than we think)
- Does adding motion tokens to Figma break any existing usage? (Unlikely — adding new tokens is non-destructive; old patterns continue to work)

---

## §9 Proposed success metrics

### Primary metric

**`design_system_figma_parity_coverage`** = `(components with .figma.tsx mapping + Figma node ID + showcase entry) / (total React components with user-visible UI)`

- **Baseline:** ~57% (17 mapped of ~30 components)
- **Target:** ≥ 95%
- **Measurement:** automated via the drift detection script (deliverable #3); reports on every CI run touching components

### Secondary metrics

- **`figma_build_status_deferred_count`** — number of features still using `figma_build_status: "deferred_to_prompt"`. Target: 0 after showcase route lands. Today: tracked manually.
- **`dark_mode_parity_coverage`** — `(components with verified Light+Dark Figma frames) / (total components)`. Target: 100%. Baseline: TBD (deliverable #4 produces the matrix).
- **`time_to_render_design_system_route`** — page LCP for `/design-system`. Target: ≤ 2.0s p75. Baseline: N/A (route doesn't exist yet).

### Guardrail metrics (must NOT degrade)

- **Homepage LCP** — must not increase by > 100ms. The `/design-system` route is its own page; it shouldn't affect home performance, but bundle size could.
- **Build time** — must not increase by > 30s. Component rendering at build time could slow the static generation pass.
- **`/glossary` LCP** — sister route; must not regress as a result of changes to shared layout.

### Leading indicators (week 1)

- `/design-system` route is live and accessible
- Drift detection script runs; produces a report
- Contribution doc published

### Lagging indicators (30/60/90 day)

- 30d: How many new components added? Did they all hit `figma_parity_coverage` threshold within the same PR?
- 60d: Drift detection report findings count — trending up = entropy increasing → need stricter gate; flat or down = system is self-maintaining
- 90d: Number of designer-team-external commits to the contribution doc — proxy for whether contributors actually use it

### Instrumentation plan

GA4 events (`requires_analytics: true`):
- `design_system_section_view` — fires on scroll into each section anchor
- `design_system_component_expand` — fires on clicking a component card to expand variants
- `design_system_code_copy` — fires on copy-to-clipboard on a code snippet
- `design_system_figma_link_click` — fires on clicking the Figma node link

These all feed `screen_scope: design_system` in `analytics-taxonomy.csv` per CLAUDE.md naming convention.

### Review cadence

- **Week 1 post-merge** — verify route renders; spot-check drift report
- **Week 4** — measure secondary metrics; review GA4 funnel
- **Quarter 1** (90d) — full metric review; decide on iteration vs. extension

### Kill criteria

- Drift between Figma file and code repeatedly exceeds 10% within 30 days of a build pass (i.e., maintenance burden outpaces value) → narrow scope to showcase route only; treat full Figma parity as documentation-grade rather than living source of truth
- Public `/design-system` route adds > 200ms to homepage LCP → roll back the shared-layout coupling; isolate
- Contribution doc adoption < 3 commits/month from non-author contributors after 60 days → simplify or reframe (was it the wrong format?)

---

## §10 Decision

**Recommendation:** Ship all 6 deliverables as a single Feature (full 9-phase lifecycle), sequenced as follows in Phase 2 (Tasks):

| Sequence | Deliverable | Why this order |
|---|---|---|
| 1st | Motion + elevation + z-index tokens (#5) | Foundation — other components reference these; quick win (~1-2h via Figma MCP) |
| 2nd | Public `/design-system` showcase route (#1) | Primary user-visible deliverable; biggest visibility lift |
| 3rd | Component coverage expansion (#2) | Builds on #1's manifest pattern; adds the missing 13+ components |
| 4th | Drift detection (#3) | Now has a complete corpus to detect drift against |
| 5th | Dark-mode parity audit (#4) | Per-component matrix; can run in parallel with #2/#3 if helpful |
| 6th | Contribution guidelines (#6) | Documents the system once stable + observable |

**Estimated effort:** ~1.5-2 weeks for a single concentrated session, or ~3-4 weeks if interspersed with other work. The 6 deliverables are not equally weighted — items #1 + #3 are the value drivers; items #2/#4/#5/#6 are completeness work.

**Out of scope:**
- Storybook integration (rejected per §3)
- Visual regression testing (Chromatic-style) — out of scope for v1; revisit if drift report surfaces visual-only drift not caught by node ID checks
- Multi-language support for the showcase page — English-only matches existing `/glossary` and `/case-studies`
- Automated component generator CLI (`npx fitme-story add-component`) — overkill given the small contributor base

**Risks:**
- (low) Dark-mode parity audit reveals widespread gaps requiring designer time — manageable; can ship matrix doc with "TODO" entries and fill incrementally
- (low) Drift detection finds significant pre-existing drift — actually a good thing, surfaces tech debt
- (med) Code Connect publish remains blocked — does NOT block this feature; showcase route works without Code Connect publish

---

## §11 Companion docs + cross-references

- Backlog item: [`docs/product/backlog.md`](../../docs/product/backlog.md) line ~169
- Web architecture: [`docs/design-system/fitme-story-design-architecture.md`](../../docs/design-system/fitme-story-design-architecture.md) (T21 of rollup feature)
- iOS-side parallel: [`docs/design-system/ios-code-connect-workflow.md`](../../docs/design-system/ios-code-connect-workflow.md) (with the recently-added "Known external blocker" section)
- Predecessor closure: [`code-connect-automation/state.json`](../code-connect-automation/state.json) (closed 2026-05-10)
- Sister design system docs: [`docs/skills/design.md`](../../docs/skills/design.md), [`docs/skills/evolution.md`](../../docs/skills/evolution.md) §27 (v4.X+CC)
- Related v8.0+ candidates: backlog item "Complete Figma design + architecture for both surfaces (iOS app + fitme-story website)" — partial overlap; this feature handles the fitme-story side independently

**End of research phase.** Awaiting user approval to advance to Phase 1 (PRD).
