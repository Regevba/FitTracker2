# UX Spec — /design-system route (two-part page)

**Phase:** 3 (UX/Integration)
**Framework:** v7.8.2
**Created:** 2026-05-10
**Companion:** [`prd.md`](./prd.md), [`tasks.md`](./tasks.md)
**Layout strategy:** **Two-part page** (user-locked 2026-05-10): existing iOS narration preserved up top, fitme-story website showcase added below.

---

## §1 Preflight findings

Surfaced before drafting:

- **Existing `/design-system/page.tsx` (322 lines)** is iOS-narration-heavy: 13 principles, iOS onboarding flow (6 PNGs), iOS live-app flow (4 PNGs), tokens (mixed: tokens are website-side, components are iOS), iOS pipeline diagram. Preserve as-is in upper half.
- **Existing `src/lib/design-tokens.ts`** holds Brand/Skill/Neutrals/Type/Measures swatches — usable for both halves.
- **Existing `src/lib/design-system-components.ts`** holds 13 iOS App* components — iOS-side only.
- **Existing `@theme` block** has color, neutrals, measures, type tokens. Missing: motion, elevation, z-index, radius, shadow tokens.
- **Existing 12 `.figma.tsx` files** in canonical fitme-story (`SiteHeader/SiteFooter/SearchInput`, `ui/{Button,Tag,CaseStudyCard,FrameworkVersionCard}`, 5 mdx callouts).
- **`figma.config.json`** present at fitme-story root; SPM wrapper unused (web-side only).
- **30+ control-room components** (control-room/, bespoke/, case-study/) — many beyond what the PRD listed; we'll start with the PRD's 13-component list and expand opportunistically.

**Preflight verdict:** PASS. All referenced surfaces exist or are explicitly being created. No blocking inconsistencies.

---

## §2 Page structure (final layout)

