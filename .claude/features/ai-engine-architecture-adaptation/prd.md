# PRD: AI Engine Architecture Adaptation

> **Owner:** Regev
> **Date:** 2026-04-15
> **Phase:** PRD (Phase 1)
> **Status:** Draft
> **Linear:** FIT-25
> **Work Type:** Enhancement (parent: adaptive-intelligence)

---

## Purpose

Apply PM-flow ecosystem patterns (input adapters, validation gate, learning cache, feedback loop) to the in-app AI engine so that recommendations become structured, inspectable, confidence-scored, and self-improving over time.

## Business Objective

The AI engine currently generates recommendations but has no way to measure quality, learn from outcomes, or explain confidence. This makes it impossible to answer "are AI recommendations useful?" — a question that blocks informed iteration. The adaptation makes the AI system data-driven so we can evaluate, tune, and improve it with real evidence.

## Target Persona(s)

| Persona | Relevance |
|---------|-----------|
| Consistent Lifter | Primary consumer of training/recovery recommendations. Wants to know "can I trust this?" |
| Data-Driven Optimizer | Most likely to engage with confidence indicators and provide feedback. Wants transparency. |
| Health-Conscious Professional | Benefits from nutrition/recovery recommendations. Time-constrained — low-confidence recs waste their attention. |

## Has UI?

Yes — Phase 4 adds thumbs up/down feedback on AI insight cards + confidence badge styling.

## Functional Requirements

| # | Requirement | Phase | Details |
|---|-------------|-------|---------|
| 1 | AIInputAdapter protocol with 4 concrete adapters | Phase 1 | Extract existing AISnapshotBuilder logic into HealthKitAdapter, ProfileAdapter, TrainingAdapter, NutritionAdapter conformances |
| 2 | Adapter registry for extensibility | Phase 1 | Array of `any AIInputAdapter` injected into snapshot builder. Adding Garmin/Whoop = adding one conformance. |
| 3 | ValidatedRecommendation wrapper | Phase 2 | Wraps AIRecommendation with dataCompleteness, sourceFreshness, overallConfidence, evidenceChain |
| 4 | Confidence-based UI rendering | Phase 2 | HIGH → full card, MEDIUM → "limited data" badge, LOW → subtle suggestion style |
| 5 | RecommendationMemory persistence | Phase 3 | On-device encrypted store of (segment, signals, userAction, outcome). SwiftData or UserDefaults. |
| 6 | Local fallback threshold tuning | Phase 3 | After N outcomes, adjust localFallback() signal thresholds based on acceptance patterns |
| 7 | Goal-aware metric prioritization | Phase 2 | GoalProfile maps each NutritionGoalMode to primary/secondary driver metrics and messaging emphasis. AI engine weights recommendations by what matters for the user's goal. |
| 8 | Goal-driven recommendation messaging | Phase 2 | Final recommendation text adapts tone and emphasis based on GoalProfile — fat loss user hears about deficit adherence first, muscle gain user hears about surplus + protein first. |
| 9 | Thumbs up/down UI on AIInsightCard | Phase 4 | Two-button overlay on existing card. Writes to RecommendationMemory. |
| 10 | Analytics events for recommendation lifecycle | Phase 4 | ai_recommendation_accepted, ai_recommendation_dismissed, ai_recommendation_confidence_level |

## Implementation Phases

Each phase is independently shippable:

### Phase 1: Input Adapter Protocol (non-breaking refactor)

```swift
protocol AIInputAdapter {
    var sourceID: String { get }
    var lastUpdated: Date? { get }
    func contribute(to snapshot: inout LocalUserSnapshot)
}
```

Refactor `AISnapshotBuilder.build()` into 4 concrete adapters. No behavior change — pure structural refactor.

**Files changed:** `AISnapshotBuilder.swift` (refactor), new `AIInputAdapter.swift` + 4 adapter files.

### Phase 2: Recommendation Confidence Gate

```swift
struct ValidatedRecommendation {
    let recommendation: AIRecommendation
    let dataCompleteness: Double   // 0-1
    let sourceFreshness: Double    // 0-1
    let overallConfidence: ConfidenceLevel  // .high, .medium, .low
    let evidenceChain: [String]    // which adapters contributed
}
```

