# Gemini Audit Remediation Plan — 2026-04-23 (updated 2026-04-24)

This is the current step-by-step operating plan for closing the remaining Gemini
audit gaps without overstating what is already true.

## Current truth snapshot (2026-04-24)

- Tier 1.1 is **partial, now measured**: `measurement-adoption-report.py`
  inventory shows 0/40 features fully adopt v6.0 measurement fields, and 0/40
  have `cache_hits` populated. Partial status is preserved but is now
  auditable via `make measurement-adoption` rather than narrative.
- Tier 1.2 is now **shipped** (promoted from "subset shipped" on 2026-04-24):
  the pre-commit hook now also verifies `phases.merge.pr_number` resolves on
  GitHub. Gate fires at write-time; the 72h integrity cycle still catches
  drift post-hoc. Both on-write and on-cycle paths covered.
- Tier 2.1 groundwork is real: the staging smoke runner exists, staging app
  launch has already passed, preflight now passes with a valid local staging
  overlay, and the onboarding-aware `sign_in_surface` smoke now also passes.
  The remaining Tier 2.1 gap is real provider verification, not harness setup.
- Tier 2.2 pilot **expanded to 5 live logs** on 2026-04-24: scaffolds seeded
  for the 3 features currently in `phase=implementation`
  (`app-store-assets`, `import-training-plan`, `push-notifications`) alongside
  the existing `staging-auth-runtime` and `meta-analysis-audit` logs. Full
  process migration still incomplete until PM-workflow usage becomes routine.
- Tier 3.1 is real and hardened: the 72h workflow now preserves the integrity
  checker's exit status and distinguishes regressions from strict/manual runs.
- Tier 3.2 is baseline-only: the dashboard exists, but trend mode now waits for
  three scheduled cycle snapshots.

## New finding (2026-04-24): `cache_hits` is 0/40 across the corpus

The v6.0 measurement protocol defined a `cache_hits[]` field on state.json but
no feature session actually writes to it. Tier 1.1 inventory surfaced this as
separate from "slow adoption" — the writer path is not being exercised at all.
Filed as an explicit known-delta in the Tier 1.1 status table; see
`.claude/shared/measurement-adoption.json` for the per-dimension breakdown.

## What was fixed in this session

1. Fixed `.github/workflows/integrity-cycle.yml` so piped integrity runs keep the
   real checker exit code instead of `tee`'s exit code.
2. Wired the manual `strict` input into the workflow and prevented strict/manual
   runs from being mislabeled as regressions.
3. Added snapshot-source metadata in `scripts/integrity-check.py` so downstream
   reports can distinguish scheduled cycles from ad hoc snapshots.
4. Tightened `scripts/documentation-debt-report.py` so trend readiness depends on
   scheduled cycle snapshots, not just any three JSON files.
5. Hardened `scripts/append-feature-log.py` so retroactive entries require an
   explicit flag and a reason.
6. Updated the trust docs, runtime-smoke docs, auth verification playbook, and
   framework memory pages so they match current implementation reality.

## Remaining staged work

### A. Finish the staging credentials

Status: complete locally.

1. Keep real staging values only in `Config/Local/Staging.xcconfig`.
2. Keep tracked `Config/Staging.xcconfig` placeholder-safe.
3. Preserve `FitTracker/Info.plist` as build-setting references only.
4. Use `.claude/shared/runtime-smoke-staging-preflight.json` as the current
   proof that all required staging keys are `valid-looking`.

### B. Re-run the staging runtime gate

Status: app launch complete locally.

1. Keep `.claude/shared/runtime-smoke-staging-app-launch.json` as the baseline
   proof that staging `app_launch` passed.
2. Continue from auth-specific verification rather than repeating credential
   setup.

### C. Complete auth runtime verification

1. Keep `.claude/shared/runtime-smoke-staging-sign-in-surface.json` as the
   harness proof that the embedded auth surface is reachable in staging.
2. Email sign-up
3. Email verification / resend
4. Email login
5. Password reset
6. Google sign-in
7. Relaunch / session restore
8. Negative cases

Use [docs/setup/auth-runtime-verification-playbook.md](/Volumes/DevSSD/FitTracker2/docs/setup/auth-runtime-verification-playbook.md)
as the exact checklist. Do not promote auth to `runtime-verified` until the real
provider flows pass.

### D. Let the integrity cycle mature

1. Keep the scheduled 72h workflow enabled.
2. Wait for three scheduled cycle snapshots with the new snapshot metadata.
3. Regenerate `.claude/shared/documentation-debt.json`.
4. Only then treat the dashboard trend view as authoritative.

### E. Expand Tier 2.2 from pilot to process

1. Start a `.claude/logs/<feature>.log.json` file at the beginning of each
   multi-session feature.
2. Append events during work rather than after merge.
3. Cite those logs from future case studies.
4. Treat unmarked retroactive backfills as process bugs.

## Documentation surfaces updated

- In-repo memory broadcast: `.claude/shared/change-log.json`
- Operational docs: `docs/process/` and `docs/setup/`
- Audit entrypoints: `project_gemini_audit_2026_04_21.md` and this trust bundle
- Framework memory: `docs/skills/evolution.md`

## Remote sync rule

Push these truth-surface updates to `origin/main` together so local and remote
status stay aligned.
