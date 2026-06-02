# PRD: AI User Feedback Loop

> **ID:** ai-user-feedback-loop | **Status:** Phase 1 (PRD) — in flight | **Priority:** MEDIUM
> **Framework version:** v7.9 | **Branch:** `feature/ai-user-feedback-loop`
> **Backlog source:** [`docs/product/backlog.md` L351](../backlog.md) — "User feedback loop for AI"
> **Phase 0 (Research):** [`.claude/features/ai-user-feedback-loop/research.md`](../../.claude/features/ai-user-feedback-loop/research.md) — shipped in PR #572

---

## Purpose

Close the deferred audit UI-024 — wire the existing `RecommendationMemory` storage + `AIFeedbackView` UI + `home_ai_feedback_submitted` analytics into a real reinforcement loop. The thumbs-up/thumbs-down tap on the Home AI insight card today goes to analytics but is dropped before reaching local storage. C5 reconnects the path + adds per-signal-per-segment confidence adjustment to `AIOrchestrator` + a Settings management surface.

## Problem Statement

`AIInsightCard.recordFeedback()` has carried a deferred-comment block since PR #79 (2026-04-10):

```swift
// Note (audit UI-024): Local RecommendationMemory recording deferred —
// RecommendationMemory is owned per-AIOrchestrator instance, not a
// shared singleton. Wiring requires either an EnvironmentObject pattern
// or a dedicated DI container.
```

Result: 47+ feedback events fired during the 2026-05-31 → 2026-06-01 GA4 window (per [B1 anomaly check ledger](../../.claude/shared/must-have-cadence-followups.md)), but `RecommendationMemory.totalCount` on every user's device stays at 0. The reinforcement-loop infrastructure exists but is inert.

The home screen shows the same recommendation patterns regardless of user response — `"Your sleep quality could use a boost"` may appear on day 50 even though the user dismissed it 49 times. No mechanical learning.

## Business Objective

Convert the existing dead-end feedback signal into a calibration mechanism that makes recommendations measurably more relevant over time. This pairs with D1 (adaptive-intelligence next pass) — D1 builds the cohort-level learning layer on top of the on-device per-user reinforcement loop this PRD ships.

---

## Success Metrics

Per the 2026-04-21 Gemini Tier 2.3 convention, all metrics carry T1/T2/T3 tier labels.

| Metric | Tier | Baseline | Target | Window |
|---|---|---|---|---|
| `home_ai_feedback_submitted` events per WAU | T1 | 0.03 (47 events / ~35 testers / 6 weeks) | ≥ 0.10 at T+30d | 30d |
| Acceptance rate ≥ 0.6 in ≥ 2 segments (T1 instrumented via `RecommendationMemory.acceptanceRate(for:)` query) | T1 | nil (no data) | ≥ 2 segments at T+30d | 30d |
| Recommendation-fatigue rate (dismissed / shown) declining trend | T2 | unknown — no instrumentation | declining over 14d | 30d |
| Settings → AI Feedback opt-out rate | T2 | 0% | ≤ 20% (kill criterion guard) | 30d |
| Suppression accuracy (qualitative — operator confirms suppressed signals match user intuition) | T3 | — | ≥ 1 positive operator observation | 14d |

## Kill Criteria

If any fires during the 30-day window, the feature flips opt-out-default-FALSE pending recalibration:

- Acceptance rate at T+14d < baseline measured before C5 ships (the loop made things worse)
- `home_ai_feedback_submitted` event volume declines (UX broke the feedback surface)
- Settings → AI Feedback opt-out rate > 20% (signal overcorrection — users explicitly disabling the loop)
- User-reported "wrong recommendations being suppressed" via in-app dismiss-reason `disagree` count > 20% of total dismissals

---

## Requirements

### User stories

- **US-1.** As a user who taps thumbs-down on an irrelevant home insight, my dismissal trains the on-device recommendation engine — by my 5th dismissal of similar signals, they no longer appear.
- **US-2.** As a user who taps thumbs-up consistently on training signals, the AI engine learns to surface training advice with higher confidence and frequency.
- **US-3.** As a user dismissing a recommendation, I can optionally tell the system WHY (5 enum choices + free text) — letting the suppression behavior weight smarter.
- **US-4.** As any user, I can view past feedback in Settings → AI Feedback (count + per-segment acceptance breakdown + suppressed-signals list).
- **US-5.** As any user, I can clear my feedback history in Settings (GDPR + reset-on-distrust pathway).
- **US-6.** As any user, I can disable the reinforcement loop entirely via a Settings toggle (default ON).

