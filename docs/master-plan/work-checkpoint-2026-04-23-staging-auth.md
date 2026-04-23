> **Purpose:** Resume checkpoint for the staging-auth/runtime-verification track. This document separates what is already on `origin/main` from newer local-only work so future sessions do not confuse pushed repo truth with uncommitted local state.

# Work Progress Checkpoint — 2026-04-23 (Staging Auth)

## Current Branch & State

- **Branch:** `main`
- **HEAD:** `2415475ae26a289a6e2a437d8a960d2481cebf03`
- **origin/main:** `2415475ae26a289a6e2a437d8a960d2481cebf03`
- **Remote baseline meaning:** the Gemini remediation bundle is pushed; the newer staging-auth/runtime changes below were still local-only when this checkpoint was written.
- **Sensitive config rule:** real staging secrets belong only in `Config/Local/Staging.xcconfig` and must not be copied back into tracked config files.

## What Is Already Remote

`origin/main` at `2415475` already contains:

- the Gemini follow-up remediation bundle
- the hardened integrity-cycle workflow and documentation-debt logic
- the staging-credentials remediation plan in [trust/audits/2026-04-21-gemini/remediation-plan-2026-04-23.md](/Volumes/DevSSD/FitTracker2/trust/audits/2026-04-21-gemini/remediation-plan-2026-04-23.md)
- the staging preflight gate that validates local staging overlays without exposing secret values

Earlier pushed work before that also established:

- the tracked `Config/*.xcconfig` layer and local overlay pattern
- dynamic simulator resolution in `scripts/runtime-smoke-gate.py`
- a real passing staging `app_launch` path once valid local credentials exist

## Local-Only Work Completed After `2415475`

### Staging config hygiene

- [FitTracker/Info.plist](/Volumes/DevSSD/FitTracker2/FitTracker/Info.plist) was restored to build-setting references:
  - `$(FITTRACKER_SUPABASE_URL)`
  - `$(FITTRACKER_SUPABASE_ANON_KEY)`
  - `$(FITTRACKER_GOOGLE_CLIENT_ID)`
  - `$(FITTRACKER_GOOGLE_REVERSED_CLIENT_ID)`
- [Config/Staging.xcconfig](/Volumes/DevSSD/FitTracker2/Config/Staging.xcconfig) was restored to placeholder-safe tracked defaults.
- Real staging credentials were placed only in local overlay `Config/Local/Staging.xcconfig` and validated successfully. That file is intentionally local-only and is not described here beyond the fact that all required keys are now `valid-looking`.
- URL-style xcconfig values were quoted in tracked/example files to avoid `https://...` truncation during build-setting expansion:
  - [Config/Base.xcconfig](/Volumes/DevSSD/FitTracker2/Config/Base.xcconfig)
  - [Config/Local/Debug.example.xcconfig](/Volumes/DevSSD/FitTracker2/Config/Local/Debug.example.xcconfig)
  - [Config/Local/Release.example.xcconfig](/Volumes/DevSSD/FitTracker2/Config/Local/Release.example.xcconfig)
  - [Config/Local/Staging.example.xcconfig](/Volumes/DevSSD/FitTracker2/Config/Local/Staging.example.xcconfig)

### Auth/runtime test hardening

- [FitTracker/Views/Auth/AuthHubView.swift](/Volumes/DevSSD/FitTracker2/FitTracker/Views/Auth/AuthHubView.swift) gained stable accessibility identifiers for passkey, email, Google, and Apple auth actions.
- [FitTracker/Views/Auth/SignInView.swift](/Volumes/DevSSD/FitTracker2/FitTracker/Views/Auth/SignInView.swift) gained provider-specific accessibility identifiers (`auth.signin.*`).
- [FitTrackerUITests/SignInUITests.swift](/Volumes/DevSSD/FitTracker2/FitTrackerUITests/SignInUITests.swift) was tightened so the smoke test now fails loudly instead of silently skipping when the expected auth surface is missing.

## Verified Results

### 1. Staging preflight is clean

Report:
[.claude/shared/runtime-smoke-staging-preflight.json](/Volumes/DevSSD/FitTracker2/.claude/shared/runtime-smoke-staging-preflight.json)

Verified state from timestamp `2026-04-23T13:35:14Z`:

- `invalid_prerequisites: []`
- `missing_prerequisites: []`
- all required staging keys are `valid-looking`

### 2. Real staging app-launch smoke passed

