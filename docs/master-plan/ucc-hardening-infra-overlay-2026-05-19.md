# UCC Hardening × Infra Master Plan — Risk Overlay (2026-05-19)

> **Status:** OPEN · paused at Phase 2 (Tasks generated, awaiting operator approval)
> **Source artifacts:** [design spec](../superpowers/specs/2026-05-19-ucc-passkey-security-hardening-design.md) · [risk + rollback](./ucc-passkey-security-hardening-risk-assessment-2026-05-19.md) · [delta PRD](../../.claude/features/ucc-passkey-auth-security-hardening/prd.md) · [tasks](../../.claude/features/ucc-passkey-auth-security-hardening/tasks.md)
> **Overlay scope:** Maps the hardening work against [`infra-master-plan-2026-05-12.md`](./infra-master-plan-2026-05-12.md) — risks introduced, mitigations available, calendar interactions.

## TL;DR

The hardening is **product code** (auth path on `fitme-story.vercel.app/control-room/*`), not framework infra — so the §3.5 Calibration Protocol's mandatory 22-day window does NOT apply. But it has **9 interactions** with the infra calendar that need to be tracked. None are blocking; 3 are timing-sensitive (R1 / R2 / R6); 2 require explicit acknowledgment in the post-merge case study (R3 / R5).

## Calendar Position

```
2026-05-19  PR #410 open (Phase 0 prep)         ← we are here
2026-05-20  Target ship (Phase 1-4 execution)   ← +1 day
2026-05-21  v7.9 PROMOTION DECISION (infra)     ← +2 days; freeze
2026-05-22  UCC hardening T+3d check (B11)      ← +3 days
2026-05-23  Parent UCC T+7d kill-criteria (B8)  ← +4 days
2026-05-28  Parent UCC Part 8 flip eligible     ← +9 days
2026-06-04  v7.10 promotion window opens        ← +16 days
```

The hardening + the v7.9 promotion decision share **2026-05-20 → 2026-05-23** as their joint write/measurement window. They are independent code-wise, but operator attention overlaps.

## Risk Register

### R1 — v7.9 freeze window collision (HIGH timing risk)

**What:** Per infra plan §2.1, the v7.9 promotion decision date is 2026-05-21 (T-2 days). Per spec §0, hardening must merge by 2026-05-20 EOD to be live for the parent UCC T+7d checkpoint on 2026-05-23.

**Why it's real:** The hardening adds an auth-path change. If it merges 2026-05-21+, it would (a) miss the parent's T+7d evaluation window, and (b) ship during the v7.9 freeze — which doesn't block product code but adds operator attention overhead on the day of the promotion decision.

**Mitigation:**
- If we slip past 2026-05-20 EOD: target 2026-05-22 instead (post v7.9 freeze, before B11). Pushes the T+7d UCC checkpoint to evaluate parent-only metrics (still meaningful).
- The v7.9 decision evaluates **framework gates**, not auth-path latency. The hardening cannot corrupt v7.9 calibration data because it writes to Redis (operational), not to `gate-coverage.jsonl` (framework telemetry).

**Severity:** HIGH (calendar) but NOT data-integrity. Decision: ship by 2026-05-20 EOD if possible, accept slip to 2026-05-22 with explicit operator buy-in.

### R2 — UCC T+7d checkpoint interaction (MEDIUM, observability)

**What:** Per [`must-have-cadence-followups.md`](.claude/shared/must-have-cadence-followups.md) B8, the parent UCC `ucc-passkey-auth` T+7d kill-criteria checkpoint is 2026-05-23. The hardening is live for ~3 of those 7 days.

**Why it's real:** The parent checkpoint measures cutover success (`auth_passkey_register_started`, `auth_signin_success`, etc.). If a legitimate failure happens, the hardening's lockout might mask the underlying cause — e.g., a stuck Redis would trigger `auth_lockout_blocked_attempt` and look like an attack rather than infra failure.

