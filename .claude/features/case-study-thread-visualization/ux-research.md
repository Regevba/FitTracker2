# UX Research — case-study-thread-visualization

> **Phase:** 3 (UX/Integration) — Step 3b (UX Research)
> **Date:** 2026-05-16
> **Surface:** fitme-story public site (web, not iOS)
> **Output for:** ux-spec.md, design preflight, build prompts

---

## 1. Applicable UX principles

The 13 FitMe UX principles (8 core + 5 FitMe-specific per [`docs/design-system/ux-foundations.md`](../../docs/design-system/ux-foundations.md)) are mostly iOS-app-oriented. Translating to a web public-site context, the principles that apply to a horizontal timeline thread are:

| Principle | Applicability | How it shapes the design |
|---|---|---|
| **Hick's Law** (minimize choices per surface) | High | Show ≤7-8 visible nodes per timeline. For 12-node `framework-integrity-v7`, page or collapse |
| **Recognition over recall** | High | Each node shows version tag (e.g., `v7.8.1`) + 1-line title so readers don't need to remember which slot is which |
| **Jakob's Law** (users expect familiar patterns) | High | Horizontal-timeline pattern is familiar from GitHub releases, Linear sub-projects, Apple newsroom — leverage existing mental models |
| **Progressive disclosure** | High | Listing shows series-level summary; detail page shows full progression context with current part highlighted |
| **Consistency** (internal + external) | High | Internal: reuse fitme-story design system tokens; external: match conventions seen on adjacent docs/changelog sites |
| **Feedback** (every action gets a response) | Medium | Click on a node → instant navigation; hover/focus → visual emphasis on that node |
| **Fitts's Law** (target size for interactive elements) | Medium | Each timeline node must be ≥44×44 CSS px effective tap target on mobile |
| **Error prevention** | Low | Timeline doesn't have error states beyond "no series_id → don't render" |

### FitMe-specific principles applicable

- **Data integrity over visual polish** — every node must resolve to a real published case study; broken links are a worse failure than ugly typography
- **Mobile-first** — the public site is read on phones; the timeline must collapse gracefully

---

## 2. iOS HIG analogs

While this is web, the project uses iOS HIG as a north-star reference:

| HIG pattern | Web translation |
|---|---|
| Tab bar (5 destinations max) | Don't render >7 nodes inline; page or collapse beyond that |
| Page indicator (dots under carousel) | Could mark "you are here" with a dot or filled node |
| Card stack | NOT applicable — we want all nodes visible at once, not stacked |
| Disclosure indicator (chevron) | Apply at end of node list when paged: "› more" |
| Reduced motion | Honor `prefers-reduced-motion: reduce`; no node hover-zoom or auto-animate |
| Minimum tap target 44pt | Web equivalent ~44×44 CSS px |

---

## 3. External UX research / horizontal timeline patterns

Web-context references for horizontal timeline + multi-part progression:

