# UX Build Prompt: auth-polish-v2

> **Feature:** auth-polish-v2
> **Work subtype:** new_ui (5 new screens, 2 modified existing)
> **Target agent:** SwiftUI implementation (Phase 4)
> **Date:** 2026-04-28
> **GitHub Issue:** [#143](https://github.com/Regevba/FitTracker2/issues/143)
> **Branch:** `feature/auth-polish-v2`
> **UX spec:** `.claude/features/auth-polish-v2/ux-spec.md`
> **UX research:** `.claude/features/auth-polish-v2/ux-research.md`
> **PRD:** `.claude/features/auth-polish-v2/prd.md`

---

## Context

auth-polish-v2 closes three auth surface gaps in a single coordinated release:
(a) a dedicated forgot-password recovery flow with deep-link return from email,
(b) refined biometric (Face ID / Touch ID) unlock UI plus a one-time post-sign-in
activation prompt, and (c) Google Sign In SDK activation that lights up UI rows
already wired but currently hidden behind `GoogleRuntimeConfiguration.isConfigured == false`.
All three sub-bundles share the same auth surfaces (`AuthHubView`, `SignInService`,
`AuthManager`) and the same `auth_*` analytics taxonomy. One PR, one smoke run.

---

## What to Build

### Screen Inventory

| Screen | File path | Presentation | Sub-bundle |
|---|---|---|---|
| `ForgotPasswordRequestView` | `FitTracker/Views/Auth/ForgotPasswordRequestView.swift` | `.sheet` from `EmailLoginView`, `.large` detent | A |
| `ForgotPasswordCooldownView` | `FitTracker/Views/Auth/ForgotPasswordCooldownView.swift` | Push within sheet's `NavigationStack` | A |
| `SetNewPasswordView` | `FitTracker/Views/Auth/SetNewPasswordView.swift` | Full-screen push from `RootView.onOpenURL` | A |
| `BiometricActivationSheet` | `FitTracker/Views/Auth/BiometricActivationSheet.swift` | `.sheet` from `RootView`, `.medium` detent | B |
| `BiometricUnlockView` | `FitTracker/Views/Auth/BiometricUnlockView.swift` | `.fullScreenCover` from `RootView` | B |
| `AuthHubView` (modify) | `FitTracker/Views/Auth/AuthHubView.swift` | — | B + C |

### Sub-bundle A: Forgot Password (3 screens)

**Step 1: Extract shared auth components (prerequisite)**

`AuthScaffold`, `AuthFormCard`, `AuthPrimaryButtonStyle`, `AuthBannerView`,
`PasswordRulesSecureField`, and `PasswordRulesTooltip` are currently private types in
`AuthHubView.swift`. Extract them to:

```
FitTracker/Views/Auth/AuthSharedComponents.swift
```

Make them `internal` (not `private`). This is required before building any new auth screen.

**ForgotPasswordRequestView wireframe:**

```
┌────────────────────────────┐
│  ← Back                    │   AppText.body, AppColor.Accent.primary
│  [FitMeBrandIcon 32pt]     │   decorative, accessibilityHidden: true
│  Forgot password?          │   AppText.pageTitle, inversePrimary
│  Enter your email...       │   AppText.bodyRegular, inverseSecondary
│  ┌──────────────────────┐  │
│  │  your@email.com      │  │   AuthFormCard + email TextField
│  └──────────────────────┘  │   .emailAddress content type
│  [AuthBannerView error]    │   conditional
│        (spacer)            │
│  ┌──────────────────────┐  │
│  │  Send reset link     │  │   AuthPrimaryButtonStyle, 52pt, disabled if empty
│  └──────────────────────┘  │
└────────────────────────────┘   AppGradient.authBackground
```

Key behaviors:
- Email field pre-filled from calling view's `$email` binding
- CTA disabled while email is empty or fails basic format check (`contains("@")` minimum)
- On tap: button enters loading state → `SignInService.requestPasswordReset(email:, redirectTo: "fitme://reset-password")` → on success: push to `ForgotPasswordCooldownView` + fire `auth_password_reset_requested`
- On error: `AuthBannerView` slides in with "Couldn't send reset email. Check your connection and try again."
- Analytics `.analyticsScreen("forgot_password")` on `.onAppear`

**ForgotPasswordCooldownView wireframe:**

```
┌────────────────────────────┐
│  ← Back                    │
│       ✓                    │   checkmark.circle.fill, AppColor.Status.success, 28pt
│   Check your inbox         │   AppText.titleMedium, inversePrimary
│  We sent a link to         │   AppText.body, inverseSecondary
│  user@example.com          │   AppText.subheading, bold — dynamic
│  ┌──────────────────────┐  │
│  │  Resend email (42s)  │  │   AppButton.secondary — DISABLED during cooldown
│  └──────────────────────┘  │   label: "Resend email" when active
│  Use a different email     │   AppButton.tertiary — always active (pops navigation)
└────────────────────────────┘   AppGradient.authBackground
```

Key behaviors:
- 60-second countdown `Timer.scheduledTimer(withTimeInterval: 1, repeats: true)` stored in `@State var cooldownSeconds = 60`
- Resend button disabled while `cooldownSeconds > 0`; label is "Resend email (in \(cooldownSeconds)s)" during cooldown, "Resend email" after
- Cooldown label announces to VoiceOver as live region (`.accessibilityLiveRegion(.polite)`)
- Resend tap during cooldown (defensive guard): fires `auth_password_reset_resend_blocked`
- Resend tap after cooldown: fires `auth_password_reset_resend`, increments `attemptCount`, resets cooldown
- "Use a different email" pops the navigation stack back to `ForgotPasswordRequestView` with email field cleared
- Analytics `.analyticsScreen("email_sent_confirmation")` on `.onAppear`

**SetNewPasswordView wireframe:**

```
┌────────────────────────────┐
│  ← (back button or none)   │   Consider hiding back button (user should complete)
│  Set new password          │   AppText.pageTitle
│  ┌──────────────────────┐  │
│  │  New password   ●●●  │  │   PasswordRulesSecureField
│  ├──────────────────────┤  │   AuthFormCard
│  │  Confirm password ● │  │   PasswordRulesSecureField
│  └──────────────────────┘  │
│  Passwords don't match     │   AppColor.Status.error, AppText.caption (if mismatch)
│  Password requirements:    │   PasswordRulesTooltip (always visible)
│  ✓ 6 to 14 characters      │
│  ○ One uppercase letter    │
│  ○ One number              │
│  ○ One special character   │
│  ┌──────────────────────┐  │
│  │  Update password     │  │   AuthPrimaryButtonStyle, disabled until valid
│  └──────────────────────┘  │
└────────────────────────────┘   AppGradient.authBackground
```

Key behaviors:
- Receives active Supabase session from `RootView.onOpenURL` → `client.auth.session(from: url)`
- CTA disabled until: both fields non-empty + fields match + all 4 password rules pass
- On tap: `auth.updateUser(password: newPassword)` → on success: navigate to Home Tab + fire `auth_password_reset_completed(time_to_complete_seconds:)` + `.notification(.success)` haptic
- On error: `AuthBannerView` with appropriate message
- Token expiry error: "This reset link has expired. Request a new one." + Done button → `EmailLoginView`
- Analytics `.analyticsScreen("set_new_password")` on `.onAppear`

### Sub-bundle B: Biometric (2 surfaces)

**BiometricActivationSheet wireframe:**

```
╔══════════════════════════════╗
║     ─────── (drag indicator)║
║   [FitMeBrandIcon 36pt]     ║
║                              ║
║  Unlock FitMe with Face ID  ║   AppText.pageTitle, Text.primary
║                              ║
║  Your data stays encrypted  ║   AppText.subheading, Text.secondary
║  on this device.            ║
║                              ║
║  ┌──────────────────────┐   ║
║  │   Enable Face ID     │   ║   AppButton.primary / AuthPrimaryButtonStyle, 52pt
║  └──────────────────────┘   ║
║         Not now             ║   AppButton.tertiary, minHeight 44pt
╚══════════════════════════════╝
  AppColor.Surface.materialLight, AppRadius.authSheet (36pt)
  .medium detent
```

Key behaviors:
- Present from `RootView` when: `biometricAuth.isAvailable && !settings.requireBiometricUnlockOnReopen && !settings.hasAskedForBiometricActivation` — after any sign-in completion
- `biometricLabel` from `AuthManager.biometricLabel` (returns "Face ID" | "Touch ID" | "Optic ID")
- `.onAppear` → fire `auth_biometric_activation_offered(biometric_type:)` + set `hasAskedForBiometricActivation = true` (cannot show again regardless of outcome)
- "Enable [label]" tap → `UIImpactFeedbackGenerator(.light).impactOccurred()` → `LAContext().evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Unlock FitMe to continue")` → on success: `settings.requireBiometricUnlockOnReopen = true` + fire `auth_biometric_activated(biometric_type:, provider:)` + `.notification(.success)` + dismiss with `AppSpring.bouncy`
- "Not now" tap → fire `auth_biometric_activation_declined(biometric_type:)` + dismiss with `AppSpring.smooth` (no haptic)
- On LAContext error (within activation): inline error text below CTA, not banner — "Face ID didn't work. Try again or tap Not now."
- `interactiveDismissDisabled(false)` — user can swipe to dismiss (treated as "Not now")
- Analytics `.analyticsScreen("biometric_activation_sheet")` on `.onAppear`

**BiometricUnlockView wireframe:**

```
┌──────────────────────────────┐
│  (AppGradient.authBackground) │
│                              │
│     [FitMeBrandIcon 48pt]    │   accessibilityHidden: true
│                              │
│   Welcome back, {firstName}  │   AppText.hero, inversePrimary
│                              │
│           👁  (88pt)          │   face.id or touchid SF Symbol
│    (AppColor.Accent.secondary)│   Font.system(size: 88, weight: .regular)
│                              │   DS-exception comment required
│  ┌──────────────────────┐    │
│  │ Unlock with Face ID  │    │   AuthPrimaryButtonStyle, 52pt, full-width
│  └──────────────────────┘    │
│   Use password instead       │   AppButton.tertiary, minHeight 44pt
│   [AuthBannerView error]     │   conditional
└──────────────────────────────┘
  .fullScreenCover presentation
```

Key behaviors:
- Present from `RootView` when: `signIn.hasStoredSession && settings.requireBiometricUnlockOnReopen && biometricAuth.isAvailable`
- `firstName` from stored session user metadata (or `"you"` as fallback)
- "Unlock" tap → `UIImpactFeedbackGenerator(.medium).impactOccurred()` → `LAContext().evaluatePolicy` → on success: record `startTime` to `endTime` duration → fire `auth_biometric_unlock_completed(biometric_type:, duration_ms:)` + `.notification(.success)` + dismiss
- On LAContext error: `AuthBannerView` "Face ID didn't work. Use your password instead." + fire `auth_biometric_unlock_failed(biometric_type:, reason:)`. Map `LAError` codes to reason strings: `.userCancel → "user_cancel"`, `.authenticationFailed → "biometry_failed"`, `.biometryLockout → "biometry_lockout"`, `.systemCancel → "system_cancel"`, `.passcodeNotSet → "passcode_not_set"`
- `LAError.biometryLockout`: redirect user to passcode entry via `LAContext().evaluatePolicy(.deviceOwnerAuthentication, ...)`
- "Use password" tap → navigate to `EmailLoginView` with email pre-filled from `signIn.storedSessionEmail`
- `interactiveDismissDisabled(true)` — user cannot swipe-dismiss the unlock screen
- Analytics `.analyticsScreen("biometric_unlock")` on `.onAppear`

### Sub-bundle C: Google Sign-In (no new UI screens)

1. `GoogleRuntimeConfiguration.isConfigured` must return `true` once `GIDClientID` is present in Info.plist AND `GoogleService-Info.plist` is bundled.
2. `AuthHubView.swift` lines 635 and 825: replace `ColorAppColor.Status.error` → `AppColor.Status.error` and `ColorAppColor.Brand.secondary` → `AppColor.Brand.secondary`.
3. No new UI work — the existing `GoogleProviderRow` auto-renders when `isConfigured` is true.

---

## UX Principles Applied

*(Verbatim from ux-spec.md Section 9.2)*

| Principle | How honored |
|---|---|
| 1.1 Fitts's Law | Primary CTAs are full-width, 52pt (`AppSize.ctaHeight`). Secondary actions visually subordinate. Biometric CTA is the dominant single target on BiometricUnlockView. |
| 1.2 Hick's Law | ≤3 active choices per screen. Resend CTA disabled during cooldown (visually 1 live choice). BiometricActivationSheet offers exactly 2 choices (Enable / Not now). |
| 1.3 Jakob's Law | Sheet presentations, push navigation, deep-link patterns, biometric activation, and Google Sign-In all follow iOS conventions and match Strava/Whoop/banking patterns. |
| 1.4 Progressive Disclosure | Reset flow is 3 sequential screens. Password rules shown only on SetNewPasswordView. Activation details handled by iOS LAContext natively. |
| 1.5 Recognition Over Recall | Email pre-filled. Sent-to email shown verbatim. Biometric type shown by name and icon. "Welcome back, {name}" confirms identity. |
| 1.6 Consistency | All screens reuse existing `Auth*` component family. No new patterns invented. |
| 1.7 Feedback | Every CTA enters loading state on press (<100ms). Success/error haptics defined for every outcome. Cooldown timer updates in real time. |
| 1.8 Error Prevention | CTA disabled until validation passes. Inline mismatch error while typing. Privacy-preserving reset response. One-shot biometric activation. |
| 1.9 Readiness-First | N/A — auth surface is a prerequisite gate, not a content surface. |
| 1.10 Zero-Friction Logging | Biometric unlock is 2 steps (tap + scan). Email pre-filled. Password rules visible inline. |
| 1.11 Privacy by Default | No account enumeration. Analytics fire `email_provided: Bool`. Biometric sheet shows "Your data stays encrypted on this device." |
| 1.12 Progressive Profiling | Biometric activation is one-shot. `hasAskedForBiometricActivation` ensures never re-prompts. "Not now" respected permanently. |
| 1.13 Celebration Not Guilt | Positive framing on all success states. "Not now" treated as valid choice — no follow-up. |

---

## State Coverage Matrix

| Screen | Default | Loading | Empty | Error | Success |
|---|---|---|---|---|---|
| ForgotPasswordRequestView | Email field + CTA (disabled) | CTA loading spinner | CTA disabled | AuthBannerView: "Couldn't send" | Push to cooldown view |
| ForgotPasswordCooldownView | Sent confirmation + countdown | Resend loading | N/A | AuthBannerView: "Couldn't resend" | Cooldown resets; label updates |
| SetNewPasswordView | Two fields + rules + CTA (disabled) | CTA loading spinner | CTA disabled | Inline mismatch + AuthBannerView | Push to Home Tab |
| BiometricActivationSheet | Brand icon + headline + 2 CTAs | CTA loading → system Face ID | N/A | Inline error "Face ID didn't work" | Bouncy dismiss |
| BiometricUnlockView | Brand + welcome + biometric icon + CTA | CTA loading → system Face ID | N/A | AuthBannerView: "{label} failed" | Cover dismisses → Home |

---

## Accessibility Requirements

### VoiceOver Labels — Critical Subset

**ForgotPasswordRequestView:**
- Email field: `accessibilityLabel("Email address")` `accessibilityHint("Enter the email associated with your FitMe account")`
- CTA (active): `accessibilityLabel("Send reset link")` `accessibilityHint("Sends a password reset link to your email address")`
- CTA (disabled): `accessibilityLabel("Send reset link, enter an email to continue")`

**ForgotPasswordCooldownView:**
- Sent-to copy: `accessibilityLabel("We sent a link to \(email)")` (dynamic, email included)
- Resend (cooldown): `accessibilityLabel("Resend reset email, available in \(seconds) seconds")` + `.isNotEnabled` trait
- Resend (active): `accessibilityLabel("Resend reset email")` `accessibilityHint("Sends a new password reset link")`
- Countdown display: `accessibilityLiveRegion(.polite)` for timer updates

**SetNewPasswordView:**
- New password field: `accessibilityLabel("New password")` `accessibilityHint("Must be 6 to 14 characters with at least one uppercase letter, one number, and one special character")`
- Each rule: `accessibilityLabel("Rule description")` + `accessibilityValue(satisfied ? "met" : "not met")`
- Mismatch error: `accessibilityLiveRegion(.assertive)` — announced immediately

**BiometricActivationSheet:**
- Brand icon: `accessibilityHidden(true)`
- CTA: `accessibilityLabel("Enable \(biometricLabel)")` `accessibilityHint("Activates biometric unlock for future app launches")`
- "Not now": `accessibilityLabel("Not now")` `accessibilityHint("Skips biometric setup. You can enable it later in Settings")`

**BiometricUnlockView:**
- Biometric icon: `accessibilityHidden(true)` (decorative — CTA label conveys action)
- CTA: `accessibilityLabel("Unlock with \(biometricLabel)")` `accessibilityHint("Authenticates using your device's biometric sensor")`
- "Use password": `accessibilityLabel("Use password instead")` `accessibilityHint("Signs you in with your email and password")`
- Error banner: `accessibilityLiveRegion(.assertive)`

**Full label list (43 total):** See ux-spec.md §6.1.

### Dynamic Type Rules

- All `AppText.*` tokens are Dynamic Type-compatible
- AX5 requirement: test at largest accessibility size before Phase 5 approval
- `ForgotPasswordCooldownView` email display: `.lineLimit(nil)` to prevent truncation at AX5
- `PasswordRulesTooltip`: `VStack` at AX5 (not `HStack`)
- `BiometricActivationSheet` assurance copy: `.fixedSize(horizontal: false, vertical: true)`
- `BiometricUnlockView` hero name: `.lineLimit(2)` + `.minimumScaleFactor(0.8)` fallback

### Tap Target Sizes (all elements)

- All primary CTAs: `AppSize.ctaHeight` (52pt) — inherits from `AuthPrimaryButtonStyle`
- Text links ("Use password", "Not now", "Use a different email"): `.contentShape(Rectangle()).frame(minHeight: 44)` required
- Biometric SF Symbol icon: non-interactive, `accessibilityHidden(true)`

### Reduce Motion

Apply `.motionSafe()` modifier (from `AppMotion.swift`) on every animation. Alternatives:
- Sheet present/dismiss: instant crossfade (`.easeOut(duration: 0.01)`)
- Icon scale pulse on biometric CTA tap: no animation, static
- AuthBannerView slide: immediate visibility at final position

---

## Haptic Taxonomy

| Moment | Generator | Style |
|---|---|---|
| Any CTA button press | `UIImpactFeedbackGenerator` | `.light` |
| Email send success | `UINotificationFeedbackGenerator` | `.success` |
| Biometric CTA tap (initiate scan) | `UIImpactFeedbackGenerator` | `.medium` |
| Biometric activation success | `UINotificationFeedbackGenerator` | `.success` |
| Biometric unlock success | `UINotificationFeedbackGenerator` | `.success` |
| Biometric failure | `UINotificationFeedbackGenerator` | `.error` |
| Password update success | `UINotificationFeedbackGenerator` | `.success` |
| Resend during cooldown | `UINotificationFeedbackGenerator` | `.warning` |

---

## Handoff Checklist

**Implementer must produce and return:**

- [ ] `FitTracker/Views/Auth/AuthSharedComponents.swift` — extracted shared auth components (prerequisite for all other screens)
- [ ] `FitTracker/Views/Auth/ForgotPasswordRequestView.swift`
- [ ] `FitTracker/Views/Auth/ForgotPasswordCooldownView.swift`
- [ ] `FitTracker/Views/Auth/SetNewPasswordView.swift`
- [ ] `FitTracker/Views/Auth/BiometricActivationSheet.swift`
- [ ] `FitTracker/Views/Auth/BiometricUnlockView.swift`
- [ ] `FitTracker/Views/Auth/AuthHubView.swift` (modified — typo fix + biometric gate + Google row enable)
- [ ] `FitTracker/FitTrackerApp.swift` (modified — `.onOpenURL` handler for `fitme://reset-password`)
- [ ] `FitTracker/Services/AppSettings.swift` (modified — `hasAskedForBiometricActivation` property)
- [ ] `FitTracker/Services/Analytics/AnalyticsProvider.swift` (modified — 9 new events, 6 params, 5 screens)
- [ ] `FitTracker.xcodeproj/project.pbxproj` (modified — new files + SPM dependency on `GoogleSignIn-iOS@8.x`)
- [ ] `FitTracker/Info.plist` (modified — `fitme://` URL scheme + GoogleSignIn reverse-DNS scheme + `GIDClientID` + `NSFaceIDUsageDescription`)
- [ ] `docs/product/analytics-taxonomy.csv` (modified — 9 event rows + 6 param rows + 5 screen rows)
- [ ] `FitTrackerTests/Auth/AuthPolishV2Tests.swift` (new — PRD test suite)
- [ ] `FitTrackerUITests/Auth/AuthPolishV2UITests.swift` (new — UI snapshot tests for 5 screens)
- [ ] `FitTrackerTests/Auth/AnalyticsEventNamingTests.swift` (new — naming convention tests)

**Pre-merge verification:**
- [ ] `xcodebuild build` clean on iOS Simulator
- [ ] `xcodebuild test` — all new tests passing
- [ ] `make tokens-check` clean
- [ ] `make runtime-smoke PROFILE=sign_in_surface MODE=local` passing
- [ ] Manual test at AX5 Dynamic Type — no truncation on any screen
- [ ] Manual test with Reduce Motion enabled — all animations degrade gracefully
- [ ] Manual test with VoiceOver — all 43 labeled elements navigable
- [ ] `ColorAppColor` typos in `AuthHubView.swift:635` and `:825` repaired to `AppColor.*`

---

## References

- **UX research:** `.claude/features/auth-polish-v2/ux-research.md`
  - §2 Apple HIG Audit (sheets, deep-link return, biometric auth, Sign In with Services)
  - §3 Competitive UX Analysis (Strava, Whoop, MyFitnessPal, Hevy, Strong, banking)
  - §7 Compliance Gateway Pre-Check (5/5 pass)
- **UX spec:** `.claude/features/auth-polish-v2/ux-spec.md`
  - §4 Token Catalogue (all tokens with line references to AppTheme.swift)
  - §6 Accessibility Requirements (43 VoiceOver labels, AX5 rules)
  - §7 Motion & Animation (all spring/easing/haptic tokens)
  - §9 Principle Application Table (12 pass / 1 N/A)
- **UX Foundations:** `docs/design-system/ux-foundations.md`
  - Part 1.1–1.13 (all 13 principles)
  - Part 2.5 Modal vs Push navigation (§2.5)
  - Part 3.3 Feedback Patterns — haptic taxonomy (§3.3)
  - Part 5 Permission & Trust Patterns — biometric activation (§5.1–5.2)
  - Part 6 State Patterns — 5-state coverage (§6.1–6.5)
  - Part 7 Accessibility Standards — tap targets, Dynamic Type, contrast (§7.1–7.2)
  - Part 8 Micro-Interactions & Motion — spring tokens, reduce motion (§8)
- **Design System:**
  - `FitTracker/Services/AppTheme.swift` (tokens)
  - `FitTracker/DesignSystem/AppComponents.swift` (atomic components)
  - `FitTracker/Views/Shared/AppDesignSystemComponents.swift` (composite components)
  - `FitTracker/DesignSystem/AppMotion.swift` (motion tokens)
- **PRD:** `.claude/features/auth-polish-v2/prd.md`
  - §Functional Requirements FR-1 through FR-18
  - §User Flows A–H
  - §Analytics Spec (9 events, 6 params, 5 screens)
  - §Appendix C (out-of-code launch checklist)
- **V2 Refactor Checklist:** `docs/design-system/v2-refactor-checklist.md`
  - Sections A, E, F, G, H (UX-phase responsibilities)

---

*End of UX build prompt for auth-polish-v2 — target agent: SwiftUI Phase 4 implementer*
