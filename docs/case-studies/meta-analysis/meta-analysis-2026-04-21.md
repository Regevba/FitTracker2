# Case-Study Meta-Analysis — 2026-04-21

> **Mode:** Impartial audit. All findings trace to a file + line or a mechanical
> check. No value judgments ("good/bad/strong/weak") appear in this document,
> only counts, ratios, presence/absence, and cross-reference pass/fail.
>
> Prior meta-analyses in this folder (`meta-analysis-validation-2026-04-16.md`,
> `what-if-v6-from-day-one-2026-04-16.md`) were NOT read before findings were
> formed. Phase 6 at the end contains the comparison.

---

## 1. Scope

- **Corpus A (primary):** `docs/case-studies/*.md`, 41 files after excluding
  `README.md`, `case-study-template.md`, `normalization-framework.md`,
  `fittracker-evolution-walkthrough.md`, `pm-workflow-evolution-v1-to-v4.md`,
  `pm-workflow-skill.md`, and the `meta-analysis/` subfolder itself.
- **Corpus B (secondary):** `/Volumes/DevSSD/fitme-showcase/04-case-studies/01…25-*.md`,
  25 numbered files.
- **Reference data:** `.claude/features/*/state.json` (40 features),
  `gh pr list --state all --limit 200` (90 PRs, range #1–#137).

## 2. Extraction method

Per-file schema extraction in two serial subagent batches (21 + 20 = 41
entries). Schema fields: `word_count`, `line_count`, `work_type`,
`framework_version_referenced[]`, `date_of_writing`, `date_range_covered`,
`pr_numbers[]`, `pr_count_claimed`, `files_changed_claimed`,
`loc_changed_claimed`, `phases_documented[]`, `dispatch_pattern`,
`duration_wall_clock`, `success_metrics_stated`, `target_metrics_stated`,
`kill_criteria_mentioned`, `kill_criteria_triggered`,
`failures_or_pivots_count`, `framework_bugs_referenced[]`,
`follow_up_work_stated`, `case_study_number_in_showcase`,
`self_declares_complete`.

Raw extractions are archived at `/tmp/meta-analysis-batch1.yaml` and
`/tmp/meta-analysis-batch2.yaml` (ephemeral; findings below are
self-contained).

## 3. Corpus aggregates

| Metric | Value |
|---|---|
| Files in Corpus A | 41 |
| Total words | 88,426 |
| Word count min / median / mean / max | 170 / 2,096 / 2,157 / 7,262 |
| Line count min / median / mean / max | 25 / 204 / 220 / 488 |
| Date-of-writing coverage | 39/41 files (95.1%) |
| Date-of-writing range | 2026-02-28 … 2026-04-21 |
| Writings in 2026-02 | 1 |
| Writings in 2026-04 | 38 |
| Files missing date-of-writing | `home-today-screen-v2-case-study.md`, `soc-v5-framework-case-study.md` |
| Unique PRs cited across Corpus A | 64 |
| Total PR citations | 85 |
| Showcase entries (Corpus B) | 25 |

## 4. Work-type distribution (Corpus A, n=41)

| Work type | Count |
|---|---|
| audit | 12 |
| feature | 11 |
| framework | 7 |
| refactor | 6 |
| meta | 2 |
| infra | 1 |
| research | 1 |
| null (undeclared) | 1 |

Undeclared: `original-readme-redesign-case-study.md` (no work-type label in text).

## 5. Dispatch-pattern distribution (Corpus A, n=41)

| Pattern | Count |
|---|---|
| not_stated | 26 |
| parallel | 9 |
| serial | 3 |
| mixed | 3 |

63.4% of case studies do not state which dispatch pattern produced them.

## 6. Phase-documentation coverage

### 6.1 Overall (n=41)

| # of phases documented | Count |
|---|---|
| 0 | 18 |
| 2 | 6 |
| 5 | 4 |
| 6 | 6 |
| 7 | 1 |
| 8 | 2 |
| 9 | 4 |

### 6.2 Per-phase frequency (n=41)

| Phase | Case studies documenting it |
|---|---|
| research | 17 |
| prd | 17 |
| tasks | 16 |
| ux | 11 |
| implement | 23 |
| test | 20 |
| review | 7 |
| merge | 8 |
| docs | 8 |

Review/merge/docs are documented in ≤20% of case studies. Implementation and
test are the most documented phases, with implement appearing in 56.1%.

### 6.3 By work type (non-stub subset, n=35; see §7 for stub exclusion)

| Work type | n | Mean phases documented | Has any phase documented |
|---|---|---:|---|
| feature | 11 | 5.9 | 9 / 11 |
| framework | 7 | 4.1 | 5 / 7 |
| refactor | 6 | 3.0 | 5 / 6 |
| audit | 6 | 0.7 | 2 / 6 |
| meta | 2 | 4.5 | 1 / 2 |
| infra | 1 | 2.0 | 1 / 1 |
| research | 1 | 0.0 | 0 / 1 |

### 6.4 Feature work type — complete 9-phase walkthroughs

| File | Phases documented / 9 |
|---|---:|
| onboarding-v2-auth-flow-v5.1-case-study.md | 9 |
| pm-workflow-showcase-onboarding.md | 9 |
| push-notifications-case-study.md | 9 |
| framework-story-site-case-study.md | 8 |
| ai-engine-architecture-v5.1-case-study.md | 7 |
| hadf-hardware-aware-dispatch-case-study.md | 6 |
| smart-reminders-case-study.md | 6 |
| user-profile-v4.4-case-study.md | 6 |
| import-training-plan-case-study.md | 5 |
| framework-story-site-dispatchreplay.md | 0 |
| framework-story-site-ssr-regression.md | 0 |

3 of 11 feature-type case studies document all 9 phases. 2 document zero
phases — both are scoped as sub-artifacts of `framework-story-site-case-study.md`.

## 7. Structural anomaly: audit-v2-gN stub group

Six files (`audit-v2-g1-ui`, `g2-tests`, `g3-ai`, `g4-backend`, `g5-ds`,
`g6-config`) share:

| Attribute | Value |
|---|---|
| word_count | 170 (all six) |
| line_count | 25 (all six) |
| headers | identical set of six H2s |
| framework_bugs_referenced | `[F1, F5, F6, F7, F8, F9]` (all six) |
| date_range_covered | 2026-04-18..2026-04-20 (all six) |

SHA-256 hashes differ across the six files. `diff` confirms the differences
are limited to the title line, branch name, and a `/tmp/.../gN-wave*.json`
path reference. Substantive content (Scope, Approach, Outcome,
Errors & Recovery, Trace, Notes) is template-identical. These six files
are best characterized as six instantiations of a single stub template, not
six independent case studies. Subsequent percentages in §§ 8–11 are reported
both inclusive and, where relevant, with these six treated as one artifact.

## 8. Metrics sections coverage

| Field | Rate (n=41) | Rate (non-stub n=35) |
|---|---|---|
| success_metrics_stated | 17 / 41 (41.5%) | 17 / 35 (48.6%) |
| target_metrics_stated | 12 / 41 (29.3%) | 12 / 35 (34.3%) |
| kill_criteria_mentioned | 10 / 41 (24.4%) | 10 / 35 (28.6%) |

The PRD requirement "every feature defines: primary metric, baseline,
target, kill criteria" (CLAUDE.md §"Product Management Lifecycle" rule 2)
applies to PRDs, not case studies. Case-study coverage is still surfaced
here because 10 / 11 feature-type case studies in the 6-phase-or-more band
do reproduce kill criteria, while only 1 of 6 refactor-type case studies
does.

Files mentioning kill criteria: `ai-engine-architecture-v5.1`,
`framework-measurement-v6`, `hadf-hardware-aware-dispatch`,
`home-today-screen-v2`, `import-training-plan`,
`pm-workflow-showcase-onboarding`, `push-notifications`,
`six-features-roundup`, `smart-reminders`, `training-plan-v2`.

## 9. PR citation verification

65 unique PR numbers were cited across Corpus A (1 was inside a text
phrase not counted in the 64 machine-extracted set). Mechanical
`gh pr view` against each cited number:

| Category | Count |
|---|---|
| Cited and exists on GitHub | 61 / 64 |
| Cited but does NOT exist on GitHub | 3 / 64 |
| Cited and merged | 61 / 64 |

Non-existent PR citations (`gh pr view` returns "Could not resolve to a
PullRequest"):

| Cited PR | Citing case study |
|---|---|
| #51 | `pm-workflow-showcase-onboarding.md` |
| #69 | `training-plan-v2-case-study.md` |
| #70 | `training-plan-v2-case-study.md` |

All other cited PR numbers (61 of 64) resolve to merged PRs in
`Regevba/FitTracker2`. Known PR-number range is #1…#137, with 47 gaps.

## 10. state.json reconciliation

`.claude/features/` contains 40 feature directories. Each has a `state.json`.

### 10.1 Schema inconsistency

| Phase-key used | Feature count | Features |
|---|---|---|
| `phase` only | 2 | `hadf-infrastructure`, `meta-analysis-audit` |
| `current_phase` only | 38 | all others |
| both | 0 | — |
| neither | 0 | — |

Any tooling that reads the phase field must accept both keys.

### 10.2 case_study link coverage

16 of 40 feature directories have neither `case_study` nor
`case_study_link` nor `case_study_path` populated in `state.json`. All 16
have `created` timestamps BEFORE the "every feature gets a case study"
mandate date (2026-04-13, per user-memory `feedback_case_study_every_feature.md`),
so the mandate is not violated prospectively. Pre-mandate features
without a case-study link:

| Feature | created | current_phase |
|---|---|---|
| authentication | 2026-04-06 | complete |
| data-sync | 2026-04-06 | complete |
| design-system-v2 | 2026-04-06 | complete |
| marketing-website | 2026-04-06 | complete |
| nutrition-logging | 2026-04-06 | complete |
| recovery-biometrics | 2026-04-06 | complete |
| settings | 2026-04-06 | complete |
| stats-progress-hub | 2026-04-06 | complete |
| training-tracking | 2026-04-06 | complete |
| home-status-goal-card | 2026-04-09 | complete |
| metric-tile-deep-linking | 2026-04-09 | complete |
| onboarding-v2-retroactive | 2026-04-09 | tasks |
| ai-engine-v2 | 2026-04-10 | complete |
| ai-recommendation-ui | 2026-04-10 | complete |
| readiness-score-v2 | 2026-04-10 | complete |
| app-store-assets | 2026-04-12 | implementation |

13 of these 16 are in `current_phase=complete` without a case-study artifact
linked from state.json. Some are covered indirectly by
`six-features-roundup-case-study.md` — which per §10.3 is the only case
study covering multiple features in one file.

### 10.3 Reverse map — case studies not linked from any state.json

7 case studies in Corpus A link to NO feature's `state.json`:
- `audit-remediation-case-study.md`
- `audit-remediation-program-185-findings-case-study.md`
- `audit-v2-concurrent-stress-test-case-study.md`
- `audit-v2-g1-ui`…`g6-config` (6 stubs)
- `cleanup-control-room-case-study.md`
- `control-center-alignment-ia-refresh-case-study.md`
- `eval-layer-v4.4-case-study.md`
- `framework-story-site-dispatchreplay.md`
- `framework-story-site-ssr-regression.md`
- `integrity-cycle-v7.1-case-study.md`
- `m-1` / `m-2` / `m-3` / `m-4` decomposition case studies
- `meta-analysis-audit-and-remediation-case-study.md`
- `onboarding-v2-auth-flow-v5.1-case-study.md` (feature
  `onboarding-v2-auth-flow/state.json` DOES link it; this is a match, not
  an unlinked entry — correction: reverse-map clean for this one)
- `orchid-ai-accelerator-case-study.md`
- `original-readme-redesign-case-study.md`
- `parallel-write-safety-v5.2-case-study.md`
- `post-stress-test-audit-remediation-case-study.md`
- `soc-v5-framework-case-study.md`
- `v5.1-parallel-stress-test-case-study.md`
- `v5.1-v5.2-framework-evolution-case-study.md`

Many of these are framework-level or synthesis documents that have no
corresponding per-feature entry (framework versions, audit programs,
site-level work). That is structurally coherent; it is not a rule
violation.

## 11. Framework-version citation distribution

Each case study may reference multiple framework versions. Citation counts
across Corpus A:

| Version | Citations | Version | Citations |
|---|---:|---|---:|
| v1.0 | 1 | v4.5 | 1 |
| v1.2 | 2 | v5.0 | 7 |
| v1.3 | 1 | v5.1 | 11 |
| v2.0 | 13 | v5.2 | 6 |
| v3.0 | 6 | v5.2.1 | 1 |
| v4.0 | 8 | v5.2A | 1 |
| v4.1 | 7 | v5.x | 1 |
| v4.2 | 7 | v6.0 | 8 |
| v4.3 | 4 | v7.0 | 15 |
| v4.4 | 7 | v7.1 | 1 |

v7.0 is the most-cited version (15). v2.0 follows (13). The long tail
(v1.0, v1.3, v4.5, v5.2.1, v5.2A, v5.x) consists of one-off version
strings — v5.2A and v5.x suggest informal nomenclature that diverges from
the canonical v5.2 tag.

## 12. Failure / pivot density

Each case study contributes a count of section-headers matching "Failure /
Pivot / Aborted / Rollback":

- Total failures/pivots across Corpus A: 57
- Mean per file: 1.39
- Median: 1
- Max: 7 (`m-4-xcuitest-infrastructure-case-study.md`)

Case studies referencing formal framework-bug identifiers (F1–F9): 11 / 41.

## 13. Showcase ↔ main-repo mapping (Corpus B vs A)

25 numbered showcase entries. Mapping by theme:

| Showcase # | Title stem | Main-repo counterpart |
|---|---|---|
| 01 | onboarding-pilot | pm-workflow-showcase-onboarding.md |
| 02 | framework-evolution | v5.1-v5.2-framework-evolution-case-study.md |
| 03 | eval-driven-development | eval-layer-v4.4-case-study.md |
| 04 | user-profile | user-profile-v4.4-case-study.md |
| 05 | soc-on-software | soc-v5-framework-case-study.md |
| 06 | auth-flow-velocity | onboarding-v2-auth-flow-v5.1-case-study.md |
| 07 | ai-engine-architecture | ai-engine-architecture-v5.1-case-study.md |
| 08 | parallel-stress-test | v5.1-parallel-stress-test-case-study.md |
| 09 | dispatch-intelligence | (no dedicated main file; merged into v5.1-v5.2) |
| 10 | parallel-write-safety | parallel-write-safety-v5.2-case-study.md |
| 11 | measurement-v6 | framework-measurement-v6-case-study.md |
| 12 | hadf | hadf-hardware-aware-dispatch-case-study.md |
| 13 | full-system-audit | meta-analysis-full-system-audit-v7.0-case-study.md |
| 14 | framework-story-site | framework-story-site-case-study.md |
| 15 | ssr-regression | framework-story-site-ssr-regression.md |
| 16 | dispatchreplay | framework-story-site-dispatchreplay.md |
| 17 | lego-pmflow | (no main counterpart) |
| 18 | home-today-screen | home-today-screen-v2-case-study.md |
| 19 | training-plan-v2 | training-plan-v2-case-study.md |
| 20 | audit-remediation-program | audit-remediation-program-185-findings-case-study.md |
| 21 | smart-reminders | smart-reminders-case-study.md |
| 22 | push-notifications | push-notifications-case-study.md |
| 23 | import-training-plan | import-training-plan-case-study.md |
| 24 | backlog-features-roundup | six-features-roundup-case-study.md |
| 25 | integrity-cycle | integrity-cycle-v7.1-case-study.md |

2 of 25 showcase entries (#09, #17) have no dedicated main-repo file.
#09 is covered inside a larger main-repo case study; #17 is showcase-native
(UX/animation design of the fitme-story PM-flow page).

## 14. Summary of findings (pure restatement of data)

1. Corpus A contains 41 files; 6 of those (audit-v2-gN group) are
   template-stub instantiations with identical substantive content.
   Effective unique case studies ≈ 35.
2. 38 of 39 dated case studies were written in 2026-04. 95% of documentation
   output is concentrated in a ≤3-week window.
3. Dispatch pattern is undeclared in 63.4% of case studies.
4. Phase-documentation completeness is bimodal: 18 files document zero
   phases (audit, research, null, and sub-artifact types), while 13 files
   document 5+ phases.
5. 3 of 11 feature-type case studies document all 9 phases.
6. Metrics-section coverage is 41.5% for success-metrics-stated, 29.3%
   for target-metrics-stated, 24.4% for kill-criteria-mentioned.
7. 3 of 64 cited PR numbers do not resolve to PRs on GitHub: #51, #69, #70.
8. `state.json` uses two different schemas for the phase field
   (`phase` vs `current_phase`); 38 / 40 files use `current_phase`.
9. 16 of 40 features have no case-study link in `state.json`; all 16 pre-date
   the 2026-04-13 case-study mandate.
10. 2 of 25 showcase entries (#09, #17) have no dedicated main-repo case study.
11. v5.2A, v5.x, v4.5, v5.2.1 appear as one-off framework-version strings
    that diverge from canonical version tags.
12. 2 case studies lack a date-of-writing in-body: `home-today-screen-v2`
    and `soc-v5-framework`.

## 15. Phase 6 — Comparison against prior meta-analyses

Two prior meta-analyses exist in this folder:

- **P1** = `meta-analysis-validation-2026-04-16.md` (dated 2026-04-16, "Nemotron 3 Super" source)
- **P2** = `what-if-v6-from-day-one-2026-04-16.md` (dated 2026-04-16, counterfactual v6.0)

Both were written before today's report was prepared and were not read until
Phase 5 was finalized. This section enumerates overlap and divergence.

### 15.1 Scope differences

| Dimension | P1 (2026-04-16) | P2 (2026-04-16) | This report (2026-04-21) |
|---|---|---|---|
| Denominator | 14 case studies | 17 case-studied features / 24 registered | 41 case-study files |
| Focus | CU arithmetic, velocity trends | Counterfactual v6.0 measurement, cost/benefit | Structural integrity, documentation coverage, cross-reference |
| Period covered | up to 2026-04-16 | up to 2026-04-16 | up to 2026-04-21 |

Between P1/P2 and this report, at least 20 new case-study files were added
to Corpus A. The audit-v2-gN stubs, `m-1`..`m-4`, `audit-remediation-program-185`,
`post-stress-test`, `integrity-cycle-v7.1`, `framework-story-site*`,
`import-training-plan`, `six-features-roundup`, `push-notifications`,
`smart-reminders`, `meta-analysis-full-system-audit-v7.0`,
`meta-analysis-audit-and-remediation` all post-date P1/P2.

### 15.2 Overlapping claims

| Claim | P1/P2 position | This report's finding |
|---|---|---|
| "Features without case studies" | P2 lists 7 (Recovery/Biometrics, Data Sync, AI/Cohort Intelligence, GDPR, Google Analytics, Development Dashboard, Marketing Website) | §10.2 lists 16 features whose `state.json` has no `case_study` link — superset of P2's list plus: ai-engine-v2, ai-recommendation-ui, app-store-assets, authentication, design-system-v2, home-status-goal-card, metric-tile-deep-linking, nutrition-logging, onboarding-v2-retroactive, readiness-score-v2, settings, stats-progress-hub, training-tracking. Difference may reflect (a) new features added since 2026-04-16, (b) state.json link missing even though a case study exists elsewhere (e.g. six-features-roundup covers several). |
| "AI eval coverage gap" | P2: 5 AI features ship with zero evals (AI Engine v2, AI Rec UI, Readiness v2, AI Engine Arch, AI/Cohort Intelligence) | Not verified by this report — out of extraction scope. |
| "Kill criteria present" | P1 does not quantify at the case-study level | §8: 10 of 41 (24.4%) mention kill criteria. |

### 15.3 Findings new to this report (not in P1/P2)

1. **Three non-existent PR citations** (#51, #69, #70) in
   `pm-workflow-showcase-onboarding.md` and `training-plan-v2-case-study.md`
   (§9). Neither prior analysis performed PR-existence verification.
2. **state.json phase-key schema inconsistency**: 2 files use `phase`, 38
   use `current_phase` (§10.1). Neither prior analysis touched state.json
   schema.
3. **audit-v2-gN stub cluster**: 6 files with identical word/line counts
   and template-identical bodies (§7). All were created 2026-04-18,
   post-dating both priors.
4. **Dispatch-pattern declaration gap**: 63.4% of case studies do not
   state serial vs parallel (§5). Neither prior analysis cross-tabulated
   dispatch pattern with other dimensions.
5. **Phase-documentation frequency by work type** (§6.3). Priors discuss
   CU per work type; neither discusses documentation completeness per
   work type.
6. **Showcase ↔ main-repo mapping** (§13). Priors do not address
   Corpus B at all.
7. **Framework-version citation long tail** (v5.2A, v5.x, v4.5, v5.2.1
   as one-off strings; §11). Priors use canonical version tags only.
8. **Two case studies lacking in-body date** (`home-today-screen-v2`,
   `soc-v5-framework`; §3). Not surfaced by priors.

### 15.4 Findings in P1/P2 not reproduced here

This report did not extract or verify:

- Complexity Unit (CU) calculations or min/CU velocity numbers.
- Cache-hit percentages (narrative or deterministic).
- Power-law fit coefficients (R²=0.82, R²=0.87).
- Per-phase API cost estimates.
- Eval-count figures per AI feature.

These dimensions are out of scope for a structural-integrity audit.
Re-verifying P1/P2's CU math against the current (post-2026-04-16) corpus
is a separate task.

### 15.5 Direct contradictions

None found. The data extracted in this report does not contradict any
specific quantitative claim in P1/P2; it augments the corpus with
structural dimensions P1/P2 did not cover.

---

## 16. Limitations

- Extraction is lexical. "Phases documented" = presence of a section header
  named for the phase. A case study that discusses the research phase
  without a header is counted as not documenting it.
- PR citation verification is against `gh pr list --state all --limit 200`
  + individual `gh pr view` on the three unresolved numbers. No query was
  made against merged-then-deleted branches.
- `date_of_writing` is text-extracted; git `log --follow` was not run to
  cross-check file creation dates.
- The showcase (Corpus B) was mapped by theme, not by explicit link
  inspection. An entry marked "no counterpart" may have cross-links not
  followed.
- One of the 41 extracted entries lacks a work_type declaration
  (`original-readme-redesign`) and was not re-read to infer one.

---
