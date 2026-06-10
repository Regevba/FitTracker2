---
title: "T3 — SignInService passkey/WebAuthn unit tests (closing the highest-risk zero-coverage service)"
slug: t3-signinservice-passkey-tests
date_written: 2026-06-10
date: 2026-06-10
work_type: Feature
work_subtype: b_medium
dispatch_pattern: "operator-driven (T3 from the test-coverage master plan)"
framework_version: v7.10
state_owner: ft2
case_study_type: feature
primary_metric: "SignInService (on the CLAUDE.md high-risk list, previously zero direct tests) gains deterministic device-free unit coverage of its passkey/WebAuthn surface."
success_metrics:
  primary: "10 SignInServicePasskeyTests covering canShowPasskeyLogin config invariants + persisted SessionTokenType raw-value/Codable contract + UserSession passkey Codable round-trip; 10/10 pass on simulator."
  secondary:
    - "Mirrors AuthManagerTests' device-free scope — the ASAuthorizationController happy path is device-only and explicitly documented as out of scope."
    - "Pins the persisted SessionTokenType raw values against silent rename drift (stored sessions would break on a rename)."
kill_criteria:
  - "Tests assert against the ASAuthorizationController UI flow (would be non-deterministic / device-only)."
  - "Tests pin implementation detail rather than the behavioral/persistence contract."
kill_criteria_resolution: "Neither fired. Coverage is limited to the deterministic, environment-independent device-free surface (canShowPasskeyLogin invariants, enum/Codable persistence contracts); the system passkey UI flow is out of scope by design (documented in the test header). The first run surfaced that the test bundle ships a real relying-party ID, so the not-configured guard is unreachable — the tests were rewritten to environment-independent invariants. The SessionTokenType raw-value assertions pin a PERSISTENCE contract, not an internal detail."
tier_tags_present: true
related_prs: []
---

# T3 — SignInService Passkey/WebAuthn Unit Tests

> **Status:** shipped 2026-06-10. Closes the **highest-risk zero-coverage service** in the test-coverage inventory (RICE 48.0).

## 1. The risk

`SignInService.swift` (1244 lines) is on the [CLAUDE.md high-risk list](../../CLAUDE.md) — it owns Apple Sign In, Google, Email/OTP, **and passkey/WebAuthn** — yet had **zero direct tests**. A refactor could silently break the passkey config gating, the not-configured fallback, or the persisted token-type contract, and nothing would catch it.

## 2. What is — and isn't — unit-testable

The passkey registration/assertion flow runs through `ASAuthorizationController` (Apple's system WebAuthn UI), which needs a real device + user interaction — not unit-testable. **Exactly like `AuthManagerTests` documents for real-device biometrics, those happy paths are out of scope here.** What IS testable is the deterministic surface that gates the whole flow:

- **Config invariants** — discovered by *running* the tests: the test bundle inherits the app Info.plist, so `isPasskeyConfigured` is actually **true** in the test environment and the not-configured guard is unreachable (and calling `signInWithPasskey()`/`registerPasskey()` when configured proceeds into the device-only `ASAuthorizationController` flow, so they must not be invoked headless). The robust, environment-independent surface is the **logical invariant** `canShowPasskeyLogin ⇒ (isPasskeyConfigured ∧ hasRegisteredPasskey)` and `canShowPasskeyLogin == false` without a registered passkey.
- **Persisted contracts** — `SessionTokenType` raw values (`passkeySignature`, `supabaseJWT`, …) are stored in sessions; a rename would silently invalidate every stored passkey session on upgrade. Pinned via raw-value + Codable round-trip tests.
- **`UserSession` Codable round-trip** for a passkey session (with `credentialID`) — survives encode/decode intact.

## 3. What shipped

`FitTrackerTests/SignInServicePasskeyTests.swift` — **10 tests** (`@MainActor`, `@testable import FitTracker`, mirroring `AuthManagerTests` style), registered in `FitTracker.xcodeproj/project.pbxproj` (4 entries: PBXBuildFile + PBXFileReference + group + Sources phase). All deterministic, no UI, no network — they run as ordinary unit tests on the existing test target.

## 4. Verification

**10/10 pass** on a clean run (iPhone 17 Pro simulator). The suite is fully deterministic + device-free. The ASAuthorizationController registration/assertion happy path remains a device-only gap, documented in the test header — the honest boundary, matching the project's UI-test-thinness policy. **The first test run earned its keep**: 4 not-configured-guard tests I'd assumed would pass *failed*, surfacing that the test bundle ships a real relying-party ID — the rewrite to environment-independent invariants is the durable version.

## 5. Why this is the right scope

It would have been easy — and wrong — to mock `ASAuthorizationController` into a fake "passkey succeeds" path; that tests the mock, not the service. Pinning the **config gating + the not-configured fallback + the persisted token contract** is the part that (a) is deterministic and (b) actually protects users: if passkey silently became "configured" when it isn't, or a stored token type drifted, real sessions break. That's the surface a unit test should own.

## 6. Cross-references

- **Spec:** [`docs/master-plan/test-coverage-master-plan-2026-05-13.md`](../master-plan/test-coverage-master-plan-2026-05-13.md) §4 T3.
- **Template:** `FitTrackerTests/AuthManagerTests.swift` (device-free scope precedent).
- **Successor gap:** the ASAuthorizationController registration/assertion happy path (device-only); fitme-story-side WebAuthn route handler tests are T8.
