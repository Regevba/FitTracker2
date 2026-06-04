---
slug: f2-phase-0-reality-check
title: "F2 Phase 0 reality-check — mechanical defense against post-squash-merge state-drift"
date_written: 2026-06-04
framework_version: v7.9.1
work_type: Feature
work_subtype: framework_feature
case_study_type: shipped
tier_tags_required: true
status: shipped
case_study: docs/case-studies/f2-phase-0-reality-check-case-study.md
case_study_showcase: fitme-story/content/04-case-studies/46-f2-phase-0-reality-check.mdx
related_prs:
  - 618
dispatch_pattern: serial
success_metrics:
  - name: scripts_wall_clock_seconds
    baseline: 5.0
    target: 5.0
    significance: descriptive
    review_at: 2026-06-04
    tier: T1
    note: "Empirical: 0.09s for a 14-task feature. Well under PRD <5s budget."
  - name: workflow_integration_callsites
    baseline: 0
    target: 2
    significance: descriptive
    review_at: 2026-06-04
    tier: T1
    note: "Phase 0.1 in /pm-workflow SKILL.md + Makefile target make phase-0-reality-check FEATURE=<name>."
  - name: drift_instances_caught_per_90d
    baseline: 0
    target: 1
    significance: descriptive
    review_at: 2026-09-04
    tier: T2
    note: "Counts post-squash-merge state-drift instances surfaced by Phase 0.1 BEFORE the next Phase 0 scheduled new work. Baseline calibration: 5 drift instances documented 2026-06-01 → 2026-06-04. Target: F2 catches ≥1 of the next 90 days' drift cases before scheduling, validated at the 2026-09-04 quarterly meta-analysis."
kill_criteria:
  - condition: "Script wall-clock >10s — operators will start skipping the step"
  - condition: "False-positive rate >20% during 14-day calibration window — operators tune out the advisories"
  - condition: "Step never catches a real drift case in the next 90 days — discipline is not load-bearing; demote"
kill_criterion_fired: false
kill_criteria_resolution: "K1 (wall-clock) measured at 0.09s on a 14-task feature; well under threshold. K2 + K3 require 14-90d operation to evaluate; reviewed at quarterly audits."
---

# F2 Phase 0 Reality-Check Sub-step — Case Study

> **Status:** Shipped 2026-06-04.
> **Framework version:** v7.9.1 (third v7.9.1 work after F16 + F17, same day).
> **Showcase:** `fitme-story/content/04-case-studies/46-f2-phase-0-reality-check.mdx`.

## TL;DR

`/pm-workflow` Phase 0 gets a new MANDATORY sub-step. Before scheduling work on a feature, the agent cross-checks the feature's `state.json::tasks` list against the last 30 days of git log + merged PR titles + Tier 2.2 log events. If 2+ evidence items hit a pending task's keywords, the advisory "**this task may already be done**" surfaces. Operator decides — never blocking — but the drift gets caught at Phase 0 instead of 3 phases later. Script wall-clock: <0.1s for a 14-task feature.

## Problem

The post-squash-merge state-drift pattern repeated **5 times in 4 days** (2026-06-01 → 2026-06-04): C5 → D1 → C2/C3/C5/C6 batch → trend-alerts-hrv → multiple F16 closure attempts. Each instance:

1. Feature work shipped via squash-merged PR; main has the changes
2. `state.json::tasks` still say `pending` because the operator merged via web UI (which doesn't update state.json) or the workflow used `gh pr merge` (which also doesn't)
3. Next session opens Phase 0 on the same feature; agent reads state.json and sees pending tasks
4. Agent schedules "new work" that is in fact already done
5. Operator catches the drift — usually 2-3 phases later — and runs `make close-feature` to reconcile

The cost is a 3-phase re-plan per drift instance. F1 in the same theme A (`STATE_TASKS_FILESYSTEM_DRIFT` advisory) addresses a similar pattern at the cycle-time gate level. F2 addresses it at the workflow level — catching drift at Phase 0, BEFORE scheduling.

T1 [infra-master-plan §3.1 Theme A F2]: RICE 42.7. Spec was clear: workflow sub-step in `/pm-workflow` reading recent state vs scheduled tasks.

## Approach

Single-script implementation. The cross-check has three input sources:

