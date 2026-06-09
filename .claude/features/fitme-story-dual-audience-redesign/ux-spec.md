# UX Spec — fitme-story Dual-Audience Redesign

**Phase:** 3 (UX/UI Definition) · `work_subtype: new_ui` (web)
**Companions:** [prd.md](./prd.md) · [design spec](../../../docs/superpowers/specs/2026-06-09-fitme-story-dual-audience-redesign-design.md)
**Grounding:** symbols below are verified to exist in `/Volumes/DevSSD/fitme-story` (preflight pass).

---

## 0. KEY RECONCILIATION — reuse the existing persona system (do not build net-new)

The site already ships a persona mechanism. The "lens" is a **refactor + narrowing** of it, not a new system.

| Existing symbol (real) | Path | Reuse / change |
|---|---|---|
| `PersonaProvider`, `usePersona()`, `useCurrentPersona()` | `src/lib/persona-context.tsx` | **Narrow `Persona` from `hr\|pm\|dev\|academic` → `dev\|pm`.** Keep provider + hooks. |
| `persona_emphasis: {hr,pm,dev,academic}` frontmatter | `src/lib/content-schema.ts` | Keep; read only `dev`/`pm` for ordering. HR/academic keys ignored (left in data, not surfaced). |
| `NumbersPanel` persona-aware labels | `src/components/home/NumbersPanel.tsx` | Reduce to 2-persona copy. |
| `ThreeWaysIn` (4 persona cards) | `src/components/home/ThreeWaysIn.tsx` | **Remove** from home; replaced by the 2-option lens chooser. |
| Persona persistence = URL search param (`PersonaSearchParamsSync`, `useSearchParams`) | `src/lib/persona-context.tsx` | **Add a cookie (`fitme_lens`) as the SSR source of truth** so the server renders the right spine with no flash. URL param stays as a shareable override that, when present, writes the cookie. |

**Terminology:** user-facing label is the audience ("For developers" / "For product managers"); internal type is the narrowed `Persona`/lens (`dev`/`pm`). We keep the existing `persona` vocabulary in code to minimize churn; "lens" is the product name for the chooser/toggle.

**Net effect on tasks:** T1–T4 become "refactor persona-context + add cookie SSR layer + new toggle," not "build a provider from scratch." Lower risk, less new surface.

## 1. Components

### 1.1 New — `LensToggle` (segmented Dev | PM control)
No segmented/tabs primitive exists today (theme toggle is a single icon button). Build `LensToggle` as a new `ui/` primitive.
- **Variants:** `header` (compact, mounts in `SiteHeader.tsx` trailing icon cluster `flex items-center gap-1 md:gap-2`, beside the theme toggle; and in `MobileNav.tsx`) and `chooser` (large, two labeled cards for the home hero).
- **Tokens:** `--color-brand-indigo` (active), `--color-neutral-*` (rest), `--motion-duration-fast` (120ms) for the active-segment slide, `--motion-easing-standard`.
- **A11y:** `role="radiogroup"` + two `role="radio"` (`aria-checked`); full keyboard (←/→ + Enter/Space); visible 2px focus ring (matches `Button`); ≥44px targets; honors reduce-motion (no slide animation when `prefers-reduced-motion`).
- **Behavior:** on select → write `fitme_lens` cookie + `setPersona()` + `router.refresh()` (re-render server spine). Fires analytics (§4).

### 1.2 Reused primitives (no new build)
| Need | Reuse | Path |
|---|---|---|
| Case-study era accordion | **`Disclosure`** (`label`, `summary?`, `defaultOpen?`; Framer-Motion 220–280ms, `aria-controls`) | `src/components/ui/Disclosure.tsx` |
| Study cards | `CaseStudyCard` (`href`, `title`, `tldr?`, `tagLabel?`, `tagVariant?`) | `src/components/ui/CaseStudyCard.tsx` |
| Era/subject labels + counts | `Tag` (`variant: flagship\|standard\|tier_t1\|muted`) | `src/components/ui/Tag.tsx` |
| Numbers strip on home | `Stat` (`value`,`label`,`size`,`accent`,`serif`) | `src/components/ui/Stat.tsx` |
| CTAs / chooser cards | `Button` (`variant: primary\|secondary\|ghost`), `Card` (`variant`,`padding`,`interactive`) | `src/components/ui/{Button,Card}.tsx` |

## 2. Screen specs + 5 states

### 2.1 Home (`/`) — rebuilt compact (T5)
Order: **Hero (who+what)** → **origin hook** (1 para, reuse `OriginNarrative` beat-1 condensed) → **`LensToggle` chooser** → **numbers strip** (`Stat` ×5, persona-aware via `NumbersPanel`) → **3 featured `CaseStudyCard`** → **"Read the full story → /story"** (`Button` secondary).
- **No lens chosen:** chooser is the visual focus; featured studies show a neutral default set; subtle "pick a view" affordance.
- **Loading (SSG):** static; persona resolved from cookie server-side (no skeleton needed).
- **Empty:** n/a (static content).
- **Error:** if content fetch fails, featured-studies block is omitted, rest renders.
- **Lens-selected:** featured studies + copy emphasis reorder for `dev`/`pm`.

### 2.2 `/story` — new lens-aware narrative (T6)
Sections: `who` → `what` → `started` (the pm-flow seed) → `grew` (reuse `Timeline` data) → `today`.
- PM lens leads with outcomes/process; Dev lens leads with mechanisms/architecture (same sections, reordered emphasis + different pull-quotes).
- States: static; no-cookie → PM default + dismissible "viewing as PM — switch to Dev" banner (`Callout`). Scroll observer fires `story_scroll_depth` per section.