Report:
[.claude/shared/runtime-smoke-staging-app-launch.json](/Volumes/DevSSD/FitTracker2/.claude/shared/runtime-smoke-staging-app-launch.json)

Verified state from timestamp `2026-04-23T13:28:07Z`:

- profile: `app_launch`
- mode: `staging`
- status: `passed`
- return code: `0`
- destination resolved to an iPhone 17 Pro simulator
- result bundle:
  `/Volumes/DevSSD/FitTracker2/.build/RuntimeSmokeDerivedData/Logs/Test/Test-FitTracker-2026.04.23_16-28-13-+0300.xcresult`

### 3. Sign-in surface smoke is now a real failure

Report:
[.claude/shared/runtime-smoke-staging-sign-in-surface.json](/Volumes/DevSSD/FitTracker2/.claude/shared/runtime-smoke-staging-sign-in-surface.json)

Verified state from timestamp `2026-04-23T13:39:30Z`:

- profile: `sign_in_surface`
- mode: `staging`
- status: `failed`
- return code: `65`

This is not a credential failure. It is a test-path mismatch.

## Root Cause Of The Remaining Failure

The current sign-in smoke still assumes auth actions should appear immediately after launch under `FITTRACKER_SKIP_AUTO_LOGIN=1`. In the real app flow, signed-out first-launch users are routed into onboarding first.

Key code facts:

- [FitTracker/FitTrackerApp.swift](/Volumes/DevSSD/FitTracker2/FitTracker/FitTrackerApp.swift) routes users into `OnboardingView` when onboarding is incomplete.
- [FitTracker/Views/Onboarding/v2/OnboardingView.swift](/Volumes/DevSSD/FitTracker2/FitTracker/Views/Onboarding/v2/OnboardingView.swift) places auth at onboarding step 5.
- [FitTracker/Views/Onboarding/v2/OnboardingAuthView.swift](/Volumes/DevSSD/FitTracker2/FitTracker/Views/Onboarding/v2/OnboardingAuthView.swift) is the real auth surface containing:
  - `Continue with Email`
  - `Continue with Google`
  - `Continue with Apple`
  - `Already have an account? Log In`
  - `Skip for now`

Relevant onboarding labels already confirmed for UI-driving:

- `Get Started`
- `Build Muscle`
- `Beginner`
- `2 days per week` / `3 days per week` accessibility labels
- `Skip`
- `Continue Without`

## Exact Next Runnable

Update [FitTrackerUITests/SignInUITests.swift](/Volumes/DevSSD/FitTracker2/FitTrackerUITests/SignInUITests.swift) so the smoke test advances through onboarding before asserting auth controls.

Suggested path:

1. Tap `Get Started`
2. Select `Build Muscle`
3. Tap `Continue`
4. Pick one profile option such as `Beginner`
5. Pick a training-frequency button such as `3 days per week`
6. Tap `Continue`
7. Use `Skip` or `Continue` on HealthKit depending on device state
8. Tap `Continue Without` on consent
9. Assert one of the onboarding auth controls exists

After patching, rerun:

```bash
make runtime-smoke PROFILE=sign_in_surface MODE=staging
```

## Working Tree Snapshot At Checkpoint Time

These files had local changes when this checkpoint was written:

- `.claude/shared/runtime-smoke-staging-app-launch.json`
- `.claude/shared/runtime-smoke-staging-preflight.json`
- `.claude/shared/runtime-smoke-staging-sign-in-surface.json`
- `Config/Base.xcconfig`
- `Config/Local/Debug.example.xcconfig`
- `Config/Local/Release.example.xcconfig`
- `Config/Local/Staging.example.xcconfig`
- `Config/Staging.xcconfig`
- `FitTracker/Info.plist`
- `FitTracker/Views/Auth/AuthHubView.swift`
- `FitTracker/Views/Auth/SignInView.swift`
- `FitTrackerUITests/SignInUITests.swift`

There was also an unrelated pre-existing deletion left untouched:

- `.claude/scheduled_tasks.lock`

## Resume Order For The Next Session

1. Read this checkpoint.
2. Read the auth verification checklist in [docs/setup/auth-runtime-verification-playbook.md](/Volumes/DevSSD/FitTracker2/docs/setup/auth-runtime-verification-playbook.md).
3. Patch the sign-in smoke to drive onboarding step 5 instead of asserting too early.
4. Rerun `sign_in_surface` in staging.
5. If it passes, continue to the real auth provider runtime checks from the playbook.
