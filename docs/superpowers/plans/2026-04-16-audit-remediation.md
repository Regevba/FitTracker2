# Audit Remediation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix all actionable findings from the Meta-Analysis Full-System Audit (185 findings, 12 critical, 49 high, 90 medium, 25 low, 9 info)

**Architecture:** 9 phases ordered by severity × effort ratio. Phases 1–4 address critical/high security, crash, data integrity, and AI correctness bugs. Phases 5–7 address design system compliance, test coverage, and UI structure. Phase 8 fixes framework config hygiene. Phase 9 tracks large-effort items deferred to separate sprints.

**Tech Stack:** Swift, SwiftUI, XCTest, Keychain, CloudKit, Supabase, AES-GCM encryption

**Source:** `.claude/shared/audit-findings.json` (185 findings) + `docs/case-studies/meta-analysis-full-system-audit-v6.1-case-study.md`

---

## Findings Summary

| Severity | Count | Actionable | Info/Pass (no fix) |
|----------|-------|------------|-------------------|
| Critical | 12 | 12 | 0 |
| High | 49 | 49 | 0 |
| Medium | 90 | 85 | 5 |
| Low | 25 | 22 | 3 |
| Info | 9 | 2 | 7 |
| **Total** | **185** | **170** | **15** |

**Non-actionable findings (no code change needed):** FW-007, FW-008, FW-009, FW-010, FW-013, FW-015, FW-018 (all PASS/expected-state), UI-025 (deferred per backlog), UI-007 (HISTORICAL file), AI-020 (structural suggestion), BE-029 (configurable sleep goal — enhancement, not fix), DS-015 (unused tokens — document decision), DS-004/DS-009/DS-010 (token pipeline expansion — separate initiative), TEST-023/TEST-025/TEST-026 (infrastructure — separate initiative).

---

## Phase 1: Critical Security & Crash Fixes

**Priority:** IMMEDIATE — ship in next commit
**Effort:** Trivial to small
**Findings:** 4 fixes covering 7 findings

### Task 1.1: `#if DEBUG` fence on review-mode authentication

**Findings:** DEEP-AUTH-001, BE-001, BE-002
**Files:**
- Modify: `FitTracker/Services/Auth/SignInService.swift` (around line 416)

- [ ] **Step 1: Read `applyReviewSessionIfNeeded()` method**

Read the method to confirm it lacks `#if DEBUG` wrapping.

- [ ] **Step 2: Wrap entire method body in `#if DEBUG`**

```swift
func applyReviewSessionIfNeeded() {
    #if DEBUG
    // existing review-mode logic here
    guard ProcessInfo.processInfo.environment["FITTRACKER_REVIEW_AUTH"] == "authenticated" else { return }
    // ... rest of method
    #endif
}
```

- [ ] **Step 3: Build to verify compilation**

Run: `xcodebuild build -scheme FitTracker -destination 'platform=iOS Simulator,name=iPhone 16' -derivedDataPath .build/DerivedData 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add FitTracker/Services/Auth/SignInService.swift
git commit -m "fix(auth): wrap applyReviewSessionIfNeeded() in #if DEBUG — DEEP-AUTH-001"
```

---

### Task 1.2: `#if DEBUG` fence on hardcoded email verification code

**Findings:** BE-025
**Files:**
- Modify: `FitTracker/Services/EmailAuthProvider.swift`

- [ ] **Step 1: Find the hardcoded verification code**

Search for `"48291"` in the file.

- [ ] **Step 2: Wrap `LocalEmailAuthProvider` in `#if DEBUG`**

Ensure the entire `LocalEmailAuthProvider` class (or at minimum the hardcoded code path) is gated behind `#if DEBUG`.

- [ ] **Step 3: Build to verify**

- [ ] **Step 4: Commit**

```bash
git add FitTracker/Services/EmailAuthProvider.swift
git commit -m "fix(auth): gate LocalEmailAuthProvider behind #if DEBUG — BE-025"
```

---

### Task 1.3: Fix `restoreSession()` timeout double-resume crash

**Findings:** DEEP-AUTH-005, BE-005
**Files:**
- Modify: `FitTracker/Services/Auth/SignInService.swift` (around line 353)

- [ ] **Step 1: Read the `restoreSession()` method**

Locate the continuation + timeout pattern. Identify the `else` branch that lacks `timeout.cancel()`.

- [ ] **Step 2: Add `timeout.cancel()` in the nil/else branch**

```swift
} else {
    timeout.cancel()  // ← ADD THIS LINE
    continuation.resume(returning: nil)
}
```

- [ ] **Step 3: Build and run tests**

- [ ] **Step 4: Commit**

```bash
git add FitTracker/Services/Auth/SignInService.swift
git commit -m "fix(auth): cancel timeout in restoreSession nil branch — DEEP-AUTH-005"
```

---

### Task 1.4: Remove dead code

**Findings:** BE-030, BE-028
**Files:**
- Modify: `FitTracker/Services/SignInService.swift` or `FitTracker/Services/Auth/SignInService.swift`

- [ ] **Step 1: Locate `generateNonce()` and `sha256()` — confirm zero call sites**
- [ ] **Step 2: Remove both functions**
- [ ] **Step 3: Remove stale comment referencing `MockEmailAuthProvider`**
- [ ] **Step 4: Build and commit**

```bash
git commit -m "chore(auth): remove dead generateNonce/sha256 code + stale comment — BE-028, BE-030"
```

---

## Phase 2: AI Fabrication-Over-Nil Fix

**Priority:** HIGH — every AI recommendation since launch uses fabricated inputs
**Effort:** Small per adapter, medium total
**Findings:** 18 findings (DEEP-AI-001 through DEEP-AI-006, AI-002 through AI-019)

### Task 2.1: Fix ProfileAdapter — read actual user preferences

**Findings:** DEEP-AI-001, AI-004, AI-005, AI-006
**Files:**
- Modify: `FitTracker/AI/Adapters/ProfileAdapter.swift`

- [ ] **Step 1: Read ProfileAdapter.swift**

Identify the three hardcoded assignments: `genderIdentity`, `trainingDaysPerWeek`, `dietPattern`.

- [ ] **Step 2: Read UserPreferences model to find actual field names**

Check `FitTracker/Models/DomainModels.swift` or relevant model file for `UserPreferences` fields.

- [ ] **Step 3: Replace hardcoded values with Optional reads**

```swift
// BEFORE: snapshot.genderIdentity = "prefer_not_to_say"
// AFTER:
snapshot.genderIdentity = userPreferences?.genderIdentity ?? nil

// BEFORE: DayType.allCases.filter(\.isTrainingDay).count  
// AFTER:
snapshot.trainingDaysPerWeek = userPreferences?.trainingDaysPerWeek ?? nil

// BEFORE: snapshot.dietPattern = "standard"
// AFTER:
snapshot.dietPattern = userPreferences?.dietPattern ?? nil
```

