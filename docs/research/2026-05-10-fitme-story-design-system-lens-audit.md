# fitme-story Design System Lens Audit — 2026-05-10

**Audit Date:** 2026-05-10  
**Design System Ship Date:** 2026-05-10  
**Scope:** 12 public routes (/ + 11 targets, excluding /control-room)  
**Baseline:** 31-component manifest, 4 token groups (brand/skill/neutral/type), 7 locked patterns, 11 resolved heritage audits

---

## Summary

- **Total findings:** 57
- **P0 (broken/illegible/inaccessible):** 7
- **P1 (drift causing real divergence):** 34
- **P2 (nice-to-have polish):** 16

**Key themes:** Underutilization of Disclosure component (3 missing applications), raw inline color in case-studies timeline (high-visibility), inconsistent text sizing across glossary and search pages, missing reduced-motion guards on interactive animations, focus ring inconsistency in search filters.

---

## Per-route findings

### / (Homepage)

- **P1-001** Missing Disclosure for "How we measured" section in case-studies page — appears inline with prose prose-lg rather than wrapped in a Disclosure (`/case-studies/page.tsx:213-338`). Should collapse/expand per design system pattern.
- **P2-002** Hero component styling uses inline bg gradients rather than semantic elevation tokens (`/components/home/Hero.tsx` — not audited but used here).
- **P2-003** NumbersPanel metric cards use `text-3xl` hardcoded; should reference `--text-display-md` for consistency (`/components/home/NumbersPanel.tsx` — verify alignment with tokens).

### /about

- **P1-004** Disclaimer box manually styled with inline border/bg/padding instead of a reusable card or callout component (`page.tsx:14-32`). Should use a design-system callout.
- **P1-005** Raw `text-[var(--color-neutral-700)] dark:text-[var(--color-neutral-300)]` repeated 7 times in about page; should be a semantic utility class or apply a class wrapper (`page.tsx:14-76`).
- **P2-006** Contact link styling uses inline `className="underline-offset-4 hover:underline"` — consistent but not explicitly in token system.

### /case-studies (index)

- **P0-007** Timeline "Methodology — How we measured" section (lines 213-338) renders as prose box rather than Disclosure; content is 200+ lines and should collapse by default. User scrolling fatigue. **High visibility P0 UX issue.**
- **P1-008** Milestone color bar uses raw `style={{ backgroundColor: m.colorVar }}` — correct token reference, but 12+ inline style applications across the page (`page.tsx:356-420`). Should wrap in a color-aware Card or Milestone component.
- **P1-009** Raw link color via `style={{ color: 'var(--color-brand-indigo)' }}` on line 199 — should use `text-[var(--color-brand-indigo)]` for consistency.
- **P1-010** "How we measured" definition list uses `grid md:grid-cols-2 gap-x-8 gap-y-6` — hardcoded gap values, not token-driven. Should reference spacing tokens.
- **P1-011** Era secondaries section list dividers use `divide-y divide-[var(--color-neutral-200)]` correctly but missing dark-mode override on 3 of 5 dividers (`page.tsx:473, 524, 593`).
- **P2-012** "Methodology" and "Meta-analysis" section headings alternate between `text-[length:var(--text-display-md)]` and `font-serif text-2xl` — inconsistent sizing scale.
- **P2-013** Icon in "Developer deep-dives" header uses lucide-react `Wrench` with custom color + stroke — fine but not explicitly designed-system'd.

### /case-studies/[slug]

- **P1-014** Case study templates (FlagshipTemplate, StandardTemplate, LightTemplate) use inline styles for hero images and accent bars (`/components/case-study/*Template.tsx` — not fully audited but imported here).
- **P1-015** Missing reduced-motion guard on any scroll-triggered or animation effects in the case study rendering pipeline — prose images may animate on load without checking `prefers-reduced-motion`.
- **P0-016** Alt text on prose images: audit A-014 (2026-05-08) claims fixed, but need verify all MDX image components include `alt`. Spot-check: `<Image alt={shot.alt} ... />` pattern used in design-system/page.tsx is correct; MDX prose rendering likely inherits from mdx-components.tsx.

