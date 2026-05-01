# UX Spec: auth-polish-v2

> **Phase:** 3 (UX)
> **Date authored:** 2026-04-28
> **Author:** /ux agent
> **Feature:** auth-polish-v2
> **Work subtype:** new_ui (5 new screens, 2 modified existing screens)
> **Framework version:** v7.6 PM Workflow
> **GitHub Issue:** #143
> **Branch:** `feature/auth-polish-v2`
>
> **Input documents:**
> - `.claude/features/auth-polish-v2/prd.md` (473 lines, approved)
> - `.claude/features/auth-polish-v2/research.md` (234 lines, approved)
> - `.claude/features/auth-polish-v2/ux-research.md` (companion analysis, this phase)
> - `docs/design-system/ux-foundations.md` (13 principles)
> - `FitTracker/Services/AppTheme.swift` (token definitions)
> - `FitTracker/DesignSystem/AppComponents.swift` (atomic components)
> - `FitTracker/Views/Shared/AppDesignSystemComponents.swift` (composite components)
>
> **Compliance gateway:** 5/5 PASS (see §9)
> **Heuristic validation:** 12/13 principles pass; 1 N/A (see §9)

---

## Section 1 — Overview & Scope

### Feature Summary

auth-polish-v2 closes three auth surface gaps in a single coordinated release:

1. **Sub-bundle A — Forgot-password recovery flow** (3 new screens): A dedicated
   request screen, email-sent confirmation with 60s cooldown, and a set-new-password
   screen reachable via deep-link return from the password-reset email.

2. **Sub-bundle B — Biometric refinement** (2 new surfaces): A full-screen biometric
   unlock view that replaces the auth hub when conditions are met, and a one-time
   post-sign-in activation sheet that converts willing users to biometric-first unlock.

3. **Sub-bundle C — Google Sign-In activation** (no new UI): `GoogleRuntimeConfiguration.isConfigured`
   flips to `true` once the SDK + Info.plist + URL scheme land. Existing `GoogleProviderRow`
   renders automatically in `AuthHubView` and `OnboardingAuthView`.

### Work Subtype

`new_ui` — 5 new views/sheets, 2 modified existing views. No v1 to refactor against.
Files live at canonical paths (no `v2/` subdirectory required by CLAUDE.md V2 Rule).

### In Scope

| Item | Type | Sub-bundle |
|---|---|---|
| `ForgotPasswordRequestView` | New screen | A |
| `ForgotPasswordCooldownView` | New screen | A |
| `SetNewPasswordView` | New screen | A |
| `BiometricActivationSheet` | New sheet | B |
| `BiometricUnlockView` | New screen | B |
| `AuthHubView` | Modified | B + C |
| `OnboardingAuthView` | Modified (minor, auto-renders Google row) | C |

### Deferred

| Item | Reason |
|---|---|
| Apple Sign In Services-ID configuration | Requires Apple Developer console action; out-of-repo scope |
| Smart reminder management UI | Different feature (`smart-reminders-ui` enhancement) |
| Sentry MCP integration | Gate C peer; unrelated to auth code path |
| Apple Watch / iPad-specific layouts | Backlog Icebox |

### Estimated Phase 3 Effort

2 days for UX spec authoring + compliance gateway + build prompt.
Phase 4 implementation estimate: 6 days (Forgot-pw 2d + Biometric 2.5d + Google 1.5d).

---

## Section 2 — Screen Inventory & Stack Order

### 2.1 Navigation Map

```
EmailLoginView
  └─ (sheet) ─→ ForgotPasswordRequestView
                  └─ (push within sheet) ─→ ForgotPasswordCooldownView
                                              └─ "Use a different email" ─→ back to ForgotPasswordRequestView

RootView (onOpenURL: fitme://reset-password)
  └─ (push) ─→ SetNewPasswordView
                └─ success ─→ Home Tab

RootView (post sign-in, trigger condition true)
  └─ (sheet) ─→ BiometricActivationSheet
                └─ success or dismiss ─→ Home Tab

RootView (stored session + require biometric)
  └─ (fullScreenCover) ─→ BiometricUnlockView
                            ├─ success ─→ Home Tab
                            └─ "Use password" ─→ EmailLoginView (email pre-filled)
```

### 2.2 Screen Presentations

| Screen | Presentation | Detent | Navigation type |
|---|---|---|---|
| `ForgotPasswordRequestView` | `.sheet(isPresented:)` from EmailLoginView | `.large` (keyboard + form) | Initial view in `NavigationStack` inside sheet |
| `ForgotPasswordCooldownView` | `NavigationLink` push within the sheet's `NavigationStack` | (inherits sheet) | Push within sheet |
| `SetNewPasswordView` | `NavigationLink` or programmatic push from `RootView` | Full-screen push | Push on `NavigationStack` at root |
| `BiometricActivationSheet` | `.sheet(isPresented:)` from `RootView` | `.medium` (compact offering) | No navigation stack needed — single-view sheet |
| `BiometricUnlockView` | `.fullScreenCover(isPresented:)` from `RootView` | Full-screen | No navigation stack — single-view cover |

**Decision flag for Phase 4 implementer:** `ForgotPasswordCooldownView` is specified as a
push within the sheet's `NavigationStack` (not a new sheet on top of the first sheet). This
keeps the sheet presentation clean and allows the user to go back to change the email address.
If the `NavigationStack`-inside-sheet pattern causes iOS 16/17 layout issues with the keyboard,
the implementer may choose to present the entire forgot-password flow as a `NavigationStack`
inside a single `.sheet`, with `ForgotPasswordRequestView` and `ForgotPasswordCooldownView`
both as views in that stack.

---

## Section 3 — Component Catalogue

### 3.1 Reused Components (existing)

All from `FitTracker/Views/Auth/AuthHubView.swift` (private types — Phase 4 must extract
to `FitTracker/Views/Auth/AuthSharedComponents.swift`):

| Component | Type | Used in |
|---|---|---|
| `AuthScaffold` | Screen container with gradient background + scroll | ForgotPasswordRequestView, ForgotPasswordCooldownView, SetNewPasswordView, BiometricUnlockView |
| `AuthFormCard` | Rounded-corner card container for form fields | ForgotPasswordRequestView (email field), SetNewPasswordView (password fields) |
| `AuthPrimaryButtonStyle` | ButtonStyle for auth primary CTA buttons | All primary CTAs in new screens |
| `AuthBannerView` | Inline error/info banner (slides in from top) | ForgotPasswordRequestView (email error), ForgotPasswordCooldownView (resend error), SetNewPasswordView (pw rules error, mismatch), BiometricUnlockView (failure) |
| `PasswordRulesSecureField` | Secure text field with UITextInputPasswordRules | SetNewPasswordView |
| `PasswordRulesTooltip` | Inline collapsible password-rules display | SetNewPasswordView |

From `FitTracker/DesignSystem/AppComponents.swift`:

| Component | Used in |
|---|---|
| `AppSheetShell` | BiometricActivationSheet (sheet container with drag indicator) |

From `FitTracker/Views/Shared/AppDesignSystemComponents.swift`:

| Component | Used in |
|---|---|
| `AppButton` (.primary) | ForgotPasswordRequestView "Send reset link" CTA (alternative to AuthPrimaryButtonStyle if extracted) |
| `AppButton` (.tertiary) | BiometricActivationSheet "Not now" CTA |
| `AppCard` (.standard) | ForgotPasswordCooldownView confirmation card |