### FROZEN constants (changing requires re-Phase-1)

| Constant | Value | Rationale |
|---|---|---|
| `acceptanceUpgradeThreshold` | 0.70 | Above this → boost confidence one tier. Matches Smart Reminders behavioral-learning Layer-1 threshold |
| `dismissalSuppressionThreshold` | 3 dismissals of same signal-id within last 30 days | Matches `RecommendationMemory.frequentlyDismissedSignals(threshold:)` existing default |
| `quorumCount` | 5 outcomes per segment | Matches existing `RecommendationMemory.acceptanceRate(for:)` quorum (already tested) |
| `adjustmentMode` | `confidenceTierOnly` (no signal synthesis) | Predictable + debuggable; doesn't fight the AI engine's signal-generation responsibility |
| `dismissReasonOptions` | `notRelevant` / `alreadyAware` / `disagree` / `repetitive` / `other` | Free-text fallback for `other` capped at 80 chars |
| `outcomeRetentionPerSegment` | 200 entries (LRU) | Matches existing `RecommendationMemory.maxEntriesPerSegment` — already shipped + tested |

### Reinforcement-loop algorithm (FROZEN)

```text
For each segment in [recovery, training, nutrition, stats]:
  let rate = recommendationMemory.acceptanceRate(for: segment)
  let dismissedSignals = recommendationMemory.frequentlyDismissedSignals(for: segment, threshold: 3)

  For each candidate recommendation in AIOrchestrator.latestRecommendations[segment]:
    For each signal in recommendation.signals:
      if dismissedSignals.contains(signal):
        confidence = downgradeOneTier(confidence)  # high → medium → low → suppress
      else if rate != nil && rate > 0.70:
        confidence = upgradeOneTier(confidence)    # low → medium → high (cap at high)
```

The reinforcement loop runs in `AIOrchestrator.refreshRecommendations()` — between candidate fetch and `ValidatedRecommendation` materialization. Pure transformation; no side effects beyond the in-memory recommendation pipeline.

### Three surfaces

#### Surface 1 — `AIInsightCard.recordFeedback` (wire only)

Existing tap handler. Replace audit-deferred comment block with:

```swift
recommendationMemory.record(outcome: RecommendationOutcome(
    segment: validated.recommendation.segment,
    signals: validated.recommendation.signals,
    confidenceLevel: validated.overallConfidence.rawValue,
    source: validated.recommendation.sourceTier,
    action: action,
    dismissReason: nil
))
```

`dismissReason` stays nil on the card (only the sheet picker provides reasons). Analytics fires unchanged.

#### Surface 2 — Dismiss-reason picker (`confirmationDialog`)

On thumbs-down in `AIIntelligenceSheet`'s feedback row (NOT in the home card — keeps card tap latency low), surface a `confirmationDialog` with the 5 enum options:

- "Not relevant to me"
- "Already aware of this"
- "I disagree"
- "Too repetitive"
- "Other (tell us more)" → opens text-input sheet, 80-char cap

Picked reason flows through to `RecommendationOutcome.dismissReason`. Free-text `other` reasons are stored verbatim on-device (never sent to server — privacy boundary).

#### Surface 3 — Settings → AI Feedback row

New `SettingsCategory.aiFeedback` row in `SettingsView`. The detail screen shows:

```text
Total outcomes recorded: 47

Per-segment acceptance:
  Training:   82% (28 outcomes)
  Recovery:   60% (15 outcomes)
  Nutrition:  45% (8 outcomes)  [≥5 quorum]
  Stats:      — (3 outcomes, below quorum)

Currently suppressed signals:
  • protein_below (12 dismissals)
  • elevated_resting_hr (8 dismissals)

[ Clear feedback history ]   ← GDPR + reset-on-distrust path

Use my feedback to personalize recommendations: [Toggle: ON]
```