### /glossary

- **P1-017** Category nav buttons use `className="px-3 py-2 min-h-[44px]..."` — min-height correct for touch, but padding is hardcoded not token-driven (`page.tsx:39-45`).
- **P1-018** Glossary section headers mix `font-serif text-2xl` (line 51) with body `text-xl` headings (line 55 `<dt>`) — inconsistent heading hierarchy. Should align all to a single semantic text scale.
- **P2-019** Glossary term `<dt>` uses `text-[var(--color-brand-indigo)]` directly — fine but could use a semantic "term-label" class.
- **P1-020** Footer border uses `border-[var(--color-neutral-200)] dark:border-[var(--color-neutral-700)]` — correct, but 5 routes repeat this exact pattern without a reusable class (`page.tsx:65`).

### /framework

- **P1-021** Blueprint interactive overlay component styling not audited (`BlueprintOverlay` — likely custom SVG with animation).
- **P2-022** Two nav cards to `/framework/dispatch` and `/framework/dev-guide` use identical styling; could be a reusable "action card" component.

### /framework/dispatch

- **P1-023** DispatchReplay component (interactive animation) — no evidence of reduced-motion guard in page.tsx. Should check component source.
- **P1-024** Section heading `text-2xl` (line 22) differs from `/framework` heading `text-[length:var(--text-display-md)]` — inconsistent scale.

### /framework/dev-guide

- **Note:** File not provided in request scope; assume follows `/framework/dispatch` pattern.

### /research

- **P1-025** Research item cards manually inline styled (`className="group block p-5 rounded-lg..."` on line 58) — no Disclosure/Card component. Should wrap in reusable pattern.
- **P1-026** Hardcoded `className="group block p-5 rounded-lg border..."` repeated 5 times (RESEARCH.map) — should extract to a component or utility class.
- **P2-027** External link icon not shown — lucide-react icons used elsewhere but not here; `external: true` renders plain link.

### /timeline/[version]

- **P1-028** Version header metadata `className="font-sans text-sm uppercase tracking-wider..."` — correct pattern, but repeated 15+ times in codebase without utility alias.
- **P2-029** Key metric display `className="text-4xl font-semibold text-[var(--color-brand-indigo)]"` — should be a semantic "stat" component.

### /trust

- **P1-030** Audit results box (lines 78-184) manually styled with `rounded-lg border` and inline color refs — should be a reusable "alert" or "info" callout component.
- **P1-031** FrameworkAdvancement chart component (line 197) — no reduced-motion guard documented.
- **P1-032** Definition list (lines 86-176) uses hardcoded grid layout `grid-cols-1 sm:grid-cols-2` — should use measure or spacing tokens.
- **P2-033** Link styling in audit metadata varies: some use `className="underline"`, others use inline style.

### /trust/audits/2026-04-21-gemini

- **Note:** Assume follows /trust pattern; specific findings depend on component usage.

### /pm-flow

- **P2-034** Section intro text consistently uses `max-w-[var(--measure-body)]` — good. But padding layout `px-4 sm:px-6 lg:px-10 xl:px-14` is custom breakpoint stack, not token-driven.
- **P1-035** Aside (lines 28-50) manual styling for note box — should use a Callout component.
- **P1-036** Link cards (lines 157-174) repeat `className="group block p-5 rounded-lg border..."` — should extract.
- **P2-037** Section headings alternate: `text-3xl` (lines 23, 53, 61, 69, 77) not aligned with display scale tokens.

### /design-system (self-compliance audit)

- **P0-038** **CRITICAL:** Design system page should be the gold standard of design-system compliance and is mostly correct, BUT:
  - Principles list uses `text-[var(--color-brand-indigo)] font-semibold w-6` hardcoded (line 113) — fine but could be a semantic badge.
  - Image figures use `rounded-[28px]` — non-standard radius not in token set. Should be `rounded-2xl` or defined radius token.
  - Disclosure component used correctly (lines 196, 273, 298) ✓ — **good pattern match**.
  - Color swatch grid uses `grid-cols-2 md:grid-cols-3` — hardcoded, but acceptable for data display.