1. **`git log --since=30 days ago --pretty=format:%H\t%s`** — recent commit subjects
2. **`.cache/gh-pr-cache.json`** — the v7.8.3 D-3 unified PR cache (FT2 + fitme-story, merged + closed + open)
3. **`.claude/logs/<feature>.log.json`** — feature's Tier 2.2 events filtered to the last 30 days

For each pending task, extract keywords from the task description (filtered against a noise-token set including "the", "test", "implement", "framework", etc.). For each source, count items where 2+ distinct keywords appear. If the combined evidence score is ≥2, emit the advisory.

The threshold is intentionally strict: 1 evidence item could be a false-positive (any frequent term coincidentally matches), but 2 items across keyword-heavy task descriptions is high-confidence.

## Decisions log

- **Noise-token filter:** 50+ common English words + framework-specific noise (test/feature/phase/scripts/case-study/v7/v8 etc.). Keeps "BRANCH_ISOLATION_VIOLATION" or "REPO_ROOT_OVERRIDE" or "T4a" as signal, while "Add a test" filters out everything.
- **≥2 keyword hits per item:** for an item to count as an evidence hit, ≥2 distinct keywords must match. Single-keyword matches are silent.
- **≥2 evidence items for advisory:** total across all 3 sources. Combining a single git commit with a single PR title both matching gets the score over the threshold.
- **Never blocking:** Phase 0.1 emits advisories; never aborts the workflow. Operator decides if drift is real.
- **Block phase advancement at SKILL-level:** /pm-workflow refuses to advance Phase 0 if Phase 0.1 has unacknowledged advisories. Acknowledge via `state.json::phase_0_reality_check_acknowledged: ["T3 reviewed"]` array.
- **30-day default window:** matches the typical "drift window" between feature ship + state-drift detection. Operators can extend via `--window-days` / `WINDOW_DAYS=60`.

## Outcomes

| Dimension | Value |
|---|---|
| Producer script | `scripts/phase-0-reality-check.py` (~300 LOC) |
| Test suite | `scripts/tests/test_phase_0_reality_check.py` — **16/16 pass in 0.15s** |
| Wall-clock empirical | 0.09s on a 14-task feature (F16 baseline test) |
| Output | `.claude/shared/phase-0-reality-check.json` + stdout summary |
| Integration | `/pm-workflow` SKILL.md Phase 0.1 section + `make phase-0-reality-check` Makefile target |
| Documentation | CLAUDE.md v7.9.1 F2 section + dev-guide v7.9.1 timeline row + this case study + fitme-story showcase MDX slot 46 |

T1/T2 tier discipline applied throughout. The 0.09s wall-clock + 16-test count are T1 (instrumented via pytest + time). The `drift_instances_caught_per_90d` metric is T2 (declared design intent), validated at the 2026-09-04 quarterly meta-analysis.

## Phase E discipline note

F2 ships during the v7.9.1 build window post-Phase-E exit. The work is workflow-only (one new script + Makefile target + SKILL.md edit) — no gate code, no schema drift, no advisory window required. Branch isolation: all work on `feature/f2-phase-0-reality-check`.

## Cross-references

- **Spec:** [`docs/master-plan/infra-master-plan-2026-05-12.md`](../master-plan/infra-master-plan-2026-05-12.md) §3.1 Theme A F2 (RICE 42.7)
- **Sibling F1:** `STATE_TASKS_FILESYSTEM_DRIFT` advisory (queued; cycle-time defense against the same pattern)
- **Predecessor F16:** [`docs/case-studies/f16-try-repo-harness-case-study.md`](f16-try-repo-harness-case-study.md) (shipped same day)
- **Predecessor F17:** [`docs/case-studies/f17-last-fired-at-index-case-study.md`](f17-last-fired-at-index-case-study.md) (shipped same day)
- **CLAUDE.md discipline:** [`CLAUDE.md`](../../CLAUDE.md) "v7.9.1 F2 — Phase 0 Reality-Check Sub-step"
- **/pm-workflow integration:** [`.claude/skills/pm-workflow/SKILL.md`](../../.claude/skills/pm-workflow/SKILL.md) Phase 0.1 section
- **Linear:** FIT-90
- **Tier 2.2 log:** [`.claude/logs/f2-phase-0-reality-check.log.json`](../../.claude/logs/f2-phase-0-reality-check.log.json)
- **Drift-pattern documentation:** 5 confirmed instances in 2026-06-01 → 2026-06-04 across C5 / D1 / C2-C6 / trend-alerts-hrv / F16 PR thread; documented in MEMORY.md
