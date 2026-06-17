# v8.0 Ready-Now Workplan — 2026-06-15

> **Scope:** the open v8.x docket items that have **no gating dependency** and can start immediately. Source: [`v8-x-build-docket-2026-06-15.md`](v8-x-build-docket-2026-06-15.md) §0.B.
> **Excluded (gated — not "ready now"):** T1 `GATE_TEST_MISSING` (F14 Phase E 2026-08-22) · F18 mutation testing (F16 Phase E, post 2026-06-18) · F19/F20/F22/F23 (GA4 / Sentry / launch signal) · T4 Swift snapshot (scaffold only) · F-CONTRACT consumer (cross-repo session).

## The 8 ready-now items

> **Status 2026-06-17:** ✅ **8 of 8 shipped** (F12, F11, F10, F13, F5, F4, F1, **F3 ← advisory, this branch**). **0 ready-now F-items remain.** Next v8.x work is date-gated (T1 2026-08-22, F18 post-F16-Phase-E) or operator-gated (F19–F23).

| # | ID | Item | RICE | Effort | Class | Infra-glob? |
|---|---|---|---|---|---|---|
| 1 | **F12** ✅ SHIPPED | `actionlint` warn-only CI (`.github/workflows/actionlint.yml`) + `make actionlint` — reclassified CI linter (like R18), not a state.json gate | **100.0** | ~0.2w | CI linter | yes (`.github/workflows/`) |
| 2 | **F11** ✅ SHIPPED | `BRANCH_ISOLATION_HISTORICAL` reverse-sync exemption (advisory narrowing, no calibration) | 40.0 | ~0.3w | Cycle-time gate | yes (`scripts/`) |
| 3 | **F10** ✅ SHIPPED | `experiment_outcome` enum on `tasks[]` (documented + advisory; not a gate) | 32.0 | ~0.3w | Schema extension | yes (`scripts/` schema) |
| 4 | **F13** ✅ SHIPPED | `source_commit` `workflow_dispatch` input + full-repo-scan fallback | 32.0 | ~0.4w | GH Actions infra (fitme-story) | fitme-story PR #221 |
| 5 | **F4** ✅ SHIPPED | `FRAMEWORK_VERSION_STALE` advisory gate — stale-version detector on phase-advance (PR #740, 2026-06-16; advisory→enforced ~2026-06-30) | 32.0 | ~0.5w | Write-time gate (advisory) | yes (`scripts/`) |
| 6 | **F5** ✅ SHIPPED | `scope_change` Tier 2.2 vocabulary event (advisory note) | 20.0 | ~0.2w | Vocabulary | yes (`scripts/` + log schema) |
| 7 | **F1** ✅ SHIPPED | `STATE_TASKS_FILESYSTEM_DRIFT` cycle-time advisory — complete feature + empty `tasks[]` + shipped artifact = ledger drift (advisory-permanent; 5 baseline fires) | 19.2 | ~0.5w | Cycle-time gate | yes (`scripts/`) |
| 8 | **F3** ✅ SHIPPED | `DEPENDENCY_GRAPH_CYCLE` cycle-time advisory — cycles / self-loops / dangling refs across `scheduled_after` + `parent_feature` (advisory-permanent; 0 baseline findings, healthy guard) | 14.4 | ~0.5w | Cycle-time gate | yes (`scripts/`) |

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
- **F4 framework_version auto-update** — ✅ **SHIPPED 2026-06-16 (PR #740)** as `FRAMEWORK_VERSION_STALE` advisory detector (operator chose detection over auto-mutation). 28 tests + try-repo fixture pair + Phase A doc. Advisory→enforced flip ~2026-06-30.

**Batch 3 — cycle-time advisories (read-only, lowest risk to commits):**
- **F11 reverse-sync allowlist** — extend `BRANCH_ISOLATION_HISTORICAL` to read `state_owner_sync_origin` / `reverse-sync/*`.
- **F1 STATE_TASKS_FILESYSTEM_DRIFT** — cycle-time advisory; detect empty `tasks[]` despite shipped work (cross-check git/PR evidence, à la F2 reality-check).
- **F3 dependency-graph cycle check** — Phase 2 multi-feature dep-cycle detector (lowest RICE; do last).

## Calendar interaction

- **2026-06-18** — F16 advisory→enforced flip (scheduled separately). Batches 1–2 can proceed in parallel; nothing here blocks on it.
- **2026-06-18** — v8.0 build kickoff target. These 8 items ARE the early v8.0 build.
- Each new advisory gate's 22-day calibration clock starts at its advisory ship; expect first enforced flips ~mid-July at the earliest.

## Suggested first action

~~Start **F12 (actionlint)**~~ — DONE, along with F11/F10/F13/F5/F4. **Next open item: F1 (`STATE_TASKS_FILESYSTEM_DRIFT`, RICE 19.2)**, then F3 (dep-graph cycle check, 14.4). Both are cycle-time advisories (read-only, lowest commit risk) — unit + dispatch test layers, no try-repo fixture needed. `scripts/create-isolated-worktree.py` → `/pm-workflow f1-state-tasks-filesystem-drift` → Phase A artifacts → advisory ship.

## Cross-references
- Docket: [`v8-x-build-docket-2026-06-15.md`](v8-x-build-docket-2026-06-15.md)
- Calibration Protocol: [`infra-master-plan-2026-05-12.md`](infra-master-plan-2026-05-12.md) §3.5
- F16 try-repo fixture discipline: [`../../CLAUDE.md`](../../CLAUDE.md) "v7.9.1 F16" section
- Canonical current state: [`../FRAMEWORK-FACTS.md`](../FRAMEWORK-FACTS.md)