```
/design-system  (single route, single page, two clearly-labeled halves)

┌──────────────────────────────────────────────────────────────────┐
│  HEADER                                                           │
│  H1: "The design system"                                          │
│  Sub: "Two systems, one story — the iOS app and the framework    │
│       story site share principles, tokens, and discipline."     │
│  Anchor nav (sticky on desktop, collapsed on mobile):            │
│  [The iOS app's design system] [The fitme-story website's        │
│   design system] [Tokens] [Components] [Drift] [Dark-mode] [Contribute] │
└──────────────────────────────────────────────────────────────────┘

PART 1 — THE iOS APP'S DESIGN SYSTEM (existing content, preserved)
┌──────────────────────────────────────────────────────────────────┐
│  §1.1 The 13 principles                       [existing]          │
│  §1.2 Onboarding flow — 6 screens             [existing]          │
│  §1.3 Live app — daily use with mock data     [existing]          │
│  §1.4 Under the hood (Disclosure x3)          [existing]          │
│       - Semantic tokens (Brand/Skill/Neutrals/Type/Measures)     │
│       - Components (13 App* iOS components)                      │
│       - Pipeline (tokens.json → Style Dictionary → Swift)        │
└──────────────────────────────────────────────────────────────────┘

═══ Visual divider ═══
"The system that renders the story site itself" lead-in paragraph

PART 2 — THE fitme-story WEBSITE'S DESIGN SYSTEM (new content)
┌──────────────────────────────────────────────────────────────────┐
│  §2.1 Tokens (extending §1.4 with motion + elevation + z-index)  │
│       - Motion: durations + easings (NEW)                        │
│       - Elevation: 4 levels with shadow specs (NEW)              │
│       - Z-index: base/header/modal/toast (NEW)                   │
│       (Re-uses existing token swatches for color/type/measure)   │
├──────────────────────────────────────────────────────────────────┤
│  §2.2 Primitives                                                  │
│       Live render of: Button × 3 variants, Tag × 3 variants,     │
│       CaseStudyCard, FrameworkVersionCard.                        │
│       Each card: status badge + GitHub link + Figma node link    │
│       + copy-to-clipboard React snippet + dark-mode toggle.      │
├──────────────────────────────────────────────────────────────────┤
│  §2.3 Layout components                                           │
│       SiteHeader, SiteFooter, MobileNav, SearchInput.             │
│       Same card pattern as §2.2.                                  │
├──────────────────────────────────────────────────────────────────┤
│  §2.4 Control-room components                                     │
│       Panel, MetricList, AlertsBanner, TrackedDocLink,            │
│       AuthPasskeyForm, DevicesTable, AuditEventRow,               │
│       AuditLogPanel, FeatureCard, TaskCard.                       │
│       Status badges most likely "Internal" — these power          │
│       /control-room (gated).                                      │
├──────────────────────────────────────────────────────────────────┤
│  §2.5 Persona components                                          │
│       PersonaBar, PersonaIndicator, PersonaLens.                  │
├──────────────────────────────────────────────────────────────────┤
│  §2.6 MDX callouts                                                │
│       MemoryRef, TriggerIncident, KillCriterionResolution,        │
│       PredecessorChain, HonestDisclosure (5 callouts).            │
├──────────────────────────────────────────────────────────────────┤
│  §2.7 Drift report (latest snapshot)                              │
│       Inline card showing: total components, mapped count,        │
│       parity %, count of unresolved IDs, count of orphans.        │
│       "Last run" date. Link to figma-code-sync-status.md          │
│       for the historical log.                                     │
├──────────────────────────────────────────────────────────────────┤
│  §2.8 Dark-mode parity matrix                                     │
│       Table from fitme-story-dark-mode-coverage.md, summarized.  │
│       Per-component ✓ Designed / ◑ AutoDerived / ✗ TODO badge.   │
│       Stats summary: "26/30 components have verified dark mode"  │
├──────────────────────────────────────────────────────────────────┤
│  §2.9 How to contribute (footer summary)                          │
│       3-bullet teaser: when to add vs. reuse, naming + status,   │
│       Code Connect mapping checklist. Links to                   │
│       CONTRIBUTING-design-system.md for the full doc.            │
└──────────────────────────────────────────────────────────────────┘
```

---

## §3 Component card layout (used in §2.2-§2.6)

Each component in Part 2 renders as a `ComponentCard` with this structure:

```
┌─────────────────────────────────────────────────────────────────┐
│  HEADER ROW                                                      │
│  ComponentName   [Stable | Experimental | Deprecated | Internal] │
│  one-line purpose (< 80 chars)                                   │
├─────────────────────────────────────────────────────────────────┤
│  PREVIEW ROW (Light + Dark side-by-side)                         │
│  ┌─────────────┐    ┌─────────────┐                             │
│  │  Live       │    │  Live       │                             │
│  │  render     │    │  render     │                             │
│  │  (Light)    │    │  (Dark)     │                             │
│  └─────────────┘    └─────────────┘                             │
├─────────────────────────────────────────────────────────────────┤
│  VARIANT GRID (if .variants[] populated)                         │
│  variant-1 · variant-2 · variant-3                               │
├─────────────────────────────────────────────────────────────────┤
│  META ROW                                                         │
│  [GitHub source ↗]  [Figma node ↗]  [Copy snippet ⧉]            │
└─────────────────────────────────────────────────────────────────┘
```

**Status badge color tokens** (apply via `data-status` attribute):
- Stable → `--color-brand-indigo` background + white text
- Experimental → `--skill-research` (amber) background + dark text
- Deprecated → `--color-neutral-500` background + white text + strikethrough name
- Internal → `--color-neutral-700` background + neutral-100 text

**Behavioral notes:**
- Click on the component name: jump to anchor (URL fragment update for sharing)
- Click on Figma node: opens new tab to `https://www.figma.com/design/fsjHfFLAHELACZHku8Rfcl/...?node-id=N-N`
- Click on Copy snippet: writes a 4-6 line React import + usage example to clipboard, fires GA4 event, shows transient ✓ for ~1.5s

