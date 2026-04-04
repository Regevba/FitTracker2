# Research: GDPR Compliance (Account Deletion + Data Export)

> Feature: gdpr-compliance | Phase 0 | Priority: CRITICAL (legal + App Store)
> Date: 2026-04-04

---

## 1. What is this solution?

Implement GDPR Articles 15, 17, and 20 — giving users the right to access, delete, and export all their personal data. Also satisfies Apple's 2022+ App Store mandate requiring in-app account deletion.

**Scope:**
- **Account Deletion** (Article 17) — wipe all user data from device, CloudKit, Supabase, and sever AI cohort links
- **Data Export** (Article 20) — export all user data as JSON archive
- **Data Access** (Article 15) — covered by the export feature

---

## 2. Why this approach?

**Problem:** FitMe stores encrypted health/fitness data across 6 data stores but has zero infrastructure for deletion or export. The app cannot be submitted to the EU App Store without this.

**Legal exposure:**
- GDPR fines: EUR 10–20M or 2–4% annual global turnover
- Apple App Store: removal for non-compliance (enforced since June 2024)
- User complaints to DPA trigger investigations

**Current state:**
- ❌ No account deletion logic (Settings has "Delete All Local Data" but NOT account erasure)
- ❌ No data export endpoint
- ❌ No grace period or soft-delete
- ✅ Encryption (AES-256-GCM) — Article 32 compliant
- ✅ Data minimization in AI (banded only) — Article 5 compliant
- ✅ GDPR consent flow (ConsentView) — Article 7 compliant

---

## 3. Why this over alternatives?

| Approach | Pros | Cons | Effort | Chosen? |
|----------|------|------|--------|---------|
| **Full in-app deletion + JSON export** | Apple-compliant, user-friendly, immediate, covers all 3 GDPR articles | Most effort, needs all 6 data stores | 2 weeks | **Yes** |
| **Web-only deletion portal** | Simpler backend | Apple rejects (must be in-app), bad UX | 1.5 weeks | No |
| **Email-request-only** | Minimal code | Not Apple-compliant, 30-day delay, poor UX | 0.5 weeks | No |
| **Key deletion only** | Cryptographically erases data | GDPR requires actual record deletion, not just key destruction | 0.5 weeks | No |

---

## 4. External Sources

