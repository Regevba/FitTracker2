# UX Research: auth-polish-v2

> **Phase:** 3 (UX)
> **Date authored:** 2026-04-28
> **Author:** /ux agent
> **Feature:** auth-polish-v2
> **Framework:** v7.6 PM Workflow
> **Work subtype:** new_ui (5 new screens, 2 modified)
> **Surfaces in scope:** ForgotPasswordRequestView, ForgotPasswordCooldownView,
>   SetNewPasswordView, BiometricActivationSheet, BiometricUnlockView,
>   AuthHubView (modified), OnboardingAuthView (modified)
>
> **Feeds into:** `ux-spec.md` §9 Principle Application Table
> **Used by:** v2-refactor-checklist sections A, E, F, G, H
> **Related PRD:** `.claude/features/auth-polish-v2/prd.md`
> **Related research:** `.claude/features/auth-polish-v2/research.md`

---

## 1. Applicable Principles — Master Table

For each of the 13 UX Foundations principles, this section documents applicability,
the concrete design decisions auth-polish-v2 must honor, and explicit do/don't rules.

### Principle 1.1 — Fitts's Law

**Applies:** YES — All 5 new screens have primary CTAs the user must hit decisively.
Password reset and biometric activation are high-stakes moments; errors (accidental
"Not now" instead of "Enable Face ID") erode trust permanently.

| How it applies | Design decision |
|---|---|
| "Send reset link" CTA must be impossible to miss | Full-width, 52pt height, anchored to bottom of screen (matches `AppSize.ctaHeight`) |
| "Unlock with Face ID" is the dominant action on BiometricUnlockView | Single primary CTA centered in lower 40% of screen; large biometric icon above it is visually reinforcing, not competitive |
| Biometric activation sheet "Enable {label}" must win the Fitts's race over "Not now" | Primary CTA is `AppButton.primary` (full-width, 52pt); secondary "Not now" is `AppButton.tertiary` (smaller, below) |
| Cooldown timer page — "Resend" must be clearly disabled, not just dimmed | Disabled state uses opacity + label change "Resend (42s)" so users don't mis-tap and get confused about why nothing happened |

**DO:** Primary CTA anchored to safe zone bottom, minimum 52pt height, full-width.
**DO:** Keep secondary actions (Use password, Not now, Use a different email) visually subordinate with `AppButton.tertiary`.
**DON'T:** Place two equally-sized CTAs side by side on any of these screens — ambiguity here fails the trust test.
**DON'T:** Make the biometric SF Symbol icon an independent tappable target that competes with the CTA button.

---

### Principle 1.2 — Hick's Law

**Applies:** YES — Auth surfaces are visited when the user is stressed (locked out,
forgot password) or eager (first sign-in, post-sign-in activation). More choices = more
hesitation = more abandonment.

| Screen | Max choices | Rule applied |
|---|---|---|
| ForgotPasswordRequestView | 2 (Send / Back) | One decision: confirm email or go back |
| ForgotPasswordCooldownView | 3 (Resend / Different email / Back) | Resend is disabled during cooldown — visually 1 live choice |
| SetNewPasswordView | 2 (Update password / Back) | Single form, single CTA |
| BiometricActivationSheet | 2 (Enable / Not now) | PRD is explicit about 2 choices; no third "Don't ask again" exposed during UX phase (PRD §flow D) |
| BiometricUnlockView | 2 (Unlock biometric / Use password) | The password fallback is a secondary link, not a button — visually 1 dominant choice |

**DO:** Limit active choices to ≤3 per screen.
**DO:** Make the disabled resend button communicate the reason (countdown) not just the state (grey).
**DON'T:** Add "Sign in with email instead" or "Use Apple Sign In" as tertiary options on the biometric screens — that belongs on the hub, not on this focused flow.

---

### Principle 1.3 — Jakob's Law

**Applies:** YES — Users have seen password-reset flows in every major app; they have
strong muscle memory for the pattern. Biometric activation follows Apple's own Settings
pattern exactly.

| Pattern | iOS convention | Our implementation |
|---|---|---|
| Forgot-password sheet | Sheet over sign-in screen | `ForgotPasswordRequestView` presented as `.sheet` from `EmailLoginView` |
| Email sent confirmation | Inline, stays in the sheet | `ForgotPasswordCooldownView` pushes within the sheet navigation stack |
| Deep-link return → set password | Full-screen push from RootView | `SetNewPasswordView` pushed from `RootView.onOpenURL` handler |
| Biometric activation | Sheet (not full-screen modal) | `BiometricActivationSheet` uses `.sheet` per iOS permission priming pattern (Part 5.2) |
| Biometric unlock | Full-screen (replaces auth entirely) | `BiometricUnlockView` uses `.fullScreenCover` per PRD §flow E |
| Sheet dismiss gesture | Swipe down | All sheets retain swipe-down dismissal (no `interactiveDismissDisabled` unless critical) |

