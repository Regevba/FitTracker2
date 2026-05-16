# UX Spec — case-study-thread-visualization

> **Phase:** 3 (UX/Integration) — Step 3c
> **Date:** 2026-05-16
> **Target surface:** fitme-story public site (web; Next.js 16 + Tailwind v4 + MDX)
> **Implementation references:** [`research.md`](research.md), [`ux-research.md`](ux-research.md), [`prd.md`](prd.md)
> **Status:** Draft for /ux validate

---

## 1. Overview

A new `<SeriesTimeline>` React component that renders multi-part case-study series as a horizontal timeline. Two variants:

- **Listing variant** — renders on `/case-studies` for each of the 10 locked series; no "you are here" marker
- **Detail variant** — renders at the top of every case-study detail page whose frontmatter declares a `series_id`; current part highlighted with "you are here" marker

The component is **server-rendered** (consumed inside `compileMDX()` and `StandardTemplate` / `FlagshipTemplate` / `LightTemplate` server components). Click/keyboard interaction is wrapped in a tiny client subcomponent so the bulk of the markup stays SSR-friendly.

---

## 2. Component anatomy

```
<nav role="navigation" aria-label="<Series Title> series" data-series-id="<id>">
  <div className="series-timeline-header">             // listing only
    <h3>{series.title}</h3>                            // e.g., "Unified Control Center"
    <span className="series-meta">                     // e.g., "v4.3 → v7.8.1 · 6 parts"
      {versionRange} · {memberCount} parts
    </span>
  </div>

  <ol className="series-timeline-track" role="list">
    {members.map((member, idx) => (
      <li className="series-timeline-node-wrap">
        <a
          href={`/case-studies/${member.slug}`}
          aria-label={`Part ${idx + 1} of ${total}: ${member.title}`}
          aria-current={isCurrent ? "page" : undefined}
          data-current={isCurrent}
        >
          <span className="series-timeline-node" />        // the filled circle
          <Tag tone="subtle">{member.version}</Tag>        // e.g., "v7.8.1"
          <span className="series-timeline-label">{member.shortTitle}</span>
        </a>
      </li>
    ))}
  </ol>
</nav>
```

**Variant differences:**
- Listing: header block visible; `aria-current` never set
- Detail: header block hidden; one node has `aria-current="page"` + `data-current="true"` (drives the "you are here" styling)

---

## 3. Token map (cites REAL fitme-story tokens)

All tokens verified against `globals.css` per Step 3e DS landscape audit.

### 3.1 Color tokens

| Element | Light token | Dark token | Reason |
|---|---|---|---|
| Container background | inherits page bg (`--color-neutral-50` / `--color-neutral-900`) | same | Blends with article |
| Connector line (default) | `--color-neutral-200` | `--color-neutral-700` | Subtle divider |
| Connector line (between current and adjacent nodes, optional emphasis v1.1) | `--color-brand-indigo` 40% | `--color-brand-indigo` 40% | Subtle hint of active thread |
| Node fill (default) | `--color-neutral-300` | `--color-neutral-500` | Visible against bg |
| Node fill (hover / focus) | `--color-brand-indigo` | `--color-brand-indigo` | Clear interactive feedback |
| Node fill (current — "you are here") | `--color-brand-indigo` | `--color-brand-indigo` | High contrast active state |
| Node outline ring (current only) | `--color-brand-indigo` 30% (4px ring) | same | Redundant visual cue beyond fill |
| Version tag (`<Tag>`) | use existing `<Tag tone="subtle">` defaults | same | Reuses `Tag` component |
| Label text (default) | `--color-neutral-700` | `--color-neutral-300` (dark override) | Editorial readable |
| Label text (current) | `--color-neutral-900` + `font-weight: 600` | `--color-neutral-50` + `font-weight: 600` | Emphasis |
| Focus ring (keyboard focus) | reuses Button focus ring (`outline: 2px solid --color-brand-indigo, outline-offset: 2px`) | same | Consistency with Button |
| Series header title | `--text-display-md` color | same | Consistent with other section headers |
| Series header meta | `--color-neutral-500` | `--color-neutral-300` (dark) | Muted |

### 3.2 Spacing (Tailwind defaults — no custom scale exists in DS)

