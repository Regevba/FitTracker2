# AI Engine v2 — Child PRD

| Field | Value |
|---|---|
| ID | ai-engine-v2 |
| Status | PRD |
| Priority | P1 |
| Parent | adaptive-intelligence-initiative |
| Work Type | Enhancement (4-phase: Tasks → Implement → Test → Merge) |
| GitHub Issue | backlog (no issue yet) |
| Last Updated | 2026-04-10 |

---

## Purpose

Adapt the existing AIOrchestrator to consume ReadinessResult as a primary input signal, enabling the 3-tier pipeline (local → cloud → Foundation Model) to generate readiness-aware, goal-specific training and recovery recommendations.

---

## Business Objective

The AI engine currently produces generic recommendations because it lacks a structured readiness signal. With ReadinessResult, the engine can answer not just "should you train?" but "what type of training, at what intensity, for your specific goal, given your sleep quality, training load, and recovery state?"

---

## Current State

| File | Size | Status |
|---|---|---|
| `FitTracker/AI/AIOrchestrator.swift` | 153 lines | 3-tier pipeline working, readiness-unaware |
| `FitTracker/AI/AITypes.swift` | 425 lines | LocalUserSnapshot has 24 fields, no readiness_score or fatigue_flags |
| `FitTracker/AI/AISnapshotBuilder.swift` | 182 lines | Builds snapshot from DailyLog, does not consume ReadinessResult |
| `FitTracker/AI/FoundationModelService.swift` | 139 lines | Builds private context, no readiness signals |
| `FitTracker/AI/AIEngineClient.swift` | 85 lines | Cloud POST to Railway FastAPI |

Active AI segments: training, nutrition, recovery, stats.

---

## What Changes

### 1. LocalUserSnapshot — AITypes.swift

Add the following fields to `LocalUserSnapshot`:

| Field | Type | Description |
|---|---|---|
| `readinessScore` | `Int?` | Overall readiness score, 0–100 |
| `readinessConfidence` | `String?` | Confidence tier: `low`, `medium`, `high` |
| `readinessRecommendation` | `String?` | Recommendation key: `restDay`, `lightOnly`, `moderate`, `fullIntensity`, `pushHard` |
| `hrvScore` | `Double?` | HRV component score |
| `sleepScore` | `Double?` | Sleep component score |
| `trainingLoadScore` | `Double?` | Training load component score |
| `rhrScore` | `Double?` | Resting heart rate component score |
| `fatigueFlags` | `[String]?` | Active flags, e.g. `hydrationWarning`, `visceralTrend` |

### 2. AISnapshotBuilder — accept ReadinessResult parameter

Update the build method signature:

```swift
static func build(from store: EncryptedDataStore, readiness: ReadinessResult?) -> LocalUserSnapshot
```

Map all ReadinessResult fields into the corresponding snapshot fields. When `readiness` is `nil`, all readiness fields remain `nil` and downstream logic degrades gracefully to the current generic behavior.

### 3. recoveryBands() — add readiness thresholds

Extend `recoveryBands()` in AITypes.swift with the following bands:

| Band key | Field | Condition |
|---|---|---|
| `readiness_high` | readiness_score | >= 70 |
| `readiness_moderate` | readiness_score | 50–69 |
| `readiness_low` | readiness_score | < 50 |
| `fatigue_none` | fatigue_level | 0 active flags |
| `fatigue_mild` | fatigue_level | 1 active flag |
| `fatigue_significant` | fatigue_level | 2 or more active flags |

### 4. trainingBands() — add ACWR awareness

Extend `trainingBands()` in AITypes.swift with training load status bands derived from the Acute:Chronic Workload Ratio:

| Band key | Condition |
|---|---|
| `training_load_optimal` | ACWR 0.8–1.3 |
| `training_load_underloaded` | ACWR < 0.8 |
| `training_load_overreaching` | ACWR > 1.3 |

### 5. FoundationModelService.buildPrivateContext() — readiness signals

Enhance the private context string with:

- Readiness score and confidence tier
- Component score breakdown (HRV, sleep, training load, RHR)
- Active fatigue flags

Add signal rules applied at context-build time:

| Condition | Context instruction |
|---|---|
| readiness_low | Suggest recovery-focused activity; caveat any training recommendation |
| readiness_high + goal = fat_loss | Suggest Zone 2 cardio for 45–60 min |
| readiness_high + goal = muscle_gain | Suggest full progressive overload program |

### 6. AIOrchestrator — readiness-aware orchestration

| Condition | Behavior |
|---|---|
| readinessConfidence == `.low` (Layer 0) | Append caveat to all recommendations noting low-confidence readiness data |
| readinessScore < 30 | Override training segment recommendations with rest/recovery guidance |
| fatigueFlags non-empty | Surface active flags in the recovery segment output |
| local readiness conflicts with cloud cohort insight | Flag conflict for user review |

---

## Key Files

| File | Change |
|---|---|
| `FitTracker/AI/AITypes.swift` | Add readiness fields to LocalUserSnapshot; extend recoveryBands() and trainingBands() |
| `FitTracker/AI/AISnapshotBuilder.swift` | Accept ReadinessResult parameter; map fields into snapshot |
| `FitTracker/AI/FoundationModelService.swift` | Enhance buildPrivateContext() with readiness signals and signal rules |
| `FitTracker/AI/AIOrchestrator.swift` | Readiness-aware orchestration logic |
| `FitTracker/AI/AIEngineClient.swift` | No change — payload shape auto-updates from snapshot struct |

---

## Success Metrics

| Metric | Baseline | Target |
|---|---|---|
| Recommendation specificity (qualitative) | Generic ("train hard" / "train easy") (T2 — Declared, 2026-04-26) | Goal + readiness specific (e.g. "Zone 2 for 45 min — sleep was excellent but ACWR is elevated") (T2 — Declared) |
| Cloud cohort match rate | N/A — pre-launch (T2 — Declared, 2026-04-26) | >30% of users placed in same readiness band (T2 — Declared) |
| Foundation Model confidence | 0.0 (stub) (T2 — Declared, 2026-04-26) | >0.4 on iOS 26+ devices (T2 — Declared) |
| Kill criteria | Recommendations override rate >70% sustained for 30 days post-launch OR Foundation Model confidence remains <0.2 on iOS 26+ devices for 60 days OR cloud cohort match rate <10% sustained 30 days → readiness-aware orchestration is considered failed and the engine reverts to the v1 generic flow (T2 — Declared, 2026-04-26) | — |

---

## Acceptance Criteria

- [ ] LocalUserSnapshot includes `readinessScore`, `readinessConfidence`, `readinessRecommendation`, `hrvScore`, `sleepScore`, `trainingLoadScore`, `rhrScore`, and `fatigueFlags`
- [ ] `AISnapshotBuilder.build()` accepts optional `ReadinessResult` parameter; nil input produces identical behavior to current implementation
- [ ] `recoveryBands()` returns readiness-based bands (high/moderate/low + fatigue tiers)
- [ ] `trainingBands()` returns ACWR-based bands (optimal/underloaded/overreaching)
- [ ] `FoundationModelService.buildPrivateContext()` includes readiness score, component breakdown, and active fatigue flags
- [ ] AIOrchestrator overrides training recommendation when readinessScore < 30
- [ ] AIOrchestrator surfaces active body composition flags in recovery segment
- [ ] All existing AIOrchestrator tests pass — backward compatible
- [ ] CI green (tokens-check + build + test)

---

## Non-Scope

- New cloud API endpoints — reuse existing `/v1/{segment}/insight`
- User feedback on recommendation quality (tracked separately as Child 3)
- Custom Foundation Model fine-tuning
- Garmin / Whoop / Oura adapter integration (Phase B)

---

## Dependencies

- **Child 1 (Readiness Score v2) must be complete** before implementation begins. This PRD requires the `ReadinessResult` type and `ReadinessEngine` to be available in the codebase.
- Reference: `docs/product/prd/readiness-score-formula-v2.md`
