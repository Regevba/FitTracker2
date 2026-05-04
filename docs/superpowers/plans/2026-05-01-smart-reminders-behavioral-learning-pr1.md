# Smart Reminders — Behavioral Learning PR 1 (Data Layer + Toggle-Off) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the data-collection foundation of the behavioral-learning sub-feature with zero user-visible behaviour change. Cohort writes start accumulating in production. Resolver and automation come in PR 2 (separate plan).

**Architecture:** Three new on-device Swift services (`BehavioralLearningStore`, `CohortPriorClient`, `CohortPriorCache`) record per-user observations and fetch the server-side cohort prior. The existing `ReminderNotificationDelegate` is extended to call `BehavioralLearningStore.recordObservation` alongside the existing analytics events from PR #158. A new global "Smart timing" toggle in Settings is wired up but **defaults off** — the toggle reads/writes `AppSettings.smartTimingEnabled` but has no consumer until PR 2 lands. Two new AI-engine endpoints reuse the existing Supabase `cohort_stats` table + `increment_cohort_frequency` RPC; one new migration extends the existing pg_cron retention job. No new tables, no new authentication paths.

**Tech Stack:** Swift 5.9+ (iOS 17+), SwiftUI, XCTest, UserNotifications, UserDefaults; Python (Railway-hosted AI engine, FastAPI); Supabase Postgres + pg_cron; existing GA4 event taxonomy.

**Predecessor PRs:** PR #98 (parent feature shipped) + PR #158 (six lifecycle analytics events; merged 2026-04-30). Both already on `main`.

**Reference:** `docs/superpowers/specs/2026-05-01-smart-reminders-behavioral-learning-design.md` is the source of truth for design decisions.

---

## File Structure

### New Swift files (PR 1)

| Path | Responsibility |
|---|---|
| `FitTracker/Services/Reminders/BehavioralLearningStore.swift` | Per-user posterior over 24 hour-of-day buckets per personalisable type. Pure logic + UserDefaults persistence. No network. |
| `FitTracker/Services/Reminders/CohortPriorClient.swift` | HTTP client for `/reminder-cohort-event` + `/reminder-cohort-priors`. Reuses `AIEngineClient` URL pattern. |
| `FitTracker/Services/Reminders/CohortPriorCache.swift` | On-device cache of the cohort prior (7-day TTL). Persists single JSON blob to UserDefaults. |
| `FitTracker/Views/Settings/BehavioralLearningSettingsView.swift` | Settings → Notifications: one global "Smart timing" toggle row. Defaults off. (PR 3 will add per-type "Why?" rows below it.) |
| `FitTrackerTests/BehavioralLearningStoreTests.swift` | Bayesian math, denominator/numerator separation, persistence, per-type isolation. |
| `FitTrackerTests/CohortPriorClientTests.swift` | No-PII-in-payload, network-error silent catch, response shape. |
| `FitTrackerTests/CohortPriorCacheTests.swift` | TTL, malformed-JSON recovery, round-trip. |

### Modified Swift files (PR 1)

| Path | Change |
|---|---|
| `FitTracker/Services/Reminders/ReminderType.swift` | Add `defaultPriorDistribution: [Hour: Double]` static property per case (used as Bayesian prior fallback). |
| `FitTracker/Services/Reminders/ReminderNotificationDelegate.swift` | Extend `willPresent` to call `store.recordObservation(tapped: false)` (denominator) and `client.recordEvent`. Extend `didReceive` to upgrade observation on tap. |
| `FitTracker/FitTrackerApp.swift` | Instantiate `BehavioralLearningStore` + `CohortPriorCache` on app launch; fire-and-forget `client.fetchPriors()` once per session (cache-TTL guarded); inject store reference into `ReminderNotificationDelegate`. |
| `FitTracker/Services/AppSettings.swift` (or equivalent settings model) | Add `@AppStorage var smartTimingEnabled: Bool = false`. Defaults off in PR 1. |
| `FitTracker/Services/EncryptedDataStore.swift` (or wherever GDPR delete lives) | Extend `deleteAllUserData()` to wipe `BehavioralLearningStore` keys. |
| `FitTracker/FitTracker.xcodeproj/project.pbxproj` | Register new Swift files in Sources build phase. |

### New backend artifacts (PR 1)

| Path | Change |
|---|---|
| `backend/supabase/migrations/000009_extend_retention_for_reminders.sql` | Extend pg_cron retention job to cover `segment LIKE 'reminders.%'`. |
| AI-engine repo (Railway): `app/api/reminder_cohort.py` (new module) | `POST /reminder-cohort-event` and `GET /reminder-cohort-priors`. |
| AI-engine repo: `app/tests/test_reminder_cohort.py` | pytest for both endpoints. |

### State + meta artifacts (PR 1)

| Path | Change |
|---|---|
| `.claude/features/smart-reminders-behavioral-learning/state.json` | Advance `current_phase` from `research` → `tasks` (start) → `implementation` (after Task 16) → `test`/`review`/`merge` (after PR opens). |
| `.claude/logs/smart-reminders-behavioral-learning.log.json` | Phase-transition events at each `current_phase` change. |

---

## Tasks

### Task 1: Pre-work — advance state.json from `research` to `tasks`

**Files:**
- Modify: `.claude/features/smart-reminders-behavioral-learning/state.json`
- Modify: `.claude/logs/smart-reminders-behavioral-learning.log.json`

- [ ] **Step 1: Update state.json `current_phase` and add timing entry**

```bash
python3 -c "
import json
from datetime import datetime, timezone
path = '.claude/features/smart-reminders-behavioral-learning/state.json'
d = json.load(open(path))
now = datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z')
d['current_phase'] = 'tasks'
d['updated'] = now
d['phases']['research']['status'] = 'complete'
d['phases']['research']['ended_at'] = now
d['phases']['tasks'] = {'status': 'in_progress', 'started_at': now}
d['timing']['phases']['research']['ended_at'] = now
d['timing']['phases']['tasks'] = {'started_at': now, 'ended_at': None, 'duration_minutes': None, 'paused_minutes': 0}
json.dump(d, open(path, 'w'), indent=2)
"
```

- [ ] **Step 2: Append phase-transition log entry**

```bash
python3 scripts/append-feature-log.py \
  --feature smart-reminders-behavioral-learning \
  --event-type phase_started \
  --phase tasks \
  --summary "Tasks phase started 2026-05-01. Spec at docs/superpowers/specs/2026-05-01-smart-reminders-behavioral-learning-design.md. Plan at docs/superpowers/plans/2026-05-01-smart-reminders-behavioral-learning-pr1.md."
```

- [ ] **Step 3: Validate the state.json**

Run: `python3 scripts/check-state-schema.py .claude/features/smart-reminders-behavioral-learning/state.json`
Expected: `✓ All 1 state.json files pass all checks`

- [ ] **Step 4: Commit**

```bash
git add .claude/features/smart-reminders-behavioral-learning/state.json .claude/logs/smart-reminders-behavioral-learning.log.json
git commit -m "chore(smart-reminders-behavioral-learning): advance phase research → tasks"
```

---

### Task 2: Add `defaultPriorDistribution` to `ReminderType`

**Files:**
- Modify: `FitTracker/Services/Reminders/ReminderType.swift`
- Test: (covered transitively by `BehavioralLearningStoreTests` in Task 4)

The existing `ReminderType` enum has a static `defaultFireHour` per case. We need a `defaultPriorDistribution: [Int: Double]` per case — a tight bell curve around the default fire hour, summing to 1.0. This is the Bayesian prior fallback when the cohort prior cache is cold.

- [ ] **Step 1: Open `FitTracker/Services/Reminders/ReminderType.swift` and locate the existing `defaultFireHour` accessor**

```swift
// Existing code, for context:
var defaultFireHour: Int {
    switch self {
    case .nutritionGap: return 16
    case .trainingDay:  return 10
    case .restDay:      return 8
    case .healthKitConnect:    return 11
    case .accountRegistration: return 14
    case .engagement:          return 18
    }
}
```

- [ ] **Step 2: Add `defaultPriorDistribution` immediately after `defaultFireHour`**

```swift
/// Tight bell curve over the 24 hour-of-day buckets, centred on `defaultFireHour`.
/// Used as the Bayesian prior fallback when the cohort prior cache is cold.
/// Sums to 1.0. σ = 1.5 hours (gives ~80% of mass within ±2 hours of centre).
var defaultPriorDistribution: [Int: Double] {
    let centre = Double(defaultFireHour)
    let sigma  = 1.5
    var raw: [Int: Double] = [:]
    for h in 0..<24 {
        let dx = Double(h) - centre
        raw[h] = exp(-(dx * dx) / (2 * sigma * sigma))
    }
    let total = raw.values.reduce(0, +)
    return raw.mapValues { $0 / total }
}
```

- [ ] **Step 3: Add `import Foundation` if not already present** (`exp` requires it; existing imports likely cover this — verify)

```bash
head -10 FitTracker/Services/Reminders/ReminderType.swift
```

