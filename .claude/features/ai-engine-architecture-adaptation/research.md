# AI Engine Architecture Adaptation — Research

> Status: Phase 0 research (advanced)
> Framework: PM-flow v5.1
> Date: 2026-04-15
> Linear: FIT-25

## 1. What is this solution?

Adapt the PM-flow ecosystem patterns (adapter layer, validation gate, learning cache, reactive data mesh) to the in-app AI engine (AIOrchestrator). The goal: make the AI system as structured, inspectable, and self-improving as the PM workflow.

## 2. Why this approach?

The current AIOrchestrator works but has architectural gaps:

| Current State | Gap | PM-flow Pattern to Apply |
|---|---|---|
| `AISnapshotBuilder` pulls from 4 hard-coded sources (profile, preferences, liveMetrics, dailyLogs) | No normalized adapter layer — adding Garmin/Whoop/Oura requires modifying the builder | **Integration Adapter** (`.claude/integrations/` pattern) |
| `AIRecommendation.confidence` is set to 0.25 for local, cloud-returned for cloud | No validation of confidence before surfacing to user | **Validation Gate** (GREEN/ORANGE/RED) |
| Recommendations are fire-and-forget — no memory of what worked | User feedback can't improve future recommendations | **Learning Cache** (L1/L2/L3) |
| `process()` has inline error handling with no structured fallback chain | Error handling is per-call, not systematized | **Graceful Degradation** (adapter fallback pattern) |
| `localFallback()` uses hard-coded signal thresholds | No evidence these thresholds are optimal | **Evidence-Based Tuning** via learning cache |

## 3. Current repo reality

### Files that exist today

| File | Purpose | Lines |
|---|---|---|
| `FitTracker/AI/AIOrchestrator.swift` | Hub — orchestrates snapshot → cloud → personalisation pipeline | 153 |
| `FitTracker/AI/AITypes.swift` | Value types: AISegment, AIRecommendation, LocalUserSnapshot, band extraction | 454 |
| `FitTracker/AI/AISnapshotBuilder.swift` | Builds LocalUserSnapshot from profile/preferences/liveMetrics/dailyLogs | 195 |
| `FitTracker/AI/AIEngineClient.swift` | Protocol + impl for cloud API calls | ~50 |
| `FitTracker/AI/FoundationModelService.swift` | On-device Foundation Model personalisation | ~80 |

### Current pipeline

```
Profile + Preferences + LiveMetrics + DailyLogs
    │
    ▼
AISnapshotBuilder.build()  →  LocalUserSnapshot
    │
    ├─── extractBands() → banded categorical values (no PII)
    │         │
    │         ▼
    │    AIEngineClient.fetchInsight() → AIRecommendation (cloud)
    │         │ (fallback: localFallback())
    │         ▼
    │    FoundationModel.adapt() → personalised recommendation
    │
    ▼
latestRecommendations[segment] = finalRecommendation
```

### What's working well

- Privacy-by-design (PII stays on-device, only bands go to cloud)
- Local fallback always exists (never empty state)
- Readiness Engine v2 integration already feeds into bands
- 4-segment architecture (training, nutrition, recovery, stats) is clean

## 4. Proposed architecture — 5 layers

```
╔══════════════════════════════════════════════════════════════╗
║  LAYER 1: INPUT ADAPTERS (normalized data ingestion)        ║
║                                                              ║
║  HealthKitAdapter ─┐                                        ║
║  ProfileAdapter ───┤                                        ║
║  TrainingAdapter ──┼──→ NormalizedHealthSnapshot             ║
║  NutritionAdapter ─┤    (replaces LocalUserSnapshot builder) ║
║  [future] GarminAdapter ──┘                                 ║
║  [future] WhoopAdapter ───┘                                 ║
╚════════════════════════════╤═════════════════════════════════╝
                             │
╔════════════════════════════▼═════════════════════════════════╗
║  LAYER 2: VALIDATION GATE (confidence + evidence scoring)   ║
║                                                              ║
║  Each recommendation passes through:                        ║
║  - Data completeness check (how many bands were available?) ║
║  - Source freshness check (how old is the data?)            ║
║  - Confidence calibration (local 0.25 vs cloud 0.4-0.9)    ║
║                                                              ║
║  Score:                                                     ║
║    HIGH (≥0.7)  — surface with full confidence styling      ║
║    MED (0.4-0.7) — surface with "based on limited data"     ║
║    LOW (<0.4)   — suppress or show as suggestion only       ║
╚════════════════════════════╤═════════════════════════════════╝
                             │
╔════════════════════════════▼═════════════════════════════════╗
║  LAYER 3: RECOMMENDATION ASSEMBLY                           ║
║                                                              ║
║  AIOrchestrator.process() — unchanged hub structure         ║
║  - Build snapshot via adapters (Layer 1)                    ║
║  - Extract bands → cloud call (existing)                    ║
║  - Foundation Model personalisation (existing)              ║
║  - Validate result (Layer 2)                                ║
║  - Tag with evidence chain (which adapters contributed)     ║
╚════════════════════════════╤═════════════════════════════════╝
                             │
╔════════════════════════════▼═════════════════════════════════╗
║  LAYER 4: LEARNING CACHE (recommendation memory)            ║
║                                                              ║
║  Per-user, on-device, privacy-safe:                         ║
║  - Store: segment + signals + user action (accepted/ignored)║
║  - After N interactions: adjust local fallback thresholds   ║
║  - Promote patterns: "this user always ignores sleep recs   ║
║    when training 6 days/week" → suppress or reframe         ║
║                                                              ║
║  Schema:                                                    ║
║  { segment, signals, timestamp, action, outcome_observed }  ║
╚════════════════════════════╤═════════════════════════════════╝
                             │
╔════════════════════════════▼═════════════════════════════════╗
║  LAYER 5: FEEDBACK LOOP (analytics + UI)                    ║
║                                                              ║
║  - UI: thumbs up/down on each recommendation                ║
║  - Analytics: ai_recommendation_shown, ai_recommendation_  ║
║    accepted, ai_recommendation_dismissed                    ║
║  - Feed back into Layer 4 cache                             ║
║  - Phase 9 (Learn) can query this data via /analytics       ║
╚══════════════════════════════════════════════════════════════╝
```

