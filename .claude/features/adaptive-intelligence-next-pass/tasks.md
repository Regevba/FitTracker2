# D1 — Adaptive Intelligence Next Pass — Phase 2 Task Breakdown

> **Status:** Phase 2 (Tasks) — in flight
> **PRD source:** [`docs/product/prd/adaptive-intelligence-next-pass.md`](../../docs/product/prd/adaptive-intelligence-next-pass.md)
> **Branch:** `feature/adaptive-intelligence-next-pass`
> **Locked pair:** D1.a (time-decay + trend) + D1.d (transparency UX)

9 discrete tasks. ~600 LoC total per PRD Phase 4 estimate.

---

## Dependency on C5

D1 extends C5's `RecommendationMemory` + `AIOrchestrator` reinforcement-loop block. C5 (PR #572) is merged to main. All API surfaces D1 calls exist on main.

---

## Task graph

```
T1 (AnalyticsProvider constants + Service methods — 3 events + 4 params)
   ↓
T2 (RecommendationMemory persisted fields — manualUnsuppressions[] + blacklistedSignals[])
   ↓
T3 (AcceptanceTrendDetector pure helper)
   ↓
T4 (AIOrchestrator reinforcement-loop extension — time-decay + trend gate)
   ↓
T5 (SuppressedSignalDetailScreen — D1.d transparency UX)
   ↓
T6 (AIFeedbackSettingsScreen row-tap routing — NavigationLink wires)
   ↓
T7 (project.pbxproj wiring for new source + test files)
   ↓
T8 (Test suite — 4 new test files, ~14 tests)
   ↓
T9 (Final verify-local + case study + state→testing + backlog strike)
```

T1+T2 parallel-startable. T3 depends on T2 (fields exist). T4 depends on T3 (helper). T5 depends on T2 (reads new fields). T6 depends on T5 (push destination). T7+T8 land after T1-T6. T9 wraps.

---

## T1 — AnalyticsProvider + AnalyticsService

**Files:**
- `FitTracker/Services/Analytics/AnalyticsProvider.swift` (modify)
- `FitTracker/Services/Analytics/AnalyticsService.swift` (modify)

**Change:** Add 3 new event constants (4th from PRD already covered by `home_ai_feedback_signal_unsuppressed_by_trend` + `_suppressed_detail_opened` + `_signal_manually_unsuppressed` + `_signal_blacklisted_permanently`). Add 4 new param constants (`prior_dismissal_count`, `days_since_last_dismiss`, `via_trend` — `dismissal_count` + `signal` + `segment` reuse C5 constants).

```swift
enum AnalyticsEvent {
    // ── D1 Adaptive Intelligence (screen-prefixed: home_) ──
    static let homeAiFeedbackSignalUnsuppressedByTrend  = "home_ai_feedback_signal_unsuppressed_by_trend"
    static let homeAiFeedbackSuppressedDetailOpened     = "home_ai_feedback_suppressed_detail_opened"
    static let homeAiFeedbackSignalManuallyUnsuppressed = "home_ai_feedback_signal_manually_unsuppressed"
    static let homeAiFeedbackSignalBlacklistedPermanently = "home_ai_feedback_signal_blacklisted_permanently"
}

enum AnalyticsParam {
    static let priorDismissalCount   = "prior_dismissal_count"   // int 3+
    static let daysSinceLastDismiss  = "days_since_last_dismiss" // int
    static let viaTrend              = "via_trend"               // bool
    // dismissalCount + signal + segment reuse existing
}

// AnalyticsService methods:
func logHomeAiFeedbackSignalUnsuppressedByTrend(segment:signal:priorDismissalCount:daysSinceLastDismiss:)
func logHomeAiFeedbackSuppressedDetailOpened(segment:signal:dismissalCount:)
func logHomeAiFeedbackSignalManuallyUnsuppressed(segment:signal:viaTrend:)
func logHomeAiFeedbackSignalBlacklistedPermanently(segment:signal:dismissalCount:)
```

**LoC:** ~70 (15 in Provider + 55 in Service)
**Tests:** T8.A — 1 test verifying all 4 events fire with correct param shape