Update the snapshot type to make these fields `Optional<String>` / `Optional<Int>` if they aren't already.

- [ ] **Step 4: Build and run tests**
- [ ] **Step 5: Commit**

```bash
git commit -m "fix(ai): ProfileAdapter reads actual user preferences — DEEP-AI-001, AI-004/005/006"
```

---

### Task 2.2: Fix HealthKitAdapter — stressLevel and BMI fabrication

**Findings:** DEEP-AI-002, DEEP-AI-003, AI-007, AI-008, AI-009
**Files:**
- Modify: `FitTracker/AI/Adapters/HealthKitAdapter.swift`

- [ ] **Step 1: Read HealthKitAdapter.swift**

- [ ] **Step 2: Make `stressLevel()` return `String?`, return `nil` when no log**

```swift
// BEFORE: returns "moderate" when no log
// AFTER:
func stressLevel() -> String? {
    guard let recentLog = /* fetch recent stress log */ else { return nil }
    // ... existing mapping
}
```

- [ ] **Step 3: Add BMI plausibility bounds and staleness guard**

```swift
// Add bounds check
guard heightCm >= 100, heightCm <= 250, weightKg >= 30, weightKg <= 300 else { return nil }
// Remove startWeightKg fallback — return nil instead
```

- [ ] **Step 4: Update `contribute()` to propagate nil through to snapshot**

- [ ] **Step 5: Build and run tests**
- [ ] **Step 6: Commit**

```bash
git commit -m "fix(ai): HealthKitAdapter returns nil instead of fabricating — DEEP-AI-002/003, AI-007/008/009"
```

---

### Task 2.3: Fix NutritionAdapter — mealsPerDay inflation

**Findings:** DEEP-AI-004, AI-010
**Files:**
- Modify: `FitTracker/AI/Adapters/NutritionAdapter.swift`

- [ ] **Step 1: Read NutritionAdapter.swift**
- [ ] **Step 2: Return nil when completed meal count is zero**

```swift
// BEFORE: falls back to latestNutrition?.meals.count (includes planned)
// AFTER: return nil when no completed meals
guard completedMealCount > 0 else { return nil }
```

- [ ] **Step 3: Build, test, commit**

```bash
git commit -m "fix(ai): NutritionAdapter returns nil for zero completed meals — DEEP-AI-004, AI-010"
```

---

### Task 2.4: Fix TrainingAdapter — duration estimation

**Findings:** DEEP-AI-005, AI-017
**Files:**
- Modify: `FitTracker/AI/Adapters/TrainingAdapter.swift`

- [ ] **Step 1: Read TrainingAdapter.swift**
- [ ] **Step 2: Use logged session duration when available, improve heuristic when not**

```swift
// BEFORE: max(20, exerciseLogs.count * 10)
// AFTER: use actual duration if available
let sessionMinutes = log.durationMinutes ?? max(20, log.exerciseLogs.count * 15)
// Also fix weeklyActiveMinutes to use the same logic
```

- [ ] **Step 3: Build, test, commit**

```bash
git commit -m "fix(ai): TrainingAdapter uses logged duration, better heuristic — DEEP-AI-005, AI-017"
```

---

### Task 2.5: Fix AIOrchestrator and AITypes miscellaneous bugs

**Findings:** AI-001, AI-002, AI-011, AI-012, AI-013, AI-014, AI-015, AI-018, AI-019
**Files:**
- Modify: `FitTracker/AI/AIOrchestrator.swift`
- Modify: `FitTracker/AI/AITypes.swift`
- Modify: `FitTracker/AI/FoundationModelService.swift`
- Modify: `FitTracker/AI/AISnapshotBuilder.swift`

- [ ] **Step 1: AI-001 — Add `#available(iOS 26, *)` guard before `adapt()` calls in AIOrchestrator**
- [ ] **Step 2: AI-002 — Fix misleading docstring in FoundationModelService (Tier 3, not Tier 2)**
- [ ] **Step 3: AI-011 — Fix `lastAdapters` empty on first `process()` — build adapters inside process() or make setAdapters() a precondition**
- [ ] **Step 4: AI-012 — Lift `isProcessing` lifecycle to `processAll()`, suppress in individual `process()` calls**
- [ ] **Step 5: AI-013 — Add lightweight JWT expiry check (decode base64 payload, check `exp` claim)**
- [ ] **Step 6: AI-014 — Align `localFallback` GoalMode string: `"Fat Loss"` → `"weight_loss"`**
- [ ] **Step 7: AI-015 — Add `case 0` to `trainingDaysWeekBand()` switch — return `"0"` or `"rest_week"`**
- [ ] **Step 8: AI-018 — Lower placeholder confidence from 0.8 to 0.5, add `#warning("Placeholder")`**
- [ ] **Step 9: AI-019 — `AnyCodable` fallback: throw `DecodingError.dataCorruptedError` instead of `value = ""`**
- [ ] **Step 10: Build and run full test suite**
- [ ] **Step 11: Commit**

```bash
git commit -m "fix(ai): orchestrator/types bug sweep — AI-001/002/011-015/018/019"
```

---

### Task 2.6: Fix RecommendationMemory misleading header

**Findings:** AI-003
**Files:**
- Modify: `FitTracker/AI/RecommendationMemory.swift`

- [ ] **Step 1: Remove 'encrypted' claim from header comment — it uses plain UserDefaults**
- [ ] **Step 2: Commit**

```bash
git commit -m "fix(ai): remove misleading 'encrypted store' claim from RecommendationMemory — AI-003"
```

---

### Task 2.7: Fix RecommendationMemory performance

**Findings:** AI-016
**Files:**
- Modify: `FitTracker/AI/RecommendationMemory.swift`

- [ ] **Step 1: Replace 4-pass `enforceLimit()` with dictionary-keyed O(1) eviction**
- [ ] **Step 2: Build, test, commit**

```bash
git commit -m "perf(ai): O(1) eviction in RecommendationMemory — AI-016"
```

---

## Phase 3: Sync & Data Integrity

**Priority:** HIGH — data loss risk on multi-device usage
**Effort:** Small to medium per fix
**Findings:** 22 findings

### Task 3.1: CloudKit daily log `needsSync` guard

**Findings:** DEEP-SYNC-003, BE-018
**Files:**
- Modify: `FitTracker/Services/CloudKit/CloudKitSyncService.swift`

- [ ] **Step 1: Read the daily log merge method**
- [ ] **Step 2: Add `needsSync` guard matching `mergeWeeklySnapshot()` pattern**

```swift
// Add before overwriting local with remote:
guard !localLog.needsSync else {
    // Local has unsaved edits — skip remote overwrite
    return
}
```

- [ ] **Step 3: Build, test, commit**

```bash
git commit -m "fix(sync): CloudKit daily log merge respects needsSync — DEEP-SYNC-003, BE-018"
```

---

### Task 3.2: Don't advance `lastPull` past decryption failures

