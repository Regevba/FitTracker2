# PRD: GDPR Compliance (Account Deletion + Data Export)

> **Owner:** Claude (PM Workflow)
> **Date:** 2026-04-04
> **Phase:** Phase 1
> **Status:** Draft
> **Priority:** CRITICAL (legal + App Store requirement)

---

## Purpose

Implement GDPR data rights (Articles 15, 17, 20) and Apple's account deletion mandate, enabling users to delete their account and export all personal data from within the app.

## Business Objective

Legal compliance is non-negotiable. Without account deletion, FitMe cannot be submitted to the EU App Store. Without data export, we're exposed to GDPR fines up to EUR 20M or 4% annual turnover. This feature removes the #1 legal blocker to launch.

## Target Persona(s)

| Persona | Relevance |
|---------|-----------|
| All users | GDPR applies to every EU user; Apple mandate applies globally |
| Privacy-conscious users | Trust signal — "I can leave anytime with my data" |
| Churned users | Clean exit path reduces support burden |

## Has UI?

Yes — Delete Account screen, Export Data screen, Grace Period status, confirmation dialogs.

## Requires Analytics?

Yes — track deletion requests, completion rates, export requests, grace period cancellations.

---

## Functional Requirements

| # | Requirement | Priority | Details |
|---|-------------|----------|---------|
| 1 | Delete Account button in Settings → Account & Security | P0 | Visible, accessible, same effort level as account creation |
| 2 | Re-authentication before deletion | P0 | Biometric or password confirmation (prevent accidental deletion) |
| 3 | Confirmation dialog with clear consequences | P0 | "This will permanently delete all your data from all devices and servers" |
| 4 | 30-day grace period | P0 | Account marked for deletion, user can cancel anytime within 30 days |
| 5 | Grace period status indicator | P1 | Show countdown in Settings when deletion is scheduled |
| 6 | Cancel deletion during grace period | P0 | One-tap undo, restores account fully |
| 7 | Automated deletion after grace period | P0 | Background job deletes: device, Keychain, UserDefaults, CloudKit, Supabase (sync_records, cardio_assets, auth.users), AI cohort (anonymize), Firebase Analytics |
| 8 | Export My Data button in Settings → Data & Sync | P0 | Generates JSON archive of all personal data |
| 9 | Export includes all user data | P0 | Profile, daily logs, weekly snapshots, nutrition, training, biometrics, AI insights, preferences |
| 10 | Export delivery via share sheet | P1 | iOS share sheet (save to Files, AirDrop, email) |
| 11 | Sign out after deletion completes | P0 | Clear session, navigate to Welcome screen |
| 12 | Email notification on deletion request | P1 | Confirm via Supabase Auth email (or in-app confirmation) |

## User Flows

### Account Deletion Flow
1. Settings → Account & Security → "Delete Account"
2. Re-authenticate (biometric/password)
3. Confirmation dialog: "Your account and all data will be permanently deleted in 30 days. You can cancel anytime."
4. User confirms → account enters grace period
5. Settings shows: "Account scheduled for deletion on {date}" + "Cancel Deletion" button
6. After 30 days → automated deletion across all 9 data stores
7. User signed out → Welcome screen

### Data Export Flow
1. Settings → Data & Sync → "Export My Data"
2. Loading indicator while JSON is generated
3. Share sheet opens with `fitme-export-{date}.json`
4. User saves/shares the file

### Cancel Deletion Flow
1. Settings shows grace period banner
2. User taps "Cancel Deletion"
3. Confirmation: "Your account will not be deleted."
4. Grace period cleared, account restored

## Current State & Gaps

| Gap | Priority | Notes |
|-----|----------|-------|
| No account deletion | P0 | Settings has "Delete All Local Data" but this only clears device — not cloud |
| No data export | P0 | No export functionality exists |
| No grace period | P0 | No soft-delete infrastructure |
| No deletion cascade | P0 | Supabase tables lack CASCADE triggers |
| Partial local clear | Exists | `EncryptedDataStore.clearInMemory()` + `EncryptionService.clearSessionContext()` work |

## Acceptance Criteria

- [ ] User can delete their account entirely from within the app (Apple mandate)
- [ ] Deletion removes data from all 9 data stores (device, Keychain, UserDefaults, CloudKit, Supabase x3, AI cohort, Firebase)
- [ ] 30-day grace period with cancel option
- [ ] User can export all personal data as JSON
- [ ] Export includes: profile, daily logs, weekly snapshots, nutrition, training, biometrics, preferences
- [ ] No orphaned records after deletion (verified by test)
- [ ] Deletion flow requires re-authentication
- [ ] App passes App Store review with account deletion

---

## Success Metrics & Measurement Plan