- [ ] **Step 4: Build to verify compilation**

Run: `xcodebuild build -project FitTracker.xcodeproj -scheme FitTracker -destination 'generic/platform=iOS Simulator' -quiet`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add FitTracker/Services/Reminders/ReminderType.swift
git commit -m "feat(smart-reminders): add ReminderType.defaultPriorDistribution (Bayesian prior fallback)"
```

---

### Task 3: Implement `BehavioralLearningStore` (Bayesian math + persistence)

**Files:**
- Create: `FitTracker/Services/Reminders/BehavioralLearningStore.swift`
- Test:   `FitTrackerTests/BehavioralLearningStoreTests.swift`
- Modify: `FitTracker/FitTracker.xcodeproj/project.pbxproj` (Sources build phase entries)

This is the core data structure: per-user, per-type rolling histogram of `(hour, tap_through)` outcomes, with a posterior accessor that combines observed counts.

- [ ] **Step 1: Create `FitTrackerTests/BehavioralLearningStoreTests.swift` with the 0-observations test** (write the failing test first)

```swift
// FitTrackerTests/BehavioralLearningStoreTests.swift
import XCTest
@testable import FitTracker

@MainActor
final class BehavioralLearningStoreTests: XCTestCase {

    private let storeKeyPrefix = "ft.reminder.posterior."
    private let countKeyPrefix = "ft.reminder.obsCount."

    override func setUp() {
        super.setUp()
        clearAllStoreDefaults()
    }

    override func tearDown() {
        clearAllStoreDefaults()
        super.tearDown()
    }

    func testPosteriorWithZeroObservations_isUniform() {
        let store = BehavioralLearningStore()
        let posterior = store.posterior(type: .nutritionGap)
        // With zero observations, posterior is uniform across 24 hours
        XCTAssertEqual(posterior.count, 24)
        for h in 0..<24 {
            XCTAssertEqual(posterior[h] ?? 0, 1.0 / 24.0, accuracy: 0.0001)
        }
        XCTAssertEqual(store.observationCount(type: .nutritionGap), 0)
    }

    private func clearAllStoreDefaults() {
        let defaults = UserDefaults.standard
        for type in ReminderType.allCases {
            for h in 0..<24 {
                let suffix = String(format: "%02d", h)
                defaults.removeObject(forKey: "\(storeKeyPrefix)\(type.rawValue).h\(suffix)")
            }
            defaults.removeObject(forKey: "\(countKeyPrefix)\(type.rawValue)")
        }
    }
}
```

- [ ] **Step 2: Create the empty `BehavioralLearningStore.swift` shell so the test compiles**

```swift
// FitTracker/Services/Reminders/BehavioralLearningStore.swift
// Per-user posterior over 24 hour-of-day buckets per personalisable ReminderType.
// Persistence: UserDefaults keys ft.reminder.posterior.<type>.h<00..23> + ft.reminder.obsCount.<type>.

import Foundation

@MainActor
final class BehavioralLearningStore {

    private let defaults: UserDefaults
    private let storeKeyPrefix = "ft.reminder.posterior."
    private let countKeyPrefix = "ft.reminder.obsCount."

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Returns the per-hour distribution for a type. Uniform when zero observations recorded.
    func posterior(type: ReminderType) -> [Int: Double] {
        var dist: [Int: Double] = [:]
        for h in 0..<24 { dist[h] = 1.0 / 24.0 }
        return dist
    }

    /// Number of observations recorded for a type.
    func observationCount(type: ReminderType) -> Int {
        return 0
    }
}
```

- [ ] **Step 3: Add both files to `project.pbxproj`** (so the test can find the type)

The pattern (mirror what was done for `ReminderNotificationDelegate.swift`/`ReminderAnalyticsTests.swift` in PR #158):

In `project.pbxproj`, in the PBXBuildFile section near other Reminder entries (around the `RM*` IDs), add:

```
		BL1000001000000000000001 /* BehavioralLearningStore.swift in Sources */ = {isa = PBXBuildFile; fileRef = BL2000001000000000000001 /* BehavioralLearningStore.swift */; };
		BL100000000000000000AT01 /* BehavioralLearningStoreTests.swift in Sources */ = {isa = PBXBuildFile; fileRef = BL200000000000000000AT01 /* BehavioralLearningStoreTests.swift */; };
```

In the PBXFileReference section, add:

```
		BL2000001000000000000001 /* BehavioralLearningStore.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = BehavioralLearningStore.swift; sourceTree = "<group>"; };
		BL200000000000000000AT01 /* BehavioralLearningStoreTests.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = BehavioralLearningStoreTests.swift; sourceTree = "<group>"; };
```

In the Reminders PBXGroup children list (near where `ReminderNotificationDelegate.swift` appears), add `BL2000001000000000000001 /* BehavioralLearningStore.swift */,`. In the Tests PBXGroup, add `BL200000000000000000AT01 /* BehavioralLearningStoreTests.swift */,`. In the FitTracker target's Sources PBXBuildPhase children, add `BL1000001000000000000001 /* BehavioralLearningStore.swift in Sources */,`. In the FitTrackerTests target's Sources PBXBuildPhase children, add `BL100000000000000000AT01 /* BehavioralLearningStoreTests.swift in Sources */,`.

- [ ] **Step 4: Run the test to confirm it passes (the shell happens to satisfy the 0-obs case)**

Run: `xcodebuild test -project FitTracker.xcodeproj -scheme FitTracker -destination 'generic/platform=iOS Simulator' -only-testing FitTrackerTests/BehavioralLearningStoreTests/testPosteriorWithZeroObservations_isUniform 2>&1 | tail -10`
Expected: `Test Suite 'BehavioralLearningStoreTests' passed`

- [ ] **Step 5: Add the `recordObservation` test (denominator path)**

Append to `BehavioralLearningStoreTests.swift`:

```swift
func testRecordObservation_incrementsCountForType() {
    let store = BehavioralLearningStore()
    store.recordObservation(type: .nutritionGap, hour: 16, tapped: false)
    XCTAssertEqual(store.observationCount(type: .nutritionGap), 1)
    XCTAssertEqual(store.observationCount(type: .trainingDay), 0,
                   "Per-type isolation: nutritionGap obs must NOT count toward trainingDay")
}
```

- [ ] **Step 6: Run to confirm it FAILS** (`recordObservation` doesn't exist yet)

Run: `xcodebuild test -project FitTracker.xcodeproj -scheme FitTracker -destination 'generic/platform=iOS Simulator' -only-testing FitTrackerTests/BehavioralLearningStoreTests/testRecordObservation_incrementsCountForType 2>&1 | tail -10`
Expected: build error `value of type 'BehavioralLearningStore' has no member 'recordObservation'`

- [ ] **Step 7: Implement `recordObservation` (minimal — just count)**

Replace `BehavioralLearningStore.swift` body methods with:

```swift
    func posterior(type: ReminderType) -> [Int: Double] {
        let count = observationCount(type: type)
        guard count > 0 else {
            var uniform: [Int: Double] = [:]
            for h in 0..<24 { uniform[h] = 1.0 / 24.0 }
            return uniform
        }
        // Each bucket = (taps in that hour) / (total observations)
        var dist: [Int: Double] = [:]
        for h in 0..<24 {
            let tapsKey = tapsKey(type: type, hour: h)
            let taps = defaults.integer(forKey: tapsKey)
            dist[h] = Double(taps) / Double(count)
        }
        return dist
    }

    func observationCount(type: ReminderType) -> Int {
        defaults.integer(forKey: "\(countKeyPrefix)\(type.rawValue)")
    }

    /// Records a `shown` event (denominator). `tapped` is initially false; call
    /// `upgradeLastObservation` after a tap to promote the same observation
    /// to a tap (numerator). Returns the observation's stable id so callers
    /// can pass it to `upgradeLastObservation`.
    @discardableResult
    func recordObservation(type: ReminderType, hour: Int, tapped: Bool) -> String {
        precondition((0..<24).contains(hour), "hour must be 0..<24")
        let countKey = "\(countKeyPrefix)\(type.rawValue)"
        defaults.set(defaults.integer(forKey: countKey) + 1, forKey: countKey)
        if tapped {
            let tapsKey = tapsKey(type: type, hour: hour)
            defaults.set(defaults.integer(forKey: tapsKey) + 1, forKey: tapsKey)
        }
        // Stash the (type, hour) of the last observation so upgrade can find it.
        defaults.set(["type": type.rawValue, "hour": hour, "tapped": tapped],
                     forKey: lastObsKey)
        return "\(type.rawValue):\(hour):\(Date().timeIntervalSince1970)"
    }

    private func tapsKey(type: ReminderType, hour: Int) -> String {
        let suffix = String(format: "%02d", hour)
        return "\(storeKeyPrefix)\(type.rawValue).h\(suffix)"
    }

    private let lastObsKey = "ft.reminder.lastObservation"