AIOrchestrator wraps final recommendation in validation. UI renders based on confidence.

#### Goal-Aware Metric Prioritization

The user's chosen goal (from onboarding or settings) determines which metrics the AI engine emphasizes. Today `localFallback()` has scattered goal checks (e.g., `primaryGoal == "weight_loss"` → append one signal). The adaptation centralizes this into a `GoalProfile` that the entire recommendation pipeline uses.

```swift
struct GoalProfile {
    let goal: NutritionGoalMode
    let primaryDrivers: [MetricDriver]
    let secondaryDrivers: [MetricDriver]
    let messagingEmphasis: [AISegment: String]
}

struct MetricDriver {
    let metric: String          // "caloric_balance", "protein_adequacy", etc.
    let direction: Direction    // .lower, .higher, .maintain
    let weight: Double          // 0-1, how much this metric matters for this goal
    let explanation: String     // human-readable: "caloric deficit is the #1 driver of fat loss"
}
```

**Goal → Driver Mapping:**

| Goal | Primary Drivers | Secondary Drivers | Messaging Emphasis |
|---|---|---|---|
| **Fat Loss** | Caloric deficit (kcal in < out, weight 0.4), Protein adequacy (≥target, weight 0.25) | Macro split (carb/fat ratio, weight 0.15), Training volume (maintain muscle, weight 0.1), Sleep quality (cortisol/recovery, weight 0.1) | Nutrition: "you're X kcal from your deficit target". Training: "strength work preserves muscle during fat loss". Recovery: "poor sleep increases cortisol which fights fat loss". |
| **Muscle Gain** | Caloric surplus (kcal in > out, weight 0.3), Protein adequacy (≥1.6g/kg, weight 0.3) | Training progressive overload (volume trending up, weight 0.2), Macro split (carb timing around training, weight 0.1), Recovery quality (muscle repair, weight 0.1) | Nutrition: "you need X more kcal to support growth". Training: "volume is progressing — surplus fuels this". Recovery: "muscle grows during rest, not during training". |
| **Maintain** | Caloric balance (±100 kcal of target, weight 0.3), Consistency (workout adherence, weight 0.25) | Protein adequacy (maintain lean mass, weight 0.2), Recovery stability (HRV/RHR trending flat, weight 0.15), Macro variety (balanced nutrition, weight 0.1) | Nutrition: "you're right on target — keep it steady". Training: "consistency matters more than intensity at maintenance". Recovery: "stable HRV means your body is adapting well". |

**How it works in the pipeline:**

1. `AISnapshotBuilder` reads `preferences.nutritionGoalMode` → resolves `GoalProfile`
2. `ValidatedRecommendation` includes the `GoalProfile` alongside confidence
3. `localFallback()` uses `GoalProfile.primaryDrivers` to generate signals weighted by driver importance (not just binary threshold checks)
4. `FoundationModel.adapt()` receives the `GoalProfile.messagingEmphasis[segment]` as system prompt context — the LLM knows what angle to emphasize
5. Final recommendation text leads with the primary driver insight for that goal, not a generic signal list

**Example — Fat Loss user, nutrition segment:**
- Today: `"local_calorie_deficit_active"` (binary — deficit exists, no magnitude)
- After: `"You're 280 kcal into your deficit target of 350 — on track. Protein is 12g below target (128g / 140g). Consider adding a protein-rich snack to protect lean mass during fat loss."`

The message ties the specific numbers to the goal context, explains *why* each metric matters for *their* goal, and gives an actionable suggestion grounded in the data.

**Files changed:** `AIOrchestrator.swift` (add validation + GoalProfile), new `ValidatedRecommendation.swift`, new `GoalProfile.swift`, `AIInsightCard` views (conditional styling), `FoundationModelService.swift` (goal-aware prompt context).

### Phase 3: Learning Cache

```swift
struct RecommendationOutcome: Codable {
    let segment: AISegment
    let signals: [String]
    let timestamp: Date
    let action: UserAction  // .accepted, .dismissed, .ignored
    let outcomeObserved: String?
}
```

On-device persistence via encrypted UserDefaults or SwiftData. After accumulating outcomes, adjust localFallback() thresholds.

**Files changed:** New `RecommendationMemory.swift`, `AIOrchestrator.swift` (read cache on process), `AITypes.swift` (adjust localFallback).