## 5. Implementation plan (draft)

### Phase 1: Input Adapter Protocol (non-breaking)

```swift
protocol AIInputAdapter {
    var sourceID: String { get }
    var lastUpdated: Date? { get }
    func contribute(to snapshot: inout LocalUserSnapshot)
}
```

Refactor `AISnapshotBuilder.build()` into 4 concrete adapters that conform to this protocol. External adapters (Garmin, Whoop, Oura) can be added later without touching the builder.

**Effort:** Small. Extract existing code into protocol conformances. No behavior change.

### Phase 2: Recommendation Confidence Gate

Add a `RecommendationConfidence` struct that wraps each `AIRecommendation`:

```swift
struct ValidatedRecommendation {
    let recommendation: AIRecommendation
    let dataCompleteness: Double  // 0-1: how many bands were available
    let sourceFreshness: Double   // 0-1: how recent is the data
    let overallConfidence: ConfidenceLevel // .high, .medium, .low
    let evidenceChain: [String]   // which adapters contributed
}
```

UI renders differently based on `overallConfidence` (full card vs. subtle suggestion vs. suppressed).

**Effort:** Medium. New struct + validation logic + UI conditional rendering.

### Phase 3: Learning Cache

On-device `RecommendationMemory` using SwiftData or UserDefaults (encrypted):

```swift
struct RecommendationOutcome: Codable {
    let segment: AISegment
    let signals: [String]
    let timestamp: Date
    let action: UserAction // .accepted, .dismissed, .ignored
    let outcomeObserved: String? // "trained_harder", "slept_better", etc.
}
```

After accumulating enough outcomes, adjust `localFallback()` signal thresholds.

**Effort:** Medium. New persistence layer + threshold adjustment logic.

### Phase 4: Feedback UI + Analytics

- Add thumbs up/down to `AIInsightCard`
- Fire `ai_recommendation_accepted` / `ai_recommendation_dismissed` events
- Wire to `RecommendationMemory`

**Effort:** Small. UI + analytics events.

## 6. Risks

| Risk | Mitigation |
|---|---|
| Over-engineering for current user base (1 user) | Keep adapters as protocol conformances, not a registry. No external adapters until demand exists. |
| Privacy leaks from learning cache | On-device only, encrypted via existing EncryptionService. No cache data leaves device. |
| Low-confidence suppression hiding useful recs | Default to showing with "limited data" badge, not hiding. User can override. |
| Adapter proliferation | Cap at 6 adapters (4 current + 2 external). Each must have a clear data contract. |

## 7. Success metrics

| Metric | Baseline | Target | Kill Criteria |
|---|---|---|---|
| Recommendation acceptance rate | Unknown (no tracking) | >40% accepted | <15% after 30 days |
| Data completeness per recommendation | ~60% (many nil bands) | >80% bands filled | — |
| Learning cache improving local fallbacks | No cache exists | Local fallback quality improves by 20% (measured by acceptance rate of local-only recs) | No improvement after 60 days |
| User feedback engagement | 0% (no UI) | >10% of shown recs get feedback | — |

## 8. Recommended approach

Run as an **Enhancement** work type (parent: adaptive-intelligence). 4-phase lifecycle: Tasks → Implement → Test → Merge.

Implementation order: Phase 1 (adapters) → Phase 2 (confidence gate) → Phase 3 (learning cache) → Phase 4 (feedback UI). Each phase is independently shippable.

## 9. Relationship to current work

- Downstream of shipped adaptive-intelligence
- Builds on readiness score v2 (already integrated into AISnapshotBuilder)
- Feeds into the eventual Garmin/Whoop/Oura integration (Task 10 in roadmap)
- Analytics events feed Phase 9 (Learn) via `/analytics report`

## 10. PM-flow pattern mapping

| PM-flow Pattern | AI Engine Analog | Notes |
|---|---|---|
| Integration Adapter (.claude/integrations/) | AIInputAdapter protocol | Same contract: raw → schema → normalize → validate → consume |
| Validation Gate (GREEN/ORANGE/RED) | RecommendationConfidence (.high/.medium/.low) | Same principle: score quality before acting |
| Learning Cache (L1/L2/L3) | RecommendationMemory | Simpler: single-level, per-user, on-device |
| Shared Data Layer (.claude/shared/) | LocalUserSnapshot | Already exists — adapters write to it |
| Hub orchestration (pm-workflow) | AIOrchestrator | Already exists — adds validation + caching |
| Phase 9 Feedback Loop | Thumbs up/down → RecommendationMemory | Closes the loop |