| Source | Pattern observed | What to borrow / not borrow |
|---|---|---|
| **GitHub release pages** ([example](https://github.com/facebook/react/releases)) | Vertical list with version + date + summary | Borrow: version tags as primary scannable element. Not borrow: vertical layout (we want horizontal) |
| **Apple newsroom timeline** | Horizontal scrolling cards with hero image + headline + date | Borrow: horizontal layout + date prominence. Not borrow: hero images per node (overkill for our density) |
| **Stripe changelog** | Grouped releases with TL;DR per stop | Borrow: short labels + dates. Not borrow: full prose per node |
| **Linear sub-issue chain** | Parent-child with progress bar | Borrow: progress visualization ("3 of 6 published"). Not borrow: progress bar metaphor (our series have no "progress" — all parts are published) |
| **Next.js learn track** | Series-aware navigation w/ progress indicator | Borrow: "you are here" pattern. Not borrow: linear-only progression (some of our series have alternative ordering) |
| **Wikipedia article-series infoboxes** | Sidebar with "Part X of Y in Z series" | Borrow: explicit "Part X of Y" label. Not borrow: sidebar placement (we want top-of-article) |
| **Mozilla Developer Network history timelines** | Horizontal date-anchored events | Borrow: temporal-anchor convention (each node's position reflects when it shipped). Not borrow: chart-axis visual |

**Pattern decision:** horizontal timeline with **discrete nodes** (not continuous line), each node = 1 case study, distance between nodes is **chronologically scaled but not pixel-accurate** (don't compress 4 v7.8.x patches into 2px because they shipped on consecutive days). Version tag + 1-line title under each node. "You are here" marker on detail variant.

---

## 4. Design pattern decisions (preliminary — locked at spec)

| Decision | Choice | Rationale |
|---|---|---|
| Layout direction | Horizontal | User explicitly chose visual prominence (Option 2); horizontal communicates chronology + breadth |
| Node shape | Filled circle (8-10 CSS px diameter) | Universal recognizable; high contrast at any size |
| Active state ("you are here") | Larger filled circle + outline ring + version tag bolded | Two redundant cues so the marker remains accessible if color is desaturated |
| Connector line | Thin horizontal stroke between consecutive nodes | Reinforces chronology; subtle enough to avoid visual noise |
| Label position | Below node | Most readable for English left-to-right reading |
| Label content | Version tag (e.g., `v7.8.1`) on line 1, 1-line title on line 2 | Version anchors the chronology; title gives identity |
| Click target | Entire node + label clickable area | Larger Fitts target |
| Hover/focus state | Node + label shifts up 2px + connector highlights | Subtle motion, respects reduced-motion |
| Reduced-motion variant | No hover transform; underline title only on focus | Honors `prefers-reduced-motion` |
| Mobile breakpoint | Below 480px: collapse to vertical list w/ same node + label per row; OR horizontal scroll with snap-points (TBD at spec — prototype both) | 8+ node series won't fit horizontally on phone |
| Listing-page section title | Series title + version range + part count | E.g., "Unified Control Center · v4.3 → v7.8.1 · 6 parts" |
| Detail-page placement | Above article H1, below page header | Anchors the reader without competing with the article title |

---

## 5. Accessibility requirements

Per AXE + WCAG 2.1 AA:

- **Keyboard navigation:** Tab to focus the timeline component as a whole (single focusable element initially); arrow keys (Left/Right) move focus between nodes; Enter activates focused node; Tab continues past the timeline
- **ARIA:** outer container `role="navigation" aria-label="<series title> series"`; each node `<a href="..." aria-label="Part N of M: <title>"`; current node adds `aria-current="page"`
- **Focus indicator:** visible focus ring on focused node (use existing fitme-story focus token if available; else `outline: 2px solid Color.accent; outline-offset: 2px`)
- **Color contrast:** node fill + connector line ≥3:1 against background; label text ≥4.5:1 against background; "you are here" outline ring ≥3:1 against node fill (it's a non-text UI element)
- **Reduced motion:** if `prefers-reduced-motion: reduce`, skip hover transforms; underline title only
- **Screen reader announce on activate:** "Navigating to: Part 3 of 6: Unified Control Center migration"

---

## 6. Component / pattern references (existing fitme-story DS)

To be confirmed by Step 3e UX preflight (pending DS landscape agent return). Anticipated reuse:

- `Tag` / `Badge` — for version markers (`v7.8.1`)
- Typography tokens — `text-sm` / `text-xs` for labels
- Color tokens — `accent` (active node + connector hover), `text-primary` / `text-secondary` (label hierarchy), `surface-subtle` (background)
- Spacing tokens — 8pt scale for node-to-label and node-to-node spacing
- Border-radius — `rounded-full` for nodes
- Motion — existing transition token (≤200ms ease-out)

If any of these don't exist in the fitme-story DS today, Step 3e flags them for either (a) compose from primitives, (b) add to DS evolution log, or (c) descope to v1.1.

---

## 7. Decisions deferred to spec

These choices are locked at Step 3c (ux-spec.md):

1. **Mobile layout** — horizontal scroll w/ snap vs collapsed vertical list. Prototype both in spec.
2. **Connector line styling** — solid vs dashed; whether to break the line at the "you are here" node
3. **Empty-future-state** — if a series has a planned-but-not-published next part, do we show a ghost node? **Tentative answer:** No — only render published parts. Out-of-scope for v1.
4. **Series-level CTA** — should listing-page series sections have a "View full series" link? **Tentative:** No — the timeline IS the navigation
5. **Number of pre-rendered nodes for ≥8-node series** — 7 visible + "+ N more" indicator vs full horizontal scroll. Prototype both.

---

## 8. Source links

- FitMe UX foundations: [`docs/design-system/ux-foundations.md`](../../docs/design-system/ux-foundations.md)
- FitMe v2 refactor checklist: [`docs/design-system/v2-refactor-checklist.md`](../../docs/design-system/v2-refactor-checklist.md) (web feature, but a11y patterns transfer)
- fitme-story design system case study (catalogue of existing components): `docs/case-studies/fitme-story-website-design-system-case-study.md`
- WCAG 2.1 AA: https://www.w3.org/WAI/WCAG21/quickref/
- Apple HIG keyboard: https://developer.apple.com/design/human-interface-guidelines/inputs/keyboards
