# UX Spec: GDPR Compliance — Account Deletion + Data Export

> Feature: gdpr-compliance | Phase 3 | Date: 2026-04-04

---

## UX Principles Applied

| Principle | Application |
|-----------|-------------|
| **Error prevention** | Re-authentication + "I understand" toggle before deletion. Can't accidentally delete. |
| **Feedback** | Every step shows progress. Grace period countdown visible in Settings. |
| **Hick's Law** | Two clear screens: Delete Account, Export Data. No combined flows. |
| **Progressive disclosure** | Deletion shows simple warning first, details on tap. |
| **Recognition over recall** | Grace period status always visible as banner in Settings. |
| **Consistency** | Follows existing Settings patterns (SettingsDetailScaffold, SettingsSectionCard). |

---

## Screen 1: DeleteAccountView

**Entry point:** Settings → Account & Security → "Delete Account" row (SettingsActionLabel, destructive tint)

### Default State (no pending deletion)

```
┌──────────────────────────────────┐
│  ← Delete Account                │  ← Navigation title
│                                  │
│  ┌────────────────────────────┐  │
│  │ ⚠️ THIS CANNOT BE UNDONE  │  │  ← SettingsSectionCard, error tint
│  │                            │  │
│  │ Deleting your account will │  │  AppText.bodyRegular
│  │ permanently remove:        │  │  AppColor.Text.secondary
│  │                            │  │
│  │ • All training logs        │  │
│  │ • All nutrition data       │  │
│  │ • All biometric records    │  │
│  │ • Your profile & settings  │  │
│  │ • All synced cloud data    │  │
│  │                            │  │
│  │ This applies to all        │  │
│  │ devices and cloud storage. │  │
│  └────────────────────────────┘  │
│                                  │
│  ┌────────────────────────────┐  │
│  │ GRACE PERIOD          30d │  │  ← SettingsSectionCard
│  │                            │  │
│  │ After confirming, your     │  │
│  │ account will be scheduled  │  │
│  │ for deletion in 30 days.   │  │
│  │ You can cancel anytime.    │  │
│  └────────────────────────────┘  │
│                                  │
│  ┌────────────────────────────┐  │
│  │ CONFIRM                    │  │
│  │                            │  │
│  │ [Toggle] I understand that │  │  ← Toggle, off by default
│  │ all my data will be        │  │
│  │ permanently deleted.       │  │
│  └────────────────────────────┘  │
│                                  │
│  ┌────────────────────────────┐  │
│  │    Delete My Account       │  │  ← AppButton.destructive
│  └────────────────────────────┘  │     Disabled until toggle ON
│                                  │
│  Requires Face ID to confirm.    │  ← AppText.caption
│                                  │
└──────────────────────────────────┘
```

### Grace Period Active State

```
┌──────────────────────────────────┐
│  ← Delete Account                │
│                                  │
│  ┌────────────────────────────┐  │
│  │ 🕐 DELETION SCHEDULED     │  │  ← SettingsSectionCard, warning tint
│  │                            │  │
│  │ Your account will be       │  │
│  │ permanently deleted on:    │  │
│  │                            │  │
│  │     May 4, 2026            │  │  ← AppText.titleStrong
│  │     (27 days remaining)    │  │  ← AppText.body, warning color
│  │                            │  │
│  │ All data will be removed   │  │
│  │ from all devices and       │  │
│  │ cloud storage.             │  │
│  └────────────────────────────┘  │
│                                  │
│  ┌────────────────────────────┐  │
│  │    Cancel Deletion         │  │  ← AppButton.primary (orange)
│  └────────────────────────────┘  │
│                                  │
│  Changed your mind? Cancelling   │
│  will fully restore your account │
│  and all data.                   │
│                                  │
└──────────────────────────────────┘
```

### Tokens Used

| Element | Token |
|---------|-------|
| Background | `SettingsDetailScaffold` default |
| Warning card | `SettingsSectionCard` + `AppColor.Status.error` border |
| Grace period card | `SettingsSectionCard` + `AppColor.Status.warning` border |
| Delete button | `AppButton` destructive style (`AppColor.Status.error`) |
| Cancel button | `AppButton` primary style (`AppColor.Brand.primary`) |
| Toggle | Native SwiftUI `Toggle` |
| Body text | `AppText.bodyRegular` + `AppColor.Text.secondary` |
| Date | `AppText.titleStrong` + `AppColor.Text.primary` |
| Caption | `AppText.caption` + `AppColor.Text.tertiary` |
| Spacing | `AppSpacing.medium` between cards |

