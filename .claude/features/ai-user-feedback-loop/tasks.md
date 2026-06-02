# C5 — AI User Feedback Loop — Phase 2 Task Breakdown

> **Status:** Phase 2 (Tasks) — in flight
> **PRD source:** [`docs/product/prd/ai-user-feedback-loop.md`](../../docs/product/prd/ai-user-feedback-loop.md)
> **Branch:** `feature/ai-user-feedback-loop`

12 discrete tasks, ordered by dependency. Estimates are LoC (≈ size of NEW or NET-CHANGED code; existing-code mutation is counted as 1× lines touched).

---

## Task graph (dependency)

```
T1 (Memory 30d window)
   ↓
T2 (FeedbackController facade)
   ↓
   ├──→ T3 (AppSettings opt-out flag)
   │    ↓
   │    T4 (FitTrackerApp @StateObject injection)
   │         ↓
T5 ──┘    T6 (AIInsightCard wire — replace UI-024 comment)
(AIOrchestrator     │
 reinforcement      │
 loop block)        ↓
   ↓           T7 (DismissReasonPicker view)
   ↓                ↓
   ↓           T8 (AIFeedbackView dismiss-reason wire)
   ↓                
   ↓           T9 (AIFeedbackSettingsScreen)
   ↓                ↓
   ↓           T10 (SettingsView aiFeedback row)
   ↓
T11 (AnalyticsService 3 new logAi* methods)
   ↓
T12 (Tests: 4 new test files, ~20 tests)
```

T1, T3, T5 can begin in parallel — they touch independent files. T6, T8, T10 each depend on a single upstream. T12 lands last.

---

## T1 — `RecommendationMemory.frequentlyDismissedSignals` → 30-day window

**File:** `FitTracker/AI/RecommendationMemory.swift` (modify)

**Change:** Extend the existing method signature with an optional `Date` parameter (defaulted) and apply a timestamp filter before the count tally.

```swift
func frequentlyDismissedSignals(
    for segment: AISegment,
    threshold: Int = 3,
    within window: TimeInterval = 30 * 24 * 60 * 60,
    now: Date = Date()
) -> [String]
```

Filter dismissed outcomes to `now.timeIntervalSince($0.timestamp) <= window` before bucketing.

**LoC:** ~12 (3 new params + 1 filter line + comment)
**Tests:** T12.A — adds 2 new tests covering the window filter (in-window dismissal counted, out-of-window not)
**Risk:** Backward-compatible — default value preserves existing behavior at call sites.

---

## T2 — `RecommendationFeedbackController` facade

**File:** `FitTracker/AI/RecommendationFeedbackController.swift` (NEW)

**Purpose:** Thin `@MainActor ObservableObject` exposing `RecommendationMemory` to SwiftUI views. Publishes `totalCount` reactively for Settings UI. Owns segment-level computed properties.

```swift
@MainActor
final class RecommendationFeedbackController: ObservableObject {
    private let memory: RecommendationMemory
    @Published private(set) var totalCount: Int = 0

    init(memory: RecommendationMemory = RecommendationMemory()) {
        self.memory = memory
        self.totalCount = memory.totalCount
    }

    func record(outcome: RecommendationOutcome) {
        memory.record(outcome: outcome)
        totalCount = memory.totalCount
    }

    func acceptanceRate(for segment: AISegment) -> Double? {
        memory.acceptanceRate(for: segment)
    }

    func frequentlyDismissedSignals(for segment: AISegment) -> [String] {
        memory.frequentlyDismissedSignals(for: segment)
    }

    func outcomes(for segment: AISegment) -> [RecommendationOutcome] {
        memory.outcomes(for: segment)
    }

    func clearAll() {
        memory.clearAll()
        totalCount = 0
    }
}
```

**LoC:** ~50
**Tests:** T12.B — 4 new tests (init reads totalCount; record bumps published count; clearAll resets; per-segment queries pass through)
**Risk:** New file, no behavior change to existing AIOrchestrator.

---

## T3 — `AppSettings.aiFeedbackLoopEnabled` toggle

**File:** `FitTracker/Services/AppSettings.swift` (modify) — add `@Published var aiFeedbackLoopEnabled: Bool` with UserDefaults persistence key `"ft.ai.feedbackLoopEnabled"`. Default `true`.

Follow the existing pattern (e.g., `notificationsEnabled` if such a flag exists; otherwise mirror the closest sibling pattern in the file).

**LoC:** ~15 (1 property + 1 didSet/UserDefaults sync + 1 load on init)
**Tests:** T12.C — 1 test (default true; persists across re-init)
**Risk:** Trivial; AppSettings churn is low.

---

