---
title: Framework v7.9 — Advisory → Enforced Promotion (3 gates, single-flag flip)
date_written: 2026-05-21
work_type: Feature
work_subtype: framework_feature
dispatch_pattern: operator-driven (decision) + agent-driven (per-gate flip implementation)
framework_version: v7.9
tier_tags_present: true
state_owner: ft2
case_study_type: framework_meta
predecessor_case_studies:
  - "docs/case-studies/framework-v7-8-branch-isolation-case-study.md"
  - "docs/case-studies/framework-v7-8-bridge-case-study.md"
  - "docs/case-studies/framework-v7-7-validity-closure-case-study.md"
spec_path: docs/master-plan/infra-master-plan-2026-05-12.md
primary_metric: "Number of advisory gates successfully promoted to enforced with 0 false positives in the 7-day post-flip soak (target: 3 promoted, 0 rollbacks)"
success_metrics:
  primary: "3 of 3 candidate gates flipped advisory → enforced on 2026-05-21; 0 rollbacks during Phase E soak 2026-05-21 → 2026-06-04 [T1, instrumented via gate-coverage.jsonl + git log on scripts/check-state-schema.py]"
  secondary:
    - "All 4 §2.2 promotion criteria verified GREEN for each candidate before flip [T1, captured in research-phase log]"
    - "Side-effects PR opens single-day; documents updated (CLAUDE.md + dev-guide + entrypoint + honesty ledger + case study) in the same commit as the flag flip [T1]"
    - "Post-promotion T+7d baseline snapshot (B2, 2026-05-28) shows zero new findings vs 2026-05-14 platform anchor [T2, pending capture 2026-05-28]"
kill_criteria:
  - "Mechanism A telemetry shows 0% coverage for any advisory-being-promoted gate at decision time (cannot promote what was never calibrated)"
  - "False positive rate >5% during the 14d calibration window for any proposed-promotion gate"
  - "Post-promotion bug surfaces requiring rollback within T+7d soak — defer promotion or restore advisory mode"
kill_criteria_resolution: "All 3 kill criteria not_fired (evaluated 2026-05-28, Phase E Day 7, post-B2 baseline snapshot). K1 (Mech A 0% coverage at decision time): 18 + 13 + 13 firings observed across 14-day calibration window 2026-05-07 → 2026-05-21; 0% coverage was NEVER observed for any of the 3 candidate gates [T1, .claude/logs/gate-coverage.jsonl]. K2 (false positive rate >5%): 0 false positives across 44 total firings; rate = 0% < 5% threshold [T1]. K3 (post-promotion rollback within T+7d): Phase E Day 7 — scripts/check-state-schema.py:132 still reads BRANCH_ISOLATION_ADVISORY_MODE = False per git log; no rollback PR opened [T1]. Verdict: PASSED — v7.9 promotion holds. Process regressions in adoption_pct_post_v6 / timing_wall_time_pct_post_v6 / cache_hits_pct_post_v6 observed via make integrity-diff are denominator dilution from +9 features added during Phase E without adoption metrics backfilled — NOT v7.9-caused; flagged for v7.9.1 backfill follow-up (see §99.2)."
related_prs: [326, 392, 393, 413, 415, 416, 417, 448]
pr_citation_exempt:
  - {pr_number: 503, reason: "Contextual cite in §99.3 — B12 hardening verdict (different feature: ucc-passkey-auth-security-hardening); referenced for Phase E timeline, not a shipping PR for v7.9 promotion."}
  - {pr_number: 520, reason: "Contextual cite in §99.3 — HADF Sub-exp 1A closure (different feature: hadf-phase2bis-replication); referenced as an example of Mode B Branch Isolation firing correctly during Phase E, not a shipping PR for v7.9 promotion."}
case_study_showcase: "fitme-story/content/04-case-studies/34-framework-v7-9-promotion.mdx"
external_audit_status: corrected  # External Audit #1 corrections applied via PR #448 (2026-05-22)
status: live
---

# Framework v7.9 — Advisory → Enforced Promotion

> **Live append-only journal.** Authored 2026-05-21 (freeze day). Section 99 (Synthesis) appended after the B2 post-v7.9 baseline lands 2026-05-28. No retroactive edits — Phase E findings + the next-flip-window planning will go in additional Sections. T1/T2/T3 tier tags throughout: T1 (instrumented), T2 (declared / not yet measured), T3 (narrative).

## Section 0 — Genesis

Three converging needs triggered v7.9 [T3]:

1. **The v7.8.1 calibration window closed 2026-05-21.** Two gates (`BRANCH_ISOLATION_VIOLATION` Modes B+C and `FEATURE_CLOSURE_COMPLETENESS`) shipped in advisory mode at v7.8.1 (2026-05-07) with a deliberate 14-day Mechanism A telemetry window to collect `{candidates, checked, skipped, skip_reasons}` data. v7.9 is the single-line flip that promotes them to enforced. [T1, source: [infra-master-plan §2.1](../master-plan/infra-master-plan-2026-05-12.md), [v7.8.1 case study §99B](framework-v7-8-branch-isolation-case-study.md)]
2. **The discipline is the deliverable.** v7.7 (FT2-FH-001) and v7.8.3 (FT2-FH-002) both shipped with silent-pass bugs because gates went live without verifying their telemetry was correctly keyed. v7.9 is the first framework version to use Mechanism A as a gate on its own promotion decision. The pattern being established is more valuable than the flip itself. [T3]
3. **HADF Phase 2-bis depends on the post-v7.9 baseline.** The next major product feature (`hadf-phase2bis-replication`) is gated on the 2026-05-28 B2 post-v7.9 baseline snapshot. Sub-experiment 1 launch is 2026-05-23, contingent on v7.9 landing cleanly today. [T2, source: [`docs/master-plan/post-v7-9-candidate-plan-2026-05-20.md`](../master-plan/post-v7-9-candidate-plan-2026-05-20.md) §3]

## Section 1 — Scope (3 gates × 4 criteria)

Per [infra-master-plan §2.1](../master-plan/infra-master-plan-2026-05-12.md), three gates were candidates for the 2026-05-21 promotion window. All three controlled by a single flag at `scripts/check-state-schema.py:132`:

| Gate | Mode | Shipped advisory | Calibration window | Source |
|---|---|---|---|---|
| `BRANCH_ISOLATION_VIOLATION` | Mode B (infra commit-level) | v7.8.1 (2026-05-07) | 14d (2026-05-07 → 2026-05-21) | T6 |
| `BRANCH_ISOLATION_VIOLATION` | Mode C (per-state.json) | v7.8.1 (2026-05-07) | 14d | T6 |
| `FEATURE_CLOSURE_COMPLETENESS` | write-time | v7.8.1 (2026-05-07) | 14d | T11-T14 |

Per [infra-master-plan §2.2](../master-plan/infra-master-plan-2026-05-12.md), each candidate must satisfy 4 criteria:

1. **Coverage emitted** — ≥7 days of `{candidates, checked, skipped}` rows
2. **No false positives** — every `failure` row maps to a legitimate violation in the staged diff
3. **No silent skips** — `skipped` counts track real reasons (not bugs)
4. **Reversibility** — advisory mode restorable in <5 min via single-line revert

Failing any criterion holds the gate at advisory and re-evaluates at next promotion window (T+14d).

## Section 2 — B1 freeze-day checklist (executed 2026-05-21 04:21–04:25Z) [T1]

Per [`.claude/shared/must-have-cadence-followups.md`](../../.claude/shared/must-have-cadence-followups.md) §B1:

| Step | Command | Result |
|---|---|---|
| B1.1 | `make integrity-check` | **0 findings** (74 features scanned, 79 case studies) |
| B1.2 | `make integrity-diff` | 3 dilution Δ vs 2026-05-14 anchor (denominator grew 70→74; numerator flat). 0 real regressions. |
| B1.3 | `make documentation-debt` | 1 open item (baseline-aligned; forward-only kill_criteria_resolution_missing advisory) |
| B1.4 | `make measurement-adoption` | 3/40 fully-adopted post-v6 (flat vs eve check) |
| B1.5 | `python3 scripts/membrane-status.py` | Normal readout; no dispatch blockers |
| B1.6 | 14d gate-coverage telemetry review | See §3 below |
| B1.7 | Per-gate decision | PROMOTE all 3 candidates |

## Section 3 — Calibration data (14d Mechanism A telemetry, 2026-05-07 → 2026-05-21) [T1]

Raw counts from `.claude/logs/gate-coverage.jsonl`:

| Gate | 14d rows | candidates=0 rows | Dominant skip reasons (all legitimate) | Verdict |
|---|---|---|---|---|
| `BRANCH_ISOLATION_VIOLATION` Mode B | 18 | 0 | `not_infra_commit_level` × 13 | PASS |
| `BRANCH_ISOLATION_VIOLATION` Mode C | 13 | 0 | (separate emission key — distinct from Mode B) | PASS |
| `FEATURE_CLOSURE_COMPLETENESS` write-time | 13 | 0 | `not_complete_transition` × 11, `no_phase_change` × 1, `no_case_study_link` × 2 | PASS |
| `ISOLATION_OPT_OUT_REASON_MISSING` | 13 | 0 | `opt_out_false_or_absent` × 12 | (already enforced at v7.8.1 — no action) |

Other gates in the 14d window (13 rows each — every-commit emission): `CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT`, `CU_V2_INVALID`, `FRAMEWORK_VERSION_FORMAT`, `PHASE_TRANSITION_NO_LOG`, `PHASE_TRANSITION_NO_TIMING`, `PR_NUMBER_UNRESOLVED`, `SCHEMA_DRIFT_LEGACY_CREATED`, `SCHEMA_DRIFT_LEGACY_PHASE`, `STATE_NO_CASE_STUDY_LINK`, `STATE_OWNER_INVALID`, `STATE_OWNER_LOCATION_MISMATCH`, `STATE_OWNER_MISSING`.

**`GATE_COVERAGE_ZERO` meta-check:** 0 gates ever-fired are missing from the 14d window. All 16 distinct gates in `gate-coverage.jsonl` history emitted within the calibration window. [T1]

**No false-positive evaluation:** all skip reasons map to documented legitimate cases (`not_infra_commit_level` = file path doesn't match infra glob; `not_complete_transition` = state.json doesn't transition current_phase → complete; `opt_out_false_or_absent` = isolation_opt_out is false or unset; `no_phase_change` = state.json modification without phase change). 0 advisory firings in 14d that should NOT have fired. [T1, operator review of 18+13+13 = 44 firing rows]

## Section 4 — The flip [T1]

Single-line edit at [`scripts/check-state-schema.py:132`](../../scripts/check-state-schema.py):

```python
# BEFORE (v7.8.1 → v7.8.6)
BRANCH_ISOLATION_ADVISORY_MODE = True

# AFTER (v7.9)
BRANCH_ISOLATION_ADVISORY_MODE = False
```

The same flag drives all 3 gates via the per-finding pattern:

```python
finding["advisory"] = BRANCH_ISOLATION_ADVISORY_MODE
# ...
if finding.get("advisory"):
    print(f"[ADVISORY] {finding['code']}: ...", file=sys.stderr)
else:
    errors.append(...)
```

Setting the flag to `False` cleanly converts every previously-printed advisory finding into a blocking error. No other code change required. [T1, verified via `git diff scripts/check-state-schema.py`]

## Section 5 — Side-effects shipped same-PR (per [infra-master-plan §2.3](../master-plan/infra-master-plan-2026-05-12.md))

| # | What | File | Status |
|---|---|---|---|
| C-1 | New "v7.9 Promotion Release" section + version-chain header update + 2 advisory→enforced text updates | `CLAUDE.md` | ✓ |
| C-2 | The flip (`BRANCH_ISOLATION_ADVISORY_MODE = False`) | `scripts/check-state-schema.py:132` | ✓ |
| C-3 | Cold-start entrypoint | `.claude/entrypoints/framework-v7-9.md` (new) | ✓ |
| C-4 | Dev-guide §2.4.1 promoted sub-section | `docs/architecture/dev-guide-v1-to-v7-7.md` | ✓ |
| C-5 | Honesty ledger entry FT2-FH-003 (calibration discipline pattern) | `docs/case-studies/framework-honesty-ledger.md` | ✓ |
| C-7 | This case study | `docs/case-studies/framework-v7-9-promotion-case-study.md` (this file) | ✓ |
| C-6 | Linear epic + per-gate sub-issues | (Linear) | ✓ Shipped: FIT-72 In Progress + PR #417 attached + freeze-day comment posted + 9 sub-issues updated (FIT-78/79/80/81/84 Done, FIT-82/83 Canceled with "already enforced at v7.8/v7.8.3" note, FIT-85/86 In Progress) |

### PR merge sequence (all 4 landed 2026-05-21, freeze day) [T1]

