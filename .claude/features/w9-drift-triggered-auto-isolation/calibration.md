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

## 2026-06-28 — T+14d review: DECISION = HOLD AT ADVISORY (option b)

Re-evaluated the four criteria against the **`w9.concurrency`** coverage key
(window: fix-merge 2026-06-14 → +14d).

**Telemetry:** 21 `w9.concurrency` rows across **9 distinct emission days**
(2026-06-14 → 2026-06-26); candidates=21, checked=0, **all 21 skipped with
`no_concurrency`**; **0 `concurrency_offer` events fired**; 0 would-be firings.

| # | Criterion | Verdict |
|---|---|---|
| 1 | ≥7d `w9.concurrency` coverage | ✅ 9 emission days |
| 2 | No false positives | ⚠️ **vacuously true** — 0 offers fired; true-positive path never exercised |
| 3 | No silent skips | ✅ 21/21 genuine `no_concurrency` post-fix |
| 4 | Reversibility | ✅ single env flag |

KC2 false-trigger rate = 0%; KC3 work-loss = none.

**Decision:** all four criteria technically pass, but criterion 2 is satisfied
*vacuously* (the 14-day window contained zero real concurrent-session
collisions, so the auto-isolate trigger was never exercised in the field).
Flipping `CLAUDE_W9_CONCURRENCY_ENFORCE=1` default-on would make the hook's
first-ever unprompted action a production action with no field-validated true
positive, against the KC3 hard-stop on uncommitted-work loss. The advisory
posture already surfaces the warning + pre-filled isolation command at zero
operational cost. **`CLAUDE_W9_CONCURRENCY_ENFORCE` stays default-off (advisory).**

**Re-eval trigger:** not date-gated anymore. Re-open this decision once ≥1 real
`concurrency_offer` row is observed in `gate-coverage.jsonl` (i.e. the trigger
has actually fired on a live sibling session), so criterion 2 can be assessed
on real data rather than vacuously.

## 2026-07-21 — Re-eval triggered (first `concurrency_offer` observed) + telemetry-loss correction

**The re-eval trigger fired and was previously missed.** A forensic audit found a
genuine `w9.concurrency` `concurrency_offer` in main's `gate-coverage.jsonl`:

```json
{"gate":"w9.concurrency","ts":"2026-07-02T18:26:52Z","candidates":1,"checked":0,
 "skipped":1,"skip_reasons":["advisory_concurrency"],"outcome":"concurrency_offer"}
```

This post-dates the 2026-06-28 window (06-14 → 06-26), so the "0 offers / criterion 2
vacuous" basis for the HOLD is **stale**. The offer was emitted only because
`another_session_live()` returned True under the 3600 s TTL at emit time (07-02 also
shows ≥5 concurrent sessions on `chore/w40-reconcile-2026-07-01`), so it is a
plausible true positive — but the leases are ephemeral (reaped), so the criterion-2
lease-freshness audit cannot be reconstructed retroactively for this single event.

**Telemetry-loss correction (why the count was unreliable).** `gate-coverage.jsonl`
is gitignored and was resolved `__file__`-relative, so W9 firings/offers inside
linked worktrees were discarded on `git worktree remove`. Evidence: **44** sessions
ran the concurrency check (`.claude/_session-state/*-w9-concurrency.done`) but only
**37** `w9.concurrency` rows reached main — a 7-session loss; any offer among them is
gone. So the true offer count is **≥1 and undercounted**. Fixed in the companion
commit (`gate_coverage.canonical_ledger_path` → git common worktree) so every
worktree now accumulates into the shared main ledger. See honesty-adjacent memory
`gate-coverage-worktree-telemetry-loss`.

**Verdict: HOLD at advisory — corrected basis, not vacuous.**

| # | Criterion | Verdict (2026-07-21) |
|---|---|---|
| 1 | ≥7d `w9.concurrency` coverage | ✅ met (9 emission days at 06-28 + more since) |
| 2 | No false positives — offers map to a genuinely-live sibling | ⚠️ **n=1** — 1 confirmed offer (07-02), emitted under the live-sibling predicate; lease audit not reconstructable; sample too small for a KC2 false-trigger-rate assessment |
| 3 | No silent skips | ✅ `no_concurrency` / `already_isolated` track real states |
| 4 | Reversibility | ✅ single env flag |

The HOLD continues **not because the detector is vacuous** (it has now fired in the
field) but because **n=1** is insufficient to assess the KC2 false-trigger rate, and
because reliable counting only began with the telemetry-loss fix. **New re-eval
condition:** accumulate ≥5 `concurrency_offer` rows post-fix (reliable count) and
audit their lease-freshness before considering the `CLAUDE_W9_CONCURRENCY_ENFORCE`
default flip. `checked=1` (the acted-isolation firing) remains unreachable in
advisory by design — the calibration signal is the `concurrency_offer` skip-row.