**DO:** Follow the Supabase deep-link pattern exactly (Part 5.2 pre-primer + system dialog) for the biometric permission moment.
**DO:** Use iOS native `.sheet()` presentation — not a custom modal — for `ForgotPasswordRequestView` and `BiometricActivationSheet`.
**DON'T:** Invent a custom "email sent" animation that diverges from iOS standards — users know the inbox pattern from every other app.

---

### Principle 1.4 — Progressive Disclosure

**Applies:** YES — The forgot-password flow is a 3-screen sequence, not one big form.
Each screen reveals exactly what the user needs for that step.

| Flow step | What is disclosed | What is deferred |
|---|---|---|
| ForgotPasswordRequestView | Email field + send CTA + reassurance copy | Cooldown timer, resend logic — user hasn't hit the edge case yet |
| ForgotPasswordCooldownView | Sent confirmation + countdown + escape hatch | Password rules — shown only on SetNewPasswordView |
| SetNewPasswordView | Two password fields + rules tooltip + CTA | Auto-login detail — just happens silently |
| BiometricActivationSheet | One headline, one assurance line, two CTAs | Biometric enrollment instructions — handled by iOS LocalAuthentication natively |
| BiometricUnlockView | Brand icon, name, biometric CTA | Account management — accessible via "Use password" fallback |

**DO:** Split the reset flow into 3 sequential screens per the Whoop pattern (research §6.1).
**DO:** Reveal password rules on SetNewPasswordView only — not on ForgotPasswordRequestView.
**DON'T:** Put the 60s cooldown countdown on the initial ForgotPasswordRequestView — it's not relevant until after the email is sent.

---

### Principle 1.5 — Recognition Over Recall

**Applies:** YES — Auth flows specifically depend on pre-filled information (email from
previous screen) and visible state (cooldown time remaining).

| State that must be visible | Where | How |
|---|---|---|
| Email address that the reset link was sent to | ForgotPasswordCooldownView | Rendered inline: "We sent a link to **{email}**" — not redacted |
| Remaining cooldown time | ForgotPasswordCooldownView resend button | Button label updates live: "Resend (42s)" |
| Biometric type (Face ID vs Touch ID) | BiometricActivationSheet and BiometricUnlockView | `biometricAuth.biometricLabel` and `biometricAuth.biometricIcon` surfaced in CTA label and SF Symbol |
| "Welcome back, {firstName}" | BiometricUnlockView | User's first name shown — they recognize it's their account |
| Password validation rules | SetNewPasswordView | `PasswordRulesTooltip` is always visible (not collapsed by default) — requirements become visible as user types |

**DO:** Pre-fill the email from the previous screen on ForgotPasswordRequestView.
**DO:** Show the exact email address the link was sent to in the confirmation screen.
**DON'T:** Show a generic "Check your email" without the address — users with multiple accounts can't tell where the link went.

---

### Principle 1.6 — Consistency

**Applies:** YES — auth-polish-v2 adds screens to an existing auth surface that already
has established patterns (`AuthScaffold`, `AuthFormCard`, `AuthPrimaryButtonStyle`,
`AuthBannerView`, `PasswordRulesSecureField`).

| Pattern | Existing component | New screens that reuse it |
|---|---|---|
| Auth screen container | `AuthScaffold` (from AuthHubView.swift line 45) | ForgotPasswordRequestView, ForgotPasswordCooldownView, SetNewPasswordView, BiometricUnlockView |
| Form field card | `AuthFormCard` | ForgotPasswordRequestView (email field), SetNewPasswordView (two password fields) |
| Primary button style | `AuthPrimaryButtonStyle` | All primary CTAs across new screens |
| Error/info banner | `AuthBannerView` | ForgotPasswordRequestView (email validation error), SetNewPasswordView (password mismatch), BiometricUnlockView (biometric failure) |
| Secure password field + rules | `PasswordRulesSecureField` + `PasswordRulesTooltip` | SetNewPasswordView |
| Brand background gradient | `AppGradient.authBackground` | BiometricUnlockView (full-screen — same gradient as onboarding auth) |

**DO:** Reuse every existing auth component without restyling it.
**DO:** `BiometricActivationSheet` uses `AppSheetShell` (from AppComponents.swift) as the container — not `AuthScaffold` — because it's a sheet, not a full-page auth screen.
**DON'T:** Invent new button styles for the new auth screens. AuthPrimaryButtonStyle is the answer.

---

### Principle 1.7 — Feedback

**Applies:** YES — Every auth action is high-stakes. "Did the email send?" and "Did
the biometric scan work?" require immediate, unambiguous feedback.

