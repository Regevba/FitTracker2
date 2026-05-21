# Framework v7.9 Promotion Release — cold-start entrypoint

> One-page summary of v7.9 for any agent or developer arriving cold.
> If you only read one document about v7.9, read this. Then follow the
> "Canonical sources" section to drill in.

**Shipped:** 2026-05-21, single-session enforcement-flip.
**Predecessor:** [v7.8.6 Cadence Batch](framework-v7-8-6.md) (shipped 2026-05-15).
**Successor:** v7.9.1 Test Discipline Foundation (target ship 2026-06-04 → 2026-06-11 per [infra master plan §3.6.3](../../docs/master-plan/infra-master-plan-2026-05-12.md)).

## Why v7.9 exists

Three gates shipped in advisory mode at v7.8.1 (2026-05-07) with a deliberate 14-day Mechanism A telemetry calibration window: every fire writes `{candidates, checked, skipped, skip_reasons}` to `.claude/logs/gate-coverage.jsonl` so the promotion decision rests on observed behavior, not assumed behavior. The window closed 2026-05-21. All four §2.2 promotion criteria were met for all three candidates. v7.9 is the single-line flip that activates blocking enforcement.

The change is intentionally minimal — no new gate code, no new schema fields, no new observability surfaces. The risk surface is the gates themselves (already in production for 14 days emitting telemetry; the flip changes whether their findings land in `errors[]` vs stderr) and the reversibility runbook (single-line revert <5 min).

## What v7.9 ships

| Item | Mechanism | File | Mode |
|---|---|---|---|
| **C-2 (the flip)** | `BRANCH_ISOLATION_ADVISORY_MODE = True → False` controls all 3 gates simultaneously | [`scripts/check-state-schema.py:132`](../../scripts/check-state-schema.py) | The only code change |
| **C-1 CLAUDE.md** | New "v7.9 Promotion Release" section + updated advisory→enforced language on 2 gate descriptions + version chain in header | [`CLAUDE.md`](../../CLAUDE.md) | Documentation |
| **C-3 Cold-start entrypoint** | This file. Mirrors `framework-v7-8-3.md` and `framework-v7-8-4.md` format | `.claude/entrypoints/framework-v7-9.md` | Documentation |
| **C-4 Dev-guide §2.4** | Promoted sub-section captures the enforcement-flip + reversibility runbook + Phase E validation calendar | [`docs/architecture/dev-guide-v1-to-v7-7.md`](../../docs/architecture/dev-guide-v1-to-v7-7.md) | Documentation |
| **C-5 Honesty ledger** | New entry FT2-FH-003 captures the calibration discipline (14-day window + 4-criterion checklist) as a generalizable pattern | [`docs/case-studies/framework-honesty-ledger.md`](../../docs/case-studies/framework-honesty-ledger.md) | Documentation |
| **C-7 Case study** | `framework-v7-9-promotion-case-study.md` with B1 checklist outcomes + decision rationale + Phase E calendar | [`docs/case-studies/framework-v7-9-promotion-case-study.md`](../../docs/case-studies/framework-v7-9-promotion-case-study.md) | Documentation |
| **C-6 Linear epic** | FIT-72 (or next sequential) v7.9-promotion + per-gate sub-issues for trackable post-promotion soak | external (Linear) | Tracking |

## Gates promoted

Single flag → 3 gates flip simultaneously:

| Gate | 14d telemetry | Action |
|---|---|---|
| `BRANCH_ISOLATION_VIOLATION` Mode B (infra commit-level) | 18 rows, 0 zero-candidate, all skips = `not_infra_commit_level` | Advisory → Enforced |
| `BRANCH_ISOLATION_VIOLATION` Mode C (per-state.json mutation) | 13 rows, 0 zero-candidate | Advisory → Enforced |
| `FEATURE_CLOSURE_COMPLETENESS` write-time | 13 rows, 0 zero-candidate, all skips = `not_complete_transition` / `no_phase_change` | Advisory → Enforced |

## Gates already enforced (no v7.9 action)

- `ISOLATION_OPT_OUT_REASON_MISSING` — enforced at v7.8.1 ship (2026-05-07)
- Mechanism A coverage gates — already met at v7.8 ship
- Mechanism C session-attribution — already met at v7.8 ship
- `CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT` (V2) — enforced at v7.8.3 Phase 0 (2026-05-11)
- Mechanism E custom merge driver (V9) — enforced at v7.8.3 Phase 0

## Gates that stay advisory by design

| Gate | Why |
|---|---|
| `BRANCH_ISOLATION_HISTORICAL` cycle-time | T17 forward-only audit — historical features predating the gate cannot retroactively pass |
| `BRANCH_ISOLATION_LAUNCHD_DRIFT` cycle-time | T18 macOS-only — environment-specific |
| `FEATURE_CLOSURE_COMPLETENESS` cycle-time mirror | T19 `--no-verify` bypass catcher — fires when write-time gate is bypassed, so blocking would create infinite-loop |

## Phase E validation calendar (2026-05-21 → 2026-06-04)

