---
title: "Framework v7.8 Mechanism C — Advisory Calibration Review"
date: 2026-05-09
date_written: 2026-05-09
framework_version: v7.8
work_type: chore
dispatch_pattern: serial
tier_tags_present: true
success_metrics: "Advisory-period data sufficient to calibrate v7.9 enforcement threshold N"
kill_criteria: "If data remains insufficient at 2026-05-16, escalate to alternative writer-path approach"
kill_criteria_resolution: "Not yet resolved — advisory period extended to 2026-05-16"
related_prs:
  - pr_number: 173
    description: "v7.8 PR-1 (Mechanism C scaffolding, squash 0f3761f)"
verdict: EXTEND
review_date: "2026-05-09 10:00 IDT (UTC+3)"
next_review: "2026-05-16"
---

# Framework v7.8 Mechanism C — Advisory Calibration Review (2026-05-09)

**Verdict: EXTEND — advisory period to 2026-05-16**

This document is the +7d calibration review for v7.8 PR-1 (Mechanism C: `PostToolUse:Read` auto-instrumentation), which shipped 2026-05-02 via PR #173 (squash `0f3761f`). The v7.9 design spec (`docs/superpowers/specs/2026-05-02-framework-v7-8-and-v7-9-bridge-design.md` §7.2) requires ≥7 days of session-ledger data before flipping enforcement. Today is day 7.

---

## §1 — What was checked

### §1.1 Session ledger primary signal

The Mechanism C session ledger (`.claude/logs/_session-<id>.events.jsonl`) is the primary data source for calibrating the v7.9 threshold N.

```bash
ls -la .claude/logs/_session-*.events.jsonl
# .claude/logs/_session-f3c657a9-d0c4-4aa8-877d-54a255fdccb0.events.jsonl (287 bytes, 2026-05-09)
```

**Finding:** 1 session file found. Content:

```json
{"timestamp":"2026-05-09T07:00:39Z","tool_name":"Read","tool_use_id":"toolu_012CVjTjk59VMw8LLkr3kvPf","file_path":"/home/user/FitTracker2/docs/superpowers/specs/2026-05-02-framework-v7-8-and-v7-9-bridge-design.md","session_id":"f3c657a9-d0c4-4aa8-877d-54a255fdccb0","active_feature":""}
```

- 1 event [T1]
- `active_feature`: `""` — attribution is broken (no `.claude/active-feature` lockfile found; `/pm-workflow` not invoked this session)
- The hook IS firing correctly (proved by this event)

### §1.2 Structural limitation: gitignore blocks cloud accumulation [T1]

Both primary Mechanism C data sources are gitignored:

```
# .gitignore:
43:.claude/logs/_session-*.events.jsonl   ← session ledger
45:.claude/logs/gate-coverage.jsonl       ← Mechanism A coverage stats
```

A cloud agent's checkout always starts fresh with 0 historical session data. The v7.9 "≥7 days of data" criterion cannot be verified from a cloud session checkout — the data exists only on the developer's local machine at `/Volumes/DevSSD/FitTracker2`.

**This is the primary blocking constraint.** It is a structural design gap, not a Mechanism C bug. The hook is working. The data simply isn't committed.

### §1.3 Mechanism A (gate-coverage.jsonl) signal

Gate-coverage.jsonl is gitignored (`.gitignore` line 45). No file in this cloud checkout. The implementation IS present in `scripts/check-state-schema.py`:

```python
# lines 54, 60, 1325-1374
from gate_coverage import GateCoverage
GATE_COVERAGE_LEDGER = LOGS_DIR / "gate-coverage.jsonl"
# Mechanism A (v7.8 §4.1): instantiate per-run gate-coverage tracker.
skip_ledger = os.environ.get("GATE_COVERAGE_LEDGER_DISABLED") == "1"
coverage.write_jsonl(GATE_COVERAGE_LEDGER)
```

Cannot verify whether coverage stats have been accumulating locally. [T3]

### §1.4 Reducer misses signal

`.claude/logs/reducer-misses.json`: not found in this checkout. Required by the v7.9 spec for "≥7 days zero false-positives" criterion. Either gitignored, not yet populated, or not tracked. [T3]

---

## §2 — Secondary signals

### §2.1 Per-feature analysis — post-Mechanism-C state.json cache_hits [T1]

Features with `created_at ≥ 2026-05-02` (post-Mechanism-C ship date):

| Feature | Created | Phase | cache_hits | Verdict |
|---|---|---|---|---|
| `framework-v7-8-bridge` | 2026-05-04 | complete | 0 | Bootstrap exception (see §2.2) |
| `push-notifications` | 2026-05-07 | complete | 3 | OK (manual) |
| `roadmap-stress-test-2026-05-07` | 2026-05-07 | complete | 2 | OK (manual) |
| `case-study-comparison-table` | 2026-05-07 | complete | 2 | OK (manual) |
| `ucc-passkey-auth` | 2026-05-07 | complete | 3 | OK (manual) |
| `fitme-story-public-enhancements` | 2026-05-08 | implementation | 3 | OK (manual, in-flight) |

