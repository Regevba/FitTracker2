# AI User Feedback Loop — Phase 0 Research

> **Feature type:** Feature (9-phase: Research → PRD → Tasks → UX/Integration → Implement → Test → Review → Merge → Docs)
> **RICE:** 9.0 (third on the 2026-05-31 refreshed Planned ranking, after C2 + C4 shipped 2026-06-01)
> **Backlog source:** `docs/product/backlog.md` L351 row — "User feedback loop for AI — can't rate recommendation quality"

## 1. Problem

FitMe has the **storage layer** for AI feedback (`FitTracker/AI/RecommendationMemory.swift` — 140 lines, fully tested in `FitTrackerTests/RecommendationMemoryTests.swift`) AND the **UI surface** for collecting feedback (`AIInsightCard.feedbackButtons` thumbs up/down + `AIIntelligenceSheet.AIFeedbackView`). What's missing is the **wire** between them — and the **reinforcement loop** that uses the wired data to improve future recommendations.

The current state of `AIInsightCard.recordFeedback()`:

```swift
private func recordFeedback(_ action: UserAction) {
    feedbackGiven = true
    guard let validated = primaryValidated else { return }

    // Log analytics — reuse existing feedback method with appropriate rating
    let rating = (action == .accepted) ? "positive" : "negative"
    analytics.logAiFeedbackSubmitted(segment: validated.recommendation.segment, rating: rating)

    // Note (audit UI-024): Local RecommendationMemory recording deferred —
    // RecommendationMemory is owned per-AIOrchestrator instance, not a
    // shared singleton. Wiring requires either an EnvironmentObject pattern
    // or a dedicated DI container. Tracked separately; analytics signal
    // already captures the feedback event server-side.
}
```

The analytics signal fires (server-side measurement works), but the **on-device reinforcement loop** doesn't — the tap is captured, then dropped. RecommendationMemory's `acceptanceRate(for:)` and `frequentlyDismissedSignals(for:)` queries always return empty because no `record(outcome:)` ever runs.

Result: the AI engine keeps surfacing the same recommendation patterns regardless of whether the user repeatedly dismisses them. The home screen's "Your sleep quality could use a boost" message shows up the 50th day in a row even though the user dismissed it 49 times.

## 2. The three closures C5 ships

### 2.1 Closure A — UI-024 wire (the deferred comment)

Promote `RecommendationMemory` from a private member of `AIOrchestrator` to an injectable `@StateObject` in `FitTrackerApp` + `.environmentObject(recommendationMemory)` into the env hierarchy. `AIInsightCard.recordFeedback` reads it via `@EnvironmentObject` and calls `record(outcome:)` directly. Replace the audit-deferred comment block with the actual call.

### 2.2 Closure B — Reinforcement loop in AIOrchestrator

`AIOrchestrator.refreshRecommendations()` (the pipeline that produces `latestRecommendations`) consumes `RecommendationMemory` BEFORE materializing the next batch:

```text
1. Fetch raw cloud + local recommendations as today
2. For each candidate signal in each segment:
     - If recommendationMemory.frequentlyDismissedSignals(for: segment).contains(signal):
         downgrade confidence by 1 tier (high → medium → low) OR suppress entirely
     - If recommendationMemory.acceptanceRate(for: segment) > 0.7 (≥5 outcomes):
         upgrade confidence by 1 tier
3. Materialize ValidatedRecommendation with adjusted confidence
4. Surface in UI
```

The adjustment is **per-signal-per-segment** (not global). A user who accepts training advice but dismisses nutrition signals gets training boosted + nutrition suppressed independently.

### 2.3 Closure C — Settings → AI Feedback management surface

New `SettingsCategory.aiFeedback` row. Shows:

