# Skills Activity Aggregator — Deferred Implementation Plan

> **Status:** DEFERRED — execution begins **post-Phase-E exit (≥ 2026-06-04)**.
> **Reason for deferral:** the work touches FT2 infra-globs (`.claude/settings.json` PostToolUse hooks, `scripts/*`, `Makefile`) which trigger `BRANCH_ISOLATION_VIOLATION` Mode B. Adding a new write-time advisory (`SKILL_ACTIVITY_STALE`) during the v7.9 post-promotion soak (2026-05-21 → ~06-04) would dilute the Phase E validation signal and risks false-positive cross-talk with the calibration of the three gates that just flipped enforced. Layout-only fix shipped separately as fitme-story PR #154 (phase-accordion presentation; no infra touch).
>
> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task once the Phase E gate clears. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the "Activity" half of P1.2 from [`docs/skills/skills-review-2026-05-13.md`](../../skills/skills-review-2026-05-13.md). Today the `/control-room/skills` page surfaces only the **inventory** side (frontmatter snapshot). The spec asks for the **activity** side — per-skill last-invocation, last-bump date, cross-skill dispatch counts — sourced from `state.json::cache_hits[]` + `.claude/shared/gate-coverage.jsonl` + `.claude/logs/_session-*.events.jsonl`.

**Architecture:** Build a FT2-side aggregator script that joins the three event sources into a per-skill activity rollup JSON, mirror it cross-repo via a new sync phase in `fitme-story/scripts/sync-from-fittracker2.ts` (same prebuild-emit pattern Mechanism F adopted in 2026-05-26's PR #152), and surface the activity columns on the existing fitme-story page. Ship the new write-time advisory `SKILL_ACTIVITY_STALE` (no invocations for N days) in advisory mode for 14 days before promotion-decision review.

**Spec of record:** [`docs/skills/skills-review-2026-05-13.md` §5 P1.2](../../skills/skills-review-2026-05-13.md). No separate design spec because every component is a read-only observability surface that follows existing patterns (Mechanism C session-attribution for the data source; Mechanism A coverage telemetry for the advisory; prebuild-emit sync for the cross-repo bridge).

**Tech stack:** Python 3 stdlib (aggregator + tests) · TypeScript / Node 24 (sync extension) · React server components (page) · Style Dictionary semantic tokens (already in use on the page).

**Timeline:** 4 working days. Day 0 = 2026-06-04 (Phase E exit). Ships 2026-06-09. Advisory-mode soak 2026-06-09 → 2026-06-23. Promotion decision 2026-06-23.

---

## Why post-Phase E (data-integrity rationale)

Three load-bearing constraints make pre-Phase-E ship the wrong call:

1. **v7.9 promotion-soak signal isolation.** The three gates that flipped enforced 2026-05-21 (`BRANCH_ISOLATION_VIOLATION` Mode B + Mode C, `FEATURE_CLOSURE_COMPLETENESS`) are mid-calibration through 2026-06-04. Shipping a new advisory in the same window means coverage telemetry for the NEW gate and post-flip telemetry for the OLD gates land in the same Mechanism A stream. A regression in `gate-coverage-weekly.jsonl` during this window would have to be disambiguated by hand instead of being attributable to one cause. The infra-master-plan §2.2 "no new gates during promotion soak" rule covers exactly this case.
2. **Forward-only data window.** Even with the aggregator landed, `invocations_7d` will read 0 for every skill for the first 7 days post-ship — the existing `_session-*.events.jsonl` stream may NOT capture Skill-tool invocations directly today (Mechanism C was scoped to Read events for cache_hits attribution). Task 1 below is a discovery step to confirm whether we need a new `PostToolUse:Skill` hook. Either way, day-1 data is sparse-to-empty; deferring 9 days gives no benefit, but also no cost, to data quality at launch.
3. **Mode B + Mode C concentration risk.** The aggregator touches three infra-globs in one PR each: `scripts/aggregate-skill-activity.py` (new script), `.claude/settings.json` (PostToolUse hook), `Makefile` (advisory wiring). Each commit fires `BRANCH_ISOLATION_VIOLATION` Mode B and forces isolated worktree dispatch. Running 4 isolated-worktree PRs back-to-back during Phase E would generate noise in the Mechanism A `branch-isolation-historical` advisory stream. v7.9.1 build window (≥ 06-04) is the canonical home for infra-glob changes.

---

## File Map

**FT2 (Repo 1) — files to create:**
- `scripts/aggregate-skill-activity.py` — aggregator
- `scripts/observe-skill-invocation.py` — `PostToolUse:Skill` hook handler (conditional on Task 1 finding)
- `scripts/test_aggregate_skill_activity.py` — fixture-based regression test (parity with `scripts/test_skills_audit.py`)
- `.claude/shared/skill-activity.json` — output artifact (regenerated at run time; gitignored OR committed as snapshot per Task 3 decision)
- `docs/case-studies/skills-activity-aggregator-case-study.md` — close-out case study

**FT2 — files to modify:**
- `.claude/settings.json` — add `PostToolUse:Skill` hook entry (conditional on Task 1)
- `Makefile` — add `make skills-activity` target + wire into `make integrity-check`
- `scripts/integrity-check.py` — register new cycle-time advisory `SKILL_ACTIVITY_STALE`
- `.gitignore` — exclude `.claude/shared/skill-activity.json` if Task 3 decides "ephemeral"
- `.gitattributes` — register merge driver for `.claude/shared/skill-activity.json` if Task 3 decides "committed snapshot"
- `.claude/integrity/observed-patterns.md` — append new pattern entry for the advisory
- `.claude/shared/must-have-cadence-followups.md` — add advisory-mode → enforced promotion decision row (target 2026-06-23)

**fitme-story (Repo 2) — files to create:**
- `src/data/skills/activity.json` — synced mirror of FT2's `.claude/shared/skill-activity.json` (prebuild-emit, identical to Mechanism F's `membrane-status.json` pattern landed 2026-05-26)

