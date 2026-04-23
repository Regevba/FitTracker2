# Runtime Smoke Gates

> Groundwork for Gemini audit Tier 2.1.
> Status: **groundwork shipped; staging preflight validates local overlays; real auth verification remains locally credential-gated**.

## Goal

Move phase transitions closer to runtime truth by requiring a minimal smoke test
before high-trust transitions, especially **Review → Merge** for features that
touch user-facing or external-service flows.

## Current blocker

The full recommendation still requires a staging-grade environment with
repeatable local setup. The runner now validates the two local-only
dependencies below and, for the staging xcconfig overlay, checks that the
auth-critical keys look real rather than placeholder-filled:

- `Config/Local/Staging.xcconfig`
- `FitTracker/GoogleService-Info.plist`

Because that environment is still local-first rather than centrally provisioned,
enforcement remains **advisory**, not blocking.

## Current status on 2026-04-23

- staging `app_launch` smoke has already passed once against the `Staging` build path
- the new preflight now blocks before runtime auth claims are made if local staging secrets still look like placeholders
- the remaining blockers are four required local keys in `Config/Local/Staging.xcconfig`:
  - `FITTRACKER_SUPABASE_URL`
  - `FITTRACKER_SUPABASE_ANON_KEY`
  - `FITTRACKER_GOOGLE_CLIENT_ID`
  - `FITTRACKER_GOOGLE_REVERSED_CLIENT_ID`

## What shipped now

- shared smoke profiles in `.claude/shared/runtime-smoke-config.json`
- a runner at `scripts/runtime-smoke-gate.py`
- a local convenience target:

```bash
make runtime-smoke PROFILE=authenticated_home
```

Dry-run the command plan instead of executing it:

```bash
make runtime-smoke PROFILE=app_launch DRY_RUN=1
```

## Profiles

- `app_launch`
- `authenticated_home`
- `sign_in_surface`
- `onboarding_surface`
- `meal_log_surface`

All current profiles are built on the shipped M-4 XCUITest harness.

## How to use it today

1. Pick the profile that matches the risky runtime surface.
2. Run the smoke gate locally.
3. Attach the resulting report to the review or merge evidence.

For staging preflight specifically, the runner blocks before `xcodebuild` if:

- `Config/Local/Staging.xcconfig` is missing
- `FitTracker/GoogleService-Info.plist` is missing
- required staging auth keys are missing or still look like placeholders

The report stays secret-safe: it records only statuses such as
`valid-looking`, `missing`, or `placeholder-looking`, never the raw values.

## How this becomes a real gate later

When staging exists:

1. switch mode from `local` to `staging`
2. build with the `Staging` Xcode configuration
3. satisfy staging prerequisites
4. require a passing report within the configured TTL before transition

At that point the runner stops being advisory and becomes the runtime-gate
evidence source for phase transitions.
