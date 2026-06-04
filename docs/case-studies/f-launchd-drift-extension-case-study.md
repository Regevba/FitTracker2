---
slug: f-launchd-drift-extension
title: "F-LAUNCHD-DRIFT-EXTENSION — Cron-context phantom-finding suppression"
date_written: 2026-06-04
framework_version: v7.9.1
work_type: Feature
work_subtype: framework_feature
case_study_type: shipped
tier_tags_required: true
status: shipped
case_study: docs/case-studies/f-launchd-drift-extension-case-study.md
case_study_showcase: ""
related_prs: []
dispatch_pattern: serial
success_metrics:
  - name: phantom_findings_per_cron_run
    baseline: 319
    target: 0
    significance: blocking
    review_at: 2026-06-11
    tier: T1
    note: "(T1) Baseline observed 2026-05-24 daily cron: 319 spurious BROKEN_PR_CITATION + PR_NUMBER_UNRESOLVED findings from one launchd-context auth failure. Target: 0 phantoms; replaced by ONE PR_CACHE_REFRESH_FAILED advisory. Verified via T+7d cron observation."
  - name: silent_broken_cron_days
    baseline: 5
    target: 0
    significance: blocking
    review_at: 2026-06-18
    tier: T2
    note: "(T2) Pre-fix: 2026-05-19 SSD migration → cron silently broken for 5 days. Post-fix: precheck_cron_context() exits 78 (EX_CONFIG) on auth failure; launchctl list <label> shows real LastExit code — observability restored within 1 cron interval."
  - name: unit_test_coverage_passing
    baseline: 0
    target: 16
    significance: descriptive
    review_at: 2026-06-04
    tier: T1
    note: "(T1) Test suite at scripts/tests/test_launchd_drift_extension.py covers 16 cases across all 3 surfaces. Measured: 16/16 pass in 0.05s."
kill_criteria:
  - "Flag mechanism mis-fires and skips PR-citation checks for ordinary interactive sessions — operators lose visibility into real findings."
  - "Cron-context detection uses an unreliable signal that breaks when launchd label format changes — Apple has changed env vars before."
  - "Flag file accumulates without cleanup, eventually skipping checks indefinitely — staleness threshold (1h) must be respected."
kill_criteria_resolution: "All 3 mitigated by design. (1) `_is_cron_context()` checks 3 independent signals (LAUNCHD_LABEL / CRON_CONTEXT=1 / XPC_SERVICE_NAME pattern); interactive sessions test all-false and never trigger the flag-write or the gate-skip. Test `test_is_cron_context_interactive_default` enforces. (2) Three independent signals provide redundancy; if Apple removes LAUNCHD_LABEL, CRON_CONTEXT=1 manual override remains usable in the plist. Test `test_is_cron_context_unrelated_xpc_ignored` guards against XPC misidentification. (3) 1h TTL on the flag (REFRESH_FAILED_FLAG_TTL_SECONDS=3600); `pr_cache_refresh_failed_recently()` returns False for stale flags. Test `test_flag_stale_returns_false` enforces."
primary_metric: "phantom_findings_per_cron_run = 0 (T1, measured at T+7d cron observation)"
predecessor_case_study: docs/case-studies/f16-try-repo-harness-case-study.md
spec: ".claude/shared/v7-9-1-candidates.md F-LAUNCHD-DRIFT-EXTENSION + docs/master-plan/post-v7-9-candidate-plan-2026-05-20.md E-14"
key_numbers:
  baseline_phantom_findings: "319 (T1, 2026-05-24 cron capture)"
  silent_broken_cron_days_prefix: "5 (T2, 2026-05-19 → 2026-05-24)"
  unit_tests_passing: "16/16 in 0.05s (T1)"
  sub_fixes_shipped: "2 of 3 — (b) + (c); (a) deferred to follow-on PR"
  flag_ttl_seconds: 3600
  detection_signals: "3 independent (LAUNCHD_LABEL / CRON_CONTEXT=1 / XPC_SERVICE_NAME)"
---

## TL;DR (T1 unless tagged)

The 2026-05-24 daily cron run produced 319 (T1) phantom `BROKEN_PR_CITATION` + `PR_NUMBER_UNRESOLVED` findings — every PR cite in every shipped case study looked broken because the launchd-context `gh` CLI couldn't reach the macOS keychain, leaving `.cache/gh-pr-cache.json` empty. The same context had silently broken cron for 5 days (T2) starting 2026-05-19 after the SSD migration. Both incidents shared one root cause: cron context is a meaningfully different execution environment, and the system was treating it like an interactive shell.

This PR ships sub-fixes (b) + (c) of the 3-part F-LAUNCHD-DRIFT-EXTENSION plan. Sub-fix (a) — promoting `BRANCH_ISOLATION_LAUNCHD_DRIFT` advisory to validate plist path resolution — is deferred to a follow-on PR per spec §3 ("any subset can ship independently"). Sub-fixes (b) + (c) cooperate to make cron failures **loud and bounded** instead of silent and amplifying.

## What changed

Three cooperating scripts, one new test file, two doc updates.

**`scripts/ensure-pr-cache-fresh.py`** — added `_is_cron_context()` returning True if any of `LAUNCHD_LABEL` (launchd-set), `CRON_CONTEXT=1` (manual override), or `XPC_SERVICE_NAME` containing both `fittracker` and `daily`. When refresh subprocess fails AND cron context detected, calls `_write_failure_flag(reason)` writing `.claude/shared/pr-cache-refresh-failed.flag` as JSON (`{ts, reason, context}`). The flag-write itself is best-effort — `OSError` is swallowed so the script's existing exit-1 behavior remains the only failure signal for the caller.