**Findings:** DEEP-SYNC-002, BE-010
**Files:**
- Modify: `FitTracker/Services/Supabase/SupabaseSyncService.swift`

- [ ] **Step 1: Read the pull loop and identify where lastPull is set**
- [ ] **Step 2: Track failed row timestamps; set lastPull to min(success timestamps) excluding failures**

```swift
var oldestFailure: Date? = nil
// In catch block:
catch {
    oldestFailure = min(oldestFailure ?? row.modifiedAt, row.modifiedAt)
    logger.error("Decryption failed for row \(row.id): \(error)")
}
// After loop:
if let oldest = oldestFailure {
    lastPull = oldest.addingTimeInterval(-1) // re-fetch from before failure
} else {
    lastPull = latestSuccessTimestamp
}
```

- [ ] **Step 3: Build, test, commit**

```bash
git commit -m "fix(sync): don't advance lastPull past decryption failures — DEEP-SYNC-002, BE-010"
```

---

### Task 3.3: Fix `needsSync = false` before `persistToDisk()` race

**Findings:** DEEP-SYNC-004, BE-017
**Files:**
- Modify: `FitTracker/Services/CloudKit/CloudKitSyncService.swift`

- [ ] **Step 1: Use `markSynced()` API instead of direct array mutation**

```swift
// BEFORE: dataStore.dailyLogs[idx].needsSync = false
// AFTER: await dataStore.markSynced(at: idx)
```

Or set `needsSync = false` only after `persistToDisk()` succeeds.

- [ ] **Step 2: Build, test, commit**

```bash
git commit -m "fix(sync): set needsSync=false only after persist succeeds — DEEP-SYNC-004, BE-017"
```

---

### Task 3.4: Fix singleton checksum computed from ciphertext

**Findings:** DEEP-SYNC-005, BE-026
**Files:**
- Modify: `FitTracker/Services/Supabase/SupabaseSyncService.swift`

- [ ] **Step 1: Read `pushSingletons()` and find where checksum is computed**
- [ ] **Step 2: Compute checksum from plaintext (pre-encryption) instead of ciphertext**

```swift
// BEFORE: let checksum = sha256(encryptedData)
// AFTER: let checksum = sha256(plaintextData)
// Then encrypt after checksum comparison
```

- [ ] **Step 3: Build, test, commit**

```bash
git commit -m "fix(sync): compute singleton checksum from plaintext — DEEP-SYNC-005, BE-026"
```

---

### Task 3.5: Add realtime event debounce

**Findings:** DEEP-SYNC-007, BE-011
**Files:**
- Modify: `FitTracker/Services/Supabase/SupabaseSyncService.swift`

- [ ] **Step 1: Add a 500ms debounce on realtime events**

```swift
private var realtimeDebounceTask: Task<Void, Never>?

func handleRealtimeEvent(_ event: RealtimeEvent) {
    realtimeDebounceTask?.cancel()
    realtimeDebounceTask = Task {
        try? await Task.sleep(for: .milliseconds(500))
        guard !Task.isCancelled else { return }
        await fetchChanges()
    }
}
```

- [ ] **Step 2: Build, test, commit**

```bash
git commit -m "fix(sync): debounce realtime events to prevent concurrent fetches — DEEP-SYNC-007, BE-011"
```

---

### Task 3.6: Fix `fetchAllRecords()` on every session change

**Findings:** DEEP-SYNC-008
**Files:**
- Modify: `FitTracker/Services/Supabase/SupabaseSyncService.swift`

- [ ] **Step 1: Only call `fetchAllRecords()` on first login (no existing lastPull)**

```swift
// In session change handler:
if lastPull == nil {
    await fetchAllRecords()  // First login — full pull
} else {
    await fetchChanges()     // Session refresh — incremental only
}
```

- [ ] **Step 2: Build, test, commit**

```bash
git commit -m "fix(sync): fetchAllRecords only on first login, fetchChanges on refresh — DEEP-SYNC-008"
```

---

### Task 3.7: Fix `deleteAllUserRecords()` digest and batch cleanup

**Findings:** DEEP-SYNC-009, BE-019
**Files:**
- Modify: `FitTracker/Services/Supabase/SupabaseSyncService.swift`
- Modify: `FitTracker/Services/CloudKit/CloudKitSyncService.swift`

- [ ] **Step 1: Clear all Supabase-prefixed UserDefaults keys during account deletion**
- [ ] **Step 2: Replace sequential CloudKit deletes with `CKModifyRecordsOperation` batches of 400**
- [ ] **Step 3: Build, test, commit**

```bash
git commit -m "fix(sync): clear Supabase digests on deletion + batch CloudKit deletes — DEEP-SYNC-009, BE-019"
```

---

### Task 3.8: Fix `cloudRecordID` persistence atomicity

**Findings:** DEEP-SYNC-014
**Files:**
- Modify: `FitTracker/Services/CloudKit/CloudKitSyncService.swift`

- [ ] **Step 1: Persist `cloudRecordID` as part of the same write that marks `needsSync = false`**
- [ ] **Step 2: Build, test, commit**

```bash
git commit -m "fix(sync): persist cloudRecordID atomically with needsSync — DEEP-SYNC-014"
```

---

### Task 3.9: Fix `pushPendingChanges()` error handling and auth validation

**Findings:** DEEP-SYNC-015, BE-007, BE-008
**Files:**
- Modify: `FitTracker/Services/Supabase/SupabaseSyncService.swift`

- [ ] **Step 1: Add error logging and failed-record identification in push catch block**

```swift
catch {
    logger.error("Push failed for record \(record.id): \(error)")
    failedRecordIDs.append(record.id)
    anyFailed = true
}
```

- [ ] **Step 2: Replace `try?` on `supabase.auth.session` with explicit error handling**

```swift
// BEFORE: guard let session = try? await supabase.auth.session else { return }
// AFTER:
let session: Session
do {
    session = try await supabase.auth.session
} catch {
    logger.error("Auth session expired: \(error)")
    // Trigger re-auth flow
    return
}
```

- [ ] **Step 3: Re-validate session between push iterations**
- [ ] **Step 4: Build, test, commit**

```bash
git commit -m "fix(sync): push error logging + auth session validation — DEEP-SYNC-015, BE-007/008"
```

---

### Task 3.10: Namespace UserDefaults keys by userID

**Findings:** BE-004, BE-009, BE-012
**Files:**
- Modify: `FitTracker/Services/Supabase/SupabaseSyncService.swift`
- Modify: `FitTracker/Services/Auth/SignInService.swift`

- [ ] **Step 1: Create a helper to namespace UserDefaults keys**

```swift
private func userScopedKey(_ base: String) -> String {
    guard let userID = currentUserID else { return base }
    return "\(userID).\(base)"
}
```

- [ ] **Step 2: Apply to `lastPull`, singleton digest keys, and `hasRegisteredPasskey`**
- [ ] **Step 3: Add migration: copy old un-namespaced values to new namespaced keys on first launch**
- [ ] **Step 4: Build, test, commit**

