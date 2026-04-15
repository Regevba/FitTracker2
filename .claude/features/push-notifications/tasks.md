# Push Notifications — Task Breakdown

**PRD:** `docs/product/prd/push-notifications.md`
**Estimated effort:** 5.5 days
**Critical path:** T1 → T3 → T5 → T8 → T10 → T12

## Tasks

| ID | Title | Type | Skill | Effort | Depends On | Status |
|---|---|---|---|---|---|---|
| T1 | NotificationService + scheduler | service | dev | 1.0d | — | pending |
| T2 | NotificationPreferencesStore | model | dev | 0.5d | — | pending |
| T3 | Permission priming view (3-step pattern) | ui | dev | 0.5d | T1 | pending |
| T4 | Workout reminder type (trigger + content) | service | dev | 0.5d | T1 | pending |
| T5 | Readiness alert type (HRV/sleep threshold) | service | dev | 0.5d | T1 | pending |
| T6 | Recovery nudge type (rest day recommendations) | service | dev | 0.5d | T1 | pending |
| T7 | Deep link handling (notification → screen) | service | dev | 0.5d | T4, T5, T6 | pending |
| T8 | Wire into app lifecycle (schedule on launch) | service | dev | 0.25d | T1, T4, T5, T6 | pending |
| T9 | 10 analytics events (notification_ prefix) | analytics | analytics | 0.25d | T1 | pending |
| T10 | Unit tests for NotificationService | test | qa | 0.5d | T1, T4, T5, T6 | pending |
| T11 | Accessibility pass (notification content) | ui | dev | 0.25d | T3 | pending |
| T12 | Build verification + pbxproj | test | dev | 0.25d | all | pending |

## Architecture Notes

- `NotificationService`: singleton, manages `UNUserNotificationCenter`, schedules/cancels notifications
- `NotificationPreferencesStore`: UserDefaults-backed, stores per-type enable/disable + frequency caps
- Permission priming: `NotificationPermissionPrimingView` shown before system dialog, follows UX Foundations 3-step pattern
- Each notification type is a `NotificationType` enum case with its own trigger condition, content builder, and deep link URL
- Confidence gate: only fire readiness alerts when `readinessResult.confidence >= .medium`
