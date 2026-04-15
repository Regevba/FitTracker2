# Figma ↔ Code Sync Status

> **Last synced:** 2026-04-15
> **Figma file:** `0Ai7s3fCFqR5JXDW8JvgmD`

## Screen Sync Matrix

| Screen | Figma Node | Code File | Status | Notes |
|---|---|---|---|---|
| **Home v3** | `859:27` (Code Truth) | `MainScreenView.swift` (v2/) | **Synced** | Built 2026-04-15. Frosted glass removed, dividers, sample data. |
| **Training v2** | `761:2` (in section `438:2135`) | `TrainingPlanView.swift` (v2/) | **Minor drift** | Figma shows hamburger icon — code uses profile icon. Figma has eye icon top-right — code has none. |
| **Nutrition v2** | `768:2` | `NutritionView.swift` (v2/) | **Minor drift** | Same toolbar icon difference. Content matches. |
| **Stats v2** | `771:2` | `StatsView.swift` (v2/) | **Minor drift** | Same toolbar icon difference. Content matches. |
| **Settings v2** | `772:2` | `SettingsView.swift` (v2/) | **Synced** | Accessed from Profile → Account & Data card. Nutrition Strategy section removed, renamed to "HR & Intervals". |
| **Profile v3** | `822:2` | `ProfileView.swift` | **Drift** | Figma shows old 10-section list. Code has simplified hybrid (hero + 2 summary cards + appearance + sign out). Profile is locked — Figma update deferred. |
| **Onboarding v2** | `688:2` | `OnboardingView.swift` (v2/) | **Synced** | 6 screens + 3 HealthKit variants. No changes since PR #59. |
| **Login** | `25:7` | `SignInView.swift` | **Synced** | Auth screens match. |

## Global Differences (apply to all screens)

These are systematic differences between Figma and code that apply across all screens:

| Element | Figma (old) | Code (current) | Priority |
|---|---|---|---|
| Toolbar left icon | Hamburger (`≡`) or missing | Profile icon (`person.circle.fill`) | Low — cosmetic |
| Toolbar right icon | Eye icon or sync indicator | None (removed) | Low — cosmetic |
| Tab bar | Some show 5 tabs (with Profile) | 4 tabs (Home, Training, Nutrition, Stats) | Low — structural |
| Card backgrounds | White opaque (`Surface.elevated`) | No containers (floating on gradient) for Home | Home only |

## What's Locked

All screens are locked as of 2026-04-15. The code is the source of truth. Figma updates for the global toolbar/tab differences are deferred — they're cosmetic and don't affect implementation.

## Next Figma Update Triggers

- When a screen gets a redesign or polish pass
- When the Profile v3 simplified design is finalized for Figma
- When push notifications or smart reminders UI ships (new screens)