```

- [ ] **Step 8: Run the new test plus the original — both should pass**

Run: `xcodebuild test -project FitTracker.xcodeproj -scheme FitTracker -destination 'generic/platform=iOS Simulator' -only-testing FitTrackerTests/BehavioralLearningStoreTests 2>&1 | tail -15`
Expected: 2 tests passed

- [ ] **Step 9: Add `upgradeLastObservation` test (numerator promotion + idempotence)**

```swift
func testUpgradeLastObservation_promotesShowToTap_andIsIdempotent() {
    let store = BehavioralLearningStore()
    store.recordObservation(type: .nutritionGap, hour: 16, tapped: false)
    XCTAssertEqual(store.observationCount(type: .nutritionGap), 1)

    store.upgradeLastObservation(type: .nutritionGap, tapped: true)
    let posterior1 = store.posterior(type: .nutritionGap)
    XCTAssertEqual(posterior1[16] ?? 0, 1.0, accuracy: 0.0001,
                   "Single observation upgraded to tap: bucket 16 holds 100% of mass")

    // Calling upgrade twice for the SAME observation must NOT double-count
    store.upgradeLastObservation(type: .nutritionGap, tapped: true)
    let posterior2 = store.posterior(type: .nutritionGap)
    XCTAssertEqual(posterior1, posterior2, "Idempotent upgrade")
    XCTAssertEqual(store.observationCount(type: .nutritionGap), 1)
}
```

- [ ] **Step 10: Run to confirm FAIL** (`upgradeLastObservation` doesn't exist)

Run: `xcodebuild test -project FitTracker.xcodeproj -scheme FitTracker -destination 'generic/platform=iOS Simulator' -only-testing FitTrackerTests/BehavioralLearningStoreTests/testUpgradeLastObservation_promotesShowToTap_andIsIdempotent 2>&1 | tail -10`
Expected: build error `value of type 'BehavioralLearningStore' has no member 'upgradeLastObservation'`

- [ ] **Step 11: Implement `upgradeLastObservation` with idempotence guard**

Add to `BehavioralLearningStore.swift`:

```swift
    /// Promotes the most recent `shown` observation to a `tap`. Idempotent —
    /// if the last observation is already marked tapped, this is a no-op.
    /// Used by ReminderNotificationDelegate.didReceive when the user taps.
    func upgradeLastObservation(type: ReminderType, tapped: Bool) {
        guard tapped else { return }  // only handle "promote to tap"
        guard let last = defaults.dictionary(forKey: lastObsKey) else { return }
        guard let recordedTypeRaw = last["type"] as? String,
              let recordedTypeRaw_ = ReminderType(rawValue: recordedTypeRaw),
              recordedTypeRaw_ == type,
              let hour = last["hour"] as? Int else { return }
        let alreadyTapped = (last["tapped"] as? Bool) ?? false
        guard !alreadyTapped else { return }  // idempotent

        // Promote: increment taps[hour], DO NOT increment obsCount (it was already incremented at recordObservation)
        let tapsK = tapsKey(type: type, hour: hour)
        defaults.set(defaults.integer(forKey: tapsK) + 1, forKey: tapsK)
        defaults.set(["type": type.rawValue, "hour": hour, "tapped": true],
                     forKey: lastObsKey)
    }
```

- [ ] **Step 12: Run all `BehavioralLearningStoreTests` to confirm 3/3 pass**

Run: `xcodebuild test -project FitTracker.xcodeproj -scheme FitTracker -destination 'generic/platform=iOS Simulator' -only-testing FitTrackerTests/BehavioralLearningStoreTests 2>&1 | tail -10`
Expected: 3 tests passed

- [ ] **Step 13: Add `deleteAllUserData` test (GDPR wipe)**

```swift
func testDeleteAllUserData_wipesAllStoreKeys() {
    let store = BehavioralLearningStore()
    store.recordObservation(type: .nutritionGap, hour: 16, tapped: true)
    store.upgradeLastObservation(type: .nutritionGap, tapped: true)
    XCTAssertEqual(store.observationCount(type: .nutritionGap), 1)

    store.deleteAllUserData()
    XCTAssertEqual(store.observationCount(type: .nutritionGap), 0)
    let posterior = store.posterior(type: .nutritionGap)
    for h in 0..<24 {
        XCTAssertEqual(posterior[h] ?? 0, 1.0 / 24.0, accuracy: 0.0001,
                       "After wipe, posterior is uniform again")
    }
}
```

- [ ] **Step 14: Run to confirm FAIL**

Run: `xcodebuild test -project FitTracker.xcodeproj -scheme FitTracker -destination 'generic/platform=iOS Simulator' -only-testing FitTrackerTests/BehavioralLearningStoreTests/testDeleteAllUserData_wipesAllStoreKeys 2>&1 | tail -10`
Expected: `value of type 'BehavioralLearningStore' has no member 'deleteAllUserData'`

- [ ] **Step 15: Implement `deleteAllUserData`**

Add to `BehavioralLearningStore.swift`:

```swift
    /// GDPR Article 17 — right to erasure. Wipes all behavioural-learning
    /// state from UserDefaults. Called by EncryptedDataStore.deleteAllUserData()
    /// (Task 11).
    func deleteAllUserData() {
        for type in ReminderType.allCases {
            defaults.removeObject(forKey: "\(countKeyPrefix)\(type.rawValue)")
            for h in 0..<24 {
                defaults.removeObject(forKey: tapsKey(type: type, hour: h))
            }
        }
        defaults.removeObject(forKey: lastObsKey)
    }
```

- [ ] **Step 16: Run all tests — 4/4 pass**

Run: `xcodebuild test -project FitTracker.xcodeproj -scheme FitTracker -destination 'generic/platform=iOS Simulator' -only-testing FitTrackerTests/BehavioralLearningStoreTests 2>&1 | tail -10`
Expected: 4 tests passed

- [ ] **Step 17: Commit**

```bash
git add FitTracker/Services/Reminders/BehavioralLearningStore.swift FitTrackerTests/BehavioralLearningStoreTests.swift FitTracker.xcodeproj/project.pbxproj
git commit -m "feat(smart-reminders): BehavioralLearningStore — per-user posterior + GDPR wipe

Pure logic + UserDefaults persistence. Records denominator (shown) on
willPresent, upgrades to numerator (tap) on didReceive. Idempotent
upgrade. Per-type isolation. deleteAllUserData() satisfies Article 17.

Tests cover: 0-obs uniform posterior, recordObservation increments, idempotent
upgradeLastObservation, deleteAllUserData wipes everything."
```

---

### Task 4: Implement `CohortPriorClient` (HTTP client + no-PII assertion)

**Files:**
- Create: `FitTracker/Services/Reminders/CohortPriorClient.swift`
- Test:   `FitTrackerTests/CohortPriorClientTests.swift`
- Modify: `FitTracker.xcodeproj/project.pbxproj`

The client wraps two HTTP calls: `POST /reminder-cohort-event` (fire-and-forget write) and `GET /reminder-cohort-priors` (read). Reuses `AIEngineClient`'s URL pattern.

- [ ] **Step 1: Create `CohortPriorClientTests.swift` with the no-PII test (write the failing test)**

```swift
// FitTrackerTests/CohortPriorClientTests.swift
import XCTest
@testable import FitTracker

@MainActor
final class CohortPriorClientTests: XCTestCase {

    func testRecordEvent_payloadContainsOnlyAllowedKeys() async throws {
        let session = MockURLSession()
        let client = CohortPriorClient(baseURL: URL(string: "https://test.local")!, session: session)

        try await client.recordEvent(type: .nutritionGap, hour: 16, tapped: true)

        let request = try XCTUnwrap(session.lastRequest)
        let body = try XCTUnwrap(request.httpBody)
        let json = try JSONSerialization.jsonObject(with: body) as? [String: Any] ?? [:]

        // The ONLY allowed keys: type, hour, tapped. No userId, no deviceId, no locale, no timestamp.
        XCTAssertEqual(Set(json.keys), Set(["type", "hour", "tapped"]),
                       "Payload must contain only {type, hour, tapped} — no PII")
        XCTAssertEqual(json["type"] as? String, "nutrition_gap")
        XCTAssertEqual(json["hour"] as? Int, 16)
        XCTAssertEqual(json["tapped"] as? Bool, true)
    }
}

/// Test double — captures the most recent request without hitting the network.
private final class MockURLSession: URLSessionProtocol {
    var lastRequest: URLRequest?
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        let response = HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!
        return (Data(), response)
    }
}
```

- [ ] **Step 2: Run to confirm FAIL** (`CohortPriorClient` doesn't exist)

Run: `xcodebuild test -project FitTracker.xcodeproj -scheme FitTracker -destination 'generic/platform=iOS Simulator' -only-testing FitTrackerTests/CohortPriorClientTests 2>&1 | tail -10`
Expected: build error referencing `CohortPriorClient`

- [ ] **Step 3: Create `CohortPriorClient.swift` with the minimal implementation + injected URLSession**

```swift
// FitTracker/Services/Reminders/CohortPriorClient.swift
// HTTP client for the AI-engine reminder-cohort endpoints.
// Two methods: recordEvent (POST, fire-and-forget) and fetchPriors (GET).
// All errors are caught and re-thrown — callers may swallow as appropriate.