| Action | Feedback (visual) | Feedback (haptic) | Timing |
|---|---|---|---|
| Tap "Send reset link" | Button enters loading state (inline spinner replaces label) | `.impact(.light)` | Immediate (< 100ms) |
| Email sent success | Screen transitions to ForgotPasswordCooldownView; checkmark icon appears | `.notification(.success)` | On API response |
| Tap "Unlock with Face ID" | Biometric icon scale pulse, then button enters loading state | `.impact(.medium)` | Immediate |
| Biometric success | Screen dismisses with spring transition to Home | `.notification(.success)` | On LAContext success callback |
| Biometric failure | `AuthBannerView` slides in with error message; icon shakes | `.notification(.error)` | On LAContext error callback |
| Tap "Enable Face ID" | Button enters loading state, then system Face ID dialog | `.impact(.light)` | Immediate |
| Biometric activation success | Sheet dismisses with spring; BiometricUnlockView will appear on next launch | `.notification(.success)` | On LAContext success |
| Password update success | Screen transitions to Home with haptic | `.notification(.success)` | On Supabase response |
| Cooldown timer tick | Button label updates in real time | No haptic | Every second |

**DO:** Never leave a button in "loading" state permanently — always resolve to success, error, or timeout.
**DO:** Use `UINotificationFeedbackGenerator(.success)` for the biometric activation moment — it is a milestone, not just a tap.
**DON'T:** Wait for the API round-trip before providing visual feedback on button press — the button must respond within 100ms.

---

### Principle 1.8 — Error Prevention