From `FitTracker/DesignSystem/`:

| Component | Used in |
|---|---|
| `FitMeBrandIcon` | BiometricUnlockView (brand icon top), BiometricActivationSheet (brand icon top of sheet) |
| `FitMeLogoLoader` | BiometricUnlockView (during biometric evaluation loading state) |

### 3.2 New Components

**None.** All patterns are served by existing components. No new components need to be
added to the design system for auth-polish-v2.

**Phase 4 extraction task (not a new component, a housekeeping task):**
Extract `AuthScaffold`, `AuthFormCard`, `AuthPrimaryButtonStyle`, `AuthBannerView`,
`PasswordRulesSecureField`, and `PasswordRulesTooltip` from their current private scope
in `AuthHubView.swift` to `FitTracker/Views/Auth/AuthSharedComponents.swift`.
This file is `internal` (not `private`) so all 5 new screens can import it.

---

## Section 4 — Token Catalogue

All tokens used in new screens, drawn exclusively from `FitTracker/Services/AppTheme.swift`.

### 4.1 Color Tokens

| Token | Value | Used in |
|---|---|---|
| `AppColor.Background.authTop` | `Color("bg-auth-top")` | BiometricUnlockView gradient top |
| `AppColor.Background.authMiddle` | `Color("bg-auth-middle")` | BiometricUnlockView gradient middle |
| `AppColor.Background.authBottom` | `Color("bg-auth-bottom")` | BiometricUnlockView gradient bottom |
| `AppGradient.authBackground` | linearGradient (authTop → authMiddle → authBottom) | BiometricUnlockView + ForgotPasswordRequestView scaffold background |
| `AppColor.Accent.primary` | `Color("brand-primary")` — orange | All primary CTA fill backgrounds |
| `AppColor.Accent.secondary` | `Color("brand-secondary")` — blue | Biometric icon tint, links |
| `AppColor.Status.success` | `Color("status-success")` — green | Success state checkmark, password rule satisfied indicators |
| `AppColor.Status.error` | `Color("status-error")` — red | Inline error text, unsatisfied password rule indicators |
| `AppColor.Status.warning` | `Color("status-warning")` — amber | AuthBannerView warning tone |
| `AppColor.Text.primary` | `Color("text-primary")` | All body/heading text |
| `AppColor.Text.secondary` | `Color("text-secondary")` | Supporting copy, captions |
| `AppColor.Text.tertiary` | `Color("text-tertiary")` | Hint text, cooldown explanation copy |
| `AppColor.Text.inversePrimary` | `Color("text-inverse-primary")` | Text on primary CTA buttons |
| `AppColor.Surface.elevated` | `Color("surface-elevated")` | AuthFormCard background |
| `AppColor.Surface.materialLight` | `Color("surface-material-light")` | Sheet surface behind content |
| `AppColor.Border.subtle` | `Color("border-subtle")` | Form field dividers |

### 4.2 Typography Tokens

| Token | Font | Used in |
|---|---|---|
| `AppText.hero` | largeTitle, rounded, bold | BiometricUnlockView "Welcome back, {name}" |
| `AppText.pageTitle` | title2, rounded, bold | ForgotPasswordRequestView headline, BiometricActivationSheet headline |
| `AppText.titleMedium` | title3, rounded, semibold | ForgotPasswordCooldownView "Check your inbox" |
| `AppText.body` | body, rounded, medium | Form labels, instruction copy |
| `AppText.bodyRegular` | body, rounded | Secondary body copy |
| `AppText.subheading` | subheadline, rounded | Assurance copy in BiometricActivationSheet, email display in cooldown view |
| `AppText.caption` | caption, rounded | Password rules tooltip items, cooldown countdown |
| `AppText.captionStrong` | caption, rounded, semibold | Password rule label text |
| `AppText.button` | body, rounded, semibold | All CTA button labels |
| `AppText.iconLarge` | 48pt, medium | Biometric icon in BiometricActivationSheet |
| `AppText.iconDisplay` | 72pt, regular | Biometric SF Symbol icon in BiometricUnlockView (88pt specified in PRD FR-8 — use `Font.system(size: 88)` as a justified one-off fixed size for this hero icon) |
| `AppText.iconMedium` | 28pt, medium | Checkmark icon in ForgotPasswordCooldownView |

**Note on 88pt biometric icon:** PRD FR-8 specifies 88pt for the biometric icon in
`BiometricUnlockView`. The closest existing token is `AppText.iconDisplay` (72pt).
88pt is a justified fixed size for this hero authentication moment (banking-app standard
for biometric icons). Use `Font.system(size: 88, weight: .regular)` with an inline
`// DS-exception: 88pt hero biometric icon per PRD FR-8; banking-app standard, no
// scaling needed as this is an SF Symbol glyph not text` comment.

### 4.3 Spacing Tokens

| Token | Value | Used in |
|---|---|---|
| `AppSpacing.xxSmall` | 8pt | Tight element pairs (icon + label, rule item rows) |
| `AppSpacing.xSmall` | 12pt | Between form card and CTA |
| `AppSpacing.small` | 16pt | Standard horizontal padding, form field internal padding |
| `AppSpacing.medium` | 20pt | Card internal padding, between sections |
| `AppSpacing.large` | 24pt | Between major layout sections |
| `AppSpacing.xLarge` | 32pt | Top inset for form cards from screen top |
| `AppSpacing.xxLarge` | 40pt | Bottom safe-area padding above CTA |

### 4.4 Radius Tokens

| Token | Value | Used in |
|---|---|---|
| `AppRadius.authSheet` | 36pt | Sheet containers (BiometricActivationSheet shell) |
| `AppRadius.button` | 20pt | Form card container radius |
| `AppRadius.large` | 24pt | AppCard containers (ForgotPasswordCooldownView confirmation card) |

### 4.5 Motion Tokens

| Token | Used for |
|---|---|
| `AppSpring.smooth` | Sheet present/dismiss transitions (ForgotPasswordRequestView, BiometricActivationSheet) |
| `AppSpring.snappy` | Biometric icon scale response when CTA is tapped |
| `AppSpring.bouncy` | Biometric activation success confirmation animation |
| `AppSpring.stiff` | BiometricUnlockView fullScreenCover dismiss transition |
| `AppDuration.standard` | Screen push transitions (300ms) |
| `AppDuration.short` | AuthBannerView slide-in/out (200ms) |
| `AppDuration.instant` | Button press opacity feedback (100ms) |
| `AppLoadingAnimation.confirmPulse` | FitMeLogoLoader pulse on biometric success |

### 4.6 Size Tokens

| Token | Value | Used in |
|---|---|---|
| `AppSize.ctaHeight` | 52pt | All primary CTA button heights |
| `AppSize.touchTargetLarge` | 48pt | "Use password" tap target expansion |

### 4.7 DS-Evolution Proposals

**None.** auth-polish-v2 requires no new design tokens.

---

## Section 5 — State Coverage

### 5.1 ForgotPasswordRequestView