import Foundation

protocol URLSessionProtocol {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionProtocol {}

struct CohortPriorResponse: Codable {
    let priors: [String: [String: Double]]   // [type: [hour: rate]]
    let killFlags: [String]                  // ["nutrition_gap", ...]

    enum CodingKeys: String, CodingKey {
        case priors
        case killFlags = "kill_flags"
    }
}

final class CohortPriorClient {

    private let baseURL: URL
    private let session: URLSessionProtocol

    init(baseURL: URL, session: URLSessionProtocol = URLSession.shared) {
        self.baseURL = baseURL
        self.session = session
    }

    /// POST /reminder-cohort-event with the minimum-PII payload.
    func recordEvent(type: ReminderType, hour: Int, tapped: Bool) async throws {
        precondition((0..<24).contains(hour), "hour must be 0..<24")
        let url = baseURL.appendingPathComponent("reminder-cohort-event")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload: [String: Any] = [
            "type":   type.rawValue,
            "hour":   hour,
            "tapped": tapped,
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        _ = try await session.data(for: req)
    }

    /// GET /reminder-cohort-priors. Returns the population prior + kill flags.
    func fetchPriors() async throws -> CohortPriorResponse {
        let url = baseURL.appendingPathComponent("reminder-cohort-priors")
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        let (data, _) = try await session.data(for: req)
        return try JSONDecoder().decode(CohortPriorResponse.self, from: data)
    }
}
```

- [ ] **Step 4: Add the file to project.pbxproj** (mirror the `BehavioralLearningStore` pbxproj entries from Task 3 with new IDs `CC1*`/`CC2*`)

- [ ] **Step 5: Run the no-PII test**

Run: `xcodebuild test -project FitTracker.xcodeproj -scheme FitTracker -destination 'generic/platform=iOS Simulator' -only-testing FitTrackerTests/CohortPriorClientTests/testRecordEvent_payloadContainsOnlyAllowedKeys 2>&1 | tail -10`
Expected: PASS

- [ ] **Step 6: Add the network-error test**

```swift
func testRecordEvent_networkError_propagates() async {
    let session = MockURLSession()
    session.error = URLError(.notConnectedToInternet)
    let client = CohortPriorClient(baseURL: URL(string: "https://test.local")!, session: session)

    do {
        try await client.recordEvent(type: .nutritionGap, hour: 16, tapped: true)
        XCTFail("Should have thrown")
    } catch is URLError {
        // Expected — caller (FitTrackerApp) is responsible for catching/swallowing
    } catch {
        XCTFail("Unexpected error type: \(error)")
    }
}
```

Update `MockURLSession` to support an injected error:

```swift
private final class MockURLSession: URLSessionProtocol {
    var lastRequest: URLRequest?
    var error: Error?
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        if let e = error { throw e }
        let response = HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!
        return (Data(), response)
    }
}
```

- [ ] **Step 7: Add the fetchPriors response-shape test**

```swift
func testFetchPriors_decodesResponse() async throws {
    let session = MockURLSession()
    session.canned = """
    {
      "priors": { "nutrition_gap": { "16": 0.34, "17": 0.41 } },
      "kill_flags": ["engagement"]
    }
    """.data(using: .utf8)!
    let client = CohortPriorClient(baseURL: URL(string: "https://test.local")!, session: session)

    let response = try await client.fetchPriors()
    XCTAssertEqual(response.priors["nutrition_gap"]?["17"], 0.41)
    XCTAssertEqual(response.killFlags, ["engagement"])
}
```

Update `MockURLSession`:

```swift
private final class MockURLSession: URLSessionProtocol {
    var lastRequest: URLRequest?
    var error: Error?
    var canned: Data = Data()
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        if let e = error { throw e }
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (canned, response)
    }
}
```

- [ ] **Step 8: Run all `CohortPriorClientTests` (3 cases) — all pass**

Run: `xcodebuild test -project FitTracker.xcodeproj -scheme FitTracker -destination 'generic/platform=iOS Simulator' -only-testing FitTrackerTests/CohortPriorClientTests 2>&1 | tail -10`
Expected: 3 tests passed

- [ ] **Step 9: Commit**

```bash
git add FitTracker/Services/Reminders/CohortPriorClient.swift FitTrackerTests/CohortPriorClientTests.swift FitTracker.xcodeproj/project.pbxproj
git commit -m "feat(smart-reminders): CohortPriorClient — POST/GET with no-PII payload

Two methods: recordEvent (fire-and-forget write) and fetchPriors (read).
Payload contains only {type, hour, tapped} — no userId / deviceId / locale.
URLSessionProtocol injection for testability.

Tests: payload-keys assertion, network-error propagation, fetchPriors decode."
```

---

### Task 5: Implement `CohortPriorCache` (TTL + JSON round-trip)

**Files:**
- Create: `FitTracker/Services/Reminders/CohortPriorCache.swift`
- Test:   `FitTrackerTests/CohortPriorCacheTests.swift`
- Modify: `FitTracker.xcodeproj/project.pbxproj`

A thin wrapper around the `CohortPriorResponse` with a 7-day TTL and graceful JSON-failure recovery.

- [ ] **Step 1: Write `CohortPriorCacheTests.swift` with the TTL + round-trip tests**

```swift
// FitTrackerTests/CohortPriorCacheTests.swift
import XCTest
@testable import FitTracker

@MainActor
final class CohortPriorCacheTests: XCTestCase {

    private let cacheKey = "ft.reminder.cohortPrior.json"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: cacheKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
        super.tearDown()
    }

    func testColdCache_isStale() {
        let cache = CohortPriorCache()
        XCTAssertTrue(cache.isStale, "Cold cache must report stale (forces fetch)")
        XCTAssertNil(cache.priors)
    }

    func testPersistThenLoad_roundTrip() {
        let cache = CohortPriorCache()
        let response = CohortPriorResponse(
            priors: ["nutrition_gap": ["16": 0.42]],
            killFlags: ["engagement"]
        )
        cache.persist(response)

        let cache2 = CohortPriorCache()  // simulate app relaunch
        XCTAssertFalse(cache2.isStale, "Just-persisted cache must NOT be stale")
        XCTAssertEqual(cache2.priors?.priors["nutrition_gap"]?["16"], 0.42)
        XCTAssertEqual(cache2.priors?.killFlags, ["engagement"])
    }

    func testStaleAfter7Days() {
        let cache = CohortPriorCache()
        let response = CohortPriorResponse(priors: [:], killFlags: [])
        // Persist with a fake "fetched 8 days ago" timestamp
        let eightDaysAgo = Date().addingTimeInterval(-8 * 24 * 60 * 60)
        cache.persist(response, fetchedAt: eightDaysAgo)

        let cache2 = CohortPriorCache()
        XCTAssertTrue(cache2.isStale, "Cache older than 7 days must be stale")
    }

    func testMalformedJSON_recoversToCold() {
        UserDefaults.standard.set("not valid json".data(using: .utf8), forKey: cacheKey)
        let cache = CohortPriorCache()
        XCTAssertTrue(cache.isStale)
        XCTAssertNil(cache.priors, "Malformed JSON must result in cold cache, not crash")
    }
}
```

- [ ] **Step 2: Run to confirm FAIL** (`CohortPriorCache` doesn't exist)

Expected: build error

- [ ] **Step 3: Create `CohortPriorCache.swift` minimal impl**

```swift
// FitTracker/Services/Reminders/CohortPriorCache.swift
// On-device cache of the cohort prior response. 7-day TTL.
// Persistence: a single JSON blob in UserDefaults key ft.reminder.cohortPrior.json.

import Foundation

final class CohortPriorCache {

    private let defaults: UserDefaults
    private let cacheKey = "ft.reminder.cohortPrior.json"
    private let ttl: TimeInterval = 7 * 24 * 60 * 60

    private struct Envelope: Codable {
        let response: CohortPriorResponse
        let fetchedAt: Date
    }

    private(set) var priors: CohortPriorResponse?
    private var fetchedAt: Date?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        loadFromDefaults()
    }

    var isStale: Bool {
        guard let fetched = fetchedAt else { return true }
        return Date().timeIntervalSince(fetched) > ttl
    }

    func persist(_ response: CohortPriorResponse, fetchedAt: Date = Date()) {
        let envelope = Envelope(response: response, fetchedAt: fetchedAt)
        guard let data = try? JSONEncoder().encode(envelope) else { return }
        defaults.set(data, forKey: cacheKey)
        self.priors = response
        self.fetchedAt = fetchedAt
    }

    private func loadFromDefaults() {
        guard let data = defaults.data(forKey: cacheKey) else { return }
        guard let envelope = try? JSONDecoder().decode(Envelope.self, from: data) else {
            // Malformed JSON — leave priors/fetchedAt nil; isStale stays true
            return
        }
        priors = envelope.response
        fetchedAt = envelope.fetchedAt
    }
}
```

- [ ] **Step 4: Add to project.pbxproj** (IDs `CP1*`/`CP2*` for store + tests)

- [ ] **Step 5: Run all `CohortPriorCacheTests` (4 tests)**

Run: `xcodebuild test -project FitTracker.xcodeproj -scheme FitTracker -destination 'generic/platform=iOS Simulator' -only-testing FitTrackerTests/CohortPriorCacheTests 2>&1 | tail -10`
Expected: 4 tests passed

- [ ] **Step 6: Commit**

```bash
git add FitTracker/Services/Reminders/CohortPriorCache.swift FitTrackerTests/CohortPriorCacheTests.swift FitTracker.xcodeproj/project.pbxproj
git commit -m "feat(smart-reminders): CohortPriorCache — 7-day TTL + graceful JSON recovery