- Total feedback events recorded (e.g., "47 outcomes")
- Per-segment acceptance rate breakdown (table: training 82%, nutrition 45%, recovery 60%, stats —)
- "Suppressed signals" list (from `frequentlyDismissedSignals(for:)`)
- "Clear feedback history" button → `RecommendationMemory.clearAll()` (GDPR compliance — already implemented in storage layer)
- Optional toggle: "Use my feedback to personalize recommendations" (default ON; opt-out gates the reinforcement loop)

## 3. Dismiss-reason picker (new UX)

The existing `RecommendationOutcome` struct has a `dismissReason: String?` field that's currently always nil. C5 adds a dismiss-reason picker that surfaces on thumbs-down:

| Option | UserDefault reason string |
|---|---|
| Not relevant to me | `not_relevant` |
| Already aware of this | `already_aware` |
| I disagree | `disagree` |
| Too repetitive | `repetitive` |
| Other (free-text) | `other` |

The picker is a `confirmationDialog` sheet with the 5 options + free-text fallback. Storing the reason lets the reinforcement loop weight suppression smarter (e.g., `already_aware` is less negative than `disagree`).

## 4. Three design decisions

**1. Promote RecommendationMemory to env-object, not full singleton.** `@StateObject` in `FitTrackerApp` lifecycle gives lazy init + same-instance-across-views without a global. Per-process singleton has GDPR concerns (a `clearAll()` between accounts must reset cleanly); StateObject lifecycle ties memory to the app instance and re-creates fresh on account deletion + relaunch.

**2. Reinforcement loop confidence-tier-only, not signal-replacement.** Don't synthesize NEW signals from user feedback — only adjust the **confidence** of existing AIEngine-emitted signals. Signal *generation* is the AI engine's job; user feedback is *post-hoc calibration*. This keeps the reinforcement loop predictable, debuggable, and explainable in the Settings surface ("Why did we suppress this? You dismissed it 5 times.").

**3. Quorum threshold 5 outcomes per segment.** Below quorum, acceptanceRate returns nil and the loop is a no-op. Above quorum, the loop kicks in. Matches existing `RecommendationMemory.acceptanceRate(for:)` behavior — already shipped + tested. Avoids overreacting to early single-tap noise.

## 5. Success metrics + kill criteria

Per the 2026-04-21 Gemini Tier 2.3 convention, all metrics carry T1/T2/T3 tier labels.

