# Task Breakdown: GDPR Compliance

> **Feature:** gdpr-compliance
> **Total effort:** 10 working days (~2 weeks)
> **Total subtasks:** 10

---

## Dependency Graph

```
[T1 Analytics events] ──→ [T2 AccountDeletionService]
                                    │
                          ┌─────────┼──────────┐
                          ▼         ▼          ▼
                    [T3 Supabase [T4 CloudKit [T5 Local
                     deletion]   deletion]    cleanup]
                          │         │          │
                          └─────────┼──────────┘
                                    ▼
                          [T6 DataExportService]
                                    │
                          ┌─────────┼──────────┐
                          ▼         ▼          ▼
                    [T7 Delete  [T8 Export  [T9 Grace
                     Account    Data        Period
                     View]      View]       Check]
                          │         │          │
                          └─────────┼──────────┘
                                    ▼
                              [T10 Testing]
```

---

## Tasks

### T1: GDPR Analytics Events
- **Type:** backend
- **Description:** Add 5 new events, 4 new parameters, 2 new screens to AnalyticsProvider.swift, AnalyticsService.swift, and analytics-taxonomy.csv. Events: account_delete_requested, account_delete_completed, account_delete_cancelled, data_export_requested, data_export_completed.
- **Effort:** 0.5 days
- **Dependencies:** None
- **Files:** `AnalyticsProvider.swift`, `AnalyticsService.swift`, `analytics-taxonomy.csv`

### T2: AccountDeletionService
- **Type:** backend
- **Description:** New `@MainActor ObservableObject` service orchestrating the 10-step deletion cascade. Manages grace period state (stored in Supabase user metadata). Methods: `requestDeletion()`, `cancelDeletion()`, `executeDeletion()`, `checkGracePeriod()`. Each step has error handling and retry.
- **Effort:** 2 days
- **Dependencies:** T1
- **Files:** `FitTracker/Services/AccountDeletionService.swift` (new)

### T3: Supabase Deletion Methods
- **Type:** backend
- **Description:** Add `deleteAllUserData()` to SupabaseSyncService. Deletes: cardio-images storage objects → cardio_assets rows → sync_records rows. Uses authenticated client (RLS enforced). Returns success/failure per table.
- **Effort:** 1 day
- **Dependencies:** T2
- **Files:** `FitTracker/Services/Supabase/SupabaseSyncService.swift` (modify)

### T4: CloudKit Deletion Methods
- **Type:** backend
- **Description:** Add `deleteAllUserRecords()` to CloudKitSyncService. Queries all record types (EncryptedDailyLog, EncryptedWeeklySnapshot, EncryptedUserProfile, EncryptedUserPreferences, EncryptedCardioAsset) in the private zone. Batch deletes via CKModifyRecordsOperation. Retry with exponential backoff on failure.
- **Effort:** 1 day
- **Dependencies:** T2
- **Files:** `FitTracker/Services/CloudKit/CloudKitSyncService.swift` (modify)

### T5: Local Data Cleanup
- **Type:** backend
- **Description:** Add `deleteAllLocalData()` method that clears: encrypted .ftenc files on disk, Keychain keys (AES-256, ChaCha20, HMAC), all `ft.*` UserDefaults keys, Firebase Analytics data (resetAnalyticsData + setUserID nil). Leverages existing `EncryptedDataStore.clearInMemory()` and `EncryptionService.clearSessionContext()`.
- **Effort:** 0.5 days
- **Dependencies:** T2
- **Files:** `FitTracker/Services/AccountDeletionService.swift` (extend), `FitTracker/Services/Encryption/EncryptionService.swift` (add deleteAllKeys)

### T6: DataExportService
- **Type:** backend
- **Description:** New service that queries all local data stores and builds a JSON export. Includes: UserProfile, UserPreferences, all DailyLogs (with exercise logs, nutrition logs, supplement logs, biometrics), WeeklySnapshots, MealTemplates. Writes to temp file, returns URL for share sheet.
- **Effort:** 1 day
- **Dependencies:** None (parallel with T2-T5)
- **Files:** `FitTracker/Services/DataExportService.swift` (new)

### T7: DeleteAccountView
- **Type:** ui
- **Description:** Settings → Account & Security → "Delete Account" pushes to DeleteAccountView. Shows: warning text, data store list, re-authentication (biometric), "I understand" confirmation toggle, "Delete My Account" destructive button. During grace period: shows countdown + "Cancel Deletion" button.
- **Effort:** 1 day
- **Dependencies:** T2
- **Files:** `FitTracker/Views/Settings/DeleteAccountView.swift` (new), `FitTracker/Views/Settings/SettingsView.swift` (modify)

### T8: ExportDataView
- **Type:** ui
- **Description:** Settings → Data & Sync → "Export My Data" pushes to ExportDataView. Shows: data summary (record counts), "Export as JSON" button, progress indicator during generation, share sheet on completion.
- **Effort:** 0.5 days
- **Dependencies:** T6
- **Files:** `FitTracker/Views/Settings/ExportDataView.swift` (new), `FitTracker/Views/Settings/SettingsView.swift` (modify)

### T9: Grace Period Check on Launch
- **Type:** backend
- **Description:** In FitTrackerApp.swift, on `.active` scene phase: check if user has a pending deletion (Supabase user metadata `deletion_scheduled_at`). If grace period expired (>30 days), trigger `AccountDeletionService.executeDeletion()`. If active, show banner in Settings.
- **Effort:** 0.5 days
- **Dependencies:** T2
- **Files:** `FitTracker/FitTrackerApp.swift` (modify)

### T10: Testing + Documentation
- **Type:** test + docs
- **Description:** Unit tests for: AccountDeletionService (mock all stores), DataExportService (verify JSON schema), analytics events (5 new events fire correctly). Update CHANGELOG, backlog, metrics framework. Verify `make tokens-check` passes.
- **Effort:** 1 day
- **Dependencies:** T1-T9
- **Files:** `FitTrackerTests/GDPRTests.swift` (new), `FitTrackerTests/AnalyticsTests.swift` (extend), docs

---

## Effort Summary

| Type | Tasks | Days |
|------|-------|------|
| backend | T1, T2, T3, T4, T5, T6, T9 | 6.5 |
| ui | T7, T8 | 1.5 |
| test + docs | T10 | 1.0 |
| **Total** | **10 tasks** | **9.0 days** |

## Execution Order

| Day | Tasks | What |
|-----|-------|------|
| 1 | T1, T6 (parallel) | Analytics events + DataExportService |
| 2-3 | T2 | AccountDeletionService orchestrator |
| 4 | T3, T4, T5 (parallel) | Supabase + CloudKit + local deletion methods |
| 5 | T7 | DeleteAccountView UI |
| 6 | T8, T9 (parallel) | ExportDataView UI + grace period check |
| 7-8 | T10 | Testing + documentation |