Wraps CohortPriorResponse with a fetchedAt timestamp + isStale getter.
Cold cache and malformed-JSON both report stale (forces fetch).

Tests: cold = stale, round-trip preserves data, 8d-old = stale, malformed JSON does not crash."
```

---

### Task 6: AI engine — `POST /reminder-cohort-event` endpoint + pytest

**Files (in the AI engine repo, separate from FT2):**
- Create: `app/api/reminder_cohort.py` (or wherever new routers live in the existing FastAPI structure)
- Create: `app/tests/test_reminder_cohort.py`
- Modify: `app/main.py` (or equivalent — register the new router)

> **Inspect the AI engine repo's existing structure before adding files.** The endpoint pattern, dependency injection (Supabase client), and test fixture imports follow whatever the existing endpoints (e.g., readiness, recommendations) use. Mirror those patterns.

- [ ] **Step 1: Locate the existing endpoint pattern**

```bash
cd <ai-engine-repo>
ls app/api/
grep -rn "increment_cohort_frequency" app/
```

Note the pattern: existing endpoints accept a Pydantic model, call `supabase.rpc(...)`, return a status code. Tests use a `pytest` async client + a mocked Supabase service.

- [ ] **Step 2: Write the failing pytest first**

`app/tests/test_reminder_cohort.py`:

```python
import pytest
from httpx import AsyncClient

@pytest.mark.asyncio
async def test_record_event_writes_two_segments_when_tapped(client: AsyncClient, mock_supabase):
    response = await client.post(
        "/reminder-cohort-event",
        json={"type": "nutrition_gap", "hour": 16, "tapped": True},
    )
    assert response.status_code == 204

    # Should have called increment_cohort_frequency twice:
    # once for shows, once for taps
    calls = mock_supabase.rpc_calls("increment_cohort_frequency")
    assert len(calls) == 2

    shows_call = next(c for c in calls if "shows" in c["params"]["p_segment"])
    taps_call  = next(c for c in calls if "taps"  in c["params"]["p_segment"])
    assert shows_call["params"] == {
        "p_segment": "reminders.shows.nutrition_gap",
        "p_field_name": "hour",
        "p_field_value": "16",
    }
    assert taps_call["params"] == {
        "p_segment": "reminders.taps.nutrition_gap",
        "p_field_name": "hour",
        "p_field_value": "16",
    }


@pytest.mark.asyncio
async def test_record_event_only_writes_shows_when_not_tapped(client: AsyncClient, mock_supabase):
    response = await client.post(
        "/reminder-cohort-event",
        json={"type": "nutrition_gap", "hour": 16, "tapped": False},
    )
    assert response.status_code == 204
    calls = mock_supabase.rpc_calls("increment_cohort_frequency")
    assert len(calls) == 1
    assert "shows" in calls[0]["params"]["p_segment"]


@pytest.mark.asyncio
async def test_record_event_no_pii_persisted(client: AsyncClient, mock_supabase):
    """Even with auth, the request body has no userId — and the RPC params
    have no per-user keys."""
    await client.post(
        "/reminder-cohort-event",
        json={"type": "nutrition_gap", "hour": 16, "tapped": True},
        headers={"Authorization": "Bearer fake_jwt_with_userId_in_claims"},
    )
    calls = mock_supabase.rpc_calls("increment_cohort_frequency")
    for call in calls:
        params = call["params"]
        assert "user_id" not in params
        assert "userId" not in params
        # Aggregation key is only (segment, field_name, field_value)
        assert set(params.keys()) == {"p_segment", "p_field_name", "p_field_value"}
```

- [ ] **Step 3: Run the test, confirm it fails (endpoint doesn't exist)**

```bash
pytest app/tests/test_reminder_cohort.py -v
```

Expected: 404 or routing error.

- [ ] **Step 4: Implement the endpoint**

`app/api/reminder_cohort.py`:

```python
from fastapi import APIRouter, status, Depends
from pydantic import BaseModel, Field, field_validator
from app.dependencies import get_supabase  # whatever path the existing pattern uses

router = APIRouter()

class CohortEvent(BaseModel):
    type: str = Field(..., description="ReminderType.rawValue, e.g. 'nutrition_gap'")
    hour: int = Field(..., ge=0, le=23)
    tapped: bool

    @field_validator("type")
    @classmethod
    def type_must_be_known(cls, v: str) -> str:
        allowed = {
            "nutrition_gap", "training_day", "rest_day",
            "healthkit_connect", "account_registration", "engagement",
        }
        if v not in allowed:
            raise ValueError(f"type must be one of {allowed}")
        return v


@router.post("/reminder-cohort-event", status_code=status.HTTP_204_NO_CONTENT)
async def record_cohort_event(event: CohortEvent, supabase = Depends(get_supabase)):
    hour_str = f"{event.hour:02d}"

    # Always write shows
    supabase.rpc("increment_cohort_frequency", {
        "p_segment":     f"reminders.shows.{event.type}",
        "p_field_name":  "hour",
        "p_field_value": hour_str,
    }).execute()

    # Conditionally write taps
    if event.tapped:
        supabase.rpc("increment_cohort_frequency", {
            "p_segment":     f"reminders.taps.{event.type}",
            "p_field_name":  "hour",
            "p_field_value": hour_str,
        }).execute()
```

- [ ] **Step 5: Register the router in `app/main.py`**

```python
from app.api.reminder_cohort import router as reminder_cohort_router
app.include_router(reminder_cohort_router)
```

- [ ] **Step 6: Run tests — 3/3 pass**

```bash
pytest app/tests/test_reminder_cohort.py -v
```

Expected: 3 passed.

- [ ] **Step 7: Commit (in the AI engine repo)**

```bash
git add app/api/reminder_cohort.py app/tests/test_reminder_cohort.py app/main.py
git commit -m "feat(reminder-cohort): POST /reminder-cohort-event endpoint

Writes anonymised cohort observations to Supabase via
increment_cohort_frequency RPC. Uses two segments per event
(shows + taps) so tap-through rate = taps[h] / shows[h] is
computable at read time.

Payload validates type ∈ known ReminderTypes; hour ∈ [0, 23].
No PII in request body or persisted RPC params."
```

---

### Task 7: AI engine — `GET /reminder-cohort-priors` endpoint + pytest

**Files (AI engine repo):**
- Modify: `app/api/reminder_cohort.py`
- Modify: `app/tests/test_reminder_cohort.py`

The read endpoint reads `cohort_stats` for `segment LIKE 'reminders.%'`, computes per-type per-hour `tap-through = taps[h] / shows[h]`, suppresses cells with `shows < 50`, and surfaces kill flags.

- [ ] **Step 1: Add the failing test for the response shape**

```python
@pytest.mark.asyncio
async def test_priors_returns_per_type_per_hour_rates(client: AsyncClient, mock_supabase):
    # Seed: nutrition_gap at hour 16 has 80 shows and 32 taps → rate 0.4
    mock_supabase.seed_cohort_stats([
        {"segment": "reminders.shows.nutrition_gap", "field_name": "hour", "field_value": "16", "frequency": 80},
        {"segment": "reminders.taps.nutrition_gap",  "field_name": "hour", "field_value": "16", "frequency": 32},
    ])
    response = await client.get("/reminder-cohort-priors")
    assert response.status_code == 200
    data = response.json()
    assert data["priors"]["nutrition_gap"]["16"] == pytest.approx(0.4)
    assert data["kill_flags"] == []

@pytest.mark.asyncio
async def test_priors_suppresses_low_volume_cells(client: AsyncClient, mock_supabase):
    # 49 shows is below the privacy threshold (50)
    mock_supabase.seed_cohort_stats([
        {"segment": "reminders.shows.nutrition_gap", "field_name": "hour", "field_value": "16", "frequency": 49},
        {"segment": "reminders.taps.nutrition_gap",  "field_name": "hour", "field_value": "16", "frequency": 20},
    ])
    response = await client.get("/reminder-cohort-priors")
    data = response.json()
    assert "16" not in data["priors"].get("nutrition_gap", {}), \
        "cells with shows<50 must be suppressed in the response"

@pytest.mark.asyncio
async def test_priors_includes_kill_flags(client: AsyncClient, mock_supabase):
    mock_supabase.seed_cohort_stats([
        {"segment": "reminders.kill_flag", "field_name": "engagement", "field_value": "true", "frequency": 1},
    ])
    response = await client.get("/reminder-cohort-priors")
    data = response.json()
    assert data["kill_flags"] == ["engagement"]