| Property | Value | Tailwind class |
|---|---|---|
| Series-section vertical margin (listing) | 48px | `my-12` |
| Header → track gap | 16px | `mt-4` |
| Node-to-node horizontal gap (track) | flexible — `flex` + `gap-8` minimum; track width drives final spacing | `gap-8` |
| Node → version tag gap (vertical, below node) | 8px | `mt-2` |
| Version tag → label gap | 4px | `mt-1` |
| Detail variant top margin (above article body) | 24px | `mt-6` |
| Section horizontal padding | reuses `.section-padding-x` utility (px-4 sm:px-6 lg:px-10 xl:px-14) | utility class |

### 3.3 Border-radius

| Element | Value | Tailwind class |
|---|---|---|
| Node | full (perfect circle) | `rounded-full` |
| Outline ring (current node) | full | `rounded-full` |
| Tag | inherits `<Tag>` component default (~6px) | — |

### 3.4 Typography

| Element | Token | Notes |
|---|---|---|
| Series title (listing header) | `--text-display-md` | Smaller than article H1; larger than body |
| Series meta (version range + part count) | `--text-body` size, `--color-neutral-500` color | Caption-like |
| Version tag | inherits `<Tag>` typography | — |
| Node label (short title) | `text-sm` (Tailwind default ~14px) on desktop; `text-xs` (~12px) on mobile | Compact |
| "You are here" label (current node) | `text-sm font-semibold` | Visual emphasis |

### 3.5 Motion

| Interaction | Duration | Easing | Tailwind / CSS |
|---|---|---|---|
| Hover/focus on node (slight translateY) | `--motion-duration-fast` (120ms) | `--motion-easing-standard` | `transition: transform var(--motion-duration-fast) var(--motion-easing-standard)` |
| Node fill color change (hover/focus) | `--motion-duration-fast` (120ms) | `--motion-easing-standard` | same property scope |
| "You are here" marker fade-in on mount (detail variant only) | `--motion-duration-standard` (200ms) | `--motion-easing-decelerate` | mount-only animation |

**Reduced-motion override** (global rule in `globals.css` already handles this — no extra code needed):
- All `transition-duration` becomes 0.001ms
- All `animation-iteration-count` becomes 1
- Node hover-translateY effectively disabled — only color change applies

### 3.6 Elevation

The timeline does not use elevation tokens — it's inline content, not a floating surface. (Compare: Card uses `--elevation-1`; we don't.)

### 3.7 Breakpoints

| Viewport | Layout |
|---|---|
| `< 640px` (sm-) | **Vertical stack** — each node on its own row, version tag + label inline-right; connector becomes a left-side vertical line |
| `640px – 1023px` (sm to lg) | Horizontal scroll with snap-points; show 4-5 nodes fitting viewport; user swipes for the rest |
| `≥ 1024px` (lg+) | Full horizontal layout; all nodes visible. For series with ≥8 nodes (`framework-integrity-v7`, `ui-audit`, `framework-history`): reduce per-node label to version tag only and put full title as a tooltip (`<title>` SVG element or `aria-describedby` description that only screen readers and hover see) |

---

## 4. State coverage

### 4.1 Required states (Phase 3 must spec all 5)