| State | What user sees | Component handling |
|---|---|---|
| **Default** | AuthScaffold with gradient background. "Forgot password?" headline (AppText.pageTitle). "Enter your email and we'll send a reset link." body copy. AuthFormCard with email TextField pre-filled. "Send reset link" primary CTA (disabled if email empty/invalid). "Back" tertiary link top-left. | AuthScaffold + AuthFormCard + AuthPrimaryButtonStyle |
| **Loading** | "Send reset link" button label replaced by inline spinner. Button remains tappable region size but not re-tappable (debounced). | Button loading state modifier |
| **Empty** | CTA is disabled. Email field placeholder "your@email.com" visible. No error banner — CTA disable alone prevents confusion. | AuthFormCard disabled state |
| **Error** | AuthBannerView slides in from below the form card: "Couldn't send reset email. Check your connection and try again." [Retry] | AuthBannerView |
| **Success** | Push to ForgotPasswordCooldownView via NavigationLink. No success state on this view — success = navigation. | NavigationLink trigger |

### 5.2 ForgotPasswordCooldownView

| State | What user sees | Component handling |
|---|---|---|
| **Default** | AuthScaffold. Checkmark SF Symbol (green, AppText.iconMedium). "Check your inbox" headline (AppText.titleMedium). "We sent a link to **{email}**." body. Two secondary actions: "Resend email (in {N}s)" (disabled during cooldown) + "Use a different email" (always enabled, pops navigation). | AuthScaffold + AppCard |
| **Loading** | "Resend email" button enters loading state when tapped (after cooldown expires). Spinner replaces label. | Button loading modifier |
| **Empty** | N/A — screen always has the email pre-filled. |  |
| **Error** | AuthBannerView: "Couldn't resend the email. Try again in a moment." | AuthBannerView |
| **Success (resend)** | Button re-enters cooldown: label resets to "Resend email (in 60s)". Light haptic `.impact(.light)`. No new screen — stays in place. | Countdown timer state |
| **Cooldown expired** | "Resend email" button becomes active (full opacity, AppColor.Accent.secondary tint) | Timer-driven state update |

### 5.3 SetNewPasswordView

| State | What user sees | Component handling |
|---|---|---|
| **Default** | Full-screen push (outside sheet, from RootView). AuthScaffold. "Set new password" headline. AuthFormCard with two PasswordRulesSecureField (new password + confirm). PasswordRulesTooltip always visible below fields. "Update password" primary CTA (disabled until rules pass + fields match). | AuthScaffold + AuthFormCard + PasswordRulesSecureField + PasswordRulesTooltip |
| **Loading** | "Update password" CTA enters loading state. FitMeLogoLoader `.breathe` replaces button label for operations > 500ms. | Button loading state |
| **Empty** | CTA is disabled. PasswordRulesTooltip shows all rules in neutral state (not red, not green). | PasswordRulesTooltip default |
| **Error — mismatch** | Inline text below confirm field: "Passwords don't match" in AppColor.Status.error. CTA disabled. | Inline error (not banner) |
| **Error — rules not met** | PasswordRulesTooltip shows unsatisfied rules in AppColor.Status.error. CTA disabled. | PasswordRulesTooltip error state |
| **Error — network** | AuthBannerView: "Couldn't update your password. Check your connection and try again." | AuthBannerView |
| **Error — expired token** | AuthBannerView: "This reset link has expired. Request a new one from the sign-in screen." [Done] — tapping Done navigates to EmailLoginView. | AuthBannerView + navigation |
| **Success** | View dismisses / navigation pops. App navigates to Home Tab. `.notification(.success)` haptic. No on-screen success state — the Home Tab appearance IS the success. | Navigation completion |

### 5.4 BiometricActivationSheet

| State | What user sees | Component handling |
|---|---|---|
| **Default** | AppSheetShell (.medium detent). Drag indicator. FitMeBrandIcon (small, 36pt). "Unlock {AppBrand.name} with {biometricLabel}" headline (AppText.pageTitle). "Your data stays encrypted on this device." assurance copy (AppText.subheading). "Enable {biometricLabel}" primary CTA. "Not now" tertiary link below. | AppSheetShell + FitMeBrandIcon + AppButton |
| **Loading** | "Enable {biometricLabel}" CTA enters loading state after user taps. iOS Face ID dialog appears on top (system-managed). | Button loading state (brief, system dialog takes over) |
| **Empty** | N/A — sheet only appears when biometricAuth.isAvailable is true. | |
| **Error — biometric failed** | Sheet remains visible. AuthBannerView (or inline text below CTA): "Face ID didn't work. Try again or tap 'Not now'." | AuthBannerView in sheet |
| **Error — biometric unavailable** | Sheet should not appear (trigger condition includes `biometricAuth.isAvailable`). If LAContext returns unavailable error, dismiss sheet silently and set both flags. | Defensive in trigger logic |
| **Success** | `.notification(.success)` haptic. Sheet dismisses with `AppSpring.bouncy`. | Sheet dismiss + haptic |
| **Declined ("Not now")** | Sheet dismisses with `AppSpring.smooth`. No haptic (neutral action). | Sheet dismiss |

### 5.5 BiometricUnlockView

| State | What user sees | Component handling |
|---|---|---|
| **Default** | Full-screen cover (`.fullScreenCover`). AppGradient.authBackground fills screen. FitMeBrandIcon centered top third. "Welcome back, {firstName}" (AppText.hero, AppColor.Text.inversePrimary). Large biometric SF Symbol (88pt, AppColor.Accent.secondary). "Unlock with {biometricLabel}" primary CTA (full-width, AppSize.ctaHeight). "Use password" tertiary link at bottom. | AuthScaffold (fullscreen) + FitMeBrandIcon + AuthPrimaryButtonStyle |
| **Loading** | "Unlock with {biometricLabel}" CTA enters loading state. FitMeLogoLoader `.breathe` overlays or replaces CTA label. iOS biometric dialog appears on top. | Loading state + FitMeLogoLoader |
| **Empty** | N/A — view only shown when session + setting conditions are met. | |
| **Error** | AuthBannerView slides in: "{biometricLabel} didn't work. Use your password instead." Secondary "Use password" CTA becomes more prominent (same tertiary link, but highlighted temporarily). `.notification(.error)` haptic. | AuthBannerView |
| **Locked out (LAError.biometryLockout)** | AuthBannerView: "Too many attempts. Use your device passcode to unlock." "Use password" CTA is the primary recovery path. | AuthBannerView + redirect to EmailLoginView |
| **Success** | `.notification(.success)` haptic. `.fullScreenCover` dismisses with `AppSpring.stiff` (standard iOS). Home Tab becomes visible. | Dismiss + haptic |

---

## Section 6 — Accessibility Requirements

### 6.1 VoiceOver Labels — Complete List

#### ForgotPasswordRequestView (9 labels)

1. **Back button (navigation):** `accessibilityLabel("Back")` `accessibilityHint("Returns to sign-in")`
2. **"Forgot password?" headline:** `accessibilityLabel("Forgot password")` `accessibilityAddTraits([.isHeader])`
3. **Instruction copy:** `accessibilityLabel("Enter your email and we'll send a reset link")` (static text, no hint needed)
4. **Email text field:** `accessibilityLabel("Email address")` `accessibilityHint("Enter the email associated with your FitMe account")`
5. **"Send reset link" CTA:** `accessibilityLabel("Send reset link")` `accessibilityHint("Sends a password reset link to your email address")` + disabled state: `accessibilityLabel("Send reset link, enter an email to continue")`
6. **AuthBannerView error:** `accessibilityLabel("Error: Couldn't send reset email")` `accessibilityHint("Check your connection and try again")`
7. **Retry button in banner:** `accessibilityLabel("Retry sending reset email")`
8. **Email field validation error:** `accessibilityLabel("Invalid email address")` (announced when field loses focus with invalid input)
9. **Loading state on CTA:** `accessibilityLabel("Sending reset link, please wait")`

