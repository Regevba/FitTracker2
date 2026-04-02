# UX Spec: Google Analytics — Consent Flow & Settings

> Feature: google-analytics | Phase 3 | Date: 2026-04-02

---

## UX Principles Applied

| Principle | Application |
|-----------|-------------|
| **Progressive disclosure** | Consent screen shows brief summary first, "Learn More" expands details |
| **Hick's Law** | Two clear choices only: Accept / Decline. No granular toggles on first screen. |
| **Jakob's Law** | Follows Apple's own permission patterns (ATT dialog + custom explanation) |
| **Feedback** | Consent status reflected immediately in Settings badge |
| **Error prevention** | Decline is reversible from Settings at any time |
| **Recognition over recall** | Settings shows current consent status with visual badge |

---

## Screen 1: ConsentView (First Launch)

**Entry point:** Shown once after sign-in/sign-up, before the home screen. Not dismissable without a choice.

### Layout

```
┌──────────────────────────────────┐
│         [AppColor.Brand.primary] │
│              📊                   │
│                                  │
│   Help Us Improve FitMe          │  ← AppText.titleStrong
│                                  │
│   We use anonymous analytics     │  ← AppText.bodyRegular
│   to understand how the app is   │     AppColor.Text.secondary
│   used and make it better.       │
│                                  │
│   ┌────────────────────────────┐ │
│   │ ✓ App usage patterns       │ │  ← AppCard.quiet
│   │ ✓ Screen views             │ │     AppText.body
│   │ ✓ Feature adoption         │ │
│   │ ✗ Health data values       │ │     ✗ items in AppColor.Status.error
│   │ ✗ Personal information     │ │
│   │ ✗ Location or contacts     │ │
│   └────────────────────────────┘ │
│                                  │
│   Learn more about our           │  ← AppText.caption, link style
│   privacy practices →            │     AppColor.Accent.primary
│                                  │
│   ┌────────────────────────────┐ │
│   │       Accept & Continue    │ │  ← AppButton.primary
│   └────────────────────────────┘ │
│                                  │
│        Continue Without          │  ← AppQuietButton
│                                  │
│   You can change this anytime    │  ← AppText.caption
│   in Settings → Data.            │     AppColor.Text.tertiary
│                                  │
└──────────────────────────────────┘
```

### Behavior

1. User taps **Accept & Continue** → `ConsentManager.grantConsent()` → triggers iOS ATT dialog → navigates to Home
2. User taps **Continue Without** → `ConsentManager.denyConsent()` → skips ATT → navigates to Home
3. ATT dialog result stored but does NOT affect GDPR consent (separate concerns)
4. Screen only shows once per account. Consent state persisted in UserDefaults.

### States

| State | Behavior |
|-------|----------|
| First launch (no account) | Show after sign-up/sign-in completes |
| Returning user (consent granted) | Skip, go to Home |
| Returning user (consent denied) | Skip, go to Home |
| Re-consent (after revoke in Settings) | Show again on next launch |

### Tokens Used

| Element | Token |
|---------|-------|
| Background | `AppColor.Background.appPrimary` |
| Icon | `AppColor.Brand.primary` (orange accent) |
| Title | `AppText.titleStrong` + `AppColor.Text.primary` |
| Body text | `AppText.bodyRegular` + `AppColor.Text.secondary` |
| Card | `AppCard.quiet` with `AppRadius.small` |
| Check marks | `AppColor.Status.success` |
| Cross marks | `AppColor.Status.error` |
| Accept button | `AppButton.primary` (full width) |
| Decline button | `AppQuietButton` |
| Footer text | `AppText.caption` + `AppColor.Text.tertiary` |
| Learn more link | `AppText.caption` + `AppColor.Accent.primary` |
| Spacing | `AppSpacing.large` between sections, `AppSpacing.small` between items |

---

## Screen 2: Settings → Data → Analytics Toggle

**Entry point:** Settings → Data section (existing `DataSettingsView`).

### Layout