**`scripts/integrity-check.py`** — added module-level `pr_cache_refresh_failed_recently()` returning `(skip_pr_gates: bool, payload: dict | None)`. Reads the flag if present, parses `ts`, returns True iff age ≤ 1h (T1, `REFRESH_FAILED_FLAG_TTL_SECONDS=3600`). When `build_snapshot()` sees `skip_pr_gates=True`, it (a) skips `load_pr_cache()` + `audit_case_study_citations()` entirely, (b) filters `PR_NUMBER_UNRESOLVED` out of per-feature findings, and (c) emits ONE `PR_CACHE_REFRESH_FAILED` advisory (severity=ADVISORY, feature=`_meta`) carrying the failure context. Stale flags (>1h) AND malformed JSON BOTH fall back to "no skip" — kill criterion #3 enforcement so a forgotten flag from a previous cron run can never indefinitely suppress real findings.

**`scripts/daily-integrity-checkpoint.py`** — added `_running_under_launchd()` and `precheck_cron_context()`. The pre-check runs first thing in `main()`. Under cron context + `gh` missing or auth-failed, it exits 78 (`EX_CONFIG` from BSD `sysexits(3)`) — launchd interprets this as "the job is misconfigured" and `launchctl list <label>` shows a real `LastExit` code instead of pretending everything worked. Interactive sessions never trigger this branch; the existing capture-make-outputs flow is unchanged.

**`scripts/tests/test_launchd_drift_extension.py`** — 16 tests across all 3 surfaces. Runs in 0.05s. Covers interactive default, 3 cron-detection signals, unrelated-XPC ignore, JSON well-formedness, reason-length cap, OSError swallow, flag-missing/fresh/stale/malformed reads, and all 4 `precheck_cron_context` outcomes (interactive/no-gh/auth-fail/auth-ok).

**`CLAUDE.md`** — new `## v7.9.1 F-LAUNCHD-DRIFT-EXTENSION sub-fixes (b)+(c)` section explaining the failure mode, the 3 cooperating changes, the failure-mode posture ("fail-safer than status quo"), and pointers to the spec + this case study.

**`.claude/shared/v7-9-1-candidates.md`** — F-LAUNCHD-DRIFT-EXTENSION status updated: sub-fixes (b)+(c) closed, sub-fix (a) remains queued; "Linked PR closing this thread" section now lists shipped files.

## Why this design

Three alternatives were considered:

1. **Force `gh` to work under launchd via `osascript`-driven keychain unlock** — high-friction, requires GUI auth dialog at boot, and the failure mode would still surface as 319 phantom findings if the unlock failed for any reason. Rejected.

2. **Disable PR-citation gates entirely in cron context** — silently suppresses real findings; operator loses observability into a class of real bugs. Rejected.

3. **Sentinel flag + ADVISORY surface (shipped)** — fail-loud-but-bounded. The operator sees exactly ONE clearly-labeled advisory (`PR_CACHE_REFRESH_FAILED`) with the failure timestamp + reason + context, instead of either silent suppression or 319 phantoms. The 1h TTL ensures the flag cannot accumulate.

## Verification

```bash
# Local syntax check passes for all 3 modified scripts:
python3 -c "import py_compile; \
  py_compile.compile('scripts/ensure-pr-cache-fresh.py', doraise=True); \
  py_compile.compile('scripts/integrity-check.py', doraise=True); \
  py_compile.compile('scripts/daily-integrity-checkpoint.py', doraise=True)"
# Output: (clean, no errors)

# Unit test suite passes:
pytest scripts/tests/test_launchd_drift_extension.py -q
# Output: 16 passed in 0.05s
```

Fault-injection verification (operator-driven, not automated): `CRON_CONTEXT=1 python3 scripts/ensure-pr-cache-fresh.py` with `gh` removed from PATH writes the flag; subsequent `make integrity-check` reports exactly 1 `PR_CACHE_REFRESH_FAILED` advisory and 0 phantom citation findings.

## Open follow-ups

- **Sub-fix (a)** — extend `check_branch_isolation_launchd_drift()` advisory to validate plist `WorkingDirectory` path + `ProgramArguments[0]` script path + `StandardOutPath` writability. Catches the 2026-05-19 SSD-migration drift class on day 1. Estimated ~1h; tracked in [`.claude/shared/v7-9-1-candidates.md`](../.claude/shared/v7-9-1-candidates.md) F-LAUNCHD-DRIFT-EXTENSION.
- **T+7d verification (2026-06-11)** — confirm one full daily-cron cycle has run cleanly with the new flag mechanism. Inspect `.claude/shared/integrity-checkpoint-ledger.jsonl` for any `PR_CACHE_REFRESH_FAILED` advisories (expected: 0 in normal conditions; ≥1 only if cron auth genuinely failed).
- **fitme-story showcase MDX (slot 47)** — deferred to companion agent per operator directive (FT2-only this session).

## References

- Spec: [`.claude/shared/v7-9-1-candidates.md`](../.claude/shared/v7-9-1-candidates.md) F-LAUNCHD-DRIFT-EXTENSION
- Master plan: [`docs/master-plan/post-v7-9-candidate-plan-2026-05-20.md`](../master-plan/post-v7-9-candidate-plan-2026-05-20.md) E-14
- Predecessor: [`docs/case-studies/f16-try-repo-harness-case-study.md`](f16-try-repo-harness-case-study.md)
- W11.b pattern: [`.claude/integrity/observed-patterns.md`](../../.claude/integrity/observed-patterns.md) §W11.b
- 2026-05-24 incident: 319 phantom findings (T1, integrity-checkpoint-ledger row `2026-05-24`)
- 2026-05-19 SSD-migration drift: 5 silently-broken cron days (T2, manually verified via plist comparison)
