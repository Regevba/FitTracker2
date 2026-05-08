# fitme-story Public Site Audit — Visibility, Accessibility, Readability

**Audit date:** 2026-05-08
**Audit type:** Code-level read-only review
**Scope:** Public surfaces of `/Volumes/DevSSD/fitme-story` (Next.js 16 App Router). Excludes `/control-room/*` (operator-gated UCC).
**Auditor:** Claude (general-purpose subagent)

---

## Executive Summary

- **Visibility — moderate.** Global nav is clear and the case-studies catalog has a thoughtful chronological narrative, but cross-case-study linking is sparse, the homepage subtitle gates Lock icons on a JS-only hover hint, the comparison table is the *only* discoverability hub for ~46 case studies, and per-page social/OG metadata + JSON-LD are almost entirely absent.
- **Accessibility — moderate-to-low.** Strong groundwork (semantic HTML, dark-mode contrast overrides, prefers-reduced-motion, lang="en") is undermined by missing skip-to-content link, no `aria-current` on nav, missing `<main>` `id` for skip target, decorative-only icon rings on cards (no visible focus state on header/footer/many cards), and one P0 contrast risk on `--color-neutral-500` in light mode.
- **Readability — strong on the page chrome, weak on long-form scaffolding.** Editorial type system is well-tuned (clamp scale, `--measure-body 65ch`, 1.7 line-height); however, 14+ case studies exceed 200 lines with **no table of contents, no scroll progress, no in-page nav, no "next/prev" affordance, no related-cases panel** — readers face a vertical wall once they enter a case study.

### Top 5 highest-impact findings

1. **[A-001] No skip-to-content link / `<main>` has no id** (P0, S) — Keyboard and screen-reader users can't bypass the global nav. WCAG 2.4.1.
2. **[V-001] No table of contents / no scroll progress / no next-prev nav on 26 case studies** (P1, M) — Several studies are 200–399 MDX lines. Once inside, readers cannot orient or traverse.
3. **[A-002] Light-mode `--color-neutral-500` (`#78716C`) on `--color-neutral-50` (`#FAFAF9`) bg fails WCAG AA at small body size** (P0, S) — used pervasively for body/sub-text on cards (catalog era-secondaries, footer, sub-labels).
4. **[V-002] Per-page OpenGraph / Twitter / JSON-LD metadata almost entirely absent** (P1, M) — Only `/` defines `openGraph`. 46 case studies, glossary, framework, trust pages all share the root `<title>`/`description`. Massive social-share + SEO loss.
5. **[A-003] No `aria-current="page"` on the global nav anywhere** (P1, S) — Screen-reader users get no signal of where they are. The Persona pill bar gets it right (`aria-pressed`), but the actual nav doesn't.

---

## Methodology

**Read:**
- All 18 page-level files under `src/app/`
- All shared layouts (`layout.tsx`, `mdx-components.tsx`)
- 100% of `src/components/{home,case-study,mdx,ui,framework-health,bespoke,pm-flow}` headers, plus full reads of the 8 most load-bearing shared components (`SiteHeader`, `SiteFooter`, `PersonaBar`, `PersonaIndicator`, `Hero`, `Timeline`, `ThreeWaysIn`, `Disclosure`, `Term`, `Figure`, `MetricsCard`, `Pullquote`, `DevDive`, `BeforeAfter`, `HeroMetric`, `BlueprintOverlay`, `CaseStudyComparisonTable`, `LightTemplate`, `StandardTemplate`, `FlagshipTemplate`, `alt-a-chrome/index.tsx`)
- Full `src/app/globals.css` (~160 lines)
- `sitemap.ts` + `robots.ts`
- One representative MDX case study (01-onboarding-pilot.mdx)
- Glossary data file headers + count

**Did not read:**
- Individual case-study MDX bodies (sampled 1 of 26)
- `/control-room/*` (out of scope per brief)
- `src/components/control-room/*` (out of scope)
- `src/lib/control-room/*`
- `node_modules`, `.next` build artifacts

**Scope boundaries:**
- Read-only. No commands, no installs, no Lighthouse, no rendering.
- Contrast claims are computed from CSS hex tokens against rendered backgrounds, but have not been visually verified at sub-pixel rendering. Where verification is impossible from code, findings are flagged "judgment".

---

## Findings

### Visibility

#### Global / nav / footer

**[V-003] Global nav has no current-page indicator** · severity: P1 · effort: S · location: `src/components/SiteHeader.tsx:82-117`