---

## §4 Tokens to add (Phase 4 — Bucket A)

Add to `@theme` block in `globals.css` AND mirror in `src/lib/design-tokens.ts` (extended) AND in Figma file `fsjHfFLAHELACZHku8Rfcl` variable collection (new "Motion + Elevation + Z" collection or extension of existing).

### Motion tokens

```css
/* Light + Dark identical */
--motion-duration-fast: 120ms;
--motion-duration-standard: 200ms;
--motion-duration-slow: 320ms;

--motion-easing-standard: cubic-bezier(0.4, 0, 0.2, 1);
--motion-easing-decelerate: cubic-bezier(0, 0, 0.2, 1);
--motion-easing-emphasized: cubic-bezier(0.2, 0, 0, 1);
```

### Elevation tokens

```css
/* Light */
--elevation-1: 0 1px 2px rgb(0 0 0 / 0.06);
--elevation-2: 0 4px 8px rgb(0 0 0 / 0.08);
--elevation-3: 0 8px 16px rgb(0 0 0 / 0.10);
--elevation-4: 0 16px 32px rgb(0 0 0 / 0.12);

/* Dark — slightly stronger to compensate for lower contrast against neutral-900 */
@variant dark {
  --elevation-1: 0 1px 2px rgb(0 0 0 / 0.4);
  --elevation-2: 0 4px 8px rgb(0 0 0 / 0.5);
  --elevation-3: 0 8px 16px rgb(0 0 0 / 0.6);
  --elevation-4: 0 16px 32px rgb(0 0 0 / 0.7);
}
```

### Z-index tokens

```css
--z-base: 0;
--z-elevated: 10;     /* dropdown trigger, hover state */
--z-header: 100;      /* sticky site header */
--z-modal: 1000;      /* dialog, drawer */
--z-toast: 10000;     /* snackbar, transient feedback */
```

**Motivation:** matches Material Design 3 motion vocabulary (decelerate / emphasized / standard) and Apple HIG duration tiers (fast / standard / slow). Z-index ladder uses 10× spacing so insertions are easy.

---

## §5 Accessibility specifications

### Keyboard navigation

- Anchor nav links use real `<a href="#anchor">` — Tab order matches visual order
- Component cards: each card's interactive elements (status, links, copy button) Tab-reachable; entire card NOT a single tab stop
- Skip-to-content link at top of page (already exists site-wide; verify it works on this route)
- Focus rings: use existing `--color-brand-indigo` outline at 2px offset (matches site default)

### Screen reader

- `<h1>` page title; `<h2>` per section; `<h3>` per component card
- Status badges: `aria-label="Component status: Stable"` on visual-only badge
- "Copy snippet" button: `aria-label="Copy {ComponentName} React snippet to clipboard"`; transient ✓ feedback uses `aria-live="polite"` region
- Light/Dark side-by-side previews: each wrapped in `<figure>` + `<figcaption>` with explicit "Light variant"/"Dark variant" text
- Drift report: numbers announced with context ("28 of 30 components mapped, 93%")

### Contrast

- All text meets WCAG 2.2 AA: 4.5:1 body, 3.0:1 large text. Already enforced site-wide via the audit-A-002+A-018 fix to `--color-neutral-500`.
- Status badges: contrast checked per badge color/text combination; document in dark-mode parity matrix

### Reduced motion

- Component preview animations (variant transitions, copy-to-clipboard ✓ fade) wrapped in `@media (prefers-reduced-motion: reduce)` to disable
- Status hint: `@media (prefers-reduced-motion: reduce) { transition: none; }` applied to all motion-token usage in this route

### Dark mode

- Page renders cleanly in both modes (existing site convention)
- Each component preview shows BOTH simultaneously per §3, so reviewers can verify per component

---

## §6 Responsive breakpoints

Mirror existing site convention (`max-w-4xl mx-auto`, single-column on mobile, multi-column on tablet+):

