---
title: "Case-Study Presentation Refactor (Alternative A)"
slug: case-study-presentation-refactor
date_written: 2026-04-28
ship_date: 2026-04-28
work_type: feature
dispatch_pattern: serial
framework_version: v7.7
status: shipped
trigger: "v7.7 review surfaced 47+ case studies trending toward dense, paragraph-heavy formats — readability degraded faster than content quality"

tldr: "An 18-hour serial sprint locked a uniform presentation pattern across 25 case studies — every one now leads with a SummaryCard, a 'how to read this' panel, a per-case visual aid, a kill-criterion banner, and a Deferred-items list — enforced at build time so a reader can grasp any case study in under sixty seconds without losing the long-form narrative."

key_numbers:
  - label: "Case studies backfilled"
    value: "25 of 25"
    tier: T1
  - label: "MDX files passing the new validator"
    value: "51 of 51"
    tier: T1
  - label: "Demo-route lines deleted on cleanup"
    value: "1284"
    tier: T1

honest_disclosures:
  - "An over-broad refine in the build-time validator initially demanded `visual_aid` on every MDX file in `content/`, including READMEs and design-system docs that use `tier: unassigned`. The validator went from 26 failures to 0 only after a one-line schema fix to bypass the rule for non-case-study tiers."
  - "FitTracker2 CI could not run during the merge window — the GitHub Actions account hit a payment block and both `Build and Test` and `integrity` checks were rejected at queue time, not failed on content. The PR was merged via admin override after fitme-story PR landed clean. The 72h integrity cycle remains the belt for any drift the bypassed gate would have caught."
  - "The FitTracker2 branch name `feature/case-study-presentation` had previously been reused for an unrelated dashboard schema-drift fix (commit a53d10b). That commit was preserved on `fix/dashboard-feature-key-v7-7` and is NOT part of this feature; the collision was resolved by tracking origin's branch and discarding the stale local."
  - "Visual-aid selection across the 25 backfilled case studies skews toward `BeforeAfter` (5×) and `DurationStack` (3×). Three appendix studies (meta-analysis ×2 + normalization-model) fall back to `KeyNumbersChart` because the numbers themselves are the visual; per the catalog rule they are flagged for a future visual-review pass."
  - "Pre-v6.0 case studies (slots 01, 03–08) intentionally omit `kill_criteria` from their backfilled frontmatter. The kill-criterion convention did not exist before v6.0; inventing them post-hoc would violate the impartiality rule. They keep `tldr` + `key_numbers` + `honest_disclosures` + `visual_aid` only."

success_metrics:
  primary: "100% of timeline + appendix case studies (25 of 25) carry the locked Alt-A frontmatter and render the chrome above the narrative."
  secondary:
    - "Build-time validator (`fitme-story/scripts/validate-frontmatter.ts`) refuses any new case study missing `tldr` or missing both `visual_aid` and `key_numbers` — passing today on 51 of 51 MDX files."
    - "Visual-aid catalog (17 components + KeyNumbersChart fallback) and Alt-A worked-example template documented at canonical FitTracker2 paths (`docs/design-system/case-study-visual-aid-catalog.md`, `docs/case-studies/templates/alternative-a-v7-5-example.md`) and cross-linked from fitme-story content schema."
    - "PM-workflow tracking artifacts (state.json + log) created so the feature is visible to the dashboard, the 72h integrity cycle, and the documentation-debt ledger."

kill_criteria:
  - "Frontmatter validator false-positive rate exceeds 5% on legitimate frontmatter in week-1 dogfooding (would force the gate to be disabled or weakened)."
  - "Reader 60-second comprehension test fails on 3+ of 5 randomly sampled case studies (SummaryCard not doing its job)."
  - "Case-study route first-paint regresses more than 100ms after chrome rollout (chrome too heavy)."

kill_criterion_fired: false