#### ForgotPasswordCooldownView (8 labels)

10. **Back button:** `accessibilityLabel("Back")` `accessibilityHint("Returns to email entry")`
11. **Checkmark icon:** `accessibilityHidden(true)` (decorative — success is conveyed by headline)
12. **"Check your inbox" headline:** `accessibilityLabel("Check your inbox")` `accessibilityAddTraits([.isHeader])`
13. **Sent-to body copy:** `accessibilityLabel("We sent a link to \(email)")` (dynamic, email included for context)
14. **"Resend email" button (active):** `accessibilityLabel("Resend reset email")` `accessibilityHint("Sends a new password reset link")`
15. **"Resend email" button (cooldown):** `accessibilityLabel("Resend reset email, available in \(seconds) seconds")` `accessibilityTraits([.isButton, .isNotEnabled])`
16. **"Use a different email" link:** `accessibilityLabel("Use a different email address")` `accessibilityHint("Returns to email entry with a blank field")`
17. **Cooldown timer display:** `accessibilityLabel("Resend available in \(seconds) seconds")` (live region if VoiceOver is active — use `accessibilityLiveRegion: .polite`)

#### SetNewPasswordView (11 labels)

18. **"Set new password" headline:** `accessibilityLabel("Set new password")` `accessibilityAddTraits([.isHeader])`
19. **New password field:** `accessibilityLabel("New password")` `accessibilityHint("Enter your new password. Must be 6 to 14 characters with at least one uppercase letter, one number, and one special character")`
20. **Confirm password field:** `accessibilityLabel("Confirm new password")` `accessibilityHint("Re-enter your new password to confirm it matches")`
21. **PasswordRulesTooltip container:** `accessibilityLabel("Password requirements")` `accessibilityElement(children: .contain)`
22. **Individual rule — length:** `accessibilityLabel("6 to 14 characters")` + dynamic `accessibilityValue(satisfied ? "met" : "not met")`
23. **Individual rule — uppercase:** `accessibilityLabel("One uppercase letter")` + `accessibilityValue(satisfied ? "met" : "not met")`
24. **Individual rule — number:** `accessibilityLabel("One number")` + `accessibilityValue(satisfied ? "met" : "not met")`
25. **Individual rule — special:** `accessibilityLabel("One special character")` + `accessibilityValue(satisfied ? "met" : "not met")`
26. **"Update password" CTA:** `accessibilityLabel("Update password")` `accessibilityHint("Sets your new password and signs you in")`
27. **Mismatch error:** `accessibilityLabel("Passwords don't match")` (live region `.assertive` — critical inline error)
28. **Network error banner:** `accessibilityLabel("Error: Couldn't update your password")` `accessibilityHint("Check your connection and try again")`

#### BiometricActivationSheet (7 labels)

29. **Brand icon:** `accessibilityHidden(true)` (decorative in this context)
30. **Headline:** `accessibilityLabel("Unlock \(AppBrand.name) with \(biometricLabel)")` `accessibilityAddTraits([.isHeader])`
31. **Assurance copy:** `accessibilityLabel("Your data stays encrypted on this device")` (static informational text)
32. **"Enable [biometric]" CTA:** `accessibilityLabel("Enable \(biometricLabel)")` `accessibilityHint("Activates biometric unlock for future app launches")`
33. **"Not now" link:** `accessibilityLabel("Not now")` `accessibilityHint("Skips biometric setup. You can enable it later in Settings")`
34. **Error text:** `accessibilityLabel("Biometric authentication failed. Try again or tap Not now")` (live region `.assertive`)
35. **Loading state:** `accessibilityLabel("Setting up \(biometricLabel), please wait")`

#### BiometricUnlockView (8 labels)

36. **Brand icon:** `accessibilityHidden(true)` (decorative — redundant with app context)
37. **"Welcome back" headline:** `accessibilityLabel("Welcome back, \(firstName)")` `accessibilityAddTraits([.isHeader])`
38. **Biometric SF Symbol icon:** `accessibilityHidden(true)` (decorative — CTA label conveys action)
39. **"Unlock with [biometric]" CTA:** `accessibilityLabel("Unlock with \(biometricLabel)")` `accessibilityHint("Authenticates using your device's biometric sensor to open FitMe")`
40. **"Use password" link:** `accessibilityLabel("Use password instead")` `accessibilityHint("Signs you in with your email and password")`
41. **Error banner:** `accessibilityLabel("\(biometricLabel) authentication failed. Use your password instead")` (live region `.assertive`)
42. **Loading state:** `accessibilityLabel("Authenticating with \(biometricLabel), please wait")`
43. **Lock-out banner:** `accessibilityLabel("Too many failed attempts. Use your device passcode to unlock")` `accessibilityHint("Tap Use password to sign in with your credentials")`

**Total VoiceOver labels: 43.** Exceeds the 30-label minimum for this complexity level.

### 6.2 Dynamic Type

- **All text elements** use `AppText.*` tokens which resolve to `Font.system(.<style>)` — fully Dynamic Type compatible.
- **AX5 test requirement:** All 5 screens must be tested at AX5 (largest accessibility size) before Phase 5 approval. Specific concerns:
  - `ForgotPasswordCooldownView`: email address display must not truncate at AX5 — use `.lineLimit(nil)` with word-wrapping.
  - `SetNewPasswordView PasswordRulesTooltip`: 4 rule items — use `VStack` (not `HStack`) at AX5 to prevent clipping.
  - `BiometricActivationSheet`: assurance copy line must not truncate — use `.fixedSize(horizontal: false, vertical: true)`.
  - `BiometricUnlockView`: hero "Welcome back, {firstName}" must not truncate — `.lineLimit(2)` + `.minimumScaleFactor(0.8)` acceptable fallback.

### 6.3 Tap Target Sizes

| Element | Visual size | Required tap target | Enforcement |
|---|---|---|---|
| "Send reset link" CTA | Full-width, `AppSize.ctaHeight` (52pt) | 52pt ✓ | Inherits from AppButton |
| "Use a different email" link | ~18pt text | ≥44pt | `.contentShape(Rectangle()).frame(minHeight: 44)` |
| "Use password" link (BiometricUnlockView) | ~18pt text | ≥44pt | `.contentShape(Rectangle()).frame(minHeight: 44)` |
| "Not now" link (BiometricActivationSheet) | ~18pt text | ≥44pt | `.contentShape(Rectangle()).frame(minHeight: 44)` |
| Resend button | Variable text + cooldown | ≥44pt | `.frame(minHeight: 44)` |
| Biometric unlock CTA | Full-width, 52pt | 52pt ✓ | Inherits from AppButton |
| Biometric SF Symbol icon (BiometricUnlockView) | 88pt | Non-interactive — decorative | `.accessibilityHidden(true)` |

### 6.4 Reduce Motion

All animations in auth-polish-v2 use the `.motionSafe()` modifier from `AppMotion.swift`.
Specific reduce-motion alternatives:

| Animation | Full-motion | Reduce-motion alternative |
|---|---|---|
| Sheet present/dismiss (ForgotPasswordRequestView) | Spring slide-up (`AppSpring.smooth`) | Instant crossfade (`.easeOut(duration: 0.01)`) |
| Push within sheet (ForgotPasswordCooldownView) | Standard push (~300ms) | Instant replace |
| Biometric icon scale pulse | `AppSpring.snappy` scale 1.0→1.12→1.0 | No animation — static |
| BiometricActivationSheet dismiss on success | `AppSpring.bouncy` | Instant dismiss |
| AuthBannerView slide-in | `AppDuration.short` slide from top | Immediate visibility at final position (no slide) |
| Cooldown timer label update | `AppMotion.quickInteraction` | Immediate update |

### 6.5 Color Contrast

All colors use `AppColor.*` tokens validated by `ColorContrastValidator` in DEBUG mode.
On the auth gradient background (`AppGradient.authBackground` / dark background):

| Text token | Background | Contrast | WCAG |
|---|---|---|---|
| `AppColor.Text.inversePrimary` | Auth dark gradient | ≥9.2:1 | AAA |
| `AppColor.Text.inverseSecondary` | Auth dark gradient | ≥5.4:1 | AA |
| `AppColor.Accent.primary` (orange) on dark | Auth dark gradient | ≥3:1 (large text/UI) | AA |

On `AppColor.Surface.elevated` (light card backgrounds):
- All `AppColor.Text.*` tokens meet WCAG AA minimum as documented in AppTheme.swift.

---

## Section 7 — Motion & Animation

### 7.1 Sheet Transitions

| Trigger | Animation | Token | Duration |
|---|---|---|---|
| ForgotPasswordRequestView presents | Slide up from bottom edge | `AppSpring.smooth` | ~400ms (spring, system) |
| ForgotPasswordRequestView dismisses | Slide down to bottom edge | `AppSpring.smooth` | ~300ms |
| ForgotPasswordCooldownView pushes in | Standard push right-to-left | `AppMotion.stepTransition` | 300ms |
| ForgotPasswordCooldownView pops | Standard pop left-to-right | `AppMotion.stepTransition` | 300ms |
| BiometricActivationSheet presents | Slide up from bottom edge | `AppSpring.smooth` | ~400ms |
| BiometricActivationSheet dismisses (success) | Slide down | `AppSpring.bouncy` | response 0.45s |
| BiometricActivationSheet dismisses (declined) | Slide down | `AppSpring.smooth` | ~300ms |
| BiometricUnlockView presents | Fade + scale up (fullScreenCover) | System fullScreenCover | ~400ms |
| BiometricUnlockView dismisses (success) | System dismiss | `AppSpring.stiff` | ~250ms |
| SetNewPasswordView pushes in | Standard push | `AppMotion.stepTransition` | 300ms |

All transitions use `.motionSafe()` modifier — reduce motion = instant.

### 7.2 Biometric Interaction Animations

| Moment | Animation | Token | What user sees |
|---|---|---|---|
| User taps "Unlock with Face ID" CTA | Icon scale pulse | `AppSpring.snappy` | SF Symbol scales 1.0→1.12→1.0 over 300ms |
| Biometric success (BiometricActivationSheet) | Sheet bouncy dismiss + haptic | `AppSpring.bouncy` | Sheet springs off-screen; `.success` haptic |
| Biometric success (BiometricUnlockView) | `FitMeLogoLoader` confirmPulse → dismiss | `AppLoadingAnimation.confirmPulse` | Brief logo pulse, then cover dismisses |
| Biometric failure | Icon horizontal shake | `AppMotion.quickInteraction` + offset keyframes | SF Symbol shakes left-right 3 times (error pattern) |

### 7.3 Form Feedback Animations

| Trigger | Animation | Token |
|---|---|---|
| PasswordRulesTooltip rule changes green | Individual rule item fade + checkmark appear | `AppEasing.short` (200ms) |
| AuthBannerView slides in | Slide from above form card, fade in | `AppDuration.short` (200ms) easeOut |
| AuthBannerView slides out | Slide up, fade out | `AppDuration.short` (200ms) easeIn |
| Button press | Scale 0.985 + opacity 0.88 | `AppMotion.pressFeedback` (160ms) |
| "Send reset link" enters loading | Label fade-out, spinner fade-in | `AppDuration.instant` (100ms) |
| Cooldown timer tick | None — instant label update | No animation (sub-1s text updates should not animate per HIG) |

### 7.4 Haptic Taxonomy

| Moment | Generator | Style | Rationale |
|---|---|---|---|
| Any CTA button press | `UIImpactFeedbackGenerator` | `.light` | Standard button feedback |
| Email send success (routes to cooldown) | `UINotificationFeedbackGenerator` | `.success` | Action completed successfully |
| Biometric scan initiated (user taps CTA) | `UIImpactFeedbackGenerator` | `.medium` | Heavier haptic for biometric moment |
| Biometric activation success | `UINotificationFeedbackGenerator` | `.success` | Milestone — feature enabled |
| Biometric unlock success | `UINotificationFeedbackGenerator` | `.success` | Session restored milestone |
| Biometric failure | `UINotificationFeedbackGenerator` | `.error` | Authentication failed |
| Password update success | `UINotificationFeedbackGenerator` | `.success` | Account recovery completed |
| Resend (cooldown active) | `UINotificationFeedbackGenerator` | `.warning` | User hit a limit |
| Cooldown expires and resend becomes active | `UIImpactFeedbackGenerator` | `.light` | State change notification |

---

## Section 8 — Analytics Instrumentation

All 9 events from PRD §Analytics Spec, with screen-prefix validation per
CLAUDE.md "Analytics Naming Convention" (`auth_*` prefix for auth-scoped events).

### 8.1 New Events

| Event name | Screen prefix | Trigger screen (SwiftUI) | Parameters | Conversion event |
|---|---|---|---|---|
| `auth_password_reset_requested` | `auth_` ✓ | `ForgotPasswordRequestView` | `email_provided: Bool` | No |
| `auth_password_reset_completed` | `auth_` ✓ | `SetNewPasswordView` | `time_to_complete_seconds: Int` | **Yes** |
| `auth_password_reset_resend` | `auth_` ✓ | `ForgotPasswordCooldownView` | `attempt_number: Int` | No |
| `auth_password_reset_resend_blocked` | `auth_` ✓ | `ForgotPasswordCooldownView` | `cooldown_remaining_seconds: Int` | No |
| `auth_biometric_activation_offered` | `auth_` ✓ | `BiometricActivationSheet` | `biometric_type: String` | No |
| `auth_biometric_activated` | `auth_` ✓ | `BiometricActivationSheet` | `biometric_type: String`, `provider: String` | **Yes** |
| `auth_biometric_activation_declined` | `auth_` ✓ | `BiometricActivationSheet` | `biometric_type: String` | No |
| `auth_biometric_unlock_completed` | `auth_` ✓ | `BiometricUnlockView` | `biometric_type: String`, `duration_ms: Int` | No |
| `auth_biometric_unlock_failed` | `auth_` ✓ | `BiometricUnlockView` | `biometric_type: String`, `reason: String` | No |

### 8.2 Instrumentation Wiring

