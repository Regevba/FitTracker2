# AI Engine Architecture Adaptation — Task Breakdown

> **Phase:** Tasks (Phase 2)
> **Work Type:** Enhancement
> **Total Tasks:** 13
> **Estimated Effort:** ~2 weeks

---

## Dependency Graph

```
T1 (AIInputAdapter protocol)
├── T2 (ProfileAdapter)
├── T3 (HealthKitAdapter)
├── T4 (TrainingAdapter)
└── T5 (NutritionAdapter)
    └── T6 (refactor AISnapshotBuilder to use adapters)
        ├── T7 (GoalProfile + MetricDriver)
        │   └── T8 (ValidatedRecommendation + confidence gate)
        │       ├── T9 (goal-aware localFallback rewrite)
        │       ├── T10 (confidence badge UI + goal messaging)
        │       └── T11 (FoundationModel goal-aware prompt)
        │           └── T12 (RecommendationMemory + threshold tuning)
        │               └── T13 (feedback UI + analytics events)
```

---

## Phase 1: Input Adapters

### T1: Define AIInputAdapter protocol
- **Type:** dev
- **Complexity:** lightweight
- **Files:** new `FitTracker/AI/Adapters/AIInputAdapter.swift`
- **Depends on:** nothing
- **Acceptance:** Protocol compiles, has `sourceID`, `lastUpdated`, `contribute(to:)` 

### T2: ProfileAdapter
- **Type:** dev
- **Complexity:** lightweight
- **Files:** new `FitTracker/AI/Adapters/ProfileAdapter.swift`
- **Depends on:** T1
- **Acceptance:** Extracts age, gender, BMI, active weeks, primary goal from `UserProfile` + `UserPreferences`. Output identical to current `AISnapshotBuilder` fields.

### T3: HealthKitAdapter
- **Type:** dev
- **Complexity:** lightweight
- **Files:** new `FitTracker/AI/Adapters/HealthKitAdapter.swift`
- **Depends on:** T1
- **Acceptance:** Extracts sleep, RHR, steps, HRV from `LiveMetrics` + `DailyLog.biometrics`. Output identical to current fields.

### T4: TrainingAdapter
- **Type:** dev
- **Complexity:** lightweight
- **Files:** new `FitTracker/AI/Adapters/TrainingAdapter.swift`
- **Depends on:** T1
- **Acceptance:** Extracts training days/week, avg session minutes, weekly sessions, workout consistency, readiness. Output identical.

### T5: NutritionAdapter
- **Type:** dev
- **Complexity:** lightweight
- **Files:** new `FitTracker/AI/Adapters/NutritionAdapter.swift`
- **Depends on:** T1
- **Acceptance:** Extracts caloric balance, protein, meals/day, diet pattern. Output identical.

### T6: Refactor AISnapshotBuilder to use adapter registry
- **Type:** dev
- **Complexity:** heavyweight
- **Files:** `FitTracker/AI/AISnapshotBuilder.swift` (refactor)
- **Depends on:** T2, T3, T4, T5
- **Acceptance:** `build()` iterates `[any AIInputAdapter]` instead of inline logic. All existing tests pass with zero behavior change. Old static helpers removed.

---

## Phase 2: Confidence Gate + Goal-Aware Intelligence

### T7: GoalProfile + MetricDriver models
- **Type:** dev
- **Complexity:** lightweight
- **Files:** new `FitTracker/AI/GoalProfile.swift`
- **Depends on:** T6
- **Acceptance:** `GoalProfile` struct with `primaryDrivers`, `secondaryDrivers`, `messagingEmphasis`. `GoalProfile.forGoal(_:)` factory returns correct profile for fatLoss/maintain/gain. Unit tests verify all 3 profiles.

### T8: ValidatedRecommendation + confidence gate
- **Type:** dev
- **Complexity:** heavyweight
- **Files:** new `FitTracker/AI/ValidatedRecommendation.swift`, modify `AIOrchestrator.swift`
- **Depends on:** T7
- **Acceptance:** `AIOrchestrator.process()` wraps final recommendation in `ValidatedRecommendation` with `dataCompleteness`, `sourceFreshness`, `overallConfidence`, `evidenceChain`, and `goalProfile`. ConfidenceLevel enum (.high ≥0.7, .medium 0.4-0.7, .low <0.4).

