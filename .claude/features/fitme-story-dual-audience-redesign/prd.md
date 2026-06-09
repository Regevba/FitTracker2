# PRD — fitme-story Dual-Audience Redesign

**Feature:** `fitme-story-dual-audience-redesign`
**Phase:** 1 (PRD) · **Work type:** Feature · `has_ui: true` · `requires_analytics: true`
**Date:** 2026-06-09
**Companions:** [research.md](./research.md) · [design spec](../../../docs/superpowers/specs/2026-06-09-fitme-story-dual-audience-redesign-design.md)
**Repos:** implementation → `fitme-story`; state + docs → `FitTracker2` (`state_owner: ft2`)

---

## 1. Overview

Reorient the fitme-story public site around **two audiences — developers and product managers** —
via a persistent, cookie-backed, server-rendered **lens** (`dev | pm`) switchable from the header.
The lens defines the **narrative spine** of every page: in the PM lens the product/process story
(pm-flow, lifecycle, design system, outcomes) leads and engineering supports; in the Dev lens the
engineering (architecture, gates, state schema, dev-guide, Code Connect) leads and product/process
supports. Rebuild the home page to answer who/what/origin/growth compactly, add a lens-aware
`/story` page, reorganize the 68-study case-study list into an era-grouped collapsible layout,
and close the missing v7.9.1 timeline entry.

## 2. Problem (with data)

From the home page it is not clear (a) which audience the site addresses, (b) what the project is /
does / measures / shows. GA4 (fitme-story web, 2026-05-10 → 2026-06-09) quantifies the cost:

| Page | Sessions | Bounce rate | Avg duration | Engagement |
|---|---|---|---|---|
| `/` (home) | 21 | **76.2%** | 65s | 23.8% |
| `/case-studies` | 4 | 0% | 53s | 100% |
| `/framework` | 3 | 0% | 77s | 100% |
| `/design-system` | 3 | 0% | 346s | 100% |
| `/about` | 2 | 0% | 371s | 100% |

(T1, GA4. Low traffic → directional, not statistically tight.) **The home page bounces ~3.5× the
site's content pages.** Visitors who reach a content page stay and engage; the home page itself fails
to convert curiosity into navigation. Secondary problem: 68 case studies in one long scroll make
recent work hard to reach; the framework timeline is missing v7.9.1.

## 3. Goals & non-goals

**Goals**
1. Make the audience explicit (Dev + PM) and let the chosen lens define each page's narrative spine.
2. Rebuild the home page so a first-time visitor understands who/what/origin/growth and chooses a lens fast.
3. Move the deep narrative to a lens-aware `/story` page.
4. Reorganize case studies into an era-grouped collapsible layout so recent work is one click away.
5. Add the v7.9.1 framework-timeline entry.

**Non-goals:** the gated `/control-room/*` operator surface; the iOS app; authoring any NEW
case-study content (re-presentation only + the v7.9.1 factual add). `/about` is retained alongside `/story`.

## 4. Users / audiences

| Audience | Wants | Lens spine |
|---|---|---|
| **Developer** | How the framework is built — architecture, gates, `state.json` schema, dev-guide, Code Connect, CI | Engineering leads; product/process is motivating context |
| **Product manager** | How the PM lifecycle works, what it produces, outcomes, the design system as a product asset | Product/process leads (pm-flow, lifecycle, design system, outcomes); engineering supports |

First-time / no-cookie visitors: home renders neutral with the chooser prominent; deep links default
to the **PM lens** with a dismissible "viewing as PM — switch to Dev" hint.

## 5. Requirements

### 5.1 Lens engine (core)
- `fitme_lens` cookie is the SSR source of truth; `getLens()` server util resolves `dev | pm | null`.
- `LensProvider` in the root layout injects `lens` into the tree (server + client).
- `LensToggle` (segmented `Dev | PM`) in the site header: sets cookie + `router.refresh()`; reachable on every page.
- `useLens()` / `<LensGate lens>` helpers let any section declare lens-variant content/order.
- No page duplication; lens-aware pages reorder / relabel / show-hide. No hydration mismatch (lens never client-only-derived).

### 5.2 Home (`/`) — rebuilt, compact
- Hero (who + what) → 1-paragraph origin hook → **lens chooser** high up → numbers strip → 3 featured case studies → "Read the full story → /story".
- Remove the 4-persona `ThreeWaysIn`; express only Dev + PM via the chooser.
- After a lens is chosen, featured studies + copy emphasis follow the lens.

### 5.3 `/story` — new, lens-aware
- Sectioned narrative: who → what → how it started (the pm-flow seed) → how it grew (timeline) → today.
- PM lens: outcomes/process/lifecycle emphasis. Dev lens: mechanisms/architecture emphasis.

### 5.4 `/framework`
- Lens-aware section ordering. Add **v7.9.1 (2026-06-04)** to the timeline (`src/lib/timeline.ts` `BRIDGE_TIMELINE`).
- PM: why → outcomes → lifecycle (architecture collapsed). Dev: architecture → gates/hooks → schema.

### 5.5 `/case-studies` — era-grouped, collapsible
- Primary axis: era (`v7.x` newest expanded → `v6.0` → `v5.x` → `v4.x` → `v2.0` collapsed), from `timeline_position.version`.
- Secondary: subject (Framework / Design System / Product Features / Meta & Methodology / Dev deep-dives).
- Within subject: order by `persona_emphasis` for active lens, then date desc.
- Accordion + per-era count badges + "expand all" + sticky era jump-nav + existing search/filter retained.
- Backfill explicit `category` + `era` frontmatter on the 68 MDX (derive from current slug map, spot-check), then group from frontmatter not regex.

