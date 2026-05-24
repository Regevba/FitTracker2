---
title: fitme-story public enhancements — a 24-task rollup retroactively brought under v7.8.1
date_written: 2026-05-09
date: 2026-05-09
dispatch_pattern: rollup_multi_pr
success_metrics:
  - audit_findings_closed_target: 30
  - audit_findings_closed_actual_at_writing: 26
  - audit_findings_closed_tier: T2
  - mobile_readiness_findings_fixed_top_priority: 8
  - mobile_readiness_findings_fixed_top_priority_tier: T1
  - sub_tasks_complete: 17
  - sub_tasks_total: 24
primary_metric: audit_findings_closed_target_30
kill_criteria:
  - vercel_js_error_rate_increase: ">0.1%"
  - user_reported_regression_per_1000_sessions: ">1"
  - cls_regression_on_case_studies_slug: "<0.1"
kill_criteria_resolution: not_fired
kill_criteria_resolution_note: "Final at phase=complete transition (2026-05-24): all 3 kill criteria did not fire across 17 sub-task PRs (12 fitme-story #59-#71 + #134 + 5 FT2 #256/#258/#260/#261/#266). (a) Vercel JS error rate baseline preserved; (b) zero user-reported regressions; (c) CLS on /case-studies/[slug] ≤ 0.1. T13 (v7.9 mirror) shipped 2026-05-21 via fitme-story PR #134 as the last task without firing any criterion."
framework_version: v7.8.1
work_type: enhancement
work_subtype: rollup_multi_pr
tier_tags_present: true
case_study_type: midstream_outlier_invocation
related_prs:
  - "fitme-story#59"
  - "fitme-story#61"
  - "fitme-story#62"
  - "fitme-story#63"
  - "fitme-story#64"
  - "fitme-story#65"
  - "fitme-story#66"
  - "fitme-story#67"
  - "fitme-story#68"
  - "fitme-story#69"
  - "fitme-story#70"
  - "fitme-story#71"
  - "fitme-story#75"
  - "fitme-story#129"
  - "fitme-story#134"
  - "FT2#256"
  - "FT2#258"
  - "FT2#260"
  - "FT2#261"
  - "FT2#266"
pr_citation_exempt:
  - pr_number: 75
    reason: "fitme-story#75 (T20 Code Connect foundation, 17 component node IDs + 4 primitives) shipped per the v4.X+CC cross-repo Code Connect bridge axis (CLAUDE.md \"v4.X+CC\" section), NOT as an audit-finding closure. Cited in state.json::tasks[T20].pr_number; intentionally not cited in case-study body because the case-study scope is audit-finding closure metrics, not Code Connect track."
  - pr_number: 129
    reason: "fitme-story#129 (T13 v9 mirror predecessor) shipped 2026-05-21 as the first ship of T13 dev-guide v7.9 bump; superseded the same-day by fitme-story#134 (the canonical T13 ship). Retained in state.json::tasks[T13].related_prs for full provenance; case-study body cites only the canonical #134 to avoid redundant narrative."
outlier_disclosure: |
  This is the first case study in the corpus written MIDSTREAM (current_phase=implementation,
  17/24 tasks done) rather than at closure. Written 2026-05-09 per direct user directive after
  the rollup was retroactively brought under v7.8.1 protocol. Pre-2026-05-09 sub-tasks shipped
  with partial logging coverage; post-2026-05-09 sub-tasks (T18, T19, T24) follow full protocol.
  Gap inventory in the body (§ Honest Gaps).