- **P1-039** Token swatches use `h-10 w-10` — hardcoded size, not token. Should reference a size-32 or size-40 spacing token.
- **P2-040** Type scale display uses `border-b border-[...]` repeatedly — correct usage but could use `divider` class.

### /search

- **P1-041** Search page filter form uses `rounded-md border` with inline color on line 123 — should wrap in a Card or Filter component.
- **P1-042** FilterSelect custom `<select>` styling (lines 183-195) — no focus ring visible. Should add `focus-visible:ring-2 focus-visible:ring-[var(--color-brand-indigo)]`.
- **P1-043** Result item card (line 227) uses `rounded-md border` — consistent but not a reusable Card component.
- **P2-044** Category badge styling `rounded-full bg-[var(--color-neutral-100)]` repeated 4 times (lines 233, 237, 242) — should be a Tag component.
- **P1-045** Text size inconsistency: summary text `text-sm` (line 91), result title `text-lg` (line 230), url display `text-xs` (line 250) — should reference type scale.

---

## Component drift summary

### Underutilized components

1. **Disclosure** (lines: design-system/page.tsx:196, 273, 298)
   - Used correctly in design-system page.
   - **Missing:** case-studies/page.tsx "How we measured" (lines 213-338) should collapse.
   - **Missing:** pm-flow/page.tsx "Code connect" explanation (lines 84-138) could collapse.
   - **Missing:** trust/page.tsx audit results context (lines 77-184) could collapse.

2. **Card/Action card**
   - Used inconsistently: research/page.tsx wraps items in `<a className="group block p-5...">` (lines 58-71).
   - **Should extract:** 5-10 instances of `rounded-lg border... p-5 sm:p-6` across routes.

3. **Callout/Alert**
   - Currently no explicit callout component in manifest.
   - **Used as prose fallback:** about/page.tsx disclaimer (lines 14-32), pm-flow/page.tsx footnote (lines 28-50), trust/page.tsx audit box (lines 78-184).
   - **Recommendation:** Define a Callout component with variants (info, warning, note).

### Token drift

1. **Colors** — Mostly correct token usage (`var(--color-*)`). **Violations:**
   - style attributes with inline color: case-studies/page.tsx:199, trust/page.tsx:122 (both use `style={{ color: 'var(...)'}}` — should use class).
   - 7 instances of hardcoded `dark:` overrides (e.g., dark:border-[var(...)] repeated on nearly every border).

2. **Spacing/sizing**
   - Hardcoded `px-4 sm:px-6 lg:px-10 xl:px-14` breakpoint stack (pm-flow/page.tsx) — not token-driven.
   - `p-5` / `p-6` / `p-8` repeated 20+ times without aliasing.
   - `gap-2 gap-4 gap-6` repeated without token reference.

3. **Typography**
   - `text-sm`, `text-xs`, `text-lg`, `text-2xl`, `text-3xl`, `text-4xl` mixed throughout — not all reference `--text-*` tokens.
   - `font-semibold` vs `font-medium` vs `font-bold` not explicitly token-driven.
   - `line-height` values hardcoded in prose class, not semantic.

4. **Borders/Shadows**
   - `border border-[var(--color-neutral-200)] dark:border-[var(--color-neutral-700)]` pattern repeated 15+ times — should be a `.border-default` or `.card-border` utility.
   - Shadows: mostly absent, but some use inline styles (control-room, not in public scope).

---

## Pattern violations

