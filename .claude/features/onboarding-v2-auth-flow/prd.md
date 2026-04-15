# PRD: Onboarding v2 Auth Flow — Embedded Account Creation

> **Owner:** Regev
> **Date:** 2026-04-15
> **Phase:** PRD (Phase 1)
> **Status:** Draft
> **Work Type:** Feature
> **Linear:** pending

---

## Purpose

Restructure the FitMe onboarding from a 6-step flow with post-onboarding auth into an 8-step flow with embedded account creation (step 5), success animation (step 6), and a working session restore — so users create their account inside the onboarding momentum, see confirmation feedback, and enter the app without freezes or dead-ends.

## Business Objective

The current flow is broken: the app freezes on the last onboarding step, auth is disconnected from onboarding, and there's no success feedback. This blocks all runtime testing, user acquisition, and App Store readiness. Fixing it unblocks the entire launch pipeline.

## Target Persona(s)

| Persona | Relevance |
|---------|-----------|
| Consistent Lifter | First-time user. Needs frictionless setup that saves their training preferences immediately. |
| Health-Conscious Professional | Time-constrained. Wants to set up once and have everything persist. No tolerance for broken flows. |
| Data-Driven Optimizer | Expects their profile + goals + HealthKit permissions to survive app reinstall. Needs account creation to enable sync. |

## Has UI?

Yes — 2 new screens (OnboardingAuthView, OnboardingSuccessView), modifications to 3 existing screens.

## Functional Requirements

| # | Requirement | Details |
|---|-------------|---------|
| 1 | Embed auth as onboarding step 5 | After consent (step 4), show account creation with Email, Google, Apple options. "Already have an account? Log In" link for returning users. |
| 2 | Success animation as step 6 | Checkmark animation + "Welcome to FitMe, {name}!" with auto-advance after 2s. Tap to skip. |
| 3 | Returning user shortcut | "Log In" on step 5 authenticates and skips steps 6-7, going straight to Home. |
| 4 | Persist profile data on sign-up | Goals, profile, HealthKit permissions set in steps 1-3 are synced to Supabase immediately after successful auth. |
| 5 | Fix session restore freeze | Move `supabase.auth.session` off main actor with 5s timeout. Graceful fallback to stored session or re-auth. |
| 6 | Remove AuthHubView from rootView | Auth is inside onboarding. After `hasCompletedOnboarding = true`, user is already authenticated → show RootTabView directly. |
| 7 | Fix "Intermediate" truncation | Add `minimumScaleFactor(0.8)` to ExperienceCard text. |
| 8 | Progress bar updates | 8 total steps. Hide progress bar on welcome (0), auth (5), and success (6) steps. |
| 9 | Onboarding-styled auth UI | Auth step uses onboarding visual style (AppGradient.screenBackground, consistent spacing) — not the separate AuthHubView dark style. |
| 10 | Handle auth failure gracefully | Network error, cancelled Google flow, invalid credentials → show inline error, stay on step 5, let user retry. |

## User Flows

### Flow A: New user (happy path)
1. Welcome → tap "Get Started"
2. Goals → select "Lose Fat" → tap "Continue"
3. Profile → select "Intermediate", 4 days → tap "Continue"
4. HealthKit → tap "Connect Apple Health" → grant → auto-advance
5. Consent → tap "Accept & Continue"
6. Create Account → tap "Continue with Email" → fill form → tap "Register"
7. Success → see checkmark + "Welcome to FitMe, Regev!" → auto-advance (2s)
8. First Action → tap "Start Your First Workout" → Home screen

### Flow B: Returning user
1. Welcome → tap "Get Started"
2-4. (skip through or fill in)
5. Consent → tap "Accept"
6. Create Account → tap "Already have an account? Log In" → email/password → authenticate
7. Skip success + first action → straight to Home (data syncs from Supabase)

### Flow C: App relaunch (session restore)
1. App launches → `restoreSession()` runs in background (off main actor, 5s timeout)
2. If valid session found → `hasCompletedOnboarding = true` + `isAuthenticated = true` → Home
3. If session expired → clear stored session → show onboarding step 5 (auth) or full onboarding if needed

### Flow D: Auth failure
1. User on step 5 → taps "Continue with Google" → cancels Google OAuth
2. Error banner: "Google Sign-In was cancelled. Try again or use another method."
3. User stays on step 5. Can retry or choose different provider.

## Current State & Gaps