| Metric | Tier | Baseline | Target | Window |
|---|---|---|---|---|
| `home_ai_feedback_submitted` event count per WAU | T1 | 0.03 (today's 47/sessions baseline) | ≥ 0.10 | 30d |
| Acceptance rate convergence to ≥ 0.6 per active segment | T1 | nil (no data) | ≥ 0.6 at T+30d in ≥ 2 segments | 30d |
| Suppression-driven user-reported "less noise" feedback | T3 | 0 | ≥ 1 positive operator-observation (qualitative) | 30d |
| Recommendation-fatigue rate (`dismissed` / `shown`) | T2 | unknown (no current measurement) | declining trend over 14d window | 30d |
| Acceptance-rate boost lift (signals matching boost criteria show higher tap-through) | T1 | — (descriptive) | descriptive only | 14d |

**Kill criteria (any):**

- Acceptance rate at T+14d < baseline (loop made things worse)
- `home_ai_feedback_submitted` event volume declines (UX-broke the feedback surface)
- User-reported "wrong recommendations being suppressed" via in-app feedback OR Settings → AI Feedback opt-out rate > 20% (signal overcorrection)

## 6. Mechanical dependencies

| Dependency | Status |
|---|---|
| `RecommendationMemory` (record + queries + clearAll) | ✅ shipped 2026-04-10 |
| `RecommendationMemoryTests` (unit tests) | ✅ shipped |
| `AIOrchestrator` + `latestRecommendations` pipeline | ✅ shipped 2026-04-10 |
| `ValidatedRecommendation` (segment + confidenceLevel + source carrier) | ✅ shipped |
| `AIInsightCard.recordFeedback` (UI tap → analytics) | ✅ shipped 2026-04-10 (with deferred-record comment) |
| `AIFeedbackView` (sheet-level thumbs up/down) | ✅ shipped 2026-04-10 |
| `analytics.logAiFeedbackSubmitted` | ✅ shipped (`home_ai_feedback_submitted`) |
| Settings v2 surface for new toggle/category | ✅ shipped (PR #550 ReminderPreferencesStore pattern reusable) |

**No new infrastructure required.** All dependencies operational at v7.9.

## 7. Scope NOT in C5

- **Cohort-level reinforcement** — feedback from other users informing your recommendations. Privacy-impacting + needs server-side aggregation. Deferred to D1 (adaptive-intelligence) follow-on.
- **Time-decay weighting** — recent feedback weighted more than old. Current `RecommendationMemory` keeps 200 outcomes per segment with simple LRU; time-decay is C5.b.
- **Signal-generation from feedback** — generating new signals based on user input. C5 only ADJUSTS confidence of AI-emitted signals.
- **Push-notification reinforcement** — C2 + C4 banner action_taken events fire `home_*_alert_action_taken` analytics but aren't routed into RecommendationMemory. Their `chosen` parameter is a CTA pick, not a recommendation-quality signal. C5.c follow-on if cross-routing is desired.
- **Why-this-was-suppressed UX** — show users why a recommendation was suppressed. Nice-to-have; out of scope until user-research validates that "suppression transparency" is a real ask.

## 8. C5 vs C2 vs C4 vs prior AI work

| Feature | What it adds |
|---|---|
| AIOrchestrator (PR #79) | Cloud + local + foundation-model triangulation; emits `latestRecommendations` |
| RecommendationMemory (PR #79) | Storage + queries — NEVER WIRED into views |
| AIFeedbackView (PR #79) | UI shell + analytics — NEVER WIRED into RecommendationMemory |
| C2 readiness-aware (PR #560) | Adds `home_readiness_alert_action_taken` event with `chosen` CTA — adjacent feedback shape |
| C4 trend-alerts (PR #564) | Adds `home_trend_alert_action_taken` with `rating` thumbs param — adjacent feedback shape |
| **C5 (this feature)** | **Wires the existing UI ↔ storage ↔ orchestrator loop. Reinforcement closes the cycle.** |

## 9. Phase E discipline

C5 ships during the v7.9 Phase E 14-day soak (2026-05-21 → 2026-06-04). **No new enforcement gates.** Consumes existing v7.8.6 + v7.9 infrastructure exclusively. Phase E compliant.

## 10. Phase 0 → Phase 1 transition criterion

- Operator approves this research.md (scope + closures A/B/C + dismiss-reason picker + quorum threshold)
- PRD authoring begins on operator go-ahead
- Phase 1 (PRD) freezes: acceptance-rate threshold for upgrade/downgrade, quorum count, dismiss-reason enum, Settings surface copy, opt-out toggle copy, new analytics event names

## 11. Cross-references

- Backlog row: `docs/product/backlog.md` L351 (line ~393)
- Storage source: [`FitTracker/AI/RecommendationMemory.swift`](../../FitTracker/AI/RecommendationMemory.swift)
- UI source: [`FitTracker/Views/AI/AIInsightCard.swift`](../../FitTracker/Views/AI/AIInsightCard.swift) (recordFeedback at line ~225 with audit UI-024 deferred comment)
- Sheet feedback shell: [`FitTracker/Views/AI/AIFeedbackView.swift`](../../FitTracker/Views/AI/AIFeedbackView.swift)
- C2 sibling pattern: `docs/case-studies/readiness-aware-training-alert-case-study.md`
- C4 sibling pattern: `docs/case-studies/trend-alerts-hrv-case-study.md`
- Tier carryover plan: `~/.claude/projects/-Volumes-DevSSD-FitTracker2/memory/project_session_2026_05_31_tier_carryover_plan.md`
- Pair feature (D1 adaptive-intelligence): backlog L# RICE 4.5