**fitme-story — files to modify:**
- `scripts/sync-from-fittracker2.ts` — add Phase G (`syncSkillActivity`) mirroring the FT2 artifact
- `src/lib/control-room/skills-manifest.ts` — extend `SkillRow` with `activity?` block + loader merge
- `src/app/control-room/skills/page.tsx` — add "Last invoked / Dispatches 7d/30d" columns to the phase-accordion cards landed in PR #154 (purely additive; presentation layer already exists)

---

## Day-by-day timeline

| Day | Tasks | Output |
|---|---|---|
| 0 (2026-06-04) | Task 1 — Discovery: inspect `_session-*.events.jsonl` for Skill-tool invocation capture | Decision: add `PostToolUse:Skill` hook OR rely on existing stream |
| 1 (2026-06-05) | Tasks 2-4 — Aggregator script + tests + Makefile wiring | FT2 PR-1 (isolated worktree) |
| 2 (2026-06-06) | Tasks 5-6 — `PostToolUse:Skill` hook (if Task 1 needs it) + observed-patterns entry | FT2 PR-2 (isolated worktree) |
| 3 (2026-06-07) | Tasks 7-8 — Advisory check code + cadence ledger row | FT2 PR-3 (isolated worktree) |
| 4 (2026-06-08) | Tasks 9-12 — Cross-repo sync extension + loader + page-column additions + case study | fitme-story PR + FT2 close-out commit |
| 5-18 (2026-06-09 → 06-22) | Advisory-mode soak | 14d Mechanism A telemetry accumulates |
| 19 (2026-06-23) | Task 13 — Promotion decision via Mechanism A `{candidates, checked, skipped}` + false-positive count | `SKILL_ACTIVITY_STALE` enforced OR remains permanent-advisory |

---

## Tasks

### Task 1: Discovery — does `_session-*.events.jsonl` capture Skill invocations today?

**Files:**
- Read: `.claude/logs/_session-*.events.jsonl` (any recent file)
- Read: `.claude/settings.json` (PostToolUse hook registration)
- Read: `scripts/observe-cache-hit.py` (existing Mechanism C handler — pattern to mirror)