```

- [ ] **Step 2: Run to confirm fail**

Expected: 404.

- [ ] **Step 3: Implement the endpoint**

Append to `app/api/reminder_cohort.py`:

```python
from typing import Dict, List

class CohortPriorsResponse(BaseModel):
    priors: Dict[str, Dict[str, float]]   # {type: {hour: rate}}
    kill_flags: List[str]


@router.get("/reminder-cohort-priors", response_model=CohortPriorsResponse)
async def get_cohort_priors(supabase = Depends(get_supabase)):
    PRIVACY_THRESHOLD = 50

    # Fetch all reminder cohort rows in one query
    rows = supabase.table("cohort_stats") \
        .select("segment, field_name, field_value, frequency") \
        .like("segment", "reminders.%") \
        .execute() \
        .data

    shows: Dict[str, Dict[str, int]] = {}
    taps:  Dict[str, Dict[str, int]] = {}
    kill_flags: List[str] = []

    for row in rows:
        segment = row["segment"]
        if segment == "reminders.kill_flag" and row["field_value"] == "true":
            kill_flags.append(row["field_name"])
            continue
        if segment.startswith("reminders.shows."):
            type_ = segment.removeprefix("reminders.shows.")
            shows.setdefault(type_, {})[row["field_value"]] = row["frequency"]
        elif segment.startswith("reminders.taps."):
            type_ = segment.removeprefix("reminders.taps.")
            taps.setdefault(type_, {})[row["field_value"]] = row["frequency"]

    priors: Dict[str, Dict[str, float]] = {}
    for type_, hour_shows in shows.items():
        priors[type_] = {}
        for hour, n_shows in hour_shows.items():
            if n_shows < PRIVACY_THRESHOLD:
                continue  # suppress
            n_taps = taps.get(type_, {}).get(hour, 0)
            priors[type_][hour] = n_taps / n_shows
        if not priors[type_]:
            del priors[type_]  # don't return empty type entries

    return CohortPriorsResponse(priors=priors, kill_flags=kill_flags)
```

- [ ] **Step 4: Run tests — all 6 (3 from Task 6 + 3 here) pass**

```bash
pytest app/tests/test_reminder_cohort.py -v
```

Expected: 6 passed.

- [ ] **Step 5: Commit**

```bash
git add app/api/reminder_cohort.py app/tests/test_reminder_cohort.py
git commit -m "feat(reminder-cohort): GET /reminder-cohort-priors endpoint

Reads cohort_stats for segment LIKE 'reminders.%', computes per-type
per-hour tap-through rate. Suppresses cells with shows < 50 (privacy
+ statistical-validity threshold). Surfaces kill flags from the
'reminders.kill_flag' segment."
```

---

### Task 8: Supabase migration — extend pg_cron retention to `reminders.%` segments

**Files:**
- Create: `backend/supabase/migrations/000009_extend_retention_for_reminders.sql`

- [ ] **Step 1: Read the existing retention migration to mirror its pattern**

```bash
cat backend/supabase/migrations/000004_retention_pg_cron.sql
```

Note the existing TTL policy and pg_cron schedule. Follow exactly the same pattern.

- [ ] **Step 2: Create the new migration**

`backend/supabase/migrations/000009_extend_retention_for_reminders.sql`:

```sql
-- Migration 000009: extend cohort_stats retention to reminders.* segments
-- Mirrors the policy defined in migration 000004 for the existing ai-engine
-- segments. The reminder cohort segments use the same TTL since their data
-- volume + sensitivity profile is identical (anonymised frequency counts).

-- Re-create the existing pg_cron job's predicate to also match reminders.%
-- (replace the original job rather than adding a second one — keeps the
-- retention policy single-sourced.)

SELECT cron.unschedule('cohort_stats_retention');

SELECT cron.schedule(
  'cohort_stats_retention',
  '0 3 * * *',  -- daily at 03:00 UTC
  $$
    DELETE FROM cohort_stats
    WHERE updated_at < NOW() - INTERVAL '90 days'
      AND (
        segment IN ('training', 'nutrition', 'recovery', 'stats')
        OR segment LIKE 'reminders.%'
      );
  $$
);

COMMENT ON EXTENSION pg_cron IS
  '90-day rolling retention on cohort_stats. Covers all known segments: '
  'the original ai-engine 4 + reminders.* added 2026-05-01 (migration 000009).';
```

> **Verify the schedule + interval against migration 000004 — adjust if 000004 uses different values.** The plan above assumes 90-day TTL + 03:00 UTC daily; replace with whatever 000004 uses.

- [ ] **Step 3: Apply the migration to the local Supabase (or staging)**

```bash
cd backend/supabase
supabase db push --include-all
# OR via the Supabase MCP if configured: mcp__claude_ai_Supabase__apply_migration
```

- [ ] **Step 4: Verify the cron job is registered**

```sql
SELECT jobname, schedule FROM cron.job WHERE jobname = 'cohort_stats_retention';
```

Expected: one row with the new schedule.

- [ ] **Step 5: Commit**

```bash
git add backend/supabase/migrations/000009_extend_retention_for_reminders.sql
git commit -m "feat(supabase): extend cohort_stats retention to reminders.% segments

Single-sources the retention policy (re-schedules the existing
cohort_stats_retention pg_cron job rather than adding a second). Uses
the same 90-day TTL as the original ai-engine segments. No new tables;
reuses cohort_stats schema verbatim per the design spec."
```

---

### Task 9: Wire `BehavioralLearningStore` into `ReminderNotificationDelegate`

**Files:**
- Modify: `FitTracker/Services/Reminders/ReminderNotificationDelegate.swift`
- Modify: `FitTrackerTests/ReminderAnalyticsTests.swift` (existing file — extend with new behaviour assertion)

`willPresent` records the **denominator** (`tapped: false`); `didReceive` upgrades to numerator on tap.

- [ ] **Step 1: Add a failing test to `ReminderAnalyticsTests.swift`** (the existing test file from PR #158 that already exercises the delegate)

```swift
func testWillPresent_recordsObservationOnStore() async {
    let store = BehavioralLearningStore()
    store.deleteAllUserData()  // clean slate
    let delegate = ReminderNotificationDelegate(analytics: nil, store: store)

    // Simulate a willPresent callback (delegate is non-isolated; we exercise
    // the store-recording branch directly via the test seam.)
    delegate.recordObservationFromNotification(type: .nutritionGap, hour: 16)
    XCTAssertEqual(store.observationCount(type: .nutritionGap), 1)
}
```

(`recordObservationFromNotification` is a small internal seam we'll expose for testability — the real `willPresent` callback is hard to drive in XCTest without a UNNotification fixture.)

- [ ] **Step 2: Run to confirm fail**

Expected: missing init parameter `store:` and missing method `recordObservationFromNotification`.

- [ ] **Step 3: Modify `ReminderNotificationDelegate.swift` to accept a store + expose the test seam**

```swift
final class ReminderNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {

    weak var analytics: AnalyticsService?
    weak var store: BehavioralLearningStore?
    weak var cohortClient: CohortPriorClient?

    init(analytics: AnalyticsService? = nil,
         store: BehavioralLearningStore? = nil,
         cohortClient: CohortPriorClient? = nil) {
        self.analytics = analytics
        self.store = store
        self.cohortClient = cohortClient
        super.init()
    }

    /// Test-only seam: directly drive the willPresent recording path
    /// without constructing a UNNotification (which has private inits).
    func recordObservationFromNotification(type: ReminderType, hour: Int) {
        Task { @MainActor in
            store?.recordObservation(type: type, hour: hour, tapped: false)
        }
        Task {
            try? await cohortClient?.recordEvent(type: type, hour: hour, tapped: false)
        }
    }

    /// Test-only seam: directly drive the didReceive(tap) path.
    func upgradeObservationFromTap(type: ReminderType, hour: Int) {
        Task { @MainActor in
            store?.upgradeLastObservation(type: type, tapped: true)
        }
        Task {
            try? await cohortClient?.recordEvent(type: type, hour: hour, tapped: true)
        }
    }

