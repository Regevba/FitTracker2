# 2026-06-15 Audit — Remaining Fix Specs (build/review-gated)

Three items from the full-system audit that should **not** be changed blind: each
needs a build/test environment, a contract redesign, or product sign-off. The
mechanical/low-risk fixes from the same audit already shipped as PRs #727 (secret),
#730 (timer leak), #731 (AI cleanup), #732 (cohort RLS), #733 (sync guard). This
file specs the rest so a build-capable session can execute + verify them.

---

## 1. `KeychainHelper.load` swallows the `SecItemCopyMatching` status (P2, high-risk)

**File:** `FitTracker/Services/Auth/SignInService.swift:1220-1231`

**Current:**
```swift
static func load(key: String) -> Data? {
    let q: [CFString: Any] = [ ... ]
    var result: AnyObject?
    SecItemCopyMatching(q as CFDictionary, &result)   // status discarded
    return result as? Data
}
```

**Problem:** the OSStatus is ignored, so a genuine keychain error is
indistinguishable from "item not found" — both return `nil`. The JWT item is
stored with `.userPresence` + `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly`,
so a user who **cancels Face ID** gets `errSecAuthFailed`/`errSecUserCanceled`,
`load` returns `nil`, and `restoreSession()` treats that as "no session" and
**clears the keychain** — silently logging the user out on a transient biometric
cancel.

**Why it needs care (not a blind fix):** the real fix is a **contract change** —
`load` must distinguish "absent" from "transient error" so `restoreSession` can
avoid wiping on the latter. `load(key:) -> Data?` is called from multiple sites;
changing it to `throws`/`Result` touches all of them. A logging-only change
(keep returning `nil`, just log) does NOT fix the session-wipe.

**Proposed approach:**
- Add `static func loadResult(key:) -> Result<Data?, OSStatus>` (or a small enum:
  `.found(Data)` / `.notFound` / `.error(OSStatus)`), keeping `load` as a thin
  wrapper for non-auth call sites.
- In `restoreSession()`, on `.error` (anything other than `errSecItemNotFound`),
  **do not clear the session** — surface a retryable "auth required" state instead.
- Audit all `KeychainHelper.load` call sites; only the JWT/session path needs the
  richer contract.

**Verification:** unit tests in `SignInService` passkey/session test target
simulating `errSecUserCanceled` on the JWT item; confirm session is preserved.
`xcodebuild test`. **High-risk area → extra review per CLAUDE.md.**

---

## 2. Unauthenticated cohort endpoint is write-poisonable (P1, needs product sign-off)

**File:** `ai-engine/app/routers/reminder_cohort.py:95,131`

**Problem:** `POST /reminder-cohort-event` and `GET /reminder-cohort-priors` have
**no auth and no rate limit** (intentional per spec §6 GDPR — anonymous cohort
writes). Payload is tightly validated, but any anonymous client can inflate
`reminders.shows.*` / `reminders.taps.*` counters without limit, poisoning the
tap-through priors that drive reminder timing for all users. The k≥50 floor
protects *read* privacy, not *write* integrity.

**Why it needs sign-off:** the unauthenticated design is deliberate. Adding auth
would break the GDPR-anonymous posture; the mitigation is **abuse control**, which
is a product/infra decision.

**Options (pick one):**
- **App Attest / DeviceCheck token** on the write endpoint — proves a genuine app
  install without identifying the user (keeps anonymity).
- **Anonymous IP/device rate-limit** (e.g. reuse the in-memory limiter keyed on a
  hashed client hint, or a Redis counter if multi-replica).
- **Server-side sanity caps** — reject implausible burst rates per time window.

**Verification:** load-test the chosen control; confirm legitimate single-device
write rates pass and burst-poisoning is rejected. Note the in-memory limiter is
per-process (defeated by Railway horizontal scaling) — a durable store is needed
if rate-limiting is the chosen path.

---

## 3. `DomainModels.swift` has no dedicated test suite (P1, needs build env)

**File under test:** `FitTracker/Models/DomainModels.swift` (load-bearing Codable
schema; on the high-risk list). Exercised only indirectly today — no first-class
invariant suite guarding Codable round-trips + computed properties.

**Why it needs a build env:** writing a Swift test file that references the exact
`DomainModels` initializers/properties cannot be verified without `xcodebuild`
(SourceKit single-file analysis can't resolve the module). A test file that
doesn't compile is worse than none.

**Proposed `DomainModelsTests.swift` coverage:**
- Codable round-trip (`encode` → `decode` → equality) for every persisted model:
  `UserProfile`, `UserPreferences`, `DailyLog`, `DailyBiometrics`, `WeeklySnapshot`,
  `MealTemplate`, `ImportedTrainingPlan`, `SupplementLog`.
- Forward/back-compat: decode a JSON fixture missing newer optional fields →
  defaults applied, no throw (schema-evolution guard).
- Computed-property invariants (e.g. `resolvedLogicDayKey`, derived BMI, any
  `needsSync` defaults — note `DailyLog.needsSync` defaults `true`, relevant to
  the #733 merge guard).
- `needsSync` / `lastModified` default values pinned (sync code depends on them).

**Verification:** `xcodebuild test`; add to the FitTrackerTests target in
`project.pbxproj`.

---

### Disposition
These three are tracked here rather than auto-fixed so they get the build
verification + high-risk review / product sign-off they require. Recommend a
follow-up session with simulator access for #1 and #3, and a product decision for #2.