```bash
git commit -m "fix(sync): namespace UserDefaults keys by userID — BE-004/009/012"
```

---

### Task 3.11: Singleton conflict resolution with timestamps

**Findings:** DEEP-SYNC-006, DEEP-SYNC-012
**Files:**
- Modify: `FitTracker/Models/DomainModels.swift`
- Modify: `FitTracker/Services/Supabase/SupabaseSyncService.swift`

- [ ] **Step 1: Add `lastModified: Date?` to `UserProfile` and `UserPreferences`**
- [ ] **Step 2: Update mutation sites to set `lastModified = Date()`**
- [ ] **Step 3: Use timestamp comparison in `applyRemoteSingleton()` for conflict resolution**
- [ ] **Step 4: Build, test, commit**

```bash
git commit -m "fix(sync): add lastModified to singletons for conflict resolution — DEEP-SYNC-006/012"
```

---

### Task 3.12: Add `schemaVersion` to DailyLog

**Findings:** DEEP-SYNC-013
**Files:**
- Modify: `FitTracker/Models/DomainModels.swift`

- [ ] **Step 1: Add `schemaVersion: Int = 1` to `DailyLog`**
- [ ] **Step 2: Add version check on decode with migration path**
- [ ] **Step 3: Build, test, commit**

```bash
git commit -m "fix(sync): add schemaVersion to DailyLog for encrypted blob migration — DEEP-SYNC-013"
```

---

### Task 3.13: Fix `deleteAllUserData()` compensation + GDPR

**Findings:** DEEP-SYNC-011, BE-023, BE-024
**Files:**
- Modify: `FitTracker/Services/Supabase/SupabaseSyncService.swift`
- Modify: `FitTracker/Services/AccountDeletionService.swift`

- [ ] **Step 1: Add compensation logging for partial deletion failures**
- [ ] **Step 2: Sync deletion grace period to Supabase (not just local UserDefaults)**
- [ ] **Step 3: Delete Supabase Auth user record as part of account deletion**
- [ ] **Step 4: Build, test, commit**

```bash
git commit -m "fix(gdpr): complete account deletion — sync grace period, delete auth user — DEEP-SYNC-011, BE-023/024"
```

---

### Task 3.14: CloudKit cardio image forwarding to Supabase

**Findings:** DEEP-SYNC-010
**Files:**
- Modify: `FitTracker/Services/CloudKit/CloudKitSyncService.swift`
- Modify: `FitTracker/Services/Supabase/SupabaseSyncService.swift`

- [ ] **Step 1: When CloudKit receives a CKAsset, extract image data**
- [ ] **Step 2: Upload to Supabase Storage as encrypted blob**
- [ ] **Step 3: Include Supabase storage reference in the sync record**
- [ ] **Step 4: Build, test, commit**

```bash
git commit -m "fix(sync): forward CloudKit cardio images to Supabase Storage — DEEP-SYNC-010"
```

---

## Phase 4: Auth & Encryption Hardening

**Priority:** HIGH — security and data loss prevention
**Effort:** Small to medium per fix
**Findings:** 16 findings

### Task 4.1: Fix passkey userID decode — hard guard, not fallback

**Findings:** DEEP-AUTH-003
**Files:**
- Modify: `FitTracker/Services/Auth/SignInService.swift` (line ~819)

- [ ] **Step 1: Replace fallback to `pendingUserHandle` with a hard `guard`**

```swift
guard let userID = String(data: cred.userID, encoding: .utf8) else {
    throw AuthError.invalidPasskeyUserID
}
```

- [ ] **Step 2: Build, test, commit**

```bash
git commit -m "fix(auth): hard guard on passkey userID decode — DEEP-AUTH-003"
```

---

### Task 4.2: Session token type safety

**Findings:** DEEP-AUTH-004
**Files:**
- Modify: `FitTracker/Services/Auth/SignInService.swift`
- Possibly modify: `FitTracker/Models/DomainModels.swift` (UserSession)

- [ ] **Step 1: Add `SessionTokenType` enum**

```swift
enum SessionTokenType: String, Codable {
    case supabaseJWT
    case debugSimulator
    case reviewMode
}
```

- [ ] **Step 2: Add `tokenType` field to `UserSession`**
- [ ] **Step 3: Set token type at each creation site**
- [ ] **Step 4: Build, test, commit**

```bash
git commit -m "fix(auth): add SessionTokenType enum for type-safe tokens — DEEP-AUTH-004"
```

---

### Task 4.3: Simulator bypass — call `setSessionContext()`

**Findings:** DEEP-AUTH-007
**Files:**
- Modify: `FitTracker/Services/AuthManager.swift` (line ~37)

- [ ] **Step 1: Add `setSessionContext(LAContext())` in simulator block**
- [ ] **Step 2: Build, test, commit**

```bash
git commit -m "fix(auth): simulator bypass calls setSessionContext — DEEP-AUTH-007"
```

---

### Task 4.4: Fix `rotateKeys()` atomicity

**Findings:** DEEP-AUTH-008, BE-014
**Files:**
- Modify: `FitTracker/Services/Encryption/EncryptionService.swift` (line ~276)

- [ ] **Step 1: Add `isRotating` actor flag to prevent concurrent encrypt() during rotation**
- [ ] **Step 2: Bundle all 3 Keychain key saves into a single operation (or save-then-rotate pattern)**
- [ ] **Step 3: Build, test, commit**

```bash
git commit -m "fix(encryption): atomic key rotation with isRotating guard — DEEP-AUTH-008, BE-014"
```

---

### Task 4.5: HMAC timestamp validation

**Findings:** DEEP-AUTH-009, BE-013
**Files:**
- Modify: `FitTracker/Services/Encryption/EncryptionService.swift` (line ~116)

- [ ] **Step 1: Decode timestamp from HMAC data and validate against max-age (e.g., 365 days)**
- [ ] **Step 2: Use canonical bigEndian encoding instead of bitPattern**
- [ ] **Step 3: Build, test, commit**

```bash
git commit -m "fix(encryption): validate HMAC timestamp for max-age — DEEP-AUTH-009, BE-013"
```

---

### Task 4.6: Keychain race condition and persistence fixes

**Findings:** DEEP-AUTH-010, DEEP-AUTH-011, BE-016, BE-020, BE-027
**Files:**
- Modify: `FitTracker/Services/Encryption/EncryptionService.swift`
- Modify: `FitTracker/Services/Auth/SignInService.swift`

- [ ] **Step 1: Replace delete-then-add with SecItemUpdate-first pattern (DEEP-AUTH-010)**
- [ ] **Step 2: Implement atomic file writes using .tmp + `FileManager.replaceItemAt` (DEEP-AUTH-011)**
- [ ] **Step 3: Add retry mechanism for `persistToDisk()` failures (BE-016)**
- [ ] **Step 4: Check `SecItemAdd` return status in `KeychainHelper.save()` (BE-020)**
- [ ] **Step 5: Make `encrypt()` fail if keys were explicitly deleted (BE-027)**
- [ ] **Step 6: Build, test, commit**