| Screen | Analytics call point | SDK call |
|---|---|---|
| `ForgotPasswordRequestView` | On successful API response (before navigation) | `AnalyticsService.logEvent("auth_password_reset_requested", params: ["email_provided": !email.isEmpty])` |
| `ForgotPasswordCooldownView` | On "Resend" tap (blocked) | `AnalyticsService.logEvent("auth_password_reset_resend_blocked", params: ["cooldown_remaining_seconds": remainingSeconds])` |
| `ForgotPasswordCooldownView` | On "Resend" tap (after cooldown) | `AnalyticsService.logEvent("auth_password_reset_resend", params: ["attempt_number": attemptCount])` |
| `SetNewPasswordView` | On successful password update | `AnalyticsService.logEvent("auth_password_reset_completed", params: ["time_to_complete_seconds": elapsed])` |
| `BiometricActivationSheet` | `.onAppear` | `AnalyticsService.logEvent("auth_biometric_activation_offered", params: ["biometric_type": biometricTypeString])` |
| `BiometricActivationSheet` | On LAContext success | `AnalyticsService.logEvent("auth_biometric_activated", params: ["biometric_type": ..., "provider": lastSignInProvider])` |
| `BiometricActivationSheet` | On "Not now" tap | `AnalyticsService.logEvent("auth_biometric_activation_declined", params: ["biometric_type": biometricTypeString])` |
| `BiometricUnlockView` | On LAContext success | `AnalyticsService.logEvent("auth_biometric_unlock_completed", params: ["biometric_type": ..., "duration_ms": elapsed])` |
| `BiometricUnlockView` | On LAContext error | `AnalyticsService.logEvent("auth_biometric_unlock_failed", params: ["biometric_type": ..., "reason": errorReason])` |

### 8.3 Screen Tracking

Each new screen fires `.analyticsScreen()` on the root view `.onAppear`:

| Screen | Screen name (GA4) |
|---|---|
| `ForgotPasswordRequestView` | `forgot_password` |
| `ForgotPasswordCooldownView` | `email_sent_confirmation` |
| `SetNewPasswordView` | `set_new_password` |
| `BiometricActivationSheet` | `biometric_activation_sheet` |
| `BiometricUnlockView` | `biometric_unlock` |

### 8.4 Consent Gating

All events are gated behind analytics consent (checked by `AnalyticsService` before any
`logEvent` call). Users who have denied analytics consent fire no events. This is
enforced at the `AnalyticsService` layer — no per-screen guard needed in view code.

---

## Section 9 — Principle Application Table

Full UX Foundations compliance gateway. Draws directly from `ux-research.md` analysis.

### 9.1 Compliance Gateway (5/5 PASS)

| Dimension | Result | Evidence |
|---|---|---|
| Token compliance | **PASS** | All visual values use `AppColor.*`, `AppText.*`, `AppSpacing.*`, `AppRadius.*`, `AppSpring.*` tokens. One 88pt fixed icon size with DS-exception comment. |
| Component reuse | **PASS** | `AuthScaffold`, `AuthFormCard`, `AuthPrimaryButtonStyle`, `AuthBannerView`, `PasswordRulesSecureField`, `AppSheetShell`, `AppButton`, `FitMeBrandIcon`, `FitMeLogoLoader` — all existing. No new components required. |
| Motion compliance | **PASS** | All animations use `AppSpring.*`, `AppEasing.*`, `AppDuration.*`, `AppLoadingAnimation.*` tokens. `.motionSafe()` modifier applied throughout. |
| Accessibility | **PASS** | 43 VoiceOver labels specified (>30 minimum). AX5 Dynamic Type rules defined. Tap targets all ≥44pt. Reduce-motion alternatives specified for all animations. |
| Pattern compliance | **PASS** | Sheet/push/fullScreenCover navigation follows Part 2.5 of ux-foundations.md. State coverage: 5 states defined for all 5 screens. No raw literals introduced. |

### 9.2 Heuristic Validation (12 PASS / 1 N/A)

| Principle | Result | How honored |
|---|---|---|
| **1.1 Fitts's Law** | **PASS** | Primary CTAs are full-width, 52pt (`AppSize.ctaHeight`). Secondary actions are visually subordinate (`AppButton.tertiary`). Biometric CTA is the dominant single target on BiometricUnlockView. |
| **1.2 Hick's Law** | **PASS** | ≤3 active choices per screen. Resend CTA is disabled during cooldown (visually 1 live choice). BiometricActivationSheet offers exactly 2 choices (Enable / Not now). |
| **1.3 Jakob's Law** | **PASS** | Sheet presentations, push navigation, deep-link patterns, biometric activation, and Google Sign-In all follow iOS conventions and match patterns in Strava/Whoop/banking apps. |
| **1.4 Progressive Disclosure** | **PASS** | Reset flow is 3 sequential screens revealing only what's needed at each step. Password rules shown only on SetNewPasswordView. Activation details handled by iOS LAContext natively. |
| **1.5 Recognition Over Recall** | **PASS** | Email pre-filled. Sent-to email shown verbatim. Biometric type shown by name and icon. Password rules visible as user types. "Welcome back, {name}" confirms identity on BiometricUnlockView. |
| **1.6 Consistency** | **PASS** | All screens reuse existing `Auth*` component family. No new patterns invented. Visual language matches `AuthHubView` and `OnboardingAuthView`. |
| **1.7 Feedback** | **PASS** | Every CTA enters loading state on press (<100ms). Success/error haptics defined for every outcome. AuthBannerView for all async errors. Cooldown timer updates in real time. |
| **1.8 Error Prevention** | **PASS** | CTA disabled until validation passes. Inline mismatch error while typing. Privacy-preserving reset response (no account enumeration). One-shot biometric activation (never re-prompts). |
| **1.9 Readiness-First** | **N/A** | Auth surface is a prerequisite gate, not a content surface. Readiness data is not available until sign-in completes. This principle governs home/today surfaces. |
| **1.10 Zero-Friction Logging** | **PASS** | Biometric unlock is 2 steps (tap + scan). Email pre-filled. Password rules visible inline. No CAPTCHA or extra verification in the unlock path. |
| **1.11 Privacy by Default** | **PASS** | No account enumeration in reset flow. Analytics fire `email_provided: Bool` not the address. BiometricActivationSheet shows "Your data stays encrypted on this device." Google token not persisted. |
| **1.12 Progressive Profiling** | **PASS** | Biometric activation is one-shot post-sign-in. `hasAskedForBiometricActivation` flag ensures never re-prompts. "Not now" is respected permanently. |
| **1.13 Celebration Not Guilt** | **PASS** | Password reset success → neutral "You're back in." Biometric activation → positive "Your account is now protected with Face ID." "Not now" is treated as a valid choice — no follow-up guilt. |

---

## Section 10 — Screen Wireframes

### 10.1 Low-fi ASCII Wireframes (5 screens)

#### ForgotPasswordRequestView

```
┌────────────────────────────┐
│  ← Back                    │   (AppText.titleMedium, AppColor.Text.inversePrimary)
│                            │
│  [FitMeBrandIcon small]    │   (32pt, centered)
│                            │
│  Forgot password?          │   (AppText.pageTitle, inversePrimary)
│                            │
│  Enter your email and      │   (AppText.body, inverseSecondary)
│  we'll send a reset link.  │
│                            │
│  ┌────────────────────┐    │
│  │  your@email.com    │    │   (AuthFormCard, PasswordRulesSecureField style)
│  └────────────────────┘    │
│                            │
│  [AuthBannerView — error]  │   (conditionally visible)
│                            │
│                            │
│                            │
│  ┌────────────────────┐    │
│  │  Send reset link   │    │   (AuthPrimaryButtonStyle, 52pt, disabled if empty)
│  └────────────────────┘    │
└────────────────────────────┘
  (AuthGradient background, authTop→authBottom)
```

