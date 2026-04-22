# Runtime Smoke Gates

> Groundwork for Gemini audit Tier 2.1.
> Status: **local smoke-gate runner shipped; full staging gate still blocked**.

## Goal

Move phase transitions closer to runtime truth by requiring a minimal smoke test
before high-trust transitions, especially **Review → Merge** for features that
touch user-facing or external-service flows.

## Current blocker

The full recommendation requires a staging-grade environment. Today the project
still has known runtime dependencies that are local-only:

- `Config/Local/Staging.xcconfig`
- `FitTracker/GoogleService-Info.plist`

Because that environment is not yet standardized, enforcement remains
**advisory**, not blocking.

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

## How this becomes a real gate later

When staging exists:

1. switch mode from `local` to `staging`
2. build with the `Staging` Xcode configuration
3. satisfy staging prerequisites
4. require a passing report within the configured TTL before transition

At that point the runner stops being advisory and becomes the runtime-gate
evidence source for phase transitions.