| Breakpoint | Layout |
|---|---|
| < 640px (mobile) | Single column. Anchor nav collapses into a select dropdown. Component preview row stacks Light → Dark vertically (not side-by-side). |
| 640px – 1024px (tablet) | Anchor nav becomes a sticky horizontal bar. Component cards stack vertically; preview row stays side-by-side. |
| ≥ 1024px (desktop) | Sticky vertical nav rail on left or sticky horizontal bar at top (match site convention). Component cards 1-up; preview row side-by-side. |

Test on iPhone 13 (390×844), iPad Pro (1024×1366), MacBook 14" (1512×982).

---

## §7 Motion handling

Per the new motion tokens:

| Interaction | Token | Effect |
|---|---|---|
| Anchor link smooth-scroll | `--motion-duration-standard` + `--motion-easing-decelerate` | Smooth scroll to section |
| Status badge appearance | `--motion-duration-fast` + `--motion-easing-standard` | Fade + 4px slide-up on first viewport entry |
| Variant grid expand | `--motion-duration-standard` + `--motion-easing-emphasized` | Height + opacity transition |
| Copy ✓ confirmation | `--motion-duration-fast` (in) + `--motion-duration-standard` (hold + out) | Fade in → 1.5s pause → fade out |
| Light/Dark preview toggle | `--motion-duration-fast` + `--motion-easing-standard` | Crossfade between preview frames |

All wrapped in `@media (prefers-reduced-motion: reduce)` opt-out.

---

## §8 Analytics events (verification of PRD §9)

Confirms the 4 events from PRD §9 with concrete event-firing locations in this UX:

| Event | Fires from |
|---|---|
| `design_system_section_view` | IntersectionObserver on each `<section>` element with `id="..."`. Threshold: 0.5 viewport coverage for 1 second. Section IDs: `tokens`, `primitives`, `layout`, `control-room`, `persona`, `mdx-callouts`, `drift`, `dark-mode`, `contribute`, `ios-narration` (the upper half) |
| `design_system_component_expand` | Click handler on `ComponentCard` header (toggles variant grid). Param `component_name` = card's component name; `component_status` = status badge value |
| `design_system_code_copy` | Click handler on "Copy snippet" button. Param `component_name`; `snippet_type = 'react'` (only React snippets in v1) |
| `design_system_figma_link_click` | Click handler on the "[Figma node ↗]" anchor. Param `component_name`; `figma_node_id`. Standard outbound-link param `outbound_url` |

All events use the site's existing GA4 instrumentation (no new SDK or wrapper). Implementation lands in T26 of `tasks.md`.

---

## §9 Component reuse vs. new (Phase 4 — Bucket B)