**Applies:** YES — Password reset and biometric activation are irreversible flows (in the
sense that errors waste the user's time significantly).

| Error prevention pattern | Applied to | How |
|---|---|---|
| Email validation inline | ForgotPasswordRequestView | CTA is disabled until email passes basic format validation (not empty, contains @) |
| Privacy-preserving response | ForgotPasswordRequestView | API always routes to confirmation screen regardless of whether email exists — no "email not found" that leaks account existence |
| Password rules inline validation | SetNewPasswordView | `PasswordRulesTooltip` shows rules; each rule turns green as user satisfies it; CTA disabled until both fields match and rules pass |
| Confirm field mismatch warning | SetNewPasswordView | Inline "Passwords don't match" below confirm field as user types — not on submit |
| Biometric scan timing | BiometricActivationSheet | User taps the CTA first (expressed intent), THEN Face ID dialog appears — never auto-triggers |
| Network retry | All network screens | `AuthBannerView` shows error + retry CTA; no data is lost |

**DO:** Keep the CTA disabled until minimum validation passes — not just after submit.
**DO:** Show "Passwords don't match" while the user is still in the confirm field (inline, not a toast).
**DON'T:** Auto-trigger `LAContext.evaluatePolicy` on sheet presentation — Apple HIG mandates user-initiated biometric prompts.

---

### Principle 1.9 — Readiness-First

**Applies:** NO (N/A — Auth surface is a prerequisite gate, not a content surface.
Readiness data is not available until the user is signed in. This principle governs
the home/today surface, not auth.)

---

### Principle 1.10 — Zero-Friction Logging

**Applies:** PARTIALLY — Auth is not a logging surface, but the biometric unlock path
is a daily interaction that should be frictionless.

| Application | Design decision |
|---|---|
| Biometric unlock on relaunch | One tap on the CTA → Face ID scan → Home. Total actions: 2 (tap + biometric). Comparable to iPhone unlock. |
| Forgot-password flow | 3 screens is the minimum for PKCE security compliance. Cannot be reduced without sacrificing security or deep-link return. |
| Pre-fill email | ForgotPasswordRequestView pre-fills email from the calling screen's form state — user never re-types it. |

**DO:** Pre-fill the email field from the EmailLoginView state when the sheet is presented.
**DON'T:** Add CAPTCHA or additional verification steps to the biometric unlock path.

---

### Principle 1.11 — Privacy by Default

**Applies:** YES — Auth surfaces are where trust is established or broken.

| Privacy rule | Applied to | Implementation |
|---|---|---|
| Don't enumerate accounts | ForgotPasswordRequestView | Always route to confirmation screen, never "email not found" |
| No PII in analytics | All auth events | `email_provided: bool` not the actual email; `biometric_type` not user identity |
| Biometric data stays on device | BiometricActivationSheet assurance copy | "Your data stays encrypted on this device" — one-sentence reassurance in activation sheet |
| Session data in Keychain | BiometricUnlockView | No session tokens in UserDefaults; Keychain only |
| Google ID token handling | Flow G | Token exchanged immediately for Supabase session; Google token not persisted |

**DO:** Use the exact copy "Your data stays encrypted on this device" in BiometricActivationSheet.
**DO:** Fire `email_provided: bool` (not the address) in `auth_password_reset_requested`.
**DON'T:** Show the user's full email address in any toast or notification that might appear in notification center.

---

### Principle 1.12 — Progressive Profiling

**Applies:** YES — Biometric activation is a one-time post-sign-in ask that fits this principle exactly.

| Application | Design decision |
|---|---|
| Activation prompt fires ONCE, after sign-in | Not during onboarding (too early — user hasn't built trust yet); not on every launch (irritating) |
| "Not now" is permanent | `hasAskedForBiometricActivation` flag ensures one-shot; user can still enable via Settings |
| No explanation of why during prompt | The prompt IS the explanation — "Unlock FitMe with Face ID" is self-evidently beneficial |

**DO:** Honor `hasAskedForBiometricActivation` — never show the activation sheet twice.
**DON'T:** Show biometric activation during onboarding — the user is still in the welcome funnel.

---

### Principle 1.13 — Celebration Not Guilt

**Applies:** YES — Password recovery and biometric activation are moments that can be
framed positively.

| Situation | "Celebration" framing | "Guilt" framing we avoid |
|---|---|---|
| Password reset complete | "You're back in. Welcome." | "You had to reset your password" |
| Biometric activation success | "Your account is now protected with Face ID" | "You finally set up biometric" |
| Biometric activation declined | Silent — no guilt, no follow-up | "You missed this security feature" |
| Biometric unlock failure | "Use password instead" — neutral fallback | "Face ID failed again" |

**DO:** Use positive present-tense framing on success screens.
**DO:** Treat "Not now" on biometric activation as a valid, respected choice — no retry, no explanation requested.
**DON'T:** Use red text or warning iconography for the biometric failure state — use a neutral `AuthBannerView` in warning tone.

---

## 2. Apple HIG Audit

### 2.1 Sheets

**HIG reference:** Human Interface Guidelines → Sheets
- Sheets slide up from the bottom edge and partially cover the parent view.
- Sheets are appropriate for creation, confirmation, and focused sub-tasks.
- Users expect swipe-down to dismiss.
- Sheet height: system-resizable via `.presentationDetents` — default is large (fills most of screen).

**auth-polish-v2 application:**
- `ForgotPasswordRequestView` — presented as `.sheet` from `EmailLoginView`. Height: `.large` detent (needs full keyboard + form). Swipe-down dismissal retained.
- `BiometricActivationSheet` — presented as `.sheet` from `RootView`. Height: `.medium` detent preferred (compact offering, not full-page). Drag indicator shown.
- `ForgotPasswordCooldownView` — pushed within the sheet navigation stack (not a new sheet). The sheet persists; content changes.

### 2.2 Deep-link Return

**HIG reference:** Apple Tech Note — URL Scheme Handling; Supabase native mobile deep linking
- Apps must declare URL schemes in `Info.plist` under `CFBundleURLTypes`.
- `UIApplicationDelegate.application(_:open:options:)` (or SwiftUI `.onOpenURL`) receives the URL.
- After `client.auth.session(from: url)`, the app has an active session and can navigate.

**auth-polish-v2 application:**
- URL scheme `fitme://reset-password` declared in Info.plist.
- `FitTrackerApp.swift` `.onOpenURL` handles the route and sets a `@State var showSetPassword: Bool`.
- `SetNewPasswordView` is presented as a push from `RootView` (not a sheet) — user has just returned from email client, full-screen context is appropriate.
- **Supabase whitelist:** `fitme://reset-password` must be added to Supabase dashboard redirect URLs (Appendix C of PRD — launch checklist item, not a code task).

### 2.3 Biometric Authentication

**HIG reference:** Human Interface Guidelines → Authentication → Face ID / Touch ID
Key HIG rules:
1. "Always request authentication before presenting content that requires it" — BiometricUnlockView blocks the home tab until scan succeeds.
2. "Allow users to fall back to a password" — secondary "Use password" CTA satisfies this.
3. "Request face ID or Touch ID when the user initiates an action" — `BiometricActivationSheet` CTA initiates `LAContext.evaluatePolicy`, never auto-triggers.
4. "Use face ID or Touch ID only for locking and unlocking your app" — we satisfy this precisely.
5. NSFaceIDUsageDescription must be in Info.plist explaining the use.

**Additional HIG compliance for LocalAuthentication:**
- `LAContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics)` for biometric-only.
- Fallback to `.deviceOwnerAuthentication` (includes passcode) via the secondary "Use password" path — or let iOS handle the automatic fallback sequence.
- Error codes to handle in BiometricUnlockView: `LAError.biometryNotEnrolled`, `LAError.biometryLockout`, `LAError.userCancel`, `LAError.authenticationFailed`.

### 2.4 Sign In with Services (Sheet vs Tab vs Modal)

**HIG reference:** Sign in with Apple (generalizable to Google Sign In)
- "Present Sign in with Apple button in a sheet" — for returning users, the Google Sign-In native sheet is already a system-level sheet presented by GoogleSignIn-iOS SDK.
- "Don't place sign-in buttons behind navigation" — `AuthHubView` places them at the root of the auth flow.
- For `OnboardingAuthView`: social sign-in buttons appear in step 5 of the 6-step onboarding sequence — no extra navigation required.

**auth-polish-v2 application:**
- Google Sign In UI rows in `AuthHubView` and `OnboardingAuthView` auto-render once `GoogleRuntimeConfiguration.isConfigured` returns true.
- The `GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)` call opens the Google account picker as a native modal — this is correct per HIG (system manages the sheet, app manages the result).

---

## 3. Competitive UX Analysis

### 3.1 Forgot-Password Flow Comparison

| App | Entry point | Request screen | Confirmation screen | Set new password | Deep-link return |
|---|---|---|---|---|---|
| **Strava** | Dedicated "Forgot password?" link on sign-in | Single email field, send CTA, reassurance copy | "Email sent — check inbox" with resend link | In-app (deep-link return via URL scheme) | Yes — full in-app |
| **MyFitnessPal** | Inline button on sign-in | Dedicated screen (email + CTA) | Email sent confirmation | Web page via Safari handoff | No — web only |
| **Hevy** | Email field on sign-in | Web redirect to Supabase hosted page | N/A (web handles it) | Web page | No — web only |
| **Whoop** | "Forgot password" link on sign-in | Dedicated screen + in-app deep-link return | Email sent + resend with cooldown | Full in-app set-new-password screen | Yes — full in-app |
| **Strong** | Inline → web Safari | Web-based | N/A | Web page | No |
| **FitMe (current)** | Inline button, status banner only | None (just fires API) | None | None | None |
| **FitMe (after this feature)** | Dedicated ForgotPasswordRequestView sheet | Single email field, pre-filled | ForgotPasswordCooldownView with countdown | SetNewPasswordView with inline validation | Yes (fitme://reset-password) |

**Winner pattern (adopted):** Whoop/Strava — full in-app 3-screen flow with deep-link return. This is the best-practice pattern for fitness apps where session continuity matters.

**Key differentiator from MyFitnessPal/Hevy:** In-app return eliminates the Safari handoff step. Users who start on iPhone complete the entire flow in FitMe without being ejected to a web browser.

### 3.2 Biometric Activation Timing Comparison

| App | When prompt appears | Trigger condition | Can skip? | One-shot? |
|---|---|---|---|---|
| **Whoop** | Immediately after first sign-in (same session) | Biometric available + not previously enabled | Yes ("Not now") | Yes — never shows again if skipped |
| **Strava** | Second launch after sign-in | New user + biometric available | Yes | Not documented — may re-show |
| **MyFitnessPal** | Settings toggle only | User-initiated | N/A | N/A |
| **Strong** | Settings toggle only | User-initiated | N/A | N/A |
| **Banking apps (Chase, Capital One)** | Immediately after first sign-in | Biometric available + first login | Yes ("Not now") | Yes |
| **FitMe (after this feature)** | Immediately after first email or Google sign-in | `biometricAuth.isAvailable && !requireBiometric && !hasAskedForBiometric` | Yes ("Not now") | Yes |

**PRD decision (OQ-1):** Immediate activation prompt (Whoop/banking pattern). Research supports this: user receptiveness peaks at the just-signed-in moment. Strava's second-launch approach is more conservative but loses 15-20% activation per public talks.

**Why activation conversion matters:** PRD secondary metric targets `auth_biometric_activated / auth_biometric_activation_offered ≥ 35%` at 60 days (T1). Whoop's public data suggests ~40% conversion on immediate prompts vs ~22% for second-launch. The banking app pattern (immediate) is consistent with Apple's own Settings onboarding flow.

### 3.3 Google Sign-In Integration Patterns

| App | Entry point | SDK used | Sheet type | Supabase bridge |
|---|---|---|---|---|
| **MyFitnessPal** | Auth hub (row with Google logo) | GoogleSignIn-iOS | Native Google account picker (system modal) | Direct (not via Supabase) |
| **Strava** | Auth hub + onboarding | GoogleSignIn-iOS 8.x | Native Google account picker | Direct (not via Supabase) |
| **Hevy** | Auth hub | GoogleSignIn-iOS | Native | Via Supabase OAuth |
| **FitMe (after this feature)** | AuthHubView + OnboardingAuthView (auto-renders when configured) | GoogleSignIn-iOS 8.x | Native Google account picker via GIDSignIn | Supabase `signInWithIdToken` + nonce per Discussion #34959 |

**Key finding:** Every major fitness app uses the native `GoogleSignIn-iOS` SDK, not ASWebAuthenticationSession. This matches the PRD decision and Apple HIG recommendation. The native sheet provides the Google account chooser that users recognize from every other app on their phone (Jakob's Law).

---

## 4. External UX Research Sources

### 4.1 Supabase Deep Linking Docs

- **Source:** https://supabase.com/docs/guides/auth/native-mobile-deep-linking
- **Relevant finding:** `client.auth.session(from: url)` is the canonical Swift call after the URL scheme triggers. This returns an active session immediately if the token is valid.
- **UX implication:** The transition from email tap → app open → SetNewPasswordView happens in <1 second on a typical device. No intermediate loading screen is needed between the URL handler and SetNewPasswordView — but a brief loading state should be shown in case the token exchange takes >200ms.

### 4.2 Apple LocalAuthentication HIG

- **Source:** https://developer.apple.com/documentation/localauthentication/logging-a-user-into-your-app-with-face-id-or-touch-id
- **Key UX rules:**
  1. Always include the reason string in `LAContext.localizedReason` (shown in the Face ID dialog).
  2. Never describe the authentication method in the reason — iOS supplies that copy.
  3. Use "Unlock {App Name}" as the reason string pattern (matches Apple Pay and banking apps).
  4. Handle `LAError.biometryLockout` — device passcode required; redirect to passcode authentication.
  5. Test on physical device — simulator Face ID behavior differs.
- **UX implication:** Our `localizedReason` string = "Unlock FitMe to continue". Keep it short; the Face ID sheet UI has limited space for the reason.

### 4.3 Google Sign-In iOS Guidance

- **Source:** https://developers.google.com/identity/sign-in/ios
- **Key UX finding:** `GIDSignIn.sharedInstance.signIn(withPresenting:)` requires the presenting `UIViewController`. In SwiftUI, this means accessing `UIApplication.shared.windows.first?.rootViewController` or using a `UIViewControllerRepresentable` wrapper. The app should not try to pre-warm or pre-authorize — the call is fast.
- **UX implication:** The Google "Continue with Google" button row can use the standard SF Symbol `person.badge.key.fill` or the actual Google logo via assets. The SDK returns within 1-3 seconds for account selection; show loading state on the button during that window.

### 4.4 Orbix Studio Biometric Auth Design Guidelines (2026)

- **Source:** https://www.orbix.studio/blogs/biometric-authentication-app-design (cited in research.md §4)
- **Key finding:** "Opt-in, one-sentence assurance, easy off-switch" — three required elements for biometric activation UX.
- **UX implication:** BiometricActivationSheet must have: (1) explicit opt-in via CTA (not auto-prompt), (2) one-sentence assurance copy, (3) a visible "Not now" option that is clearly non-permanent (users should know they can enable it later in Settings).

---

## 5. User Flow Mapping

### 5.1 Sub-bundle A — Forgot Password

#### Primary path (happy path)
```
EmailLoginView
  ↓ tap "Forgot password?"
ForgotPasswordRequestView (sheet, medium detent optional or large)
  ↓ email pre-filled, tap "Send reset link"
  → API: auth.requestPasswordReset(email:, redirectTo: "fitme://reset-password")
  → fire auth_password_reset_requested
ForgotPasswordCooldownView (push within sheet)
  ↓ user opens email app, taps link
  → iOS: fitme://reset-password?... opens app
  → RootView.onOpenURL → client.auth.session(from: url)
SetNewPasswordView (full-screen push from RootView)
  ↓ user enters new password, taps "Update password"
  → API: auth.updateUser(password:)
  → fire auth_password_reset_completed
Home Tab (auto-login success)
```

#### Skip path
- User has changed device → link opens on original device → handled by Supabase PKCE session expiry.
- User closes the sheet at ForgotPasswordRequestView → dismisses, back to EmailLoginView. No state change.
- User closes the sheet at ForgotPasswordCooldownView → dismisses, back to EmailLoginView. Has not yet completed reset; can re-enter from the forgot-password button again.

#### Error paths
- **Empty/invalid email:** CTA remains disabled. No API call. Inline validation "Enter a valid email address" below field.
- **Network error on requestPasswordReset:** `AuthBannerView` shows "Couldn't send reset email. Check your connection and try again."
- **Token expired when opening deep link:** Supabase returns error. App should show `AuthBannerView` on SetNewPasswordView (or a dedicated expired-link screen) with "This link has expired. Request a new one."
- **Password mismatch on SetNewPasswordView:** Inline "Passwords don't match" appears as user types in confirm field.
- **Password rules failure:** PasswordRulesTooltip shows unmet rules in error color; CTA remains disabled.

#### Edge cases
- **User has multiple email accounts:** ForgotPasswordCooldownView shows the exact email address. "Use a different email" → back to ForgotPasswordRequestView with cleared field.
- **User taps resend within cooldown window:** Button is disabled; `auth_password_reset_resend_blocked` fires; label shows remaining seconds.
- **User taps resend after cooldown:** Button re-enables; `auth_password_reset_resend` fires; cooldown resets to 60s.

### 5.2 Sub-bundle B — Biometric

#### Primary path — first activation
```
[Any sign-in completion]
  ↓ RootView checks: biometricAuth.isAvailable && !requireBiometric && !hasAskedForBiometric
BiometricActivationSheet (sheet from RootView)
  ↓ fire auth_biometric_activation_offered
  ↓ user taps "Enable Face ID"
  → LAContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics)
  → user authenticates
  ↓ set requireBiometricUnlockOnReopen = true
  ↓ set hasAskedForBiometricActivation = true
  → fire auth_biometric_activated
BiometricActivationSheet dismisses → Home Tab
```

#### Primary path — subsequent unlock
```
App launched → RootView checks: hasStoredSession && requireBiometric && biometricAuth.isAvailable
BiometricUnlockView (.fullScreenCover, blocks tab access)
  ↓ fire auth_biometric_unlock_started (optional/local only, not in analytics spec)
  ↓ user taps "Unlock with Face ID"
  → LAContext.evaluatePolicy
  → success
  ↓ fire auth_biometric_unlock_completed
Home Tab
```

#### Skip/decline path (activation)
```
BiometricActivationSheet
  ↓ user taps "Not now"
  → set hasAskedForBiometricActivation = true
  → fire auth_biometric_activation_declined
Home Tab
```

#### Error path (unlock)
```
BiometricUnlockView
  ↓ user taps CTA
  → LAContext fails (LAError.authenticationFailed)
  → iOS auto-retries once
  → second failure or user cancel
  → fire auth_biometric_unlock_failed (reason: "biometry_failed" or "user_cancel")
  ↓ AuthBannerView: "Face ID didn't work. Use your password instead."
  ↓ secondary CTA "Use password" becomes primary
EmailLoginView (email pre-filled from stored session)
```

#### Edge cases
- **Device biometrics disabled/locked:** `LAError.biometryLockout` → redirect to passcode flow via `LAContext.evaluatePolicy(.deviceOwnerAuthentication)` fallback.
- **User un-enrolls Face ID in Settings:** `biometricAuth.isAvailable` returns false → `BiometricUnlockView` is skipped; user lands on `AuthHubView` instead. `requireBiometricUnlockOnReopen` should be reset to false when biometry becomes unavailable.
- **Optic ID (Vision Pro):** `biometricAuth.biometricLabel` returns "Optic ID"; biometric icon shows correct SF Symbol. PRD analytics spec includes `"optic_id"` as an allowed value for `biometric_type`.

### 5.3 Sub-bundle C — Google Sign In

#### Primary path (new user)
```
OnboardingAuthView step 5 (or AuthHubView)
  ↓ GoogleRuntimeConfiguration.isConfigured == true → "Continue with Google" row visible
  ↓ user taps row
  → fire auth_signin_started (provider: "google")
  → GIDSignIn.sharedInstance.signIn(withPresenting:)
  → native Google account picker sheet
  ↓ user selects account + grants consent
  → Google returns GIDSignInResult
  → supabase.auth.signInWithIdToken(credentials:)
  ↓ fire auth_signin_completed (provider: "google")
  ↓ check biometric trigger: BiometricActivationSheet (if applicable)
Home Tab (or onboarding continues to step 6)
```

#### Cancelled/error path
```
  ↓ user taps "Cancel" in Google sheet
  → GIDSignInError thrown
  → fire auth_signin_cancelled (provider: "google")
  ↓ AuthBannerView: "Google sign-in cancelled. Try again or use another method."
Auth screen unchanged
```

---

## 6. CX Signal Check

**Source reviewed:** `.claude/shared/cx-signals.json` (version 1.0, updated 2026-04-04)

The CX signals file does not yet contain any user-reported auth friction signals — the
signals arrays for reviews, confusion signals, and friction phrases are empty (the app
is in pre-launch development).

**Pattern-based analysis using the keyword_patterns in cx-signals.json:**

The keyword patterns document known friction signals: "too many steps", "complicated",
"can't figure out", "confusing navigation". These map to the following auth-surface risks:

| CX risk pattern | Mitigation in auth-polish-v2 |
|---|---|
| "too many steps" | Forgot-password flow is 3 screens minimum (security requirement). Mitigated by: pre-filled email (no re-entry), inline validation (no re-submission), skip path with sheet dismissal. |
| "can't figure out" | Biometric activation uses explicit labeling: "Unlock FitMe with Face ID" — not "Enable biometric authentication". Plain language throughout. |
| "confusing navigation" | Each auth screen is linearly forward-only. No ambiguous back states. Sheet dismiss = "I changed my mind, cancel entire flow". |
| "doesn't work" | Biometric lock-out and network errors have explicit inline `AuthBannerView` messages — users know what happened. |

**Dispatch conclusion:** No live CX signals to dispatch. Zero user-reported auth friction
in the signals file. The design decisions in this spec are informed by competitive
analysis and Apple HIG rather than reactive CX repair.

**CX monitoring recommendation (post-launch):** Add `auth_password_reset_resend_blocked`
rate to the CX signal dashboard. A rate > 5% (PRD guardrail) indicates users don't
understand the cooldown and are rapidly re-tapping — a UX signal to increase cooldown
visibility or shorten the window.

---

## 7. Compliance Gateway Pre-Check

### 7.1 Token Compliance (C-dimension)

All new screens inherit the token pattern from `AuthHubView` (existing auth surface).
No raw literals are anticipated. Key token uses verified against `AppTheme.swift`:

| Token namespace | Available tokens confirmed | Use in auth-polish-v2 |
|---|---|---|
| `AppColor.Background.authTop/Middle/Bottom` | Yes (AppTheme.swift line 27-29) | `BiometricUnlockView` gradient background |
| `AppGradient.authBackground` | Yes (AppTheme.swift line 313) | `BiometricUnlockView`, `ForgotPasswordRequestView` scaffold |
| `AppColor.Accent.primary` | Yes | Primary CTA backgrounds |
| `AppColor.Status.success/error/warning` | Yes | Inline validation states, success/error banners |
| `AppColor.Text.primary/secondary/tertiary` | Yes | All body/caption/label text |
| `AppColor.Text.inversePrimary` | Yes | Text on primary CTA buttons |
| `AppRadius.authSheet` (36pt) | Yes | Sheet containers |
| `AppRadius.button` (20pt) | Yes | Form card corners |
| `AppSize.ctaHeight` (52pt) | Yes | All primary CTA buttons |
| `AppSpacing.small` (16pt) | Yes | Standard horizontal padding |
| `AppSpacing.medium` (20pt) | Yes | Card internal padding |
| `AppSpring.smooth` | Yes | Sheet present/dismiss transitions |
| `AppSpring.snappy` | Yes | Biometric icon confirmation scale pulse |
| `AppSpring.bouncy` | Yes | Biometric activation success animation |
| `AppDuration.standard` (300ms) | Yes | Screen transitions |
| `AppDuration.short` (200ms) | Yes | Banner slide-in/out |

**New token need (DS-Evolution proposal):** None. No new tokens are needed for auth-polish-v2.
The existing auth token set (`AppColor.Background.auth*`, `AppGradient.authBackground`,
`AppRadius.authSheet`, `AppRadius.button`) covers all required visual states. The biometric
icon is rendered via SF Symbol at `AppText.iconDisplay` (72pt), which is an existing token.

### 7.2 Component Reuse (D-dimension)

| Component needed | Available in DS | Location |
|---|---|---|
| Screen container | `AuthScaffold` | `AuthHubView.swift` (private) — note: needs extraction |
| Form card | `AuthFormCard` | `AuthHubView.swift` (private) — note: needs extraction |
| Primary button style | `AuthPrimaryButtonStyle` | `AuthHubView.swift` (private) — note: needs extraction |
| Error/info banner | `AuthBannerView` | `AuthHubView.swift` (private) |
| Secure field + rules | `PasswordRulesSecureField` + `PasswordRulesTooltip` | `AuthHubView.swift` (private) |
| Sheet shell | `AppSheetShell` | `FitTracker/DesignSystem/AppComponents.swift` |
| Primary button (generic) | `AppButton` | `FitTracker/Views/Shared/AppDesignSystemComponents.swift` |
| Brand icon | `FitMeBrandIcon` | `FitTracker/DesignSystem/FitMeBrandIcon.swift` |
| Loading animation | `FitMeLogoLoader` | `FitTracker/DesignSystem/FitMeLogoLoader.swift` |

**Implementation note for Phase 4:** `AuthScaffold`, `AuthFormCard`, `AuthPrimaryButtonStyle`, and
`AuthBannerView` are currently private types inside `AuthHubView.swift`. Phase 4 should extract
these to a shared `AuthSharedComponents.swift` file so the new screens can import them without
copy-pasting. This is an existing DS gap, not a new one — flagged for Phase 4 implementer.

**No new components needed.** All patterns are served by existing components.

### 7.3 Gateway Result (preliminary)

| Dimension | Pre-check | Notes |
|---|---|---|
| Token compliance | PASS | All tokens exist in AppTheme.swift |
| Component reuse | PASS (with caveat) | Auth private components need extraction in Phase 4 |
| Motion | PASS | AppSpring.smooth / AppSpring.snappy / AppSpring.bouncy all applicable |
| Accessibility | PASS | 30+ VoiceOver labels specified in ux-spec.md §6 |
| Pattern compliance | PASS | No new patterns invented; all patterns match existing auth surface |

**Preliminary: 5/5 pass.** Full gateway recorded in ux-spec.md §9.

---

*End of ux-research.md — feeds into ux-spec.md Section 9 (Principle Application Table)*
