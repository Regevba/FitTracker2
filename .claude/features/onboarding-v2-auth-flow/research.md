# Onboarding v2 Auth Flow — Research

> Status: Phase 0 research
> Framework: PM-flow v5.1
> Date: 2026-04-15

## 1. What is this solution?

Restructure the FitMe onboarding flow to embed account creation within the onboarding sequence (after consent, before first action), add a success animation after authentication, and fix the app-wide layout and session restore issues discovered during runtime verification testing.

## 2. Why this approach?

### Current problems

| # | Problem | Impact | Evidence |
|---|---|---|---|
| 1 | Auth is post-onboarding — user completes 6 onboarding steps, THEN sees a separate AuthHubView | Disorienting. User thinks onboarding is complete, then hits a registration wall. No context for why they need an account. | Simulator testing 2026-04-15 |
| 2 | App freezes on "Start Your First Workout" tap | The `completeOnboarding()` → `rootView` re-evaluation → `restoreSession()` network call blocks the main actor | Simulator testing 2026-04-15 |
| 3 | No success feedback after account creation | User creates account, then immediately lands on Home. No celebration, no confirmation, no transition. | UX review |
| 4 | UILaunchScreen was missing | App renders in compatibility mode on newer iPhones (letterboxed) | ✅ Fixed 2026-04-15 |
| 5 | DEBUG auto-login bypasses all auth | Simulator testing can't validate real auth flows | ✅ Fixed via FITTRACKER_SKIP_AUTO_LOGIN env var |
| 6 | "Intermediate" text truncated on Profile step | ExperienceCard font too large for 3-card layout on narrow screens | Simulator screenshot |

### Why embed auth in onboarding?

1. **Context**: after setting goals, profile, and granting consent, the user understands WHY they need an account — to save their data. The ask is motivated.
2. **Completion momentum**: the user is already in a "setup" mindset. Interrupting with a separate screen breaks momentum.
3. **Industry standard**: Duolingo, Headspace, MyFitnessPal, Strava all ask for account creation during onboarding, not after.
4. **Data integrity**: profile + goals + HealthKit permissions are set BEFORE the account, so they can be persisted immediately to Supabase on sign-up.

## 3. Competitive analysis

| App | When auth happens | Methods | Success feedback | First action after auth |
|---|---|---|---|---|
| **Duolingo** | After language selection (step 3 of 5) | Email, Google, Apple, Facebook | Confetti animation + "Account created!" | First lesson |
| **Headspace** | After goal selection (step 2 of 4) | Email, Google, Apple | Gentle checkmark + "Welcome, [name]" | First meditation |
| **MyFitnessPal** | Step 1 (before anything else) | Email, Google, Apple, Facebook | Redirect to goal setup | Calorie target |
| **Strava** | Step 1 (before anything else) | Email, Google, Apple | Profile photo prompt | Activity feed |
| **Noom** | After quiz (step 8 of 12) | Email, Google, Apple | Progress bar completion + "You're in!" | Personalized plan |
| **Strong** | Optional — can use without account | Email, Apple | Simple "Signed in" toast | Continue using app |

**Best practice pattern:** Auth after 2-4 setup steps (not step 1, not last). Success animation/screen before entering the app. FitMe should follow the Duolingo/Headspace/Noom pattern.

## 4. Proposed new flow

```
Step 0: Welcome ──────── "Get Started" (brand gradient, logo)
Step 1: Goals ─────────── Select fitness goal / Skip
Step 2: Profile ────────── Training experience + frequency / Skip
Step 3: HealthKit ──────── Connect Apple Health / Skip
Step 4: Consent ────────── Accept analytics / Continue Without
Step 5: CREATE ACCOUNT ── Email, Google, or Apple. Also "Log In" for returning users.
Step 6: SUCCESS ────────── Checkmark animation + "Welcome to FitMe!" + auto-advance
Step 7: First Action ──── "Start Workout" or "Log Meal" → Home
```

### Key differences from current flow

