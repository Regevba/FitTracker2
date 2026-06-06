# PRD — w9-drift-triggered-auto-isolation

**Status:** draft (Phase 1) · **Work type:** Feature (framework infra) · **Impact tier:** A_high
**Framework version:** v7.9.1 · **Has UI:** no · **Requires analytics:** no
**Author:** Claude Opus 4.8 + operator · **Date:** 2026-06-06
**Backing:** [research.md](research.md) + `state.json::brainstorm` (problem + three-option matrix)
**Approved scope (Phase 0 gate):** phased rollout **Option 1 → Option 2**; Option 3 deferred.

---

## 1. Problem statement

Branch isolation in the framework triggers on **file path** only (`BRANCH_ISOLATION_VIOLATION` Mode B/C, enforced v7.9) and is only **reactively detected** after HEAD has already flipped (W9 alert). There is no trigger keyed on **concurrency** or on **drift-as-a-trigger**, and **non-infra work** (features/enhancements/tasks/chores) has **no proactive isolation at all**. In the operator's dominant workflow — multiple concurrent Claude sessions sharing one SSD checkout — a sibling session's `git checkout` flips the shared HEAD, and an unprotected session's commits land on the wrong branch. Observed 3+ times in a single session (2026-06-05/06), each needing manual recovery.

**JTBD:** *When I run several Claude sessions against one checkout, I want each session's commits to land on its own branch automatically, so I don't have to detect and hand-repair branch drift.*

## 2. Goals / non-goals