```bash
git commit -m "fix(encryption): atomic Keychain ops + persistent writes — DEEP-AUTH-010/011, BE-016/020/027"
```

---

### Task 4.7: Password exposure and sign-out ordering

**Findings:** DEEP-AUTH-012, DEEP-AUTH-013, DEEP-AUTH-014, BE-003
**Files:**
- Modify: `FitTracker/Services/Auth/SignInService.swift`
- Modify: `FitTracker/Services/AuthManager.swift`

- [ ] **Step 1: Remove `password` from `PendingEmailRegistration` Codable struct — pass as separate parameter (DEEP-AUTH-012)**
- [ ] **Step 2: Fix `evaluatePolicy` weak self — capture result before Task (DEEP-AUTH-013)**
- [ ] **Step 3: Fix sign-out ordering: broadcast cancellation → await Supabase signOut → clear local state (DEEP-AUTH-014, BE-003)**
- [ ] **Step 4: Handle signOut error, consider `.global` scope**
- [ ] **Step 5: Build, test, commit**

```bash
git commit -m "fix(auth): password exposure, weak self race, sign-out ordering — DEEP-AUTH-012/013/014, BE-003"
```

---

### Task 4.8: Biometric enrollment data protection

**Findings:** BE-015
**Files:**
- Modify: `FitTracker/Services/Encryption/EncryptionService.swift`

- [ ] **Step 1: Replace `.biometryCurrentSet` with `.biometryAny`**

Or implement a key recovery mechanism that survives biometric re-enrollment.

- [ ] **Step 2: Build, test, commit**

```bash
git commit -m "fix(encryption): use .biometryAny to survive biometric re-enrollment — BE-015"
```

---

### Task 4.9: Continuation leak and JWT storage

**Findings:** BE-022, DEEP-AUTH-006, BE-021
**Files:**
- Modify: `FitTracker/Services/SupabaseAppleAuthProvider.swift`
- Modify: `FitTracker/Services/Auth/SignInService.swift`

- [ ] **Step 1: Resume previous continuation with cancellation error before overwriting (BE-022)**

```swift
func startSignIn() async throws -> AppleSignInResult {
    // Cancel any pending sign-in
    continuation?.resume(throwing: CancellationError())
    // ...
}
```

- [ ] **Step 2: Separate JWT into its own Keychain item with tighter ACL (BE-021, DEEP-AUTH-006)**
- [ ] **Step 3: Build, test, commit**

```bash
git commit -m "fix(auth): fix continuation leak + separate JWT Keychain storage — BE-022, DEEP-AUTH-006, BE-021"
```

---

### Task 4.10: Checksums in Keychain

**Findings:** DEEP-AUTH-015
**Files:**
- Modify: `FitTracker/Services/Encryption/EncryptionService.swift`

- [ ] **Step 1: Move three-way merge checksums from UserDefaults to Keychain**
- [ ] **Step 2: Build, test, commit**

```bash
git commit -m "fix(encryption): move merge checksums to Keychain — DEEP-AUTH-015"
```

---

## Phase 5: Design System Token Compliance

**Priority:** MEDIUM — consistency and accessibility
**Effort:** Low to medium (mostly mechanical replacement)
**Findings:** 20 findings

### Task 5.1: Migrate 66 deprecated `Color.status.*`/`Color.accent.*` calls

**Findings:** DS-002
**Files:**
- Modify: `FitTracker/Views/Training/TrainingPlanView.swift` (35 calls — HISTORICAL, if still compiled)
- Modify: `FitTracker/Views/Nutrition/NutritionView.swift` (11 calls — HISTORICAL)
- Modify: remaining 6 files with deprecated calls

- [ ] **Step 1: Global search for `Color.status.` and `Color.accent.` across all compiled views**
- [ ] **Step 2: Replace each with `AppColor.Status.*` and `AppColor.Accent.*` equivalents**
- [ ] **Step 3: Delete the deprecated extension block from AppTheme.swift**
- [ ] **Step 4: Build, test, commit**

```bash
git commit -m "fix(ds): migrate 66 deprecated Color.status/accent calls — DS-002"
```

---

### Task 5.2: Migrate 26 deprecated `Color.appOrange*`/`Color.appBlue*` calls

**Findings:** DS-003
**Files:**
- Modify: `FitTracker/Views/Main/v2/MainScreenView.swift`
- Modify: `FitTracker/Views/Stats/StatsView.swift`
- Modify: `FitTracker/Views/Auth/AuthHubView.swift`
- Modify: remaining files with deprecated calls

- [ ] **Step 1: Global search for `Color.appOrange`, `Color.appBlue`, `Color.appSurface`, `Color.appStroke`**
- [ ] **Step 2: Replace: `appOrange1→AppColor.Brand.warmSoft`, `appBlue2→AppColor.Brand.secondary`, etc.**
- [ ] **Step 3: Delete deprecated extension block**
- [ ] **Step 4: Build, test, commit**

```bash
git commit -m "fix(ds): migrate 26 deprecated Color.app* calls — DS-003"
```

---

### Task 5.3: Replace hardcoded font sizes with AppText tokens

**Findings:** DS-001, DS-005, DS-006, DS-012, UI-008, UI-009, UI-010, UI-011, UI-012, UI-013, UI-014, UI-021, UI-022
**Files:**
- Modify: `FitTracker/Views/Main/v2/MainScreenView.swift` (12 calls)
- Modify: `FitTracker/Views/Onboarding/v2/OnboardingWelcomeView.swift`
- Modify: `FitTracker/Views/Onboarding/v2/OnboardingFirstActionView.swift`
- Modify: `FitTracker/Views/Profile/ProfileView.swift`
- Modify: `FitTracker/Views/Shared/LockedFeatureOverlay.swift`
- Modify: `FitTracker/Views/Nutrition/MealEntrySheet.swift`
- Modify: `FitTracker/Views/Main/BodyCompositionCard.swift`
- Modify: `FitTracker/Views/Shared/AppDesignSystemComponents.swift`
- Modify: `FitTracker/Views/RootTabView.swift`
- Modify: `FitTracker/Services/AppTheme.swift` (DS-012: metricM font)

- [ ] **Step 1: Map each hardcoded size to the appropriate AppText token**

| Size | Token |
|------|-------|
| 22pt icon | `AppText.iconMedium` |
| 28pt icon | `AppText.iconLarge` |
| 32pt | `AppText.hero` or new `AppText.brandWordmark` |
| 36pt | `AppText.hero` |
| 40pt | `AppText.iconXL` |
| 56pt | `AppText.iconDisplay` |

