# Integration Spec — w9-drift-triggered-auto-isolation (Phase 3b, no UI)

Technical contracts for the Phase 1 (drift-reactive) slice. Phase 2 contracts are sketched at the end (built later behind the advisory flag).

## 1. Components & file footprint (Phase 1)

| Component | File | New/changed |
|---|---|---|
| Isolation primitive (T1) | `scripts/w9_auto_isolate.py` | new module + `isolate_current_work()` API |
| W9 hook escalation (T2) | `scripts/check-branch-drift.py` | changed — add act-on-drift branch |
| Telemetry (T3) | both above → `.claude/logs/gate-coverage.jsonl` | append-only emit |
| Status readout (T5) | `scripts/w9_isolation_status.py` + `Makefile` target `w9-isolation-status` | new |
| Tests (T4) | `scripts/tests/test_w9_auto_isolate.py` | new |
| Docs (T12) | `.claude/integrity/observed-patterns.md` (W9), `.claude/shared/pattern-skill-map.json` | changed |

## 2. Isolation primitive contract (T1)

`scripts/w9_auto_isolate.py::isolate_current_work(reason: str, *, dry_run=False) -> IsolationResult`

**Algorithm (atomic, data-loss-safe — GR4/KC3):**
1. Acquire an exclusive lock at `.claude/_session-state/w9-isolate.lock` (O_CREAT|O_EXCL). If held → return `result=skipped, reason=lock_contended` (do NOT block; fall back to W9 warn-only).
2. Capture pre-state: current branch, HEAD sha, `git status --porcelain` (dirty?).
3. If working tree is **clean** → nothing to protect; return `result=noop, reason=clean_tree`.
4. `git stash push -u -m "w9-auto-isolate <ts>"` — capture the stash ref. **If stash fails → abort, release lock, return `error` (never proceed on a failed stash).**
5. Create/adopt the isolated worktree for the active feature via the existing `scripts/create-isolated-worktree.py` contract (idempotent, adopt-existing). Worktree path from smart-directory selection; register lease in `.claude/shared/agent-leases.json`.
6. In the new worktree: `git stash apply <ref>` (apply, not pop — keep the stash as a recovery copy until success is confirmed).
7. Verify apply succeeded + tree matches pre-state digest. **On success:** `git stash drop <ref>`, release lock, return `result=isolated, worktree=<path>`. **On any failure:** leave the stash intact (recoverable), restore original branch, release lock, return `error` with the stash ref in the message.

**Invariant:** uncommitted work is recoverable at every step (stash is never dropped until the apply is verified). This is the GR4 guarantee and is the primary thing T4 tests.

**Return type** `IsolationResult{result: isolated|noop|skipped|error, reason, worktree, stash_ref}`.

## 3. W9 hook escalation contract (T2)

In `scripts/check-branch-drift.py`, after drift is detected (HEAD changed vs the per-session recorded branch):

```
drift_detected AND working_tree_dirty:
    if env CLAUDE_W9_DISABLE_DRIFT_CHECK: emit telemetry(skipped, reason=disabled); warn-only (current behavior)
    elif isolation_opt_out(active_feature): emit telemetry(skipped, reason=opt_out); warn-only
    elif env CLAUDE_W9_AUTO_ISOLATE == "1":          # advisory-first: act only on explicit opt-in
        res = w9_auto_isolate.isolate_current_work(reason="w9_drift")
        emit telemetry(checked, outcome=res.result)
        print recovery/outcome notice
    else:                                            # default advisory: OFFER, don't act
        emit telemetry(candidate, reason=offer_not_acted)
        print the EXACT pre-filled isolation command + the existing 4-step playbook
```

Backward-compatible: with no env set, behavior is the current W9 warn + now also a pre-filled isolation command. Acting requires `CLAUDE_W9_AUTO_ISOLATE=1` until the T+7d promotion.

## 4. Telemetry schema (T3) — `gate-coverage.jsonl` Mechanism A

```json
{"gate": "w9.auto_isolate", "ts": "<ISO>", "candidates": 1, "checked": 0, "skipped": 1,
 "skip_reasons": ["offer_not_acted"], "outcome": "offer", "drift": {"from_branch": "...", "to_branch": "..."}}
```
- `candidates` = drift events seen; `checked` = isolations attempted; `skipped` = warn-only/offer/opt-out/disabled.
- Mirrors the existing Mechanism A row shape so `scripts/refresh-gate-last-fired.py` + weekly scans pick it up with no extra wiring.

## 5. Env vars / escape hatches

| Var | Effect |
|---|---|
| `CLAUDE_W9_DISABLE_DRIFT_CHECK=1` | existing — disables W9 entirely (no detection, no isolation) |
| `CLAUDE_W9_AUTO_ISOLATE=1` | new — opt in to acting (advisory→enforced makes this default at T+7d) |
| `state.json::isolation_opt_out` (+ reason) | existing — per-feature opt-out; honored (warn-only) |

## 6. Error handling / failure posture

- Lock contended → warn-only (never two isolations racing — addresses the self-race risk).
- Stash failure → abort, no worktree created, original state intact.
- Worktree create failure → stash preserved, original branch restored, `error` returned, operator sees the stash ref.
- **Fail-safe principle:** any error path leaves the repo no worse than current W9 warn-only behavior, with uncommitted work always recoverable.

## 7. Backward compatibility

- No change to existing path-based `BRANCH_ISOLATION_VIOLATION` Mode B/C (N4).
- W9 detection logic unchanged; only a new post-detection branch is added.
- Default (no new env) = current behavior + a pre-filled command line. Zero behavior change until explicit opt-in, then promotion.

## 8. Phase 2 contracts (sketch — built later, advisory)

- `scripts/w9_auto_isolate.py::another_session_live(ttl_seconds) -> bool` reads `agent-leases.json`, returns true if a non-self lease's heartbeat is within TTL.
- Concurrency-gated extension of `BRANCH_ISOLATION_VIOLATION` runs in ADVISORY mode (telemetry only) until the v7.9 4-criteria calibration at T+14d.
- First-edit trigger hook fires `another_session_live()` before the first non-infra Edit/Write.
