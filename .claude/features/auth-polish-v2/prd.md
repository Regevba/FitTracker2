# PRD: auth-polish-v2

> **Owner:** Regev
> **Date:** 2026-04-27
> **Phase:** 1 (PRD)
> **Status:** Draft (ready for approval)
> **Work Type:** Feature
> **Framework:** v7.6 PM Workflow
> **Parent features:** authentication, onboarding-v2-auth-flow (PR #80)
> **Linear:** to be filed on Phase 2 approval
> **GitHub Issue:** [#143](https://github.com/Regevba/FitTracker2/issues/143)
> **Branch:** `feature/auth-polish-v2`

---

## Purpose

Close three intentionally-related gaps on the existing auth surface in a single coordinated release: (a) a dedicated forgot-email/password recovery flow with deep-link return, (b) refined biometric (Face ID / Touch ID) unlock UI plus a one-time post-sign-in activation prompt, and (c) Google Sign In SDK activation that lights up UI rows already wired but currently hidden. The bundle ships on one branch, one PR, one analytics taxonomy update, and one auth-runtime smoke run.

## Business objective

The auth path is the #1 high-risk area in CLAUDE.md and a confirmed Gate C launch-readiness blocker on the master plan ("Authentication hardening — runtime credentials needed"). Closing these three items in one move:

1. Removes 3 of the 4 outstanding auth checklist items (Apple Services-ID is the 4th and remains deferred — it is a Developer-console action, not a code action).
2. Unlocks the auth runtime smoke profile to flip from `partial` to `full` once Sentry MCP and `GoogleService-Info.plist` land (those are Gate C peers, separately tracked).
3. Demonstrates a v7.6 case-study-from-day-one feature, which the framework needs as another non-trivial real-world data point alongside `unified-control-center`.
4. Improves auth-recovery success rate, the proxy metric for trust in the encrypted-data product story.

## Target personas

| Persona | Relevance |
|---|---|
| Consistent Lifter | Daily-active. Needs biometric unlock to remove friction on every relaunch. |
| Health-Conscious Professional | Time-constrained. Forgot-password recovery is the difference between recovering an account and uninstalling. |
| Data-Driven Optimizer | Multi-device. Google Sign-In gives them a portable identity across Mac + iPhone + iPad without per-device credential entry. |

## Has UI?

**Yes.** 5 new views/sheets, 2 modified existing views.

| Surface | Type | Notes |
|---|---|---|
| `ForgotPasswordView` | New | Email entry, primary "Send reset link" CTA |
| `EmailSentConfirmationView` | New | Inbox-confirmation, resend (60s cooldown), change-email |
| `SetNewPasswordView` | New | Two `PasswordRulesSecureField` + rules tooltip + auto-login on success |
| `BiometricUnlockView` | New | Full-screen, biometric-first unlock when stored session + setting enabled |
| `BiometricActivationSheet` | New | One-time post-sign-in modal offering activation |
| `AuthHubView` | Modified | Replace tertiary biometric row with conditional gate that promotes to full screen; flip `isGoogleAuthAvailable` once SDK lands |
| `OnboardingAuthView` | Modified | No structural change — Google row will auto-render once SDK lands |

## Requires analytics?

**Yes.** 7 new events, 3 new screens, 0 new user properties (within the 25 cap). Analytics Spec section below is non-skippable per the v7.6 gate.

## Functional requirements

| # | Requirement | Priority | Source |
|---|---|---|---|
| FR-1 | Forgot-password tap opens dedicated `ForgotPasswordView` (not just an inline button on `EmailLoginView`) | Critical | research §6.1 |
| FR-2 | Tapping "Send reset link" calls `signIn.requestPasswordReset(email:)` and routes to `EmailSentConfirmationView` regardless of whether the email exists (privacy: don't enumerate accounts) | Critical | research §3 ("forgot-password approach"); industry standard |
| FR-3 | `EmailSentConfirmationView` exposes "Resend email" with 60-second cooldown and "Use a different email" → back to step 1 | High | research §6.1 |
| FR-4 | App registers `fitme://reset-password` URL scheme; `FitTrackerApp.swift` `.onOpenURL` handler routes recovery deep links to `SetNewPasswordView` after `client.auth.session(from: url)` | Critical | [Supabase deep linking](https://supabase.com/docs/guides/auth/native-mobile-deep-linking) |
| FR-5 | Supabase dashboard redirect URL `fitme://reset-password` is whitelisted (out-of-code config; documented in PRD Appendix C as a launch-checklist item) | Critical | Supabase dashboard config |
| FR-6 | `SetNewPasswordView` enforces existing `UITextInputPasswordRules` (6-14 chars, 1 cap, 1 num, 1 special) and on success: auto-signs-in, navigates to Home, fires `auth_password_reset_completed` | High | reuse existing `PasswordRulesSecureField` |
| FR-7 | Biometric-first unlock screen renders when `signIn.hasStoredSession && settings.requireBiometricUnlockOnReopen && biometricAuth.isAvailable` (replaces current tertiary row) | Critical | research §6.2 |
| FR-8 | `BiometricUnlockView` shows brand icon, hero "Welcome back, {firstName}", 88pt biometric icon, primary "Unlock with {biometricLabel}" CTA, secondary "Use password" → `EmailLoginView` | High | research §6.2 + Apple HIG |
| FR-9 | `BiometricActivationSheet` presents once after first email/Google sign-in if `biometricAuth.isAvailable && !settings.requireBiometricUnlockOnReopen && !settings.hasAskedForBiometricActivation` | Critical | research §6.2 |
| FR-10 | Activation sheet's primary CTA triggers `LAContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics)` — the scan IS the consent. On success: set both `requireBiometricUnlockOnReopen = true` AND `hasAskedForBiometricActivation = true`. On cancel/fail: only `hasAskedForBiometricActivation = true` | Critical | Apple HIG §"Biometric prompts" |
| FR-11 | New `AppSettings.hasAskedForBiometricActivation: Bool = false` persisted property, defaults false, never reset by sign-out | High | new settings field |
| FR-12 | Add `GoogleSignIn-iOS` SPM dependency (latest 8.x) | Critical | research §3 |
| FR-13 | Add `GIDClientID` to Info.plist; read from `GoogleService-Info.plist` (single source) so it shares the Firebase analytics config | Critical | per Phase 0 open question default |
| FR-14 | Add reverse-DNS URL scheme to Info.plist (matches GoogleSignIn requirement) | Critical | GoogleSignIn-iOS docs |
| FR-15 | `GoogleAuthProvider.signIn()` body calls `GIDSignIn.sharedInstance.signIn(withPresenting:)`, extracts ID token, calls `supabase.auth.signInWithIdToken(credentials: .init(provider: .google, idToken: ..., accessToken: ..., nonce: ...))` per [Supabase Discussion #34959](https://github.com/orgs/supabase/discussions/34959) nonce semantics | Critical | research §3 |
| FR-16 | `GoogleRuntimeConfiguration.isConfigured` returns true iff `GIDClientID` is present in Info.plist AND a `GoogleService-Info.plist` is bundled. UI gates auto-flip once both exist | Critical | minimal change to existing config check |
| FR-17 | All flows handle network failure inline (no full-screen error states); error banners use existing `AuthBannerView` | High | match existing UX pattern |
| FR-18 | Repair `ColorAppColor` typos at [AuthHubView.swift:635](FitTracker/Views/Auth/AuthHubView.swift#L635) and [AuthHubView.swift:825](FitTracker/Views/Auth/AuthHubView.swift#L825) → `AppColor.Status.error` and `AppColor.Brand.secondary` | Critical | research §8 ("Existing-code finding") |

## User flows

### Flow A — Forgot password (happy path, in-app return)

1. User on `EmailLoginView` taps "Forgot password?" with email pre-filled
2. Routes to `ForgotPasswordView` with email pre-filled
3. User taps "Send reset link" → `auth_password_reset_requested` fires
4. Routes to `EmailSentConfirmationView` ("Check your inbox — we sent a link to {email}")
5. User taps the link in their email client → iOS opens FitMe via `fitme://reset-password#access_token=...&refresh_token=...`
6. App's `.onOpenURL` calls `client.auth.session(from: url)` → session active
7. App routes to `SetNewPasswordView`
8. User enters new password (validated via existing rules) → tap "Update password"
9. `auth_password_reset_completed` fires; app routes to Home (already authenticated)

### Flow B — Forgot password (cooldown / wrong email / cross-device)

- **Resend** (within 60s of step 4): button is disabled with countdown; `auth_password_reset_resend_blocked` fires
- **Resend** (after 60s): button enabled; tapping fires `auth_password_reset_resend` and re-enters the cooldown
- **Wrong email**: tap "Use a different email" → back to step 2 with email field cleared
- **Cross-device**: user opens email on desktop → web link opens browser → user can complete reset via Supabase hosted page, OR can ignore link and try again from phone (no friction either way)

### Flow C — Biometric activation (first sign-in, device supports biometrics)

1. User completes email or Google sign-in
2. `RootTabView` checks: `biometricAuth.isAvailable && !settings.requireBiometricUnlockOnReopen && !settings.hasAskedForBiometricActivation` — true
3. `BiometricActivationSheet` presents with: brand icon, "Unlock {AppBrand.name} with {biometricLabel}", one-line assurance, "Enable {biometricLabel}" + "Not now"
4. `auth_biometric_activation_offered` fires
5. User taps "Enable {biometricLabel}" → `LAContext.evaluatePolicy(...)` → biometric scan → success
6. `auth_biometric_activated` fires; both flags set; sheet dismisses; user lands on Home
7. Next app relaunch → `BiometricUnlockView` (Flow E) instead of `AuthHubView`

### Flow D — Biometric activation (declined)

1-4. Same as Flow C
5. User taps "Not now" → only `hasAskedForBiometricActivation = true` is set
6. `auth_biometric_activation_declined` fires; sheet dismisses
7. User can still enable later from Settings → Privacy & Security
8. Sheet does NOT re-prompt automatically (one-shot per CLAUDE.md "Approval gates are multi-part" memory — don't ask again unless user opts in)

### Flow E — Biometric unlock on relaunch

1. App launches → `restoreSession()` finds stored session; `requireBiometricUnlockOnReopen = true`
2. `RootTabView` shows `BiometricUnlockView` instead of `AuthHubView`
3. User sees "Welcome back, {firstName}" + large biometric icon + "Unlock with {biometricLabel}"
4. User taps CTA → `LAContext.evaluatePolicy(...)` → success → Home
5. `auth_biometric_unlock_completed` fires

### Flow F — Biometric unlock fallback

1-3. Same as Flow E
4. Biometric scan fails (user pulled iPhone away, mask, etc.) → second attempt offered automatically by `LAContext`
5. After 2 failures or 1 user cancel: secondary CTA "Use password" routes to `EmailLoginView` with email pre-filled from stored session
6. `auth_biometric_unlock_failed` fires with `reason: "user_cancel" | "biometry_failed"`

### Flow G — Google Sign-In (new user)

1. User on `OnboardingAuthView` step 5 OR `AuthHubView` taps "Continue with Google"
2. `auth_signin_started` fires with `provider: "google"`
3. `GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)` opens native sheet
4. User selects Google account → grants consent
5. Google returns `GIDSignInResult` with ID token + access token + nonce
6. `supabase.auth.signInWithIdToken(...)` exchanges for Supabase session
7. `auth_signin_completed` fires with `provider: "google"`
8. Onboarding continues to step 6 (success animation) OR `AuthHubView` dismisses to Home
9. **First-time post-sign-in:** Flow C triggers (biometric activation sheet) immediately

### Flow H — Google Sign-In (returning user, cancelled)

1. User taps "Log in with Google" → native sheet
2. User taps "Cancel" → `GIDSignInError` thrown
3. `auth_signin_cancelled` fires with `provider: "google"`
4. `AuthBannerView` shows "Google sign-in cancelled. Try again or use another method."
5. User stays on auth screen

## Current state & gaps

| Gap | Today | After this feature |
|---|---|---|
| Forgot password | Inline button on `EmailLoginView`, sends email but no in-app return path | Dedicated 3-screen flow with deep-link return |
| Biometric UI | Tertiary row in `AuthHubView` | Full-screen unlock when applicable + activation sheet on first sign-in |
| Google Sign-In | UI exists, gated to `false` | UI active, real SDK, real Supabase bridge |
| `ColorAppColor` typos | Two unresolved symbols in `AuthHubView` | Repaired to `AppColor.*` |
| `hasAskedForBiometricActivation` flag | Doesn't exist | Added to `AppSettings` |

## Non-goals (explicit exclusions)

| Item | Why excluded | Tracked in |
|---|---|---|
| Apple Sign In Services-ID setup | Requires Apple Developer console action; outside repo scope | Backlog "Apple Sign In (needs Services ID)" |
| Smart reminder management UI | Different feature, different parent (smart-reminders), different review surface | Tracked separately as `smart-reminders-ui` enhancement (next PM cycle) |
| Sentry MCP connection | Gate C peer; unrelated to auth code path | Backlog "Sentry Error Tracking Integration" |
| `GoogleService-Info.plist` provisioning | One-time per-environment Firebase action; user supplies the file | Will be handled at deploy/release time, documented in Appendix C |
| Phone OTP registration | Already deferred per `docs/design-system/deferred-phone-otp-task.md` | Existing deferral |
| Apple Watch / iPad-specific layouts | Out of scope for v1 | Backlog "Icebox" |

## Success metrics

### Primary metric

**Auth recovery success rate** = (`auth_password_reset_completed` ∪ `auth_biometric_unlock_completed` ∪ (`auth_signin_completed` where `provider=google`)) / (`auth_password_reset_requested` + `auth_biometric_unlock_offered` + `auth_signin_started` where provider=google).

| Field | Value |
|---|---|
| Baseline | unmeasured (events do not exist yet) |
| 30-day post-ship target | establish baseline, no target |
| 60-day post-ship target | ≥ 70% |
| 90-day post-ship target | ≥ 75% |
| Tier | T1 (Instrumented) — fully measurable from GA4 from day one |

### Secondary metrics

| Metric | 30-day target | 60-day target | Tier |
|---|---|---|---|
| `auth_password_reset_completed` / `auth_password_reset_requested` | establish baseline | ≥ 60% | T1 |
| `auth_biometric_activated` / `auth_biometric_activation_offered` | ≥ 25% | ≥ 35% | T1 |
| `auth_signin_completed` with `provider=google` / total `auth_signin_completed` | establish baseline | ≥ 20% | T1 |
| Biometric unlock latency P95 (`auth_biometric_unlock_completed.duration_ms`) | report only | < 1500ms | T1 |

### Guardrail metrics (must not degrade)

| Guardrail | Threshold | Source |
|---|---|---|
| `auth_signin_completed` overall rate (all providers) | not below current baseline -5% | new GA4 event vs onboarding-v2 baseline |
| Crash-free rate | > 99.5% | CLAUDE.md system-wide guardrail |
| Cold start P95 (Sentry once wired; baseline today via local profiling) | < 2s | CLAUDE.md system-wide guardrail; GoogleSignIn SDK init must not push us over |
| `requireBiometricUnlockOnReopen = true` users / total signed-in users | ≥ 25% by day 14 | derived from `auth_biometric_activated` count |
| `auth_password_reset_resend_blocked` rate | < 5% (otherwise cooldown UX is wrong) | new GA4 event |

### Leading indicators (within 1 week)

- `auth_biometric_activation_offered` event fires for ≥ 80% of users who complete a sign-in (sanity check that the trigger condition fires)
- `auth_password_reset_requested` produces a corresponding `auth_password_reset_completed` within 1 hour for ≥ 50% of cases (sanity check that the deep-link return path works)
- `auth_signin_completed` with `provider=google` is non-zero (sanity check Google SDK is wired)

### Lagging indicators

- 30 days: baseline for primary + secondary metrics established with confidence intervals
- 60 days: primary metric ≥ 70%; investigate any miss
- 90 days: primary ≥ 75%; case study published

### Kill criteria

| Trigger | Action |
|---|---|
| `auth_biometric_activation_offered` ↑ but `auth_biometric_activated` < 5% by day 14 | Iterate copy/timing. If second iteration doesn't move it, kill the activation sheet and move biometric to Settings-only. |
| Google Sign-In produces > 0.5% crashes/hangs (Sentry once wired, or App Store reports) | Set `GoogleRuntimeConfiguration.isConfigured` to `false` via remote-config (Phase 4 contingency: ship a feature flag for this) → UI auto-hides Google rows. |
| Forgot-password deep-link return fails > 10% of attempted resets | Regress to status-banner-only mode (current behavior) by routing `requestPasswordReset` to the existing inline path. Diagnose URL scheme / Supabase whitelist. |
| `auth_signin_completed` overall rate drops > 5% week-over-week | Halt rollout, investigate. Most likely cause: GoogleSignIn SDK conflict with another SPM dep. |

### Review cadence

- **Day 7:** sanity-check leading indicators. Owner: Regev. Output: thumbs-up/down on whether instrumentation is producing data.
- **Day 14:** activation-sheet conversion check. Owner: Regev + analytics review.
- **Day 30:** establish baselines. Output: append actuals to PRD §metrics.
- **Day 60:** primary-metric target evaluation. Output: keep / iterate / kill.
- **Day 90:** case-study publication.

### Instrumentation plan

All metrics are T1 (Instrumented) via GA4 events fired through the existing `AnalyticsService` injected into `SignInService` and `AuthManager`. No new analytics infrastructure needed — we extend the existing taxonomy.

---

## Analytics Spec (GA4 Event Definitions) — required by v7.6 gate

### New events (7)

| Event name | Category | GA4 type | Trigger screen | Parameters | Conversion? |
|---|---|---|---|---|---|
| `auth_password_reset_requested` | engagement | recommended-style custom | `forgot_password` | `email_provided: bool` | No |
| `auth_password_reset_completed` | engagement | recommended-style custom | `set_new_password` | `time_to_complete_seconds: int` (between requested and completed for the same email — privacy-safe because we hash email at the GA4 ingest layer) | Yes |
| `auth_password_reset_resend` | engagement | custom | `email_sent_confirmation` | `attempt_number: int` (2,3,4...) | No |
| `auth_password_reset_resend_blocked` | engagement | custom | `email_sent_confirmation` | `cooldown_remaining_seconds: int` | No |
| `auth_biometric_activation_offered` | engagement | custom | `biometric_activation_sheet` | `biometric_type: "face_id" \| "touch_id"` | No |
| `auth_biometric_activated` | engagement | custom | `biometric_activation_sheet` | `biometric_type: "face_id" \| "touch_id"`, `provider: "email" \| "google" \| "apple" \| "passkey"` | Yes |
| `auth_biometric_activation_declined` | engagement | custom | `biometric_activation_sheet` | `biometric_type: "face_id" \| "touch_id"` | No |
| `auth_biometric_unlock_completed` | engagement | custom | `biometric_unlock` | `biometric_type: "face_id" \| "touch_id"`, `duration_ms: int` | No |
| `auth_biometric_unlock_failed` | engagement | custom | `biometric_unlock` | `biometric_type: "face_id" \| "touch_id"`, `reason: "user_cancel" \| "biometry_failed" \| "system_cancel" \| "passcode_not_set"` | No |

(Note: 9 events listed; "7 new" in the FR table is shorthand — formal taxonomy = 9.)

### Reused events (existing — already in `AnalyticsEvent` enum)

- `auth_signin_started` (will gain new `provider: "google"` value via existing `provider` parameter — not a new event, taxonomy extension)
- `auth_signin_completed` (same — `provider` parameter extended to `"google"`)
- `auth_signin_cancelled` (same)

### New parameters (3)

| Parameter | Type | Allowed values | Used by |
|---|---|---|---|
| `biometric_type` | string | `"face_id"`, `"touch_id"`, `"optic_id"`, `"none"` | activation + unlock events |
| `time_to_complete_seconds` | int | 0..86400 (1 day cap) | `auth_password_reset_completed` |
| `cooldown_remaining_seconds` | int | 0..60 | `auth_password_reset_resend_blocked` |
| `attempt_number` | int | 1..10 | `auth_password_reset_resend` |
| `duration_ms` | int | 0..30000 | `auth_biometric_unlock_completed` |
| `reason` | string | enum per event spec | `auth_biometric_unlock_failed` |

(`provider` — existing parameter, extended set: add `"google"` to allowed values.)

### New screens (3)

| Screen name | SwiftUI view | Category |
|---|---|---|
| `forgot_password` | `ForgotPasswordView` | auth |
| `email_sent_confirmation` | `EmailSentConfirmationView` | auth |
| `set_new_password` | `SetNewPasswordView` | auth |
| `biometric_unlock` | `BiometricUnlockView` | auth |
| `biometric_activation_sheet` | `BiometricActivationSheet` | auth |

(5 new screens; "3 new" in the requires_analytics summary was wrong — formal count = 5.)

### New user properties

**None.** Stays at current count, well below the 25 cap.

### Naming Validation Checklist (per `AnalyticsProvider.swift` rules)

- [x] All event names snake_case, lowercase
- [x] All event names ≤ 40 characters (longest: `auth_password_reset_resend_blocked` = 33)
- [x] All parameter names snake_case, lowercase
- [x] No reserved prefixes (`ga_`, `firebase_`, `google_`)
- [x] No PII in any parameter (no email values, no names, no user IDs)
- [x] All parameter values ≤ 100 characters
- [x] All events have ≤ 25 parameters (max here = 3)
- [x] Total custom user properties ≤ 25 after additions (still 0 added)
- [x] No duplicate names against existing enums (verified by greppable convention; Phase 4 will assert via test)
- [x] All events follow project screen-prefix convention from CLAUDE.md (`auth_*` for auth-scoped events)
- [x] Cross-screen lifecycle events stay unprefixed (no new ones in this feature)

---

## AI behaviors

**None.** No AI/ML logic. `eval_results.min_eval_coverage_met` auto-passes per v6.0 gate.

## Test & Eval Requirements

### Unit tests (per Phase 5 gate)

| Test suite | Coverage |
|---|---|
| `ForgotPasswordViewTests` | Email validation, button-disable on empty, navigation to confirmation on success, error banner on `requestPasswordReset` throw |
| `SetNewPasswordViewTests` | Password rule enforcement (mocked), auto-login on success, error path |
| `BiometricUnlockViewTests` | Biometric icon mapping (face/touch/optic), unlock success path, fallback button visibility |
| `BiometricActivationSheetTests` | Trigger-condition logic (3-flag gate), `LAContext` evaluation success/cancel paths, persistence of both flags |
| `SignInServiceTests` (new cases) | `signInWithGoogle` calls Google provider then Supabase, error propagation, `provider` param population |
| `AnalyticsTests` (new cases) | Each of the 9 new events fires with correct params + screen tracking |
| `AppDelegateUrlHandlerTests` | `fitme://reset-password#access_token=...&refresh_token=...` parses to a `SetNewPasswordView` route |

**Estimated total new tests:** ~25-30.

### Integration / smoke tests

- `make runtime-smoke PROFILE=sign_in_surface MODE=local` must pass on `feature/auth-polish-v2`
- Manual smoke: deep-link return from a real email send (requires Supabase Tokyo project, real GoogleService-Info.plist) — flagged in Phase 5 acceptance gate

### Eval coverage

N/A (no AI behaviors). `min_eval_coverage_met = true` automatically.

---

## Technical implementation notes

### Branch hygiene

- All work on `feature/auth-polish-v2`
- Commits follow `feat(auth-polish-v2): ...` / `fix(auth-polish-v2): ...` / `docs(auth-polish-v2): ...` convention
- v7.6 pre-commit hooks active: schema enforcement, phase-transition logging, PR citation validation, case-study tier tags

### Files touched (estimated)

| Path | Type | Reason |
|---|---|---|
| `FitTracker/Views/Auth/AuthHubView.swift` | Modified | Conditional gate to BiometricUnlockView; `ColorAppColor` typo fix |
| `FitTracker/Views/Auth/SignInView.swift` | Modified (minor) | New `provider: .google` mapping in helpers |
| `FitTracker/Views/Auth/ForgotPasswordView.swift` | New | FR-1, FR-2 |
| `FitTracker/Views/Auth/EmailSentConfirmationView.swift` | New | FR-3 |
| `FitTracker/Views/Auth/SetNewPasswordView.swift` | New | FR-6 |
| `FitTracker/Views/Auth/BiometricUnlockView.swift` | New | FR-7, FR-8 |
| `FitTracker/Views/Auth/BiometricActivationSheet.swift` | New | FR-9, FR-10 |
| `FitTracker/Services/Auth/SignInService.swift` | Modified | Real `GoogleAuthProvider.signIn()` body, password-reset routing |
| `FitTracker/Services/Auth/GoogleRuntimeConfiguration.swift` | Modified | Read `GIDClientID` from Info.plist |
| `FitTracker/Services/AppSettings.swift` | Modified | Add `hasAskedForBiometricActivation` |
| `FitTracker/FitTrackerApp.swift` | Modified | `.onOpenURL` handler for `fitme://reset-password` |
| `FitTracker/Services/Analytics/AnalyticsProvider.swift` | Modified | Add 9 events, 6 params, 5 screens |
| `FitTracker/Info.plist` | Modified | URL scheme `fitme`, GoogleSignIn reverse-DNS scheme, `GIDClientID` |
| `FitTracker.xcodeproj/project.pbxproj` | Modified | Add new Swift files, add SPM dependency on `GoogleSignIn-iOS` |
| `FitTrackerTests/AnalyticsTests.swift` | Modified | New analytics tests |
| `FitTrackerTests/Auth*Tests.swift` | New (multiple) | Unit tests per FR |
| `FitTrackerTests/AppDelegateUrlHandlerTests.swift` | New | Deep-link parsing |
| `docs/product/analytics-taxonomy.csv` | Modified | 9 event rows + 6 param rows + 5 screen rows |
| `docs/product/prd/auth-polish-v2.md` | New | This PRD copied for `docs/product/prd/` index |
| `docs/case-studies/auth-polish-v2-case-study.md` | New | Case study scaffold lands in Phase 1 (not Phase 8) per v7.6 case-study-from-day-one |

**Estimated total: 17 modified + 9 new = 26 files. Crosses the 5-file threshold → mandatory feature branch (already chosen).**

### Risk register

| Risk | Severity | Likelihood | Mitigation |
|---|---|---|---|
| GoogleSignIn 8.x nonce API shift breaks Supabase ID-token exchange | High | Medium | Phase 4 acceptance gate: minimal vertical slice (Google → Supabase round-trip) tested before any UI work |
| Deep-link URL scheme conflicts with future deep-link surfaces (achievements, share-link) | Medium | Low | Reserve `fitme://reset-password` and document the scheme convention in `docs/architecture/deep-linking.md` (new doc, Phase 8) |
| `LAContext` policy change between iOS versions | Low | Low | `evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics)` is stable since iOS 11 |
| `ColorAppColor` typo turns out to mask a build break that's been silent | Medium | Low | Phase 4 starts with `xcodebuild build` to verify current state. If broken, T0 fixes it before any FR work |
| Activation-sheet copy doesn't drive ≥ 25% conversion | Medium | Medium | Day-14 review checkpoint; iterate copy if needed; kill criteria documented |
| GoogleSignIn SDK adds noticeable cold-start regression | Medium | Low | Lazy-init via `GIDSignIn.sharedInstance` is idle-cheap; verify with cold-start measurement before/after |

### Rollout plan

| Step | When | Owner |
|---|---|---|
| Merge PR to main | Phase 7 | Regev |
| Vercel auto-deploys (no-op for iOS) | On merge | Vercel |
| iOS build TestFlight roll | Post-merge | Manual (out of scope for this PRD) |
| Day 7 review | T+7 days post first TestFlight install | Regev |
| Day 14 activation-sheet review | T+14 | Regev |
| Day 30 baseline establishment | T+30 | Regev |
| Day 60 primary-metric eval | T+60 | Regev |
| Day 90 case study publication | T+90 | Regev |

---

## Decisions Log (Phase 0 open questions resolved)

| OQ | Decision | Rationale |
|---|---|---|
| OQ-1: Activation-prompt timing (immediate vs second launch) | **Immediate** after first sign-in | User receptiveness peaks at the just-typed-credentials moment; Whoop pattern; Strava's second-launch is more conservative but loses ~15-20% activation per their public talks |
| OQ-2: Forgot-password redirect URL scheme | **`fitme://reset-password`** | Project brand prefix, future-extensible for other deep links |
| OQ-3: `GIDClientID` source | **Read from `GoogleService-Info.plist`** | One config file for both Firebase and Google Sign-In; unified Gate C launch checklist |

These three answers are PRD-locked. If any is wrong, this is the moment to push back.

---

## Phase 1 exit criteria checklist

- [x] Purpose, business objective, personas
- [x] `has_ui = true` confirmed
- [x] `requires_analytics = true` confirmed
- [x] Functional requirements (18, prioritized)
- [x] User flows (8: A-H)
- [x] Current state & gaps
- [x] Non-goals
- [x] Primary metric with baseline + target + tier
- [x] 4 secondary metrics with tier
- [x] 5 guardrail metrics
- [x] Leading + lagging indicators
- [x] Kill criteria (4 triggers)
- [x] Review cadence (5 milestones)
- [x] Instrumentation plan
- [x] Analytics Spec — 9 events, 6 params, 5 screens, 0 user props
- [x] Naming Validation Checklist (10 boxes)
- [x] AI behaviors section (none — auto-pass)
- [x] Test & Eval requirements
- [x] Risk register (6 entries)
- [x] Rollout plan
- [x] Decisions Log (3 OQs resolved)
- [x] Files-touched estimate (26 total — flags mandatory feature branch)
- [x] Case-study scaffold flagged as Phase 1 deliverable (not Phase 8) per v7.6

**Ready for user approval to advance Phase 1 → Phase 2 (Tasks).**

---

## Appendix A — Event taxonomy for `analytics-taxonomy.csv`

(Will be transcribed verbatim into the CSV during Phase 4 task T-analytics-1. Held here as the canonical PRD source.)

```
auth_password_reset_requested,engagement,custom,forgot_password,"email_provided",no,auth
auth_password_reset_completed,engagement,custom,set_new_password,"time_to_complete_seconds",yes,auth
auth_password_reset_resend,engagement,custom,email_sent_confirmation,"attempt_number",no,auth
auth_password_reset_resend_blocked,engagement,custom,email_sent_confirmation,"cooldown_remaining_seconds",no,auth
auth_biometric_activation_offered,engagement,custom,biometric_activation_sheet,"biometric_type",no,auth
auth_biometric_activated,engagement,custom,biometric_activation_sheet,"biometric_type;provider",yes,auth
auth_biometric_activation_declined,engagement,custom,biometric_activation_sheet,"biometric_type",no,auth
auth_biometric_unlock_completed,engagement,custom,biometric_unlock,"biometric_type;duration_ms",no,auth
auth_biometric_unlock_failed,engagement,custom,biometric_unlock,"biometric_type;reason",no,auth
```

## Appendix B — Case study scaffold

Per CLAUDE.md "feedback_case_study_every_feature" (mandatory from 2026-04-13) and v7.6 pre-commit hook `CASE_STUDY_MISSING_TIER_TAGS`, the case study scaffold lands NOW (Phase 1) with placeholder T1/T2/T3 tier tags so the framework's measurement instrumentation runs from day one — not retroactively. The full narrative populates as phases complete.

Path: `docs/case-studies/auth-polish-v2-case-study.md` — to be created in Phase 1 close-out as part of the phase transition.

## Appendix C — Out-of-code launch checklist

These are not codebase tasks but **must** be done before merge for the feature to function:

1. **Supabase dashboard:** add `fitme://reset-password` to the redirect URL whitelist for the `hwbbdzwaismlajtfsbed` project. Documented in `docs/setup/supabase-setup-guide.md` update.
2. **Google Cloud console:** confirm OAuth client ID is configured for the iOS bundle ID `com.fitme.fittracker` (or whatever the canonical bundle is) and that the URL scheme is whitelisted.
3. **`GoogleService-Info.plist`:** Regev to provide and bundle in the iOS target. (Same file Gate C needs for Firebase analytics.)
4. **TestFlight build:** post-merge, push a TestFlight build for end-to-end runtime smoke (real email + real Google sign-in + real biometric).
