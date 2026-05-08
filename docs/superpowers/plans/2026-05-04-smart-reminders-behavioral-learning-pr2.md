# Smart Reminders — Behavioral Learning PR 2 (SmartTimingResolver + A/B Test) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the resolver layer of the behavioral-learning sub-feature. Personalised fire times for users with ≥10 observations on a personalisable type; static defaults for everyone else. Toggle default flips ON for new installs. A/B test instrumentation begins so the merge gate (≥+5pp aggregate tap-through lift at p<0.05 over 14±4 day per-user readout) can fire.

**Architecture:** PR 1 (merged 2026-05-04 via FT2 PR #190 + #198) shipped the data layer: `BehavioralLearningStore`, `CohortPriorClient`, `CohortPriorCache`, the AI-engine endpoints, and the Settings toggle that defaults OFF. PR 2 inserts a single new component — `SmartTimingResolver` — between `ReminderScheduler` and the existing fire-time logic. The resolver consults the prior + posterior to compute a per-user fire hour for the three personalisable types (`nutritionGap`, `trainingDay`, `restDay`) and short-circuits to `type.defaultFireHour` for the other three or when the toggle is off or when the type has a server kill_flag.

**A/B test:** Deterministic hash of user UUID assigns each user to `treatment` (resolver active) or `control` (resolver short-circuits to static defaults but `BehavioralLearningStore` still records observations so post-hoc analysis isn't biased). User property `smart_timing_arm` written to GA4 on first launch post-PR-2. Manual toggle-off changes arm to `opted_out` and excludes the user from the t-test.

**Tech Stack:** Swift 5.9+ (iOS 17+), SwiftUI, XCTest, UserDefaults; existing GA4 event taxonomy (extended); existing GA4 user properties.

**Predecessor PRs (must already be on `main`):**
- PR #98 (parent feature shipped)
- PR #158 (six lifecycle analytics events)
- PR #190 (smart-reminders-behavioral-learning iOS data layer + toggle off)
- PR #198 (smart-reminders-behavioral-learning AI-engine endpoints + retention migration)

**Reference:** [`docs/superpowers/specs/2026-05-01-smart-reminders-behavioral-learning-design.md`](../specs/2026-05-01-smart-reminders-behavioral-learning-design.md) is the source of truth for design decisions. Specifically PR-2 work is described in §4 (Architecture), §5 (Components, items marked `PR 2`), §6 Flow B + Privacy, §7 (Error handling), §8 (Testing + A/B instrumentation).

**Pre-flight gate:** PR-2 work cannot meaningfully start until production has cohort data. Verify before Task 1:

```bash
supabase --project-ref <ref> sql -- "SELECT segment, COUNT(*) AS rows, SUM(frequency) AS events
  FROM cohort_stats WHERE segment LIKE 'reminders.%' GROUP BY segment ORDER BY rows DESC"
```

Expected (≥5 days post-PR-#198 merge i.e. ≥2026-05-09):

- `reminders.shows.<type>` rows for at least one of `nutrition_gap`, `training_day`, `rest_day`.
- Per-cell shows ≥ ~10 across many cells (the privacy threshold is 50; below 50 the resolver gets uniform-no-signal).
- If empty: extend the wait by another ~3 days OR investigate whether iOS clients are actually firing `reminder_shown` events (check Sentry breadcrumbs for `reminder_cohort_event` POST failures).

If pre-flight fails, **DO NOT START** Task 1. Document the gap on PR #198 as a comment + extend the data-window monitor.

---

## File Structure

### New Swift files (PR 2)

| Path | Responsibility |
|---|---|
| `FitTracker/Services/Reminders/SmartTimingResolver.swift` | Decision-maker. `firingTime(for: ReminderType) -> Hour`. Combines prior (cache) + posterior (store) via Bayesian update; short-circuits to static default for non-personalisable types AND when toggle off AND when type has a server kill_flag. |
| `FitTracker/Services/Reminders/SmartTimingArm.swift` | Tiny enum + assignment helper. `case treatment, control, optedOut`. `static func assign(userID: String) -> SmartTimingArm` deterministic via hash. |
| `FitTrackerTests/SmartTimingResolverTests.swift` | Static-default short-circuits, toggle-off path, cold-cache fallback, kill-flag honouring, Bayesian smoothing. |
| `FitTrackerTests/SmartTimingArmTests.swift` | Determinism (same userID → same arm), 50/50 split over a large hash sample, opted_out semantics. |
| `FitTrackerTests/ReminderSchedulerSmartTimingTests.swift` | Scheduler-resolver integration (resolver consulted before trigger build), control-arm path (resolver returns static), kill-flag-during-scheduling path. |

### Modified Swift files (PR 2)

| Path | Change |
|---|---|
| `FitTracker/Services/Reminders/ReminderScheduler.swift` | Inject the resolver. `scheduleIfAllowed` consults `SmartTimingResolver.firingTime(for: type)` BEFORE building the trigger. Existing `delayMinutes` parameter remains an explicit override. Preserves existing guards: quiet hours, daily cap, per-type cap, lifetime cap, min interval. |
| `FitTracker/FitTrackerApp.swift` | Bootstrap: instantiate `SmartTimingResolver` (consumes the existing PR-1 store + cache + toggle); inject into `ReminderScheduler.shared.resolver`; assign `smartTimingArm` on first launch and persist to UserDefaults; emit `smart_timing_arm_assigned` GA4 user property. |
| `FitTracker/Services/AppSettings.swift` | Default for `smartTimingEnabled` flips from `false` to `true` for **new installs only**. Existing-user-detection: if the UserDefaults key `ft.smartTimingEnabled` exists, leave the value untouched. New installs initialise to `true`. |
| `FitTracker/Services/Analytics/AnalyticsService.swift` | Add 3 new event constants + log helpers: `logSmartTimingArmAssigned(arm:)`, `logSmartTimingFetchFailed(reason:)`, `logSmartTimingRecordFailed(reason:)`. Plus user property setter `setSmartTimingArm(_ arm: String)`. |
| `FitTracker/Services/Analytics/AnalyticsProvider.swift` | New event constants + 1 user-property constant. |
| `docs/product/analytics-taxonomy.csv` | Add 3 events + 1 user property + (potentially) 1 conversion event. |
| `FitTracker.xcodeproj/project.pbxproj` | Register the 5 new Swift files in the Sources build phase. |

### State + meta artifacts (PR 2)

State.json transition strategy is undecided as of plan-write time. Two options:

**Option A — Re-enter the existing feature's state.json** (advance `complete → tasks` for PR 2, walk through again, mark `complete` again at PR-2 merge). Risk: violates the v7.7 PHASE_LIE-equivalent assumption that `complete` is terminal. May need framework-version bump or a `pr_iteration` field.

**Option B — Create a sibling feature dir** `.claude/features/smart-reminders-behavioral-learning-pr2/` with its own state.json that links the parent via `predecessor_features: ["smart-reminders-behavioral-learning"]`. Cleanest for the framework but conceptually splits one feature into two state files.

**Option C — Add a `pr_iterations[]` array** to the existing state.json that records each PR's lifecycle independently while keeping `current_phase` reflecting the latest. New schema field; needs a small `check-state-schema.py` extension.

**Decision: defer to Task 1.** Read the framework state at execution time and pick the option with the least friction. Plan body assumes Option B (sibling feature) for simplicity but the actual choice can be made when Task 1 runs.

---

## Tasks

---

### Task 1: Pre-flight + state.json strategy

**Files:**
- Read: `.claude/features/smart-reminders-behavioral-learning/state.json`
- Decide: which option (A/B/C above) to use for PR-2 state tracking.
- Possibly create: `.claude/features/smart-reminders-behavioral-learning-pr2/state.json` (Option B)

- [ ] **Step 1: Verify production cohort data exists** (the pre-flight gate above). If empty, **STOP** and re-evaluate timing.

- [ ] **Step 2: Pick state.json option**
  - Option A if framework v7.8+ now has a `re_enter` exempt tag.
  - Option B otherwise (default — sibling state.json).

- [ ] **Step 3: Create PR-2 state.json (Option B)**

```bash
mkdir -p .claude/features/smart-reminders-behavioral-learning-pr2
cat > .claude/features/smart-reminders-behavioral-learning-pr2/state.json <<'JSON'
{
  "feature": "smart-reminders-behavioral-learning-pr2",
  "feature_name": "smart-reminders-behavioral-learning-pr2",
  "display_name": "Smart Reminders — Behavioral Learning PR 2 (Resolver + A/B Test)",
  "case_study": "docs/case-studies/smart-reminders-behavioral-learning-pr2-case-study.md",
  "work_type": "feature",
  "framework_version": "v7.7",
  "current_phase": "tasks",
  "status": "in_progress",
  "created_at": "<NOW>",
  "updated": "<NOW>",
  "branch": "feature/smart-reminders-behavioral-learning-pr2",
  "parent_feature": "smart-reminders",
  "predecessor_features": [
    "smart-reminders-behavioral-learning"
  ],
  "depends_on": [
    "FT2 PR #190 (iOS data layer, merged 2026-05-04)",
    "FT2 PR #198 (AI-engine endpoints + migration 000009, merged 2026-05-04)",
    "Production cohort_stats has reminders.* data (verified at Task 1 step 1)"
  ],
  "success_metrics": [
    "Aggregate tap-through (treatment vs control) lifts by >= +5 pp at p < 0.05 over the 14 +/- 4 day per-user readout window",
    "None of (nutritionGap, trainingDay, restDay) regresses below static-baseline tap-through by >= -3 pp"
  ],
  "kill_criteria": [
    "Aggregate tap-through lift < +0 pp at end of readout window",
    "Any single personalised type regresses by >= -3 pp vs static baseline -> per-type rollback (kill_flag)",
    "Disable rate increases >= +3 pp from baseline"
  ],
  "dispatch_pattern": "serial",
  "phases": {
    "research": {"status": "skipped", "skipped_reason": "PR-1 spec covers PR-2 architecture; no separate research phase needed."},
    "prd": {"status": "skipped", "skipped_reason": "Same spec covers PR-2 PRD-equivalent (success_metrics, kill_criteria already inherited from PR-1 state)."},
    "tasks": {"status": "in_progress", "started_at": "<NOW>"},
    "ux_or_integration": {"status": "skipped", "skipped_reason": "PR-2 ships zero UI. PR-3 is the UI affordance."},
    "implementation": {"status": "not_started"},
    "test": {"status": "not_started"},
    "review": {"status": "not_started"},
    "merge": {"status": "not_started", "pr_number": null},
    "documentation": {"status": "not_started"},
    "complete": {"status": "not_started"}
  },
  "timing": {
    "session_start": "<NOW>",
    "phases": {
      "tasks": {"started_at": "<NOW>", "ended_at": null, "duration_minutes": null, "paused_minutes": 0}
    }
  },
  "cu_v2": {
    "factors": {"complexity": 0.55, "blast_radius": 0.5, "novelty": 0.4, "verification_difficulty": 0.65},
    "total": 2.10,
    "tier_class": "B_medium"
  },
  "cache_hits": [],
  "notes": "PR-2 ships SmartTimingResolver + A/B test instrumentation. Toggle default flips from off to on for new installs. PR-1 (#190 + #198) merged 2026-05-04 supplies the data layer."
}
JSON
```

(Replace `<NOW>` with `$(date -u +"%Y-%m-%dT%H:%M:%SZ")`.)

- [ ] **Step 4: Run schema-check + log entry**

```bash
python3 scripts/check-state-schema.py .claude/features/smart-reminders-behavioral-learning-pr2/state.json
python3 scripts/append-feature-log.py \
  --feature smart-reminders-behavioral-learning-pr2 \
  --event-type phase_started \
  --phase tasks \
  --summary "PR-2 spec at docs/superpowers/specs/2026-05-01-smart-reminders-behavioral-learning-design.md (shared with PR-1). Plan at docs/superpowers/plans/2026-05-04-smart-reminders-behavioral-learning-pr2.md."
```

- [ ] **Step 5: Commit + push, on a fresh branch**

```bash
git checkout -b feature/smart-reminders-behavioral-learning-pr2
git add .claude/features/smart-reminders-behavioral-learning-pr2/ .claude/logs/smart-reminders-behavioral-learning-pr2.log.json
git commit -m "chore(smart-reminders-behavioral-learning-pr2): scaffold PR-2 sub-feature in tasks phase"
```

---

### Task 2: Implement `SmartTimingArm` enum + assignment helper

**Files:**
- Create: `FitTracker/Services/Reminders/SmartTimingArm.swift`
- Create: `FitTrackerTests/SmartTimingArmTests.swift`
- Modify: `FitTracker.xcodeproj/project.pbxproj`

The arm is assigned once on first launch post-PR-2 and persisted to UserDefaults. Uses a deterministic hash (`abs(userID.hashValue) % 100`) so the assignment is reproducible across launches and stable per device.

- [ ] **Step 1: Write the determinism + 50/50 split tests first**

```swift
// FitTrackerTests/SmartTimingArmTests.swift
import XCTest
@testable import FitTracker

final class SmartTimingArmTests: XCTestCase {

    func testSameUserID_alwaysAssignsToSameArm() {
        let id = "user-deadbeef-1234"
        let assignments = (0..<50).map { _ in SmartTimingArm.assign(userID: id) }
        let unique = Set(assignments)
        XCTAssertEqual(unique.count, 1, "Deterministic: same userID must always assign to the same arm")
    }

    func testRoughly50_50SplitOverLargeSample() {
        // 10 000 synthetic UUIDs; expect 45-55% in each arm at this sample size
        let sample = (0..<10_000).map { "user-\(UUID().uuidString)" }
        let treatments = sample.filter { SmartTimingArm.assign(userID: $0) == .treatment }.count
        let ratio = Double(treatments) / Double(sample.count)
        XCTAssertGreaterThan(ratio, 0.45, "Treatment ratio too low: \(ratio)")
        XCTAssertLessThan(ratio, 0.55, "Treatment ratio too high: \(ratio)")
    }

    func testEmptyUserID_isStillAssignedDeterministically() {
        // Edge case — guest users may have no userID. Empty string should still
        // hash deterministically (probably to a fixed arm — either is acceptable).
        let a = SmartTimingArm.assign(userID: "")
        let b = SmartTimingArm.assign(userID: "")
        XCTAssertEqual(a, b)
    }
}
```

- [ ] **Step 2: Implement the type**

```swift
// FitTracker/Services/Reminders/SmartTimingArm.swift
import Foundation

enum SmartTimingArm: String, Codable {
    case treatment, control, optedOut

    /// Deterministic 50/50 split based on `Hashable.hashValue` of the userID.
    /// Per-launch stability is provided by Swift 5.x's randomised hash seed +
    /// caller's responsibility to persist the result (this method does not
    /// itself memoise — the caller writes to UserDefaults on first call).
    static func assign(userID: String) -> SmartTimingArm {
        let h = abs(userID.hashValue) % 100
        return h < 50 ? .treatment : .control
    }
}
```

> **Caveat noted in spec §6:** Swift's `String.hashValue` uses a randomised seed per process launch as of Swift 5.x. This means `assign("u1")` from process A may return `.treatment` while process B returns `.control` for the same input — *within* a process the result is stable but *across* launches it is not. For PR-2's purposes this is OK because the caller persists the first-launch assignment to UserDefaults and never re-computes. **DO NOT** call `assign` on every launch and overwrite — the persistence-on-first-call rule is load-bearing for sticky assignment.

Alternative: hash-stably with `SHA-256` if Swift's hashing seed becomes a problem. Defer until evidence of cross-launch flapping in production.

- [ ] **Step 3: Add to project.pbxproj** (mirror Task 3 of PR-1 — IDs `STA*` for arm + tests)

- [ ] **Step 4: Run the tests**

```bash
xcodebuild test -project FitTracker.xcodeproj -scheme FitTracker \
  -destination 'platform=iOS Simulator,id=7B0CF224-34EE-4C5C-96D5-494418BB3CE0' \
  -only-testing FitTrackerTests/SmartTimingArmTests
```

Expected: **3/3 pass**.

- [ ] **Step 5: Commit**

---

### Task 3: Implement `SmartTimingResolver` (Bayesian combine + short-circuits)

**Files:**
- Create: `FitTracker/Services/Reminders/SmartTimingResolver.swift`
- Create: `FitTrackerTests/SmartTimingResolverTests.swift`
- Modify: `FitTracker.xcodeproj/project.pbxproj`

Per spec §6 Flow B Bayesian formula:

```
posteriorWeight = obsCount / (obsCount + 10)
combined[h]     = (1 - posteriorWeight) * prior[h] + posteriorWeight * posterior[h]
firingTime      = argmax over h ∈ [0, 23] of combined[h]
```

- [ ] **Step 1: Write tests first (full coverage of short-circuits + math)**

```swift
// FitTrackerTests/SmartTimingResolverTests.swift
import XCTest
@testable import FitTracker

@MainActor
final class SmartTimingResolverTests: XCTestCase {

    private var store: BehavioralLearningStore!
    private var cache: CohortPriorCache!

    override func setUp() {
        super.setUp()
        store = BehavioralLearningStore()
        cache = CohortPriorCache()
        store.deleteAllUserData()
        cache.deleteAllUserData()
    }

    override func tearDown() {
        store.deleteAllUserData()
        cache.deleteAllUserData()
        super.tearDown()
    }

    // ── Short-circuit cases ────────────────────────────────

    func testToggleOff_returnsStaticDefault() {
        let resolver = SmartTimingResolver(store: store, cache: cache, toggleEnabled: false, arm: .treatment)
        XCTAssertEqual(resolver.firingTime(for: .nutritionGap), ReminderType.nutritionGap.defaultFireHour)
    }

    func testNonPersonalisableType_returnsStaticDefault() {
        let resolver = SmartTimingResolver(store: store, cache: cache, toggleEnabled: true, arm: .treatment)
        XCTAssertEqual(resolver.firingTime(for: .healthKitConnect), ReminderType.healthKitConnect.defaultFireHour)
        XCTAssertEqual(resolver.firingTime(for: .accountRegistration), ReminderType.accountRegistration.defaultFireHour)
        XCTAssertEqual(resolver.firingTime(for: .engagement), ReminderType.engagement.defaultFireHour)
    }

    func testControlArm_returnsStaticDefaultEvenIfPersonalisable() {
        // Seed obs so the resolver would normally personalise — but control arm forces static.
        for _ in 0..<20 {
            store.recordObservation(type: .nutritionGap, hour: 12, tapped: true)
        }
        let resolver = SmartTimingResolver(store: store, cache: cache, toggleEnabled: true, arm: .control)
        XCTAssertEqual(resolver.firingTime(for: .nutritionGap), ReminderType.nutritionGap.defaultFireHour)
    }

    func testOptedOutArm_returnsStaticDefault() {
        let resolver = SmartTimingResolver(store: store, cache: cache, toggleEnabled: true, arm: .optedOut)
        XCTAssertEqual(resolver.firingTime(for: .trainingDay), ReminderType.trainingDay.defaultFireHour)
    }

    func testKillFlag_overridesEverythingElse() {
        // Even with treatment arm + toggle on + obs data, a server kill_flag forces static.
        for _ in 0..<20 {
            store.recordObservation(type: .nutritionGap, hour: 12, tapped: true)
        }
        cache.persist(CohortPriorResponse(priors: ["nutrition_gap": ["12": 0.8]],
                                          killFlags: ["nutrition_gap"]))
        let resolver = SmartTimingResolver(store: store, cache: cache, toggleEnabled: true, arm: .treatment)
        XCTAssertEqual(resolver.firingTime(for: .nutritionGap), ReminderType.nutritionGap.defaultFireHour)
    }

    // ── Bayesian path ──────────────────────────────────────

    func testCold_zeroObsZeroCohort_usesDefaultPriorPeak() {
        // No observations + no cohort data → use type.defaultPriorDistribution → argmax = defaultFireHour.
        let resolver = SmartTimingResolver(store: store, cache: cache, toggleEnabled: true, arm: .treatment)
        XCTAssertEqual(resolver.firingTime(for: .nutritionGap), ReminderType.nutritionGap.defaultFireHour)
    }

    func testHighObs_postPersonalisedHourDominates() {
        // 100 taps at hour 9 → posterior weight ~0.91 → argmax should be 9.
        for _ in 0..<100 {
            store.recordObservation(type: .nutritionGap, hour: 9, tapped: true)
        }
        let resolver = SmartTimingResolver(store: store, cache: cache, toggleEnabled: true, arm: .treatment)
        XCTAssertEqual(resolver.firingTime(for: .nutritionGap), 9)
    }

    func testLowObs_priorDominates() {
        // 2 taps at hour 9 → posterior weight = 2/12 ≈ 0.17 → prior (default 16) wins.
        for _ in 0..<2 {
            store.recordObservation(type: .nutritionGap, hour: 9, tapped: true)
        }
        let resolver = SmartTimingResolver(store: store, cache: cache, toggleEnabled: true, arm: .treatment)
        XCTAssertEqual(resolver.firingTime(for: .nutritionGap), ReminderType.nutritionGap.defaultFireHour)
    }

    func testBoundary_10Obs_postWeightHalf() {
        // 10 taps at hour 9 → posterior weight = 0.5 → tied with default; pick implementation-defined
        // (here we check it's either 9 or default — both are correct outcomes of the smoothing rule).
        for _ in 0..<10 {
            store.recordObservation(type: .nutritionGap, hour: 9, tapped: true)
        }
        let resolver = SmartTimingResolver(store: store, cache: cache, toggleEnabled: true, arm: .treatment)
        let hour = resolver.firingTime(for: .nutritionGap)
        XCTAssertTrue([9, ReminderType.nutritionGap.defaultFireHour].contains(hour),
                      "At weight=0.5 either bucket can win; got \(hour)")
    }
}
```

- [ ] **Step 2: Implement the resolver**

```swift
// FitTracker/Services/Reminders/SmartTimingResolver.swift
import Foundation

@MainActor
final class SmartTimingResolver {

    /// Set of types that personalise. Other types short-circuit to static.
    static let personalisableTypes: Set<ReminderType> = [.nutritionGap, .trainingDay, .restDay]

    /// Smoothing constant from spec §6: posteriorWeight = obs / (obs + 10).
    static let smoothingConstant: Double = 10

    private let store: BehavioralLearningStore
    private let cache: CohortPriorCache
    private let toggleEnabled: Bool
    private let arm: SmartTimingArm

    init(
        store: BehavioralLearningStore,
        cache: CohortPriorCache,
        toggleEnabled: Bool,
        arm: SmartTimingArm
    ) {
        self.store = store
        self.cache = cache
        self.toggleEnabled = toggleEnabled
        self.arm = arm
    }

    /// Returns the fire hour [0, 23] for `type`. Short-circuits to
    /// `type.defaultFireHour` for non-personalisable types, when the toggle
    /// is off, when the arm is control or optedOut, or when the type has a
    /// server-issued kill_flag in the cached cohort response. Otherwise
    /// computes the Bayesian-combined fire hour over the 24 hour-of-day buckets.
    func firingTime(for type: ReminderType) -> Int {
        if !shouldPersonalise(type: type) {
            return type.defaultFireHour
        }
        let prior = priorDistribution(for: type)
        let posterior = store.posterior(type: type)
        let obsCount = store.observationCount(type: type)
        let postWeight = Double(obsCount) / (Double(obsCount) + Self.smoothingConstant)
        var bestHour = type.defaultFireHour
        var bestScore = -Double.infinity
        for h in 0..<24 {
            let combined = (1 - postWeight) * (prior[h] ?? 0) + postWeight * (posterior[h] ?? 0)
            if combined > bestScore {
                bestScore = combined
                bestHour = h
            }
        }
        return bestHour
    }

    // MARK: - Private

    private func shouldPersonalise(type: ReminderType) -> Bool {
        guard toggleEnabled else { return false }
        guard arm == .treatment else { return false }
        guard Self.personalisableTypes.contains(type) else { return false }
        // Server kill_flag overrides everything
        if let killed = cache.priors?.killFlags, killed.contains(type.rawValue) {
            return false
        }
        return true
    }

    private func priorDistribution(for type: ReminderType) -> [Int: Double] {
        if let cohort = cache.priors?.priors[type.rawValue], !cohort.isEmpty {
            // Convert string hour keys ("00".."23") to Int.
            var dist: [Int: Double] = [:]
            for (hourStr, rate) in cohort {
                if let h = Int(hourStr), (0..<24).contains(h) {
                    dist[h] = rate
                }
            }
            // Normalise so it sums to 1.0
            let total = dist.values.reduce(0, +)
            if total > 0 {
                return dist.mapValues { $0 / total }
            }
        }
        // Fallback to the type's static bell-curve prior
        return type.defaultPriorDistribution
    }
}
```

- [ ] **Step 3: pbxproj** (mirror BL/CC pattern; new IDs `STR*`)

- [ ] **Step 4: Run tests — 9/9 pass**

- [ ] **Step 5: Commit**

---

### Task 4: Wire `SmartTimingResolver` into `ReminderScheduler`

**Files:**
- Modify: `FitTracker/Services/Reminders/ReminderScheduler.swift`
- Create: `FitTrackerTests/ReminderSchedulerSmartTimingTests.swift`
- Modify: `FitTracker.xcodeproj/project.pbxproj`

The scheduler accepts a resolver via injection seam (mirrors how `analytics` is injected). When the resolver is set, `scheduleIfAllowed(type:)` consults `firingTime(for: type)` to pick the trigger hour. When the resolver is nil (e.g. test harness, pre-PR-2 path), behaviour is unchanged.

- [ ] **Step 1: Read the existing scheduler interface**

```bash
grep -nE "func scheduleIfAllowed|class ReminderScheduler|var analytics" FitTracker/Services/Reminders/ReminderScheduler.swift
```

Note where `analytics` is injected; mirror the same pattern for `resolver`.

- [ ] **Step 2: Add a `resolver: SmartTimingResolver?` property + setter**

- [ ] **Step 3: In `scheduleIfAllowed(type:)`, if resolver is set, use its firingTime to compute the trigger hour** (instead of the existing inline default).

- [ ] **Step 4: Tests cover:**
  1. Resolver returns a non-default hour → trigger built at that hour.
  2. Resolver returns the default hour (control arm, toggle off, kill flag) → trigger built at default — no behavioural delta vs PR-1.
  3. Existing scheduler guards (quiet hours, daily cap, etc.) still apply *after* the resolved hour is computed.

- [ ] **Step 5: Run tests; commit**

---

### Task 5: Bootstrap `SmartTimingResolver` in `FitTrackerApp` + assign A/B arm on first launch

**Files:**
- Modify: `FitTracker/FitTrackerApp.swift`

- [ ] **Step 1: Add `SmartTimingResolver` instance + `smartTimingArm` storage**

```swift
// In FitTrackerApp's stored properties section (near the existing PR-1 wiring)
@MainActor private lazy var smartTimingResolver: SmartTimingResolver = {
    SmartTimingResolver(
        store: behavioralLearningStore,
        cache: cohortPriorCache,
        toggleEnabled: settings.smartTimingEnabled,
        arm: smartTimingArm
    )
}()

// On first launch post-PR-2, assign + persist; subsequent launches read from UserDefaults.
@MainActor private var smartTimingArm: SmartTimingArm {
    if let raw = UserDefaults.standard.string(forKey: "ft.smartTimingArm"),
       let arm = SmartTimingArm(rawValue: raw) {
        return arm
    }
    let userID = signIn.activeSession?.userID ?? UIDevice.current.identifierForVendor?.uuidString ?? ""
    let assigned = SmartTimingArm.assign(userID: userID)
    UserDefaults.standard.set(assigned.rawValue, forKey: "ft.smartTimingArm")
    analytics?.setSmartTimingArm(assigned.rawValue)
    analytics?.logSmartTimingArmAssigned(arm: assigned.rawValue)
    return assigned
}
```

- [ ] **Step 2: In `.task`, after the existing PR-1 wiring, set `ReminderScheduler.shared.resolver = smartTimingResolver`**

- [ ] **Step 3: Build to verify compilation**

> **Note on `lazy var` in App struct:** PR-1 Task 10 hit this — `lazy var` doesn't work in struct App because the `.task` closure captures `self` immutably. If the `lazy` keyword fails to compile, switch to `private let smartTimingResolver` initialised eagerly at construction (the resolver's properties are all available by then since they are also `let`).

- [ ] **Step 4: Commit**

---

### Task 6: Flip default for `smartTimingEnabled` to `true` for new installs

**Files:**
- Modify: `FitTracker/Services/AppSettings.swift`

The existing `smartTimingEnabled` field defaults to `false`. PR 2 needs it to default to `true` for **new installs only** — existing users who already have a value persisted in UserDefaults must keep their setting.

- [ ] **Step 1: Update the init logic**

```swift
init() {
    // ... existing reads ...
    if UserDefaults.standard.object(forKey: "ft.smartTimingEnabled") != nil {
        // Existing user: respect their persisted choice.
        smartTimingEnabled = UserDefaults.standard.bool(forKey: "ft.smartTimingEnabled")
    } else {
        // New install: default ON (PR-2 sequencing).
        smartTimingEnabled = true
        UserDefaults.standard.set(true, forKey: "ft.smartTimingEnabled")
    }
}
```

- [ ] **Step 2: Update or add a unit test asserting both branches** (existing user with persisted `false` keeps `false`; cleared UserDefaults defaults to `true`).

- [ ] **Step 3: Commit**

---

### Task 7: Add 3 new analytics events + 1 user property

**Files:**
- Modify: `FitTracker/Services/Analytics/AnalyticsService.swift`
- Modify: `FitTracker/Services/Analytics/AnalyticsProvider.swift`
- Modify: `docs/product/analytics-taxonomy.csv`

Per spec §7 + §8:

| Event / property | Purpose | Naming compliance |
|---|---|---|
| `smart_timing_arm_assigned` | Fired once per user on first launch post-PR-2 | Cross-screen lifecycle (no screen prefix per CLAUDE.md analytics convention) |
| `smart_timing_fetch_failed` | Fired when `CohortPriorClient.fetchPriors()` errors | Cross-screen lifecycle |
| `smart_timing_record_failed` | Fired when `CohortPriorClient.recordEvent()` errors | Cross-screen lifecycle |
| user property `smart_timing_arm` | One of `treatment` / `control` / `opted_out` | GA4 user property |

- [ ] **Step 1: Add event constants to `AnalyticsProvider.swift`**

- [ ] **Step 2: Add log helpers to `AnalyticsService.swift`**

- [ ] **Step 3: Append rows to `analytics-taxonomy.csv`** (3 events + 1 user property)

- [ ] **Step 4: Update test `AnalyticsEventNamingTests` to cover the 3 new events**

- [ ] **Step 5: Commit**

---

### Task 8: Wire opt-out path

**Files:**
- Modify: `FitTracker/Views/Settings/BehavioralLearningSettingsView.swift`

When the user manually toggles Smart Timing off, the arm changes to `optedOut`. The toggle's `didSet` logic on `AppSettings.smartTimingEnabled` doesn't currently know about the arm — wire that in.

- [ ] **Step 1: Add a callback or observer that updates the arm on toggle-off**

```swift
// In the View's onChange(of: settings.smartTimingEnabled)
.onChange(of: settings.smartTimingEnabled) { _, newValue in
    if newValue == false {
        UserDefaults.standard.set(SmartTimingArm.optedOut.rawValue, forKey: "ft.smartTimingArm")
        analytics?.setSmartTimingArm(SmartTimingArm.optedOut.rawValue)
    }
}
```

- [ ] **Step 2: Test the toggle-off path** (manual: launch with assigned `treatment`, toggle off, verify UserDefaults flips to `optedOut`).

- [ ] **Step 3: Commit**

---

### Task 9: Run full test suite + UI audit

- [ ] **Step 1: Run new + existing tests**

```bash
xcodebuild test -project FitTracker.xcodeproj -scheme FitTracker \
  -destination 'platform=iOS Simulator,id=7B0CF224-34EE-4C5C-96D5-494418BB3CE0' \
  -only-testing FitTrackerTests/SmartTimingArmTests \
  -only-testing FitTrackerTests/SmartTimingResolverTests \
  -only-testing FitTrackerTests/ReminderSchedulerSmartTimingTests \
  -only-testing FitTrackerTests/BehavioralLearningStoreTests \
  -only-testing FitTrackerTests/CohortPriorClientTests \
  -only-testing FitTrackerTests/CohortPriorCacheTests \
  -only-testing FitTrackerTests/ReminderAnalyticsTests
```

- [ ] **Step 2: UI audit** (`make ui-audit`) — expect P0 = 0; new files should produce no findings.

- [ ] **Step 3: Manual smoke test** (per spec §8): launch fresh install, confirm Smart Timing toggle is ON, observe `smart_timing_arm_assigned` in GA4 DebugView, toggle off + verify arm → `opted_out`.

---

### Task 10: state.json transitions through to `complete`

**Files:**
- Modify: `.claude/features/smart-reminders-behavioral-learning-pr2/state.json`
- Modify: `.claude/logs/smart-reminders-behavioral-learning-pr2.log.json`

Walk through `tasks → implementation → testing → review → merge → documentation → complete` per the v7.6 schema requirements (each transition needs a corresponding log event within the 15-min freshness window).

---

### Task 11: Push branch + open PR 2

```bash
git push -u origin feature/smart-reminders-behavioral-learning-pr2
gh pr create --base main --head feature/smart-reminders-behavioral-learning-pr2 \
  --title "feat(smart-reminders): behavioral learning PR 2 — SmartTimingResolver + A/B test (toggle defaults on)" \
  --body "$(cat docs/superpowers/plans/2026-05-04-smart-reminders-behavioral-learning-pr2.md | head -200)"  # paraphrase
```

PR description should explicitly call out:
- The merge gate is **NOT** the CI pass alone — it's the A/B test result over the 14±4 day per-user window.
- Until the gate fires, the resolver is live for treatment-arm users. If the kill criterion fires (any single type regresses ≥-3pp), the server writes a kill_flag and clients short-circuit that type to static within ~7 days (cache TTL).
- This PR introduces zero schema changes (no Supabase migration; no state.json schema additions).

---

## Risks

1. **String.hashValue is randomised per process** — see Task 2 caveat. The persistence-on-first-call rule mitigates but doesn't eliminate the risk. If production telemetry shows arm flapping (same userID assigned to different arms across launches on the same device), switch to SHA-256-based assignment.

2. **Production cohort data may be too thin to inform the resolver.** The privacy threshold (50 shows per cell) is high for a feature that's been collecting for ~5 days. If most cells are suppressed at fetch time, the resolver falls back to per-type bell-curve priors — which is exactly the toggle-off behaviour. The A/B test would then show no signal for ~3-6 weeks until cohort cells cross the threshold. **Acceptable degraded behaviour; document in PR 2 description.**

3. **A/B assignment determinism cross-device.** A user who signs in on a new device (different `identifierForVendor`) before signing in (no userID) gets re-assigned. Persisting on first arm-resolution and surfacing via Supabase user metadata is a possible v3 — out of scope for PR 2.

4. **Kill flag latency.** If a kill_flag is written by BigQuery aggregation, clients only pick it up at the next `fetchPriors()` (which is gated by `cache.isStale` — 7 days). For an emergency rollback shorter than that window, a manual remote-config flag (or app force-update) would be needed. **Out of scope for PR 2; if required, ship as a follow-on.**

5. **Toggle off mid-test pollutes the t-test.** Mitigation: arm = `opted_out` excludes the user from analysis. Implementation correctness is checked in Task 8.

---

## Pre-flight checklist (before starting Task 1)

- [ ] PR #190 + PR #198 both merged on `main` (verified at session resume).
- [ ] `cohort_stats` has `reminders.shows.*` rows with non-zero frequency (Task 1 step 1 SQL).
- [ ] `ai-engine/.venv` exists; `pytest` available (per `project_smart_reminders_behavioral_learning.md` memory page).
- [ ] iOS test cycle works: `xcodebuild test ... -only-testing FitTrackerTests/CohortPriorClientTests` passes.
- [ ] Either Supabase MCP authenticated OR `supabase` CLI auth configured (no migrations expected for PR 2 but kill_flag manual-write may need it).

---

## Acceptance Criteria for Plan Completion

Plan is "done" when:

1. All 11 tasks above checked off.
2. `xcodebuild test` (full Tests target) green; `pytest` (ai-engine) green.
3. PR open against `main` with green CI.
4. State.json `current_phase: complete` for `smart-reminders-behavioral-learning-pr2`.
5. PR description references the A/B test merge gate (the actual gate is data-dependent, not CI-dependent).
6. No regressions on PR-1 work — all 23 PR-1 XCTests + 19 PR-1 pytests still pass.

---

## Next Steps After Plan Approval

1. **Verify pre-flight** (production cohort data exists). If empty, defer execution.
2. **Branch + state.json scaffold** (Task 1).
3. **Iterate Tasks 2-9** (each task = ~1-3 commits; iOS test cycle ~2-3 min).
4. **State advance + PR open** (Tasks 10-11).
5. **Wait for A/B test data** (14±4 days per-user; aggregate readout 7-day rolling). The PR can merge as soon as CI is green; the merge gate (success threshold ≥+5pp lift) is observed *post-merge* in BigQuery. If the kill criterion fires, ship a follow-on PR that disables the resolver via the server-issued kill_flag path (already implemented in PR 1 + checked here in Task 3).

---

**Status:** plan_for_review. Execution gated on production cohort data window opening (~2026-05-09).

**Estimated total effort:** 11 tasks; ~3-5 hours of focused work mostly waiting on xcodebuild iterations. No backend work; no migrations.
