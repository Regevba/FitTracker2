# Telemetry + soak-window audit — pre-T7.9.0 baseline

**Date:** 2026-05-12 (D-9 before promotion decision 2026-05-21)
**Author:** Claude Opus 4.7 (1M context)
**Purpose:** establish a pre-review baseline of telemetry readiness for the v7.9 promotion decision. Re-run on 2026-05-18 → 20 during T7.9.0 ([FIT-78](https://linear.app/fitme-project/issue/FIT-78)) and diff against this baseline.

## 1. Soak window status (Calibration Protocol Phase B → D)

| Metric | Required | Actual @ 2026-05-12 15:23Z | Status |
|---|---|---|---|
| Telemetry span | ≥7 days | **8.35 days** (2026-05-04T06:58Z → 2026-05-12T15:23Z) | ✅ |
| `gate-coverage.jsonl` entries | — | 1,845 entries / 17 unique gates | ✅ |
| 72h integrity-cycle snapshots | — | 5 snapshots (last 2026-05-12T07-22Z) | ✅ |
| Tier 1.1 weekly snapshots | ≥3 for trend mode | 9 snapshots since 2026-05-03 | ✅ trend-ready |
| Tier 3.2 cycle snapshots | ≥3 for trend mode | 3 cycle snapshots; trend_ready=True | ✅ trend-ready |
| Mechanism C session ledgers | — | 23 sessions / 1,079 events | ✅ |
| Most recent integrity-check baseline | — | 0 findings + 1 advisory (this very session, `CACHE_HITS_AUTO_INSTRUMENTATION_INACTIVE`) | ✅ |

## 2. v7.9 candidate-gate per-gate soak data

5 gates queued for advisory → enforced promotion at 2026-05-21:

| Gate | Real fires | Skips | Candidates checked | First fire | Linear |
|---|---:|---:|---:|---|---|
| `BRANCH_ISOLATION_VIOLATION` (Mode B) | 16 | 26 | 42 | 2026-05-07 14:59 | [FIT-79](https://linear.app/fitme-project/issue/FIT-79) |
| `BRANCH_ISOLATION_VIOLATION_MODE_C` | 10 | 275 | 285 | 2026-05-07 14:58 | [FIT-80](https://linear.app/fitme-project/issue/FIT-80) |
| `FEATURE_CLOSURE_COMPLETENESS` | 16 | 269 | 285 | 2026-05-07 14:58 | [FIT-81](https://linear.app/fitme-project/issue/FIT-81) |
| `ISOLATION_OPT_OUT_REASON_MISSING` | 35 | 250 | 285 | 2026-05-07 14:58 | (already enforced as v7.8.1) |
| `CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT` | 18 | 60 | 78 | 2026-05-11 17:08 | [FIT-83](https://linear.app/fitme-project/issue/FIT-83) |

### 2.1 Skip-reason distribution per gate

```
BRANCH_ISOLATION_VIOLATION:
   26  not_infra_commit_level

BRANCH_ISOLATION_VIOLATION_MODE_C:
  231  not_staged_mode
   30  feature_opt_out
    9  no_expected_branch
    5  no_phase_change

FEATURE_CLOSURE_COMPLETENESS:
  231  not_staged_mode
   25  not_complete_transition
    7  no_case_study_link
    6  no_phase_change

ISOLATION_OPT_OUT_REASON_MISSING:
  250  opt_out_false_or_absent

CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT:
   35  pre_v6
   18  pre_mechanism_c
    7  not_complete
```

**Interpretation:** Skip reasons are well-distributed and expected. The dominant `not_staged_mode` skip for Mode C + FEATURE_CLOSURE_COMPLETENESS is by design — those gates only fire on staged phase-transition commits.

## 3. Tier 1.1 measurement-adoption — latest snapshot (2026-05-12)

```
features_total:        68
features_post_v6:      34
features_pre_v6:       34
fully_adopted:          3   (3/34 post-v6 = 8.8%)
partial_adopted:       26
zero_adopted:          39   (mostly pre-Mechanism-C exempted)
tier_1_1_status:    partial
```

**Worth flagging for T7.9.0:** 8.8% post-v6 full-adoption is low. **Not a v7.9 blocker** (the gate-promotion candidates don't depend on this metric directly), but should inform v7.9.1 / v8.0 backfill scope ([FIT-95 F1](https://linear.app/fitme-project/issue/FIT-95) + [FIT-96 F4](https://linear.app/fitme-project/issue/FIT-96)).

## 4. CI cron health

| Cron | Schedule | Last 5 runs |
|---|---|---|
| 72h integrity-cycle | Every 72h | 2026-05-10 ✅ · 2026-05-08 ✅ · 2026-05-07 ❌ · 2026-05-04 ❌ · 2026-05-01 ❌ |
| Weekly framework-status | Monday 05:00 UTC | 2026-05-11 ✅ · 2026-05-04 ❌ · 2026-04-27 ✅ |

**Status:** all green since 2026-05-08. Earlier failures were the cron-permissions incident, repaired 2026-05-08 via `can_approve_pull_request_reviews` flip + orphan snapshot recovery (see [project_integrity_cycle_recovery_2026_05_08](https://github.com/Regevba/FitTracker2)/...)).

## 5. Real-time advisory finding from this audit session

```
[CACHE_HITS_AUTO_INSTRUMENTATION_INACTIVE]
3d-interactive-framework-flow-diagram:
  session ledgers attribute 8 Read event(s) to this feature
  but state.json::cache_hits[] is empty/absent
```

This advisory firing **right now** is itself validation that the v7.9 promotion logic works: Mechanism C correctly captured 8 Reads, the gate correctly detected drift between session-ledger attribution and `state.json::cache_hits[]`, and v7.9 promotion will close the wedge by promoting `observe-cache-hit.py` to dual-write.

## 6. Promotion-criteria decision matrix (Calibration Protocol Phase D)

| Criterion | Required | Status |
|---|---|---|
| ≥7 days `gate-coverage.jsonl` telemetry under canonical key | YES | ✅ 8.35 days |
| No false positives in soak window | YES | ⚠️ Need close review (§7 below) |
| Calibration data verified clean | YES | ✅ v7.8.5 PR #320 closed key-emission concern |
| Plan + spec reviewed | YES | ✅ via PR #321 (v7.8.5→v8.2 implementation plan §4) |

## 7. T7.9.0 review focus areas (2026-05-18 → 20)

The 5 candidate gates need close examination on these specific concerns:

### 7.1 `BRANCH_ISOLATION_VIOLATION_MODE_C` — sample-size adequacy

- **Real fires: 10** across 285 candidates over 5-day active window
- **Question:** is 10 fires enough to confidently flip to enforced?
- **Action:** review each of the 10 fires; confirm none are false positives (correctly attributed to actual phase transitions from non-feature branches)
- **Recommendation:** if all 10 are true positives, proceed; if any are false, defer to v7.9.1

### 7.2 `CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT` — 23% real-fire rate

- 18 fires / 78 candidates = 23% real-fire rate (highest of the 5)
- **Hypothesis:** fires are correct detections of post-Mechanism-C features missing manual `log-cache-hit.py` invocations
- **Action:** spot-check 5 of the 18 fires; verify state.json::cache_hits[] is genuinely empty AND session ledgers show Reads
- **Recommendation:** if 5/5 are true positives, fire rate is acceptable (we expect this to drop after v7.9 dual-write promotion)

### 7.3 `FEATURE_CLOSURE_COMPLETENESS` — 25 `not_complete_transition` skips

- Skip-reason `not_complete_transition` fired 25 times
- **Question:** is the skip correctly applied (gate should only fire on `current_phase=complete` transitions)?
- **Action:** verify the gate logic — skip should not catch a `complete → complete` no-op transition; should only skip when transition is not to `complete`

### 7.4 `BRANCH_ISOLATION_VIOLATION` Mode B — 16 fires
- 16 fires / 42 candidates = 38% real-fire rate
- Skip-reason `not_infra_commit_level` accounts for the 26 skips — those are commits that touched no infra paths
- **Action:** spot-check 3 of the 16 fires; confirm they're actual infra-path commits from non-feature branches

### 7.5 Cross-gate: Tier 1.1 backfill scope deferral

- 39/68 zero-adopted ↔ partial Tier 1.1 status
- **Not a v7.9 blocker** but should inform v7.9.1 backfill scope
- **Action:** make explicit decision: defer all 39 to v7.9.1 ([FIT-95 F1](https://linear.app/fitme-project/issue/FIT-95))? Or backfill subset before v7.9 ship to lift the adoption baseline?

## 8. Recommendations for v7.9 promotion

Based on this baseline:

| Gate | Confidence | Recommendation |
|---|---|---|
| `BRANCH_ISOLATION_VIOLATION` Mode B | High | PROMOTE on 2026-05-21 |
| `BRANCH_ISOLATION_VIOLATION_MODE_C` | Medium | PROMOTE if T7.9.0 spot-check confirms 10 true positives |
| `FEATURE_CLOSURE_COMPLETENESS` | High | PROMOTE on 2026-05-21 |
| Mechanism A coverage gates | High | PROMOTE on 2026-05-21 (mechanical; already calibrated) |
| Mechanism C session-attribution / `CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT` | Medium-High | PROMOTE if T7.9.0 spot-check of 5 fires confirms true positives |

**Overall verdict from this baseline:** the data is **promotion-ready** subject to the T7.9.0 spot-checks on the 5 specific concerns above. None of the gates show catastrophic failure modes; all show sample sizes adequate for a calibration decision.

## 9. What this audit did NOT do

- Per-fire review of the 60 real fires (10 + 16 + 16 + 18 = 60 across the 4 candidates needing spot-checks). That is the T7.9.0 task itself.
- Backwards-compatibility check against the pre-v7.8.3 gate firings (those were under different canonical key names per PR #185 / #186 schema migration; the post-v7.8.5 corpus is the only valid soak data).
- False-negative analysis (gates that should have fired but didn't). Different methodology — would require synthesizing test fixtures and replaying.

## 10. Auto-instrumentation roadmap

Once this audit's data flows through F17 ([FIT-89 v7.9.1 last_fired_at index](https://linear.app/fitme-project/issue/FIT-89)):

- This 100-line manual analysis becomes an O(1) query
- 2026-08-12 first Data Freshness Audit ([FIT-101](https://linear.app/fitme-project/issue/FIT-101)) becomes possible
- `GATE_COVERAGE_ZERO` meta-check can fire (detects gates that haven't fired in 90 days)
- All downstream calibration decisions (v7.9.1, v8.0, etc.) inherit this infrastructure

This audit is the manual proof-of-concept for what F17 automates.