    // ... existing willPresent + didReceive methods unchanged from PR #158 BUT
    //     each now also calls the corresponding seam:

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping @Sendable (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        let typeRaw = userInfo["type"] as? String

        Task { @MainActor in
            if let raw = typeRaw, let type = ReminderType(rawValue: raw) {
                analytics?.logReminderShown(type: type.rawValue)
                let hour = Calendar.current.component(.hour, from: Date())
                recordObservationFromNotification(type: type, hour: hour)
            }
        }
        completionHandler([.banner, .sound, .list])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping @Sendable () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        let actionIdentifier = response.actionIdentifier
        let typeRaw = userInfo["type"] as? String

        Task { @MainActor in
            guard let raw = typeRaw, let type = ReminderType(rawValue: raw) else {
                completionHandler()
                return
            }
            let hour = Calendar.current.component(.hour, from: Date())
            switch actionIdentifier {
            case UNNotificationDismissActionIdentifier:
                analytics?.logReminderDismissed(type: type.rawValue)
                // No upgrade — observation stays tapped:false
            case UNNotificationDefaultActionIdentifier:
                analytics?.logReminderTapped(type: type.rawValue)
                upgradeObservationFromTap(type: type, hour: hour)
                Self.postDeepLinkNotification(type: type, userInfo: userInfo)
            default:
                analytics?.logReminderTapped(type: type.rawValue)
                upgradeObservationFromTap(type: type, hour: hour)
                Self.postDeepLinkNotification(type: type, userInfo: userInfo)
            }
            completionHandler()
        }
    }
}
```

- [ ] **Step 4: Run the new test**

Run: `xcodebuild test -project FitTracker.xcodeproj -scheme FitTracker -destination 'generic/platform=iOS Simulator' -only-testing FitTrackerTests/ReminderAnalyticsTests/testWillPresent_recordsObservationOnStore 2>&1 | tail -10`
Expected: PASS

- [ ] **Step 5: Run the existing `ReminderAnalyticsTests` (12 cases from PR #158) — none regressed**

Run: `xcodebuild test -project FitTracker.xcodeproj -scheme FitTracker -destination 'generic/platform=iOS Simulator' -only-testing FitTrackerTests/ReminderAnalyticsTests 2>&1 | tail -10`
Expected: 13 tests passed (12 existing + 1 new)

- [ ] **Step 6: Commit**

```bash
git add FitTracker/Services/Reminders/ReminderNotificationDelegate.swift FitTrackerTests/ReminderAnalyticsTests.swift
git commit -m "feat(smart-reminders): wire BehavioralLearningStore into delegate

ReminderNotificationDelegate now takes optional store + cohortClient.
willPresent records the denominator (shown event) on the store and
fires-and-forgets a cohort write. didReceive upgrades to numerator on
tap. Dismissals leave observations as tapped:false (correct — denominator
without numerator).

Existing 12 PR #158 tests unchanged; +1 new assertion that exercises
the recordObservation seam."
```

---

### Task 10: Wire stores + fetch into `FitTrackerApp`

**Files:**
- Modify: `FitTracker/FitTrackerApp.swift`

Bootstrap the new services + trigger a fire-and-forget cohort prior fetch on app launch.

- [ ] **Step 1: Add service properties to `FitTrackerApp`**

In the `@StateObject` block (around line 52, near `analytics`):

```swift
    // Behavioural learning sub-feature (PR 1 ships data-collection only)
    private let behavioralLearningStore = BehavioralLearningStore()
    private let cohortPriorCache        = CohortPriorCache()
    private lazy var cohortPriorClient: CohortPriorClient = {
        // Reuse the existing AI-engine base URL (defined elsewhere in this file).
        CohortPriorClient(baseURL: makeAIEngineBaseURL())
    }()
```

- [ ] **Step 2: Wire the delegate to the new services in the `init()` or `.task` modifier**

Find where `reminderNotificationDelegate.setAnalytics(analytics)` is called (PR #158 pattern). Add alongside:

```swift
                .task {
                    // ... existing analytics + delegate wiring from PR #158 ...
                    reminderNotificationDelegate.store = behavioralLearningStore
                    reminderNotificationDelegate.cohortClient = cohortPriorClient

                    // Fire-and-forget cohort prior fetch if cache is stale or cold.
                    if cohortPriorCache.isStale {
                        Task {
                            do {
                                let response = try await cohortPriorClient.fetchPriors()
                                cohortPriorCache.persist(response)
                            } catch {
                                // Silent fallback — resolver (PR 2) uses static defaults
                                analytics.logEvent("smart_timing_fetch_failed",
                                                   parameters: ["reason": "\(error)"])
                            }
                        }
                    }
                }
```

- [ ] **Step 3: Build to verify compilation**

Run: `xcodebuild build -project FitTracker.xcodeproj -scheme FitTracker -destination 'generic/platform=iOS Simulator' -quiet 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add FitTracker/FitTrackerApp.swift
git commit -m "feat(smart-reminders): bootstrap BehavioralLearningStore + CohortPriorCache

App-launch wiring: instantiate the three new services and inject the
store + client into the existing ReminderNotificationDelegate. Fire-
and-forget cohort prior fetch if cache is stale (>7d) or cold. Network
errors caught silently — the next app launch will retry, and the
resolver (PR 2) gracefully uses static defaults when cache is empty.

PR 1's wiring stops here: the resolver in PR 2 is not yet connected."
```

---

### Task 11: Extend `EncryptedDataStore.deleteAllUserData()` to wipe the store

**Files:**
- Modify: `FitTracker/Services/Encryption/EncryptedDataStore.swift` (or wherever `deleteAllUserData` lives — verify path)
- Test: extend an existing GDPR-delete test if one exists, else add a new one to `BehavioralLearningStoreTests`

GDPR Article 17 right-to-erasure must reach the new store.

- [ ] **Step 1: Locate `deleteAllUserData`**

```bash
grep -rn "deleteAllUserData" FitTracker/Services/
```

Note the file + signature.

- [ ] **Step 2: Add a call to `BehavioralLearningStore().deleteAllUserData()` in the existing implementation**

If `deleteAllUserData` is on `EncryptedDataStore`:

```swift
func deleteAllUserData() async {
    // ... existing cleanup ...
    await MainActor.run {
        BehavioralLearningStore().deleteAllUserData()
    }
}
```

(or non-async if the existing method is sync — match the existing signature.)

- [ ] **Step 3: Add an integration test**

In `FitTrackerTests/BehavioralLearningStoreTests.swift` (or a sibling test), add:

```swift
func testEncryptedDataStore_deleteAllUserData_wipesBehavioralLearning() async {
    let store = BehavioralLearningStore()
    store.recordObservation(type: .nutritionGap, hour: 16, tapped: true)
    XCTAssertEqual(store.observationCount(type: .nutritionGap), 1)

    let dataStore = EncryptedDataStore()  // or however it's instantiated in tests
    await dataStore.deleteAllUserData()

    XCTAssertEqual(store.observationCount(type: .nutritionGap), 0,
                   "GDPR Article 17 — deleteAllUserData must wipe BehavioralLearningStore")
}
```

- [ ] **Step 4: Run the test**

Run: `xcodebuild test -project FitTracker.xcodeproj -scheme FitTracker -destination 'generic/platform=iOS Simulator' -only-testing FitTrackerTests/BehavioralLearningStoreTests/testEncryptedDataStore_deleteAllUserData_wipesBehavioralLearning 2>&1 | tail -10`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add FitTracker/Services/Encryption/EncryptedDataStore.swift FitTrackerTests/BehavioralLearningStoreTests.swift
git commit -m "feat(smart-reminders): extend GDPR Article 17 wipe to BehavioralLearningStore

EncryptedDataStore.deleteAllUserData() now also wipes the per-user
behavioural-learning posterior. Test asserts the wipe takes effect."
```

---

### Task 12: Add the global "Smart timing" toggle (defaults OFF) to Settings

**Files:**
- Create: `FitTracker/Views/Settings/BehavioralLearningSettingsView.swift`
- Modify: `FitTracker/Services/AppSettings.swift` (or the equivalent `@AppStorage` host)
- Modify: `FitTracker/Views/Settings/<existing notifications view>` to embed the new view
- Modify: `FitTracker.xcodeproj/project.pbxproj`

PR 1's UI is intentionally minimal: one toggle row, defaults OFF, no consumer yet (resolver lands in PR 2).

- [ ] **Step 1: Add the `@AppStorage` flag**

In `AppSettings.swift` (or wherever `@AppStorage` properties live):

```swift
    @AppStorage("smartTimingEnabled") var smartTimingEnabled: Bool = false
```

- [ ] **Step 2: Create the new view**

```swift
// FitTracker/Views/Settings/BehavioralLearningSettingsView.swift
// PR 1: single global toggle, defaults OFF.
// PR 3 will add per-type "Why this time?" rows below this toggle.

import SwiftUI

struct BehavioralLearningSettingsView: View {

    @AppStorage("smartTimingEnabled") private var smartTimingEnabled: Bool = false

    var body: some View {
        Section(header: Text("Smart timing")) {
            Toggle(isOn: $smartTimingEnabled) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Smart timing")
                    Text("Learns when you're most responsive and shifts reminder times to match. Off = static defaults.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
```

- [ ] **Step 3: Embed the new view in the existing notifications settings screen**

Find the existing `NotificationSettingsView.swift` or whichever Settings → Notifications root. Add:

```swift
struct NotificationSettingsView: View {
    var body: some View {
        Form {
            // ... existing per-type toggles ...
            BehavioralLearningSettingsView()
        }
    }
}
```