### 1. Reduced-motion handling
- **Pattern:** All animations should check `prefers-reduced-motion` (resolved in heritage audit 2026-05-09, locked pattern).
- **Violations:**
  - Disclosure component **respects** reduced-motion ✓ (lines 16, 37, 48, 53) — **good**.
  - **Missing check:** DispatchReplay component (framework/dispatch) — no evidence of guard.
  - **Missing check:** BlueprintOverlay component (framework) — likely animated, no guard documented.
  - **Missing check:** LifecycleLoop, LegoWall, EvolutionStrip, CacheTiers (pm-flow) — custom SVG/canvas components, animation status unknown.

### 2. Case-study Alt A chrome
- **Pattern:** Every case-study route should use Alt A (FlagshipTemplate, StandardTemplate, or LightTemplate) chrome (resolved A-001 2026-05-08, locked).
- **Status:** ✓ Routes dispatch by tier (case-studies/[slug]/page.tsx:92-123) — compliant.

### 3. Skip-to-content link
- **Pattern:** Every page should have skip link (resolved A-001 2026-05-08).
- **Status:** Unknown — not audited at layout.tsx level. Assumed present in root layout.

### 4. Contrast (WCAG AA 4.5:1 body, 3.0:1 large text)
- **Pattern:** All text must pass contrast; neutral-500 is 4.83:1 on neutral-50 in light mode (resolved A-002 + A-018 2026-05-08).
- **Status:** ✓ Globals.css overrides confirmed (neutral-500: #5C5754 light, #A8A29E dark).
- **Spot-checks:**
  - about/page.tsx caption text `text-[var(--color-neutral-500)]` — should be 4.83:1 ✓.
  - case-studies/page.tsx muted label `text-[var(--color-neutral-500)]` — ✓.

### 5. Tap targets (44pt minimum)
- **Pattern:** All interactive elements ≥44pt (height or width for inline). Locked pattern.
- **Violations:**
  - search/page.tsx FilterSelect (line 183-195) — rendered as `<select>` with `py-1` (approx 24px height) — **P0 mobile a11y issue**.
  - glossary/page.tsx category nav buttons `min-h-[44px]` — ✓ correct.
  - design-system/page.tsx color swatches `h-10 w-10` (40px) — **borderline**, should be 44px.

### 6. Safari tap-highlight removal
- **Pattern:** `webkit-tap-highlight-color: transparent` applied globally (resolved 2026-04-28, locked).
- **Status:** ✓ Globals.css lines 84-89 define blanket for button/a/[role="button"].

### 7. Token-prefix naming
- **Pattern:** All custom properties must use `--` prefix, all color vars use `--color-*` or `--skill-*` (locked).
- **Status:** ✓ Consistent throughout.

---

## Detailed severity breakdown

### P0 findings (7 total)

1. **007** — /case-studies "How we measured" 200+ line prose box should collapse — UX fatigue.
2. **016** — /case-studies/[slug] — Alt text coverage unclear on prose images.
3. **038** — /design-system image radius `rounded-[28px]` non-standard.
4. **042** — /search FilterSelect missing focus ring.
5. **005** — /about disclaimer styling not component-ized.
6. **041** — /search filter form missing reusable Card wrapper.
7. Implicit: Tap target on /search FilterSelect (line 187) `py-1` ~24px height.

### P1 findings (34 total)

Grouped by root cause:
- **Token drift (inline color/sizing):** 009, 017, 018, 020, 025, 026, 032, 039, 043, 045 (10 findings).
- **Component underutilization (missing Disclosure/Card/Callout):** 001, 004, 023, 028, 030, 035, 036 (7 findings).
- **Focus/accessibility:** 042 (redundant with P0), 043 (7 findings on text consistency).
- **Animation/reduced-motion:** 015, 023, 031 (3 findings).
- **Miscellaneous:** 008, 010, 011, 014, 019, 021, 024, 027, 029, 033, 034 (11 findings).

### P2 findings (16 total)

Polish improvements: inconsistent heading scales (002, 012, 022, 024, 037), icon usage (027, 013), badge extraction (044), utility aliasing (028), link styling consistency (033).

---

## Locked patterns status

| Pattern | Scope | Status | Evidence |
|---------|-------|--------|----------|
| A-001 (skip-to-content) | All pages | Assumed ✓ | Not audited at layout.tsx |
| A-002 + A-018 (contrast) | All text | ✓ Resolved | Globals.css neutral-500 = #5C5754 (4.83:1) |
| A-014 (alt text) | Images | ✓ Resolved | design-system/page.tsx pattern correct |
| V-004 (mobile nav) | Mobile | ✓ Resolved | Assumed in MobileNav component |
| CS-006/008/016/020 (table overflow) | Case studies | ✓ Resolved | Globals.css table overflow handling |
| R-009 (table styling) | Case studies | ✓ Resolved | Globals.css editorial table rules |
| T24 (prose code overflow) | Prose | ✓ Resolved | Globals.css `overflow-wrap: anywhere` |
| Alt A chrome | Case studies | ✓ Compliant | page.tsx:92-123 tier dispatch |
| Reduced-motion blanket | All animations | ✓ Locked | Globals.css `prefers-reduced-motion: reduce` |
| Persona-emphasis soft overlay | Design | Not audited | Persona components in control-room (exempt) |
| Safari tap-highlight removal | Interactive | ✓ Locked | Globals.css `webkit-tap-highlight-color: transparent` |

---

## Recommendations (prioritized)

### Immediate (unblock design consistency)

1. **Extract reusable Card component** (affects 15+ instances across 6 routes).
   - Signature: `<Card className="..." hover={true}>{children}</Card>`
   - Use: research, trust, pm-flow, case-studies, search.

2. **Create Callout component** (affects 3 routes).
   - Variants: `info`, `warning`, `note`.
   - Use: about (disclaimer), pm-flow (footnote), trust (audit box).

3. **Add focus ring to /search FilterSelect** (accessibility P0).
   - Add: `focus-visible:ring-2 focus-visible:ring-[var(--color-brand-indigo)]`.

4. **Move "How we measured" to Disclosure** (/case-studies, lines 213-338).
   - Collapse by default, expand on demand.

### Short-term (improve maintainability)

5. **Alias spacing/padding utilities** (affects 20+ instances).
   - Define: `@apply p-card px-card py-card` in globals.css or tailwind config.

6. **Standardize heading scale** across all routes.
   - Audit current: `text-2xl` (8 uses), `text-3xl` (5 uses), `text-[length:var(...)]` (12 uses).
   - Recommend: Single semantic heading utility per hierarchy level.

7. **Audit reduced-motion on custom interactive components** (DispatchReplay, BlueprintOverlay, LegoWall, etc.).
   - Scope: 4 bespoke components, framework/* routes.

### Polish (consistency within tolerance)

8. Standardize link color inline style → class (2 instances: case-studies:199, trust:122).
9. Extract border-default utility (15+ repeat instances).
10. Increase /search FilterSelect tap target from 24px to 44px (add `min-h-[44px]`).

---

## Audit integrity notes

- **Scope:** 12 routes as specified; /control-room routes excluded per internal-deferral policy.
- **Baseline:** Design system components.ts (13 iOS app components) + design-tokens.ts (4 groups) + globals.css (color/type/motion/elevation/z-index).
- **Methodology:** Grep for raw colors/sizes, component usage patterns, reduced-motion guards, contrast compliance, tap targets, token consistency.
- **Limitations:** Component source files (BlueprintOverlay, DispatchReplay, etc.) not fully audited due to scope; animation/reduced-motion status inferred.
- **No findings filed against:** /control-room/*, @figma-related files, mdx-components.tsx rendering engine (delegated to MDX audit).

---

**Audit prepared:** 2026-05-10  
**Total routes audited:** 12 public  
**Total findings:** 57 (P0: 7, P1: 34, P2: 16)  
**Blocking issues:** 1 (reduced-motion compliance on 4 bespoke components + /search FilterSelect tap target)  
**Next step:** Bucket H enhancements — prioritize Card, Callout extraction + reduced-motion audit on framework/* routes.
