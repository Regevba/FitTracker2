# UX Spec: Onboarding v2 Auth Flow

> **Feature:** onboarding-v2-auth-flow
> **Date:** 2026-04-15
> **Inputs:** research.md, prd.md, ux-foundations.md

---

## 1. Principle Application Table

| Principle | Applies? | How Applied |
|---|---|---|
| **Fitts's Law** | Yes | Auth buttons are full-width, 52pt height. "Log In" link has generous tap target. Success screen is tap-anywhere-to-skip. |
| **Hick's Law** | Yes | Auth step shows max 3 providers + 1 login link. No overwhelming list of options. |
| **Jakob's Law** | Yes | Auth UI follows iOS patterns (Apple Sign In native button, Google branding). Users recognize these from other apps. |
| **Progressive Disclosure** | Yes | Auth comes AFTER the user has set goals/profile/consent — the ask is motivated. Email registration unfolds into a form only when tapped. |
| **Recognition over Recall** | Yes | Provider icons (envelope, Google G, Apple logo) are universally recognized. No text-only buttons. |
| **Consistency** | Yes | Auth step uses the same `AppGradient.screenBackground`, `AppText`, `AppColor` tokens as steps 1-4. Not a jarring style switch. |
| **Feedback** | Yes | Success animation provides celebration. Auth failure shows inline banner. Loading states during auth. |
| **Error Prevention** | Yes | Email validation before submit. Password rules shown upfront. Google/Apple auth has no user-side error path. |
| **Minimum Viable Friction** | Yes | Only 3 auth options shown. "Skip" is NOT available on auth step (account is required for data persistence). But "Log In" provides an escape for returning users. |
| **Celebration Not Guilt** | Yes | Success screen celebrates: "Welcome to FitMe!" with animation. No "finally" or "about time" language. |

---

## 2. Screen Definitions

### Screen 5: OnboardingAuthView (Create Account)

**Entry:** User taps "Accept & Continue" or "Continue Without" on Consent step (step 4).

**Layout (top to bottom):**

```
┌─────────────────────────────────┐
│  ← (back)    ●●●●●○○○          │  progress bar (step 5 of 8, hidden)
│                                 │
│         🔒                      │  SF Symbol: person.badge.plus
│    (circle background)          │  AppColor.Brand.coolSoft.opacity(0.5)
│                                 │
│   Save your progress            │  AppText.titleStrong
│                                 │
│   Create an account to keep     │  AppText.bodyRegular
│   your data safe and synced     │  AppColor.Text.secondary
│   across devices.               │
│                                 │
│  ┌─────────────────────────┐    │
│  │ 📧  Continue with Email │    │  AuthProviderRow style
│  └─────────────────────────┘    │  AppColor.Surface.elevated bg
│  ┌─────────────────────────┐    │
│  │ G   Continue with Google│    │  White bg, Google branding
│  └─────────────────────────┘    │
│  ┌─────────────────────────┐    │
│  │ 🍎  Continue with Apple │    │  Black bg, white text
│  └─────────────────────────┘    │
│                                 │
│   Already have an account?      │  AppText.body
│   Log In                        │  AppColor.Brand.primary, tappable
│                                 │
│   ⚠️ Error banner (if any)      │  AppColor.Status.error tint
│                                 │
└─────────────────────────────────┘
```

**Visual style:**
- Background: `AppColor.Background.appTint` (same as steps 1-4, not authBackground)
- Hero icon: `person.badge.plus` in `AppText.iconHero`, `AppColor.Brand.secondary`
- Circle backing: `AppColor.Brand.coolSoft.opacity(0.5)`, 120pt diameter
- Title: "Save your progress" — frames auth as benefit, not requirement
- Subtitle: motivates WHY (data safety + sync)
- Provider buttons: reuse `AuthCardButtonStyle` patterns from AuthHubView but in onboarding colors
- Error banner: same `AuthBannerView` pattern, positioned below buttons
- Back button: navigates to step 4 (consent)

**States:**

| State | Appearance |
|---|---|
| Default | 3 provider cards + login link visible |
| Loading (after tap) | Tapped button shows ProgressView, others disabled |
| Error | Red banner below buttons with error message. Buttons re-enabled. |
| Email selected | Navigates to inline email registration form (reuse EmailRegistrationView layout within onboarding scroll) |

**Interaction:**
- Tap "Continue with Email" → expand inline email form (first name, last name, email, password, confirm) OR push to email registration sub-step
- Tap "Continue with Google" → trigger `signIn.signInWithGoogle()` → loading → success callback
- Tap "Continue with Apple" → trigger `signIn.signInWithApple()` → native Apple sheet → success callback
- Tap "Log In" → navigate to email login form. On success → `onLogin()` → skip success + first action → Home
- On auth success → `onAuthenticated(session)` → advance to step 6

**Accessibility:**
- VoiceOver: "Create account. Continue with Email, button. Continue with Google, button. Continue with Apple, button. Already have an account? Log in, button."
- All buttons meet 44pt minimum tap target
- Error banner announced via `.accessibilityAnnouncement`

---

### Screen 6: OnboardingSuccessView

**Entry:** Successful authentication from step 5.

**Layout:**

