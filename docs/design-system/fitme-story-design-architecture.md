# fitme-story Design System Architecture

> ⛔ **Code Connect DISABLED 2026-06-15.** Figma Code Connect requires an Org/Enterprise plan; this account is Pro, so the web `.figma.tsx` publish bridge is non-operational (workflow is a disabled stub; the Figma file `fsjHfFLAHELACZHku8Rfcl` is empty/partial). The `globals.css` → component architecture described below is real and operational; only the Code Connect / Figma-Dev-Mode mapping layer is inert. **Code is the source of truth.** See [`figma-source-of-truth-plan-2026-06-15.md`](./figma-source-of-truth-plan-2026-06-15.md) + honesty ledger FT2-FH-005.

**Created:** 2026-05-08
**Closes:** [fitme-story-public-enhancements](../../.claude/features/fitme-story-public-enhancements/state.json) T21 (audit ID **FIG-W6**)
**Source:** [`fitme-story/src/app/globals.css`](https://github.com/Regevba/fitme-story/blob/main/src/app/globals.css)
**Companion docs:** [`docs/design-system/feature-development-gateway.md`](./feature-development-gateway.md) (the iOS-side gateway, parallel doc), [`fitme-story EXTRACTION-RECIPE.md`](https://github.com/Regevba/fitme-story/blob/main/EXTRACTION-RECIPE.md) (UCC migration playbook)

---

## §1 What this doc is

A reference for how the fitme-story Next.js app's design system is wired together. Lives in FT2 because:

- FT2 is the framework's documentation home; cross-repo design contracts belong in one place
- The `/design build` skill (FT2-side) reads this doc to know what tokens to expect when it pushes screens to Figma (T18 FIG-W1 in the queue)
- Cross-repo features (UCC, ucc-passkey-auth) reference it from their FT2 state.json + case studies

**This doc is NOT a tutorial.** Readers are assumed to know Tailwind v4 + Next.js 16 + React 19. It documents the contracts, the rationale, and the maintenance protocol — not how to use Tailwind.

---

## §2 The big picture

fitme-story uses **Tailwind v4 with `@theme`-defined CSS variables** as the single source of truth for design tokens. There is no Style Dictionary, no design-tokens.json, no token build pipeline. The CSS file is the canonical token store.

```
fitme-story/src/app/globals.css
├── @theme block — declares CSS variables consumed by Tailwind v4 utilities + components
├── html { } base — applies neutral-900/50 colors site-wide
├── html.dark { } overrides — WCAG-tuned shifts for dark mode
├── @media (prefers-reduced-motion) — disables animation site-wide
├── Native Safari quirk fixes — display:none on <details>::-webkit-details-marker etc.
└── .prose table { } overrides — editorial table styling (T4 mobile-overflow fix included)
```

That's the whole token surface. ~160 lines of CSS, no build step beyond Tailwind's standard PostCSS pipeline.

---

## §3 Token inventory

### Brand palette (2 colors × 2 modes)

| Token | Light hex | Dark hex | Usage |
|---|---|---|---|
| `--color-brand-indigo` | `#4F46E5` | `#818CF8` | Primary CTA, link text, focus ring, current-page underline |
| `--color-brand-indigo-hover` | `#4338CA` | (no override) | Hover state for indigo elements |
| `--color-brand-coral` | `#F97066` | `#FDA29B` | Flagship case-study chip, kill-criterion-fired banner, accent secondaries |
| `--color-brand-coral-hover` | `#F15048` | (no override) | Hover state for coral elements |

**Why indigo + coral together:** indigo signals framework/structure (the PM workflow); coral signals warning/important (kill criteria, flagship). The pair is high-contrast against both editorial neutrals (warm grays) and pure white/black.

### PM-flow skill palette (11 colors)

One color per skill in the PM workflow. All from Tailwind's `*-500` family for consistent perceived brightness + WCAG AA against both light and dark editorial backgrounds.

| Token | Hex | Skill |
|---|---|---|
| `--skill-pm-workflow` | `#4F46E5` (indigo, reuses brand) | hub orchestrator |
| `--skill-research` | `#F59E0B` (amber) | /research |
| `--skill-ux` | `#D946EF` (fuchsia) | /ux |
| `--skill-design` | `#EC4899` (pink) | /design |
| `--skill-dev` | `#0EA5E9` (sky) | /dev |
| `--skill-qa` | `#84CC16` (lime) | /qa |
| `--skill-analytics` | `#06B6D4` (cyan) | /analytics |
| `--skill-cx` | `#F43F5E` (rose) | /cx |
| `--skill-marketing` | `#F97316` (orange) | /marketing |
| `--skill-ops` | `#64748B` (slate) | /ops |
| `--skill-release` | `#10B981` (emerald) | /release |

**Used by:** `LegoWall`, `LifecycleLoop`, `EvolutionStrip`, `SharedDataTiles`, `CacheTiers` (all in `src/components/pm-flow/`); the `Term` MDX component when rendering skill-named glossary entries; the case-study comparison table's per-skill chips.

### Editorial neutrals (warm grays, 7 stops)

| Token | Light hex | Dark hex (when overridden) | Notes |
|---|---|---|---|
| `--color-neutral-50` | `#FAFAF9` | (bg only) | Site background light |
| `--color-neutral-100` | `#F5F5F4` | (no override) | Card backgrounds, hover states |
| `--color-neutral-200` | `#E7E5E4` | (no override) | Borders, dividers |
| `--color-neutral-300` | `#D6D3D1` | (no override) | Secondary borders |
| `--color-neutral-500` | `#5C5754` ⚠ | `#A8A29E` | Body text secondary; bumped from `#78716C` (4.16:1 fail) → `#5C5754` (4.83:1 pass) on 2026-05-08 per audit A-002 + A-018 |
| `--color-neutral-700` | `#44403C` | `#D6D3D1` | Body text primary |
| `--color-neutral-800` | `#292524` | (no override) | Card backgrounds dark |
| `--color-neutral-900` | `#1C1917` | (bg only) | Site background dark |

**Warm grays (not pure neutrals)** because the editorial type calls for serif body + serif display. Pure cool grays read as "tech blog"; warm grays read as "longform editorial". Stylistic choice that's load-bearing for the showcase tone.

### Editorial measures (line-length budget)

| Token | ch | px (at 17px body) | Use |
|---|---|---|---|
| `--measure-narrow` | 58ch | ~580px | Tight reading column (intro paragraphs, deck) |
| `--measure-body` | 65ch | ~650px | Default body width on Standard/Flagship case-study templates |
| `--measure-wide` | 72ch | ~720px | Light template + ops-combined (slightly wider) |

All three are **constraint tokens** — used by the case-study templates' `max-w-[var(--measure-*)]` to enforce a healthy reading column regardless of viewport width.

### Editorial type scale

| Token | clamp | Use |
|---|---|---|
| `--text-body` | `1.0625rem` (17px) | Body — passes iOS no-zoom-on-focus threshold |
| `--text-body-lh` | `1.7` | Body line-height |
| `--text-display-xl` | `clamp(2.5rem, 5vw, 4.5rem)` | Flagship case-study h1 |
| `--text-display-lg` | `clamp(2rem, 4vw, 3.25rem)` | Standard / Light case-study h1 + section landings |
| `--text-display-md` | `clamp(1.5rem, 3vw, 2.25rem)` | Card titles, eyebrow → h2 transitions |

**No display-sm or display-xs** — any heading smaller than `display-md` falls back to Tailwind's `text-2xl` / `text-xl` / `text-lg` typography defaults. Keeps the scale shallow + decisions explicit.

---

## §4 Dark mode contract

`html.dark` is the toggle (set by [`SiteHeader`](https://github.com/Regevba/fitme-story/blob/main/src/components/SiteHeader.tsx) on user click + [`MobileNav`](https://github.com/Regevba/fitme-story/blob/main/src/components/MobileNav.tsx) drawer toggle, persisted to `localStorage` + initial OS-preference read via `useSyncExternalStore`).

The 4 dark-mode overrides in `globals.css` are intentional WCAG fixes — light-mode hex values that fail AA on dark backgrounds:

| Token | Light → Dark | WCAG status |
|---|---|---|
| `--color-neutral-500` | `#5C5754` → `#A8A29E` | Both pass 4.5:1 against their respective backgrounds |
| `--color-neutral-700` | `#44403C` → `#D6D3D1` | Body text primary — passes both |
| `--color-brand-indigo` | `#4F46E5` → `#818CF8` | Light passes ~6.8:1; dark passes ~4.7:1 |
| `--color-brand-coral` | `#F97066` → `#FDA29B` | Light borderline at small body; dark passes 3.5:1 (fine for large text) |

**Maintenance rule:** when adding a new color token to `@theme`, audit it against BOTH backgrounds (#FAFAF9 light + #1C1917 dark) using a contrast checker. If it fails AA on either, add the appropriate override in the `html.dark { }` block. Never ship a token that fails AA on either mode.

---

## §5 Component architecture

Three layers, top-down:

```
┌──────────────────────────────────────────────────────────────────┐
│ Layout layer                                                      │
│   src/app/layout.tsx — root <html><body> with SiteHeader/Footer  │
│   Per-route layout.tsx — case-study templates, control-room      │
└──────────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────────────────┐
│ Shared chrome                                                     │
│   SiteHeader, SiteFooter — global nav + footer                   │
│   MobileNav — hamburger drawer (md:hidden)                        │
│   Hero, OriginNarrative, Timeline, NumbersPanel — homepage       │
│   PersonaBar, PersonaIndicator — persona switcher                │
└──────────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────────────────┐
│ MDX components (registered in src/mdx-components.tsx)            │
│   pre → Pre wrapper (syntax highlighting + CopyButton, T17)      │
│   MetricsCard, Pullquote, Figure, TimelineNav, FindingsTable,    │
│   DevDive, Term — editorial primitives                           │
│   Plus 13 case-study visual aids + 4 bespoke components          │
└──────────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────────────────┐
│ Case-study templates                                              │
│   LightTemplate / StandardTemplate / FlagshipTemplate            │
│   alt-a-chrome — SummaryCard / DataKey / KillCriterionBanner /   │
│     DeferredItemsList / VisualAidResolver                         │
│   Plus the queued ArticleNav sidebar (T7, ships next)            │
└──────────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────────────────┐
│ Control-room (UCC, /control-room/* — auth-gated, separate audit) │
│   Panel, MetricList, AlertsBanner, TrackedDocLink                │
│   AuthPasskeyForm, DevicesTable, AuditEventRow, AuditLogPanel    │
│   (out of scope for this doc — see UCC case study)               │
└──────────────────────────────────────────────────────────────────┘
```

**Key invariants:**

- **No raw colors in component className.** Every color reference is `text-[var(--color-*)]` or `bg-[var(--color-*)]`. Never `text-red-500`. (Few exceptions: T1/T2/T3 tier badges use Tailwind's `*-700` on `*-100` for fixed visual identity.)
- **No raw font-size in component className.** Every size is `text-[length:var(--text-*)]` or Tailwind's named sizes (`text-sm`, `text-base`, `text-2xl`). Display sizes always go through the type scale.
- **No raw spacing in className.** Tailwind's `p-*`, `m-*`, `gap-*`, `space-*` only. (Exception: `min-h-[44px]` for touch-target enforcement — this is a numeric constant, not a spacing token.)
- **Every interactive element has `focus-visible` outline.** Pattern: `focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[var(--color-brand-indigo)]`. Audit A-008 (2026-05-08) made this corpus-wide; new components must include it.

---

## §6 The `/design build` contract (forward-looking)

When the Figma track lands (T18 FIG-W1 → T19 FIG-W2 → T12 FIG-P4 → T20 FIG-W5), `/design build` (FT2-side skill) will push fitme-story screens into the new "FitMe Story Web — Design System" Figma file via Figma MCP.

The contract `/design build` enforces against this Figma file:

1. **Token names match between Figma variables and CSS variables.** The Figma file uses variable names exactly matching the CSS custom properties — `--color-brand-indigo` in CSS = `color/brand/indigo` in Figma (slash-separated for Figma's variable hierarchy). Mismatches block `/design build` from completing.

2. **Type scale matches.** The 5 editorial type tokens (`text-body`, `text-display-xl/lg/md`) exist as Figma text styles with the same names. Components that use `text-[length:var(--text-display-lg)]` map to "display/lg" in Figma.

3. **Component frames match registered MDX components.** When `/design build` pushes a case-study screen to Figma, the page's component instances must resolve to Figma components named after their TSX counterparts (`SummaryCard` in TSX → `summary-card` Figma component).

4. **Skip rules.** Components flagged with `figma_build_status: "deferred_to_prompt"` in their host feature's state.json are exempt — `/design build` writes a portable prompt to `docs/prompts/ui/{date}-{feature}-design-build.md` instead of pushing to Figma. The escape hatch documented in v4.X (used by ucc-passkey-auth, ucc itself, and this rollup feature for any per-task deferrals).

Until T18 lands, `/design build` defers to the prompt fallback for every fitme-story feature. After T18, the prompt fallback becomes the documented escape hatch (rare, with reason).

---

## §7 Maintenance contract

### When adding a new color token

1. Add to `@theme { ... }` in `globals.css` — light value
2. Audit against both `#FAFAF9` (light bg) and `#1C1917` (dark bg) for WCAG AA
3. If light value fails on dark bg, add an override in `html.dark { ... }` block
4. Document the rationale in a comment next to the token (audit ID + date when known)
5. When Figma file exists (post-T18): mirror the variable in Figma using slash-separated naming

### When adding a new component

1. Create under `src/components/<area>/` (mdx, ui, home, pm-flow, case-study, bespoke, control-room)
2. Use **only** `var(--color-*)` for colors, `var(--text-*)` for display sizes, Tailwind named utilities for everything else
3. Include `focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[var(--color-brand-indigo)]` on every interactive element
4. Touch targets ≥ `min-h-[44px]` and `min-w-[44px]` for any clickable
5. If MDX-renderable, register in `src/mdx-components.tsx`
6. When Figma file exists (post-T18): build the matching Figma component before merging the TSX

### When adding a new MDX component to `mdx-components.tsx`

1. Same color/spacing/focus rules as §7.2
2. Server component by default (RSC); only mark `'use client'` if state, refs, or browser APIs needed
3. If it accepts MDX children (like `Pullquote` or `DevDive`), document the expected children shape in a JSDoc above the function
4. Add to the registration export list in `useMDXComponents()`

### When updating `globals.css`

Any change to tokens or layout-level rules MUST be captured in the audit synthesis trail OR a follow-up case study (per the verbatim-then-remediate rule). Don't silently change a token value — the audit trail explains why.

---

## §8 Cross-references

- **Audit synthesis:** [`docs/research/2026-05-08-fitme-story-audit-synthesis.md`](../research/2026-05-08-fitme-story-audit-synthesis.md) — surfaced FIG-W6 + the queue items this architecture supports
- **Website-enhancement-queue spec:** [`docs/superpowers/specs/2026-05-08-fitme-story-website-enhancement-queue.md`](../superpowers/specs/2026-05-08-fitme-story-website-enhancement-queue.md) — Figma track tasks (FIG-W1, FIG-W2, FIG-W5, FIG-U3, FIG-U4, FIG-P4)
- **Dual-outlet pattern:** [`docs/case-studies/dual-outlet-pattern.md`](../case-studies/dual-outlet-pattern.md) — case-study writing contract that uses the design tokens documented here
- **Visual-aid catalog:** [`docs/design-system/case-study-visual-aid-catalog.md`](./case-study-visual-aid-catalog.md) — registry of the 13 case-study visual-aid components
- **iOS-side parallel:** [`docs/design-system/feature-development-gateway.md`](./feature-development-gateway.md) — the iOS app's design-system gateway (parallel to this doc, different stack)
- **fitme-story extraction recipe:** [`fitme-story/EXTRACTION-RECIPE.md`](https://github.com/Regevba/fitme-story/blob/main/EXTRACTION-RECIPE.md) — playbook for moving the showcase into a separately-extractable repo

---

## §9 What this doc is NOT

- **Not a Tailwind v4 tutorial.** Readers are assumed to know `@theme` directive, CSS variables, dark variants. If you don't, [Tailwind v4 docs](https://tailwindcss.com/docs) first.
- **Not a Figma file.** The Figma file doesn't exist yet (queued as T18 FIG-W1). When it lands, this doc will gain a §10 cross-referencing the Figma library URL + Code Connect mapping spec.
- **Not a token autogen spec.** There is no Style Dictionary / token build pipeline. The CSS file is the source of truth. (If we later add iOS app token generation from this CSS, that's a separate spec.)
- **Not an immutable architecture decision.** When the corpus grows or the audit produces new findings, this doc gets updated. Last update: 2026-05-08 (T21 ship).