---

## T2 — `RecommendationMemory` persisted fields

**File:** `FitTracker/AI/RecommendationMemory.swift` (modify)

**Change:** Add 2 new Codable struct types + 2 new persisted arrays + 4 query methods + 2 mutation methods.

```swift
struct ManualUnsuppression: Codable, Sendable {
    let signal: String
    let segment: String
    let timestamp: Date  // 14-day re-evaluation window starts here
}

struct BlacklistedSignal: Codable, Sendable {
    let signal: String
    let segment: String
    let timestamp: Date  // informational; persists until clearAll
}

// In RecommendationMemory:
private var manualUnsuppressions: [ManualUnsuppression] = []
private var blacklistedSignals: [BlacklistedSignal] = []

// Public query API:
func isManuallyUnsuppressed(_ signal:String, in:AISegment, within:TimeInterval=14*86400, now:Date=Date()) -> Bool
func isBlacklisted(_ signal:String, in:AISegment) -> Bool
func manualUnsuppressionsCount() -> Int     // for analytics
func blacklistsCount() -> Int               // for analytics

// Public mutation API:
func recordManualUnsuppression(signal:String, segment:AISegment, now:Date=Date())
func recordBlacklist(signal:String, segment:AISegment, now:Date=Date())
```

`clearAll()` wipes both new arrays alongside existing outcomes. UserDefaults key migrates additively (decoder default-fills both new arrays to `[]` for legacy users).

**LoC:** ~120
**Tests:** T8.B — 4 tests covering: persistence round-trip, isManuallyUnsuppressed window expiry, isBlacklisted permanence, clearAll wipes both

---

## T3 — `AcceptanceTrendDetector` pure helper

**File:** `FitTracker/AI/AcceptanceTrendDetector.swift` (NEW)

**Purpose:** Pure-function wrapper around `RecommendationMemory` queries. No state.

```swift
enum AcceptanceTrendDetector {
    /// Time-decayed suppression score for a signal in a segment.
    /// Each dismissal contributes exp(-λ × days_since(timestamp)) per PRD §"Algorithm".
    /// timeDecayLambda = 0.0231 day^-1 (half-life 30 days).
    static func timeDecayedSuppressionScore(
        for signal: String,
        in segment: AISegment,
        memory: RecommendationMemory,
        now: Date = Date(),
        timeDecayLambda: Double = 0.0231
    ) -> Double { /* ... */ }

    /// Last-7-day acceptance rate for a segment. Returns nil if < 3 outcomes
    /// in the window (quorum from PRD §"Algorithm" — trend-unsuppression
    /// floor only fires with sufficient sample).
    static func last7DayAcceptanceRate(
        for segment: AISegment,
        memory: RecommendationMemory,
        now: Date = Date()
    ) -> Double?

    /// Combined decision: should this signal be un-suppressed by trend?
    /// True iff:
    ///   timeDecayedSuppressionScore >= 3 (would-suppress under C5)
    ///   AND NOT blacklisted
    ///   AND last7DayAcceptanceRate(segment) >= 0.50 (PRD constant)
    static func shouldUnsuppressByTrend(
        signal: String,
        segment: AISegment,
        memory: RecommendationMemory,
        now: Date = Date()
    ) -> Bool
}
```

All injectable `now: Date` for deterministic test seeding (matches C5 pattern).

**LoC:** ~80
**Tests:** T8.C — 4 tests covering: decay weights correctly, last-7-day quorum returns nil below 3, trend-unsuppress AND-gate (all 3 conditions), blacklisted signal never un-suppresses

---

## T4 — `AIOrchestrator` reinforcement-loop extension

**File:** `FitTracker/AI/AIOrchestrator.swift` (modify)

**Change:** Extend `applyReinforcementLoop(recommendation:segment:)` (existing C5 helper) to consult `AcceptanceTrendDetector` BEFORE applying C5's suppression. The new flow:

