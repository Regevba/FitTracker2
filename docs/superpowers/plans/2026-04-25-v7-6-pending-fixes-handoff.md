# Framework v7.6 Pending Fixes — Working Plan + Agent Handoff

**Created:** 2026-04-25T08:18:03Z  
**Branch:** `framework-v7.6-pending-fixes`  
**Base commit:** `805daab505083c8a44c2cb28e59f855cce81c729` (`origin/main` at branch creation)  
**Purpose:** Finish the remaining framework v7.6 reconciliation work without disturbing ongoing parallel-agent work.

## Current Snapshot

At branch creation, `main`, `origin/main`, and `HEAD` all pointed to:

```text
805daab505083c8a44c2cb28e59f855cce81c729 docs(dev-guide): add DEV-only framework guide v1.0 -> v7.6 (745 lines, 16 sections)
```

The working tree already had two unrelated local runtime-metadata edits:

```text
M .claude/scheduled_tasks.lock
M .claude/settings.local.json
```

Do not include those files in the v7.6 pending-fixes commits unless the user explicitly asks. They pre-date this handoff branch and appear to be local agent/runtime state.

## What Is Already Merged To Main

The v7.6 series is on `origin/main`:

- `0a23922` — Phase 1 write-time pre-commit hooks.
- `c0be8ea` — Phase 2 PR bot, weekly cron, measurement history.
- `ecb172d` — Phase 3 Class B gaps inventory + `CLAUDE.md`.
- `58b82b5` — Phase 4 manifest bump, case study, propagation.
- `805daab` — DEV-only framework guide.

Current verified operational state:

- `python3 scripts/integrity-check.py --findings-only` reports 0 findings.
- `python3 scripts/check-state-schema.py` passes on 42 state files.
- `python3 scripts/check-case-study-preflight.py` passes on 44 eligible case-study files.
- `bash scripts/framework-status.sh` reports framework version `7.6`, 0 findings, pre-commit hook installed.
- `bash scripts/test-v7-5-pipeline.sh` passes with full permissions: 15 pass, 0 fail.

Important caveat: the regression test needs permission to create its temporary fixture and to run GitHub-backed PR lookup. In restricted sandbox mode it can fail for environmental reasons.

## Scope Guard

Other agent work is still in progress. Treat this branch as a coordination branch, not as proof that the whole framework is finished.

Before editing any file:

1. Run `git status --short --branch`.
2. Inspect files for unexpected new edits.
3. Do not overwrite other agents' changes.
4. Prefer one focused commit per fix group.
5. Keep rollback simple: each fix group should be revertable by commit.

## Pending Fix Groups

### 1. Reconcile v7.6 Feature State

Problem:

- `.claude/features/data-integrity-framework-v7-6/state.json` still says:
  - `current_phase: "implement"`
  - `status: "in_progress"`
  - `phases.implement.status: "in_progress"`
- The manifest/docs say v7.6 shipped.

Target:

- Update the v7.6 feature state to reflect the real current status after coordination with any active agent.
- If the work is truly complete, advance to an appropriate terminal phase/status and fill timing fields:
  - `timing.phases.implement.ended_at`
  - any new phase `started_at` / `ended_at` fields required by the framework.
- Append a contemporaneous log event via `scripts/append-feature-log.py`.

Checks:

- `python3 scripts/check-state-schema.py`
- `python3 scripts/integrity-check.py --findings-only`
- `bash scripts/test-v7-5-pipeline.sh` with full permissions.

Rollback:

- Revert only the commit that changes `.claude/features/data-integrity-framework-v7-6/state.json` and the matching log entry.

### 2. Register v7.6 In Shared Tracking Surfaces

Problem:

These files currently do not mention `data-integrity-framework-v7-6`, `Mechanical Enforcement`, or `v7.6`:

- `.claude/shared/feature-registry.json`
- `.claude/shared/case-study-monitoring.json`
- `.claude/shared/task-queue.json`
- `.claude/shared/framework-health.json`

Target:

- Add or update only the tracking entries that the framework convention expects.
- Keep entries factual and consistent with the final reconciled state from Fix Group 1.
- If a file is intentionally not supposed to track framework-internal work, document that decision in the relevant docs instead of forcing an entry.

Checks:

- JSON parse each edited file.
- `python3 scripts/integrity-check.py --findings-only`
- `bash scripts/framework-status.sh`

Rollback:

- Revert the shared-tracking commit.

### 3. Tighten PR Workflow Enforcement Semantics

Problem:

`.github/workflows/pr-integrity-check.yml` runs:

- schema check
- integrity check
- measurement-adoption

But the commit status is currently computed only from `pr_findings - main_findings`. The schema/adoption exit codes are captured but do not affect `pm-framework/pr-integrity`.

Target decision:

- Decide whether this workflow should fail only on new integrity findings, or also on schema/adoption command failures.
- If the docs continue to claim the PR bot runs all three as gates, update the workflow so schema/adoption failures affect the final status.
- If schema/adoption are informational, update docs/manifest language to say so clearly.