## T4 — `FitTrackerApp` @StateObject injection

**File:** `FitTracker/FitTrackerApp.swift` (modify) — add:

```swift
@StateObject private var feedbackController = RecommendationFeedbackController()
```

Then thread `.environmentObject(feedbackController)` onto the app's root view (after existing env-object chain).

**LoC:** ~3
**Tests:** none directly — verified via T6 + T9 integration tests when views read the env-object successfully.
**Risk:** Low; SwiftUI env-object pattern already used everywhere in the file.

---

## T5 — AIOrchestrator reinforcement-loop block

**File:** `FitTracker/AI/AIOrchestrator.swift` (modify)

**Insertion point:** between line 121 (after `finalRecommendation` is set) and line 122 (`latestRecommendations[segment] = finalRecommendation`).

```swift
// C5 — apply user-feedback reinforcement before publishing
let publishedRecommendation: AIRecommendation
if let memory = feedbackMemory, settings.aiFeedbackLoopEnabled {
    publishedRecommendation = applyReinforcementLoop(
        recommendation: finalRecommendation,
        segment: segment,
        memory: memory
    )
} else {
    publishedRecommendation = finalRecommendation
}
latestRecommendations[segment] = publishedRecommendation
```

The `feedbackMemory` and `settings` properties get injected at init time (optional `RecommendationMemory?` + `AppSettings`; nil-pass keeps existing test paths working). `applyReinforcementLoop` is a new private method:

```swift
private func applyReinforcementLoop(
    recommendation: AIRecommendation,
    segment: AISegment,
    memory: RecommendationMemory
) -> AIRecommendation {
    let dismissed = memory.frequentlyDismissedSignals(for: segment)
    let rate = memory.acceptanceRate(for: segment)
    let signalsTouched = recommendation.signals.filter { dismissed.contains($0) }
    let shouldDowngrade = !signalsTouched.isEmpty
    let shouldUpgrade = !shouldDowngrade && (rate ?? 0) > 0.70

    if shouldDowngrade {
        analytics.logAiFeedbackSignalSuppressed(segment: segment, signal: signalsTouched[0], dismissalCount: dismissed.count)
        return recommendation.withConfidence(downgrade(recommendation.confidence))
    } else if shouldUpgrade {
        let count = memory.outcomes(for: segment).filter { $0.action != .ignored }.count
        analytics.logAiFeedbackSegmentBoosted(segment: segment, acceptanceRate: Int((rate ?? 0) * 100), outcomeCount: count)
        return recommendation.withConfidence(upgrade(recommendation.confidence))
    }
    return recommendation
}
```

**LoC:** ~40 (init param + the block + private helper + 2 tier-mutation helpers)
**Tests:** T12.D — 5 new tests in `AIOrchestratorTests.swift` (no-memory → unchanged; suppressed signal → downgraded; high acceptance → upgraded; opt-out disables loop; quorum-below-5 → unchanged)
**Risk:** Behavior change to publish path. `AIRecommendation.withConfidence` helper may need adding as part of this task — check existing API; if absent, add a trivial pure-mutation method.

---

## T6 — `AIInsightCard.recordFeedback` real call (replace UI-024)

**File:** `FitTracker/Views/AI/AIInsightCard.swift` (modify lines 230-235 region)

Delete the audit UI-024 comment block. Replace with:

```swift
@EnvironmentObject private var feedbackController: RecommendationFeedbackController
// (declaration at struct top)

// inside recordFeedback(_ action: UserAction):
feedbackController.record(outcome: RecommendationOutcome(
    segment: validated.recommendation.segment,
    signals: validated.recommendation.signals,
    confidenceLevel: validated.overallConfidence.rawValue,
    source: validated.recommendation.sourceTier,
    action: action,
    dismissReason: nil
))
```

**LoC:** ~10 net (delete 6, add 8 + 1 env-object property)
**Tests:** T12.E — 1 test confirming after-tap totalCount delta on the controller (UI-level via ViewInspector or via a mock-controller injection helper).
**Risk:** Audit UI-024 ships closed.

---

## T7 — `DismissReasonPicker` view

**File:** `FitTracker/Views/AI/DismissReasonPicker.swift` (NEW)

A `confirmationDialog` modifier wrapper exposing the 5-enum picker + free-text fallback sheet (80-char cap). Returns the picked reason via closure.

```swift
struct DismissReasonPicker: ViewModifier {
    @Binding var isPresented: Bool
    let onPick: (DismissReason) -> Void
    @State private var showOtherSheet = false
    @State private var otherText: String = ""

    enum DismissReason: String {
        case notRelevant = "not_relevant"
        case alreadyAware = "already_aware"
        case disagree = "disagree"
        case repetitive = "repetitive"
        case other = "other"
    }
    // body: confirmationDialog + secondary sheet for `.other` free-text
}
```