#### ForgotPasswordCooldownView

```
┌────────────────────────────┐
│  ← Back                    │
│                            │
│       ✓                    │   (AppColor.Status.success, AppText.iconMedium, 28pt)
│                            │
│   Check your inbox         │   (AppText.titleMedium, inversePrimary)
│                            │
│  We sent a link to         │   (AppText.body, inverseSecondary)
│  user@example.com          │   (AppText.subheading, bold — actual email)
│                            │
│  ┌─────────────────────────┐│
│  │  Resend email (in 42s)  ││   (AppButton.secondary, disabled state during cooldown)
│  └─────────────────────────┘│
│                            │
│  Use a different email      │   (AppButton.tertiary link)
│                            │
└────────────────────────────┘
  (AuthGradient background)
```

#### SetNewPasswordView

```
┌────────────────────────────┐
│  ← Back                    │
│                            │
│  Set new password          │   (AppText.pageTitle)
│                            │
│  ┌────────────────────┐    │
│  │  New password      │    │   (PasswordRulesSecureField)
│  ├────────────────────┤    │   (AuthFormCard)
│  │  Confirm password  │    │   (PasswordRulesSecureField)
│  └────────────────────┘    │
│  Passwords don't match     │   (inline error, AppColor.Status.error, conditionally visible)
│                            │
│  Password requirements:    │   (PasswordRulesTooltip, always visible)
│  ○ 6 to 14 characters      │
│  ○ One uppercase letter    │
│  ○ One number              │
│  ○ One special character   │
│                            │
│  ┌────────────────────┐    │
│  │  Update password   │    │   (AuthPrimaryButtonStyle, disabled until valid)
│  └────────────────────┘    │
└────────────────────────────┘
  (AuthGradient background)
```

#### BiometricActivationSheet

```
┌────────────────────────────┐
│        ─────               │   (drag indicator)
│                            │
│      [BrandIcon]           │   (FitMeBrandIcon, 36pt)
│                            │
│  Unlock FitMe with         │   (AppText.pageTitle, Text.primary on sheet surface)
│  Face ID                   │
│                            │
│  Your data stays           │   (AppText.subheading, Text.secondary)
│  encrypted on this device. │
│                            │
│  ┌────────────────────┐    │
│  │  Enable Face ID    │    │   (AppButton.primary, 52pt)
│  └────────────────────┘    │
│                            │
│        Not now             │   (AppButton.tertiary)
│                            │
└────────────────────────────┘
  (AppColor.Surface.materialLight background, AppRadius.authSheet)
  (.medium detent, resizable)
```

#### BiometricUnlockView

```
┌────────────────────────────┐
│                            │   (AppGradient.authBackground fills entire screen)
│                            │
│      [FitMeBrandIcon]      │   (48pt, top third)
│                            │
│   Welcome back,            │   (AppText.hero, AppColor.Text.inversePrimary)
│   Regev                    │
│                            │
│           👁               │   (face.id SF Symbol, 88pt, AppColor.Accent.secondary)
│   (or fingerprint icon)    │   (touchid SF Symbol)
│                            │
│                            │
│  ┌────────────────────┐    │
│  │ Unlock with Face ID│    │   (AuthPrimaryButtonStyle, 52pt, full-width)
│  └────────────────────┘    │
│                            │
│    Use password instead    │   (AppButton.tertiary link, 44pt tap target)
│                            │
│  [AuthBannerView error]    │   (conditionally visible, bottom)
└────────────────────────────┘
```

### 10.2 High-fi Schematics with Token Annotations

#### ForgotPasswordRequestView (High-fi)

```
┌──────────────────────────────────────────────────────────────────┐
│  ← Back                    (AppText.body.weight(.medium),        │
│    (44pt tap target)        AppColor.Accent.primary, leading)    │
│                                                                  │
│        [FitMeBrandIcon 32pt]  (accessibilityHidden: true)       │
│        [centered, AppSpacing.large top]                          │
│                                                                  │
│  Forgot password?           AppText.pageTitle                    │
│                             AppColor.Text.inversePrimary         │
│                             AppSpacing.small top                 │
│                                                                  │
│  Enter your email and       AppText.bodyRegular                  │
│  we'll send a reset link.   AppColor.Text.inverseSecondary       │
│                             AppSpacing.xxSmall top               │
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐     │
│  │  your@email.com                                        │     │
│  │   (AppText.body, AppColor.Text.primary,                │     │  AppRadius.button (20pt)
│  │    .emailAddress content type, AppColor.Accent.primary │     │  AppColor.Surface.elevated bg
│  │    cursor/focus ring)                                  │     │  AppSpacing.small padding
│  └────────────────────────────────────────────────────────┘     │  AppShadow.cardColor, cardRadius
│                                                                  │
│  [AuthBannerView — slides in from above the card]               │
│   AppColor.Status.error bg tint, AppText.caption text           │
│   AppDuration.short (200ms) slide animation                      │
│                                                                  │
│                            (flex spacer)                         │
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐     │
│  │           Send reset link                              │     │  AppSize.ctaHeight (52pt)
│  │  (AppText.button, AppColor.Text.inversePrimary)        │     │  AppColor.Accent.primary bg
│  └────────────────────────────────────────────────────────┘     │  AppRadius.button (20pt)
│  (AppSpacing.medium bottom + safe area inset)                    │  AppShadow.ctaColor shadow
└──────────────────────────────────────────────────────────────────┘
Background: AppGradient.authBackground (authTop → authMiddle → authBottom)
Screen padding: AppSpacing.medium horizontal, AppSpacing.xLarge top
```

#### SetNewPasswordView (High-fi)

```
┌──────────────────────────────────────────────────────────────────┐
│  ← Back                    (AppText.body, Accent.primary)        │
│                                                                  │
│  Set new password           AppText.pageTitle                    │
│                             AppColor.Text.inversePrimary         │
│                             AppSpacing.medium top                │
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐     │
│  │  New password                (placeholder text)        │     │  AuthFormCard
│  │  ●●●●●●   👁 toggle           (PasswordRulesSecureField)│     │  AppRadius.button (20pt)
│  ├────────────────────────────────────────────────────────┤     │  AppColor.Surface.elevated
│  │  Confirm password                                      │     │  AppShadow.card
│  │  ●●●●●●   👁 toggle                                    │     │
│  └────────────────────────────────────────────────────────┘     │
│  Passwords don't match  (AppColor.Status.error, AppText.caption)│
│  [only if mismatch detected while typing]                        │
│                                                                  │
│  Password requirements:     AppText.captionStrong, Text.secondary│
│  ┌──────────────────────────────────────────────────────┐       │
│  │ ✓  6 to 14 characters      (green = AppStatus.success)│       │
│  │ ○  One uppercase letter    (grey = neutral)           │       │
│  │ ○  One number              (red on error = Status.err)│       │
│  │ ○  One special character                              │       │
│  └──────────────────────────────────────────────────────┘       │
│  (PasswordRulesTooltip — always visible, not collapsible)        │
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐     │
│  │           Update password                              │     │  AppSize.ctaHeight 52pt
│  └────────────────────────────────────────────────────────┘     │  AuthPrimaryButtonStyle
│                                                                  │  Disabled: AppOpacity.disabled
└──────────────────────────────────────────────────────────────────┘
Background: AppGradient.authBackground
```