```text
For each signal in recommendation.signals:
  if memory.isBlacklisted(signal, in: segment):
    permanent suppression — drop confidence to low/min tier
  else if AcceptanceTrendDetector.shouldUnsuppressByTrend(...):
    fire home_ai_feedback_signal_unsuppressed_by_trend(...)
    return recommendation unchanged (un-suppression)
  else if memory.isManuallyUnsuppressed(signal, in: segment):
    skip C5 suppression for this signal (manual override active for 14d)
  else:
    apply existing C5 logic (frequentlyDismissedSignals + acceptanceRate)
```

Inserts before the existing `dismissed.contains` check + acceptanceRate boost. Backward-compatible.

**LoC:** ~50 (insertion + analytics fire + small helper changes)
**Tests:** T8.D — 3 tests covering: blacklisted signal stays suppressed, trend-unsuppress flow fires analytics + returns unchanged, manual-override skips C5 suppression within window

---

## T5 — `SuppressedSignalDetailScreen` (D1.d transparency UX)

**File:** `FitTracker/Views/Settings/v2/Screens/SuppressedSignalDetailScreen.swift` (NEW)

**Purpose:** Push-navigation detail for a single suppressed signal. Reads from `RecommendationMemory` via env-object facade.

Layout:

```text
┌──────────────────────────────────────┐
│  protein_below                       │
│  Recovery segment                    │
├──────────────────────────────────────┤
│  Why suppressed                      │
│  3 dismissals in last 30 days:       │
│  • 2026-05-20 — not_relevant         │
│  • 2026-05-25 — already_aware        │
│  • 2026-05-29 — (no reason)          │
│  Time-decay weight: 2.1 / 3.0        │
├──────────────────────────────────────┤
│  Last 7 days acceptance rate         │
│  Recovery: 0.45 (3 of 7)             │
│  Below the 0.50 floor for auto-      │
│  un-suppression                      │
├──────────────────────────────────────┤
│  [ Un-suppress this signal ]         │
│  Stays surfaceable for 14 days       │
│                                      │
│  [ Blacklist permanently ]           │
│  Cannot be re-suppressed without     │
│  Clear feedback history              │
└──────────────────────────────────────┘
```

Both buttons fire confirmation dialogs. Each emits the relevant analytics event on confirm.

Inputs: signal (String), segment (AISegment). Reads via `@EnvironmentObject feedbackController: RecommendationFeedbackController` (exposing the new `manualUnsuppressionsCount` + `blacklistsCount` + the underlying memory queries).

**LoC:** ~170
**Tests:** T8.E — 2 tests covering: empty state when no dismissals exist; un-suppress + blacklist buttons fire correct events (via mock service)

---

## T6 — `AIFeedbackSettingsScreen` row-tap routing

**File:** `FitTracker/Views/Settings/v2/Screens/AIFeedbackSettingsScreen.swift` (modify)

**Change:** Existing screen's "Currently Suppressed" section gets `NavigationLink` wiring so each suppressed-signal row pushes the new `SuppressedSignalDetailScreen` for that signal. No other layout changes.

```swift
ForEach(suppressedSignals, id: \.signal) { entry in
    NavigationLink {
        SuppressedSignalDetailScreen(
            signal: entry.signal,
            segment: entry.segment
        )
        .environmentObject(feedbackController)
        .environmentObject(analytics)
    } label: {
        suppressedSignalRow(entry)
    }
}
```

**LoC:** ~25
**Tests:** none directly (T8.E covers detail-screen behavior).

---

## T7 — `project.pbxproj` wiring

**File:** `FitTracker.xcodeproj/project.pbxproj` (modify)

Register 2 new source files (T3 `AcceptanceTrendDetector.swift` + T5 `SuppressedSignalDetailScreen.swift`) and 4 new test files in Sources phase + group + file references.

**LoC:** ~40 (4 entries × 4 sections per file × 6 files)

---

## T8 — Test suite

**Files (NEW — 4 test files):**

- `FitTrackerTests/AnalyticsAdaptiveIntelligenceEventsTests.swift` (T8.A — 1 test)
- `FitTrackerTests/RecommendationMemoryD1FieldsTests.swift` (T8.B — 4 tests)
- `FitTrackerTests/AcceptanceTrendDetectorTests.swift` (T8.C — 4 tests)
- `FitTrackerTests/AIOrchestratorTrendUnsuppressTests.swift` (T8.D — 3 tests)
- (T8.E view-level deferred — see scope note below)