```
┌─────────────────────────────────┐
│                                 │
│                                 │
│                                 │
│            ✓                    │  Animated checkmark
│         (circle)                │  Scale 0→1 + opacity
│                                 │
│   Welcome to FitMe!             │  AppText.hero
│                                 │
│   {firstName}, your account     │  AppText.body
│   is ready.                     │  AppColor.Text.secondary
│                                 │
│                                 │
│                                 │
│   Tap anywhere to continue      │  AppText.caption
│                                 │  AppColor.Text.tertiary
│                                 │  Fade in after 1s
└─────────────────────────────────┘
```

**Visual style:**
- Background: `AppGradient.brand` (orange gradient, same as Welcome step — bookend effect)
- Checkmark: `AppColor.Surface.inverse` (white) circle, 80pt, with `checkmark` SF Symbol
- Animation: circle scales from 0.3→1.0 with `AppMotion.spring`, checkmark fades in 0.3s after circle
- Title: "Welcome to FitMe!" in `AppText.hero`, `AppColor.Text.inversePrimary` (white on orange)
- Subtitle: "{firstName}, your account is ready." — personalized
- "Tap anywhere" hint fades in after 1s delay
- Auto-advance after 2s via `Task.sleep`

**States:**

| State | Appearance |
|---|---|
| Animating (0-0.5s) | Checkmark circle scales in, icon fades in |
| Resting (0.5-1s) | Full checkmark visible, text appears |
| Hint visible (1-2s) | "Tap anywhere to continue" fades in |
| Auto-advance (2s) | Transitions to step 7 |

**Accessibility:**
- VoiceOver: "Welcome to FitMe! {firstName}, your account is ready. Double tap to continue."
- Reduce motion: skip animation, show final state immediately, still auto-advance after 2s

---

## 3. Modified Screens

### OnboardingView (container)

| Change | Details |
|---|---|
| `totalSteps` | 6 → 8 |
| Step 5 tag | `OnboardingAuthView` |
| Step 6 tag | `OnboardingSuccessView` |
| Step 7 tag | `OnboardingFirstActionView` (moved from tag 5) |
| Progress bar visibility | Hide on steps 0 (welcome), 5 (auth), 6 (success) |
| Background | Step 6 uses `AppGradient.brand` (like step 0). Steps 5, 7 use `AppColor.Background.appTint`. |

### OnboardingProfileView

| Change | Details |
|---|---|
| ExperienceCard label | Add `.minimumScaleFactor(0.8)` + `.lineLimit(1)` to prevent "Intermediate" truncation |

### OnboardingProgressBar

| Change | Details |
|---|---|
| Total segments | 6 → 8 |
| Hidden steps | 0, 5, 6 (was just 0 and 4) |

### FitTrackerApp rootView

| Change | Details |
|---|---|
| Remove | `AuthHubView` branch entirely |
| Simplify | `!hasCompletedOnboarding` → OnboardingView. `isAuthenticated` → RootTabView. `hasStoredSession + biometric` → LockScreen. else → reset onboarding. |

---

## 4. Navigation Flow Diagram

```
Step 0 (Welcome)
  │ "Get Started"
  ▼
Step 1 (Goals)
  │ "Continue" / "Skip"
  ▼
Step 2 (Profile)
  │ "Continue" / "Skip"
  ▼
Step 3 (HealthKit)
  │ "Connect" / "Skip"
  ▼
Step 4 (Consent)
  │ "Accept" / "Continue Without"
  ▼
Step 5 (Auth) ◄──── back button returns to step 4
  │
  ├── "Continue with Email" → inline form → Register → onAuthenticated
  ├── "Continue with Google" → Google OAuth → onAuthenticated
  ├── "Continue with Apple" → Apple Sign In → onAuthenticated
  └── "Log In" → email login → onLogin → completeOnboarding → HOME
  │
  ▼ (onAuthenticated)
Step 6 (Success)
  │ auto-advance 2s / tap to skip
  ▼
Step 7 (First Action)
  │ "Start Workout" / "Log Meal" → completeOnboarding
  ▼
HOME (RootTabView)
```

---

## 5. Design System Compliance

| Check | Status | Notes |
|---|---|---|
| Token compliance | Pass | All colors, fonts, spacing from AppTheme. No raw values. |
| Component reuse | Pass | Auth buttons reuse AuthCardButtonStyle patterns. Error banner reuses AuthBannerView pattern. |
| Pattern consistency | Pass | Onboarding auth matches consent step structure (hero icon + title + subtitle + actions). |
| Accessibility | Pass | All buttons ≥44pt. VoiceOver labels defined. Reduce motion supported. Dynamic Type via ScrollView. |
| Motion | Pass | Success animation uses AppMotion.spring. MotionSafe respects reduceMotion. |

No design system violations. No new tokens or components required.

---

## 6. Copy

| Screen | Element | Text |
|---|---|---|
| Auth (step 5) | Title | "Save your progress" |
| Auth (step 5) | Subtitle | "Create an account to keep your data safe and synced across devices." |
| Auth (step 5) | Email button | "Continue with Email" |
| Auth (step 5) | Google button | "Continue with Google" |
| Auth (step 5) | Apple button | "Continue with Apple" |
| Auth (step 5) | Login link | "Already have an account? Log In" |
| Auth (step 5) | Error (cancelled) | "Sign-in was cancelled. Try again or use another method." |
| Auth (step 5) | Error (network) | "Couldn't connect. Check your internet and try again." |
| Auth (step 5) | Error (invalid) | "Invalid email or password. Please try again." |
| Success (step 6) | Title | "Welcome to FitMe!" |
| Success (step 6) | Subtitle | "{firstName}, your account is ready." |
| Success (step 6) | Hint | "Tap anywhere to continue" |