Likely implementation:

- In `Compute delta + status`, include:
  - `steps.schema.outputs.exit`
  - `steps.adoption.outputs.exit`
  - possibly `steps.integrity.outputs.exit`
- Set status to `failure` when any required command exits non-zero.
- Include the failing command in the sticky comment and workflow summary.

Checks:

- Review shell quoting carefully.
- Keep dynamic GitHub values routed through `env`.
- Run a local text inspection and, if possible, use GitHub Actions validation in CI.

Rollback:

- Revert only the workflow commit.

### 4. Align Documentation With Actual Guarantees

Problems observed:

- `README.md` still says PM Framework `v7.0`.
- `.claude/skills/pm-workflow/README.md` still says `v6.1`.
- Some docs describe `PHASE_TRANSITION_NO_LOG` and `PHASE_TRANSITION_NO_TIMING` as cycle checks, but the code makes them staged/write-time checks only.
- Some docs say tier-tag enforcement scans each quantitative claim, but the code only verifies at least one `T1`/`T2`/`T3` tag exists in a scoped file.
- Some docs say PR checks use `gh pr view`; the implementation uses a cached `gh pr list`.
- Some docs say PR checks hard-block, while code skips gracefully when `gh` is unavailable.

Target:

- Update docs so they match implementation exactly, or update implementation where the stronger doc claim is intended.
- Preferred wording: distinguish `hard when GitHub PR cache is available` from `skipped gracefully when gh is unavailable`.
- Keep historical docs truthful; add corrections instead of rewriting audit history.

Primary files:

- `README.md`
- `.claude/skills/pm-workflow/README.md`
- `CLAUDE.md`
- `docs/architecture/dev-guide-v1-to-v7-6.md`
- `docs/case-studies/mechanical-enforcement-v7-6-case-study.md`
- `.claude/shared/framework-manifest.json`
- `.claude/integrity/README.md`

Checks:

- `rg -n "v6.1|v7.0|gh pr view|Write \\+ cycle|quantitative claim|hard-block|12 check codes|11 check codes"`
- `python3 scripts/integrity-check.py --findings-only`

Rollback:

- Revert the documentation-alignment commit.

### 5. Decide Whether To Rename The Regression Test

Problem:

`scripts/test-v7-5-pipeline.sh` now tests v7.5 plus v7.6 assertions, but the name and output still say v7.5 in places.

Options:

- Keep name for compatibility and update comments/output to say "v7.5/v7.6".
- Add a wrapper `scripts/test-v7-6-pipeline.sh` that calls the existing script.
- Rename only if all references are updated.

Checks:

- `rg -n "test-v7-5-pipeline|v7.5 Data Integrity Framework|All 8 defenses"`
- `bash scripts/test-v7-5-pipeline.sh` with full permissions.

Rollback:

- Revert the test-name/comment commit.

## Suggested Commit Plan

1. `docs(framework): add v7.6 pending-fixes handoff`
2. `chore(framework): reconcile v7.6 feature state`
3. `chore(framework): register v7.6 shared tracking surfaces`
4. `ci(framework): align PR integrity status with required checks`
5. `docs(framework): align v7.6 docs with implementation guarantees`
6. Optional: `test(framework): clarify v7.5/v7.6 regression suite naming`

Each commit should pass its local checks and remain individually revertable.

## Rollback Strategy

This branch was created from `805daab505083c8a44c2cb28e59f855cce81c729`.

To abandon all pending-fix work:

```bash
git switch main
git branch -D framework-v7.6-pending-fixes
```

To rollback a single fix after it is committed:

```bash
git revert <commit-sha>
```

To inspect only this branch's changes against current main:

```bash
git diff main...framework-v7.6-pending-fixes
git diff --stat main...framework-v7.6-pending-fixes
```

Do not use `git reset --hard` while other agents are active unless the user explicitly approves it.

## Handoff For Other Agents

You are not alone in the codebase. Other agents may still be editing docs, shared state, or framework scripts.

Before taking ownership of a fix group:

1. Announce the fix group you are editing.
2. Re-run `git status --short --branch`.
3. Read the exact files you will edit.
4. Keep your write set narrow.
5. Do not revert unrelated changes.
6. Leave a final note listing:
   - files changed
   - checks run
   - anything intentionally left pending
   - rollback commit SHA if committed

Recommended ownership split:

- Agent A: Fix Groups 1 and 2 (state + shared tracking).
- Agent B: Fix Group 3 (PR workflow semantics).
- Agent C: Fix Group 4 (docs alignment).
- Agent D: Fix Group 5 plus final verification.

Final verification before merging this branch:

```bash
git status --short --branch
python3 scripts/check-state-schema.py
python3 scripts/check-case-study-preflight.py
python3 scripts/integrity-check.py --findings-only
bash scripts/framework-status.sh
bash scripts/test-v7-5-pipeline.sh
```

The last command requires permission/full local filesystem access because it creates synthetic fixtures and uses GitHub-backed PR lookup.