### Phase 4: Feedback UI + Analytics

- Thumbs up/down on `AIInsightCard`
- 3 new analytics events
- Wire feedback to RecommendationMemory

**Files changed:** `AIInsightCard.swift` (feedback buttons), `AnalyticsProvider.swift` (3 events), `AIOrchestrator.swift` (feedback ingestion).

## Current State & Gaps

| Gap | Priority | Notes |
|-----|----------|-------|
| No adapter abstraction for data sources | High | Adding Garmin/Whoop requires modifying AISnapshotBuilder directly |
| No confidence scoring before surfacing | High | Users see all recommendations equally regardless of data quality |
| No memory of recommendation outcomes | High | System can't learn what works |
| No user feedback mechanism | Medium | No thumbs up/down, no way to dismiss |
| Hard-coded local fallback thresholds | Medium | No evidence they're optimal |

## Acceptance Criteria

- [ ] AISnapshotBuilder refactored into adapter protocol with no behavior change (Phase 1)
- [ ] All existing tests pass unchanged after Phase 1 refactor
- [ ] Recommendations carry confidence level visible in UI (Phase 2)
- [ ] LOW confidence recommendations render with "limited data" badge (Phase 2)
- [ ] RecommendationMemory persists across app restarts, encrypted (Phase 3)
- [ ] After 20+ outcomes, local fallback thresholds adjust automatically (Phase 3)
- [ ] User can thumbs-up/down any AI recommendation (Phase 4)
- [ ] 3 analytics events fire correctly and pass `/analytics validate` (Phase 4)
- [ ] PII never stored in RecommendationMemory — only segment, signals, action (all phases)

---

## Success Metrics & Measurement Plan

### Primary Metric
- **Metric:** AI recommendation acceptance rate
- **Baseline:** Unknown (no tracking exists)
- **Target:** >40% of shown recommendations receive positive feedback
- **Timeframe:** 30 days post-Phase 4 launch

### Secondary Metrics
| Metric | Baseline | Target | Instrumentation |
|--------|----------|--------|-----------------|
| Data completeness per recommendation | ~60% (many nil bands) | >80% bands filled | ValidatedRecommendation.dataCompleteness |
| Feedback engagement rate | 0% (no UI) | >10% of shown recs get feedback | ai_recommendation_accepted + ai_recommendation_dismissed / ai_insight_shown |
| Local fallback quality | Unmeasured | 20% improvement in acceptance of local-only recs | RecommendationMemory acceptance rate for local vs cloud |
| Confidence distribution | Unknown | <20% of recs are LOW confidence | ai_recommendation_confidence_level parameter |

### Guardrail Metrics

| Metric | Current Value | Acceptable Range |
|--------|--------------|-----------------|
| Crash-free rate | >99.5% | Must stay >99.5% |
| Cold start time | <2s | Must stay <2s — adapter init must be lazy |
| AI processing time | ~1s per segment | Must stay <2s per segment |
| App storage size | ~5MB | RecommendationMemory must stay <500KB |

### Leading Indicators
- Phase 1: Adapter refactor passes all existing tests with zero behavior change
- Phase 2: >50% of recommendations surface with HIGH confidence
- Phase 4: >5% feedback engagement in first week

### Lagging Indicators
- D30: Acceptance rate trend is positive (improving over time as cache learns)
- D60: Local fallback thresholds have been adjusted at least once by the learning cache
- D90: Users who engage with feedback have higher retention than those who don't

### Instrumentation Plan

| Event/Metric | Method | Status |
|-------------|--------|--------|
| `home_ai_insight_shown` | GA4 (existing) | Ready |
| `home_ai_insight_tap` | GA4 (existing) | Ready |
| `ai_recommendation_accepted` | GA4 (new — Phase 4) | Not started |
| `ai_recommendation_dismissed` | GA4 (new — Phase 4) | Not started |
| `ai_recommendation_confidence_level` | GA4 param on existing events (new — Phase 2) | Not started |
| Data completeness | ValidatedRecommendation.dataCompleteness (in-app) | Not started |
| Cache hit rate | RecommendationMemory.hitCount (in-app) | Not started |

### Analytics Spec (GA4 Event Definitions)