deferred_items:
  - title: "Per-case visual review for KeyNumbersChart fallbacks"
    ledger: "docs/product/backlog.md (Refine case-study presentation/readability)"
    reason: "Three appendix studies fell back to the auto-rendered chart; a follow-up pass should pick a specialised component for each."
  - title: "Cross-case-study comparison table"
    ledger: "docs/product/backlog.md (Refine case-study presentation/readability — goal 2)"
    reason: "Auto-generated from frontmatter, not part of the chrome rollout. Backlog item; build after the corpus settles."
  - title: "Audit of v2.0–v7.0 timeline studies for the same readability standard"
    ledger: "docs/product/backlog.md (Refine case-study presentation/readability — goal 5)"
    reason: "Older studies are inconsistent in tone and structure; uniform presentation does not retroactively fix uneven prose. Editorial pass deferred."

visual_aid:
  component: BeforeAfter
  data:
    beforeLabel: "before lock"
    before:
      label: "before lock"
      value: "47+ case studies"
      subtitle: "Inconsistent frontmatter, no enforced visual aid, dense Section-99 syntheses, no top-of-page summary, multiple silently-different markdown renderers across cases."
    afterLabel: "after lock"
    after:
      label: "after lock"
      value: "25 with chrome + 51/51 validator pass"
      subtitle: "SummaryCard → DataKey → visual aid → KillCriterionBanner → DeferredItemsList → body, in that order, on every case study; build-time refuse for non-conforming new content."
    delta: "uniform presentation locked + enforced"
---

# Case-Study Presentation Refactor (Alternative A)

## 1. Why this case study exists

By 2026-04-28 the corpus had grown to 47+ case studies. The content was solid — every framework version had its own narrative, every multi-PR sprint had its own retrospective, every audit had its own remediation report — but the *presentation* had drifted. Three problems compounded:

1. **Frontmatter shape varied.** Some studies had a `tldr`. Some had a `kill_criteria` block. Some had T1/T2/T3 tier tags on quantitative claims; others had bare numbers. There was no single header anyone could land on and read in under a minute.
2. **Markdown rendering was silently different across cases.** Tables rendered as raw pipe-text in a few cases because `compileMDX` was not wired to `remark-gfm`. The reader saw broken pipes; the author saw a perfectly-formed table in their editor.
3. **Visual aids were optional.** Some case studies had a graph. Most did not. When they existed they were one-offs without a catalog, so a reader could not tell whether "no graph here" meant "the data does not support one" or "the author ran out of time."

The fix had to do three things at once: lock a uniform header, wire markdown rendering correctly site-wide, and require a visual aid on every case study with editorial selection of *which* aid serves *that* case best. Anything less would rebuild the same drift inside a year.

## 2. The locked decision

After exploring two alternatives — Alternative A (Web-First Card + Disclosure Tail) and Alternative B (Anthology + Card Quote, a bigger information-architecture shift) — Alternative A was locked on 2026-04-28. The deciding factor was migration cost: Alt-A required adding ~6 frontmatter fields per case study and a small chrome component bundle, with the body text untouched. Alt-B would have rewritten case-study URLs and forced editorial work on every legacy case.

The locked component order is:

1. **SummaryCard** — TL;DR + 5 frontmatter fields + 3 inline honest disclosures
2. **DataKey** — collapsed "How to read this" panel (T1/T2/T3 tier badges, ledger, kill criterion, Deferred semantics)
3. **VisualAidResolver** — renders the named `visual_aid.component`, falls back to `KeyNumbersChart` when only `key_numbers[]` is provided
4. **KillCriterionBanner** — emerald (`kill_criterion_fired: false`) or coral (`true`)
5. **DeferredItemsList** — bordered list with ledger + reason per item
6. **Narrative body** — the existing prose, untouched

Locked-design memory: `project_case_study_presentation_locked.md`. Visual-aid catalog: `docs/design-system/case-study-visual-aid-catalog.md`.

## 3. The rollout

Two repositories, four commits each:

**fitme-story `preview/case-study-presentation`** (squash-merged via PR #8 as commit `ed72514`):

- `9c8fba7` — production chrome (`alt-a-chrome/{VisualAidResolver,index}.tsx`) + Standard / Light / Flagship template wiring
- `af6bc75` — backfill 6 milestone case studies
- `56f6e30` — backfill 14 non-milestone case studies
- `656ed55` — backfill 3 appendix studies + add `scripts/validate-frontmatter.ts`
- `399f0af` — cleanup before merge: drop demo `case-studies-preview/` routes, fix over-broad validator refine, update stale `timeline.test.ts` assertion

**FitTracker2 `feature/case-study-presentation`** (squash-merged via PR #146 as commit `f58ee01`):

- `34dd38b` — preview alt-a visual-aid rule
- `991b5f7` — lock Alt-A + visual-aid rule (Alt-A and Alt-B worked-example templates)
- `38aa5ec` — visual-aid catalog (17 components inventoried)
- `9c0ff5e` — state.json + log so the feature is dashboard / integrity-check / doc-debt visible

The work was serial, single-author, and finished in roughly eighteen wall-clock hours from first preview commit (`2026-04-28T04:09 UTC`) to second merge (`2026-04-28T~22:30 UTC`).

## 4. The visual-aid catalog

A separate companion to the chrome rollout: a 17-component catalog at `docs/design-system/case-study-visual-aid-catalog.md`, with a data-shape → component selection table, anti-patterns (forcing a chart to fit the data, decorative visuals, duplicating the SummaryCard), and an audit rhythm (every case-study merge + every 72h cycle snapshot + every framework version bump).

The catalog identifies one likely-needed gap — `LinearTimeline`, a continuous line chart for "metric over weeks" or "adoption over snapshots" — that would serve the Tier 1.1 + Tier 3.2 trend dashboards once their cron snapshots accumulate. It is not built; the catalog rule is to build a new component only when ≥3 case studies need the same shape and no existing component covers it.

The selection across the 25 backfilled cases (and where the editorial choices fell):

- **`BeforeAfter` ×5** — Capability-matrix or magnitude shifts ("v7.6 → v7.7 gate count", "MealEntrySheet 1104 → 140 lines")
- **`DurationStack` ×3** — Phase wall-times for sprints
- **`HeroMetric`, `RankedBars`, `FlowDiagram`, `PhaseTimingChart`, `BlueprintOverlay` ×2, `ParallelGantt`, `DispatchReplay`, `RaceTimeline`, `PRStackDiagram`, `ChipAffinityMap`, `AuditFunnel`** — one each, picked because the data shape matched the case's primary claim
- **`KeyNumbersChart` fallback ×3** — meta-analysis ×2 + normalization-model. The numbers ARE the visual in those methodology pieces; flagged for a follow-up visual-review pass per the catalog's own rule.

## 5. What broke during the rollout (the honest part)

Two real surprises and one banal one.

**The over-broad validator.** When the build-time validator was added in commit `656ed55`, it walked every `.mdx` file under `content/` and required every one to declare either `visual_aid` or `key_numbers`. The locked rule was always "every *case study* must declare a visual aid", but the schema's refine did not encode that scope — it refined unconditionally. Twenty-six MDX files (READMEs, design-system docs, research notes, all using `tier: unassigned`) failed validation the moment the cleanup commit removed the demo routes and ran the validator end-to-end. The fix was a one-line schema refinement: bypass the visual_aid check when `tier === 'unassigned'`, matching the existing `tldr` bypass. From 26 failures to 51/51 passing.

The lesson is small but worth writing down: when the rule is "every case study must X", the validator must encode "case study", not "every MDX file". Drift between the rule's wording and the validator's scope is exactly the gap the framework's tier system was designed to close, and we walked into it on day one.

**The branch-name collision.** The FitTracker2 branch `feature/case-study-presentation` had a second life as the temporary name for an unrelated dashboard schema-drift fix that landed earlier the same day (commit `a53d10b` locally, `de1770b` on origin's `fix/dashboard-feature-key-v7-7`). When the case-study work resumed on the same branch name, the local repository pointed at the dashboard fix while origin pointed at the catalog. The collision surfaced at branch-checkout time, not at commit time, and was resolved by force-tracking origin and discarding the stale local pointer. The dashboard-fix commit is preserved on its proper branch.

**The CI billing block.** When FitTracker2 PR #146 opened, both `Build and Test` and `integrity` checks were marked failed. The cause was not the content — both jobs were rejected at queue time with the message "recent account payments have failed or your spending limit needs to be increased". The PR was merged via admin override after fitme-story PR #8 landed clean. The 72h integrity cycle continues to run as a belt for anything the gate would have caught. This is the second time in two weeks that an environmental block (last time it was a remote-cache Vercel issue) presented as a CI failure; checking the run-level annotation before reading the diff stays cheap.

## 6. What stays the same

The body of every existing case study is unchanged. The chrome renders above the body; the prose below it reads exactly as it always did. The case-study URLs are unchanged. The reading order is card first, narrative second — the order most readers were already taking implicitly by reading the title + intro + skipping to the conclusion.

Two things that *also* stay the same:

- **The 72h integrity cycle still scans every case study.** Tier-tag presence on post-2026-04-21 case studies, broken PR citations, schema drift, missing case-study links from terminal-phase features — all of those gates fire on the same audit window they did before this rollout. The Alt-A chrome adds a presentation layer; it does not replace any cycle-time check.
- **The forward-only data-quality-tier rule (T1/T2/T3, est. 2026-04-21).** Every quantitative metric in this case study carries a tier label. The chrome's DataKey panel surfaces the convention to readers, but the convention itself was set by the 2026-04-21 Gemini independent audit and is enforced by `scripts/check-case-study-preflight.py`.

## 7. What did not ship in this rollout

Three deferred items, all on the backlog:

1. **Visual-review pass on KeyNumbersChart fallbacks.** Three appendix studies fall back to the auto-rendered chart; the catalog rule is to pick a specialised component for each. Tracked under "Refine case-study presentation/readability" in `docs/product/backlog.md`.
2. **Cross-case-study comparison table.** Auto-generated from frontmatter — every case study at a glance, sortable by version / work_type / kill_criterion_fired / ship_date. Backlog item; will be built once the corpus settles for a few weeks under the new chrome.
3. **Audit of v2.0–v7.0 timeline studies for editorial consistency.** Older studies are inconsistent in tone and structure beyond what frontmatter can fix. A presentation refactor does not retroactively fix uneven prose; the audit pass is a separate piece of work.

## 8. What earned the bump

The rollout did not change the framework version (v7.7 stays v7.7). It did three things that move the trustworthiness of the corpus forward:

- **Build-time refuse for new case studies.** Adding a case study without a `tldr` or without (`visual_aid` OR `key_numbers`) is now mechanically impossible on the path that runs `npm run validate-content`. The 72h cycle backstops the gate.
- **Catalog-driven visual selection.** The 17-component inventory plus the data-shape → component selection table exists; the rule "pick the component whose data shape matches the case's primary claim" is documented and audit-rhythm tracked. Future case studies have a finite, explicit menu to pick from rather than starting blank.
- **Companion repos kept honest.** State.json + log on FT2 makes the feature visible to the dashboard, the doc-debt ledger, and the 72h cycle. The work would have been invisible to all three of those without it; that pattern repeats often enough that documenting it as the closing step of every feature merge is now the default.

## 9. Links

- **Locked-design memory:** `project_case_study_presentation_locked.md` (in conversation memory)
- **Visual-aid catalog:** [`docs/design-system/case-study-visual-aid-catalog.md`](../design-system/case-study-visual-aid-catalog.md)
- **Alt-A worked-example template:** [`docs/case-studies/templates/alternative-a-v7-5-example.md`](templates/alternative-a-v7-5-example.md)
- **Alt-B reference template:** [`docs/case-studies/templates/alternative-b-v7-5-example.md`](templates/alternative-b-v7-5-example.md)
- **fitme-story PR #8** (squash-merged as `ed72514`)
- **FitTracker2 PR #146** (squash-merged as `f58ee01`)
- **State.json:** [`.claude/features/case-study-presentation/state.json`](../../.claude/features/case-study-presentation/state.json)
- **Predecessor:** [`framework-v7-7-validity-closure-case-study.md`](framework-v7-7-validity-closure-case-study.md)
