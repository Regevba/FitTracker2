# Auth Runtime Verification Playbook

> Purpose: safely validate FitMe's real Supabase-backed email and Google auth flows without polluting the repo with local secrets or overstating production readiness.
> Status: active maintenance playbook
> Last updated: 2026-04-21

---

## Why this exists

Repo wiring is no longer the main auth problem. The remaining gap is runtime proof:

- real Supabase credentials
- real Google client IDs and URL scheme values
- end-to-end validation for email and Google auth
- session restore after relaunch

This playbook keeps that work repeatable and safe.

## Safety rules

1. Never commit real secrets, client IDs, or downloaded provider files.
2. Keep the checked-in `Info.plist` placeholders intact in git.
3. Put real local values in `Config/Local/*.xcconfig`, not in tracked plist files.
4. Record evidence in docs, Notion, Linear, and the shared PM files only after a real validation step passes.
5. If any step is only compile-verified, say `compile-verified`, not `runtime-verified`.

## Local-only materials

| Item | Where it comes from | Where it is used |
|---|---|---|
| `FITTRACKER_SUPABASE_URL` | Supabase Dashboard > Settings > API | `Config/Local/Debug.xcconfig` or `Config/Local/Staging.xcconfig` |
| `FITTRACKER_SUPABASE_ANON_KEY` | Supabase Dashboard > Settings > API | `Config/Local/Debug.xcconfig` or `Config/Local/Staging.xcconfig` |
| `FITTRACKER_GOOGLE_CLIENT_ID` | Google Cloud / Firebase iOS OAuth client | `Config/Local/Debug.xcconfig` or `Config/Local/Staging.xcconfig` |
| `FITTRACKER_GOOGLE_REVERSED_CLIENT_ID` | Google Cloud / Firebase iOS OAuth client | `Config/Local/Debug.xcconfig` or `Config/Local/Staging.xcconfig` |
| `GoogleService-Info.plist` | Firebase console | local app bundle only if Firebase runtime validation is also needed |

## Recommended safe setup flow

### Option A — current project-compatible flow

Use the checked-in placeholders as the stable repo baseline, then inject local values through the untracked xcconfig overlay:

1. Confirm the current repo has placeholder-backed values in `FitTracker/Info.plist`.
2. Copy `Config/Local/Debug.example.xcconfig` or `Config/Local/Staging.example.xcconfig` to the matching non-example filename.
3. Fill in the real local values for:
   - `FITTRACKER_SUPABASE_URL`
   - `FITTRACKER_SUPABASE_ANON_KEY`
   - `FITTRACKER_GOOGLE_CLIENT_ID`
   - `FITTRACKER_GOOGLE_REVERSED_CLIENT_ID`
   - `FITTRACKER_PASSKEY_RELYING_PARTY_ID` if passkey verification is needed
   - `FITTRACKER_AI_ENGINE_BASE_URL` if a staging AI endpoint is part of the smoke path
4. Select the matching Xcode configuration (`Debug` or `Staging`).
5. Run the verification sequence below.
6. Capture evidence.
7. Confirm the local xcconfig remains untracked before committing anything.

## Provider configuration checklist

### Supabase

- Email/password provider enabled
- Email verification behavior understood and intentionally configured
- Password reset emails enabled
- Redirect URLs match the app configuration
- Any test users are clearly non-production accounts

### Google

- Google Sign-In package is present in `FitTracker.xcodeproj`
- `GoogleAuthProvider.swift` is in the target
- iOS OAuth client exists for the app bundle ID
- reversed client ID matches the URL scheme in `Info.plist`
- Supabase Google provider is configured if the app path exchanges against Supabase

## Pre-flight checks

Before runtime validation:

1. Build the iOS app successfully.
2. Confirm the simulator or device is signed out of any stale test state if the run needs a clean auth session.
3. Delete the app from the simulator if you need to re-test first-run onboarding or auth setup.
4. Confirm network access to Supabase and Google sign-in endpoints.
5. Confirm test inbox access for email verification and password-reset links/codes.

## Verification sequence

Run these in order and log pass/fail for each:

### 1. Email sign-up

- Create a new test account
- Verify field validation and error states
- Confirm the account is created in Supabase

### 2. Email verification / resend

- Complete the verification flow
- Trigger resend once
- Confirm expired or invalid codes fail clearly

### 3. Email login

- Log in with the verified account
- Confirm success UI state and authenticated app entry

### 4. Password reset

- Trigger `Forgot password?`
- Complete the reset flow
- Log in with the new password

### 5. Google sign-in

- Start from a signed-out state
- Run the Google flow
- Confirm the app returns successfully through the configured URL scheme
- Confirm the authenticated session is present in app state and backend state

### 6. Relaunch / session restore

- Fully terminate the app
- Relaunch
- Confirm the session restores correctly
- Confirm token refresh does not strand the user in a bad auth state

### 7. Negative cases

- Missing network
- Bad verification code
- Invalid credentials
- Cancelled Google flow
- Expired session / refresh path

## Evidence to capture

Minimum evidence for a truthful status change:

- date and environment used
- simulator or device used
- provider(s) tested
- exact steps passed
- any steps still blocked
- screenshots only when they add diagnostic value
- repo/docs/Linear/Notion updates made after the run

## Safe rollback after testing

After local verification:

1. Remove any local-only downloaded provider files that should not remain in the repo.
2. Confirm `git diff` contains only intended code/doc changes, not secrets.
3. Update:
   - `docs/product/prd/18.6-authentication.md`
   - `FIT-6`
   - `Chapter 3 — Auth Hardening`
   - shared PM monitoring files

## Truth labels to use

Use these exact labels in docs and planning:

- `repo-wired` — source/package/target/config scaffolding exists
- `compile-verified` — build succeeded
- `runtime-verified` — real provider flow completed successfully
- `config-gated` — feature remains hidden until valid local config is present
- `not production-ready` — any critical runtime verification is still missing

## Follow-on improvements

- Add an auth verification checklist to the control room knowledge hub.
- Add a small regression checklist for every future auth-related change so this playbook stays reusable.