Toggle copy: `"When on, the AI engine adapts to your thumbs-up/down history. When off, recommendations come from the engine baseline only."`

Default ON. When OFF, `AIOrchestrator.refreshRecommendations` skips the reinforcement-loop block entirely (analytics + storage still happen — the user can re-enable later without losing history).

### Settings copy

| Surface | Copy |
|---|---|
| Settings row title | "AI Feedback" |
| Settings row icon | `SF Symbol: hand.thumbsup.fill` (or AppIcon.thumbsUp filled variant) |
| Settings row subtitle | "Manage what the AI learns from your taps" |
| Detail screen header | "AI Feedback" |
| Empty state (totalCount == 0) | "Once you tap thumbs up or down on insights, your history will appear here." |
| Clear-all confirmation | "Clear feedback history? This resets your acceptance rates and unsuppresses all signals. This action is irreversible but doesn't delete any HealthKit or workout data." |
| Opt-out toggle off explanation | "AI recommendations will come from the engine baseline only — your feedback is still recorded but won't influence what you see." |

---

## Technical Approach

### New source files

- `FitTracker/AI/RecommendationFeedbackController.swift` — thin facade exposing `RecommendationMemory` to views via `@MainActor ObservableObject`. Holds + publishes a `@Published var totalCount: Int` for reactive Settings UI. Owns the per-segment computed properties (acceptanceRate, suppressedSignals).
- `FitTracker/Views/AI/DismissReasonPicker.swift` — `confirmationDialog` sheet for the 5 enum + free-text picker. Returns the picked reason via closure callback.
- `FitTracker/Views/Settings/v2/Screens/AIFeedbackSettingsScreen.swift` — Settings detail screen with the 4 sections (total + per-segment + suppressed + clear/toggle).

### Modified source files

- `FitTracker/AI/RecommendationMemory.swift` — extract `frequentlyDismissedSignals` window from "all-time" to "last 30 days" via timestamp filter. Minor change to match the algorithm.
- `FitTracker/AI/AIOrchestrator.swift` — add reinforcement-loop block in `refreshRecommendations()` between candidate fetch and ValidatedRecommendation materialization. Gated on the opt-out flag.
- `FitTracker/Views/AI/AIInsightCard.swift` — replace audit-deferred comment with actual `recommendationMemory.record(outcome:)` call. Add `@EnvironmentObject` for the controller.
- `FitTracker/Views/AI/AIFeedbackView.swift` — extend the sheet feedback row to surface `DismissReasonPicker` on thumbs-down. Wire picked reason into `RecommendationOutcome`.
- `FitTracker/Views/Settings/v2/Screens/SettingsView.swift` — add `SettingsCategory.aiFeedback` row.
- `FitTracker/Services/AppSettings.swift` (or extension thereof) — new `@Published var aiFeedbackLoopEnabled: Bool = true` field + UserDefaults persistence key `"ft.ai.feedbackLoopEnabled"`.
- `FitTracker/Services/Analytics/AnalyticsProvider.swift` — add 3 new event constants (see below).
- `FitTracker/Services/Analytics/AnalyticsService.swift` — add 3 new `logAi*` methods.
- `FitTracker/FitTrackerApp.swift` — promote `RecommendationFeedbackController` to `@StateObject` + env-object injection.

### Branch isolation discipline

- All work on `feature/ai-user-feedback-loop` (Mode C compliant — feature branch + state.json + Tier 2.2 log)
- No infra-path edits (no `.github/workflows/*`, no `scripts/*`, no `CLAUDE.md`) — Mode B not triggered

---

## Analytics Events

All three new events screen-prefixed `home_` per the 2026-04-08 project convention. The existing `home_ai_feedback_submitted` stays unchanged.

| Event | Trigger | Params |
|---|---|---|
| `home_ai_feedback_signal_suppressed` | Reinforcement loop suppresses a signal in this evaluation pass | `segment`, `signal`, `dismissal_count` (int 3+) |
| `home_ai_feedback_segment_boosted` | Reinforcement loop upgrades a segment's confidence based on acceptanceRate > 0.7 | `segment`, `acceptance_rate` (rounded int 0-100), `outcome_count` (int 5+) |
| `home_ai_feedback_history_cleared` | User taps "Clear feedback history" in Settings | `total_outcomes_cleared` (int) |