Free-text sheet uses `TextField` with `.onChange(of: otherText)` capping at 80 chars.

**LoC:** ~80
**Tests:** T12.F — 2 tests (5 enum strings stable; 80-char cap enforced)
**Risk:** New view. Sheet presentation patterns already used in AIFeedbackView.

---

## T8 — `AIFeedbackView` dismiss-reason wire

**File:** `FitTracker/Views/AI/AIFeedbackView.swift` (modify)

On thumbs-down tap, set `showDismissReasonPicker = true`. Apply the new `DismissReasonPicker` modifier. The picked reason flows into `RecommendationOutcome.dismissReason` via the controller call (which now accepts an optional reason).

```swift
@EnvironmentObject private var feedbackController: RecommendationFeedbackController
@State private var showDismissReasonPicker = false

.modifier(DismissReasonPicker(isPresented: $showDismissReasonPicker) { reason in
    // record outcome with reason
})
```

The existing analytics call (`logAiFeedbackSubmitted`) stays unchanged.

**LoC:** ~25
**Tests:** T12.G — 1 test (dismiss-reason picker surfaces only on thumbs-down)
**Risk:** UI-level — manual smoke recommended in Phase 5.

---

## T9 — `AIFeedbackSettingsScreen` view

**File:** `FitTracker/Views/Settings/v2/Screens/AIFeedbackSettingsScreen.swift` (NEW)

Settings detail screen with 4 sections:

1. **Header** — `"AI Feedback"` + total outcomes (or empty state if 0)
2. **Per-segment breakdown** — iterates over `AISegment.allCases`, shows percentage + outcome count + below-quorum dash
3. **Suppressed signals** — list from `frequentlyDismissedSignals(for:)` per segment
4. **Footer** — opt-out toggle (bound to `settings.aiFeedbackLoopEnabled`) + clear-all button with confirmation dialog

```swift
struct AIFeedbackSettingsScreen: View {
    @EnvironmentObject var feedbackController: RecommendationFeedbackController
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var analytics: AnalyticsService
    @State private var showClearConfirm = false
    // ...
}
```

Clear-all calls `feedbackController.clearAll()` + fires `home_ai_feedback_history_cleared` analytics with `total_outcomes_cleared`.

**LoC:** ~180
**Tests:** T12.H — 3 tests (empty state shown when totalCount=0; per-segment table renders all 4 segments; clear-all triggers controller + analytics)
**Risk:** Largest new surface. Token compliance via `AppSpacing` / `AppColor` / `AppText` — must keep P0=0 on `make ui-audit`.

---

## T10 — `SettingsView` aiFeedback row

**File:** `FitTracker/Views/Settings/v2/SettingsView.swift` (modify)

Add `case aiFeedback` to the `SettingsCategory` enum (line 8 region). Provide `title`, `subtitle`, `icon` (`"hand.thumbsup.fill"`), `tint` (`AppColor.Accent.primary`).

Wire `navigationDestination` to `AIFeedbackSettingsScreen()`.

**LoC:** ~25 (5 switch cases × 1 line each + 1 navigation case + enum case)
**Tests:** T12.I — 1 test (SettingsCategory.allCases includes .aiFeedback)
**Risk:** Low; pattern already established by 6 sibling categories.

---

## T11 — `AnalyticsService` 3 new `logAi*` methods

**File:** `FitTracker/Services/Analytics/AnalyticsService.swift` (modify) — add:

```swift
func logAiFeedbackSignalSuppressed(segment: AISegment, signal: String, dismissalCount: Int) {
    logEvent("home_ai_feedback_signal_suppressed", params: [
        "segment": segment.rawValue, "signal": signal, "dismissal_count": dismissalCount
    ])
}

func logAiFeedbackSegmentBoosted(segment: AISegment, acceptanceRate: Int, outcomeCount: Int) {
    logEvent("home_ai_feedback_segment_boosted", params: [
        "segment": segment.rawValue, "acceptance_rate": acceptanceRate, "outcome_count": outcomeCount
    ])
}

func logAiFeedbackHistoryCleared(totalOutcomesCleared: Int) {
    logEvent("home_ai_feedback_history_cleared", params: [
        "total_outcomes_cleared": totalOutcomesCleared
    ])
}
```

**File:** `FitTracker/Services/Analytics/AnalyticsProvider.swift` — add the 3 event-name constants.

**LoC:** ~30
**Tests:** T12.J — 1 test confirming all 3 events fire with correct param shape (via `MockAnalyticsService`)
**Risk:** Pattern matches `logHomeReadinessAlertActionTaken` (C2) + `logHomeTrendAlertActionTaken` (C4) shipped 2026-06-01.