**Goals**
- G1. Eliminate manual branch-drift recovery in concurrent-session work.
- G2. Make isolation trigger on **drift** (Phase 1) and **concurrency** (Phase 2), for **all work-types**, not just infra paths.
- G3. Reuse existing machinery (W9 hook, `create-isolated-worktree.py`, `agent-leases.json`); no new bespoke isolation engine.
- G4. Keep solo, single-session workflows friction-free (no isolation when there's no drift and no concurrency).

**Non-goals**
- N1. Option 3 (unconditional always-isolate at SessionStart) — deferred end-state.
- N2. Auto-cleanup/GC of orphaned worktrees — tracked separately (current gap; out of scope here beyond cleanup-on-merge hook if cheap).
- N3. Cross-repo (fitme-story) isolation — FT2-only for this feature.
- N4. Changing the existing path-based Mode B/C triggers (they keep working unchanged).

## 3. Solution overview (phased)

### Phase 1 — Drift-triggered reactive auto-isolation (Option 1)
Extend [`scripts/check-branch-drift.py`](../../../scripts/check-branch-drift.py) (the W9 `PostToolUse:Bash` hook): when it detects HEAD changed between tool calls **AND** the working tree has uncommitted or about-to-commit work, escalate from *warn* to *act* — atomically move the current work into its own worktree via `scripts/create-isolated-worktree.py` (or surface the exact pre-filled command in agent context), then register the lease. Ships **advisory→enforced**: advisory first (prints the isolation command + auto-dispatches only with `CLAUDE_W9_AUTO_ISOLATE=1`), promoted to default-act after the calibration window shows a low false-trigger rate.

### Phase 2 — Concurrency-triggered proactive auto-isolation (Option 2)
On first Edit/Write to non-infra feature code, check `.claude/shared/agent-leases.json` for another **live** lease (freshness TTL) on the same checkout. If concurrency is detected, isolate **before** any drift can occur — extend the `BRANCH_ISOLATION_VIOLATION` auto-isolation flow to all work-types **gated on concurrency**. Because this changes an **enforced** gate, it runs a mandatory **advisory→enforced calibration window** (≥7 days of Mechanism A `{candidates, checked, skipped}` telemetry, 0 false positives) before it acts unprompted — same promotion protocol as v7.9.

**Escape hatches (both phases):** `isolation_opt_out` + `isolation_opt_out_reason` in state.json (honored); env kill-switches following the W9 convention (`CLAUDE_W9_DISABLE_DRIFT_CHECK`, new `CLAUDE_W9_AUTO_ISOLATE`).

## 4. Success metrics

### Primary
| | Metric | Baseline | Target | Source |
|---|---|---|---|---|
| **P1** | Branch-drift incidents requiring **manual** recovery, per parallel-session-day | **3+** (2026-06-05/06, T1 instrumented from this session's git history) | **0** | git reflog / drift-event log |

### Secondary
- **S1.** % of substantive non-infra work sessions that ran isolated when concurrency was present → target ≥ 90% (Phase 2). Source: `agent-leases.json` + session logs.
- **S2.** Auto-isolation **false-trigger rate** (isolations fired with no real drift/concurrency) → target ≤ 10%. Source: new `gate-coverage.jsonl` key `w9.auto_isolate`.
- **S3.** Mean operator actions to recover from a drift event → baseline ~5 manual git ops; target 0 (automated).

### Guardrails (must not degrade)
- **GR1.** Solo single-session start latency — no meaningful regression (isolation must NOT fire without drift/concurrency).
- **GR2.** Worktree count must not grow unbounded — net new auto-worktrees reconcilable to active leases (cleanup keeps pace).
- **GR3.** No regression in existing path-based Mode B/C behavior (existing try-repo fixtures stay green).
- **GR4.** The auto-isolation step must not itself cause data loss (atomic stash→worktree→pop; never drops uncommitted work).

### Leading indicators (≤1 week)
- Phase 1 advisory telemetry shows W9 detecting drift events and emitting the isolation offer; false-trigger rate measurable from `w9.auto_isolate` rows.

### Lagging indicators (30/60/90 day)
- Sustained 0 manual drift recoveries across parallel-session-days; operator does not set the kill-switch.

### Instrumentation plan
- New Mechanism A coverage key `w9.auto_isolate` emitting `{candidates, checked, skipped, skip_reasons}` to `.claude/logs/gate-coverage.jsonl` on every W9 hook fire (Phase 1) and every concurrency-gate evaluation (Phase 2).
- Drift events + auto-isolation outcomes appended to the per-session W9 state + a feature log event.
- `make` readout (e.g. `make w9-isolation-status`) summarizing recent auto-isolations + false-trigger rate.

### Review cadence
- Phase 1 calibration review at **T+7d** after Phase 1 ships (advisory → enforced decision).
- Phase 2 calibration review at **T+14d** after Phase 2 ships (advisory → enforced decision, v7.9-style 4-criteria gate).

### Kill criteria
- **KC1.** If, after Phase 1 ships and the trigger is active, manual drift-recovery incidents do **not** drop toward 0 across a 14-day window → the trigger threshold/axis was wrong; revert to advisory, re-pick the axis.
- **KC2.** If the false-trigger rate (S2) exceeds **25%** over the calibration window, OR the operator sets the kill-switch ≥2 times → isolation is firing where it shouldn't; hold at advisory and narrow the trigger predicate.
- **KC3.** If the auto-isolation step ever loses uncommitted work (GR4 violation) → immediate revert; GR4 is a hard safety stop, not a tunable.

**kill_criteria_resolution** will be recorded at closure (required by `FEATURE_CLOSURE_COMPLETENESS`).

## 5. Risks & mitigations

| Risk | Mitigation |
|---|---|
| **Self-race** — auto-isolating mid-session collides with a concurrent checkout | Atomic `stash → worktree-add → pop` guarded by a lock file; abort + warn (fall back to current W9 behavior) if lock contended |
| **Lease-signal unreliable** (Phase 2) | Freshness TTL on leases; treat stale (> TTL) leases as absent; advisory window measures false-trigger rate before acting |
| **Enforced-gate change** (Phase 2) | Mandatory advisory→enforced calibration (v7.9 4-criteria); single-line revert to advisory |
| **Worktree proliferation** | Phase 1/2 fire only on drift/concurrency (not always); cleanup-on-merge hook if cheap; GR2 monitored |
| **Data loss during stash/pop** | GR4 hard stop + KC3; never operate on a dirty tree without a recoverable stash; test with deliberate dirty-tree fixtures |

## 6. Alternatives considered

Full three-option matrix in `state.json::brainstorm.three_option_matrix`. Option 3 (always-isolate) deferred — friction tax on every solo session + worktree proliferation + SSD disk pressure (the SanDisk Extreme disconnect bug is a known hazard) outweigh the marginal safety over the targeted 1→2 triggers. Re-evaluate Option 3 only if 1→2 prove insufficient.

## 7. Rollout & reversibility

- Phase 1 ships advisory; promote to default-act at T+7d if false-trigger rate ≤ target.
- Phase 2 ships advisory; promote at T+14d via the v7.9 4-criteria gate.
- **Reversibility:** every acting behavior is behind an advisory-mode flag + env kill-switch; revert is a single-line flag flip (< 5 min), matching the v7.9 promotion runbook.
- Mandatory: append the new auto-isolation behavior to the W9 entry in [`observed-patterns.md`](../../integrity/observed-patterns.md) + `pattern-skill-map.json` before closure (§v7.8.5).

## 8. Open questions for PRD gate

1. **Phase 1 acting-default:** ship Phase 1 acting **advisory-first** (offer + `CLAUDE_W9_AUTO_ISOLATE=1` opt-in) then promote at T+7d — confirmed approach? (PRD assumes yes.)
2. **Worktree cleanup scope:** include a cheap cleanup-on-merge hook in Phase 1, or defer all cleanup to the separate worktree-GC track (N2)? (PRD assumes: include only if cheap.)
3. **Concurrency signal (Phase 2):** rely solely on `agent-leases.json` freshness, or also a secondary signal (e.g. `.git/index.lock` / lockfiles)? (PRD assumes leases-only for v1.)