### 2.3 `/case-studies` — era-grouped accordion (T7+T8)
- One `Disclosure` per era: `v7.x` (`defaultOpen`) → `v6.0` → `v5.x` → `v4.x` → `v2.0`. `label` = era name + `Tag` count badge. Inside: subject sub-headers (Framework / Design System / Product Features / Meta & Methodology / Dev deep-dives), each a list of `CaseStudyCard`, ordered by `persona_emphasis[lens]` then `date` desc.
- Sticky era **jump-nav** rail (anchors to each `Disclosure`); "expand all" toggles every `Disclosure` open.
- Retain existing search/filter. Featured/milestone studies pin atop the `v7.x` era.
- **Era/subject from new frontmatter** (`era`, `category` — T7 backfill), replacing the current slug-regex bucketing in `case-studies/page.tsx`.
- States: loading=static; empty (filter no-match) → "no studies match" row; error → fall back to flat date-sorted list.

### 2.4 `/framework` (T9 + T10)
- **T9:** add `v7.9.1 (2026-06-04)` node to `BRIDGE_TIMELINE` in `src/lib/timeline.ts` (label: "Build window — 8 ships / 14 PRs, 0 new enforcement gates").
- **T10:** lens-order sections — PM: why → outcomes → lifecycle (architecture in a collapsed `Disclosure`); Dev: architecture → gates/hooks → schema lead.

### 2.5 Nav (T11) + spines (T12)
- `nav.ts` NAV array reordered per lens at render (PM: PM Flow, Case Studies, Framework, Design System; Dev: Framework, Dev Guide, Design System, Case Studies). Add `/story`. Keep `isCurrentNav()` active logic + gated Control Center entry.
- `/pm-flow` + `/design-system`: PM lens = first-class chapter framing; Dev lens = supporting reference (design-system → tokens/Code Connect detail in a `Disclosure`).

## 3. Design-system compliance (web gateway)

> The iOS `make ui-audit` / `AppTheme.swift` gates do **not** apply (this is the web repo). Compliance is checked against `src/lib/design-tokens.ts` + `src/components/ui/*`.

| Check | Status | Notes |
|---|---|---|
| Token compliance | PASS | All color/space/type/motion via `var(--…)` tokens from `design-tokens.ts`; no raw hex/px in new components |
| Component reuse | PASS | Only 1 genuinely-new component (`LensToggle`); accordion/cards/tags/stats/buttons reused |
| Pattern consistency | PASS | Toggle mounts in existing header icon cluster; mirrors theme-toggle pattern; accordion reuses `Disclosure` |
| Accessibility | PASS (spec) | radiogroup semantics, keyboard, focus ring, 44px, reduce-motion, `aria-controls` on disclosures |
| Motion | PASS | `--motion-duration-fast/standard` + `--motion-easing-*`; reduce-motion respected |

**One new primitive justified:** `LensToggle` — no segmented control exists; it becomes a reusable `ui/` addition (documented in design-tokens usage). Compliance decision: **evolve** (add primitive), not override.

## 4. Analytics reconciliation (corrects PRD assumption)

Real pattern: `emit(eventName, params)` in `src/lib/control-room/analytics.ts` (SSR guard + `window.gtag` guard; **no explicit consent gate** — GA opt-in is via `NEXT_PUBLIC_GA_ID`; gtag silently no-ops if blocked). New public helpers to add (mirroring `trackDashboardLoad` style), with screen-prefixed names per the taxonomy rule:
- `trackHomeLensSelect({lens})` → `home_lens_select`
- `trackNavLensSwitch({from_lens,to_lens})` → `nav_lens_switch`
- `trackStoryScrollDepth({section})` → `story_scroll_depth`
- `trackCaseStudyEraExpand({era,expanded})` → `case_study_era_expand`
- `trackCaseStudyOpen({slug,era,lens})` → `case_study_open`

**PRD correction:** the Phase-5 "consent-gated" verification (T15) is replaced by **"no-GA no-op guard"** verification (event helper is a safe no-op when `window.gtag` is absent) — matching the site's actual model. (Will note this in the PRD at Phase 5.)

## 5. Test + lighthouse bootstrap (scope note for T14–T16)

The site currently has **no test runner and no lighthouse-ci**. So:
- **T14/T15** must bootstrap a test setup (Vitest + React Testing Library is the lightest fit for Next 16). This is larger than the 0.5d estimate — re-estimate at **1.0d** to include harness setup. Flag for Phase 2 re-baseline at implementation.
- **T16** bootstraps `lighthouserc.json` covering `/`, `/story`, `/case-studies`, `/framework` (perf + a11y categories).

## 6. UX principles applied

- **Jakob's Law / recognition:** the audience chooser uses the familiar segmented-control idiom; reuses the site's existing visual language.
- **Hick's Law:** 4 personas → 2 lenses cuts the entry decision in half.
- **Progressive disclosure:** era accordion + per-lens collapsed "go deeper" sections show only what the audience leads with.
- **Feedback:** toggle animates active segment; `router.refresh()` re-renders immediately; events instrument the choice.
- **Consistency:** toggle lives where the theme toggle lives; accordion is the existing `Disclosure`.

## 7. Open items → Phase 4

1. Re-baseline T14–T16 effort (test/lighthouse harness bootstrap, +1.0d).
2. Confirm at Phase 3 approval: keep `persona` code vocabulary (recommended) vs rename to `lens` everywhere (more churn).
3. Whether URL-param persona sharing stays (recommended: yes, it writes the cookie) or is dropped for cookie-only.
