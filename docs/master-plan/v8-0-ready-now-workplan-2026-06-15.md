# v8.0 Ready-Now Workplan — 2026-06-15

> **Scope:** the open v8.x docket items that have **no gating dependency** and can start immediately. Source: [`v8-x-build-docket-2026-06-15.md`](v8-x-build-docket-2026-06-15.md) §0.B.
> **Excluded (gated — not "ready now"):** T1 `GATE_TEST_MISSING` (F14 Phase E 2026-08-22) · F18 mutation testing (F16 Phase E, post 2026-06-18) · F19/F20/F22/F23 (GA4 / Sentry / launch signal) · T4 Swift snapshot (scaffold only) · F-CONTRACT consumer (cross-repo session).

## The 8 ready-now items

| # | ID | Item | RICE | Effort | Class | Infra-glob? |
|---|---|---|---|---|---|---|
| 1 | **F12** | `actionlint` in pre-commit + CI | **100.0** | ~0.2w | Write-time gate | yes (`.githooks/`, `.github/workflows/`) |
| 2 | **F11** | `BRANCH_ISOLATION_HISTORICAL` reverse-sync allowlist | 40.0 | ~0.3w | Cycle-time gate | yes (`scripts/`) |
| 3 | **F10** | `experiment_outcome` enum on `tasks[]` | 32.0 | ~0.3w | Schema extension | yes (`scripts/` schema) |
| 4 | **F13** | `source_commit` `workflow_dispatch` input | 32.0 | ~0.4w | GH Actions infra | yes (`.github/workflows/`) |
| 5 | **F4** | Auto-update `framework_version` on protocol writes | 32.0 | ~0.5w | Write-time/migration | yes (`scripts/`) |
| 6 | **F5** | `scope_change` Tier 2.2 vocabulary event | 20.0 | ~0.2w | Vocabulary | yes (`scripts/` + log schema) |
| 7 | **F1** | `STATE_TASKS_FILESYSTEM_DRIFT` advisory | 19.2 | ~0.5w | Cycle-time gate | yes (`scripts/`) |
| 8 | **F3** | Phase 2 dependency-graph cycle check | 14.4 | ~0.5w | Workflow gate | yes (`scripts/`) |

**Total effort:** ~2.9 engineer-weeks. All 8 touch infra-glob paths.

## Non-negotiable constraints (apply to every item)

1. **Isolated worktree (enforced).** Every item touches `scripts/` / `.githooks/` / `.github/workflows/` → `BRANCH_ISOLATION_VIOLATION` Mode B fires (enforced at v7.9). Work each in an isolated worktree via `scripts/create-isolated-worktree.py` (or `superpowers:using-git-worktrees`). Do **not** commit infra-glob changes from a non-isolated branch.
2. **Calibration Protocol (§3.5, mandatory for new gates).** Each NEW gate (F1, F4, F5, F11, F12, F3) ships **advisory first** with Phase A artifacts authored BEFORE code: `function_name`, `emission_key`, dispatch site, expected skip reasons, **1 positive + 1 negative fixture**, and a regression test asserting coverage fires. Then walk B (advisory + measure 7d) → C (calibration 7d) → D (promote decision) → E (validate 7d). **Min 22 days per gate to enforced.** F10 (pure schema) + F13 (workflow input) are not gates → no calibration walk, but still need tests.
3. **F16 try-repo fixture pair (mandatory for new write-time gates).** Per CLAUDE.md F16 discipline, F12 + F4 (write-time) MUST ship a `tests/fixtures/<GATE_ID>/{positive,negative}/state.overrides.json` pair + a per-gate test in the appropriate `test_try_repo_*_gates.py` bucket. (Cycle-time gates F1/F11/F3 use the unit + dispatch test layers.)
4. **Soak-window discipline.** F16's own advisory→enforced flip is 2026-06-18. The layer-stacking rule (§3.5.2) forbids building a new layer on one not yet in Phase E — none of these 8 stack on F16, so they're clear, but do not start F18 (which depends on F16 Phase E).
5. **Full PM lifecycle by work-type.** Each is a `chore` or `fix` (gate/schema add) → Implement → Test → Merge; no PRD needed. Use `/pm-workflow {name}` and select work-type.

## Recommended sequencing (3 batches, low-risk-first within RICE order)

**Batch 1 — CI/lint infra (no schema risk):**
- **F12 actionlint** (RICE 100, highest) — add `actionlint` to `.githooks/pre-commit` + a CI job; warn-only first, then enforce after calibration. Catches the workflow-YAML error class that F13 also touches.
- **F13 source_commit input** — `workflow_dispatch` input + full-repo scan fallback. Pairs naturally with F12 (both GH-Actions surface) → consider one worktree, two PRs.

**Batch 2 — schema + vocabulary (coordinated, low risk):**
- **F10 experiment_outcome enum** — add enum to `tasks[]` schema + backfill existing deferred tasks + validator. Not a gate.
- **F5 scope_change event** — add to Tier 2.2 vocabulary + `append-feature-log.py`. Not a gate.
- **F4 framework_version auto-update** — partial coverage exists (`FRAMEWORK_VERSION_FORMAT` + `tracking-drift-check` #659); scope to the *auto-update on protocol-touching writes* gap. Write-time → calibration + try-repo fixture.

**Batch 3 — cycle-time advisories (read-only, lowest risk to commits):**
- **F11 reverse-sync allowlist** — extend `BRANCH_ISOLATION_HISTORICAL` to read `state_owner_sync_origin` / `reverse-sync/*`.
- **F1 STATE_TASKS_FILESYSTEM_DRIFT** — cycle-time advisory; detect empty `tasks[]` despite shipped work (cross-check git/PR evidence, à la F2 reality-check).
- **F3 dependency-graph cycle check** — Phase 2 multi-feature dep-cycle detector (lowest RICE; do last).

## Calendar interaction

- **2026-06-18** — F16 advisory→enforced flip (scheduled separately). Batches 1–2 can proceed in parallel; nothing here blocks on it.
- **2026-06-18** — v8.0 build kickoff target. These 8 items ARE the early v8.0 build.
- Each new advisory gate's 22-day calibration clock starts at its advisory ship; expect first enforced flips ~mid-July at the earliest.

## Suggested first action

Start **F12 (actionlint)** — highest RICE, smallest effort, lowest schema risk, and it hardens the very CI-workflow surface the other infra items edit. `scripts/create-isolated-worktree.py` → `/pm-workflow f12-actionlint-gate` (work-type: chore) → Phase A artifacts → advisory ship.

## Cross-references
- Docket: [`v8-x-build-docket-2026-06-15.md`](v8-x-build-docket-2026-06-15.md)
- Calibration Protocol: [`infra-master-plan-2026-05-12.md`](infra-master-plan-2026-05-12.md) §3.5
- F16 try-repo fixture discipline: [`../../CLAUDE.md`](../../CLAUDE.md) "v7.9.1 F16" section
- Canonical current state: [`../FRAMEWORK-FACTS.md`](../FRAMEWORK-FACTS.md)