**Total:** ~12 tests. **Scope note:** view-level T8.E (SuppressedSignalDetailScreen mode tests) would need ViewInspector infra not in project. Pure-logic surfaces (T8.A-D) cover the algorithm + analytics surfaces at ≥90% coverage. View behavior verified at Phase 5 simulator walkthrough.

**LoC:** ~280

---

## T9 — Final verify-local + case study + state→testing + backlog strike

**Files:**
- `docs/case-studies/adaptive-intelligence-next-pass-case-study.md` (NEW)
- `.claude/features/adaptive-intelligence-next-pass/state.json` (modify — advance `current_phase: testing`)
- `.claude/logs/adaptive-intelligence-next-pass.log.json` (auto-append)
- `docs/product/backlog.md` (strike Planned RICE row 4.5)

**Checks:**
- `xcodebuild build -scheme FitTracker -destination 'generic/platform=iOS Simulator'` → BUILD SUCCEEDED
- `xcodebuild test -only-testing:FitTrackerTests/{Analytics…D1,RecommendationMemoryD1,AcceptanceTrendDetector,AIOrchestratorTrendUnsuppress}Tests` → 12/12 PASS
- `make ui-audit` → P0=0 maintained
- Schema check → pass

**LoC:** ~170

---

## Out-of-scope guards (from PRD §"Phased v8.0+ deferrals")

Explicit do-not-implement in D1 v1:
- **D1.b — Cohort priors** (k≥20 federated avg) — backend touch + DPIA delta; deferred to v8.0
- **D1.c — AI-suggested replacement** when blacklisted — mapping table OR LLM gateway; deferred to v8.0+
- **D1.e — Cross-segment trend correlation** — deferred to future

---

## Phase 4 (Implement) ordering

Recommended landing order (7 standalone-buildable commits):

1. **T1** — Analytics infra. Single commit. ~70 LoC.
2. **T2** — RecommendationMemory new persisted fields. Standalone commit. ~120 LoC.
3. **T3 + T4** — AcceptanceTrendDetector + AIOrchestrator extension. Single commit. ~130 LoC.
4. **T5 + T6** — SuppressedSignalDetailScreen + AIFeedbackSettingsScreen routing. Single commit. ~195 LoC.
5. **T7 + T8** — pbxproj + test suite. Single commit. ~320 LoC.
6. **T9** — Final verify-local + case study + state→testing + backlog strike. ~170 LoC.

**Estimated total LoC:** ~835 (PRD estimated ~600; tasks.md re-estimate accounts for pbxproj overhead + case study + test boilerplate).

**Estimated wall time:** ~3.5h matches PRD's 3.5pd scaled to single-session iteration.

---

## Phase transition criteria

| From → To | Criterion |
|---|---|
| tasks → implement | Operator approves this tasks.md (scope frozen + ordering OK) |
| implement → test | All 9 tasks complete; project.pbxproj wires all new source + test files; xcodebuild BUILD SUCCEEDED |
| test → review | All 12 tests pass; coverage ≥ 90% on new files; ui-audit P0=0 |
| review → merge | /ux + /design pre-merge-review pass |
| merge → complete | PR merged; backlog Planned row 4.5 struck; FEATURE_CLOSURE_COMPLETENESS gate passes |

---

## Cross-references

- PRD: `docs/product/prd/adaptive-intelligence-next-pass.md`
- Research: `.claude/features/adaptive-intelligence-next-pass/research.md`
- State.json: `.claude/features/adaptive-intelligence-next-pass/state.json`
- Predecessor C5: `FitTracker/AI/RecommendationMemory.swift` + `FitTracker/AI/AIOrchestrator.swift` (extended here)
- C5 case study: `docs/case-studies/ai-user-feedback-loop-case-study.md`
- Sibling C3/C6 case studies — pattern reference for single-session lifecycle