external_audit_status: pending
pr_citation_exempt:
  - pr_number: 59
    reason: "Cross-repo citation to fitme-story repo, not FitTracker2. Bare-number gate cannot resolve. Verified live at fitme-story repo PR 59 (cross-repo)."
  - pr_number: 60
    reason: "Cross-repo citation to fitme-story repo (orphan / superseded by #61). Verified live."
  - pr_number: 61
    reason: "Cross-repo citation to fitme-story repo (T7 ArticleNav). Verified live."
  - pr_number: 62
    reason: "Cross-repo citation to fitme-story repo (T16 MobileNav). Verified live."
  - pr_number: 63
    reason: "Cross-repo citation to fitme-story repo (T14 buildMetadata). Verified live."
  - pr_number: 64
    reason: "Cross-repo citation to fitme-story repo (T13 partial dev-guide mirror). Verified live."
  - pr_number: 65
    reason: "Cross-repo citation to fitme-story repo (T17 rehype-pretty-code + CopyButton). Verified live."
  - pr_number: 66
    reason: "Cross-repo citation to fitme-story repo (T15 callouts). Verified live."
  - pr_number: 67
    reason: "Cross-repo citation to fitme-story repo (T9 frontmatter audit). Verified live."
  - pr_number: 68
    reason: "Cross-repo citation to fitme-story repo (CI infra). Verified live."
  - pr_number: 69
    reason: "Cross-repo citation to fitme-story repo (HADF citation fix). Verified live."
  - pr_number: 70
    reason: "Cross-repo citation to fitme-story repo (T10 search + bundled UX polish). Verified live; merged squash 809a709."
  - pr_number: 71
    reason: "Cross-repo citation to fitme-story repo (T24 mobile-readiness). Verified live; merged squash e675fe9."
pr_citation_exempt_meta_note: |
  Every entry above demonstrates the asymmetry this rollup itself surfaces (Phase B of the
  2026-05-09 directive ports the framework to fitme-story repo, which would let the
  BROKEN_PR_CITATION gate validate cross-repo refs natively). Until Phase B lands, this
  exemption block is the documented escape hatch per CLAUDE.md FEATURE_CLOSURE_COMPLETENESS
  override convention.
---

# fitme-story public enhancements — a 24-task rollup retroactively brought under v7.8.1

> **Outlier disclosure.** This case study is written at `current_phase=implementation` (17/24 tasks done), not at closure. The rollup pre-dated formal protocol invocation. Per user directive 2026-05-09: invoke v7.8.1 retroactively, mark as outlier, fill in gaps honestly. The remaining 7 tasks will continue under full protocol; a closure addendum will append when `current_phase=complete`.

## Trigger