**Steps:**
- [ ] Grep recent session ledgers for `tool_name.*Skill` or similar markers
- [ ] If present: schema-document the event shape; aggregator can join on it directly
- [ ] If absent: design `PostToolUse:Skill` hook handler in `scripts/observe-skill-invocation.py` modeled on Mechanism C
- [ ] Decide whether to backfill from case-study citations / `state.json::cache_hits[]` (proxy signal) for the first 7 days

**Done when:** decision recorded in this plan (replace this paragraph with "Decision: present" or "Decision: hook required") and any required hook handler stubbed.

### Task 2: Aggregator script

**Files:**
- Create: `scripts/aggregate-skill-activity.py`

**Steps:**
- [ ] Walk `.claude/features/*/state.json::cache_hits[]` collecting per-skill SKILL.md path references
- [ ] Walk `.claude/shared/gate-coverage.jsonl` collecting per-skill gate-firing counts (already keyed by `gate_name`; needs join via observed-patterns catalog → owning-skill map)
- [ ] Walk `.claude/logs/_session-*.events.jsonl` collecting per-skill invocation timestamps (source depends on Task 1)
- [ ] Emit `.claude/shared/skill-activity.json` schema: `{ syncedAt, skills: [{ name, lastInvokedAt, invocations7d, invocations30d, topFeatures: [...], dispatchedFrom: [...], dispatchedTo: [...] }] }`
- [ ] Add `--verbose` and `--quiet` modes; default exits 0 always (data layer, not gate)

**Done when:** script runs in <2s on current data; emits valid JSON; manual spot-check matches `git log --grep='/pm-workflow'` for at least one skill.

### Task 3: Decide artifact-storage policy

**Files:**
- Modify: `.gitignore` OR `.gitattributes`

**Question:** is `.claude/shared/skill-activity.json` ephemeral (regenerated per run, gitignored, prebuild-only consumer) or committed (snapshot in repo, append-only merge driver via Mechanism E)?

**Recommendation:** ephemeral. The prebuild sync (Task 9) reads it from FT2's working dir on each fitme-story build. Committing the file adds merge-conflict surface every time anyone runs the aggregator locally. Mirror the `membrane-status.json` ephemerality pattern shipped 2026-05-26.

**Done when:** `.gitignore` updated + decision noted here.

### Task 4: Wire into Makefile + integrity-check

**Files:**
- Modify: `Makefile`
- Modify: `scripts/integrity-check.py`

**Steps:**
- [ ] Add `make skills-activity` target invoking the aggregator
- [ ] Add `make skills-activity` to `make integrity-check`'s subcommand list (advisory; never blocks)
- [ ] Register `SKILL_ACTIVITY_STALE` cycle-time advisory in `scripts/integrity-check.py` — fires when a skill's `lastInvokedAt > N days ago` (default N=90, configurable)

**Done when:** `make integrity-check` baseline shows the new advisory's `{candidates, checked, skipped}` row in `gate-coverage.jsonl`.

### Task 5: PostToolUse:Skill hook (conditional on Task 1)

**Files:**
- Create: `scripts/observe-skill-invocation.py` (if needed)
- Modify: `.claude/settings.json`

**Steps:**
- [ ] Mirror `scripts/observe-cache-hit.py` shape — single-purpose handler appending one line per Skill invocation to the current session's events ledger
- [ ] Add bash short-circuit guard for cross-repo cwd (per [`docs/superpowers/specs/2026-05-08-cross-repo-gate-asymmetry.md`](../specs/2026-05-08-cross-repo-gate-asymmetry.md))

**Done when:** test invocation in this conversation appends an expected event row.

### Task 6: Observed-patterns catalog entry

**Files:**
- Modify: `.claude/integrity/observed-patterns.md`

Append a new pattern row covering `SKILL_ACTIVITY_STALE` firing + remediation. Standard format.

### Task 7: Test fixture

**Files:**
- Create: `scripts/test_aggregate_skill_activity.py`

