# Research & Discovery — w9-drift-triggered-auto-isolation

**Work type:** Feature (framework infra) · **Impact tier:** A_high · **Framework version:** v7.9.1
**Has UI:** no · **Requires analytics:** no
**Docket source:** [`.claude/shared/v7-9-1-candidates.md` → F-W9-DRIFT-TRIGGERED-AUTO-ISOLATION](../../shared/v7-9-1-candidates.md) (PR #646)

---

## 1. What is this solution?

Extend **W9** — today a *reactive* branch-drift **alert** ([`scripts/check-branch-drift.py`](../../../scripts/check-branch-drift.py), a `PostToolUse:Bash` hook that prints a warning + 4-step recovery playbook when HEAD flips between tool calls) — into a **trigger that proactively isolates work into its own git worktree**, for **all work-types** (features / enhancements / tasks / chores), not just infra paths. The goal: in a shared checkout with concurrent agents, each session's commits land where intended even when a sibling session runs `git checkout`.

## 2. Why this approach? (problem it solves)

**System problem (locked framing):** branch isolation triggers today on two signals only:
- **Path** — `BRANCH_ISOLATION_VIOLATION` Mode B/C (enforced v7.9) auto-isolates when staged files match infra globs, or on a `state.json::current_phase` mutation off the feature branch.
- **Reactive detection** — W9 warns *after* HEAD has already flipped.

Neither is keyed on **concurrency** or on **drift-as-a-trigger**, and **non-infra work has no proactive isolation at all**. In the operator's dominant workflow (multiple concurrent Claude sessions sharing one SSD checkout at `/Volumes/DevSSD/FitTracker2`), a sibling's `git checkout` flips the shared HEAD and an unprotected session's commits land on the wrong branch.

**Empirical pain (this very session, 2026-06-05/06):** branch drift struck 3+ times — the #645 CI-fix commit landed on `feature/3d-universe-phase-4c-act1-threshold`; HEAD later flipped to `main` twice; 8 live worktrees + ≥1 concurrent session shared the main checkout. Each recovery was manual: move the commit to the correct branch, restore the sibling's branch, restore HEAD. This is the failure mode the feature eliminates.

## 3. Why this over alternatives? (trigger-threshold trade-off)

See the full three-option matrix in `state.json::brainstorm.three_option_matrix`. Summary:

| Approach | Pros | Cons | Effort | Chosen? |
|---|---|---|---|---|
| **1. Drift-triggered (reactive)** | Smallest surface; extends existing W9 hook + `create-isolated-worktree.py`; no change to the enforced gate; fires rarely | Acts after drift detected (small window); self-race risk during isolation | M | **Recommended Phase 1** |
| **2. Concurrency-triggered (proactive, lease-gated)** | Zero drift window; isolates before first risky edit; solo sessions untouched | Extends an *enforced* gate → mandatory calibration window; needs reliable lease-freshness signal | L | **Recommended Phase 2** |
| **3. Always-isolate (unconditional)** | Drift structurally impossible | Friction tax on every solo session; worktree proliferation + SSD disk pressure; cleanup debt | L | Deferred (end-state, high blast radius) |

**First-principles check:** the load-bearing belief is *"isolation must be triggered by file-path risk."* Evidence for it = convention (the gate was built path-first). Re-deriving without it: the real invariant is *"a session's commits must land on its intended branch"* — which is violated by **concurrency**, independent of path. So the path-only trigger is the wrong axis for the operator's workflow; concurrency/drift is the right axis. This validates reframing the trigger.

**Recommendation captured for the gate, not pre-ranked in the matrix:** ship as a **phased rollout — Option 1 (reactive) then Option 2 (proactive)** — rather than picking one. Option 3 stays the deferred end-state. Operator picks the rollout scope at the PRD gate.

## 4. External sources / prior art

- **git worktrees** — the native primitive for N private working trees over one object store; the correct isolation mechanism (vs clones). `superpowers:using-git-worktrees` skill + `scripts/create-isolated-worktree.py` already wrap it with smart-directory naming + lease registration.
- **Pattern reference (reactive→proactive):** the framework's own `BRANCH_ISOLATION_VIOLATION` auto-isolation flow (v7.8.1) is the proven dispatch path to reuse.
- **Lease model:** `.claude/shared/agent-leases.json` already records per-feature worktree leases — the candidate concurrency signal.
- **Reversibility precedent:** W9 already ships an env kill-switch (`CLAUDE_W9_DISABLE_DRIFT_CHECK=1`); the new triggers inherit the same opt-out discipline.

## 5. "Market" examples (how other tooling isolates concurrent work)

- **CI runners / GH Actions** give every job a fresh checkout — isolation-by-default (Option 3 analog), accepting the setup cost because jobs are ephemeral. Our sessions are long-lived, so unconditional isolation costs more (the Option 3 friction critique).
- **Dev-container / per-task workspaces (e.g. Nx, Bazel sandboxes)** isolate on *task start* when contention is possible — the Option 2 analog (proactive, contention-gated).
- **`git worktree` power-user workflows** isolate reactively when a context switch is needed — the Option 1 analog.

Takeaway: the industry spans all three points; the right pick depends on session lifetime + contention frequency. Our sessions are long-lived and contention is now steady-state → a **targeted trigger (1→2)** beats unconditional (3).

## 6. UI / design

N/A — no UI. Operator-facing surface is stderr notices from the W9 hook + worktree creation logs. "Design" here = integration with existing hooks/gates/config (see matrix `design` rows).

## 7. Data & demand signals

- **3+ drift incidents in a single session** (2026-06-05/06), each requiring manual recovery — the proximate trigger for filing F-W9-DRIFT-TRIGGERED-AUTO-ISOLATION.
- **8 live worktrees + concurrent sessions** are the steady state, not an edge case (operator runs parallel agents by design).
- Prior W9 catalog entry documents the drift class; the recovery playbook exists but is manual — demand is for automation of that playbook.

## 8. Technical feasibility

- **Dependencies already exist:** W9 hook, `create-isolated-worktree.py` (idempotent, adopt-existing), `agent-leases.json`, the `BRANCH_ISOLATION_VIOLATION` auto-isolation flow, the env kill-switch convention.
- **Risks / unknowns (from the matrix `failure_modes`):**
  1. **Self-racing** — auto-creating a worktree mid-session could itself collide with a concurrent checkout. Needs an atomic `stash → worktree-add → pop` with a lock.
  2. **Lease-signal reliability** (Option 2) — stale lease → false isolation; missing lease → missed isolation. Needs freshness TTL.
  3. **Worktree lifecycle** — auto-created worktrees need auto-cleanup (cleanup-on-merge is the current gap).
  4. **Enforced-gate change** (Option 2) — extending `BRANCH_ISOLATION_VIOLATION` to non-infra work-types is a behavior change to an *enforced* gate → mandatory advisory→enforced calibration window per the A_high rule.

## 9. Proposed success metrics (draft — finalized in PRD)

- **Primary:** branch-drift incidents requiring **manual** recovery per parallel-session-day → target **0** (baseline: 3+ on 2026-06-05/06).
- **Secondary:** % of substantive non-infra work sessions that ran isolated when concurrency was present; auto-isolation false-trigger rate (isolations with no real concurrency/drift).
- **Guardrail:** session-start latency must not regress meaningfully for solo sessions; worktree count must not grow unbounded (cleanup keeps pace).
- **Kill criterion (draft):** if drift incidents do **not** drop after the trigger ships, OR false-trigger rate is high enough that the operator disables it (`CLAUDE_W9_*` kill-switch usage), the trigger threshold was wrong → revert to advisory and re-pick the axis.

## 10. Decision (recommended)

Adopt the **system-problem framing** and ship a **phased rollout**: **Phase 1 = Option 1 (drift-triggered reactive auto-isolation)** — lowest risk, reuses existing pieces, no enforced-gate change; **Phase 2 = Option 2 (concurrency-triggered proactive)** behind an advisory→enforced calibration window. **Option 3 (always-isolate)** remains the deferred end-state. Default-on with the existing `isolation_opt_out` / `CLAUDE_W9_*` escape hatches.

**Open question for the operator at this gate:** confirm the phased scope (1→2, defer 3) vs. a different rollout (e.g. ship only Option 1 now and re-evaluate; or go straight to Option 2). This is the Phase 0 → Phase 1 decision.