#### New Events
| Event Name | Category | GA4 Type | Screen/Trigger | Parameters | Conversion? | Notes |
|------------|----------|----------|----------------|------------|-------------|-------|
| `ai_recommendation_accepted` | Engagement | Custom | Home / AI sheet | `segment`, `confidence_level`, `source` | No | User taps thumbs-up |
| `ai_recommendation_dismissed` | Engagement | Custom | Home / AI sheet | `segment`, `confidence_level`, `source`, `reason` | No | User taps thumbs-down |

#### New Parameters
| Parameter Name | Type | Allowed Values | Used By Events | Notes |
|---------------|------|----------------|----------------|-------|
| `confidence_level` | string | "high", "medium", "low" | ai_recommendation_accepted, ai_recommendation_dismissed, home_ai_insight_shown | Added to existing events too |
| `source` | string | "cloud", "local", "personalised" | ai_recommendation_accepted, ai_recommendation_dismissed | Which pipeline produced the rec |
| `reason` | string | "not_relevant", "already_know", "disagree", "other" | ai_recommendation_dismissed | Optional dismissal reason |

#### Naming Validation Checklist
- [x] All event names: snake_case, <40 chars
- [x] All parameter names: snake_case, <40 chars
- [x] No reserved prefixes (ga_, firebase_, google_)
- [x] No duplicate names (checked against AnalyticsProvider.swift)
- [x] No PII in any parameter
- [x] ≤25 parameters per event
- [x] Parameter values spec'd to max 100 chars
- [x] Screen-prefix rule: events are cross-screen (AI surfaces on Home + sheet), so `ai_` prefix is correct

#### Files to Update During Implementation
- [ ] `AnalyticsProvider.swift` — add `ai_recommendation_accepted`, `ai_recommendation_dismissed` constants + `confidence_level`, `source`, `reason` params
- [ ] `docs/product/analytics-taxonomy.csv` — add rows for new events and parameters

### Review Cadence
- **First review:** 1 week post-Phase 4 launch
- **Ongoing:** Weekly for 4 weeks, then monthly

### Kill Criteria

- If acceptance rate < 15% after 30 days of Phase 4 → rethink recommendation quality, not just measurement
- If feedback engagement < 3% after 30 days → remove feedback UI (adds clutter without signal)
- If RecommendationMemory exceeds 500KB → cap entries and implement LRU eviction
- If local fallback adjustment degrades acceptance rate → revert to static thresholds

---

## Key Files

| File | Purpose |
|------|---------|
| `FitTracker/AI/AIOrchestrator.swift` | Hub — orchestrates the pipeline |
| `FitTracker/AI/AITypes.swift` | Value types, LocalUserSnapshot, band extraction |
| `FitTracker/AI/AISnapshotBuilder.swift` | Builds snapshot from data sources (refactor target) |
| `FitTracker/AI/AIEngineClient.swift` | Cloud API protocol |
| `FitTracker/AI/FoundationModelService.swift` | On-device personalisation |
| `FitTracker/Views/Main/v2/MainScreenView.swift` | Home screen (hosts AIInsightCard) |

## Dependencies & Risks

| Dependency/Risk | Mitigation |
|----------------|------------|
| Phase 2 UI changes touch AIInsightCard in Home v2 | Confidence badge is additive — no existing behavior removed |
| SwiftData requires iOS 17+ | Already our minimum target. Fallback: encrypted UserDefaults. |
| Learning cache persists user behavioral data | On-device only, encrypted via EncryptionService. No data leaves device. GDPR Article 5 compliant. |
| Over-engineering for 1 user | Each phase is independently shippable. Stop after any phase if ROI doesn't justify continuing. |
| Foundation Model (iOS 26+) dependency for personalisation | Already handled — FallbackFoundationModel exists for pre-iOS 26 |

## Estimated Effort

- **Total:** ~2 weeks
- **Breakdown:**
  - Phase 1 (Adapters): 2 days — pure refactor, no new behavior
  - Phase 2 (Confidence Gate): 3 days — new struct + UI conditional rendering
  - Phase 3 (Learning Cache): 4 days — persistence layer + threshold adjustment logic
  - Phase 4 (Feedback UI): 2 days — UI buttons + analytics events
  - Testing: 2 days — unit tests for adapters, validation, cache, and analytics
