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
- [FitTracker/Views/Onboarding/v2/OnboardingAuthView.swift](/Volumes/DevSSD/FitTracker2/FitTracker/Views/Onboarding/v2/OnboardingAuthView.swift) gained stable onboarding-auth accessibility identifiers.
- [FitTracker/FitTrackerApp.swift](/Volumes/DevSSD/FitTracker2/FitTracker/FitTrackerApp.swift) now supports a launch-only `FITTRACKER_FORCE_ONBOARDING=1` override so the sign-in smoke can verify the embedded auth step deterministically without depending on prior simulator onboarding state.
- [FitTrackerUITests/UITestSupport.swift](/Volumes/DevSSD/FitTracker2/FitTrackerUITests/UITestSupport.swift) now pairs `FITTRACKER_SKIP_AUTO_LOGIN=1` with `FITTRACKER_FORCE_ONBOARDING=1` for `forcedSignIn`.
- [FitTrackerUITests/SignInUITests.swift](/Volumes/DevSSD/FitTracker2/FitTrackerUITests/SignInUITests.swift) now drives the onboarding path through step 5 before asserting auth controls, so the smoke reflects the real product flow instead of a stale direct-to-auth assumption.

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

### 3. Staging sign-in surface smoke passed

Report:
[.claude/shared/runtime-smoke-staging-sign-in-surface.json](/Volumes/DevSSD/FitTracker2/.claude/shared/runtime-smoke-staging-sign-in-surface.json)

Verified state from timestamp `2026-04-23T13:55:00Z`:

- profile: `sign_in_surface`
- mode: `staging`
- status: `passed`
- return code: `0`
- result bundle:
  `/Volumes/DevSSD/FitTracker2/.build/RuntimeSmokeDerivedData/Logs/Test/Test-FitTracker-2026.04.23_16-55-04-+0300.xcresult`

The key fix was not credentials. It was harness alignment:

- `FITTRACKER_SKIP_AUTO_LOGIN=1` only disables session restore; it does not reset onboarding completion.
- on a simulator that already completed onboarding, the old smoke could not truthfully assume `Get Started` would appear.
- the new `FITTRACKER_FORCE_ONBOARDING=1` launch override makes the embedded auth step deterministic for this smoke without changing default product behavior.

## Exact Next Runnable

Run the real provider checklist from [docs/setup/auth-runtime-verification-playbook.md](/Volumes/DevSSD/FitTracker2/docs/setup/auth-runtime-verification-playbook.md):

1. Email sign-up
2. Email verification / resend
3. Email login
4. Password reset
5. Google sign-in
6. Relaunch / session restore
7. Negative auth cases

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
- `FitTracker/Views/Onboarding/v2/OnboardingAuthView.swift`
- `FitTracker/FitTrackerApp.swift`
- `FitTrackerUITests/SignInUITests.swift`
- `FitTrackerUITests/UITestSupport.swift`

There was also an unrelated pre-existing deletion left untouched:

- `.claude/scheduled_tasks.lock`

## Resume Order For The Next Session

1. Read this checkpoint.
2. Read the auth verification checklist in [docs/setup/auth-runtime-verification-playbook.md](/Volumes/DevSSD/FitTracker2/docs/setup/auth-runtime-verification-playbook.md).
3. Use the now-green staging smoke reports as the baseline runtime proof for harness readiness.
4. Continue to the real auth provider runtime checks from the playbook.