### 5.6 `/pm-flow` & `/design-system` — lens spine members
- PM lens: first-class chapters (pm-flow surfaced prominently in PM nav; design-system framed as "why + what it guarantees").
- Dev lens: supporting reference (design-system → tokens/components/Code Connect detail).

### 5.7 Nav
- Reorders per lens. PM order: PM Flow / Case Studies / Framework / Design System. Dev order: Framework / Dev Guide / Design System / Case Studies. `/story` linked from home + nav.

## 6. Success metrics

> All metrics are GA4 (web). Traffic is low (~20 home sessions/30d) — treat targets as **directional**;
> evaluate on trend + a ≥60-day window, not a single week.

**Primary**
- **Lens-selection rate** = `home_lens_select` sessions / home `page_view` sessions.
  Baseline **0** (mechanism is new). **Target ≥ 40%** within 60 days of launch. (T1)

**Secondary**
- **Home bounce rate**: baseline **76.2%** → **target ≤ 60%** at 60 days. (T1)
- **Case-study reach depth**: share of `/case-studies` sessions that open ≥1 study OR expand a non-newest era. Baseline TBD at instrumentation; **target ≥ 35%**. (T1)
- **`/story` engagement**: median `story_scroll_depth` reaches the "how it grew" section in ≥ 50% of `/story` sessions. (T1)

**Guardrails (must not degrade)**
- Content-page bounce (`/framework`, `/case-studies`, `/design-system`) stays ≤ current (~0–25%). (T1)
- Lighthouse perf on changed routes (`/`, `/story`, `/case-studies`, `/framework`) not lower than current CI budget. (T1, lighthouse-ci)
- Cross-page navigation depth (pages/session) not lower than baseline. (T1)

**Leading indicators (≤ 1 week)**: `home_lens_select` fires; `nav_lens_switch` observed; no lighthouse regression on changed routes.
**Lagging indicators (30/60/90d)**: home bounce trend; case-study reach depth; `/story` completion.

**Instrumentation plan**: GA4 events in §7, wired in the home chooser, header toggle, `/story` scroll observer, and case-study accordion. Verified via the analytics test layer in Phase 5.

**Review cadence**: first review **2026-07-09** (T+30d), then **2026-08-09** (T+60d, primary-metric evaluation).

**Kill criteria**
- At T+60d: lens-selection rate < 20% **AND** home bounce not improved (> 70%) → revert to a neutral (lens-less) home; keep the case-study + timeline improvements.
- Lens switching causes measurable confusion: cross-page navigation depth drops > 15% vs baseline OR direct feedback signals confusion → simplify the lens (e.g., make PM the silent default, demote the toggle).

## 7. Analytics Spec (GA4) — requires_analytics = true

New events (screen-prefixed per the taxonomy convention; `home_`/`story_`/`case_study_` screen-scoped, lens-switch is global):

| Event | Scope | Params | GA4 type | Conversion? | Trigger |
|---|---|---|---|---|---|
| `home_lens_select` | home | `lens` (`dev`\|`pm`) | custom | **yes** | First/explicit lens choice in the home chooser |
| `nav_lens_switch` | global | `from_lens`, `to_lens` | custom | no | Header `LensToggle` used on any page |
| `story_scroll_depth` | story | `section` (`who`\|`what`\|`started`\|`grew`\|`today`) | custom | no | `/story` section enters viewport |
| `case_study_era_expand` | case_studies | `era`, `expanded` (bool) | custom | no | Era accordion toggled |
| `case_study_open` | case_studies | `slug`, `era`, `lens` | custom (verify reuse) | no | A study card/link opened (extend existing if present) |

**Naming validation checklist**
- [x] snake_case, lowercase
- [x] ≤ 40 chars (event + param names)
- [x] no reserved prefixes (`ga_`/`firebase_`/`google_`)
- [x] no PII in any param (lens/era/section/slug are non-PII enums/identifiers)
- [x] param values ≤ 100 chars
- [x] ≤ 25 params per event
- [x] screen-prefix rule honored (`home_`/`story_`/`case_study_`; `nav_lens_switch` is global/cross-page)
- [x] GA4 recommended events unaffected

> Note: fitme-story uses its own web GA4 instrumentation (not the iOS `AnalyticsProvider.swift` enums); the Analytics Spec is realized in the site's analytics module + taxonomy doc. Phase 5 verification asserts each event fires with correct params and is consent-gated per the site's existing consent model.

## 8. Risks & dependencies

| Risk | Mitigation |
|---|---|
| SSR hydration mismatch on lens | Read cookie server-side, pass lens down; never derive client-only |
| Low traffic → noisy metrics | Directional targets; ≥60-day eval window; trend over point |
| Frontmatter backfill inaccuracy | Derive from current slug map; spot-check; backfill is reversible data-only |
| Lens doubles per-page content cost | Re-narrate shared content, don't duplicate pages; spine = ordering/emphasis, not new copy everywhere |
| Lighthouse regression on rebuilt routes | lighthouse-ci gate on changed routes in Phase 5/6 |

**Dependencies:** Next.js 16 App Router; existing GA4 web instrumentation + consent model; existing design-system / control-room component vocabulary; `timeline.ts`; the 68 MDX case-study files.

## 9. Rollout

Lens engine → home rebuild → `/story` → case-study era-grouping + frontmatter backfill → per-page
spines + nav → v7.9.1 timeline entry. Each behind CI (build, lint, lighthouse-ci on changed routes,
analytics verification). Feature branch `feature/fitme-story-dual-audience-redesign` in fitme-story;
squash-merge after Phase 6 dual pre-merge review.