---

## Screen 2: ExportDataView

**Entry point:** Settings → Data & Sync → "Export My Data" row (SettingsActionLabel, accent tint)

```
┌──────────────────────────────────┐
│  ← Export My Data                │  ← Navigation title
│                                  │
│  ┌────────────────────────────┐  │
│  │ YOUR DATA SUMMARY         │  │  ← SettingsSectionCard
│  │                            │  │
│  │ Profile           1 record │  │  ← SettingsValueRow
│  │ Daily Logs       247 logs  │  │
│  │ Weekly Snapshots  35 snaps │  │
│  │ Meal Templates    12 items │  │
│  │ Preferences       1 record │  │
│  └────────────────────────────┘  │
│                                  │
│  ┌────────────────────────────┐  │
│  │ EXPORT FORMAT              │  │  ← SettingsSectionCard
│  │                            │  │
│  │ JSON file containing all   │  │
│  │ your data in a portable,   │  │
│  │ machine-readable format.   │  │
│  │                            │  │
│  │ No health data values are  │  │
│  │ sent to any server during  │  │
│  │ export — everything stays  │  │
│  │ on your device.            │  │
│  └────────────────────────────┘  │
│                                  │
│  ┌────────────────────────────┐  │
│  │    Export as JSON           │  │  ← AppButton.primary
│  └────────────────────────────┘  │
│                                  │
│  [Progress bar when exporting]   │  ← ProgressView (hidden by default)
│                                  │
└──────────────────────────────────┘
```

After export completes → iOS share sheet opens with `fitme-export-{date}.json`.

### Tokens Used

| Element | Token |
|---------|-------|
| Section cards | `SettingsSectionCard` |
| Value rows | `SettingsValueRow` |
| Export button | `AppButton` primary (`AppColor.Brand.primary`) |
| Progress | Native `ProgressView` |
| Body text | `AppText.bodyRegular` + `AppColor.Text.secondary` |

---

## Settings Integration

### Account & Security section — add at bottom:

```
┌────────────────────────────────┐
│ ACCOUNT                        │
│                                │
│ ... existing rows ...          │
│                                │
│ Delete Account           →     │  ← SettingsActionLabel
│ Schedule permanent deletion    │     icon: trash.fill
│ of your account and all data.  │     tint: AppColor.Status.error
└────────────────────────────────┘
```

### Data & Sync section — add before "Danger Zone":

```
┌────────────────────────────────┐
│ DATA PORTABILITY               │
│                                │
│ Export My Data            →    │  ← SettingsActionLabel
│ Download all your data as a    │     icon: square.and.arrow.up.fill
│ JSON file.                     │     tint: AppColor.Accent.primary
└────────────────────────────────┘
```

---

## Accessibility Requirements

| Requirement | Implementation |
|-------------|---------------|
| Min tap target | All buttons: 44pt height minimum |
| Dynamic Type | All text uses AppText tokens |
| VoiceOver | Delete button: "Delete my account. Requires Face ID confirmation." |
| VoiceOver | Export button: "Export all my data as JSON file." |
| VoiceOver | Toggle: "I understand that all my data will be permanently deleted." |
| Contrast | All text meets WCAG AA 4.5:1 via AppColor tokens |
| Reduce Motion | No custom animations |

---

## Design System Compliance Report

| Check | Status | Details |
|-------|--------|---------|
| **Token compliance** | ✅ Pass | All colors, text, spacing use AppTheme tokens. Zero raw values. |
| **Component reuse** | ✅ Pass | Uses: SettingsDetailScaffold, SettingsSectionCard, SettingsValueRow, SettingsActionLabel, AppButton, Toggle. No new components. |
| **Pattern consistency** | ✅ Pass | Follows existing Settings detail screen pattern (same as Data & Sync, Account & Security). |
| **Accessibility** | ✅ Pass | 44pt targets, Dynamic Type, VoiceOver labels, WCAG AA contrast. |
| **Motion** | ✅ Pass | No custom animations. Standard SwiftUI transitions. |

**All 5 checks pass.** No compliance violations. No design system evolution needed.