- [ ] **Step 2: Add `AppText.brandWordmark` token if needed for 32pt onboarding**
- [ ] **Step 3: Fix DS-012: replace `Font.custom("SF Pro Rounded")` with `Font.system(design: .rounded)`**
- [ ] **Step 4: Replace all 9 hardcoded icon sizes (DS-006)**
- [ ] **Step 5: Replace raw shadow literals with `AppShadow` tokens in `AppDesignSystemComponents` (UI-014)**
- [ ] **Step 6: Fix `LockedFeatureOverlay` fixed width → `maxWidth` (UI-011)**
- [ ] **Step 7: Fix deprecated `.foregroundColor(.white)` → `.foregroundStyle(AppColor.Text.inversePrimary)` (UI-012)**
- [ ] **Step 8: Build, test, commit**

```bash
git commit -m "fix(ds): replace hardcoded fonts/shadows/colors with tokens — DS-001/005/006/012, UI-008-014/021/022"
```

---

### Task 5.4: Replace ad-hoc animation literals with AppMotion tokens

**Findings:** DS-007
**Files:**
- Modify: Files with inline `.animation()` calls (MainScreenView, AppDesignSystemComponents, etc.)

- [ ] **Step 1: Map each literal to AppSpring/AppEasing token**

| Literal | Token |
|---------|-------|
| `.easeOut(duration: 0.35)` | `AppEasing.snappy` |
| `.easeOut(duration: 0.5)` | `AppEasing.smooth` |
| `.easeOut(duration: 0.6)` | `AppEasing.progress` |
| Spring literals | `AppSpring.*` |

- [ ] **Step 2: Replace all 10 instances**
- [ ] **Step 3: Build, test, commit**

```bash
git commit -m "fix(ds): replace 10 ad-hoc animation literals with AppMotion tokens — DS-007"
```

---

### Task 5.5: Replace inline progress bars with ProgressBar component

**Findings:** DS-008
**Files:**
- Modify: `FitTracker/Views/Nutrition/NutritionView.swift` (if compiled v2 version)

- [ ] **Step 1: Replace 2 inline GeometryReader progress bars with `ProgressBar` component**
- [ ] **Step 2: Build, test, commit**

```bash
git commit -m "fix(ds): replace inline progress bars with ProgressBar component — DS-008"
```

---

### Task 5.6: Replace inline opacity literals with AppOpacity tokens

**Findings:** DS-011
**Files:**
- Modify: Views with `.opacity(0.12)`, `.opacity(0.15)`, `.opacity(0.08)` calls

- [ ] **Step 1: Replace `0.12 → AppOpacity.subtle`, `0.15 → AppOpacity.disabled`, `0.08 → AppOpacity.hover`**
- [ ] **Step 2: Build, test, commit**

```bash
git commit -m "fix(ds): replace opacity magic numbers with AppOpacity tokens — DS-011"
```

---

### Task 5.7: Add `AppColor.Overlay.scrim` token

**Findings:** DS-013
**Files:**
- Modify: `FitTracker/Services/AppTheme.swift`
- Modify: `FitTracker/Views/Shared/LockedFeatureOverlay.swift`

- [ ] **Step 1: Add `AppColor.Overlay.scrim = Color.black.opacity(0.4)` to AppTheme**
- [ ] **Step 2: Replace raw literal in LockedFeatureOverlay**
- [ ] **Step 3: Build, test, commit**

```bash
git commit -m "fix(ds): add AppColor.Overlay.scrim token — DS-013"
```

---

### Task 5.8: Replace hardcoded padding with AppSize token

**Findings:** DS-014
**Files:**
- Modify: `FitTracker/Views/Training/TrainingPlanView.swift` (if compiled)

- [ ] **Step 1: Replace `56` with `AppSize.tabBarClearance`**
- [ ] **Step 2: Build, test, commit**

```bash
git commit -m "fix(ds): use AppSize.tabBarClearance instead of literal 56 — DS-014"
```

---

### Task 5.9: Accessibility labels

**Findings:** UI-019, UI-020
**Files:**
- Modify: `FitTracker/Views/AI/AIInsightCard.swift`
- Modify: `FitTracker/Views/Shared/LockedFeatureOverlay.swift`

- [ ] **Step 1: Add `.accessibilityLabel("Helpful")` and `.accessibilityLabel("Not helpful")` to thumbs buttons**
- [ ] **Step 2: Add `.accessibilityHint("Dismisses the upgrade prompt")` to "Maybe later" button**
- [ ] **Step 3: Build, test, commit**

```bash
git commit -m "fix(a11y): add accessibility labels to AI feedback + overlay dismiss — UI-019/020"
```

---

## Phase 6: Test Coverage

**Priority:** MEDIUM — high-risk files have zero tests
**Effort:** Medium to high per test file
**Findings:** 30 findings

### Task 6.1: Fix phantom tests (asserting local arithmetic)

**Findings:** TEST-018, TEST-019, TEST-020, TEST-021, TEST-022
**Files:**
- Modify: `FitTrackerTests/FitTrackerCoreTests.swift`
- Modify: `FitTrackerTests/EvalTests/AITierBehaviorEvals.swift`
- Modify: `FitTrackerTests/NotificationTests.swift`
- Modify: `FitTrackerTests/SupabaseTests/SyncMergeTests.swift`

- [ ] **Step 1: TEST-018 — Assert WCAG opacity against actual `AppColor.Text.tertiary` value**
- [ ] **Step 2: TEST-019 — Iterate over `AppSpacing.allValues` instead of hardcoded array**
- [ ] **Step 3: TEST-020 — Write black-box test: AIOrchestrator with confidence 0.39 vs 0.41**
- [ ] **Step 4: TEST-021 — Test against production `isQuietHour()` method (make internal)**
- [ ] **Step 5: TEST-022 — Add same-timestamp tie-breaking and nil-modifiedAt tests**
- [ ] **Step 6: Run test suite**
- [ ] **Step 7: Commit**

```bash
git commit -m "fix(tests): phantom tests now assert against production code — TEST-018/019/020/021/022"
```

---

### Task 6.2: Extract duplicated test helper

**Findings:** TEST-029
**Files:**
- Modify: `FitTrackerTests/EvalTests/AIOutputQualityEvals.swift`
- Modify: `FitTracker/Views/AI/AIInsightCard.swift`

- [ ] **Step 1: Extract `humanReadableSignal` as `internal static` function in production code**
- [ ] **Step 2: Call production function from eval test**
- [ ] **Step 3: Build, test, commit**

```bash
git commit -m "fix(tests): AIOutputQualityEvals calls production humanReadableSignal — TEST-029"
```

---

### Task 6.3: Fix non-deterministic test helper

**Findings:** TEST-030
**Files:**
- Modify: `FitTrackerTests/ReadinessEngineTests.swift`

- [ ] **Step 1: Replace `Double.random()` with deterministic offsets in `makeLogs()`**
- [ ] **Step 2: Build, test, commit**

```bash
git commit -m "fix(tests): deterministic makeLogs helper — TEST-030"
```

