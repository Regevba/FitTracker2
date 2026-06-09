---
title: "fitme-story Dual-Audience Redesign — a cookie-backed lens that re-narrates one site for two audiences"
feature: fitme-story-dual-audience-redesign
date_written: 2026-06-09
date: 2026-06-09
framework_version: v7.9.1
work_type: Feature
work_subtype: new_ui
dispatch_pattern: dual-outlet
primary_metric: "Lens-selection rate (home_lens_select sessions / home page_view sessions); baseline 0; target ≥40% within 60d (T1, GA4)"
success_metrics:
  - "Primary: lens-selection rate ≥40% at 60d (baseline 0) — T1"
  - "Home bounce rate 76.2% → ≤60% at 60d — T1"
  - "Case-study reach depth ≥35% of /case-studies sessions — T1"
  - "/story scroll reaches 'how it grew' in ≥50% of sessions — T1"
kill_criteria:
  - "T+60d: lens-selection rate <20% AND home bounce not improved (>70%) → revert to a neutral lens-less home; keep the case-study + timeline improvements"
  - "Lens switching causes measurable confusion: cross-page navigation depth drops >15% vs baseline OR direct confusion feedback → simplify the lens (PM as silent default, demote toggle)"
kill_criteria_resolution: "Pre-registered, not yet evaluable at ship. The lens mechanism is net-new (baseline 0) and both kill criteria are 30/60-day metric evaluations. First review 2026-07-09 (T+30d), primary-metric evaluation 2026-08-09 (T+60d). No kill condition is triggerable at ship time; resolution will be recorded at the first review."
related_prs:
  - "fitme-story PR #213"
tier_tags_present: true
state_owner: ft2
---

# fitme-story Dual-Audience Redesign

> **One-line:** the public site served one undifferentiated narrative to two distinct audiences (developers and product managers); this feature introduces a persistent, cookie-backed, server-rendered **lens** (`dev | pm`) that reorders and re-frames every page around the chosen audience — without duplicating a single page.

## Problem (with data)

GA4 (fitme-story web, 2026-05-10 → 2026-06-09) showed the home page bouncing at **76.2%** — roughly **3.5×** the site's content pages (`/case-studies`, `/framework`, `/design-system`, `/about` all bounced 0% and engaged 100% over the window). **(T1, GA4 — low traffic, ~21 home sessions/30d, so directional not statistically tight.)** Visitors who reached a content page stayed and engaged; the home page itself failed to convert curiosity into navigation, because it never made explicit (a) which audience the site addresses or (b) what the project is / does / measures.

Two secondary problems: 68 case studies in one long scroll buried recent work, and the framework timeline was missing its v7.9.1 entry. **(T2, declared from the content inventory.)**

## What shipped

Implementation landed as a single squash-merge: **fitme-story PR #213** (96 files, +1653/−624), merge commit `1f5bd09`, 2026-06-09. State + docs live in FitTracker2 (`state_owner: ft2`) per the cross-repo contract; the runnable code lives in fitme-story. This is the **dual-outlet dispatch pattern** — one feature, two repos, state authoritative in FT2.

1. **Lens engine (core).** A `fitme_lens` cookie is the SSR source of truth; a `getLens()` server util resolves `dev | pm | null`, a `LensProvider` injects it into the tree, and a header `LensToggle` (one justified new primitive — no segmented control existed) sets the cookie + `router.refresh()`. `useLens()` / `<LensGate>` let any section declare lens-variant order/content. The lens is **never client-only-derived**, so there is no hydration mismatch.
2. **Home, rebuilt compact** — hero (who + what) → origin hook → lens chooser high up → numbers strip → 3 featured studies → "Read the full story → /story". The old 4-persona `ThreeWaysIn` was removed in favor of an explicit Dev + PM chooser.
3. **`/story`** — new lens-aware narrative (who → what → how it started → how it grew → today).
4. **`/case-studies`** — era-grouped collapsible layout (v7.x expanded → v2.0 collapsed), driven by **backfilled `category` + `era` frontmatter** on the 68 MDX files (derived from the slug map, spot-checked) rather than regex; existing search/filter retained.
5. **`/framework`** — lens-aware section ordering + the missing **v7.9.1 (2026-06-04)** timeline entry.
6. **Per-page spines + nav reorder** per lens; GA4 events (`home_lens_select`, `nav_lens_switch`, `story_scroll_depth`, `case_study_era_expand`, `case_study_open`) wired and consent-gated.

## How the framework carried it

- **Full 10-phase lifecycle in one session** (research 05:20Z → review), all phases logged to `.claude/logs/fitme-story-dual-audience-redesign.log.json` (Tier 2.2). **(T1, contemporaneous log.)**
- **Phase 6 dual pre-merge review passed.** UX: shipped surfaces match `ux-spec.md` — LensToggle (radiogroup a11y), compact home chooser, era-grouped `/case-studies`, lens-aware `/story`; 5 states covered. Design: 100% `var()` tokens + serif/sans typography, reused Disclosure/Tag/CaseStudyCard/Card/Stat, one justified new primitive (LensToggle); iOS ui-audit/figma_node_ids N/A (web repo, re-presentation reusing existing components). **(T1, pre_merge_review record.)**
- **CI green at merge** — lighthouse-ci on changed routes, verify, audit, gates, mdx-render, unit-tests, Vercel, GitGuardian all passed. **(T1, GitHub checks.)**

## Outcome

Net effect: a re-narration, not a rewrite — the lens is ordering + emphasis, not duplicated pages. The success bet (an explicit audience choice converts the home page's curiosity into navigation) is **pre-registered and not yet evaluable** — the mechanism is new (baseline 0) and the metrics need a ≥60-day window. First review **2026-07-09** (T+30d); primary-metric (lens-selection rate ≥40%) evaluation **2026-08-09** (T+60d). Kill criteria are pre-registered above. **(T2, declared targets.)**

## Follow-ups

- **Showcase MDX** (`fitme-story/content/04-case-studies/`) — the chronological public showcase slot for this feature is a fitme-story-repo artifact and ships as a separate fitme-story PR (chronological-order rule, enforced at PR review). Tracked as a follow-up; `case_study_showcase` will be populated when it lands.
- **T+30d / T+60d metric reviews** per the cadence above.