Mirror `scripts/test_skills_audit.py` shape. Provide 1-2 fixture session ledgers and assert aggregator output matches golden.

### Task 8: Cadence-ledger row

**Files:**
- Modify: `.claude/shared/must-have-cadence-followups.md`

Add advisory-mode promotion-decision row dated 2026-06-23 with the 4 v7.9-style criteria (≥7d coverage, 0 false positives, no silent skips, single-line reversibility).

### Tasks 9-11: Cross-repo sync + page wiring (fitme-story)

**Files:**
- Modify: `fitme-story/scripts/sync-from-fittracker2.ts` — add `syncSkillActivity()` Phase G
- Modify: `fitme-story/src/lib/control-room/skills-manifest.ts` — extend `SkillRow` + merge activity
- Modify: `fitme-story/src/app/control-room/skills/page.tsx` — add columns to phase-accordion cards (purely additive; layout already lives in PR #154)

**Honesty banner requirement:** page must surface "Data window opened 2026-06-09" until 30 days post-launch (i.e. through 2026-07-09). Without that banner the page reads as "11/12 skills are zombies" on day 1.

### Task 12: Close-out case study

**Files:**
- Create: `docs/case-studies/skills-activity-aggregator-case-study.md`

Standard close-out: success metrics (advisory coverage ≥7d, false-positive count, total invocations captured day-1 → day-14), kill criteria + resolution, framework_version `v7.9.1` or `v7.9.2` depending on which build window absorbs it, related_prs covering all 4 PRs.

### Task 13: Promotion decision (2026-06-23)

Standard advisory→enforced decision per [infra-master-plan §2.2](../../master-plan/infra-master-plan-2026-05-12.md). Required: ≥7 days of `{candidates, checked, skipped}` rows, 0 false positives across all firings, no silent skips, reversibility runbook tested. If criteria met: single-line flag flip `SKILL_ACTIVITY_ADVISORY_MODE = True → False`. If not: keep advisory permanent (like `TIER_TAG_LIKELY_INCORRECT`).

---

## Risk register

| Risk | Likelihood | Mitigation |
|---|---|---|
| `_session-*.events.jsonl` doesn't capture Skill invocations | Medium | Task 1 discovery + Task 5 fallback hook |
| Day-1 data sparse → page looks broken | High | Honesty banner per Task 11 + "Data window opened X" footer |
| Phase E soak slip → start date moves | Low | Plan dates are anchored to "Phase E exit + 1 day" not calendar |
| Advisory false-positive rate too high | Low-medium | 14d soak surfaces it; Task 13 default = keep advisory permanent if FP > 10% |
| Mode B isolated-worktree churn during 3 back-to-back PRs | Low | Standard pattern post-v7.9; 4 PRs is within typical batch |

---

## Cross-references

- **Spec of record:** [`docs/skills/skills-review-2026-05-13.md` §5 P1.2](../../skills/skills-review-2026-05-13.md)
- **Layout-only predecessor:** fitme-story PR #154 (phase-accordion presentation; no data change)
- **Mechanism C pattern (for hook design):** [`scripts/observe-cache-hit.py`](../../../scripts/observe-cache-hit.py) + v7.8 Bridge spec
- **Mechanism F pattern (for prebuild-emit sync):** `scripts/membrane-status.py` + fitme-story `scripts/sync-from-fittracker2.ts` Phase F (landed 2026-05-26)
- **Cross-repo asymmetry contract:** [`docs/superpowers/specs/2026-05-08-cross-repo-gate-asymmetry.md`](../specs/2026-05-08-cross-repo-gate-asymmetry.md)
- **v7.9 promotion case study (advisory→enforced pattern):** [`docs/case-studies/framework-v7-9-promotion-case-study.md`](../../case-studies/framework-v7-9-promotion-case-study.md)
- **Infra master plan §2.2 (no-new-gates-during-soak rule):** [`docs/master-plan/infra-master-plan-2026-05-12.md`](../../master-plan/infra-master-plan-2026-05-12.md)