### 10.3 BiometricActivationSheet — Full Composite

```
╔══════════════════════════════════════════════════════════════════╗
║                                                                  ║
║  ┌──────────────────────────────────────────────────────────┐   ║
║  │                                                          │   ║
║  │              ─────────────                               │   ║  Drag indicator:
║  │         (Capsule, AppColor.Border.strong,                │   ║  36pt × 4pt
║  │          AppSpacing.xSmall top, AppSpacing.xxSmall bot)  │   ║
║  │                                                          │   ║
║  │                                                          │   ║
║  │                [   FitMeBrandIcon   ]                    │   ║  36pt brand icon
║  │                 (centered, 36pt,                         │   ║  accessibilityHidden: true
║  │                  AppSpacing.large top)                   │   ║
║  │                                                          │   ║
║  │                                                          │   ║
║  │         Unlock FitMe with Face ID                        │   ║  AppText.pageTitle
║  │                                                          │   ║  AppColor.Text.primary
║  │        (AppText.pageTitle, Text.primary,                 │   ║  multilineTextAlignment(.center)
║  │         .center, AppSpacing.xSmall top)                  │   ║  AppSpacing.medium horizontal
║  │                                                          │   ║
║  │      Your data stays encrypted                           │   ║  AppText.subheading
║  │      on this device.                                     │   ║  AppColor.Text.secondary
║  │                                                          │   ║  .center, AppSpacing.xxSmall top
║  │      (1 line max at default type; .lineLimit(nil) at AX5)│   ║
║  │                                                          │   ║
║  │                                                          │   ║
║  │  ┌────────────────────────────────────────────────┐     │   ║  AppSize.ctaHeight (52pt)
║  │  │           Enable Face ID                       │     │   ║  AppColor.Accent.primary bg
║  │  │    (AppText.button, Text.inversePrimary)        │     │   ║  AppRadius.button (20pt)
║  │  └────────────────────────────────────────────────┘     │   ║  AppShadow.ctaColor
║  │  (AppSpacing.medium horizontal, AppSpacing.xSmall top)  │   ║
║  │                                                          │   ║
║  │              Not now                                     │   ║  AppText.button
║  │     (AppButton.tertiary, Text.secondary,                 │   ║  AppColor.Text.secondary
║  │      .center, 44pt tap target via .frame(minHeight:44)) │   ║  contentShape(Rectangle)
║  │                                                          │   ║
║  │  (AppSpacing.medium bottom + UIApplication safeAreaInsets│   ║
║  │   bottom — accounts for home indicator)                  │   ║
║  │                                                          │   ║
║  └──────────────────────────────────────────────────────────┘   ║
║                                                                  ║
║  Sheet background: AppColor.Surface.materialLight               ║
║  Sheet corner radius: AppRadius.authSheet (36pt, top corners)   ║
║  Sheet detent: .medium (compact offering)                        ║
║  Overlay: AppColor.Overlay.scrim (black 40%) behind sheet        ║
║                                                                  ║
║  ANALYTICS:                                                      ║
║    .onAppear → auth_biometric_activation_offered                 ║
║      params: biometric_type: "face_id" | "touch_id" | "optic_id"║
║    Enable tap → LAContext.evaluatePolicy → success:              ║
║      → auth_biometric_activated                                  ║
║      params: biometric_type, provider (email|google|apple)      ║
║    Not now tap → auth_biometric_activation_declined              ║
║      params: biometric_type                                      ║
║                                                                  ║
║  HAPTICS:                                                        ║
║    Enable tap: UIImpactFeedbackGenerator(.light)                 ║
║    Success:   UINotificationFeedbackGenerator(.success)          ║
║    Not now:   no haptic (neutral action)                         ║
╚══════════════════════════════════════════════════════════════════╝
```

---

## Section 11 — Phase 4 Implementer Checklist

Cross-reference with `docs/design-system/v2-refactor-checklist.md` sections A/E/F/G/H.
These are /ux phase responsibilities that must be verified in Phase 4:

**From Section A (Audit & Spec):**
- [x] A2. `ux-research.md` exists — `.claude/features/auth-polish-v2/ux-research.md`
- [x] A3. `ux-spec.md` exists — this file
- [ ] A4. Compliance gateway run — 5/5 PASS (preliminary; Phase 4 confirms after code exists)
- Note: A1 (v2-audit-report) and A5 (v2_file_path) are marked N/A — `work_subtype = "new_ui"`, not `"v2_refactor"`. New screens have no v1 to audit against.

**From Section E (UX Principles):**
- [x] E1 Fitts's Law — 52pt primary CTAs, subordinate secondaries
- [x] E2 Hick's Law — ≤3 choices per screen
- [x] E3 Jakob's Law — iOS sheet/push/fullScreenCover conventions
- [x] E4 Progressive Disclosure — 3-screen reset flow
- [x] E5 Recognition Over Recall — pre-filled email, biometric type visible
- [x] E6 Consistency — existing auth component family reused
- [x] E7 Feedback — haptics + loading states + animations for every action
- [x] E8 Error Prevention — CTA disabled until valid, inline validation
- [ ] E9 N/A (Readiness-First — auth surface)
- [x] E10 Zero-Friction Logging (partial — biometric unlock 2-tap path)
- [x] E11 Privacy by Default — no account enumeration, `email_provided: Bool`
- [x] E12 Progressive Profiling — one-shot biometric activation
- [x] E13 Celebration Not Guilt — positive framing on all success states

**From Section F (State Coverage):**
- [x] F1 Default state — all 5 screens
- [x] F2 Loading state — all 5 screens
- [x] F3 Empty state — ForgotPasswordRequestView (CTA disabled), others N/A
- [x] F4 Error state — all 5 screens (AuthBannerView + inline)
- [x] F5 Success state — all 5 screens (navigation, haptic, dismissal)

**From Section G (Accessibility):**
- [x] G1 accessibilityLabel on every interactive element — 43 labels specified
- [x] G2 accessibilityHint on non-trivial actions
- [ ] G3 Chart accessibility — N/A (no charts in auth screens)
- [ ] G4 Custom accessibility actions — N/A (no rotating cards or custom segmented controls)
- [x] G5 Tap targets ≥44×44pt — all elements verified
- [x] G6 Touch target spacing ≥8pt — `AppSpacing.xSmall` (12pt) minimum between adjacent CTAs
- [x] G7 Dynamic Type — all AppText tokens, AX5 rules defined
- [x] G8 Color contrast — all AppColor tokens, WCAG AA minimum verified
- [x] G9 Color not only indicator — biometric failure uses icon shake + banner + haptic (not just color)

**From Section H (Motion):**
- [x] H1 Every animation maps to state change/feedback/celebration
- [x] H2 Durations from AppDuration tokens
- [x] H3 Springs use AppSpring tokens
- [x] H4 Reduce Motion honored — `.motionSafe()` on all animations
- [x] H5 Haptics use correct generator per taxonomy
- [x] H6 No animation-only feedback — all animations paired with haptic or label change

---

*End of ux-spec.md — Phase 3 deliverable for auth-polish-v2*
