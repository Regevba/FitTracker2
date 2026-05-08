# Design Audit — push-notifications-v2

**Phase:** 3 (UX/Integration), Step 3g (`/design audit`)
**Date:** 2026-05-07
**Spec:** `.claude/features/push-notifications/ux-spec.md`
**Compliance Gateway:** Phase 3 Design System Compliance — final check before /ux prompt + /design prompt + /design build

---

## 1. Token Compliance

| Check | Status | Details |
|---|---|---|
| Semantic tokens only (no raw color/font/spacing/radius literals in spec) | ✓ PASS | 20/20 tokens validated at /ux preflight |
| `make tokens-check` | ✓ PASS (no new tokens introduced) | v2 uses existing tokens only |
| Token pipeline (DesignTokens.swift ↔ tokens.json) | ✓ unchanged | No new tokens to round-trip |

**Verdict:** PASS — zero token violations.

---

## 2. Component Reuse

| Component | Reuse status | Source |
|---|---|---|
| `NotificationPermissionPrimingView` | Reused (revival) | v1 file at `FitTracker/Views/Notifications/NotificationPermissionPrimingView.swift` — currently HISTORICAL, T4 un-marks it |
| `RootTabView` | Reused | Existing entry point for `.onOpenURL` and `.onChange(of:)` observation |
| `ReminderNotificationDelegate` | Reused (extended) | Smart-reminders' delegate gains DeepLinkRouter integration via the paired backlog enhancement |
| Settings v2 Notifications row | Edit existing Settings | `FitTracker/Views/Settings/v2/SettingsView.swift` |
| `NotificationGateway` | NEW (Phase 4 T1) | Justified — single auth + dispatch surface for all consumers |
| `DeepLinkRouter` | NEW (Phase 4 T3) | Justified — closes deep-link infrastructure gap surfaced in research §6 |
| `NotificationConsumerRegistry` | NEW (Phase 4 T2) | Justified — per-consumer registration mechanism |
| `SettingsDeepLinkBanner` | NEW (Phase 4 T8) | Justified — one-time post-denial recovery surface; no existing equivalent |

**4 new components proposed.** All have explicit justification (single platform layer, no parallel-DS divergence). Per CLAUDE.md design-system evolution rule, these merge to main with this feature.

**Verdict:** PASS — component reuse maximized; new components fully justified.

---

## 3. Pattern Consistency

| Pattern | Status | Notes |
|---|---|---|
| Permission priming pattern (3-step per ux-foundations §5.2) | ✓ Compliant | Pre-Primer → System Dialog → Graceful Degradation |
| Sheet presentation (`.presentationDetents([.medium, .large])`) | ✓ Consistent with existing app sheets | iOS 16+ standard |
| Banner pattern (top-of-Home with dismiss) | ✓ Consistent with existing banners | Used in onboarding-v2, training reminders |
| Settings row dynamic CTA (state-driven label) | ✓ Consistent | Settings v2 already uses this pattern |
| `@AppStorage` for one-time UserDefaults flag | ✓ Consistent | Used across the app |

**Verdict:** PASS — no pattern deviations; v2 follows established conventions.

---

## 4. Accessibility

| Check | Status | Details |
|---|---|---|
| WCAG AA contrast | ✓ PASS | All token combinations pre-validated; no new color combinations introduced |
| Tap targets ≥ 44pt | ✓ PASS | Primary CTA 48pt; default Buttons ≥ 44pt; banner X 32pt visual + 12pt touch slop = 44pt+ effective |
| Dynamic Type | ✓ PASS | All text uses `AppText.*` scaling tokens |
| VoiceOver labels | ✓ PASS | 6/6 interactive elements labeled (CTA, Not Now, Open Settings, Dismiss X, Settings row, Category list) |
| Reduce Motion | ✓ PASS | Banner slide-in respects `accessibilityReduceMotion` per spec §6 |
| Decorative icon hidden | ✓ PASS | Bell icon `.accessibilityHidden(true)` |

**Verdict:** PASS — accessibility complete at design level; live `axe` audit deferred to Phase 6.

---

## 5. Motion

| Check | Status | Details |
|---|---|---|
| Animations use `AppMotion` presets | ✓ PASS — none used in v2 | Only banner slide-in via SwiftUI `.transition(.move + .opacity)` standard primitives |
| Raw `.spring/.easeInOut/.easeOut` calls | ✓ PASS — zero | No raw motion calls in spec |
| `accessibilityReduceMotion` respected | ✓ PASS | Banner transition gated on environment value |
| Default sheet/tab motion | ✓ PASS | UIKit-managed, framework-default |

**Verdict:** PASS — motion compliant; no new `AppMotion` tokens needed.

---

## 6. ui-audit Scanner (existing scannable code)

`python3 scripts/ui-audit.py --file FitTracker/Views/Notifications/NotificationPermissionPrimingView.swift --no-fail`

```
UI audit — 0 files scanned, 1 skipped
  P0 (blocking): 0
  P1 (warning):  0
  files with findings: 0
```

**Result:** Priming view is skipped because the HISTORICAL marker is still on the file (scanner skips HISTORICAL files by design). T4 (Phase 4) removes the marker, at which point ui-audit will scan it. Pre-emptive read of the file shows token-clean code (verified during /ux preflight + spec drafting).

The new files (NotificationGateway, DeepLinkRouter, NotificationConsumerRegistry, SettingsDeepLinkBanner) don't exist yet — Phase 4 creates them. They will be scanned at Phase 6 via `/design pre-merge-review`.

**Verdict:** PASS — no current scannable code has findings; Phase 6 gate will run the full scan against shipped code.

---

## 7. Compliance Gateway Verdict

| Check | Status |
|---|---|
| Token compliance | ✓ PASS |
| Component reuse | ✓ PASS (4 new components fully justified) |
| Pattern consistency | ✓ PASS |
| Accessibility | ✓ PASS |
| Motion | ✓ PASS |
| ui-audit (existing scannable surface) | ✓ PASS (0 findings) |

**OVERALL: PASS** — Phase 3 Design System Compliance Gateway clear.

Spec is approvable for `/ux prompt` (3h), `/design prompt` (3i), and `/design build` (3j).
