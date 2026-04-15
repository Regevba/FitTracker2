# Smart Reminders — Task Breakdown

**PRD:** `docs/product/prd/smart-reminders.md`
**Estimated effort:** 6.5 days
**Critical path:** T1 → T2 → T3/T4 → T10 → T8 → T13 → T14
**Phased:** Phase 1 = T1-T4, T8, T10-T14. Phase 2 = T5-T7, T9.

## Tasks

| ID | Title | Type | Skill | Effort | Depends On | Status |
|---|---|---|---|---|---|---|
| T1 | NotificationScheduler service (core engine) | service | dev | 1.0d | — | pending |
| T2 | ReminderType enum + trigger conditions | model | dev | 0.5d | — | pending |
| T3 | Type 3 — Goal-gap nutrition reminder | service | dev | 0.5d | T1, T2 | pending |
| T4 | Type 4 — Training/rest day reminder | service | dev | 0.5d | T1, T2 | pending |
| T5 | Type 1 — HealthKit connect reminder | service | dev | 0.25d | T1, T2 | pending |
| T6 | Type 2 — Account registration reminder | service | dev | 0.25d | T1, T2 | pending |
| T7 | Type 5 — Engagement reminder (lapse detection) | service | dev | 0.25d | T1, T2 | pending |
| T8 | Frequency cap manager (3/day global, per-type) | service | dev | 0.5d | T1 | pending |
| T9 | LockedFeatureOverlay view (guest users) | ui | dev | 0.5d | — | pending |
| T10 | AIOrchestrator integration (personalized content) | service | dev | 0.5d | T1, T3, T4 | pending |
| T11 | Analytics events (reminder_ prefix, 15+ events) | analytics | analytics | 0.25d | — | pending |
| T12 | Unit tests for scheduler + all 5 types | test | qa | 1.0d | T3-T7 | pending |
| T13 | Wire into app lifecycle (launch + significant events) | service | dev | 0.25d | T1, T8 | pending |
| T14 | Build verification + pbxproj | test | dev | 0.25d | all | pending |