- [ ] **Step 4: Add `BehavioralLearningSettingsView.swift` to `project.pbxproj`** (mirror Task 3's pattern with new IDs)

- [ ] **Step 5: Build to verify compilation**

Run: `xcodebuild build -project FitTracker.xcodeproj -scheme FitTracker -destination 'generic/platform=iOS Simulator' -quiet 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add FitTracker/Views/Settings/BehavioralLearningSettingsView.swift FitTracker/Services/AppSettings.swift FitTracker/Views/Settings/NotificationSettingsView.swift FitTracker.xcodeproj/project.pbxproj
git commit -m "feat(smart-reminders): add global 'Smart timing' toggle (defaults off, no consumer)

Settings → Notifications now includes a single Smart timing toggle row.
Defaults off — PR 1 ships zero user-visible behaviour change. PR 2 will
flip the default to on for new installs and wire the toggle to the
SmartTimingResolver.

PR 3 will append per-type 'Why this time?' rows below this toggle."
```

---

### Task 13: Run the full test suite + UI audit

- [ ] **Step 1: Run the full test suite to verify no regressions**

Run: `xcodebuild test -project FitTracker.xcodeproj -scheme FitTracker -destination 'generic/platform=iOS Simulator' 2>&1 | tail -10`
Expected: all tests pass; new `BehavioralLearningStoreTests` (4) + `CohortPriorClientTests` (3) + `CohortPriorCacheTests` (4) + extended `ReminderAnalyticsTests` (13) all green.

- [ ] **Step 2: Run the UI audit**

Run: `make ui-audit 2>&1 | tail -10`
Expected: P0 count unchanged from baseline (or zero new findings on the new view file).

- [ ] **Step 3: Run state.json + cu_v2 validators**

```bash
python3 scripts/check-state-schema.py .claude/features/smart-reminders-behavioral-learning/state.json
python3 scripts/validate-cu-v2.py --state .claude/features/smart-reminders-behavioral-learning/state.json
```

Expected: both ✓.

- [ ] **Step 4: If any failures, fix them and commit before advancing**

---

### Task 14: Advance state.json to `implementation` → `test` → `review` → `merge`

**Files:**
- Modify: `.claude/features/smart-reminders-behavioral-learning/state.json`
- Modify: `.claude/logs/smart-reminders-behavioral-learning.log.json`

PR 1 is data-layer only; phases are short.

- [ ] **Step 1: Advance phases as the work progresses**

Each transition:
1. Update `current_phase` and the `phases.<old>.status` to complete + `phases.<new>.status` to in_progress
2. Append a phase-transition log entry via `scripts/append-feature-log.py`
3. Update `timing.phases.<phase>` started_at/ended_at
4. Validate via `scripts/check-state-schema.py`
5. Commit

- [ ] **Step 2: When all tests pass and the local build is green, set `current_phase: review`**

```bash
python3 scripts/append-feature-log.py \
  --feature smart-reminders-behavioral-learning \
  --event-type phase_started \
  --phase review \
  --summary "PR 1 ready for review. All Swift tests pass; AI-engine pytests pass; Supabase migration applied to staging."
```

- [ ] **Step 3: Commit the phase advance**

```bash
git add .claude/features/smart-reminders-behavioral-learning/state.json .claude/logs/smart-reminders-behavioral-learning.log.json
git commit -m "chore(smart-reminders-behavioral-learning): PR 1 ready for review (phase=review)"
```

---

### Task 15: Push branch + open PR 1

- [ ] **Step 1: Push the branch**

```bash
git push origin feature/smart-reminders-behavioral-learning
```

- [ ] **Step 2: Open PR 1 against `main`**

```bash
gh pr create --base main --head feature/smart-reminders-behavioral-learning \
  --title "feat(smart-reminders): behavioral learning PR 1 — data layer + toggle-off" \
  --body "$(cat <<'EOF'
## Summary

PR 1 of 3 for the smart-reminders behavioral learning sub-feature. Ships
the data-collection foundation: per-user posterior store, cohort prior
client + cache, AI-engine writer/reader endpoints, Supabase retention
extension, and the global "Smart timing" Settings toggle (defaults off).
**Zero user-visible behaviour change.** Cohort writes start accumulating
in production for the resolver in PR 2 to consume after ~5-7 days.

## Spec

`docs/superpowers/specs/2026-05-01-smart-reminders-behavioral-learning-design.md`

## Plan

`docs/superpowers/plans/2026-05-01-smart-reminders-behavioral-learning-pr1.md` (this PR)

## What's in this PR

- **Swift services (3 new):** BehavioralLearningStore, CohortPriorClient, CohortPriorCache
- **Swift wiring:** ReminderNotificationDelegate records observations on willPresent/didReceive; FitTrackerApp bootstraps stores + fire-and-forget cohort fetch
- **GDPR:** EncryptedDataStore.deleteAllUserData() extended
- **UI:** Settings → Notifications adds a Smart timing toggle (defaults off, no consumer)
- **AI engine:** POST /reminder-cohort-event + GET /reminder-cohort-priors endpoints
- **Supabase:** migration 000009 extends pg_cron retention to reminders.* segments

## What's NOT in this PR

- SmartTimingResolver (PR 2)
- A/B test instrumentation (PR 2)
- "Why this time?" UI affordance (PR 3)

## Test plan

- [x] All Swift tests pass (24 tests added across 3 new test files; 1 added to existing ReminderAnalyticsTests)
- [x] AI-engine pytests pass (6 new tests)
- [ ] Supabase migration applied to staging (verified by checking pg_cron.job table)
- [ ] Manual smoke: install on simulator, verify the toggle renders in Settings → Notifications, verify cohort writes hit Supabase via the AI engine
- [ ] PR-integrity gate: state.json schema valid, cu_v2 valid

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 3: After PR is opened, advance state.json to `merge` phase (with `pr_number` filled)**

```python
# python helper inline; or via append-feature-log + manual edit
import json, subprocess
pr_number = int(subprocess.check_output(["gh", "pr", "view", "--json", "number", "-q", ".number"]).decode().strip())
path = ".claude/features/smart-reminders-behavioral-learning/state.json"
d = json.load(open(path))
d["phases"]["merge"]["pr_number"] = pr_number
json.dump(d, open(path, "w"), indent=2)
```

```bash
git add .claude/features/smart-reminders-behavioral-learning/state.json
git commit -m "chore(smart-reminders-behavioral-learning): record PR number on state.json"
git push
```

---

## Self-Review

After writing this plan, run a fresh-eyes pass against the spec:

**1. Spec coverage:**

| Spec section | Plan task |
|---|---|
| §5 BehavioralLearningStore | Task 3 |
| §5 CohortPriorClient | Task 4 |
| §5 CohortPriorCache | Task 5 |
| §5 SmartTimingResolver | **Deferred to PR 2 plan** (intentional — see scope check above) |
| §5 BehavioralLearningSettingsView toggle | Task 12 |
| §5 WhyThisTimeSheet | **Deferred to PR 3 plan** |
| §5 ReminderType.defaultPriorDistribution | Task 2 |
| §5 ReminderNotificationDelegate extension | Task 9 |
| §5 FitTrackerApp wiring | Task 10 |
| §5 EncryptedDataStore.deleteAllUserData extension | Task 11 |
| §5 project.pbxproj registration | Tasks 3, 4, 5, 12 (per-file) |
| §5 AI engine endpoints | Tasks 6, 7 |
| §5 Supabase migration 000009 | Task 8 |
| §5 Tests (PR 1 scope) | Tasks 3, 4, 5, 9, 11 |
| §6 Flow A (App launch) | Task 10 |
| §6 Flow C (Observation recording) | Task 9 |
| §7 Network failures | Task 10 (silent catch in fetch) + Task 4 (network-error test) |
| §7 GDPR Article 22 / 17 | Task 11 |
| §7 Toggle off → revert | Task 12 (toggle exists but no consumer in PR 1; reverts naturally) |

PR 2 / PR 3 scope (resolver, A/B, "Why?" UI) intentionally **not** covered here — own plans when PR 1 ships.

**2. Placeholder scan:** No `TBD`, `TODO`, "implement appropriately" patterns. ✓

**3. Type consistency:** `BehavioralLearningStore` API signatures match across Tasks 3, 9, 10, 11. `CohortPriorClient` matches across Tasks 4, 9, 10. `CohortPriorResponse` matches Tasks 4, 5. ✓

**4. Open ambiguities:**

- Task 8 step 2 contains a `verify against migration 000004` annotation rather than the exact policy. The pattern is correct (re-schedule the existing job rather than adding a second), but the executor must read 000004 first. Acceptable since the plan can't pre-fetch unknown content; flagged in the step.
- Task 11 step 1 says "Locate `deleteAllUserData`" via `grep` rather than naming the file directly. The existing GDPR-delete entrypoint isn't fully specified in the spec; the executor will identify the correct path. Acceptable.

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-05-01-smart-reminders-behavioral-learning-pr1.md`. Two execution options:**

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration. Good for a 15-task plan that touches multiple repos (FT2 + AI engine + Supabase) — each subagent gets a focused brief.

**2. Inline Execution** — Execute tasks in this session using `executing-plans`, batch execution with checkpoints for review.

**Which approach?**