### T9: Goal-aware localFallback rewrite
- **Type:** dev
- **Complexity:** heavyweight
- **Files:** `FitTracker/AI/AITypes.swift` (modify `localFallback()`)
- **Depends on:** T7
- **Acceptance:** `localFallback()` uses `GoalProfile.primaryDrivers` to generate weighted signals instead of binary checks. Fat loss user gets deficit-first signals, muscle gain user gets surplus+protein-first signals. Unit tests for all 3 goals × 4 segments.

### T10: Confidence badge UI + goal-framed messaging
- **Type:** dev + design
- **Complexity:** heavyweight
- **Files:** modify `AIInsightCard` views in Home v2, modify `AIIntelligenceSheet`
- **Depends on:** T8
- **Acceptance:** HIGH confidence → full card (current style). MEDIUM → card with "Based on limited data" badge using `AppColor.textTertiary`. LOW → collapsed suggestion row. Recommendation text leads with primary driver insight for the user's goal.

### T11: FoundationModel goal-aware prompt context
- **Type:** dev
- **Complexity:** lightweight
- **Files:** `FitTracker/AI/FoundationModelService.swift`
- **Depends on:** T7
- **Acceptance:** `buildPrompt()` includes `GoalProfile.messagingEmphasis[segment]` as system context. LLM output frames advice around the user's goal (e.g., "for your fat loss goal, deficit adherence is the priority"). Fallback model returns goal-framed template text.

---

## Phase 3: Learning Cache

### T12: RecommendationMemory + threshold tuning
- **Type:** dev
- **Complexity:** heavyweight
- **Files:** new `FitTracker/AI/RecommendationMemory.swift`, modify `AIOrchestrator.swift`, modify `AITypes.swift`
- **Depends on:** T8
- **Acceptance:**
  - `RecommendationOutcome` struct persists to encrypted UserDefaults
  - `RecommendationMemory` stores up to 200 outcomes per segment (LRU eviction)
  - After 20+ outcomes, `localFallback()` adjusts signal weights based on acceptance patterns
  - Storage stays <500KB (verified by unit test)
  - PII-free: only segment, signals, action, timestamp stored
  - `clearAll()` method for account deletion / GDPR

---

## Phase 4: Feedback UI + Analytics

### T13: Feedback UI + analytics events
- **Type:** dev + analytics
- **Complexity:** heavyweight
- **Files:** modify `AIInsightCard` views, `AnalyticsProvider.swift`, `AIOrchestrator.swift`
- **Depends on:** T12
- **Acceptance:**
  - Thumbs up / thumbs down buttons on `AIInsightCard` and `AIIntelligenceSheet`
  - Tap writes `RecommendationOutcome` to `RecommendationMemory`
  - Fires `ai_recommendation_accepted` / `ai_recommendation_dismissed` GA4 events
  - Events include `segment`, `confidence_level`, `source` params
  - Dismissed event includes optional `reason` param
  - Events pass `/analytics validate`
  - `AnalyticsProvider.swift` has new constants
  - `analytics-taxonomy.csv` updated with new rows

---

## Task Summary

| ID | Task | Phase | Type | Complexity | Depends On |
|---|---|---|---|---|---|
| T1 | AIInputAdapter protocol | 1 | dev | lightweight | — |
| T2 | ProfileAdapter | 1 | dev | lightweight | T1 |
| T3 | HealthKitAdapter | 1 | dev | lightweight | T1 |
| T4 | TrainingAdapter | 1 | dev | lightweight | T1 |
| T5 | NutritionAdapter | 1 | dev | lightweight | T1 |
| T6 | Refactor AISnapshotBuilder | 1 | dev | heavyweight | T2-T5 |
| T7 | GoalProfile + MetricDriver | 2 | dev | lightweight | T6 |
| T8 | ValidatedRecommendation + confidence gate | 2 | dev | heavyweight | T7 |
| T9 | Goal-aware localFallback rewrite | 2 | dev | heavyweight | T7 |
| T10 | Confidence badge UI + goal messaging | 2 | dev+design | heavyweight | T8 |
| T11 | FoundationModel goal-aware prompt | 2 | dev | lightweight | T7 |
| T12 | RecommendationMemory + threshold tuning | 3 | dev | heavyweight | T8 |
| T13 | Feedback UI + analytics events | 4 | dev+analytics | heavyweight | T12 |

**Parallel opportunities:**
- T2, T3, T4, T5 can all run in parallel after T1 (E-core lane, sonnet)
- T9 and T11 can run in parallel after T7 (both only need GoalProfile)
- T10 depends on T8 but is independent of T9/T11