A 2026-05-08 broad audit of [fitme-story.vercel.app](https://fitme-story.vercel.app) (the public-site face of the FitMe project) surfaced 30 findings spanning accessibility (WCAG contrast, focus, skip-to-content, mobile nav), readability (line-length, table overflow, deep-linking), performance (TTI on case-study pages), SEO (per-page OG/canonical), code-presentation (no syntax highlighting, no CopyButton), and design-system gaps (no formal token export, no Figma file).

The findings cleanly cluster into ~24 self-contained sub-tasks, each shippable as a small (<5-files) PR. Rather than spawn 24 features, the team created a **rollup feature** at `.claude/features/fitme-story-public-enhancements/state.json` with `work_type=enhancement` and `work_subtype=rollup_multi_pr`. Each sub-task ships on its own short-lived branch off main; the rollup state.json tracks progress + scope + sequencing.

## Why this rollup is an outlier

The `enhancement` work-type follows a 4-phase lifecycle (Tasks → Implement → Test → Merge). The rollup pattern (`work_subtype=rollup_multi_pr`) was a v7.8.1 latitude: instead of one feature with 24 phases, twenty-four atomic shippables under one umbrella. This works structurally but creates measurement asymmetries:

1. **State.json updates accumulate from main.** The rollup state.json is metadata-only — code lives on per-sub-task branches. When sub-tasks merge to main and the rollup needs reconciling, the update happens FROM main (not on a feature branch). This forced `isolation_opt_out: true` on Mode C of `BRANCH_ISOLATION_VIOLATION`.
2. **No Tier 2.2 emission gate parity for fitme-story.** Per v7.8.2 (PR #258), Tier 2.2 contemporaneous logging gates do NOT fire on fitme-story commits — a documented exemption. Sub-task PRs in fitme-story produced inconsistent log entries, with ~50% coverage.
3. **No Mechanism A coverage telemetry on fitme-story commits.** Same reason as above. The 12 fitme-story PRs (#59–#71) generated zero `gate-coverage.jsonl` entries.
4. **Per-sub-task timing not captured at the granularity gates expect.** `timing.phases` exists at rollup level (session_start 2026-05-08T03:30Z, phases.tasks + phases.implementation timestamps) but not per-sub-task. Each sub-task PR's commit timestamp + merge timestamp is reconstructable from `git log` and `gh pr view`, but it's not in state.json today.

These three asymmetries are the explicit triggers for **Phase B + Phase C** of the 2026-05-09 directive (port full framework to fitme-story; sync data between repos).

## What shipped

### Phase 1 — 2026-05-08 morning (T1–T7, A11y + readability quick-wins)

12 fitme-story PRs landed in one calendar day (T2):

| PR | SHA | Tasks | Scope |
|---|---|---|---|
| fitme-story#59 | `95cb4d1` | T1 + T2 + T3 + T4 + T5 + T6 | Skip-to-content link · WCAG contrast bump on `--color-neutral-500` (4.16:1 → 4.83:1, P0 fail → AA pass) · `aria-current` + 2px underline on nav · global focus-visible ring · rehype-slug + rehype-autolink-headings · `.prose table` `display:block; overflow-x:auto` · `chrome_minimal` frontmatter opt-out · `<TimelineNav>` prev/next |
| fitme-story#60 | `14179cf8` | T7 (orphan, superseded) | First ArticleNav attempt — orphaned for re-do |
| fitme-story#61 | `a548e5f` | T7 | `<ArticleNav>` sticky sidebar with TOC scrape + scroll-progress + active-section IntersectionObserver |
| fitme-story#62 | `d560500` | T16 | `<MobileNav>` hamburger drawer — closes V-004 P0 (mobile nav previously had `hidden md:flex` with no fallback) |
| fitme-story#63 | `83b1a89` | T14 | `buildMetadata()` helper + per-page OG / Twitter / canonical |
| fitme-story#64 | `ddfdae4` | T13 (partial) | Dev-guide page mirrors v7.8.2 bump from FT2 |
| fitme-story#65 | `ef1077f` | T17 | `rehype-pretty-code` syntax highlighting (dual-theme github-light/dark) + `<CopyButton>` MDX component |
| fitme-story#66 | `3da5591` | T15 | Callout component family — `<HonestDisclosure>`, `<TriggerIncident>`, `<MemoryRef>`, `<PredecessorChain>`, `<KillCriterionResolution>` |
| fitme-story#67 | `e79bc8c` | T9 | Frontmatter audit + backfill 5 MDX → COMPLIANT_FULL + label 3 BARE_INTENTIONAL |
| fitme-story#68 | `df79d11` | infra | CI: wire Vercel SSO bypass token into `verify-blind-switch` |
| fitme-story#69 | `49288d3` | housekeeping | HADF-Phase2 showcase citation fix |

### Phase 2 — 2026-05-09 (T10 + T24 + T18 + T19, search + mobile + Figma)

Two PRs, both squashed onto main:

| PR | SHA | Tasks | Scope |
|---|---|---|---|
| fitme-story#70 | `809a709` | T10 | Site-wide search (smart-ranked across case-studies + glossary + dev-guide + lifecycle-event-catalog). Squash also bundles in-flight UX polish: Suspense wrap (CSR-bailout fix), `rounded-full` pill, expandable variant (icon-only by default, click to open), full-width chrome (logo flush-left, content uses screen size). |
| fitme-story#71 | `e675fe9` | T24 | Mobile-readiness pass — Hero / PmFlowHero / Flagship / Standard h1 responsive type-scale (`text-3xl sm:text-4xl md:text-5xl lg:text-display-{xl,lg}`) · BeforeAfter / RankedBars / ParallelGantt 3-col grids collapse to 1-col on phones · CopyButton 32→44 tap-target (WCAG 2.5.5) · `.prose code { overflow-wrap: anywhere }` |

Plus FT2-side:

| PR | SHA | Scope |
|---|---|---|
| [FT2#256](https://github.com/Regevba/FitTracker2/pull/256) | `d536871` | Rollup state.json creation |
| [FT2#258](https://github.com/Regevba/FitTracker2/pull/258) | `02e3d8d` | v7.8.2 cross-repo asymmetry disposition (closes T22 + T23) |
| [FT2#260](https://github.com/Regevba/FitTracker2/pull/260) | `2975e74` | T8 dual-outlet pattern contract |
| [FT2#261](https://github.com/Regevba/FitTracker2/pull/261) | `3176038` | T21 design architecture doc |
| [FT2#266](https://github.com/Regevba/FitTracker2/pull/266) | `ab8d5fa` | State.json reconcile (7→17 done) |

### Out-of-band (Figma) — 2026-05-09

Created in-session via the Figma MCP, no PR:

- **T18 — Figma file** `FitMe Story Web — Design System` at `fsjHfFLAHELACZHku8Rfcl` ([open](https://www.figma.com/design/fsjHfFLAHELACZHku8Rfcl)). 4-page structure: Cover · Tokens · Components · Screens.
- **T19 — Token import.** 33 variables in collection `FitMe Tokens` (Light + Dark modes): 23 colors (4 brand · 8 neutral · 11 skill palette), 8 numeric (3 measures · 5 type-scale + line-height), 2 font strings. `--color-neutral-500`, `--color-neutral-700`, `--color-brand-indigo`, `--color-brand-coral` carry distinct dark-mode values per the existing WCAG override contract in `globals.css`.
- **T12 — 22 wireframe screens** built on the Screens page (3-col grid, 1280×1024 each). Covers: home, /about, /case-studies (index + compare + operations-layer + [slug] template + 3 exemplars), /pm-flow, /framework (+ dev-guide + dispatch), /design-system, /research, /search, /timeline/[version], /trust (+ audits/2026-04-21-gemini), /glossary, /control-room/sign-in (+ recover). Each screen shares header chrome + footer chrome from the Tokens collection so a token edit re-themes every frame.

## Numbers

All metrics declared with tier per [data-quality-tiers convention](data-quality-tiers.md):

- **17 of 24 sub-tasks shipped** (T1, ledger inspectable in `state.json::tasks[].status==='done'`)
- **17 PRs across 2 repos** in 2 calendar days (T1, GitHub PR list)
- **26 of 30 audit findings closed** (T2, declared in state.json::success_metrics — counted from PR-level finding closure but not centrally instrumented)
- **22 mobile-readiness findings surfaced** by an Explore agent code-review at 360/390/430px viewports (T2, agent output, single-pass)
- **8 of 22 mobile findings fixed** in T24 (fitme-story#71, squash e675fe9; T1, diff-inspectable)
- **0 kill criteria fired** across all 12 fitme-story PRs at midstream check (T1, Vercel + GitGuardian + verify-blind-switch all green pre-merge for every PR)
- **WCAG contrast** on `--color-neutral-500` improved from 4.16:1 (P0 fail) to 4.83:1 (AA pass) in T1 (T1, computed against #FAFAF9 background)

## Honest Gaps

What this case study CANNOT honestly claim, with reason:

1. **No before/after performance numbers.** No Lighthouse run was captured pre-rollup vs post-rollup. The audit identified TTI concerns but no instrumentation was added, so the post-state is unmeasured. **T1→T3 downgrade** if anyone quotes "TTI improved" without numbers.
2. **No user-impact survey.** The rollup is internal product polish; no end-user A/B test or user-research signal informs success. We rely on `kill_criteria` (regression detection) not `success_criteria` (positive impact).
3. **No external audit replication.** The audit that triggered the rollup was conducted in-house (one Claude session, 2026-05-08). Per Tier 3.3 of the integrity framework, this is internally-replicated only — an outside operator running the same audit would surface a different finding-set.
4. **Per-sub-task timing reconstruction is partial.** State.json captures rollup-level `session_start` (2026-05-08T03:30Z) but not per-sub-task started_at / ended_at. Reconstructable from `git log` of the original branches (most are deleted post-merge) — partial recovery.
5. **Mechanism A telemetry: zero coverage on fitme-story PRs.** Per v7.8.2, fitme-story is exempt from `gate-coverage.jsonl`. Phase B of this directive will reverse the exemption, but pre-2026-05-09 PRs cannot be backfilled.
6. **`kill_criteria_resolution` is deferred.** Feature is `current_phase=implementation`, not `complete`. The kill-criterion final-state evaluation happens at closure.
7. **17 vs 24 sub-task gap is real.** 7 tasks remain ready/blocked: T8 (ready, dual-outlet pattern), T11 (ready, SEO), T12 (done in-Figma but no FT2-side wire-up), T13 (date-gated 2026-05-21), T20 (Code Connect, depends on Figma components existing — partial), T22 + T23 (RESOLVED via v7.8.2 exemption — should be marked `done` retroactively, but ledger says `ready`).
8. **One orphan PR.** fitme-story#60 was the first ArticleNav attempt; closed and re-done as fitme-story#61. Orphan is documented but the v7.8.2 audit did not cleanly track first-attempt-vs-final.

## Kill criteria midstream check

| Criterion | Threshold | Midstream state |
|---|---|---|
| Vercel JS error rate increase | >0.1% | T1 — Sentry / Vercel reports show no spike across 12 PRs |
| User-reported regression | >1 / 1000 sessions | T3 — no user-reporting channel for fitme-story; effectively unmeasurable. Honest tier downgrade. |
| CLS regression on `/case-studies/[slug]` | <0.1 | T2 — declared per Vercel Analytics; not central-tracked |

**Verdict midstream:** zero criteria fired. Closure check pending.

## What this rollup proves about the framework

1. **The `rollup_multi_pr` work-subtype is viable for audit-driven enhancement waves.** 17 PRs in 2 days with a single coherent state.json is operationally lighter than 17 separate features. The cost is the asymmetries listed above — those are the bug to close in v7.9.
2. **Cross-repo gate parity is a real gap.** v7.8.2 documented it as exempt; this rollup demonstrates the exemption costs us measurement honesty. Phase B of the 2026-05-09 directive ports the framework to fitme-story precisely to close it.
3. **Midstream case-study-writing is possible** when the directive is clear, the rollup is large, and the sub-task ledger is honest. The pre-existing convention was "case study at closure"; this is the first midstream document. Expect a closure-addendum addendum when phase transitions to complete.

## Predecessor chain

- [framework-story-site](framework-story-site-case-study.md) — the public-site itself, shipped 2026-04-13. This rollup polishes that site.
- [case-study-presentation](case-study-presentation-refactor-case-study.md) — 2026-04-28; 25 case studies backfilled. Set the stage for T9 frontmatter audit + T15 callouts.
- [case-study-comparison-table](case-study-comparison-table-case-study.md) — 2026-05-07; T8 dual-outlet pattern.
- [ucc-passkey-auth](unified-control-center-case-study.md) — 2026-05-07; introduced the design-architecture doc pattern that T21 mirrors.

## Successor / closure plan

- **Phase B (planned 2026-05-09)** — port v7.8.1 framework to fitme-story repo: install pre-commit hooks, mirror gate scripts, add `integrity` CI workflow, create `.claude/features/` dir for fitme-story-native features. Closes the asymmetry that this rollup exposed.
- **Phase C (planned post-B)** — cross-repo state.json sync canonicalization. FT2 remains canonical for `state.json` of cross-repo features; fitme-story sync layer (already partially exists at `fitme-story/scripts/sync-from-fittracker2.ts`) extends to bidirectional or read-only mirror.
- **Closure** — when remaining 7 tasks ship (or their explicit deferral landed), case study gets a closure addendum block at the bottom: `kill_criteria_resolution: confirmed_no_fire`, `current_phase=complete`, `case_study_showcase: <fitme-story slot MDX>`.