### Primary Metric
- **Metric:** Account deletion completion rate
- **Baseline:** 0% (feature doesn't exist)
- **Target:** 100% of requested deletions complete across all stores within 30 days
- **Timeframe:** Measurable immediately after first deletion request

### Secondary Metrics
| Metric | Baseline | Target | Instrumentation |
|--------|----------|--------|-----------------|
| Data export generation time | N/A | < 30 seconds (< 1000 logs) | Timer in DataExportService |
| Grace period cancellation rate | N/A | Track (no target — informational) | GA4 event |
| App Store review pass | Blocked | Pass on first submission | Manual |

### Guardrail Metrics
| Metric | Current Value | Acceptable Range |
|--------|--------------|-----------------|
| Crash-free rate | >99.5% | Must stay >99.5% |
| Cold start time | <2s | Must stay <2s |
| Sync success rate | >99% | Must stay >99% |
| Zero orphaned records post-deletion | N/A | 0 orphans (verified by test) |

### Leading Indicators
- Deletion request event fires correctly in GA4
- Export generates valid JSON (verified in tests)
- Grace period countdown renders correctly

### Lagging Indicators
- App Store approval with account deletion
- Zero GDPR complaints from users
- Deletion completion rate at 100% after 60 days

### Instrumentation Plan
| Event/Metric | Method | Status |
|-------------|--------|--------|
| account_delete_requested | GA4 custom event | Not started |
| account_delete_completed | GA4 custom event | Not started |
| account_delete_cancelled | GA4 custom event | Not started |
| data_export_requested | GA4 custom event | Not started |
| data_export_completed | GA4 custom event | Not started |
| Deletion completion rate | GA4 funnel | Not started |
| Export generation time | AnalyticsService timer | Not started |

### Analytics Spec (GA4 Event Definitions)

> **Required: `requires_analytics = true`**
> Reference: `FitTracker/Services/Analytics/AnalyticsProvider.swift`

#### New Events
| Event Name | Category | GA4 Type | Screen/Trigger | Parameters | Conversion? | Notes |
|------------|----------|----------|----------------|------------|-------------|-------|
| `account_delete_requested` | Account | Custom | Settings/Account | `method` (biometric/password) | No | Fires when user confirms deletion |
| `account_delete_completed` | Account | Custom | Background | `stores_deleted` (comma-sep list) | Yes | Fires after all stores wiped |
| `account_delete_cancelled` | Account | Custom | Settings/Account | `days_remaining` (int) | No | Fires when user cancels during grace |
| `data_export_requested` | Account | Custom | Settings/Data | — | No | Fires when user taps Export |
| `data_export_completed` | Account | Custom | Settings/Data | `size_bytes` (int), `record_count` (int) | No | Fires after JSON generated |

#### New Parameters
| Parameter Name | Type | Allowed Values | Used By Events | Notes |
|---------------|------|----------------|----------------|-------|
| `stores_deleted` | string | comma-sep: device,keychain,userdefaults,cloudkit,supabase,ai,firebase | account_delete_completed | Which stores were wiped |
| `days_remaining` | int | 0-30 | account_delete_cancelled | Days left in grace period |
| `size_bytes` | int | 0-100000000 | data_export_completed | Export file size |
| `record_count` | int | 0-100000 | data_export_completed | Total records exported |

#### New Screens
| Screen Name | View Name | SwiftUI View | Category |
|-------------|-----------|--------------|----------|
| Delete Account | `delete_account` | DeleteAccountView | settings |
| Export Data | `export_data` | ExportDataView | settings |

#### New User Properties
None — existing properties sufficient.

#### Naming Validation Checklist
- [x] All event names: snake_case, <40 chars
- [x] All parameter names: snake_case, <40 chars
- [x] No reserved prefixes (ga_, firebase_, google_)
- [x] No duplicate names (checked against AnalyticsProvider.swift — all 5 events are new)
- [x] No PII in any parameter (no emails, names, user IDs)
- [x] ≤25 parameters per event (max 2 per event)
- [x] Total custom user properties still ≤25 (currently 6, adding 0)
- [x] Parameter values ≤100 chars
- [x] Conversion events identified (account_delete_completed)

#### Files to Update During Implementation
- [x] `AnalyticsProvider.swift` — add 5 events + 4 params + 2 screens to enums
- [x] `AnalyticsService.swift` — add typed convenience methods
- [x] `docs/product/analytics-taxonomy.csv` — add rows

### Review Cadence
- **First review:** 1 week post-launch (verify deletions complete, export works)
- **Ongoing:** Monthly (monitor deletion rate, export usage)

### Kill Criteria

This feature cannot be killed — it's a legal requirement. However, the grace period duration (30 days) can be adjusted if cancellation rate is extremely high (>80%) or if users complain about the wait.

---

## Key Files

| File | Purpose |
|------|---------|
| `FitTracker/Services/AccountDeletionService.swift` | New — orchestrates deletion across all stores |
| `FitTracker/Services/DataExportService.swift` | New — generates JSON export |
| `FitTracker/Views/Settings/DeleteAccountView.swift` | New — deletion UI |
| `FitTracker/Views/Settings/ExportDataView.swift` | New — export UI |
| `FitTracker/Views/Settings/SettingsView.swift` | Modified — add buttons |
| `FitTracker/Services/Supabase/SupabaseSyncService.swift` | Modified — add deleteAllUserData() |
| `FitTracker/Services/CloudKit/CloudKitSyncService.swift` | Modified — add deleteAllUserRecords() |
| `FitTracker/Services/Encryption/EncryptionService.swift` | Existing — clearSessionContext() |
| `FitTracker/Services/Analytics/AnalyticsProvider.swift` | Modified — add GDPR events |

## Dependencies & Risks

| Dependency/Risk | Mitigation |
|----------------|------------|
| CloudKit deletion is async, may fail | Retry queue with exponential backoff |
| Supabase lacks CASCADE on delete | Explicit deletion order: cardio_assets → sync_records → auth.users |
| Grace period must survive reinstall | Store deletion_scheduled_at in Supabase (not UserDefaults) |
| AI cohort_stats may have user_id | Soft-delete: anonymize user_id → NULL |
| Firebase Analytics user data | Call Analytics.resetAnalyticsData() + setUserID(nil) |

## Estimated Effort

- **Total:** 2 weeks (10 working days)
- **Breakdown:** research: 0.5d, PRD: 0.5d, tasks: 0.5d, UX: 1d, implementation: 5d, testing: 1.5d, review: 0.5d, docs: 0.5d