| Gap | Priority | Notes |
|-----|----------|-------|
| App freezes on last onboarding step | Critical | `restoreSession()` blocks main actor with real Supabase credentials |
| Auth is post-onboarding | Critical | Users hit a wall after completing setup |
| No success feedback | High | No confirmation that account was created |
| "Intermediate" text truncated | Medium | Font too large for 3-card layout |
| No returning user shortcut | Medium | Must repeat full onboarding to log in |

## Acceptance Criteria

- [ ] User can create an account (email) during onboarding step 5 and reach Home
- [ ] User can create an account (Google) during onboarding step 5 and reach Home
- [ ] User can create an account (Apple) during onboarding step 5 and reach Home
- [ ] Success animation plays for 2s with user's name after account creation
- [ ] Returning user can tap "Log In" on step 5 and reach Home without completing steps 6-7
- [ ] App relaunch with valid session goes directly to Home (no onboarding replay)
- [ ] App relaunch with expired session shows auth screen (not freeze)
- [ ] Auth failure shows inline error, user stays on step 5
- [ ] Profile + goals persist to Supabase after sign-up
- [ ] "Intermediate" text displays fully without truncation
- [ ] Progress bar shows 8 steps, hidden on auth + success steps
- [ ] All existing 197 tests still pass
- [ ] No regression in onboarding analytics events

---

## Success Metrics & Measurement Plan

### Primary Metric
- **Metric:** Onboarding completion rate (step 0 → Home)
- **Baseline:** 0% (flow is currently broken — freezes at step 5)
- **Target:** >70% of users who start onboarding reach Home
- **Timeframe:** 14 days post-launch

### Secondary Metrics
| Metric | Baseline | Target | Instrumentation |
|--------|----------|--------|-----------------|
| Auth conversion rate (step 5 shown → account created) | 0% | >60% | `onboarding_auth_method_selected` / `onboarding_step_viewed` (step 5) |
| Time from app open to Home | Unknown | <90 seconds | `tutorial_begin` → `tutorial_complete` timestamps |
| Session restore success rate | 0% (broken) | >95% | `session_restore_result` event |
| Auth method distribution | Unknown | Track | `onboarding_auth_method_selected` with `method` param |
| Drop-off per step | Unknown | <15% per step | `onboarding_step_viewed` funnel |

### Guardrail Metrics

| Metric | Current Value | Acceptable Range |
|--------|--------------|-----------------|
| Crash-free rate | >99.5% | Must stay >99.5% |
| Cold start time | <2s | Must stay <2s |
| Existing onboarding analytics events | All firing | No regressions |
| Test suite | 197 passing | Must stay passing |

### Leading Indicators
- Week 1: >50% of sessions that start onboarding reach step 5 (auth)
- Week 1: >30% of step 5 impressions convert to account creation
- Week 1: Session restore works on >90% of relaunches

### Lagging Indicators
- D7: Onboarding completion rate stabilizing above 60%
- D30: >50% of created accounts return within 7 days (retention signal)
- D30: Auth method mix established (email vs Google vs Apple)

### Instrumentation Plan

| Event/Metric | Method | Status |
|-------------|--------|--------|
| `onboarding_step_viewed` (steps 0-7) | GA4 (existing, extend to steps 5-7) | Extend |
| `onboarding_step_completed` (steps 0-7) | GA4 (existing, extend) | Extend |
| `onboarding_auth_method_selected` | GA4 (new) | Not started |
| `onboarding_auth_completed` | GA4 (new) | Not started |
| `onboarding_auth_failed` | GA4 (new) | Not started |
| `onboarding_success_shown` | GA4 (new) | Not started |
| `session_restore_result` | GA4 (new) | Not started |
| `tutorial_begin` | GA4 (existing) | Ready |
| `tutorial_complete` | GA4 (existing) | Ready |

### Analytics Spec (GA4 Event Definitions)

#### New Events
| Event Name | Category | GA4 Type | Screen/Trigger | Parameters | Conversion? | Notes |
|------------|----------|----------|----------------|------------|-------------|-------|
| `onboarding_auth_method_selected` | Auth | Custom | Onboarding step 5 | `method` | No | User taps an auth provider |
| `onboarding_auth_completed` | Auth | Custom | Onboarding step 5 | `method`, `is_new_account` | Yes | Account created or login succeeded |
| `onboarding_auth_failed` | Auth | Custom | Onboarding step 5 | `method`, `error_type` | No | Auth attempt failed |
| `onboarding_success_shown` | Engagement | Custom | Onboarding step 6 | — | No | Success animation displayed |
| `session_restore_result` | Auth | Custom | App launch | `result`, `restore_time_ms` | No | Session restore outcome |