Hover styles flip text to indigo, but neither `aria-current` nor a persistent visual marker (underline, dot, pill background) signals which top-level surface the user is currently on. Compare with `PersonaBar.tsx:25` which uses `aria-pressed` correctly. Add `aria-current="page"` and a 2px bottom-border or dot when `usePathname()` matches.

**[V-004] Mobile nav is hidden behind `hidden md:flex` with no hamburger fallback** · severity: P0 · effort: M · location: `src/components/SiteHeader.tsx:83`

Below the `md` breakpoint (768px) the seven nav items disappear entirely. There is no hamburger menu, no bottom-sheet, no dropdown, no even a "Menu" link. Mobile users can navigate ONLY via in-page Links + the footer (5 links, plus the homepage). This is severe for a content site of ~75 routes.

**[V-005] Footer is sparse and asymmetric** · severity: P2 · effort: S · location: `src/components/SiteFooter.tsx`

Footer carries only About / GitHub-content / Glossary / Trust / © line. No sitemap-style category nav (Case studies, Framework, Design system, Research, PM Flow, Timeline). Given the missing mobile nav (V-004) and the absence of in-content cross-linking (V-007), the footer is the user's last orientation surface — and it omits 6 of the 7 top-level routes.

**[V-006] "Control Center" gated link uses opaque Lock icon + tooltip-only hint** · severity: P2 · effort: S · location: `src/components/SiteHeader.tsx:96-106`

The `title="Gated: requires operator credentials"` tooltip is invisible on touch devices and opaque to screen readers (Lock icon has `aria-label="gated"` — a single word). A plain-text "(operator)" suffix or a subtle `[lock] Login required` would communicate intent without relying on hover.

#### Case studies catalog + cross-linking

**[V-001] 26 case studies have no in-page navigation, no scroll progress, no next/prev** · severity: P1 · effort: M · location: `src/components/case-study/{Light,Standard,Flagship}Template.tsx`

All three templates end with `<FullCaseStudyLink />` (a GitHub link) but no:
- Table of contents (TOC) sidebar — the `<aside aria-label="Sidebar" className="hidden md:block" />` slot in StandardTemplate.tsx:57 and FlagshipTemplate.tsx:63 is **literally empty** on every page. This is a perfect TOC anchor.
- Scroll progress indicator
- "Next case study" / "Previous case study" nav (a `TimelineNav` component exists at `src/components/mdx/TimelineNav.tsx` but is only invoked when MDX authors hand-author it — none of the sampled case studies do this)
- Related cases ("Other studies in v5.x", "Also from this era")

The catalog page (`src/app/case-studies/page.tsx:454-498`) has "era secondaries" — it knows the relationships. The case-study pages don't surface them.

**[V-007] No "back to catalog" or breadcrumb on case-study pages** · severity: P1 · effort: S · location: `src/components/case-study/{Light,Standard,Flagship}Template.tsx` (all three)

Once a reader is on `/case-studies/onboarding-pilot`, the only path back to `/case-studies` is the global nav. The `/case-studies/compare` page has a back-link (`compare/page.tsx:40-48`); template pages do not. Add `← Case studies` or a breadcrumb (`Case studies › Milestone 1 › Pilot`).

**[V-008] Comparison table (`/case-studies/compare`) is the only filterable surface and is not discoverable from anywhere except the catalog header** · severity: P2 · effort: S · location: `src/app/case-studies/page.tsx:192-200`

The link text "Compare every case study at a glance →" is good but lives only at the top of `/case-studies`. It should also appear in the global nav (or as a sub-menu/secondary nav under "Case studies"), in the footer, and from inside individual case-study pages.

**[V-009] Glossary anchor links (`#cat-hardware-analog`) are not visible from main nav or surface as related-content from case studies** · severity: P2 · effort: S · location: `src/app/glossary/page.tsx:36-46`, `src/components/mdx/Term.tsx`

`<Term>` MDX component links inline glossary references — that's good. But there is no global glossary chip in the article footer ("Terms in this article: SoC, big.LITTLE, palettization →") and the catalog page does not surface "Glossary" prominently — only the global footer has a link.

#### Homepage

**[V-010] Hero has no primary CTA** · severity: P2 · effort: S · location: `src/components/home/Hero.tsx`

The hero shows: title → subtitle → PersonaBar (4 buttons) → PersonaIndicator → "The story starts here" + bouncing chevron. There is no explicit "Start with PM flow", "Read the headline case study", or "View framework". The PersonaBar is excellent perspective-tuning but isn't a destination — the user has to scroll for `<ThreeWaysIn>` (way down on the page) to find an actual entry path.