---

## T12 — Test suite

**Files (NEW):**

- `FitTrackerTests/RecommendationMemoryWindowTests.swift` (T12.A — 2 tests)
- `FitTrackerTests/RecommendationFeedbackControllerTests.swift` (T12.B — 4 tests)
- `FitTrackerTests/AISettingsFeedbackToggleTests.swift` (T12.C — 1 test)
- `FitTrackerTests/AIOrchestratorReinforcementTests.swift` (T12.D — 5 tests)
- `FitTrackerTests/Views/AIInsightCardRecordFeedbackTests.swift` (T12.E — 1 test)
- `FitTrackerTests/Views/DismissReasonPickerTests.swift` (T12.F — 2 tests)
- `FitTrackerTests/Views/AIFeedbackViewPickerTests.swift` (T12.G — 1 test)
- `FitTrackerTests/Views/AIFeedbackSettingsScreenTests.swift` (T12.H — 3 tests)
- `FitTrackerTests/SettingsCategoryFeedbackCaseTests.swift` (T12.I — 1 test)
- `FitTrackerTests/AnalyticsAIFeedbackEventsTests.swift` (T12.J — 1 test)

**Total:** 21 new tests across 10 new test files. All use `UserDefaults(suiteName:)` instances for isolation per existing `RecommendationMemoryTests` pattern.

**LoC:** ~400 (mostly XCTestCase boilerplate + assertions)
**Coverage target:** ≥ 90% on all new production files (T2/T7/T9/T11) verified via Slather post-merge.

**File:** `FitTracker.xcodeproj/project.pbxproj` (modify) — add all 13 new files (10 test + 3 source: T2 controller, T7 picker, T9 settings screen) to their respective targets.

---

## Out-of-scope guards

The following remain explicitly out-of-scope per PRD §"Enhancements (future C5.b/c/d)":

- Time-decay weighting (C5.b)
- Cross-routing C2 + C4 banner action_taken events into RecommendationMemory (C5.c)
- Cohort-level aggregation (C5.d → D1)
- Suppression-transparency UX (C5.e)
- Server-side dismiss-reason aggregation (privacy boundary)

If any task discovers a need for these, file a backlog row + flag in PR description. Don't expand scope mid-Phase 4.

---

## Phase 4 (Implement) ordering

Recommended landing order (each commit standalone + buildable):

1. **T1 + T3 + T11** — pure infrastructure (Memory window, AppSettings flag, analytics methods). No view churn. Single commit if convenient.
2. **T2 + T4** — Controller + env-object plumbing. Standalone commit.
3. **T5** — Orchestrator reinforcement block. Behavior change. Standalone commit with T12.D tests in same commit.
4. **T6** — UI-024 closure (the headline change). Standalone commit + T12.E test.
5. **T7 + T8** — Dismiss-reason picker + wire. Standalone commit + T12.F + T12.G tests.
6. **T9 + T10** — Settings screen + row. Standalone commit + T12.H + T12.I tests.
7. **Final** — `make ui-audit` P0=0 + `make tokens-check` + `xcodebuild test` green. Update CASE_STUDY.md placeholder.

Estimated total LoC: **~870** (470 production + 400 tests).

---

## Phase transition criteria

| From → To | Criterion |
|---|---|
| tasks → implement | Operator approves this Phase 2 tasks.md (scope frozen + ordering OK) |
| implement → test | All 12 tasks complete; project.pbxproj wires all 13 new files; `xcodebuild build -scheme FitTracker` exits 0 |
| test → review | All 21 tests pass; coverage ≥ 90% on new files; `make ui-audit` P0=0; `make tokens-check` green |
| review → merge | `/ux pre-merge-review` + `/design pre-merge-review` both pass + PR description includes Figma node IDs (none added by C5 — no new Figma surfaces, all reuse existing tokens/components) |
| merge → complete | PR merged; FEATURE_CLOSURE_COMPLETENESS gate passes |

---

## Cross-references

- PRD: `docs/product/prd/ai-user-feedback-loop.md`
- Research: `.claude/features/ai-user-feedback-loop/research.md`
- State.json: `.claude/features/ai-user-feedback-loop/state.json`
- Existing storage: `FitTracker/AI/RecommendationMemory.swift`
- Existing UI tap site: `FitTracker/Views/AI/AIInsightCard.swift:230-235`
- Sibling pattern C2: `docs/case-studies/readiness-aware-training-alert-case-study.md`
- Sibling pattern C4: `docs/case-studies/trend-alerts-hrv-case-study.md`