---

### Task 6.4: Add EncryptionService tests

**Findings:** TEST-001
**Files:**
- Create: `FitTrackerTests/EncryptionServiceTests.swift`

- [ ] **Step 1: Write tests for: round-trip encrypt/decrypt, wrong-key rejection, IV uniqueness, empty-data edge, corrupted-ciphertext handling, keychain key regeneration**
- [ ] **Step 2: Build, run tests, commit**

```bash
git commit -m "test(encryption): add EncryptionServiceTests — TEST-001"
```

---

### Task 6.5: Add AuthManager tests

**Findings:** TEST-002
**Files:**
- Create: `FitTrackerTests/AuthManagerTests.swift`

- [ ] **Step 1: Write tests for: initial state, authentication transition, lock/unlock cycle, session expiry, concurrent sign-in protection**
- [ ] **Step 2: Build, run tests, commit**

```bash
git commit -m "test(auth): add AuthManagerTests — TEST-002"
```

---

### Task 6.6: Add CloudKitSyncService tests

**Findings:** TEST-003
**Files:**
- Create: `FitTrackerTests/CloudKitSyncServiceTests.swift`

- [ ] **Step 1: Create mock CKDatabase**
- [ ] **Step 2: Write tests for: zone setup, record serialization, conflict resolution, offline queue**
- [ ] **Step 3: Build, run tests, commit**

```bash
git commit -m "test(sync): add CloudKitSyncServiceTests — TEST-003"
```

---

### Task 6.7: Add SupabaseSyncService tests

**Findings:** TEST-004
**Files:**
- Create: `FitTrackerTests/SupabaseSyncServiceTests.swift`

- [ ] **Step 1: Create mock URLSession or Supabase client**
- [ ] **Step 2: Write tests for: successful pull, 401 retry, network timeout, empty-delta, merge dispatch**
- [ ] **Step 3: Build, run tests, commit**

```bash
git commit -m "test(sync): add SupabaseSyncServiceTests — TEST-004"
```

---

### Task 6.8: Add HealthKitService tests

**Findings:** TEST-005
**Files:**
- Create: `FitTrackerTests/HealthKitServiceTests.swift`

- [ ] **Step 1: Create mock HKHealthStore**
- [ ] **Step 2: Write tests for: permission grant/deny, HRV mapping, nil-data degradation**
- [ ] **Step 3: Build, run tests, commit**

```bash
git commit -m "test(healthkit): add HealthKitServiceTests — TEST-005"
```

---

### Task 6.9: Add AI adapter and service tests

**Findings:** TEST-006, TEST-007, TEST-008, TEST-009, TEST-010
**Files:**
- Create: `FitTrackerTests/AIAdaptersTests.swift`
- Create: `FitTrackerTests/AIOrchestratorTests.swift`
- Create: `FitTrackerTests/RecommendationMemoryTests.swift`
- Create: `FitTrackerTests/ValidatedRecommendationTests.swift`

- [ ] **Step 1: Add golden I/O tests for each adapter (edge cases: zero meals, nil biometrics, no training logs)**
- [ ] **Step 2: Add orchestrator tests: cloud call, adaptation threshold, error recovery**
- [ ] **Step 3: Add memory tests: store/retrieve, TTL expiry, segment isolation, clear()**
- [ ] **Step 4: Add validation tests: valid passes, below-threshold fails, empty signals fails**
- [ ] **Step 5: Build, run tests, commit**

```bash
git commit -m "test(ai): add adapter, orchestrator, memory, validation tests — TEST-006/007/008/009/010"
```

---

### Task 6.10: Add remaining service tests

**Findings:** TEST-011, TEST-012, TEST-013, TEST-014, TEST-015, TEST-016, TEST-017
**Files:**
- Modify/Create test files for: AccountDeletionService, WatchConnectivityService, NotificationService, ReminderScheduler, AppSettings, TrainingProgramStore, GoalProfile

- [ ] **Step 1: AccountDeletionService — full deletion, partial failure, grace period (TEST-011)**
- [ ] **Step 2: WatchConnectivityService — activation, messaging, applicationContext (TEST-012)**
- [ ] **Step 3: NotificationService — scheduleNotification(), permission flow, daily cap, quiet hours (TEST-013)**
- [ ] **Step 4: ReminderScheduler — schedule(), lifetime cap, canSchedule(), trigger evaluation (TEST-014)**
- [ ] **Step 5: AppSettings — defaults, UserDefaults round-trip (TEST-015)**
- [ ] **Step 6: TrainingProgramStore — phase advancement, exercise list, set templates (TEST-016)**
- [ ] **Step 7: GoalProfile — from each NutritionGoalMode, default when nil (TEST-017)**
- [ ] **Step 8: Build, run tests, commit**

```bash
git commit -m "test: add coverage for AccountDeletion, Watch, Notifications, Reminders, AppSettings, Training, Goal — TEST-011-017"
```

---

### Task 6.11: Add performance and import edge-case tests

**Findings:** TEST-024, TEST-027, TEST-028
**Files:**
- Modify: `FitTrackerTests/ImportTests.swift`
- Create: `FitTrackerTests/PerformanceTests.swift`

- [ ] **Step 1: Add malformed CSV, non-numeric values, unknown fields, and `measure()` performance tests for Import (TEST-024)**
- [ ] **Step 2: Add `measure()` tests: ReadinessEngine with 90 logs (<50ms), EncryptedDataStore load/save (<100ms) (TEST-027)**
- [ ] **Step 3: Add basic accessibility tests: interactive elements have labels, min 44x44pt (TEST-028)**
- [ ] **Step 4: Build, run tests, commit**

```bash
git commit -m "test: import edge cases, performance benchmarks, accessibility basics — TEST-024/027/028"
```

---

## Phase 7: UI Structure & Cleanup

**Priority:** MEDIUM-LOW — code quality, not user-facing bugs
**Effort:** Trivial to medium
**Findings:** 10 findings

### Task 7.1: Archive historical v1 files

**Findings:** UI-001, UI-003, UI-005
**Files:**
- Move: `FitTracker/Views/Training/TrainingPlanView.swift` → `_historical/`
- Move: `FitTracker/Views/Nutrition/NutritionView.swift` → `_historical/`
- Move: `FitTracker/Views/Settings/SettingsView.swift` → `_historical/`