| Reuse | Build new |
|---|---|
| `Disclosure` (existing in `src/components/ui/Disclosure.tsx`) | `ComponentCard` |
| `FlowDiagram` (existing in `src/components/case-study/FlowDiagram.tsx`, used by Part 1's pipeline diagram) | `TokenSwatch` |
| `buildMetadata` (existing in `src/lib/seo.ts`) | `VariantGrid` |
| `Image` (Next.js native) | `StatusBadge` |
| Existing tokens (`design-tokens.ts`) | `MotionTokenList` (extends design-tokens.ts to include motion tokens) |
|  | `ElevationTokenGrid` |
|  | `ZIndexTokenLadder` |
|  | `DriftReportCard` |
|  | `DarkModeMatrix` |

New components live in `src/components/design-system/` (new directory). Showcase-only — not reused elsewhere on the site.

---

## §10 Performance budget

| Metric | Budget |
|---|---|
| Page LCP (p75 on Vercel-hosted preview) | ≤ 2.0s |
| Page TBT | ≤ 200ms |
| First payload (uncompressed) | ≤ 250kb (existing route is already in this range) |
| Component live-render: SSR-only where possible; client hydration only for copy-to-clipboard + IntersectionObserver | — |

If LCP exceeds 2.0s, isolate `/design-system` into its own route segment with explicit chunking; preload only critical fonts.

---

## §11 Dark-mode handling per component preview

For each component card's Light + Dark side-by-side:

```tsx
<div className="grid grid-cols-1 md:grid-cols-2 gap-4">
  <figure data-mode="light" className="bg-[var(--color-neutral-50)] p-6 rounded-lg">
    {/* Forced light mode rendering — overrides system theme */}
    <div className="not-dark">
      <ComponentInstance />
    </div>
    <figcaption className="text-xs text-neutral-500 mt-2">Light variant</figcaption>
  </figure>
  <figure data-mode="dark" className="bg-[var(--color-neutral-900)] p-6 rounded-lg">
    {/* Forced dark mode rendering — overrides system theme */}
    <div className="dark">
      <ComponentInstance />
    </div>
    <figcaption className="text-xs text-neutral-300 mt-2">Dark variant</figcaption>
  </figure>
</div>
```

The `.not-dark` and `.dark` class scoping forces token override at the local level, regardless of user's system theme. Need to verify Tailwind v4 `@variant dark` supports this scope-down — fallback to inline `style={{ colorScheme: 'light' }}` if not.

---

## §12 Failure modes + handling

| Failure | UX response |
|---|---|
| Figma node link is unresolvable (drift detected) | Render a `[Figma node ↗ broken]` badge in red; clicking opens the Figma file root rather than 404 |
| `figma_node_ids` for a component is missing | Render `[Figma node — not yet captured]` in muted text; component still appears in showcase |
| Copy-to-clipboard API fails (older browsers, permissions) | Fallback: render the snippet in a textarea inline with a "Select all" button |
| GA4 instrumentation fails to load | Component still works; events silently dropped per existing site convention |
| Drift detection script hasn't run yet (no report data) | Drift Report card renders "Last run: never. Run `make figma-drift` to populate." with link to docs |
| Dark-mode matrix file missing | §2.8 renders a placeholder card "Dark-mode parity audit pending" |

---

## §13 What's NOT in this UX (intentional)

- Live editable variant controls (Storybook-style props playground) — too much scope for v1
- Component diff view (compare two versions of a component) — premature
- Internationalization — English-only matches sister routes
- Accessibility-tester widget (axe-core inline) — separate concern
- Component popularity / usage metrics (auto-counted from `grep` of imports) — interesting but defer

---

## §14 Implementation sequencing alignment

Maps PRD/tasks.md task IDs to UX sections:

| UX section | tasks.md task IDs |
|---|---|
| §4 Motion/elevation/z-index tokens | T1, T2, T3 |
| §2.1-§2.9 Page structure (showcase route shell) | T4, T5, T6, T7, T8, T9 |
| §2.2-§2.6 Component cards | T10, T11, T12, T13, T14, T15, T16 |
| §2.7 Drift report card | T17 (read-only render of T18 output) |
| §2.8 Dark-mode matrix card | T23, T24 |
| §2.9 Contribute footer | T25 |
| §8 Analytics events | T26, T27, T28 |
| §10 Performance verification | T29 |

---

## §15 Approval criteria

This ux-spec is approvable when:

- [x] §1 preflight passes (no missing surfaces)
- [x] §2 page structure decided (two-part page)
- [x] §3 component card layout specified
- [x] §4 new tokens enumerated with concrete values
- [x] §5 a11y requirements explicit
- [x] §6 responsive breakpoints defined
- [x] §7 motion handling specified per interaction
- [x] §8 analytics implementation locations identified
- [x] §9 component reuse vs. new clear
- [x] §10 performance budget set
- [x] §11 dark-mode preview pattern defined
- [x] §12 failure modes covered
- [x] §13 scope boundaries set
- [x] §14 sequencing aligned with tasks.md

**Awaiting user approval to advance to Phase 3c (`/design preflight` + `/design build`).**