**Mitigation:**
- The parent's T+7d evaluation document MUST explicitly note: "hardening was live for {N} of {7} days; lockout events should be reviewed for cause separately from cutover signals."
- Spec §11 already requires `auth_lockout_triggered` count review.
- B8 owner: operator (you) — flag this when running B8.

**Severity:** MEDIUM. Mitigation is procedural (acknowledge in the eval doc).

### R3 — Mechanism A telemetry impact (LOW, framework boundary)

**What:** Per infra plan §6.1 + §3.5.1, Mechanism A emits to `.claude/logs/gate-coverage.jsonl`. The hardening adds new audit events that write to Redis (`ucc:audit-log:events`), not to `gate-coverage.jsonl`. No Mechanism A contamination.

**Why it's real:** The hardening's new events MIGHT eventually feed `framework-status-weekly.yml` if OQ-4 is honored. That's a separate follow-up PR, not this enhancement.

**Mitigation:**
- Spec §10 OQ-4: "Should `auth_lockout_blocked_attempt` events be elevated to `framework-status-weekly.yml` for trend tracking? YES — add to the weekly digest in a follow-up PR; out-of-scope for the hardening merge itself."
- Tracking: open as a v7.9.1+ candidate after merge.

**Severity:** LOW. No framework data corruption; just defers an observability ask.

### R4 — Cross-repo state sync (LOW, mechanical)