| Aspect | Current | Proposed |
|---|---|---|
| Auth placement | After onboarding (separate screen) | Step 5 of onboarding (embedded) |
| Success feedback | None | Animated success screen (step 6) |
| Steps count | 6 (onboarding) + separate auth | 8 (onboarding with auth integrated) |
| Data persistence | Profile/goals set before auth, may be lost | Profile/goals + auth = immediate Supabase sync |
| Returning users | Hit AuthHubView after onboarding | "Log In" option on step 5, skip to Home |
| Session restore freeze | Broken (main actor blocked) | Fixed: async background restore |

## 5. Technical changes required

### 5a. OnboardingView.swift — add 2 new steps

| Change | File | Details |
|---|---|---|
| Add step 5 (auth) | `OnboardingView.swift` | Embed `OnboardingAuthView` — wraps auth providers (email, Google, Apple) in onboarding-styled container |
| Add step 6 (success) | `OnboardingView.swift` | New `OnboardingSuccessView` with checkmark animation + "Welcome to FitMe!" |
| Update `totalSteps` | `OnboardingView.swift` | 6 → 8 |
| Update progress bar | `OnboardingProgressBar.swift` | Adjust for 8 steps, hide on auth + success steps |
| Update step names | `OnboardingView.swift` | Add "auth" (5) and "success" (6) to stepName mapping |

### 5b. New views to create

| View | Purpose |
|---|---|
| `OnboardingAuthView.swift` | Embeds auth methods (email, Google, Apple) in onboarding visual style. Reuses `SignInService` methods but with onboarding UI wrapper. "Log In" link for returning users. |
| `OnboardingSuccessView.swift` | Animated checkmark → "Welcome to FitMe, {name}!" → auto-advances after 2 seconds. Uses `AppMotion` tokens. |

### 5c. FitTrackerApp.swift — simplify rootView

| Change | Details |
|---|---|
| Remove AuthHubView from rootView | Auth is now inside onboarding. After onboarding completes, user is already authenticated. |
| Fix restoreSession freeze | Move `supabase.auth.session` call off main actor, add 5s timeout |
| Simplify flow | `!hasCompletedOnboarding` → OnboardingView (includes auth). `isAuthenticated` → RootTabView. else → OnboardingView (forces re-auth). |

### 5d. Session restore fix

| Problem | Fix |
|---|---|
| `restoreSession()` calls `supabase.auth.session` on main actor | Wrap in `Task.detached` with 5-second timeout. If timeout, clear stored session and show auth. |
| No error handling for network failure | Add try/catch with graceful fallback to stored session |

### 5e. UI layout fixes (embedded in this feature)

| Fix | File | Details |
|---|---|---|
| "Intermediate" truncation | `OnboardingProfileView.swift` | Add `.minimumScaleFactor(0.8)` to ExperienceCard label |
| Ensure all onboarding steps have visible CTA | All onboarding views | Verify Continue/Skip buttons visible without scrolling on smallest supported device |

## 6. Risks

| Risk | Mitigation |
|---|---|
| Returning users must go through onboarding to log in | "Already have an account? Log In" link on auth step — logs in and skips remaining onboarding |
| Auth step may confuse users who don't want an account | Position after consent where trust is established. Frame as "Save your progress" not "Create account" |
| Google Sign-In may fail on simulator | Test with real device for Google. Email + Apple work on simulator. |
| Success animation adds delay | 2s auto-advance is snappy. User can tap to skip. |

## 7. Success metrics (draft)

| Metric | Baseline | Target |
|---|---|---|
| Onboarding completion rate (step 0 → step 7) | Unknown | >70% |
| Auth conversion rate (step 5 shown → account created) | 0% (no auth in onboarding) | >60% |
| Time from app open to Home screen | Unknown | <90 seconds |
| Session restore success rate | 0% (broken) | >95% |
| App crash-free rate during onboarding | Unknown | >99.5% |

## 8. Decision

**Recommended approach:** Embed auth as onboarding step 5, add success animation as step 6, fix session restore. This is a Feature work type with full 10-phase lifecycle.

**Scope boundaries:**
- IN: onboarding flow restructure, auth embedding, success screen, session restore fix, "Intermediate" truncation fix
- OUT: comprehensive UI audit of all app screens (separate enhancement), Google Cloud OAuth setup (already done), Supabase schema changes (already done)
