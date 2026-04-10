# Settings v2 — UX Foundations Audit Report

> **Date:** 2026-04-10
> **File:** `FitTracker/Views/Settings/SettingsView.swift` (1,183 lines)
> **Severity:** 0 P0, 2 P1, 2 P2 (lightest of all 6 screens)

## Compliance Scorecard

| Dimension | Score |
|-----------|-------|
| Font tokens | 99% (2 raw fonts) |
| Spacing tokens | 100% |
| Color tokens | 85% (8 raw colors) |
| Radius tokens | 100% |
| Motion tokens | 100% (0 raw animations!) |
| Accessibility | 13% (1/8 — worst absolute count) |
| State coverage | 100% (sync status enum present) |
| Component architecture | Best — 14 well-extracted nested types |

## P1 Findings (2)

### F1. Raw color literals (8 instances)
- `.accent.cyan`, `.accent.purple`, `.status.success`, `.status.warning`, `.status.error`, `.accent.primary`
- **Fix:** Replace with `AppColor.Accent.*` and `AppColor.Status.*`

### F2. Accessibility gaps (7/8 interactive elements unlabeled)
- Biometric toggle, Add Passkey, Stats metric toggles, Reset Metrics, Sync Now, Analytics toggle, Delete All Local Data
- **Critical:** Delete All Local Data (destructive) has no VoiceOver hint
- **Fix:** Add labels + hints to all interactive elements

## P2 Findings (2)

### F3. Raw font literals (2 instances)
- Lines 863, 1060: `.caption.weight(.semibold)` → `AppText.captionStrong`

### F4. Hardcoded frames (5 instances)
- 34x34 icon bg, 6x6 status dot, 26x26 icon, 96pt numeric field, 12pt spacer
- **Fix:** Use AppSize/AppSpacing tokens
