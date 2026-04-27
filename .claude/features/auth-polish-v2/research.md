# Research: auth-polish-v2

> **Phase:** 0 (Research)
> **Date:** 2026-04-27
> **Owner:** Regev
> **Framework:** v7.6 PM Workflow
> **Parent features:** authentication, onboarding-v2-auth-flow (PR #80)

---

## 1. What is this solution?

A polish bundle for the existing auth surface, scoped to three intentionally-related gaps that share the same surfaces (`AuthHubView`, `OnboardingAuthView`, `SignInService`, `AuthManager`):

1. **Forgot email/password recovery flow** — promote the inline "Forgot password?" button on `EmailLoginView` into a real recovery flow with a dedicated request screen, an email-sent confirmation, a deep-link return path, and a "Set new password" screen.
2. **Biometric (Face ID / Touch ID) UI refinement + activation** — replace the current tertiary "Use Face ID" row in `AuthHubView` with a refined biometric-first unlock UX, and add a one-time post-sign-in activation prompt that fires when the device supports biometrics but the user has not enabled `requireBiometricUnlockOnReopen` yet.
3. **Google Sign In activation** — integrate the `GoogleSignIn-iOS` SPM package, configure `GIDClientID` + URL scheme, and bridge the Google ID token into Supabase via `signInWithIdToken`. UI is already wired in `AuthHubView` and `OnboardingAuthView`; the only blocker is that `GoogleRuntimeConfiguration.isConfigured` returns `false`.

Excluded from this bundle: AI smart reminder management UI (tracked separately as a smart-reminders enhancement), and Apple Sign In Services-ID configuration (deferred per backlog — needs Apple Developer console work outside the codebase).

## 2. Why this approach?

### User pain points it addresses

| Pain point | Source | Impact |
|---|---|---|
| User forgets password → cannot recover | Backlog "Password reset flow" item; no dedicated screen exists | Cold-restart user is locked out, has to delete + reinstall |
| Biometric unlock UI feels like a third-tier afterthought (one row in a stack) | [AuthHubView.swift:113-145](FitTracker/Views/Auth/AuthHubView.swift#L113-L145) — biometric is one of three tertiary buttons | Returning user has to read three options when they almost always want biometric |
| Users with biometrics enabled at the device level never discover the in-app option | Onboarding v2 auth flow does not prompt for `requireBiometricUnlockOnReopen` | Friction on every relaunch; trust score for the app suffers |
| Google sign-in row is permanently hidden | `GoogleRuntimeConfiguration.isConfigured == false`; UI exists but never renders | Lost conversion at register/login; only Apple + Email available |
| Existing `signIn.requestPasswordReset(email:)` lacks UI feedback | Called from [AuthHubView.swift:404-417](FitTracker/Views/Auth/AuthHubView.swift#L404-L417), surfaces only as a status banner — no inbox-confirmation screen, no deep-link return path | Users don't know if the email was sent, never see the "Set new password" flow |

### Why bundle these three together?

They share **the same files** ( `AuthHubView`, `SignInService`, `AuthManager`), **the same analytics scope** (`auth_*` events), **the same QA scope** (auth runtime smoke profile), and the **same review risk surface** (high-risk auth path). Splitting them into three branches multiplies merge conflicts and review overhead without product benefit. One PR, one analytics taxonomy update, one smoke run.

## 3. Why this over alternatives?

### Forgot-password approach

| Approach | Pros | Cons | Effort | Chosen? |
|---|---|---|---|---|
| **Reuse `signIn.requestPasswordReset` with a dedicated `ForgotPasswordView`** + Supabase deep-link redirect → `SetNewPasswordView` | Service exists, Supabase PKCE is default in Swift, no new auth surface | Need URL scheme + AppDelegate URL handler | 2 days | ✅ Yes |
| Inline reset via current "Forgot password?" button only (status banner) | Already mostly built | Confusing UX; user does not know if email was actually sent; cannot set new password from app | 0.5 days | ❌ Status quo |
| Move reset entirely to a web flow (Supabase hosted page) | Simple, no client work | Breaks the in-app experience, requires Safari handoff, regresses trust | 1 day | ❌ Worse UX |
| Custom OTP-style reset (5-digit code in app) | Consistent with our email verification UX | Supabase doesn't support this natively; would need server-side bridging | 5+ days | ❌ Too costly |

### Biometric refinement approach

| Approach | Pros | Cons | Effort | Chosen? |
|---|---|---|---|---|
| **Promote biometric to a dedicated full-screen `BiometricUnlockView`** when stored session + setting enabled, plus a one-time `BiometricActivationSheet` after first email/Google sign-in | Apple HIG compliance, single-tap unlock, opt-in activation, easy to disable | Need new screen + sheet + persistence flag | 2.5 days | ✅ Yes |
| Inline auto-prompt biometric on app launch (no UI), fall through to AuthHub on cancel | Fastest path for the user | Apple HIG: "shouldn't prompt without showing buttons" — feels invasive; cancel state is jarring | 0.5 days | ❌ Violates HIG |
| Add a Settings toggle only — no in-context activation prompt | Lowest churn | Discovery is poor; users never enable | 0.5 days | ❌ Status quo, low value |
| System-level only (no in-app biometric, defer to passcode) | Simplest | Loses the trust-building moment; "you locked your fitness data with Face ID" is a feature differentiator | 0 days | ❌ Loses product value |

### Google Sign In approach

| Approach | Pros | Cons | Effort | Chosen? |
|---|---|---|---|---|
| **`GoogleSignIn-iOS` SPM package + `signInWithIdToken` to Supabase + URL scheme + `GIDClientID`** | Official path; Supabase docs explicitly recommend this; native UX (no Safari) | Adds 1 SPM dependency; Info.plist changes | 1.5 days | ✅ Yes |
| Web-based Supabase OAuth via `signInWithOAuth(provider: .google)` + Safari | No SDK needed | Safari handoff is jarring vs Apple Sign In's native sheet; HIG penalty; account chooser worse | 1 day | ❌ Worse UX |
| Sign in with Google via ASWebAuthenticationSession only | Smaller dependency footprint | Manual nonce/PKCE handling, more error paths, Supabase explicitly discourages | 2 days | ❌ Reinvents wheel |

## 4. External sources

### Forgot password / Supabase deep linking

- [Supabase — Native Mobile Deep Linking](https://supabase.com/docs/guides/auth/native-mobile-deep-linking) — canonical URL-scheme + `client.auth.session(from: url)` pattern.
- [Supabase — Password-based Auth](https://supabase.com/docs/guides/auth/passwords) — confirms PKCE is default in Swift.
- [Supabase — Password Reset guide](https://supabase.com/docs/guides/auth/auth-password-reset) — `resetPasswordForEmail` API + redirect URL contract.
- [Supabase — Redirect URLs](https://supabase.com/docs/guides/auth/redirect-urls) — must whitelist deep-link URI in dashboard.
- [iOS Password Reset Flow Examples (PageFlows)](https://pageflows.com/ios/flows/password-reset-flow/) — reference UX patterns (request → confirmation → set-new → success).

### Biometric activation UX

- [Apple HIG — Logging a User into Your App with Face ID or Touch ID](https://developer.apple.com/documentation/localauthentication/logging-a-user-into-your-app-with-face-id-or-touch-id) — official Apple pattern: button-driven, not auto-prompt.
- [Apple Developer Forums — biometric prompts](https://developer.apple.com/forums/thread/87797) — confirms the post-first-login prompt pattern.
- [Biometric Authentication App Design — Orbix Studio (2026)](https://www.orbix.studio/blogs/biometric-authentication-app-design) — opt-in, one-sentence assurance, easy off-switch.
- [Auth0.swift — Touch ID / Face ID Authentication](https://auth0.com/docs/libraries/auth0-swift/auth0-swift-touchid-faceid) — fallback mechanics.

### Google Sign In + Supabase

- [Supabase — Login with Google (Swift)](https://supabase.com/docs/reference/swift/auth-signinwithidtoken) — `signInWithIdToken(credentials: OpenIDConnectCredentials)` is the canonical Swift call.
- [Supabase iOS Auth Guide (Google)](https://github.com/supabase/supabase/blob/master/apps/docs/content/guides/auth/social-login/auth-google.mdx) — full integration walkthrough.
- [GoogleSignIn-iOS — Swift Package Registry](https://swiftpackageregistry.com/google/GoogleSignIn-iOS) — current package: `https://github.com/google/GoogleSignIn-iOS`, latest 8.x.
- [Supabase Discussion #34959 — GoogleSignIn 8.1 nonce integration](https://github.com/orgs/supabase/discussions/34959) — current nonce/PKCE quirks (relevant: 8.x changed nonce API).

## 5. Market examples (how others solve this)

| App | Forgot password | Biometric activation | Google sign-in |
|---|---|---|---|
| **MyFitnessPal** | Dedicated screen → email confirmation → web set-new | Settings toggle only, no in-context activation | Native, on auth screen |
| **Strava** | Dedicated screen → in-app deep-link return → set-new in-app | Post-sign-in modal "Use Face ID next time?" with skip | Native, on auth screen |
| **Hevy** | Web-based reset (Safari hand-off) | Settings toggle only | Native, on auth screen |
| **Whoop** | In-app full flow (request → email → deep-link → set-new) | Single-tap full-screen unlock UI, activation modal first launch after sign-in | Native + Apple |
| **Strong** | Web-based reset | Quick unlock row similar to current FitMe | Native + Apple |
| **iOS Settings (Apple)** | N/A | Inline switch with one-line description, biometric prompt confirms toggle change | N/A |

**Pattern winners** (what we want to match):
- Whoop and Strava — full in-app flow + post-sign-in biometric activation modal.
- Apple's settings screen — biometric prompt confirms the activation moment (the Face ID scan IS the consent).

## 6. UI design — visual references

### 6.1 Forgot-password flow (3 screens)

| Screen | Reference apps | Key elements |
|---|---|---|
| **Forgot Password Request** | Whoop, Strava | Single email field (auto-filled from login), large primary CTA "Send reset link", supporting copy: "We'll email you a secure link to set a new password", inline back nav |
| **Email Sent Confirmation** | Whoop | Large checkmark icon, "Check your inbox" headline, "We sent a link to {email}. Tap it to continue.", secondary actions: "Resend" (60s cooldown) + "Use a different email" |
| **Set New Password** | Strava | Two `PasswordRulesSecureField` (new + confirm), inline rules tooltip (already exists in `PasswordRulesTooltip`), primary CTA "Update password", success → auto-login + navigate to Home |

### 6.2 Biometric refinement (2 surfaces)

| Surface | Reference apps | Key elements |
|---|---|---|
| **Biometric-first Unlock Screen** (replaces current tertiary row when `hasStoredSession && requireBiometricUnlockOnReopen && biometricAuth.isAvailable`) | Whoop, banking apps | Full-screen `AppGradient.authBackground`, brand icon top, "Welcome back, {firstName}" hero, large `Image(systemName: biometricAuth.biometricIcon)` 88pt, primary CTA "Unlock with {biometricLabel}", secondary "Use password" link to `EmailLoginView` |
| **Activation Sheet** (sheet presented once after first email/Google sign-in if `biometricAuth.isAvailable && !settings.requireBiometricUnlockOnReopen && !settings.hasAskedForBiometricActivation`) | Strava, Whoop | Modal sheet, brand icon, headline "Unlock {AppBrand.name} with {biometricLabel}", one-sentence assurance "Your data stays encrypted on this device.", primary CTA "Enable {biometricLabel}" (triggers `LAContext.evaluatePolicy` — the scan IS the consent), secondary "Not now" (dismiss), tertiary "Don't ask again" — sets `hasAskedForBiometricActivation = true` either way |

### 6.3 Google Sign In

No new UI work — just flip `GoogleRuntimeConfiguration.isConfigured` to `true` once SDK + Info.plist + URL scheme land. Existing `GoogleProviderRow` ([AuthHubView.swift:513-543](FitTracker/Views/Auth/AuthHubView.swift#L513-L543)) and equivalent in `OnboardingAuthView` will auto-render.

### Mood

Match the existing onboarding-v2 visual language: `AppGradient.authBackground`, `AppText.hero`/`body`/`subheading`, `AppRadius.sheet` cards, no novel components needed except: `BiometricUnlockView` (composes existing `AuthScaffold` + `AuthPrimaryButtonStyle`), `BiometricActivationSheet` (uses existing sheet styling), `ForgotPasswordView` / `EmailSentConfirmationView` / `SetNewPasswordView` (compose existing `AuthScaffold` + `AuthFormCard` + `AuthPrimaryButtonStyle`).

**No new design tokens needed.** Component compliance gateway should pass.

## 7. Data & demand signals

| Signal | Source | What it tells us |
|---|---|---|
| Backlog explicitly flags forgot-password as gap | [docs/product/backlog.md:113](docs/product/backlog.md#L113) — "Password reset flow — reset action is available... ✅" was wishful checkmark; UI is partial | Real product gap, not invented work |
| `GoogleRuntimeConfiguration.isConfigured = false` in production builds | [SignInService.swift:326-330](FitTracker/Services/Auth/SignInService.swift#L326-L330) — Google provider is `Unavailable` until config lands | Documented blocker, not a question |
| Onboarding-v2 auth flow case study (PR #80) flagged biometric activation as deferred | `docs/case-studies/onboarding-v2-auth-flow-v5.1-case-study.md` | Already on the team's radar, just never scheduled |
| Auth surface is the #1 high-risk file area per CLAUDE.md ("AuthManager.swift, SignInService.swift") | CLAUDE.md "High-risk areas" | Justifies bundling — fewer review cycles on the same risk surface |
| App Store launch readiness blocked on auth runtime verification (Gate C) | Master plan 2026-04-15, "Authentication hardening" | Gate C blocker — closing forgot-pw + Google sign-in + biometric activation removes 3 of the launch checklist items |

**No GA4 telemetry exists yet** for any of these flows because the screens don't exist yet. Phase 1 PRD will define the events.

## 8. Technical feasibility

### Forgot password
- **Existing:** `EmailAuthProviding.requestPasswordReset(email:)` ([SignInService.swift:152](FitTracker/Services/Auth/SignInService.swift#L152)), three implementations (`MockEmailAuthProvider`, `SupabaseEmailAuthProvider`, `UnavailableEmailAuthProvider`). `SignInService.requestPasswordReset(email:)` ([SignInService.swift:653](FitTracker/Services/Auth/SignInService.swift#L653)) is the controller call.
- **Missing:** dedicated views, URL scheme handler in `FitTrackerApp.swift`, `client.auth.session(from: url)` bridge for deep-link return, redirect URL whitelist in Supabase dashboard (config-only, no code).
- **Risk:** medium — touches the auth path. Mitigated by smoke test profile `sign_in_surface` (already exists per CLAUDE.md "runtime-smoke" section).

### Biometric refinement
- **Existing:** `AuthManager` + `LAContext` plumbing complete. `biometricLabel`, `biometricIcon`, `authenticateForQuickUnlock()`, `requireBiometricUnlockOnReopen` setting.
- **Missing:** `BiometricUnlockView`, `BiometricActivationSheet`, `hasAskedForBiometricActivation` flag in `AppSettings`. Wiring in `RootTabView` / `AuthHubView` to gate which screen shows.
- **Risk:** low — purely additive; existing flows unchanged when settings off.

### Google Sign In
- **Existing:** `GoogleAuthProviding` protocol, `GoogleAuthProvider` (real implementation, currently unreferenced because `GoogleRuntimeConfiguration.isConfigured = false`), UI rows + handlers.
- **Missing:** `GoogleSignIn-iOS` SPM package add + Info.plist `GIDClientID` + URL scheme + the body of `GoogleAuthProvider.signIn()` that calls `GIDSignIn.sharedInstance.signIn(withPresenting:)` and bridges to `supabase.auth.signInWithIdToken(...)`.
- **Risk:** medium — new dependency; nonce handling per [Supabase Discussion #34959](https://github.com/orgs/supabase/discussions/34959) needs the GoogleSignIn 8.x nonce API.
- **Constraint:** requires `GoogleRuntimeConfiguration` to read `GIDClientID` from Info.plist or a generated config file. Supabase project Google OAuth provider was already enabled in 2026-04-15 consolidation per memory.

### Existing-code finding worth flagging now

[AuthHubView.swift:635](FitTracker/Views/Auth/AuthHubView.swift#L635) and [AuthHubView.swift:825](FitTracker/Views/Auth/AuthHubView.swift#L825) reference `ColorAppColor.Status.error` and `ColorAppColor.Brand.secondary`. There is no `ColorAppColor` typealias anywhere in the project (verified via grep). This is almost certainly two typos that should read `AppColor.Status.error` and `AppColor.Brand.secondary`. CLAUDE.md says "iOS Build: Green" which conflicts — possible explanations: (a) the code paths are not exercised in current build flags, (b) the typo was introduced after the last green build, (c) my grep missed something. **Phase 4 acceptance gate: confirm via `xcodebuild build`. Either way, fix it as part of this feature** (under task `T0` "Repair existing `ColorAppColor` typos").

## 9. Proposed success metrics

These are draft proposals for the PRD to refine:

### Primary metric

**Auth recovery success rate** = (users who complete password reset OR successfully use biometric unlock OR successfully sign in with Google) / (total auth-failure events that triggered a recovery path).

**Why this metric:** It captures the bundle's product thesis — "when the user has trouble with auth, can they recover without churning?". Each of the three workstreams contributes a numerator path.

**Baseline:** unmeasured today (no events fire). First 30 days post-ship establishes the baseline.

**Target:** ≥ 70% within 60 days post-ship.

### Secondary metrics

| Metric | Target | Source |
|---|---|---|
| `auth_password_reset_completed` / `auth_password_reset_requested` | ≥ 60% | new GA4 events |
| `auth_biometric_activated` / `auth_biometric_activation_offered` | ≥ 35% | new GA4 events |
| `auth_signin_completed` with `provider: google` / total `auth_signin_completed` | ≥ 20% by day 30 | new GA4 events |

### Guardrail metrics (must not degrade)

| Guardrail | Threshold | Why |
|---|---|---|
| `auth_signin_completed` overall rate | not below current baseline (-5%) | New providers should expand, not cannibalize |
| Crash-free rate | > 99.5% (CLAUDE.md system-wide guardrail) | Auth path is high-risk |
| Cold start P95 | < 2s (CLAUDE.md system-wide guardrail) | GoogleSignIn SDK init must not regress this |
| `requireBiometricUnlockOnReopen = true` users post-sign-in | ≥ 25% by day 14 | Validates activation prompt isn't being dismissed reflexively |

### Kill criteria (PRD will lock these in)

- If `auth_biometric_activation_offered` ↑ but `auth_biometric_activated` < 5%: the activation prompt is wrong copy/timing. Iterate or kill.
- If Google sign-in produces > 0.5% crashes / hangs: roll back via flipping `GoogleRuntimeConfiguration.isConfigured` server-side default (or local feature flag).
- If forgot-password deep-link return fails > 10% of the time: reset flow regresses to status-banner-only mode.

## 10. Decision

**Recommendation:** proceed with the bundled approach. All three items share the auth surface, share the test/review/QA scope, and unblock 3 of the Gate C launch-readiness items in one PR. Estimated effort: **6 days** (Forgot 2 + Biometric 2.5 + Google 1.5).

**Order:**
1. **Google Sign In first** (1.5d) — config + SDK swap, no UI work, validates Supabase ID-token bridge.
2. **Biometric refinement** (2.5d) — touches the same surfaces; the activation prompt slots into the post-sign-in moment that Google + Email flows both reach.
3. **Forgot password** (2d) — net new screens, but uses existing `requestPasswordReset` call.
4. **`ColorAppColor` typo fix** (T0, 0.1d) — preflight repair of existing AuthHubView bugs surfaced during research.

**Branch:** `feature/auth-polish-v2` (touches > 5 files, modifies auth services → mandatory feature branch per CLAUDE.md).

**Work type:** Feature (full 10-phase lifecycle). Although items 1-3 each individually look like enhancements to a shipped feature, the bundle introduces 5 new screens/sheets, a new SDK dependency, a new URL scheme, and 7+ new GA4 events — collectively at the threshold for full PRD + UX phases.

**Case study type:** `live_pm_workflow` (per CLAUDE.md mandatory case-study rule).

---

## Phase 0 exit criteria checklist

- [x] Solution and rationale documented
- [x] 3+ alternatives compared per workstream
- [x] External sources cited (10+ links)
- [x] Market examples table
- [x] Visual references for new screens
- [x] Data and demand signals
- [x] Technical feasibility per workstream
- [x] Proposed primary + secondary + guardrail + kill criteria
- [x] Existing-code findings logged (`ColorAppColor` typos)
- [x] Decision recorded with effort + branch + work type

**Ready for user approval to advance Phase 0 → Phase 1 (PRD).**