- **2026-05-21** — v7.9 ships. PR opens; merge after CI green.
- **2026-05-22** — B11 UCC hardening T+3d check; new feature work may resume (no new gates this window per §3.6.2).
- **2026-05-23** — B8 parent UCC T+7d kill-criteria evaluation (K1/K2/K3 resolution).
- **2026-05-27** — B12 UCC hardening T+7d kill-criteria → advance to complete.
- **2026-05-28** — **B2 post-v7.9 baseline snapshot:** `make snapshot-phase PHASE=post-v7-9-baseline FEATURE=framework-v7-8-branch-isolation`. Compare against [2026-05-12 pre-v7-9 baseline](../../docs/master-plan/infra-master-plan-2026-05-12.md#2.4) and [2026-05-14 platform anchor](../../scripts/integrity-diff.py). Document deltas in [v7.9 case study](../../docs/case-studies/framework-v7-9-promotion-case-study.md) §99.
- **2026-05-28+** — B9 UCC Part 8 passkey-only flip decision (preconditions: B8 + B2 + C4 all complete + 0 auth_passkey_register_failed last 7 days).
- **~2026-06-04** — Phase E exit. v7.9.1 build window opens (F16 try-repo harness + F17 last_fired_at index + F2 Phase 0 reality-check + F6 B_medium tier doc + D-2 GA4 conversions + D-4 Firebase cleanup).

During Phase E:
- **No new gates ship** — keep the post-promotion baseline clean
- **No new test-discipline work (F14, F18) starts** — those are v7.9.1 docket
- **Operator monitors** `.claude/logs/gate-coverage.jsonl` for unexpected `failure` rows
- **F17** (`last_fired_at` index) MAY be built in parallel since it's read-only — does not add new gates

## Reversibility runbook (if Phase E surfaces regression)

```bash
cd /Volumes/DevSSD/FitTracker2
git checkout -b chore/v7-9-rollback main
# Edit scripts/check-state-schema.py:132 → BRANCH_ISOLATION_ADVISORY_MODE = True
git add scripts/check-state-schema.py
git commit -m "chore(v7-9-rollback): restore advisory mode for 3 gates"
git push -u origin HEAD
gh pr create --fill && gh pr merge --squash
```

End-to-end: <5 minutes. Reason for rollback MUST be recorded in [framework-honesty-ledger.md](../../docs/case-studies/framework-honesty-ledger.md) as FT2-FH-00N + the v7.9 case study §99 must be updated with the regression-surface details + the next promotion attempt must wait for the new calibration window (next earliest: T+14d after rollback).

## Canonical sources

| Document | Path |
|---|---|
| **v7.9 promotion case study** | [`docs/case-studies/framework-v7-9-promotion-case-study.md`](../../docs/case-studies/framework-v7-9-promotion-case-study.md) |
| **Honesty ledger entry FT2-FH-003** | [`docs/case-studies/framework-honesty-ledger.md#ft2-fh-003`](../../docs/case-studies/framework-honesty-ledger.md) |
| **Infra master plan (anchor for §2.1 advisory-enforced calendar + §2.2 decision criteria + §2.3 side-effects)** | [`docs/master-plan/infra-master-plan-2026-05-12.md`](../../docs/master-plan/infra-master-plan-2026-05-12.md) |
| **v7.8 bridge case study (predecessor)** | [`docs/case-studies/framework-v7-8-bridge-case-study.md`](../../docs/case-studies/framework-v7-8-bridge-case-study.md) |
| **v7.8.1 branch-isolation case study (predecessor — the gates promoted)** | [`docs/case-studies/framework-v7-8-branch-isolation-case-study.md`](../../docs/case-studies/framework-v7-8-branch-isolation-case-study.md) |
| **Pre-commit hook (where the flag lives)** | [`scripts/check-state-schema.py:132`](../../scripts/check-state-schema.py) |
| **Gate-coverage telemetry ledger** | [`.claude/logs/gate-coverage.jsonl`](../../.claude/logs/gate-coverage.jsonl) (gitignored) |
| **DEV onboarding guide §2.4** | [`docs/architecture/dev-guide-v1-to-v7-7.md`](../../docs/architecture/dev-guide-v1-to-v7-7.md) |
| **Pre-drafted day plan (executed today)** | [`docs/master-plan/post-v7-9-candidate-plan-2026-05-20.md`](../../docs/master-plan/post-v7-9-candidate-plan-2026-05-20.md) |
| **B1 freeze checklist** | [`.claude/shared/must-have-cadence-followups.md`](../../.claude/shared/must-have-cadence-followups.md) §B1 |

## How v7.x got here

- **v7.5** added the cycle-time gate harness + 12 check codes (data integrity foundation).
- **v7.6** added per-PR review bot + weekly framework-status cron + 4 new pre-commit gates (mechanical enforcement).
- **v7.7** added 4 more write-time gates + 1 cycle-time check + 1 advisory + bulk frontmatter + state.json backfill (validity closure). Shipped with a silent-pass (FT2-FH-001).
- **v7.8** added the meta-layer: gates that observe gate execution, schema bridges that observe schema drift, the honesty ledger that documents what we got wrong.
- **v7.8.1** added BRANCH_ISOLATION_VIOLATION + FEATURE_CLOSURE_COMPLETENESS in advisory mode + calibration window setup.
- **v7.8.2** documented the cross-repo telemetry asymmetry as exempted-by-design.
- **v7.8.3** shipped the cross-repo state-sync impl (V2 + V9 → enforced).
- **v7.8.4** cleaned the v7.9 calibration baseline (PR cache freshness gate + TIER_TAG heuristic + cache_hits backfills).
- **v7.8.5** added the Observed Patterns Catalog + W9 branch-drift alert.
- **v7.8.6** closed the 96h observability drift window (`make integrity-diff`, `make preflight WORK_TYPE=<...>`, weekly Mechanism A scan, daily stale-branch warning).
- **v7.9** (this) flips the 3 v7.8.1 candidate gates from advisory → enforced after the calibration window closed clean. Pattern from this point: "trust through track record."
