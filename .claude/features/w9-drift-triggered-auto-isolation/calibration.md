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