| PR | Title | Merge SHA | Merged at |
|---|---|---|---|
| [#413](https://github.com/Regevba/FitTracker2/pull/413) | docs(ucc-passkey-auth-security-hardening): Phase 8 docs — case study + cadence + W12/W13 patterns | `e05eb320` | 2026-05-21T04:54:40Z |
| [#415](https://github.com/Regevba/FitTracker2/pull/415) | chore(ucc-sign-in-figma-mapping): reconcile state — 8/11 actually shipped + W14 catalog entry | `424963fd` | 2026-05-21T05:11:45Z |
| [#416](https://github.com/Regevba/FitTracker2/pull/416) | docs(master-plan): fitme-story discoverability plan — 4-phase, ~11-13h, target 50+/wk by 2026-06-30 | `0178a9c2` | 2026-05-21T05:28:56Z |
| [#417](https://github.com/Regevba/FitTracker2/pull/417) | **feat(framework-v7-9-promotion): flip 3 advisory gates → enforced (single-flag, B1 GREEN)** | **`ea53ff44`** | **2026-05-21T05:44:53Z** |

PR #417 carried 10 files / 553 ins / 28 del. The squash-merge commit is the marker for "v7.9 promotion enforcement live on `main`."

State.json transitions (final at v7.9 ship):

- `phases.research.status` → `approved` (decision: PROMOTE all 3)
- `phases.prd.status` → `skipped` (reason: spec pre-exists at infra-master-plan §2.x)
- `phases.tasks_phase.status` → `skipped` (reason: tasks pre-defined in post-v7-9-candidate-plan §1)
- `phases.implement.status` → `approved` (PR #417 merged ea53ff4 at 05:44:53Z)
- `phases.test.status` → `approved` (auto-passed via CI: 8/8 GREEN; ci_passed=true)
- `phases.review.status` → `approved` (PR self-review + pr-integrity bot GREEN + operator batch preauthorization)
- `phases.merge.status` → `approved` (pr_number=417, merge_commit=ea53ff4459921948d029c4a3ef3bd57a29aa4d2c, merged_at=2026-05-21T05:44:53Z, merge_method=squash)
- `phases.docs.status` → `in_progress` (this close-out PR)
- `phases.learn.status` → `pending` (Phase E 2026-05-21 → 2026-06-04; B2 baseline 2026-05-28)
- `current_phase`: `research` → `implement` → `docs` (single PR + close-out PR)
- `related_prs`: `[417, 413, 415, 416]`
- `linear`: `FIT-72`
- `branch` set to `feature/v7-9-promotion`

## Section 6 — Phase E validation calendar (2026-05-21 → 2026-06-04) [T2]

Per [infra-master-plan §3.6.2](../master-plan/infra-master-plan-2026-05-12.md):

- **2026-05-21** — v7.9 ships. PR opens; CI green; merge to main.
- **2026-05-22** — B11 UCC hardening T+3d check; product feature work resumes.
- **2026-05-23** — B8 parent UCC T+7d kill-criteria; HADF Phase 2-bis Sub-experiment 1 launch.
- **2026-05-27** — B12 UCC hardening T+7d → advance to complete.
- **2026-05-28** — **B2 post-v7.9 baseline snapshot:** `make snapshot-phase PHASE=post-v7-9-baseline FEATURE=framework-v7-8-branch-isolation`. Compare against the 2026-05-12 pre-v7-9 baseline + 2026-05-14 platform anchor. Document deltas in §99 of this file.
- **~2026-06-04** — Phase E exit. v7.9.1 build window opens (F16 try-repo harness + F17 last_fired_at index + F2 + F6 + D-2 + D-4).

**Phase E constraints:**

- No new gates ship — keeps the post-promotion baseline clean
- No new test-discipline work (F14, F18) starts — those are v7.9.1 docket
- F17 (`last_fired_at` index) MAY be built since it's read-only — no new gates
- Operator monitors `.claude/logs/gate-coverage.jsonl` for unexpected `failure` rows daily

## Section 7 — Reversibility runbook [T2]

If a regression surfaces during Phase E:

```bash
cd /Volumes/DevSSD/FitTracker2
git checkout -b chore/v7-9-rollback main
# Edit scripts/check-state-schema.py:132 → BRANCH_ISOLATION_ADVISORY_MODE = True
git add scripts/check-state-schema.py
git commit -m "chore(v7-9-rollback): restore advisory mode for 3 gates — see FT2-FH-00N"
git push -u origin HEAD
gh pr create --fill && gh pr merge --squash
```

End-to-end: <5 minutes. Reason for rollback MUST be recorded in [`framework-honesty-ledger.md`](framework-honesty-ledger.md) as FT2-FH-00N + this case study §99 must be updated with the regression-surface details + the next promotion attempt waits for a new T+14d calibration window. [T2]

## Section 8 — Open follow-ups (post-v7.9, NOT today's scope) [T3]

Tracked in [`docs/master-plan/post-v7-9-candidate-plan-2026-05-20.md`](../master-plan/post-v7-9-candidate-plan-2026-05-20.md):

- **§0 master plan + backlog refresh** (~4-5h) — deferred per operator decision today; runs in a separate session
- **Post-promotion telemetry-commit workflow fix** — noted during today's commit-to-main (BRANCH_ISOLATION_VIOLATION advisory fired on routine cron-artifact commit before the worktree spin-up). Now that the gate is enforced, cron artifact commits to `.claude/shared/*` will be blocked from main. Two paths: (a) add `.claude/shared/*.json` to `branch-isolation-exempt.json` allowlist, or (b) move cron-artifact commits to an isolated chore branch with auto-PR. Decision deferred to v7.9.1 build window.
- **C1 F14/F15 dispatch-test coverage push** (~2026-05-22) — opens `framework-f14-f15-dispatch-test-coverage` feature

## Section 99 — Synthesis (executed 2026-05-28, post-B2)

> **Authored:** 2026-05-28T17:30:00Z, immediately after the B2 post-v7.9 baseline snapshot at `~/Documents/FitTracker2-backups/2026-05-28-framework-v7-8-branch-isolation-post-v7-9-baseline/` (6/6 source files sha256-verified per `CHECKSUMS.sha256`). Phase E Day 7 of 14.

### §99.1 — Kill-criteria resolution

All three kill criteria evaluated against the 14-day calibration window (2026-05-07 → 2026-05-21) + 7-day Phase E soak data through 2026-05-28 [T1]:

| K# | Criterion | Observed | Verdict |
|---|---|---|---|
| K1 | Mechanism A telemetry shows 0% coverage for any advisory-being-promoted gate at decision time | `.claude/logs/gate-coverage.jsonl` 2026-05-07 → 2026-05-21: 18 + 13 + 13 firings across the 3 candidate gates; 0% coverage was **never observed** | **not_fired** [T1] |
| K2 | False positive rate >5% during the 14d calibration window | 0 false positives across 44 total firings; rate = 0% < 5% threshold | **not_fired** [T1] |
| K3 | Post-promotion bug surfaces requiring rollback within T+7d soak | Phase E Day 7 (2026-05-28). `scripts/check-state-schema.py:132` still reads `BRANCH_ISOLATION_ADVISORY_MODE = False` per `git log` on main. No rollback PR opened on `chore/v7-9-rollback` or equivalent | **not_fired** [T1] |

**Resolution:** All 3 kill criteria `not_fired`. v7.9 promotion holds. Advance `docs → complete`.

### §99.2 — B2 post-v7.9 baseline delta table

`make integrity-diff` against the 2026-05-14 platform anchor (per v7.8.6 § MUST-have batch #1), measured 2026-05-28T17:00Z [T1]:

| Metric | 2026-05-14 baseline | 2026-05-28 current | Δ | Verdict |
|---|---|---|---|---|
| `integrity_findings` | 0 | 0 | 0 | ✓ No regression |
| `integrity_advisory` | 4 | 3 | −1 | ✓ Improvement (1 advisory closed during Phase E) |
| `doc_debt_open` | 1 | 1 | 0 | ✓ Stable |
| `features_total` | 70 | 79 | +9 | New feature work continued during Phase E (expected) |
| `features_post_v6` | 36 | 45 | +9 | All 9 new features are post-v6 |
| `fully_adopted` | 3 | 3 | 0 | Stable |
| `fully_adopted_post_v6` | 3 | 3 | 0 | Stable |
| `adoption_pct_post_v6` | 8.3% | 6.7% | −1.6 pp | ⚠ Dilution from +9 features (process, not v7.9) |
| `timing_wall_time_pct_post_v6` | 47.2% | 37.8% | −9.4 pp | ⚠ Same dilution effect |
| `cache_hits_pct_post_v6` | 52.8% | 51.1% | −1.7 pp | ⚠ Same dilution effect |
| `per_phase_timing_pct_post_v6` | 80.6% | 86.7% | +6.1 pp | ✓ Improvement |
| `cu_v2_pct_post_v6` | 19.4% | 31.1% | +11.7 pp | ✓ Improvement (operator backfilling `cu_v2` on new features) |

**Honest framing:** The 3 measured regressions (`adoption_pct`, `timing_wall_time`, `cache_hits`) are **PROCESS regressions** caused by adding 9 new features during Phase E (2026-05-21 → 2026-05-28) without backfilling their adoption metrics. They are NOT v7.9 kill criteria; the kill criteria targeted FALSE POSITIVES and ROLLBACKS, both of which were `not_fired`. Phase E exit (~2026-06-04) is the right time to address the process regressions via an adoption-metric backfill pass — filed as a v7.9.1 follow-up (see §99.4 below). [T1]

### §99.3 — Phase E daily observations log (Days 1-7)

Through Phase E Day 7 (2026-05-28), no unexpected `failure` rows in `gate-coverage.jsonl` for the 3 promoted gates beyond expected legitimate skips (`not_complete_transition`, `not_infra_commit_level`). No operator-driven rollback decisions. The 3 newly-enforced gates DID block several commits during Phase E (each surfaced via auto-isolation flow as designed — including the PR #520 HADF Sub-exp 1A closure workflow today, which correctly fired Mode B on `.claude/shared/hadf/*` infra edits and prompted isolated-worktree creation). [T1]

Cadence-followup milestones executed during Phase E [T1]:

- **B11 (2026-05-22)** — UCC hardening T+3d check executed PASS
- **B8 (2026-05-23)** — UCC T+7d kill-criteria evaluation: `not_fired`
- **B12 (2026-05-27)** — UCC hardening T+7d evaluation: PROMOTE verdict via PR #503 squash `bca2e12`
- **B2 (2026-05-28)** — Post-v7.9 baseline snapshot captured (this case study's primary trigger)

### §99.4 — Lessons recorded

No FT2-FH-NNN-level lessons surfaced through Phase E Day 7. Two minor learnings to flag:

1. **Snapshot script MANIFEST.md checksum ordering bug** — `scripts/snapshot-phase-completion.sh` writes `MANIFEST.md` AFTER `CHECKSUMS.sha256` is generated, so its hash is stale by design. `shasum -c CHECKSUMS.sha256` returns `MANIFEST.md: FAILED` consistently. Cosmetic only; data integrity verified via 6/6 source-file hashes OK. **Filed as v7.9.1 candidate** `F-SNAPSHOT-MANIFEST-CHECKSUM-ORDERING` (~15 min fix: regenerate `CHECKSUMS.sha256` after `MANIFEST.md` is written, or exclude `MANIFEST.md` from the checksum list). [T1]
2. **Adoption-metric dilution discipline** — adding 9 features during a soak window (Days 1-7 of Phase E) without backfilling their adoption metrics caused the 3 measured regressions in §99.2. Worth codifying as a Phase E discipline: "during a soak window, either freeze numerator/denominator OR run backfill in parallel." This isn't a v7.9 framework bug; it's an operational pattern observation. **Filed as v7.9.1 candidate** `F-PHASE-E-ADOPTION-FREEZE-DISCIPLINE` (~30 min spec; documentation-only). [T3]

### §99.5 — v7.10 anchor points

Not committed yet. Per the v7.8 / v7.9 staged-promotion pattern, v7.10 anchor points emerge from observed gaps during Phase E + Phase E exit (~2026-06-04). Will be drafted when v7.9.1 build window opens. Candidate anchor points to be considered at that time:

- Phase E hygiene gates (codify the adoption-freeze discipline from §99.4 lesson 2)
- Snapshot-script integrity hardening (close the cosmetic-bug surface filed at §99.4 lesson 1)
- Whatever v7.9.1 candidates accumulate in `.claude/shared/v7-9-1-candidates.md` between now and 06-04

### §99.6 — Closure timeline

| Event | Timestamp |
|---|---|
| B2 snapshot captured | 2026-05-28T16:30:12Z |
| Integrity-diff measurement (T1 evidence) | 2026-05-28T17:00:00Z |
| §99 synthesis authored | 2026-05-28T17:30:00Z |
| `kill_criteria_resolution` populated (state.json + frontmatter) | 2026-05-28T17:30:00Z |
| State.json advanced `docs → complete` | 2026-05-28T17:30:00Z |
| Phase E exit anticipated | ~2026-06-04 (Day 14) |
| v7.9.1 build window opens | ~2026-06-04 |

**Final status:** v7.9 Promotion Release is `complete`. The `learn` phase continues through Phase E exit, but the feature's PM lifecycle has reached terminal positive closure. Future v7.9.1 build work is tracked separately under the v7.9.1 candidates docket.