- [ ] **Step 1: Create `_historical/` directory if it doesn't exist**
- [ ] **Step 2: Move 3 v1 files (ensure they're already removed from build target)**
- [ ] **Step 3: Update project.pbxproj to remove file references**
- [ ] **Step 4: Build, commit**

```bash
git commit -m "chore(ui): archive 3 HISTORICAL v1 files — UI-001/003/005"
```

---

### Task 7.2: Remove/wire dead views

**Findings:** UI-015, UI-016, UI-024
**Files:**
- `FitTracker/Views/Import/ImportSourcePickerView.swift`
- `FitTracker/Views/Import/ImportPreviewView.swift`
- `FitTracker/Views/Notifications/NotificationPermissionPrimingView.swift`
- `FitTracker/Views/AI/AIInsightCard.swift`

- [ ] **Step 1: Decide: wire dead import views into nav, or remove them**
- [ ] **Step 2: Wire or remove NotificationPermissionPrimingView**
- [ ] **Step 3: Wire `RecommendationOutcome` to `RecommendationMemory` or remove dead construction (UI-024)**
- [ ] **Step 4: Build, commit**

```bash
git commit -m "chore(ui): wire or remove dead views — UI-015/016/024"
```

---

### Task 7.3: SettingsView v2 decomposition (optional — large refactor)

**Findings:** UI-002
**Files:**
- Modify: `FitTracker/Views/Settings/v2/SettingsView.swift`

- [ ] **Step 1: Extract each category destination to its own file**
- [ ] **Step 2: SettingsView becomes ~200-line router**
- [ ] **Step 3: Build, test, commit**

```bash
git commit -m "refactor(ui): decompose SettingsView v2 into category files — UI-002"
```

---

### Task 7.4: MainScreenView ViewModel extraction (optional)

**Findings:** UI-006, UI-018
**Files:**
- Create: `FitTracker/Views/Main/v2/HomeViewModel.swift`
- Modify: `FitTracker/Views/Main/v2/MainScreenView.swift`

- [ ] **Step 1: Extract milestone detection and 12 @State properties to HomeViewModel**
- [ ] **Step 2: Wire ViewModel into MainScreenView**
- [ ] **Step 3: Build, test, commit**

```bash
git commit -m "refactor(ui): extract HomeViewModel from MainScreenView — UI-006/018"
```

---

## Phase 8: Framework Config Hygiene

**Priority:** LOW — measurement integrity and config consistency
**Effort:** Trivial per fix
**Findings:** 10 findings

### Task 8.1: Version alignment and manifest fixes

**Findings:** FW-001, FW-002, FW-003, FW-004, FW-006
**Files:**
- Modify: `.claude/shared/audit-findings.json`
- Modify: `.claude/shared/framework-manifest.json`
- Modify: `.claude/shared/token-budget.json`
- Modify: `.claude/shared/cache-metrics.json`

- [ ] **Step 1: Align all `framework_version` fields to `6.1`**
- [ ] **Step 2: Update `framework-manifest.json` description to say v6.1**
- [ ] **Step 3: Update `structure.shared_files` count to 25**
- [ ] **Step 4: Fix or remove misleading `model` field in token-budget.json**
- [ ] **Step 5: Add `framework_version` field to cache-metrics.json**
- [ ] **Step 6: Commit**

```bash
git commit -m "chore(framework): align versions and manifest — FW-001/002/003/004/006"
```

---

### Task 8.2: Fix stale monitoring entries and timestamps

**Findings:** FW-016, FW-019, FW-020
**Files:**
- Modify: `.claude/shared/case-study-monitoring.json`

- [ ] **Step 1: Update dispatch-intelligence-v5.2 and parallel-write-safety-v5.2 to `status: complete`, framework_version: 6.1**
- [ ] **Step 2: Fix inverted timestamps (started_at > updated_at)**
- [ ] **Step 3: Document denominator explicitly for 80% vs 75% accuracy discrepancy**
- [ ] **Step 4: Commit**

```bash
git commit -m "chore(framework): fix stale monitoring entries and timestamps — FW-016/019/020"
```

---

### Task 8.3: Delete dead artifact

**Findings:** FW-017
**Files:**
- Delete: `.claude/shared/v52-dispatch-log.json`

- [ ] **Step 1: Delete the orphaned file**
- [ ] **Step 2: Commit**

```bash
git commit -m "chore(framework): remove orphaned v52-dispatch-log.json — FW-017"
```

---

### Task 8.4: Fix cache discovery and measurement

**Findings:** FW-005, FW-011, FW-012, FW-014
**Files:**
- Modify: `.claude/skills/*/SKILL.md` (measurement trigger)
- Modify: Cache write logic to populate `_index.json`

- [ ] **Step 1: Fix cache indexing — populate `_index.json` entries array on every cache write**
- [ ] **Step 2: Fix measurement trigger in SKILL.md — update `cache-metrics.json` on feature completion**
- [ ] **Step 3: Backfill cache-metrics from existing case study data**
- [ ] **Step 4: Run a manual Phase 0 health check to populate `framework-health.json`**
- [ ] **Step 5: Commit**

```bash
git commit -m "fix(framework): cache discovery + measurement triggers — FW-005/011/012/014"
```

---

## Phase 9: Large-Effort Deferred Items

**Priority:** Tracked for separate sprints — not part of this remediation pass
**Effort:** Large

These items require significant architectural work and should be planned as separate features:

| Finding | Title | Effort | Recommendation |
|---------|-------|--------|----------------|
| DEEP-AUTH-002, BE-006 | Server-side passkey WebAuthn verification | Large | Requires Supabase Edge Function deployment. Separate sprint. |
| DEEP-SYNC-001 | Dual-sync coordination (CloudKit + Supabase) | Large | Architectural decision: sequence or merge coordinator. Separate sprint. |
| UI-004, UI-017 | MealEntrySheet decomposition + ViewModel | Large | 1155 lines, 17 @State, 4 tabs. Full v2 refactor candidate. |
| DS-004, DS-009, DS-010 | Token pipeline expansion + dark mode | High | ~40% token categories missing from CI pipeline. Separate initiative. |
| TEST-023 | Network mocking infrastructure | High | URLProtocol-based stub for all sync/auth tests. Foundation for TEST-003/004. |
| TEST-025 | XCUITest suite | High | New test target + critical user journeys. |
| TEST-026 | Snapshot tests | High | swift-snapshot-testing integration for 13 DS components. |

---

## Execution Summary

| Phase | Tasks | Findings Resolved | Effort | Priority |
|-------|-------|-------------------|--------|----------|
| 1. Critical Security & Crash | 4 | 7 | Trivial–Small | IMMEDIATE |
| 2. AI Fabrication Fix | 7 | 18 | Small–Medium | HIGH |
| 3. Sync & Data Integrity | 14 | 22 | Small–Medium | HIGH |
| 4. Auth & Encryption Hardening | 10 | 16 | Small–Medium | HIGH |
| 5. Design System Tokens | 9 | 20 | Low–Medium | MEDIUM |
| 6. Test Coverage | 11 | 30 | Medium–High | MEDIUM |
| 7. UI Structure & Cleanup | 4 | 10 | Trivial–Medium | MEDIUM-LOW |
| 8. Framework Config | 4 | 10 | Trivial | LOW |
| 9. Deferred | — | 7+ | Large | FUTURE |
| **Total** | **63 tasks** | **140+ findings** | | |

Remaining ~30 findings are info-severity, pass-state, or already addressed as root causes of other findings.