#### New Parameters
| Parameter Name | Type | Allowed Values | Used By Events | Notes |
|---------------|------|----------------|----------------|-------|
| `method` | string | "email", "google", "apple" | onboarding_auth_method_selected, onboarding_auth_completed, onboarding_auth_failed | Auth provider used |
| `is_new_account` | string | "true", "false" | onboarding_auth_completed | Register vs login |
| `error_type` | string | "cancelled", "network", "invalid_credentials", "unknown" | onboarding_auth_failed | Failure classification |
| `result` | string | "success", "expired", "failed", "timeout" | session_restore_result | Restore outcome |
| `restore_time_ms` | int | 0-10000 | session_restore_result | Time taken for restore |

#### Naming Validation Checklist
- [x] All event names: snake_case, <40 chars
- [x] All parameter names: snake_case, <40 chars
- [x] No reserved prefixes (ga_, firebase_, google_)
- [x] No duplicate names (checked against AnalyticsProvider.swift)
- [x] No PII in any parameter
- [x] ≤25 parameters per event
- [x] Parameter values spec'd to max 100 chars
- [x] Screen-prefix rule: `onboarding_` prefix for onboarding events, `session_` for app-level auth events

#### Files to Update During Implementation
- [ ] `AnalyticsProvider.swift` — add 5 new event constants + 4 new param constants
- [ ] `AnalyticsService.swift` — add typed convenience methods
- [ ] `docs/product/analytics-taxonomy.csv` — add rows for new events and parameters

### Review Cadence
- **First review:** 7 days post-launch
- **Ongoing:** Weekly for 4 weeks, then monthly

### Kill Criteria

- If onboarding completion rate < 40% after 14 days → investigate which step has the highest drop-off
- If auth conversion rate < 25% after 14 days → test removing mandatory auth (make account optional)
- If session restore success rate < 80% → add offline-first fallback with delayed sync
- If crash-free rate drops below 99% during onboarding → hotfix immediately

---

## Key Files

| File | Purpose | Change Type |
|------|---------|-------------|
| `FitTracker/Views/Onboarding/v2/OnboardingView.swift` | Container — add steps 5-6, update totalSteps | Modify |
| `FitTracker/Views/Onboarding/v2/OnboardingAuthView.swift` | NEW — auth providers in onboarding style | Create |
| `FitTracker/Views/Onboarding/v2/OnboardingSuccessView.swift` | NEW — animated success screen | Create |
| `FitTracker/Views/Onboarding/v2/OnboardingProfileView.swift` | Fix "Intermediate" truncation | Modify |
| `FitTracker/Views/Onboarding/v2/OnboardingProgressBar.swift` | Update for 8 steps | Modify |
| `FitTracker/FitTrackerApp.swift` | Remove AuthHubView, fix restoreSession | Modify |
| `FitTracker/Services/Auth/SignInService.swift` | Add timeout to restoreSession | Modify |
| `FitTracker/Services/Analytics/AnalyticsProvider.swift` | Add 5 events + 4 params | Modify |
| `FitTracker/Services/Analytics/AnalyticsService.swift` | Add convenience methods | Modify |

## Dependencies & Risks

| Dependency/Risk | Mitigation |
|----------------|------------|
| Google Sign-In requires real device for full test | Email + Apple Sign-In work on simulator. Google tested manually on device. |
| Supabase Tokyo region latency (~200ms) | Session restore has 5s timeout — 200ms is well within budget |
| Auth step makes onboarding longer | Research shows auth mid-flow (Duolingo/Headspace pattern) has higher conversion than post-flow |
| Returning users must tap through to step 5 | "Already have an account?" detected at app launch → skip to auth step directly |

## Estimated Effort

- **Total:** ~3 days
- **Breakdown:**
  - OnboardingAuthView (new): 0.5 days
  - OnboardingSuccessView (new): 0.25 days
  - OnboardingView container changes: 0.25 days
  - FitTrackerApp rootView simplification: 0.25 days
  - Session restore fix (SignInService): 0.5 days
  - Analytics events: 0.25 days
  - Profile truncation fix: 0.1 days
  - Testing + regression: 0.5 days
  - Review + merge: 0.25 days
