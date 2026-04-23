# Gemini Audit Remediation Plan — 2026-04-23

This is the current step-by-step operating plan for closing the remaining Gemini
audit gaps without overstating what is already true.

## Current truth snapshot

- Tier 1.1 is still partial: the measurement protocol shipped, but system-wide
  measured adoption is incomplete.
- Tier 2.1 groundwork is real: the staging smoke runner exists, staging app
  launch has already passed, preflight now passes with a valid local staging
  overlay, and the remaining auth-runtime gap is the onboarding-aware
  `sign_in_surface` smoke path plus real provider verification.
- Tier 2.2 is now in pilot mode: the logger exists, rejects silent backdating by
  default, and has its first live adoption entry.
- Tier 3.1 is real and hardened: the 72h workflow now preserves the integrity
  checker's exit status and distinguishes regressions from strict/manual runs.
- Tier 3.2 is baseline-only: the dashboard exists, but trend mode now waits for
  three scheduled cycle snapshots.

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

1. Fix `FitTrackerUITests/SignInUITests.swift` so `sign_in_surface` drives
   onboarding step 5 before asserting auth buttons.
2. Re-run `make runtime-smoke PROFILE=sign_in_surface MODE=staging`.
3. Email sign-up
4. Email verification / resend
5. Email login
6. Password reset
7. Google sign-in
8. Relaunch / session restore
9. Negative cases

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