The existing `home_ai_feedback_submitted` (segment + rating) keeps its current shape. The new events fire in addition.

Param naming follows existing convention:

- `segment`: `recovery` / `training` / `nutrition` / `stats`
- `signal`: signal-id string (e.g., `protein_below`, `elevated_resting_hr`)
- `dismissal_count`: int — exactly how many dismissals triggered the suppression
- `acceptance_rate`: int 0-100 — rounded percentage
- `outcome_count`: int — sample size at boost time

---

## Phased Rollout

Single-PR Feature ship (no phased rollout for this scope). Phase 4 (Implement) lands all 3 new files + 8 modified files + tests. Post-merge:

- T+7d: first metrics readout (event volume, acceptance-rate distributions)
- T+14d: kill-criteria evaluation
- T+30d: cohort metrics review + decide on C5.b (time-decay) / C5.c (push routing) follow-ons

---

## Dependencies

All shipped as of 2026-06-01:

| Dependency | Source | Status |
|---|---|---|
| `RecommendationMemory` (record + queries + clearAll) | PR #79 | ✅ shipped 2026-04-10 |
| `RecommendationMemoryTests` | PR #79 | ✅ shipped 2026-04-10 |
| `RecommendationOutcome` (segment + signals + confidenceLevel + source + action + dismissReason + timestamp) | PR #79 | ✅ shipped 2026-04-10 |
| `AIInsightCard.recordFeedback` (analytics fires, storage deferred) | PR #79 | ✅ shipped 2026-04-10 |
| `AIFeedbackView` (sheet shell with thumbs up/down) | PR #79 | ✅ shipped 2026-04-10 |
| `AIOrchestrator.refreshRecommendations` pipeline | PR #79 | ✅ shipped 2026-04-10 |
| `ValidatedRecommendation` (carries segment + confidenceLevel + source) | PR #79 | ✅ shipped 2026-04-10 |
| `analytics.logAiFeedbackSubmitted` | PR #79 | ✅ shipped 2026-04-10 |
| Settings v2 surface pattern | PR #550 + #560 | ✅ shipped 2026-05-31 + 2026-06-01 |

**No new infrastructure required.**

---

## GDPR / Privacy

- `RecommendationOutcome` storage is plain `UserDefaults` (per the existing `RecommendationMemory.swift` header comment — PII-free: segment + signals + confidence + action + timestamp). No new data collection.
- Dismiss-reason free-text ("other") is stored verbatim on-device; **never sent to server**. The PRD explicitly disallows server-side aggregation of dismiss-reasons in C5 scope.
- "Clear feedback history" calls existing `RecommendationMemory.clearAll()` which `UserDefaults.standard.removeObject(forKey:)`s the storage key. Idempotent. Recoverable only via fresh-installation.
- Settings opt-out is a single bool. Disabling routes recommendations through the AI engine baseline; doesn't delete historical outcomes (so re-enable later doesn't lose data).
- No HealthKit data flows through this feature. No analytics-event data sent to GA4 carries free-text or PII.

---

## Risks

| Risk | Impact | Mitigation |
|---|---|---|
| **Suppression over-correction** — user dismisses a signal once-by-mistake and it gets suppressed on the 3rd dismissal even if 2 of those were intentional | False suppression | 3-dismissal threshold + 30-day window. Settings exposes which signals are currently suppressed; user can clear-all to reset. |
| **Acceptance-rate overfit** — user accepts training signals during peak motivation, suppressing recovery signals; later regrets when injury comes | Mis-tuned reinforcement | Per-segment scope means accepting training doesn't suppress recovery. Confidence-tier-only adjustment keeps the AI engine baseline available. |
| **Opt-out cliff** — users disable the loop after first frustration with suppression | Adoption | Default ON + clear opt-out copy explaining behavior. The `home_ai_feedback_signal_suppressed` analytics event lets us see suppression-then-opt-out patterns. |
| **Settings discoverability** — users don't find the AI Feedback row until after they've already opted out via other means | Low usage | Add to Settings v2 alongside Notifications + other AI-related toggles. Phase 6 (Review) confirms placement matches sibling surfaces. |
| **Test-flake from RecommendationMemory.clearAll() between test cases** | CI noise | All new tests use a per-test `UserDefaults(suiteName:)` instance for isolation. Pattern already established in `RecommendationMemoryTests.swift`. |

