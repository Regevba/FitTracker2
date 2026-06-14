# Phase 2 Calibration — concurrency-proactive auto-isolation

**Status at ship:** ADVISORY (telemetry-only). Acting unprompted requires BOTH
`CLAUDE_W9_AUTO_ISOLATE=1` and `CLAUDE_W9_CONCURRENCY_ENFORCE=1`.

Phase 2 (T6–T8) extends the `BRANCH_ISOLATION_VIOLATION` posture with a
concurrency-gated proactive trigger. Because acting unprompted would change
default dispatch behavior for non-infra work, it follows the **v7.9 4-criteria
advisory→enforced** promotion protocol before the `CLAUDE_W9_CONCURRENCY_ENFORCE`
default flips on.

## Promotion criteria (all four required)

| # | Criterion | How measured |
|---|---|---|
| 1 | **Coverage emitted** — ≥7 days of `w9.auto_isolate` rows with `outcome` ∈ {`no_concurrency`, `concurrency_offer`, `already_isolated`} | `make w9-isolation-status` + `gate-coverage.jsonl` grep `concurrency` |
| 2 | **No false positives** — every `concurrency_offer` row maps to a genuinely-live sibling session (not a stale lease) | manual review of the leases at each offer vs `last_heartbeat` TTL |
| 3 | **No silent skips** — `no_concurrency` / `already_isolated` skip reasons track real states, not bugs | skip-reason audit |
| 4 | **Reversibility** — advisory restorable in <5 min | unset `CLAUDE_W9_CONCURRENCY_ENFORCE` (single env flag) |

## Window

- **Opens:** Phase 2 ship date.
- **Review (T+14d):** evaluate the four criteria; if all pass, document the
  decision and either (a) make `CLAUDE_W9_CONCURRENCY_ENFORCE=1` the default in
  the hook, or (b) hold at advisory and narrow the predicate (KC2).
- Tracked in [`.claude/shared/must-have-cadence-followups.md`](../../shared/must-have-cadence-followups.md).

## Kill criteria (inherited from PRD §4)

- **KC1** — if drift incidents don't drop after the trigger ships → wrong axis; revert to advisory.
- **KC2** — false-trigger rate > 25% over the window OR kill-switch used ≥2× → narrow the predicate, hold at advisory.
- **KC3** — any uncommitted-work loss → immediate revert (hard stop; not tunable).

## TTL tuning

`another_session_live(ttl_seconds=3600)` defaults to a 1h lease-freshness TTL.
If criterion 2 shows stale leases triggering false offers, lower the TTL (the
heartbeat cadence of `create-isolated-worktree.py` bounds the floor).

## 2026-06-14 — Calibration INVALIDATED + window RESET (fix/w9-session-id-keying)

A pre-promotion audit (2026-06-14) found the original 2026-06-07 → 2026-06-20
window collected **zero valid Phase-2 telemetry**. Root cause: the once-per-
session marker keyed on `CLAUDE_SESSION_ID`, which Claude Code never sets (the id
is delivered on hook **stdin JSON**). Every session shared the constant
`"default"` marker, so `default-w9-concurrency.done` (written 2026-06-07)
suppressed `concurrency_isolation_decision()` for every later session. The 45
`w9.auto_isolate` rows in the window were ALL from Phase-1 drift (a different
code path, `outcome=offer`), and were themselves near-100% false positives from
the operator's own intentional `git checkout`s (same shared-`default` baseline
bug in `check-branch-drift.py`).

**Fixes shipped (this PR):**

1. Session id resolved via `scripts/w9_session.py` (hook-stdin `session_id`), not the env var.
2. Phase 2 now emits a **distinct gate `w9.concurrency`** (was `w9.auto_isolate`) so the v7.10 `GATE_COVERAGE_ZERO` meta-check can see it independently of Phase-1 drift.
3. Phase-1 drift suppresses intentional checkouts (`evaluate_drift` → `intentional`) so its telemetry reflects real concurrent-session collisions only.
4. Stale leases reaped from `agent-leases.json` (the 2026-05-07 lease was 38d dead).

**Window reset:** the 14-day advisory→enforced clock for `CLAUDE_W9_CONCURRENCY_ENFORCE`
**restarts when this fix lands on main**. Re-evaluate the four criteria against
`w9.concurrency` rows (NOT `w9.auto_isolate`) at fix-merge + 14d. Criterion 1 now
requires ≥7d of genuine `w9.concurrency` rows with `outcome` ∈ {`no_concurrency`,
`concurrency_offer`, `already_isolated`}. Until then: **HOLD at advisory.**