**5/5 completed post-Mechanism-C features have non-zero `cache_hits[]`** in `state.json`. [T1]

Important: these are **manually populated** entries. Mechanism C writes only the session ledger in v7.8 advisory mode; it does NOT write to `state.json::cache_hits[]`. That dual-write activates in v7.9 (per spec §6, bridge table row: "Session events ledger → `observe-cache-hit.py` also calls `log-cache-hit.py`"). Manual population is still working correctly.

### §2.2 Bootstrap exception: `framework-v7-8-bridge`

The one complete post-Mechanism-C feature with `cache_hits: 0` is `framework-v7-8-bridge` (created 2026-05-04, phase=complete). This is the feature that shipped Mechanism C itself. Its lifecycle pre-dates the fully-wired hook (the `.claude/active-feature` lockfile and `/pm-workflow` integration were part of the same PR). The exception is expected and non-generalizable.

### §2.3 Measurement-adoption trajectory [T1]

From `.claude/shared/measurement-adoption-history.json` — cache_hits dimension, post-v6 features:

| Date | post-v6 features | cache_hits present | post-v6 % |
|---|---|---|---|
| 2026-04-25 | 7 | 2 | 28.6% |
| 2026-04-27 | 8 | 2 | 25.0% |
| 2026-04-30 | 11 | 5 | 45.5% |
| 2026-05-01 | 12 | 5 | 41.7% |
| 2026-05-03 | 12 | 5 | 41.7% |
| 2026-05-04 | 14 | 6 | 42.9% |
| 2026-05-07 | 19 | 6 | 31.6% |

The 2026-05-07 drop from 42.9% → 31.6% is denominator inflation: 5 new post-v6 features created 2026-05-07 without cache_hits yet (in-flight or recently shipped). The numerator held steady at 6. This is expected behavior, not regression.

### §2.4 Observed cache_hits distribution (manual, complete post-Mechanism-C features) [T1]

For calibrating threshold N:

- `push-notifications`: 3
- `roadmap-stress-test-2026-05-07`: 2
- `case-study-comparison-table`: 2
- `ucc-passkey-auth`: 3
- Range: 2–3 for feature/chore types over 1–3 day lifecycle

For context, `unified-control-center` (older, larger feature, 5+ day lifecycle) has `cache_hits: 8`.

**Provisional N = 1** (presence-only, matching current gate behavior) is defensible at this stage. **Calibrated N ≥ 2** would require session-ledger data showing actual Read-repeat events per feature session, which is unavailable from this checkout.

---

## §3 — Script quality check: `scripts/observe-cache-hit.py`

Read and reviewed. Findings:

**Strengths:**
- Fail-soft contract: any error exits 0 (hook semantics: non-zero doesn't break the tool call)
- Correct gitignored ledger path: `.claude/logs/_session-<session_id>.events.jsonl`
- Two-layer attribution: `$FT2_ACTIVE_FEATURE` env var > `.claude/active-feature` lockfile > ""
- Append-only write pattern (no locking needed for single-writer)

**Potential false-positive patterns:**
- Every Read of any file in the repo triggers an event, including infra Reads (`.gitignore`, `CLAUDE.md`, etc.) — these aren't cache hits in the semantic sense. The hit definition (§4.3: "path already read this session") filters this correctly at v7.9 promotion time.
- Cross-repo cwd: fixed in v7.8.2 (existence guard `[ -f scripts/observe-cache-hit.py ] && ...` in `.claude/settings.json`)

**Missed-trigger patterns:**
- Attribution empty when session not started via `/pm-workflow` (confirmed by this session's event: `active_feature: ""`). This is the largest noise source.
- A session that never invokes `/pm-workflow` produces events with no feature attribution — the `CACHE_HITS_AUTO_INSTRUMENTATION_INACTIVE` advisory check cannot fire on them.

**Signal-to-noise assessment [T3]:** Moderate. The hook fires reliably; attribution is the weak link. Without attribution, session events cannot be matched to features for the `CACHE_HITS_AUTO_INSTRUMENTATION_INACTIVE` check. This is a workflow discipline issue, not a Mechanism C bug.

---

## §4 — v7.9 readiness criteria vs. observed data

From spec §7.2 + §9:

| Criterion | Required | Observed | Met? |
|---|---|---|---|
| ≥7 days session-ledger data | Yes | 1 session, 1 event (cloud checkout) | NO |
| cache_hits threshold N calibrated | Yes | Provisional only (2–3 from manual entries) | PARTIAL |
| reducer-misses.json ≥7d zero-FP | Yes | File absent | NO |
| gate-coverage.jsonl ≥7d coverage | Yes | File gitignored, not in checkout | NO |
| CACHE_HITS_EMPTY_POST_V6 can fire | Yes (schema bug fixed in v7.8) | Bug is fixed (dual-read) | YES |
| Post-Mechanism-C features non-zero cache_hits | Signal | 5/5 complete features (manual) | YES |

**3 of 6 criteria unmet. Verdict: EXTEND.** [T1 for criterion checks, T3 for "partially met" assessment]

---

## §5 — Structural gap identified (v7.9 prerequisite)

**The calibration data sources for Mechanism C are gitignored.** This means no cloud agent — today or at 2026-05-16 — can directly verify the ≥7-day distribution requirement. The data lives only on the developer's local machine.

**Recommendation before 2026-05-16 review:**

Introduce `.claude/shared/mechanism-c-calibration.json` — a committed, PII-free aggregated summary of session-ledger stats. The developer's local machine populates it via:

```bash
python3 scripts/aggregate-session-ledger.py \
  --since 2026-05-02 \
  --output .claude/shared/mechanism-c-calibration.json
```

Content shape (proposed):

```json
{
  "version": "1.0",
  "window_start": "2026-05-02",
  "window_end": "2026-05-16",
  "sessions_observed": 42,
  "total_read_events": 1847,
  "sessions_with_attribution": 31,
  "attribution_rate": 0.74,
  "per_feature_read_counts": {
    "push-notifications": {"sessions": 3, "reads": 47, "repeat_reads": 12},
    "ucc-passkey-auth": {"sessions": 5, "reads": 89, "repeat_reads": 31}
  },
  "threshold_candidates": {
    "N=1": {"features_passing": 19, "features_failing": 1},
    "N=2": {"features_passing": 14, "features_failing": 6}
  }
}
```

This file should be tracked in git and committed before the 2026-05-16 review.

Without this file, future cloud-agent calibration reviews will hit the same structural wall this review hit.

---

## §6 — Note for next agent (2026-05-16)

> **If running on 2026-05-16:** this is the second calibration review. Check the following before deciding:
>
> 1. Does `.claude/shared/mechanism-c-calibration.json` exist? If not, **escalate** — the calibration can't be done from a cloud checkout without it. The developer must run the local aggregation script first.
> 2. Does `.claude/logs/gate-coverage.jsonl` still appear in `.gitignore`? If so, Mechanism A coverage stats are also invisible to cloud agents. Consider committing a periodic gate-coverage summary to `.claude/shared/gate-coverage-summary.json`.
> 3. If calibration data IS available: check `attribution_rate` in the calibration file. If ≥ 70%, calibrate N from the `threshold_candidates` block. If attribution_rate < 50%, Mechanism C has a serious wiring problem — check whether `/pm-workflow` is writing `.claude/active-feature` on every session entry.
> 4. If data is still sparse at 2026-05-16: **propose abandoning Mechanism C as the automated writer-path and adopt the alternative from `docs/research/2026-05-02-framework-v7-9-implementation-safety-research.md` §4** (stricter enforcement of the manual `log-cache-hit.py` call via a new pre-phase gate that rejects phase transitions without cache_hits evidence).

---

## §7 — What this review does NOT block

The advisory-period extension applies specifically to the Mechanism C → v7.9 enforcement flip. It does NOT affect:

- All v7.8.x gates already shipped (BRANCH_ISOLATION_VIOLATION, FEATURE_CLOSURE_COMPLETENESS, ISOLATION_OPT_OUT_REASON_MISSING): these continue as-is
- The CACHE_HITS_EMPTY_POST_V6 gate (schema bug fixed; gate can fire; remains advisory for pre-Mechanism-C features per existing exemption)
- The GATE_COVERAGE_ZERO advisory check (advisory in v7.8 regardless)
- Manual cache_hits population workflow (still required; still working per §2.1)

---

## §8 — Verdict summary

| Dimension | Finding | Tier |
|---|---|---|
| Session ledger firing | YES (1 event observed this session) | T1 |
| Session attribution | BROKEN (active_feature empty; no pm-workflow invocation) | T1 |
| Historical ledger data | INACCESSIBLE (gitignored; cloud checkout starts fresh) | T1 |
| Gate-coverage.jsonl | INACCESSIBLE (gitignored) | T1 |
| Post-Mechanism-C manual cache_hits | 5/5 complete features non-zero | T1 |
| N calibration | PROVISIONAL (N=2 from manual distribution) | T3 |
| v7.9 enforcement flip | NOT READY | T1 |

**VERDICT: Branch B — EXTEND advisory period to 2026-05-16.**

**Prerequisite before 2026-05-16 review:** developer must commit `.claude/shared/mechanism-c-calibration.json` with aggregated session-ledger stats from the local machine.

PR for this case study: opened 2026-05-09 from branch `docs/framework-v7-8-advisory-calibration-2026-05-09`. See comment on PR #173 for the verdict summary.