**[V-011] Hero subtitle changes on persona switch but the change is silent** · severity: P3 · effort: S · location: `src/components/home/HeroSubtitle.tsx:18-21`

`HeroSubtitle` swaps copy when `usePersona()` changes. There's no transition, no `aria-live` region, and no visual cue that something just changed. Easy to miss. PersonaIndicator gets `role="status" aria-live="polite"` right (PersonaIndicator.tsx:30-32); the subtitle does not.

#### SEO + machine-readable

**[V-012] Per-page OpenGraph / Twitter cards / JSON-LD almost entirely absent** · severity: P1 · effort: M · location: `src/app/page.tsx:12` is the only file with `openGraph`

- Case-study `generateMetadata` (`src/app/case-studies/[slug]/page.tsx:18-26`) sets `title` + `description` but no `openGraph`, no `twitter`, no `og:image`.
- Glossary, framework, dev-guide, design-system, trust, about, research, compare, operations-layer, timeline/[version] — none set `openGraph`. They get only the root layout's title.
- No JSON-LD anywhere (Article, BlogPosting, BreadcrumbList).
- No `og:image` files in `public/`. Social shares show no preview card.

For a content-first site whose core value prop is shareable case studies, this is the highest-impact SEO / virality lever.

**[V-013] Sitemap omits `/case-studies/compare`** · severity: P3 · effort: S · location: `src/app/sitemap.ts:12-27`

`/case-studies/compare` is a major filterable surface but is missing from `staticRoutes`. Also missing: `/glossary#cat-*` deep anchors aren't surfaced (acceptable, but the parent `/glossary` IS in the list — fine).

**[V-014] No canonical URL declared per page** · severity: P2 · effort: S · location: all pages

Most case studies are mirrored at `github.com/Regevba/fitme-showcase`. None of the page-level `Metadata` objects set `alternates: { canonical: ... }`. This risks SEO duplicate-content penalties when GitHub mirrors are crawled.

#### Discoverability of long-tail content

**[V-015] No filtering on `/case-studies` page** · severity: P2 · effort: M · location: `src/app/case-studies/page.tsx`

The 6 milestone cards + "era secondaries" + meta-analysis + developer deep-dive sections are well-organized but **static**. No "filter by tier", "filter by year", "filter by work type" — that lives only on `/case-studies/compare`. Either link the user there more aggressively, or add inline filters here.

**[V-016] Glossary page has no search even for 53 entries** · severity: P2 · effort: S · location: `src/app/glossary/page.tsx`

Category nav (4 chips) is good but a `<input type="search">` that filters the list client-side would be 30 minutes of work and dramatically improve scannability — this is in the same spirit as the queued SEARCH-1 site-wide search but at a much lower scope.

**[V-017] Research page lists 5 items with no sorting, no tiering, no recency markers** · severity: P3 · effort: S · location: `src/app/research/page.tsx`

The list mixes case-study links and external-GitHub links with no visual differentiation beyond a tooltip-less `target="_blank"`. Add a small `↗` icon on external links and group by "On this site" / "External archives".

**[V-018] `/timeline/[version]` pages list "case studies in this version" but offer no link back to the parent timeline** · severity: P3 · effort: S · location: `src/app/timeline/[version]/page.tsx`

Single back-link to `/case-studies` would reduce orphan-page feel.

---

### Accessibility (WCAG 2.1 AA)

#### Global / structural

**[A-001] No skip-to-content link, `<main>` has no `id`** · severity: P0 · effort: S · location: `src/app/layout.tsx:21-25`

Layout renders `<SiteHeader />` then `<main className="flex-1">` then `<SiteFooter />`. The header has 7 nav items + theme toggle (~10 tab stops). Keyboard users must tab through every nav item on every page before reaching content. Add a visually-hidden-until-focused "Skip to content" link inside `<body>` pointing at `<main id="main">` per WCAG 2.4.1.