---

## Open Questions

| # | Question | Decision |
|---|---|---|
| OQ-1 | Should suppressed signals show on the home card as a "muted" state (with a "show me anyway" affordance) or be invisible? | **Invisible.** Mute-with-affordance adds visual noise and dilutes the "AI learning from me" trust signal. C5.b can revisit if users explicitly ask. |
| OQ-2 | Should the dismiss-reason picker appear on the home card or only in the sheet? | **Sheet only.** Home-card tap latency is critical (1-tap dismiss); sheet has more room + already shows the Why? section. |
| OQ-3 | Free-text `other` reason — max length? Privacy review? | **80 chars on-device only. Never sent to GA4 or any server.** Free-text is for the user's own benefit (can show in Settings → AI Feedback for self-review). |
| OQ-4 | What about pre-existing feedback events fired before C5 ships? Do we backfill? | **No backfill.** Historical events live in GA4 only; not on-device. C5 starts a fresh on-device store. |
| OQ-5 | Should the reinforcement loop pause during specific contexts (e.g., first 7 days post-install)? | **Defer to D1.** D1 (adaptive-intelligence) can layer cold-start handling on top. C5 ships the basic loop. |
| OQ-6 | Should `frequentlyDismissedSignals` window be 30 days or all-time? | **30 days.** Lets users "rehabilitate" suppressed signals after time passes. Matches the existing `RecommendationMemory.maxEntriesPerSegment = 200` LRU eviction. |

---

## Enhancements (future C5.b/c/d — out of scope this PRD)

- **C5.b** — Time-decay weighting: recent feedback weighted more than old. Currently equal-weight within the 30-day window.
- **C5.c** — Push notification routing: C2 + C4 `home_*_alert_action_taken` events get routed into `RecommendationMemory` so push-banner picks influence home-card AI insight suppression too.
- **C5.d** — Cohort-level feedback aggregation (privacy-impacting; needs separate GDPR review). Belongs to D1.
- **C5.e** — Suppression-transparency UX: tell users why a recommendation was suppressed when they explicitly ask. UX research needed first.

---

## Phase transition criteria

| From → To | Criterion |
|---|---|
| research → prd | Operator approves PRD (this document) freezing thresholds + algorithm + Settings copy + analytics events |
| prd → tasks | Tasks.md authored breaking implementation into discrete units (estimate: 12 tasks) |
| tasks → implement | All tasks defined + operator approval |
| implement → test | All tasks complete; swiftc -parse exit 0; CI ci.yml green |
| test → review | New tests pass (target: ~20 tests across 4 test files); coverage ≥ 90% on new files |
| review → merge | `/ux pre-merge-review` + `/design pre-merge-review` both pass |
| merge → complete | PR merged; backlog L351 row struck through; FEATURE_CLOSURE_COMPLETENESS gate passes |

---

## Cross-references

- Phase 0 research: [`.claude/features/ai-user-feedback-loop/research.md`](../../.claude/features/ai-user-feedback-loop/research.md)
- State.json: [`.claude/features/ai-user-feedback-loop/state.json`](../../.claude/features/ai-user-feedback-loop/state.json)
- Tier 2.2 log: [`.claude/logs/ai-user-feedback-loop.log.json`](../../.claude/logs/ai-user-feedback-loop.log.json)
- Audit UI-024 source line: `FitTracker/Views/AI/AIInsightCard.swift:230-235`
- Storage layer: `FitTracker/AI/RecommendationMemory.swift`
- Sibling C2 (readiness-aware-training-alert) case study: `docs/case-studies/readiness-aware-training-alert-case-study.md`
- Sibling C4 (trend-alerts-hrv) case study: `docs/case-studies/trend-alerts-hrv-case-study.md`
- Pair feature D1 (adaptive-intelligence next pass): backlog RICE 4.5
- 2026-05-31 tier carryover plan: `~/.claude/projects/-Volumes-DevSSD-FitTracker2/memory/project_session_2026_05_31_tier_carryover_plan.md`