```
┌──────────────────────────────────┐
│  Data & Privacy                  │  ← SettingsDetailScaffold
│                                  │
│  ┌────────────────────────────┐  │
│  │ ANALYTICS          [🟢 On] │  │  ← SettingsSectionCard + eyebrow
│  │                            │  │
│  │ App Analytics    [Toggle]  │  │  ← SettingsValueRow + Toggle
│  │                            │  │
│  │ Help improve FitMe by      │  │  ← SettingsSupportingText
│  │ sharing anonymous usage    │  │
│  │ data. No health data is    │  │
│  │ ever shared.               │  │
│  │                            │  │
│  │ Privacy Policy →           │  │  ← SettingsActionLabel, link
│  └────────────────────────────┘  │
│                                  │
│  ┌────────────────────────────┐  │
│  │ APPLE TRACKING      [🟡]  │  │
│  │                            │  │
│  │ Ad Tracking       [Badge]  │  │  ← Shows ATT status
│  │                            │  │
│  │ Managed by iOS Settings.   │  │  ← SettingsSupportingText
│  │ Go to Settings → Privacy   │  │
│  │ → Tracking.                │  │
│  └────────────────────────────┘  │
│                                  │
└──────────────────────────────────┘
```

### Behavior

| Action | Result |
|--------|--------|
| Toggle ON | `ConsentManager.grantConsent()` → analytics resume |
| Toggle OFF | Confirmation alert → `ConsentManager.revokeConsent()` → analytics stop |
| ATT badge | Read-only, shows system ATT status (Authorized/Denied/Not Determined) |

### Tokens Used

| Element | Token |
|---------|-------|
| Section card | `SettingsSectionCard` |
| Eyebrow | `AppText.eyebrow` + `AppColor.Text.tertiary` |
| Badge (On) | `SettingsBadgeView` + `AppColor.Status.success` |
| Badge (Off) | `SettingsBadgeView` + `AppColor.Status.warning` |
| Toggle | Native SwiftUI `Toggle` |
| Supporting text | `SettingsSupportingText` + `AppText.caption` |
| Link | `SettingsActionLabel` + `AppColor.Accent.primary` |

---

## Screen 3: Analytics ViewModifier (Invisible)

No UI — a SwiftUI ViewModifier applied to all 25 tracked screens:

```swift
.analyticsScreen("screen_name")
```

Calls `AnalyticsService.logScreenView()` on `.onAppear`. No visual impact.

---

## Accessibility Requirements

| Requirement | Implementation |
|-------------|---------------|
| Min tap target | Accept/Decline buttons: 44pt height minimum |
| Dynamic Type | All text uses `AppText` tokens (already @ScaledMetric) |
| VoiceOver | Accept button: "Accept analytics and continue" / Decline: "Continue without analytics" |
| Contrast | All text meets WCAG AA 4.5:1 (verified via AppColor semantic tokens) |
| Reduce Motion | No custom animations in consent flow |

---

## Design System Compliance Report

| Check | Status | Details |
|-------|--------|---------|
| **Token compliance** | ✅ Pass | All colors, text, spacing, radius map to AppTheme tokens. Zero raw values. |
| **Component reuse** | ✅ Pass | Uses existing: AppCard, AppButton, AppQuietButton, SettingsSectionCard, SettingsValueRow, SettingsSupportingText, SettingsActionLabel, SettingsBadgeView, SettingsDetailScaffold. **One new component:** `AnalyticsScreenModifier` (ViewModifier, no visual). |
| **Pattern consistency** | ✅ Pass | Consent screen follows auth flow pattern (full-screen, not dismissable). Settings follows existing Data section layout. |
| **Accessibility** | ✅ Pass | 44pt tap targets, Dynamic Type via AppText, VoiceOver labels, WCAG AA contrast. |
| **Motion** | ✅ Pass | No custom animations. Standard SwiftUI transitions. |

**All 5 checks pass.** No compliance violations. No design system evolution needed.