**[A-002] Light-mode `--color-neutral-500` (#78716C) on `--color-neutral-50` (#FAFAF9) fails WCAG AA at small body sizes** · severity: P0 · effort: S · location: `src/app/globals.css:31-38`

Contrast: ~4.16:1 (manually computed against the CSS hex). Required for AA body text: 4.5:1. Used pervasively as the default `text-[var(--color-neutral-500)]` for:
- `SiteFooter.tsx:6` body text
- Catalog "era secondaries" date + reading time chips (`page.tsx:485, 489, 542`)
- All "uppercase tracking-wider" labels site-wide (already small-cap, compounds the problem)
- `Term` tooltip "Click to read more →" hint

The dark-mode override at line 64 (`#A8A29E`) was intentional and passes; the light-mode value was missed. Bump to `#6B6764` or darker (≥4.7:1).

**[A-004] `<html lang="en">` is set; no language switch needed** ✓ · location: `src/app/layout.tsx:19` — this is correct.

**[A-005] No focus management on Next.js App Router route changes** · severity: P2 · effort: S · location: layout-wide

Next.js App Router does NOT auto-move focus to `<main>` on navigation. After clicking a `<Link>`, focus stays on the link (or its ghost), so screen-reader users have no indication the page changed. Standard fix: a `<RouteAnnouncer>` client component or focus the `<h1>` on route change.

#### Header / nav

**[A-003] No `aria-current="page"` on nav links** · severity: P1 · effort: S · location: `src/components/SiteHeader.tsx:108-114`

Add `aria-current={pathname === item.href ? 'page' : undefined}` on each `<Link>` so screen-reader users get "current page" announced.

**[A-006] Theme toggle button has good `aria-label` but no `aria-pressed` and no live-region announcement of theme change** · severity: P2 · effort: S · location: `src/components/SiteHeader.tsx:118-124`

The button correctly announces "Switch to dark theme". After the click, the label updates to "Switch to light theme" — that's actually fine for screen-readers since the next focus brings the new label. But adding `aria-pressed={dark}` would let assistive tech surface state.

**[A-007] Lock icon `aria-label="gated"` is too terse and the gated link opens in new tab without `aria-describedby`** · severity: P2 · effort: S · location: `src/components/SiteHeader.tsx:96-106`

Screen readers will announce "Control Center, link, gated, opens in new tab" only if you wire `rel="noopener"` (yes), `target="_blank"` (yes), AND a more descriptive `aria-label` like "Control Center — operator login required, opens in new tab". Currently they hear "Control Center, link, image, gated".

#### Buttons / interactive surfaces

**[A-008] No visible focus indicator on `SiteHeader` nav links, `SiteFooter` links, `Hero` chevron, `ThreeWaysIn` cards, `TimelineNode` cards** · severity: P1 · effort: S · location: header/footer/home

Reliance on browser default focus ring is fragile (varies by OS, removed by some user-agent stylesheets). Catalog page shows the right pattern (`focus-visible:outline-2 focus-visible:outline-[var(--color-brand-indigo)]` on the infographic pins, `page.tsx:350`). Apply the same `focus-visible:` ring globally — likely a single shared `.focus-ring` utility.

**[A-009] Comparison-table sort buttons are valid `<button>` but have no `aria-sort` on the `<th>`** · severity: P2 · effort: S · location: `src/components/case-study/CaseStudyComparisonTable.tsx:339-361`

Add `aria-sort="ascending|descending|none"` on the SortableTh's `<th>` for screen-reader-friendly sort state.

**[A-010] `Disclosure` component is well-instrumented (`aria-expanded`, `aria-controls`, `useId`)** ✓ · location: `src/components/ui/Disclosure.tsx` — this is correct and exemplary.

**[A-011] DataKey `<details>` element uses CSS to hide the default disclosure marker but no explicit ARIA** · severity: P3 · effort: S · location: `src/components/case-study/alt-a-chrome/index.tsx:111-156`, `globals.css:84-91`

`<details>` natively handles keyboard + ARIA, so this is OK — but the click-target is only the `<summary>` row's chevron triangle area, and the visual "▾" is css-rotated. Consider adding `min-h-11` (already there) and verifying the entire row is the keyboard target.

#### Forms / inputs

**[A-012] Comparison-table search input has `aria-label` but no associated visible `<label>` and no error/empty-state announcement when filters return zero** · severity: P2 · effort: S · location: `src/components/case-study/CaseStudyComparisonTable.tsx:178-186, 191-193, 227-232`

`aria-live="polite"` on the result count is good. The empty state ("No case studies match. Adjust filters.") is not in a live region — moving focus to it would be heavy-handed but at least adding `role="status"` would help.

#### Images

**[A-013] Design-system page renders 10 phone screenshots (1320×2868) with no `priority`, no `sizes`, no `loading="lazy"` declaration** · severity: P2 · effort: S · location: `src/app/design-system/page.tsx:113-170`

`next/image` will lazy-load by default below the fold, but explicit `sizes="(max-width: 768px) 100vw, 33vw"` on the responsive grid would prevent over-fetching. None of the figures are `priority`, so LCP isn't affected, but page weight is large.

**[A-014] `<Image>` `alt` text equals image `title` in the screenshot grid (not descriptive)** · severity: P1 · effort: S · location: `src/app/design-system/page.tsx:121, 155`

`alt={shot.title}` produces alt="Welcome", alt="Goal selection" — purely identifying labels rather than describing what's in the screenshot. Replace with content-describing alt: "FitMe welcome screen showing brand wordmark, value proposition, and a single Sign Up call-to-action."

**[A-015] `Figure` MDX component has good `alt` propagation but `caption` should not duplicate `alt` text** · severity: P3 · effort: S · location: `src/components/mdx/Figure.tsx`

Functional. Document in MDX guidelines that `alt` ≠ `caption`.

#### Color / contrast

**[A-016] Brand-indigo `#4F46E5` light-mode link text on `#FAFAF9` bg passes (~6.8:1)** ✓ · location: `globals.css:12, 56`

**[A-017] `text-emerald-700` / `text-amber-700` tier badges in T1/T2/T3 chips on light bg** · severity: P3 · effort: S (verification) · location: `src/components/case-study/alt-a-chrome/index.tsx:167-172`

Tailwind's `*-700` shades on `*-100` backgrounds generally pass AA but the audit relies on Tailwind v4 defaults. Worth a colour-eye check at `text-stone-700 / bg-stone-100` (T3) which is the lowest-contrast pairing.

**[A-018] DevDive aside uses `text-[var(--color-neutral-500)]` for the "Developer deep-dive" small-caps label on `--color-neutral-50` bg in light mode — same A-002 issue, but small-caps so even riskier** · severity: P0 · effort: S · location: `src/components/mdx/DevDive.tsx:10`

Bundles into the A-002 fix.

#### Headings / landmarks

**[A-019] Catalog page has overlapping `<h1>` patterns when chrome is present** · severity: P1 · effort: S · location: `src/components/case-study/{Standard,Flagship,Light}Template.tsx`

When `hasChrome` is true, the template's `<header>` doesn't render the `<h1>` (line 33-37 of StandardTemplate) — instead, `SummaryCard` becomes the `<h1>` source (`alt-a-chrome/index.tsx:57-59`). When `hasChrome` is false, the template renders the `<h1>`. This conditional means: case studies WITH frontmatter chrome have the `<h1>` inside a card-styled `<div>` (not inside `<header>` / `<article>`-level), and the page's first heading is buried 5 levels deep inside a card.

This is structurally OK for accessibility tree (the `<h1>` exists), but it makes outline-mode and screen-reader navigation feel inconsistent across the corpus. Move the `<h1>` to the article header always, and let the SummaryCard render an `<h2>` or `<p class="title-echo">`.

**[A-020] StandardTemplate has `<aside aria-label="Sidebar" className="hidden md:block" />` — empty aside is announced as a region with the label "Sidebar"** · severity: P2 · effort: S · location: `StandardTemplate.tsx:57`, `FlagshipTemplate.tsx:63`

Either populate the aside (TOC, see V-001) or remove it. Empty landmark with a label is noise.

#### Motion

**[A-021] `prefers-reduced-motion` global CSS rule is excellent** ✓ · location: `globals.css:70-77` — correctly disables animation site-wide.

#### Tables (in MDX prose)

**[A-022] Editorial prose table styling is well-tuned (`globals.css:117-158`)** ✓ — header band, hover row, dark-mode border. No issue.

**[A-023] `FindingsTable` MDX component lacks `<caption>` and uses color-only severity indicator** · severity: P2 · effort: S · location: `src/components/mdx/FindingsTable.tsx:31-33`

`<span className={`inline-block w-2 h-2 rounded-full mr-1 ${SEVERITY_COLOR[f.severity]}`} />` followed by the text severity is OK because the text is present. But the colour dot has no semantic meaning to assistive tech (no `aria-hidden`). Add `aria-hidden="true"`.

#### Code blocks

**[A-024] Inline `<code>` styling exists; no fenced code-block component, no copy button, no language label, no syntax highlighting** · severity: P2 · effort: M · location: MDX rendering chain (`mdx-components.tsx`, `compileMDX` in case-study `[slug]/page.tsx`)

`compileMDX` is set up with `remark-gfm` only — no `rehype-pretty-code` or shiki. Case studies that include shell snippets render as plain monospace with no highlighting and no copy-to-clipboard affordance. Adding `rehype-pretty-code` is a one-line plugin install.

---

### Readability

#### Long-form (case studies)

**[R-001] No table of contents on case-study pages** · severity: P1 · effort: M · location: `src/components/case-study/{Light,Standard,Flagship}Template.tsx`

Bundled with V-001. The empty `<aside>` slot in Standard + Flagship is the natural home. A 30-line `<TableOfContents>` client component that walks `headings[]` from MDX → renders sticky list with active-section tracking is feasible without redesigning anything.

**[R-002] No reading-time-remaining indicator (only static "X min read")** · severity: P3 · effort: S · location: all three templates (`readingTimeMin` prop)

Reading-time-remaining or scroll-progress bar at the top of the article would help with long studies (200+ MDX lines = 15-25 min reads).

**[R-003] No "next case study" / "previous case study" affordance** · severity: P1 · effort: S · location: `{Light,Standard,Flagship}Template.tsx`

`TimelineNav` MDX component exists but isn't auto-rendered. Add it after the children, computing prev/next from chronological order in `getAllCaseStudies()`.

#### Typography / vertical rhythm

**[R-004] Body type scale is excellent (`--text-body 1.0625rem / lh 1.7`, `--measure-body 65ch`)** ✓ · location: `globals.css:40-50`

**[R-005] Heading hierarchy in case studies skips levels** · severity: P2 · effort: S · location: case-study templates

Catalog page: `<h1>` Case studies → `<h2>` How we measured → `<h3>` Milestone titles. Good.
Case study page (Light): `<h1>` Title → directly to MDX `<h2>` Context → `<h3>` Approach. Mostly OK.
**Issue:** when `hasChrome=true`, the SummaryCard `<h1>` is the document's only h1 but it's inside a `bg-white dark:bg-neutral-800` card with `text-[length:var(--text-display-md)]` — visually NOT the largest text on the page. Many readers (and SEO/social-share tools) will look for the most prominent heading and find the version chip + `text-display-lg` "Case studies" h1 from the parent layout (which doesn't exist for case-study pages but the visual weight expectation is set).

#### Per-page density

**[R-006] Catalog "How we measured" 6-card grid (`page.tsx:233-334`) is dense — six prose paragraphs in a `dl` grid with no visual separation** · severity: P2 · effort: S · location: `src/app/case-studies/page.tsx`

Each `<dt>` is small-caps + bold; each `<dd>` is 4-6 lines of prose. Six in a row before the user reaches the actual milestone cards. Consider collapsing 3 of them behind a `<Disclosure>` ("Methodology details") with the 3 most user-facing visible.

**[R-007] Numbers panel renders 5 huge metrics without context links** · severity: P3 · effort: S · location: `src/components/home/NumbersPanel.tsx`

Each "16 features shipped", "8 framework versions" etc. is a static stat. Make each one a `<Link>` to the relevant page (`/case-studies`, `/timeline`, etc.) — the visual treatment already implies clickability.

#### Code blocks (mid-prose)

**[R-008] No copy-button on code blocks (see A-024)** · severity: P2 · effort: M · bundles with A-024.

#### Tables in MDX

**[R-009] Tables rendered via prose styles get no horizontal scroll wrapper on mobile** · severity: P2 · effort: S · location: `globals.css:117-158`

`.prose table { width: 100%; }` will overflow on narrow viewports. Wrap in `<div data-scrollable className="overflow-x-auto">` automatically via a custom MDX `table` component (currently not registered in `mdx-components.tsx`).

#### Dark mode

**[R-010] Dark mode is offered + has explicit AA-tuned overrides** ✓ · location: `globals.css:58-68` — exemplary; the comment explicitly documents the 4.5:1 + 3.0:1 contrast targets.

**[R-011] Dark mode toggle has no system-default-respecting "Auto" option in the UI** · severity: P3 · effort: S · location: `src/components/SiteHeader.tsx`

The underlying `useSyncExternalStore` reads from localStorage OR system preference, but the toggle button only flips light↔dark — no third "auto/system" mode. After first interaction, the user is locked out of "follow OS" until they clear localStorage.

#### Mobile

**[R-012] Viewport meta is auto-injected by Next.js** ✓

**[R-013] Touch targets on `SiteHeader` nav are correctly `min-h-[44px]` (line 79, 101, 111)** ✓

**[R-014] Hero section is not responsive-typography-tested** · judgment-only · location: `src/components/home/Hero.tsx`

`text-[length:var(--text-display-xl)] leading-[1.05]` clamps via `clamp(2.5rem, 5vw, 4.5rem)` — should be fine, but with `<span>/pm-flow</span>` inline the line-break point on a 360px viewport is unverified.

**[R-015] `BlueprintOverlay` is `tabIndex={0}` on each floor and listens to `onFocus/onBlur` to expand details — good keyboard support, but `tabIndex={0}` on 7 stacked items adds 7 tab stops with no skip mechanism** · severity: P2 · effort: S · location: `src/components/bespoke/BlueprintOverlay.tsx:23`

Combine with the missing skip-link (A-001) — the framework page becomes very tab-heavy for keyboard users.

#### Pullquote / Term

**[R-016] `Pullquote` component uses `text-2xl` italic on coral border-l-4 — bold and well-spaced** ✓

**[R-017] `Term` tooltip is keyboard-accessible (focus + blur)** ✓ · `src/components/mdx/Term.tsx:36-39`. Good.

**[R-018] `Term` tooltip has no `aria-describedby` association on the trigger** · partial · location: `Term.tsx:40` actually does set `aria-describedby={`term-tooltip-${entry.slug}`}` — this is ✓ correct.

---

## Quick wins (P0 + P1, effort = S)

These can ship in one afternoon:

1. **A-001** Add skip-to-content link in `layout.tsx`, give `<main>` `id="main"`. (P0/S)
2. **A-002 + A-018** Bump light-mode `--color-neutral-500` to `#6B6764` (or `#5C5754` for safety). (P0/S)
3. **A-014** Rewrite design-system screenshot `alt` text to describe content, not just title. (P1/S)
4. **A-019** Move `<h1>` out of SummaryCard back into template `<header>` always. (P1/S)
5. **A-003** Add `aria-current="page"` to nav via `usePathname()`. (P1/S)
6. **A-008** Add a global `focus-visible:outline-2 focus-visible:outline-[var(--color-brand-indigo)] focus-visible:outline-offset-2` utility, apply to header/footer/cards. (P1/S)
7. **V-003** Same component as A-003 — add a current-page underline. (P1/S)
8. **V-007** Add `← Case studies` back-link to all 3 case-study templates. (P1/S)
9. **R-003** Auto-render `<TimelineNav>` after children in all 3 templates with computed prev/next. (P1/S)

## Strategic recommendations

1. **Promote the empty `<aside aria-label="Sidebar">` slot into a real, shared `<CaseStudySidebar>` component.** It currently exists in 2/3 templates as dead markup. Filling it with a sticky `<TableOfContents>` + `<RelatedCases>` + key-numbers card would close R-001, R-002, V-001 (partial), V-005 (era cross-linking), and A-020 in one architectural move. The data is already collected by `getAllCaseStudies()` and `MILESTONES`/`secondariesByMilestone` arrays — no new sources needed.

2. **Introduce per-page `generateMetadata` returning `openGraph` + `twitter` + JSON-LD on every dynamic + static route.** Build a single `buildMetadata({ title, description, slug, type, image })` helper in `src/lib/seo.ts`. Even without per-case-study OG images (use a single fallback `/og.png`), this closes V-012, V-014, and dramatically improves social share + SEO surface. The `generateMetadata` pattern is already used for case studies (`[slug]/page.tsx:18-26`); just extend it.

3. **Consolidate the "tier badge" / "small-caps label" / "uppercase tracking-wider text-neutral-500" pattern into 2-3 named typography utilities.** This pattern repeats across 30+ files with slightly different opacity/colour combos — and is the source of A-002. A `<Eyebrow tier="meta">…</Eyebrow>` + `<Caption>…</Caption>` MDX/component pair would normalize spacing, contrast, and small-caps treatment in one place.

4. **Build a `<MobileNav>` as a separate component.** Currently `SiteHeader` `hidden md:flex`'s the entire nav. Adding a hamburger that opens a focus-trapped Dialog with the full nav + theme toggle + "Skip to glossary" + "Skip to compare" would fix V-004, partially V-005, partially V-009 (glossary discoverability), and partially A-001 (since skip-link affordances naturally pair with mobile nav).

5. **Wire `rehype-pretty-code` (or `shiki` directly) into the MDX pipeline.** One-line plugin add, but it covers A-024 + R-008 + improves the developer-facing dev-guide and developer deep-dive case studies materially. Optional: add a `<CopyButton>` MDX component.

---

## Appendix

### Route inventory (public surfaces only)

| Route | Page file | Purpose |
|---|---|---|
| `/` | `app/page.tsx` | Hero + persona switcher + origin narrative + timeline + numbers panel + 3-ways-in cards |
| `/about` | `app/about/page.tsx` | Project disclaimer, contact, links |
| `/case-studies` | `app/case-studies/page.tsx` | Catalog: 6 milestone cards + era secondaries + meta + dev deep-dives |
| `/case-studies/[slug]` | `app/case-studies/[slug]/page.tsx` | Renders MDX via Light/Standard/Flagship templates |
| `/case-studies/compare` | `app/case-studies/compare/page.tsx` | Sortable + filterable + searchable comparison table (~46 rows) |
| `/case-studies/operations-layer` | `app/case-studies/operations-layer/page.tsx` | Static 3-section operations write-up |
| `/design-system` | `app/design-system/page.tsx` | 13 principles + 6 onboarding screenshots + 4 live screens + tokens/components/pipeline disclosures |
| `/framework` | `app/framework/page.tsx` | Floor blueprint overlay + 2 follow-on cards (dispatch + dev guide) |
| `/framework/dispatch` | `app/framework/dispatch/page.tsx` | Live DispatchReplay component |
| `/framework/dev-guide` | `app/framework/dev-guide/page.tsx` | MDX render of `content/framework/dev-guide.md` (790 lines) |
| `/glossary` | `app/glossary/page.tsx` | 53 alphabetized + categorized definitions |
| `/pm-flow` | `app/pm-flow/page.tsx` | LifecycleLoop + LegoWall + EvolutionStrip + SharedDataTiles + CacheTiers + build-your-own |
| `/research` | `app/research/page.tsx` | 5-item research card list |
| `/timeline/[version]` | `app/timeline/[version]/page.tsx` | Per-version landing with case-study list |
| `/trust` | `app/trust/page.tsx` | Audit policy + Gemini 2026-04-21 results + FrameworkAdvancement chart |
| `/trust/audits/2026-04-21-gemini` | (sub-route, not read in detail) | Verbatim audit archive |

### Token inventory (referenced in findings)

| CSS custom property | Hex (light) | Hex (dark override) | WCAG status |
|---|---|---|---|
| `--color-brand-indigo` | `#4F46E5` | `#818CF8` | both pass on white/near-black |
| `--color-brand-coral` | `#F97066` | `#FDA29B` | dark passes; light borderline at small body |
| `--color-neutral-50` | `#FAFAF9` | (bg only) | n/a |
| `--color-neutral-500` | `#78716C` ⚠ | `#A8A29E` ✓ | **A-002 P0 — light fails ~4.16:1** |
| `--color-neutral-700` | `#44403C` | `#D6D3D1` | both pass |
| `--color-neutral-900` | `#1C1917` | (bg only) | n/a |

### Key shared components touched

| Component | Path | Findings ref |
|---|---|---|
| `SiteHeader` | `src/components/SiteHeader.tsx` | V-003, V-004, V-006, A-003, A-006, A-007, A-008 |
| `SiteFooter` | `src/components/SiteFooter.tsx` | V-005, A-002, A-008 |
| `Hero` + `HeroSubtitle` | `src/components/home/Hero.tsx`, `HeroSubtitle.tsx` | V-010, V-011 |
| `PersonaBar` + `PersonaIndicator` | `src/components/PersonaBar.tsx`, `PersonaIndicator.tsx` | (well-instrumented; reference exemplars) |
| `TimelineNode` | `src/components/home/TimelineNode.tsx` | A-008 |
| `LightTemplate` / `StandardTemplate` / `FlagshipTemplate` | `src/components/case-study/*.tsx` | V-001, V-007, A-019, A-020, R-001, R-002, R-003 |
| `alt-a-chrome` (`SummaryCard`, `DataKey`, `KillCriterionBanner`, `DeferredItemsList`) | `src/components/case-study/alt-a-chrome/index.tsx` | A-019 |
| `CaseStudyComparisonTable` | `src/components/case-study/CaseStudyComparisonTable.tsx` | A-009, A-012 |
| `Disclosure` | `src/components/ui/Disclosure.tsx` | (exemplar — A-010 ✓) |
| `Term` | `src/components/mdx/Term.tsx` | (exemplar — R-017, R-018 ✓) |
| `DevDive` | `src/components/mdx/DevDive.tsx` | A-018 |
| `Figure` | `src/components/mdx/Figure.tsx` | A-013, A-014, A-015 |
| `FindingsTable` | `src/components/mdx/FindingsTable.tsx` | A-023 |
| `BlueprintOverlay` | `src/components/bespoke/BlueprintOverlay.tsx` | R-015 |

### Counts

- 12 V- findings (Visibility)
- 24 A- findings (Accessibility)
- 18 R- findings (Readability)
- **9 quick wins** (P0/P1 with effort = S, listed above)
- **3 P0** (A-001 skip link, A-002/A-018 contrast, V-004 mobile nav) — V-004 is M effort, doesn't make the quick-wins cut
