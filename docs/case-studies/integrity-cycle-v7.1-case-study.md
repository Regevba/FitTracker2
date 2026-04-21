# Integrity Cycle — v7.1 Case Study

**Date written:** 2026-04-21

**Subtitle:** How a single multi-hour audit that surfaced 7 "shipped but unreconciled" features became a 72-hour automated background process — and why that counts as a framework version bump.

| Field | Value |
|---|---|
| Framework version | v7.1 |
| Work type | Framework infrastructure (not a product feature) |
| Trigger date | 2026-04-20 open-items audit |
| Ship date | 2026-04-20 (infra) + 2026-04-21 (v7.1 docs) |
| Wall time | ~3 hours (design + script + workflow + docs + initial snapshot) |
| Commits shipping the cycle | `993be3a` (infra), `c21ab15` (upstream tickets), `f8a7e82` (Category A+B+C remediation) |
| Snapshot ledger | `.claude/integrity/snapshots/` — `2026-04-20T20-45-00Z.json` is the baseline |
| Baseline findings | **0** after Category A/B/C remediation landed |
| Prior-audit findings count | 31 (10 pre-PM backfill false positives + 8 real lies + other) |

---

## 1. Why This Case Study Exists

The 2026-04-20 session ran a deep audit across every `.claude/features/*/state.json` and found a systemic drift pattern no prior audit had surfaced: **7 features whose top-level `current_phase` said `complete` even though the code had shipped to `main` weeks earlier without ever updating state.json.** The lies weren't malicious; they were just the natural outcome of a framework that had no feedback loop between "your PR merged" and "your feature's state.json should reflect that."

The surfaced drift:

| Feature | Shipped | Drifted until | Days of lie |
|---|---|---|---|
| HADF Infrastructure | 2026-04-16 (PR #82 chain) | 2026-04-20 | 4 |
| home-today-screen | 2026-04-09 (PR #61, bf3bd67) | 2026-04-20 | 11 |
| nutrition-v2 | 2026-04-19 (M-2 chain) | 2026-04-20 | 1 |
| onboarding-v2-auth-flow | ~2026-04-15 | 2026-04-20 | ~5 |
| settings-v2 | 2026-04-19 (M-1 chain) | 2026-04-20 | 1 |
| user-profile-settings | 2026-04-13 | 2026-04-20 | 7 |
| parallel-write-safety-v5.2 | 2026-04-16 (T6 deferred flag wrong) | 2026-04-20 | 4 |

Median drift: 4 days. Max: 11. These features had working code, merged PRs, and existing case studies — the state.json was just *wrong*. A reader looking at the framework's feature registry saw 7 items marked `complete` that weren't reconciled and 7 items marked `implementation` that were done.

The fix for those 7 features landed in `f8a7e82` (batch reconcile). That closed the one-time problem. **v7.1 is the fix for the systemic problem.**

---

## 2. Summary Card

| Metric | Value | Source |
|---|---|---|
| Design rationale | "Shipped but unreconciled" drift is invisible without an explicit audit | 2026-04-20 audit findings |
| Cycle cadence | Every 72 hours (GitHub Actions cron `0 4 */3 * *`) | `.github/workflows/integrity-cycle.yml` |
| Failure modes detected | 8 (PHASE_LIE, TASK_LIE, NO_CS_LINK, V2_FILE_MISSING, PARTIAL_SHIP_TERMINAL, NO_STATE, INVALID_JSON, NO_PHASE) | `scripts/integrity-check.py` |
| Bypass markers | 2 (`pre_pm_workflow_backfill`, `roundup`) | audit script |
| Infrastructure files | 5 (script, workflow, README, initial snapshot, Makefile targets) | commit `993be3a` |
| Initial baseline | 40 features, 44 case studies, 0 findings | `.claude/integrity/snapshots/2026-04-20T20-45-00Z.json` |
| Manual invocation | `make integrity-check`, `make integrity-snapshot` | Makefile |
| Regression response | Auto-open GitHub issue (`integrity-cycle`, `regression` labels) | workflow step |
| Ledger policy | Every snapshot committed to main (append-only history) | workflow commit step |

---

## 3. Design Walkthrough

### 3.1 What a failure mode looks like

The 2026-04-20 audit classified its findings into repeatable codes. Each code is now a detector in the integrity script.

**`PHASE_LIE` — top-level says complete but sub-phases say pending.** Example: HADF's `current_phase: "implementation"` but all 9 of its tasks had already shipped to main via PR #82 chain (commits `7478a8e` through `a5faa4f`). Detector: iterate `phases.*` and flag any status not in the valid-complete set.

**`TASK_LIE` — top-level terminal but tasks list has pending/in_progress entries.** Example: home-today-screen's T1-T17 all marked `pending` despite the case study documenting the six shipping commits. Detector: iterate `tasks.task_list[].status` and flag any in the open-task set.

**`NO_CS_LINK` — terminal phase but no case-study linkage.** Example: 9 pre-2026-04-13 backfill features that pre-date the "every feature gets a case study" rule. These need either a `case_study`, `parent_case_study` (for sub-features), or `case_study_type` marker. Detector: check for presence of any of those three fields.

**`V2_FILE_MISSING` — state declares `v2_file_path` but the file doesn't exist on disk.** Example: a v2 refactor that shipped, then got rolled back without updating state.json. Detector: resolve the path and check existence.

**`PARTIAL_SHIP_TERMINAL` — `partial_ship: true` alongside a terminal phase.** This is the specific case of UI-015 (import-training-plan) and UI-016 (push-notifications) before the 2026-04-20 audit: infra shipped but no user can reach the feature. Policy is either downgrade phase or remove the flag, pick one. Detector: flag the combination.

**`NO_STATE` / `INVALID_JSON` / `NO_PHASE`** — structural failures. Detector: file existence + JSON parse + field presence.

### 3.2 Why bypass markers exist

Without bypass markers, 10 of the 31 findings in the 2026-04-20 audit would be false positives:

- **9 pre-PM-workflow backfills** legitimately use legacy phase vocabulary (`pre-pm-workflow`, `backfilled`, `shipped`). These aren't lies; they're just from before the post-2026-04-06 schema existed. Marker: `case_study_type: "pre_pm_workflow_backfill"`.
- **6 features in the six-features-roundup** (ai-cohort-intelligence, android-design-system, development-dashboard, gdpr-compliance, google-analytics, stats-v2) are covered by a consolidation case study. Sub-phase granularity isn't meaningful because the roundup is the accounting unit. Marker: `case_study_type: "roundup"`.

With these markers, the initial baseline is **0 findings**. Without them, it would be ~15. The markers are the signal-to-noise dial.

### 3.3 The 72-hour cadence — empirical, not arbitrary

Three data points from the 2026-04-20 audit:

1. **Median drift: 4 days.** A 72-hour cycle catches the median case one cycle after it happens.
2. **Max drift: 11 days.** A weekly cycle would still have let that case sit for 4 days past the first cycle. 72h means max 5 days (one cycle).
3. **7 features accumulated drift in 14 days.** That's a rate of 1 per 2 days. A 72h cycle (3 days) matches the accumulation rhythm — each cycle flags the ~1-2 drifted features from that window, not a pile of 7.

Faster cycles (24h, 12h) would commit too many identical snapshots to the ledger for no detection benefit on the median case. Slower cycles (weekly+) would defeat the "drift for at most one cycle" property.

### 3.4 The snapshot ledger — append-only, git-native

Each cycle writes one file to `.claude/integrity/snapshots/<timestamp>.json` and commits it. The directory grows ~10 files/month. Each snapshot is ~50KB (40 features × ~1KB each + overhead). 10 years of cycles = ~6MB — negligible in a repo this size.

Why commit to main rather than keep snapshots as GitHub Actions artifacts?

- **Git is the ledger.** Artifacts expire. Commits don't.
- **Readable.** Anyone can `cat .claude/integrity/snapshots/2026-04-21T04-00-00Z.json` without GitHub API.
- **Diffable offline.** `git log -- .claude/integrity/snapshots/` gives the full cycle history with commit dates.
- **Auditable.** The integrity cycle's own committed state is itself integrity-checkable.

### 3.5 Regression semantics — what counts as a regression

Three regression gates trigger an auto-opened issue:

1. **Feature present in previous snapshot, absent now** — someone deleted a feature directory
2. **Case study present before, absent now** — a case study file was removed
3. **A new `(feature, finding_code)` pair that wasn't in the previous snapshot** — drift re-emerged, or a new feature shipped without linkage

Non-regression changes that do NOT trigger an issue:

- New features added (expected — growth)
- New case studies added (expected — growth)
- state.json content changed but still consistent (expected — reconciliation)
- Previously-flagged findings resolved (expected — improvement)

The asymmetry is deliberate: the cycle only pages on *newly introduced drift*, not on the current drift backlog. The backlog is fixed once; the introduction rate is what we need to watch.

---

## 4. What Shipped

### Infrastructure

| File | Role | Size |
|---|---|---|
| `scripts/integrity-check.py` | Audit script — produces snapshot, runs diff, emits findings | 356 lines |
| `.github/workflows/integrity-cycle.yml` | Cron trigger + commit step + auto-issue on regression | ~100 lines |
| `.claude/integrity/README.md` | Design doc + schema reference + false-positive guide | ~170 lines |
| `.claude/integrity/snapshots/2026-04-20T20-45-00Z.json` | Initial baseline snapshot | ~50 KB |
| `Makefile` targets | `integrity-check`, `integrity-snapshot` — local invocation | 2 targets added |
| `CLAUDE.md` § Integrity Cycle | Project-level policy reference | ~12 lines added |
| `.gitignore` allow-list | `.claude/integrity/**` whitelisted through existing `.claude/` ignore | 2 lines added |

### Dependent remediation (landed alongside to make the baseline clean)

| Commit | Closed |
|---|---|
| `f8a7e82` | Category A (10 backfill markers) + Category B (7-feature task/phase reconcile) + Category C (app-store-assets downgrade) — 30 of 31 audit findings |
| `63a216d` | HADF T2-T9 reconcile (closed before the integrity-cycle commit) |
| `bf77705` | HADF T1 reconcile (closed before the integrity-cycle commit) |
| `993be3a` | **v7.1 integrity-cycle infrastructure itself** |

### Framework-manifest capability flag

`.claude/shared/framework-manifest.json` now declares `capabilities.integrity_cycle: true` and a `v7_1_integrity_cycle` sub-object with the full config surface. This is how other skills discover the capability at dispatch time.

---

## 5. What It Does Not Do

- **Does not prevent drift from being introduced.** Phase 0 (the PM workflow's health check) still owns gatekeeping. The cycle is a *detector*, not a *preventer*.
- **Does not verify correctness of the features themselves.** A feature can have a perfectly consistent state.json that describes a broken product. The cycle only checks the self-report for internal consistency.
- **Does not run on sub-second intervals.** Cycle firing is intentionally 72h — tight enough to catch drift, loose enough to not spam the ledger.
- **Does not gate CI.** The cycle runs on a cron schedule, not on every commit. A PR that introduces a state.json lie will not be blocked at merge time — it'll be flagged within 72h.

The scope is deliberately narrow: **detect drift between reality and state.json's self-report, and page on regressions.** That's it.

---

## 6. Why It Earned a Version Bump

v6.0 added **measurement** (phase timing, cache hit rates).
v7.0 added **hardware awareness** (HADF 5-layer dispatch).
v7.1 adds **self-observation** — a recurring background process that checks the framework's own bookkeeping for consistency.

This is structurally different from every prior version. All prior versions added capabilities that run when a feature is dispatched (skill-on-demand loading, cache compression, batch dispatch, parallel safety, hardware fingerprinting). v7.1 adds a capability that runs *without* a feature being dispatched — it runs because 72h elapsed. That's a steady-state change to the framework's behavior, which is the version-bump bar.

It's also the first framework capability whose design was driven **entirely by empirical observation of drift** rather than by design theory. The 2026-04-20 audit made the case for the cycle's existence; the 3 data points (median / max / accumulation rate) made the case for the specific 72h cadence. Every prior version had some theoretical design argument ("SoC reclaims context," "HADF routes to hardware"). v7.1 has a pure-measurement argument: here's the drift we saw; here's the cycle that would have caught it.

---

## 7. Lessons

1. **A one-time audit that finds a systemic drift pattern should convert to an automated cycle, not stay as a one-off.** The 2026-04-20 audit found 7 drifted features. Without v7.1, the 8th, 9th, and 10th would accumulate unseen until the next explicit audit — which is when and how this pattern was originally missed.

2. **Empirical cadence beats theoretical cadence.** 72h wasn't picked because it felt nice. It was picked because the drift-accumulation rate (1 per 2 days), the median drift duration (4 days), and the max tolerated backlog (1 cycle) converged on it. Other projects would find a different cadence from their own data.

3. **Bypass markers are a signal-to-noise dial, not a cheat code.** Without `pre_pm_workflow_backfill` and `roundup`, the initial baseline would be 15 findings and the cycle would be useless (every run would "detect" the same legacy state). With them, the baseline is 0 and any future finding is new drift worth paging on. The cost is that adding a new exemption requires explicit approval — the default is "flag it."

4. **Framework-level regressions should auto-open issues, not fail CI.** CI gates PR merges; the integrity cycle gates the steady state. These are different authority loops. A state.json drift isn't a merge-blocker (the code is fine); it's a hygiene event. An auto-opened issue with the `regression` label gets the right humans' attention without blocking the delivery pipeline.

5. **Version bumps should require a capability change, not a point improvement.** v7.1 isn't "better measurement" or "better dispatch" — it's a new class of behavior (recurring self-observation) that didn't exist in any prior version. The bar for the bump is "would a reader of the version table understand this as a new kind of thing?" Answer here: yes — prior versions' cadence was "per-dispatch," v7.1's is "per-72h-wall-clock," and that's structurally different.

---

## 8. Links

- **Script:** [`scripts/integrity-check.py`](../../scripts/integrity-check.py)
- **Workflow:** [`.github/workflows/integrity-cycle.yml`](../../.github/workflows/integrity-cycle.yml)
- **Design doc:** [`.claude/integrity/README.md`](../../.claude/integrity/README.md)
- **Initial baseline snapshot:** [`.claude/integrity/snapshots/2026-04-20T20-45-00Z.json`](../../.claude/integrity/snapshots/2026-04-20T20-45-00Z.json)
- **Remediation commits that made the baseline clean:** `f8a7e82`, `63a216d`, `bf77705`
- **Infrastructure commit:** `993be3a`
- **Evolution narrative:** [`docs/skills/evolution.md` § 25](../skills/evolution.md#25-v62--integrity-cycle-2026-04-21)
- **Version-history row:** [`docs/skills/pm-workflow.md#version-history`](../skills/pm-workflow.md#version-history)
- **Framework manifest entry:** `v7_1_integrity_cycle` in [`.claude/shared/framework-manifest.json`](../../.claude/shared/framework-manifest.json)
- **Upstream framework bugs surfaced in the related 2026-04-20 work:** [F6 #51286](https://github.com/anthropics/claude-code/issues/51286), [F7 #51287](https://github.com/anthropics/claude-code/issues/51287), [F8 #51288](https://github.com/anthropics/claude-code/issues/51288), [F9 #51289](https://github.com/anthropics/claude-code/issues/51289)
- **Showcase version:** [`fitme-showcase/04-case-studies/25-integrity-cycle.md`](../../../fitme-showcase/04-case-studies/25-integrity-cycle.md)