- [GDPR Article 17 — Right to Erasure](https://gdpr-info.eu/art-17-gdpr/)
- [GDPR Article 20 — Right to Data Portability](https://gdpr-info.eu/art-20-gdpr/)
- [Apple App Store Guidelines § 5.1.1 — Account Deletion](https://developer.apple.com/app-store/review/guidelines/#data-collection-and-storage)
- [Supabase — Delete User Data](https://supabase.com/docs/guides/auth/managing-user-data)
- [CloudKit — Deleting Records](https://developer.apple.com/documentation/cloudkit/ckmodifyrecordsoperation)

---

## 5. Market Examples

| App | Deletion Flow | Export | Grace Period |
|-----|---------------|--------|--------------|
| **Strava** | In-app → email confirm → 7-day grace | JSON + CSV | 7 days |
| **MyFitnessPal** | Settings → Account → Delete → email confirm | JSON/CSV | 30 days |
| **Strong** | In-app → confirmation → immediate wipe | JSON | None |
| **Hevy** | Settings → Danger Zone → delete → email | JSON + CSV | None |

**Pattern:** Email confirmation mandatory. 7–30 day grace common. JSON standard.

---

## 6. Data Stores Audit

Every store that contains user data and must be deleted/exported:

| Store | Location | Data | Deletion Method |
|-------|----------|------|-----------------|
| **Device disk** | Local | logs.ftenc, snaps.ftenc, profile.ftenc, mealTemplates.ftenc, userPreferences.ftenc | Delete files + clear in-memory |
| **Keychain** | iOS Secure Enclave | AES-256, ChaCha20, HMAC keys | Delete keychain items |
| **UserDefaults** | Device | 15+ keys (unit system, appearance, consent, sync digests, passkey) | Remove all ft.* keys |
| **CloudKit** | iCloud Private DB | EncryptedDailyLog, EncryptedWeeklySnapshot, EncryptedUserProfile, EncryptedUserPreferences, EncryptedCardioAsset | CKModifyRecordsOperation delete per record type |
| **Supabase sync_records** | PostgreSQL | Encrypted sync blobs (all models) | DELETE WHERE user_id = ? (RLS enforced) |
| **Supabase cardio_assets** | PostgreSQL + Storage | Cardio image metadata + encrypted images | DELETE rows + remove storage objects |
| **Supabase auth.users** | Auth schema | Email, display name, session tokens | supabase.auth.admin.deleteUser() |
| **AI cohort_stats** | PostgreSQL | Anonymized frequency counts with user_id FK | Soft-delete: set user_id = NULL (anonymize) |
| **Firebase Analytics** | Google servers | Analytics events linked to user | Analytics.resetAnalyticsData() + setUserID(nil) |

---

## 7. UI Component

**Yes, this feature has UI:**
- "Delete Account" button in Settings → Account & Security
- Confirmation dialog with password/biometric re-authentication
- Grace period countdown screen ("Account scheduled for deletion on {date}")
- "Cancel Deletion" option during grace period
- "Export My Data" button in Settings → Data & Sync
- Export progress indicator + download/share sheet
- Email confirmation for deletion request

---

## 8. Technical Feasibility

**Dependencies:**
- Supabase Auth admin API (delete user)
- CloudKit CKModifyRecordsOperation (batch delete)
- EncryptionService.clearSessionContext() (already exists)
- EncryptedDataStore.clearInMemory() (already exists)
- Email service for confirmation (new — or use Supabase Auth email)

**Risks:**
- CloudKit deletion is async and may fail silently — need retry queue
- Supabase cascade delete not automatic — need explicit deletion order (cardio_assets → sync_records → auth.users)
- Grace period state needs to survive app reinstall (store in Supabase, not just UserDefaults)
- Cannot delete encryption keys as substitute for record deletion (GDPR requires actual data removal)

**Existing infrastructure to leverage:**
- `EncryptedDataStore.clearInMemory()` — already clears in-memory state
- `EncryptionService.shared.clearSessionContext()` — clears crypto session
- Settings "Delete All Local Data" button — partial implementation exists
- Supabase RLS policies — already scope all queries to user_id

---

## 9. Proposed Success Metrics

**Primary:** Account deletion completion rate — % of deletion requests that fully complete across all 6 data stores (target: 100%)

**Secondary:**
- Data export generation time — < 30 seconds for typical user (< 1000 daily logs)
- Grace period cancellation rate — % of users who cancel deletion during grace period
- App Store compliance — passes App Store review with account deletion

**Guardrails:**
- Zero data leaks during deletion (no orphaned records)
- Cold start time must not increase
- Existing sync functionality unaffected

---

## 10. Decision

**Recommended approach:** Full in-app implementation with 30-day grace period.

**Architecture:**
```
AccountDeletionService (new)
    ├── requestDeletion() → email confirm → start grace period
    ├── cancelDeletion() → remove grace period flag
    ├── executeDeletion() → triggered after grace period expires
    │   ├── deleteLocalData() → disk + keychain + UserDefaults
    │   ├── deleteCloudKit() → batch delete all record types
    │   ├── deleteSupabase() → cardio_assets → sync_records → auth.users
    │   ├── anonymizeAI() → cohort_stats user_id → NULL
    │   └── resetAnalytics() → Firebase reset + clear user ID
    └── getDeletionStatus() → pending/scheduled/completed

DataExportService (new)
    ├── generateExport() → query all stores → build JSON
    ├── encryptExport() → optional password-protected ZIP
    └── deliverExport() → share sheet or email link
```

**Effort estimate:** 2 weeks (10 working days).

**`has_ui` = true** (deletion UI + export UI in Settings)
**`requires_analytics` = true** (account_delete_requested, account_delete_completed, data_export_requested events)