| State | Visual | Notes |
|---|---|---|
| **Default** | Node filled neutral-300/500 (light/dark); label neutral-700/300; connector neutral-200/700 | Static |
| **Hover** | Node fills indigo; label fills indigo + translateY(-2px) | Pointer devices only; reduced-motion disables transform |
| **Focused** (keyboard) | Node fills indigo + 2px indigo outline ring at 2px offset | Reuses Button focus ring contract |
| **Current ("you are here")** | Node fills indigo + 4px indigo-30% outline ring; label font-weight 600 + neutral-900/50; node 1.2x larger than default | Detail variant only |
| **No-series** (case study has no `series_id`) | Component renders nothing (null return) | Defensive: no `<nav>` element |
| **Broken series_id** (series_id present but doesn't resolve in catalog) | Component renders nothing + console.warn in dev mode | CI drift check should prevent this from reaching production |
| **Reduced-motion** | No translateY transitions; color changes still apply (instant) | Global `prefers-reduced-motion` rule covers this |

### 4.2 Listing vs detail variant

| Property | Listing | Detail |
|---|---|---|
| Header block (title + meta) | Visible | Hidden |
| `aria-current="page"` | Never | On the matching member |
| "You are here" ring | Not rendered | Rendered on current member |
| Container `aria-label` | `"<Series Title> series"` | `"<Series Title> series — Part {N} of {M}"` |
| Click target | Always navigates (it's an `<a>`) | Same as listing (current node still clickable — refreshes/anchors but no-op for UX) |

### 4.3 Edge cases

- **Series with 12+ members** (`framework-integrity-v7`): apply lg-breakpoint label compression (version-tag-only); preserve aria-label for full title context
- **Single-session series** (≥3 members published same day, e.g., parts authored back-to-back): timeline still renders; nodes order by `timeline_position.order` then by date as tiebreaker
- **Future-published members** (series catalog references a slug whose MDX hasn't shipped yet): CI drift check FAILs at PR time; should never reach prod
- **Dark mode**: every color token has a dark-mode override (verified in DS landscape); no additional work
- **Reduced motion**: global rule handles it; no component-level logic needed
- **JS-disabled**: component is server-rendered; nodes are real `<a>` tags. Navigation works without JS. Only the GA4 event-firing is JS-dependent

---

## 5. A11y contract

### 5.1 ARIA

- Outer container: `role="navigation"` + `aria-label="<Series Title> series"` (listing) or `"<Series Title> series — Part N of M"` (detail)
- Node track: `<ol role="list">` (Tailwind `list-none` removes default markers but keeps semantic list)
- Each node: `<a href>` element. `aria-label="Part N of M: <full title>"`. Current node also gets `aria-current="page"` per WAI-ARIA 1.2
- Version tag inside `<a>`: redundant info; mark with `aria-hidden="true"` so screen readers don't double-announce ("v7.8.1 Part 4 of 6: UCC Passkey Auth" — bad)

### 5.2 Keyboard

| Key | Behavior |
|---|---|
| Tab | Move focus to first node in the timeline; subsequent Tab moves focus past the timeline (NOT into next node — that's arrow key territory) |
| Shift+Tab | Move focus backward past the timeline |
| ArrowRight / ArrowDown | Move focus to next node within the timeline |
| ArrowLeft / ArrowUp | Move focus to previous node |
| Home | Focus first node |
| End | Focus last node |
| Enter | Activate focused node (navigate to that case study) |
| Space | Same as Enter (per `<a>` element default behavior; works automatically) |

### 5.3 Focus indicator

Reuses Button focus pattern: `focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand-indigo`.

### 5.4 Color contrast

| Pair | Required ratio | Verified |
|---|---|---|
| Node fill (default) vs page background | 3:1 (non-text UI) | TBC at Phase 5 — neutral-300 on neutral-50 should hit 3:1 |
| Node fill (current) vs page background | 3:1 | brand-indigo on neutral-50 = ~5:1 ✓ |
| Label text (default) vs page background | 4.5:1 | neutral-700 on neutral-50 = ~9:1 ✓ |
| "You are here" outline ring vs node fill | 3:1 | indigo-30% over indigo = ~3:1 ✓ (verify at Phase 5 with actual pixel inspection) |
| Focus ring vs adjacent backgrounds | 3:1 | reuses Button pattern, already compliant |

### 5.5 Screen reader announcement

When a screen reader hits the detail variant: "Navigation. Unified Control Center series — Part 4 of 6. List of 6 items. Part 1 of 6: cleanup control room, link. Part 2 of 6: control center alignment IA refresh, link. ... Part 4 of 6: UCC passkey auth, link, current page. ..."

---

## 6. Insertion points

### 6.1 Listing page (`src/app/case-studies/page.tsx`)

Render a new `<section className="series-section">` ABOVE the existing v7-category accordions. Iterate the 10 locked series in `series-catalog.ts` order; render one `<SeriesTimeline variant="listing">` per series.

Default state: all 10 timelines expanded. Future v1.1 may collapse longer series behind a `<Disclosure>` reveal.

### 6.2 Detail page (`src/app/case-studies/[slug]/page.tsx`)

Modify each of the three case-study templates (`StandardTemplate`, `FlagshipTemplate`, `LightTemplate`) to accept an optional `seriesTimeline?: ReactNode` prop. Detail page passes:

```tsx
const series = getSeriesById(frontmatter.series_id);
const seriesTimeline = series ? (
  <SeriesTimeline variant="detail" series={series} currentSlug={slug} />
) : null;

<StandardTemplate
  frontmatter={frontmatter}
  seriesTimeline={seriesTimeline}
>
  {content}
</StandardTemplate>
```

Inside each template, render `seriesTimeline` between `<header>` and `{children}` (the MDX article body). When `null`, render nothing — the template's grid layout absorbs the missing block.

### 6.3 Three-tier behavior

| Template | Insertion | Notes |
|---|---|---|
| `StandardTemplate` (most case studies) | Between header and children | Primary integration |
| `FlagshipTemplate` (top-tier showcase) | Same slot | Verify visual harmony with FlagshipTemplate's larger header treatment |
| `LightTemplate` (appendix / round-up) | Same slot — but most light-template studies are roundups / framework-history-only standalone entries with no series_id, so this template will rarely receive the timeline | Defensive: render normally when present |

---

## 7. Responsive layout details

### 7.1 Mobile (< 640px) — vertical stack

```
●  v4.3   cleanup control room
│
●  v4.3   control center alignment
│
●  v7.6   unified control center
│
● (current outline)  v7.8   UCC migration showcase
│
●  v7.8.1 UCC passkey auth
```

Connectors become vertical lines on the left (`border-l-2 border-neutral-200`).

### 7.2 Tablet (640-1023px) — horizontal scroll

```
●─────●─────●─────●─────●─────●  ← (horizontally scrollable; snap-to-node)
v4.3  v4.3  v7.6  v7.8  v7.8  v7.8.1
```

Container: `overflow-x-auto snap-x snap-mandatory`. Each node-wrap: `snap-center`. Default scroll position: current node centered (detail variant) or first node visible (listing).

### 7.3 Desktop (≥ 1024px) — full horizontal

All nodes visible inline. For ≥8-node series:
- Reduce label to version tag only
- Full title becomes `title="..."` attribute (browser tooltip) + screen-reader-only span (`<span className="sr-only">`)

### 7.4 Print stylesheet (low priority)

`@media print { /* show all labels regardless of viewport */ }` — optional polish; tracked as P2 cleanup.

---

## 8. Analytics events

Per PRD §Analytics Spec — 4 events. Implementation uses fitme-story's existing `emit()` helper pattern:

```typescript
import type { CaseStudySeriesViewEvent, CaseStudySeriesNodeClickEvent } from "@/lib/case-study-series-analytics";

function emitSeriesView(params: CaseStudySeriesViewEvent): void {
  if (typeof window === 'undefined') return;
  const gw = window as GtagWindow;
  if (typeof gw.gtag !== 'function') return;
  gw.gtag('event', 'case_study_series_view', params as Record<string, unknown>);
}
```

### 8.1 `case_study_series_view`
Fires once per session per series via `IntersectionObserver` when the series section becomes ≥50% visible. Throttle: dedupe within session via `sessionStorage` flag `cstv-view-<series_id>`.

### 8.2 `case_study_series_node_click`
Fires on `<a>` click handler. Sends `series_id`, `from_slug` (current page slug or `"listing"`), `to_slug`, `position_clicked`. Conversion event.

### 8.3 `case_study_series_nav_click`
N/A for v1 — there's no separate prev/next nav in this spec; the timeline IS the navigation. This event is reserved for if/when v1.1 adds a footer prev/next supplement. Implementers should add the event helper but not wire it.

### 8.4 `case_study_series_keyboard_nav`
Fires on `keydown` for ArrowLeft/Right/Up/Down on a focused node. `interaction_type: "focus"`. Fires on Enter activation as `interaction_type: "activate"`.

---

## 9. Token / component reuse checklist (input to /ux preflight)

| Citation | Type | Exists in fitme-story DS? | Source |
|---|---|---|---|
| `--color-neutral-{50,200,300,500,700,900}` | color tokens | YES | globals.css |
| `--color-brand-indigo` + dark override | color token | YES | globals.css |
| `--text-display-md`, `--text-body` | typography | YES | globals.css |
| `--motion-duration-{fast,standard}` | motion tokens | YES | globals.css |
| `--motion-easing-{standard,decelerate}` | motion tokens | YES | globals.css |
| `<Tag tone="subtle">` | component | YES | `src/components/ui/Tag.tsx` |
| `.section-padding-x` utility | utility class | YES | globals.css |
| `rounded-full`, `text-sm`, `text-xs`, `font-semibold` | Tailwind defaults | YES | Tailwind v4 |
| `sm:`, `md:`, `lg:`, `xl:` breakpoints | Tailwind defaults | YES | Tailwind v4 @theme |
| `prefers-reduced-motion` global rule | CSS rule | YES | globals.css `@media (prefers-reduced-motion: reduce)` |
| `aria-current="page"` + `aria-label` patterns | a11y patterns | YES | seen in `Callout.tsx`, `Button.tsx` |
| `focus-visible:outline-2 focus-visible:outline-offset-2` | a11y pattern | YES | `Button.tsx` |
| `<Disclosure>` | component | YES (deferred to v1.1 if needed) | `src/components/ui/Disclosure.tsx` |
| `<Card>` | component | NOT USED in this spec | — |
| `<Callout>` | component | NOT USED in this spec | — |
| Custom horizontal-timeline component | new build | NO — building novel UI | This spec is the contract |

**Zero unknown tokens / unknown components referenced.** Preflight should report PASS.

---

## 10. Files this spec implies

(matches PRD §Key Files but with refined locations)

| File | Action | Where |
|---|---|---|
| `src/lib/content-schema.ts` | MODIFY — add `series_id` | line ~77 (next to unused `related[]`) |
| `src/lib/series-catalog.ts` | NEW | top-level lib |
| `src/lib/series.ts` | NEW | top-level lib |
| `src/lib/case-study-series-analytics.ts` | NEW | mirrors `design-system-analytics.ts` pattern |
| `src/components/case-study/SeriesTimeline.tsx` | NEW | with same dir as `LightTemplate`, etc. |
| `src/components/case-study/SeriesTimeline.client.tsx` | NEW (Client Component for interactivity) | same dir |
| `src/app/case-studies/page.tsx` | MODIFY — new Series section | top of route |
| `src/app/case-studies/[slug]/page.tsx` | MODIFY — pass `seriesTimeline` to template | |
| `src/components/case-study/StandardTemplate.tsx` | MODIFY — accept + render `seriesTimeline` prop | |
| `src/components/case-study/FlagshipTemplate.tsx` | MODIFY — same | |
| `src/components/case-study/LightTemplate.tsx` | MODIFY — same | |
| `src/__tests__/series-catalog.test.ts` | NEW | unit tests |
| `src/__tests__/SeriesTimeline.test.tsx` | NEW | component tests |
| `scripts/check-series-drift.ts` | NEW | CI |
| `.github/workflows/ci.yml` | MODIFY — add drift check step | |
| Various `content/04-case-studies/*.mdx` | MODIFY — add `series_id` | ~46 files |
| 4 new MDX showcases | NEW | T16-T19 from tasks.md |

---

## 11. Out of scope for v1

Deferred to v1.1 (post-30-day metric review):

- Cross-series navigation (e.g., "this case study also belongs to series X")
- Future-published placeholder nodes (ghost nodes for not-yet-shipped parts)
- Per-series CTA ("View full series" link)
- Animated node-to-node line drawing on mount (excluded for motion-sensitive readers)
- Series-level analytics dashboards in `/control-room` (operator-side; separate feature)
- ≥3-member exception for 2-member clusters (currently 13 deferred clusters — re-evaluate based on metric)

---

## 12. Validation gates

### 12.1 /ux validate self-check (this spec)

- [x] All 5 required states specified (default, hover, focus, current, reduced-motion)
- [x] Edge cases enumerated (≥8-node, no-series, broken-series_id, dark mode, JS-disabled)
- [x] Token + component citations grounded in real DS (Step 3e preflight will verify)
- [x] A11y contract complete: ARIA, keyboard, focus, contrast, screen-reader
- [x] Insertion points file-path-specific
- [x] Analytics events tied to PRD specs
- [x] Responsive layouts specified for all 3 breakpoints
- [x] Motion respects `prefers-reduced-motion` global rule

### 12.2 /design audit (this spec)

- All tokens map to existing DS — see §9 checklist
- No raw color/spacing literals
- No new component required outside this spec's own `SeriesTimeline`
- A11y / motion / breakpoint patterns consistent with existing components
- Will be re-validated by Step 3g `/design audit` skill dispatch

---

## 13. Decisions locked

| ID | Decision | Source |
|---|---|---|
| US1 | Horizontal layout on desktop; vertical stack on mobile (< 640px); horizontal-scroll-with-snap on tablet (640-1023px) | This spec |
| US2 | Node = filled circle; current state = larger fill + outline ring; label below node (vertical) | This spec |
| US3 | Token reuse only — no new DS tokens introduced | This spec, verified by §9 checklist |
| US4 | Reuse `<Tag tone="subtle">` for version markers | This spec |
| US5 | Server-rendered base + tiny client component for keyboard + analytics handlers | This spec |
| US6 | Reduced-motion handled by existing globals.css `@media (prefers-reduced-motion: reduce)` rule — no component-level logic | This spec |
| US7 | Three case-study templates (Standard/Flagship/Light) modified to accept optional `seriesTimeline` prop | This spec |
| US8 | Listing page: new Series section ABOVE v7-category accordions; all 10 timelines expanded by default | This spec |
| US9 | ≥8-node series compresses labels to version-tag-only on desktop; full title in screen-reader-only span + `title=` attribute | This spec |
| US10 | No prev/next supplement nav for v1; timeline IS the navigation | This spec |