**What:** Per infra plan §1 + v7.8.3 cross-repo state-sync, FT2 owns `state.json` (state_owner=ft2) while fitme-story owns the auth code. The hardening updates state.json in FT2 (this PR #410) and auth code in fitme-story (the future T22 PR).

**Why it's real:** Three state.json mutations during execution:
1. Phase 1 → Phase 2 (tasks generated) — already happened today
2. Phase 2 → Phase 3 (implementation start) — pending operator approval
3. Phase 3 → 4 (test/merge) — sequence-of-mutations on the same branch

Each mutation triggers `PHASE_TRANSITION_NO_LOG` + `PHASE_TRANSITION_NO_TIMING` + `BRANCH_ISOLATION_VIOLATION_MODE_C` gates.

**Mitigation:**
- Branch already aligned with `state.json::branch = feat/ucc-passkey-security-hardening` (T+0 work today already proved this).
- `scripts/append-feature-log.py` invocation is automated by the pm-workflow skill on every transition.
- D-1 reverse-sync GHA in fitme-story handles state.json mirror.

**Severity:** LOW (mechanical, gates handle it; operator just needs to invoke the skill at transitions).

### R5 — Parent UCC Part 8 break-glass interaction (LOW, future)

**What:** Per infra plan §1.3, parent UCC Part 8 (flip `UCC_AUTH_MODE=passkey`, drop `DASHBOARD_USER`/`DASHBOARD_PASS`) is gated 2026-05-28+. The hardening adds layers UNDER `UCC_AUTH_MODE=both`.

**Why it's real:** Hardening assumes `UCC_AUTH_MODE=both` (operator can still fall back to basic-auth). When Part 8 flips to `passkey` only, the allowlist + lockout layers will be the SOLE gate. A lockout misconfig at that point could lock the operator out entirely.

**Mitigation:**
- Spec §7.4 nuclear rollback path: flip `UCC_AUTH_MODE` back to `basic` (still works because Part 8 hasn't flipped yet).
- After Part 8 flips: nuclear rollback requires manual Redis edit. Document this in Part 8 runbook as a Part-8 follow-up.
- B9 (in cadence-followups) already tracks Part 8 with the 2026-05-28+ gate.

**Severity:** LOW currently (Part 8 is 9+ days away); MEDIUM after 2026-05-28 (revisit rollback procedure).

### R6 — Preservation branch cleanup (LOW, hygiene)

**What:** Branch `chore/ssd-migration-preserve-2026-05-19` on origin (`01b9366`) carries the same 4 files now committed on `feat/ucc-passkey-security-hardening`. Hash parity confirmed today.

**Why it's real:** The preservation branch is now redundant. Leaving it open clutters origin and could confuse a future operator about where the canonical work lives.

**Mitigation:**
- After PR #410 merges, delete `chore/ssd-migration-preserve-2026-05-19` from origin.
- Until merge, leave the preservation branch as a safety net.

**Severity:** LOW. Hygiene-only.

### R7 — Preflight heuristic false-positive (LOW, framework bug)

**What:** `make preflight WORK_TYPE=enhancement FEATURE=<name>` blocks on `enhancement_parent` because it checks the enhancement feature itself for a parent-PRD, not the parent referenced by `state.json::parent_feature`. Worked around today by writing a thin "delta PRD" for the enhancement.

**Why it's real:** This false-positive will block every future enhancement using the v7.8.6 preflight protocol. The delta-PRD workaround is OK for now but obscures the heuristic bug.

**Mitigation:**
- File as v7.9.1 candidate: `scripts/preflight.py` enhancement_parent check should resolve `state.json::parent_feature` and check THAT feature.
- Add to Observed Patterns Catalog (`make observed-patterns`) so the next operator knows it's a known false-positive.
- The delta-PRD itself is real content (lists primary/secondary/guardrail metrics + kill criteria), so it's not pure ceremony.

**Severity:** LOW. Workaround is in place; durable fix queued.

### R8 — Mechanism A telemetry sparseness on new SSD (LOW, calibration)

**What:** Per earlier sweep, `.claude/logs/gate-coverage.jsonl` was reset to 66 rows on the new X10 Pro (SSD migration was a fresh `git clone`; gitignored ledger didn't transfer). The hardening's own gate firings during Phase 3 execution will look "anomalous" against a near-empty cumulative file.

**Why it's real:** v7.9 promotion criterion #1 ("Coverage emitted") reads `gate-coverage.jsonl`. The pre-migration data IS preserved off-SSD (`~/Documents/FitTracker2-backups/...`) but isn't in the live file.

**Mitigation:**
- The 14-day calibration archive is preserved in 3 forms (full 05-15 ledger + daily summaries + on-SSD snapshots dir). v7.9 decision can pull from these.
- The hardening's gate firings on its own commits add to the post-migration stream; this is normal accumulation.
- No action required for hardening — this is a framework-side concern logged in the earlier sweep.

**Severity:** LOW. Already mitigated by preservation.

### R9 — fitme-story docs-mirror PR #126 timing (LOW, mechanical)

**What:** fitme-story PR #126 (docs-mirror sync from FT2 main @ 1a77b0e) is open. The hardening's eventual fitme-story PR (T22) will modify auth code, NOT the docs mirror. But running prebuild in fitme-story for testing might create a new mirror diff against PR #126.

**Why it's real:** If T22 lands before PR #126, the mirror PR will need a rebase. If PR #126 lands first, T22 starts from a fresher mirror baseline.

**Mitigation:**
- Recommended merge order: **PR #126 first** (docs mirror, mechanical), then T22 (auth code).
- Both PRs touch different parts of the tree (docs mirror = `src/data/`; T22 = `src/lib/auth/` + `src/app/api/auth/`). Conflict-free at the file level.

**Severity:** LOW. Order matters but no blocker.

## Mitigation Summary Table

| Risk | Pre-2026-05-21 action | Post-merge action | Owner |
|---|---|---|---|
| R1 — v7.9 freeze | Ship by 2026-05-20 EOD; accept slip to 2026-05-22 | Document in case study | Operator |
| R2 — T+7d checkpoint | Note hardening live-window in B8 doc | Annotate parent T+7d eval | Operator |
| R3 — Telemetry boundary | None — confirmed clean | Open OQ-4 follow-up PR | Future op |
| R4 — Cross-repo sync | Use `/pm-workflow` for transitions | None — D-1 reverse-sync auto | Skill |
| R5 — Part 8 interaction | None — Part 8 is 9+ days away | Revisit rollback in B9 prep | Operator (2026-05-28) |
| R6 — Preservation branch | Leave as safety net | Delete `chore/ssd-migration-preserve-2026-05-19` from origin | Operator |
| R7 — Preflight heuristic | Workaround via delta-PRD (done) | File v7.9.1 PR for `scripts/preflight.py` | Future op |
| R8 — Telemetry sparseness | None — already preserved | None — accumulation resumes | (Auto) |
| R9 — Docs-mirror order | Merge PR #126 before T22 | None | Operator |

## Calibration Protocol Applicability

Per infra plan §3.5, **framework infrastructure** must walk a 22-day calibration (5 phases). The hardening is **product code** and does NOT need this — but the spirit (advisory ship → measure → enforce) applies via:

- **Phase A (Specify):** ✓ Spec + risk-assessment + delta-PRD + tasks already exist
- **Phase B (Ship advisory + measure):** The hardening ships **enforced from day one** (auth path can't be advisory — either the gate is on or off). The "measure" surface is spec §11 (signals to monitor).
- **Phase C (Calibration gate):** spec §11 T+7d kill-criteria check (2026-05-23) IS the calibration gate
- **Phase D (Promotion decision):** N/A — no advisory → enforced flip
- **Phase E (Post-promotion validation):** 7 days of monitoring per spec §11 signals

**Net mapping:** the hardening compresses §3.5's 22-day cycle into a 7-day live-and-monitor cycle, justified because it's product code (not framework gates that could corrupt other gates).

## Layer Stacking Rule Check

Per §3.5.2: "No new layer of framework infrastructure may be BUILT on top of a layer that hasn't reached Phase E."

The hardening builds on:
- ✓ `ucc-passkey-auth` (parent, complete 2026-05-07; T+12d as of today; post Phase E)
- ✓ `ucc-passkey-auth-audit-log-redis-fix` (sibling, in implementation; provides audit-log infra; not gating)
- ✓ Existing Upstash Redis (operational, not framework)
- ✓ v7.8.x framework gates (advisory; the hardening doesn't add gates, just consumes them)

**No layer-stacking violation.**

## Save Progress State (2026-05-19 ~20:00 UTC)

| Artifact | Status | Path |
|---|---|---|
| Phase 0 design spec | Shipped (PR #410) | `docs/superpowers/specs/2026-05-19-ucc-passkey-security-hardening-design.md` |
| Phase 0 risk + rollback | Shipped (PR #410) | `docs/master-plan/ucc-passkey-security-hardening-risk-assessment-2026-05-19.md` |
| Companion dev-env audit | Shipped (PR #410) | `docs/research/2026-05-19-dev-env-audit-stability-and-scale.md` |
| Delta PRD (Phase 1 stub) | Written today | `.claude/features/ucc-passkey-auth-security-hardening/prd.md` |
| Task breakdown (Phase 2) | Written today | `.claude/features/ucc-passkey-auth-security-hardening/tasks.md` |
| state.json::tasks[] | Populated (26 tasks) | `.claude/features/ucc-passkey-auth-security-hardening/state.json` |
| Tier 2.2 log | Updated (2 events) | `.claude/logs/ucc-passkey-auth-security-hardening.log.json` |
| **Infra overlay (this doc)** | Written today | `docs/master-plan/ucc-hardening-infra-overlay-2026-05-19.md` |

## Resume Path

When the operator returns:

1. **Read this doc + tasks.md** — understand the 26-task scope
2. **Read state.json::tasks[]** — pick ready (no-deps) tasks first: T1, T2, T3, T4, T18, T19
3. **Invoke `/pm-workflow ucc-passkey-auth-security-hardening`** — skill resumes from `current_phase: tasks`
4. **Approve Phase 2 → Phase 3 transition** — skill writes phase_approved event + bumps current_phase to `implementation`
5. **Execute tasks** in P-core → E-core → operator order per `tasks.md` critical path
6. **Merge T22 by 2026-05-20 EOD** if possible; accept 2026-05-22 slip per R1 mitigation
