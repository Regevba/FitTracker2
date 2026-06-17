---
title: "GDPR Compliance — Case Study"
date_written: 2026-05-05
work_type: Feature
dispatch_pattern: serial
success_metrics:
  primary: "App Store Review approval (binary, T2). Required for App Store submission per Apple Privacy guidelines + EU GDPR Articles 17 + 20."
  secondary:
    - "Account-deletion flow completes end-to-end without orphaned data in any of 9 stores [T1 once instrumented; T2 at ship]"
    - "30-day grace-period cancellation works (user can rescue account up to expiry) [T2]"
    - "JSON export returns all user data in machine-readable form [T2]"
kill_criteria:
  - "Legal requirement — cannot be killed. If implementation surfaces a 9-store-clear failure mode under load, downgrade to a synchronous-with-rollback design rather than removing the feature."
kill_criteria_resolution: "not_applicable — legal/compliance requirement; cannot be killed. The synchronous-with-rollback downgrade mitigation was never triggered (no 9-store-clear failure mode surfaced under load)."
tier_tags_present: true
case_study_type: pre_pm_workflow_backfill
parent_case_study: "docs/case-studies/six-features-roundup-case-study.md"
predecessor_case_studies: []
status: shipped
framework_version: pre-v5.0
ship_date: 2026-04-04
pr_merge_commit: 2acd1d9
---

# Case Study: gdpr-compliance

> **Status:** Shipped 2026-04-04 (pre-PM-workflow rule, backfilled 2026-05-05)
> **Framework version:** pre-v5.0
> **Case study type:** `pre_pm_workflow_backfill` — written retroactively from the existing PRD + research + tasks + ux-spec; no fabrication
> **Parent (until split 2026-05-05):** [`six-features-roundup-case-study.md`](six-features-roundup-case-study.md)

## 1. One-line headline

The first feature in the project where kill criteria read "Legal requirement — cannot be killed," shipped end-to-end in two hours [T2 wall time].

## 2. Summary card

| Field | Value |
|---|---|
| Scope | In-app account deletion (GDPR Art 17) + JSON data export (Art 20) + 30-day grace period + Settings integration |
| PR / commits | Merge `2acd1d9` (8 files, +711 lines) [T1]. Implementation: `a416b4a` (PM phases), `13f4cfe` (core services + views + analytics), `470ee94` (settings wiring), `ff1c737` (6 analytics tests + taxonomy validation), `40131ee` (docs) |
| Work type | Feature |
| Transitions | 10 — full lifecycle 2026-04-04T11:00Z → 13:00Z [T1] |
| Wall time | 2 hours end-to-end [T2 declared, derived from transition timestamps] |
| Tests | 6 GDPR analytics tests (total `AnalyticsTests.swift` now +23 events covered) [T1] |
| High-risk files touched | Zero [T1 manual audit at review] |
| Priority | CRITICAL (legal + App Store requirement) |

## 3. What shipped

`AccountDeletionService.swift` (162 lines), `DataExportService.swift` (170 lines), `DeleteAccountView.swift` (154 lines), `ExportDataView.swift` (76 lines), 28-line `SettingsView.swift` integration, 22 lines in `AnalyticsProvider.swift` + 31 lines in `AnalyticsService.swift` for the 5 GDPR events, and 69 lines of `AnalyticsTests.swift` additions. The PRD enumerates 9 data stores that must be cleared on deletion: device, Keychain, UserDefaults, CloudKit, Supabase (sync_records, cardio_assets, auth.users), AI cohort (anonymize), Firebase Analytics.

## 4. Scope decisions

Research picked "full in-app deletion + JSON export + 30-day grace period" over the two alternatives (web portal, email-request workflow). The grace period is architectural: account is marked for deletion, user can cancel within 30 days, and a background job does the actual destructive work after expiry. Re-authentication (biometric or password) is required before deletion proceeds. Export is JSON via iOS share sheet — not PDF, not CSV, not email.

## 5. Risks logged at review

Two explicit:
- "Real Supabase/CloudKit runtime verification requires credentials" — known external blocker, not a regression.
- "Atomic rollback not yet implemented for partial deletion failures." — the service composes 9 store-clears and if the 7th fails, the first 6 don't roll back. Known gap rather than undiscovered.

The kill criteria entry ("Legal requirement — cannot be killed") is the project's first explicit acknowledgment that some features have floor-only, never-ceiling success conditions.

## 6. Chain of custody

Source artifacts (all present pre-2026-04-13 rule, retained verbatim):

| Artifact | Path | Lines |
|---|---|---|
| PRD | [`.claude/features/gdpr-compliance/prd.md`](../../.claude/features/gdpr-compliance/prd.md) | 228 |
| Research | [`.claude/features/gdpr-compliance/research.md`](../../.claude/features/gdpr-compliance/research.md) | 168 |
| Tasks | [`.claude/features/gdpr-compliance/tasks.md`](../../.claude/features/gdpr-compliance/tasks.md) | 128 |
| UX spec | [`.claude/features/gdpr-compliance/ux-spec.md`](../../.claude/features/gdpr-compliance/ux-spec.md) | 228 |
| State | [`.claude/features/gdpr-compliance/state.json`](../../.claude/features/gdpr-compliance/state.json) | — |
| Merge | `2acd1d9` (8 files, +711 lines) | — |

## 7. Why this wasn't a dedicated case study at ship time

The "every feature gets a case study" rule landed 2026-04-13, nine days after GDPR merged. The feature has the densest PRD of the six features in the original roundup (12 requirements, 5 events, 2 screens, 9 data stores audited) and the cleanest paper trail. It could have been a dedicated case study at ship time; it was originally consolidated into [`six-features-roundup-case-study.md`](six-features-roundup-case-study.md) because three of the six features in that roundup don't warrant one and consolidating was cleaner than mixing formats.

This dedicated case study was split out 2026-05-05 as part of the chain-of-custody initiative (full-repair-mode plan, Decision 3 + Q1 = Option 3 hybrid split): dense features get their own case study because the source material justifies it; thin features stay roundup-only.

## 8. What a full live-pm-workflow case study would have additionally recorded

The 2-hour wall time as the shape of "well-scoped legal feature with no design ambiguity" — research consumed 30 min, PRD consumed 15 min, tasks + UX consumed 30 min, implementation consumed 45 min, and review/merge/docs consumed 15 min. Roughly an hour each for "decide" and "build" on a feature with zero high-risk files [T2 declared, derived from transition timestamps]. Compare against [google-analytics](google-analytics-case-study.md) (19-hour active wall time, +1970 lines, cross-cutting).

## 9. Cross-feature lesson

Kill criteria reveal feature shape. GDPR's "Legal requirement — cannot be killed" describes a feature that cannot be removed on a growth threshold. Floor-only kill criteria correlate with stories about compliance and risk management (rather than adoption and iteration).

## Links

- **State:** `.claude/features/gdpr-compliance/state.json`
- **Source PRD/research/tasks/UX:** `.claude/features/gdpr-compliance/`
- **Companion case studies (split out same day from same roundup):** [`google-analytics-case-study.md`](google-analytics-case-study.md), [`android-design-system-case-study.md`](android-design-system-case-study.md)
- **Original roundup parent:** [`six-features-roundup-case-study.md`](six-features-roundup-case-study.md)
- **Showcase:** to be published as part of full-repair-mode plan PR-F
