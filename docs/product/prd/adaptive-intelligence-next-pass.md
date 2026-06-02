# PRD: Adaptive Intelligence Next Pass (D1) — v1 = D1.a (time-decay + trend) + D1.d (transparency UX)

> **ID:** adaptive-intelligence-next-pass | **Status:** Phase 1 (PRD) — in flight
> **Priority:** MEDIUM (RICE 4.5)
> **Framework version:** v7.9 | **Branch:** `feature/adaptive-intelligence-next-pass`
> **Backlog source:** [`docs/product/backlog.md`](../backlog.md) Planned RICE row 4.5
> **Phase 0 (Research):** [`.claude/features/adaptive-intelligence-next-pass/research.md`](../../.claude/features/adaptive-intelligence-next-pass/research.md) — 12 sections, 4 candidates enumerated
> **Predecessor:** C5 ai-user-feedback-loop (PR #572 merged `ec5dff9` 2026-06-02; closed audit UI-024)

---

## Purpose

D1 v1 builds the next layer on top of C5's per-user reinforcement loop. Two sub-features ship together:

- **D1.a — Time-decay + trend detection** on `RecommendationMemory`. Recent feedback weighted more than 30-day-old feedback. Per-user trend detector flags signal-acceptance trending UP / DOWN / FLAT over 60-day windows. Trend-informed un-suppression of signals previously suppressed.
- **D1.d — Suppression transparency UX** in `Settings → AI Feedback`. Tap a suppressed signal to see why (date list of dismissals, optional reasons), un-suppress manually, or blacklist permanently.

The pair stays 100% on-device. Closes 2 of C5 PRD's explicit out-of-scope items: C5.b (time-decay) + C5.e (transparency UX).

**D1.b (cohort priors) and D1.c (AI-suggested replacement) are deferred to v8.0+** — they require backend infra + DPIA delta that don't fit the Phase E discipline window.

## Problem Statement

C5 shipped the on-device reinforcement loop, but two operational gaps remain:

1. **No time decay.** A signal dismissed 4 times 60 days ago and accepted 3 times in the last 7 days is treated as net-3-dismissed. Recent feedback should win.
2. **No reversibility surface.** Once a signal is suppressed, the user has no UI affordance to un-suppress it without clearing ALL feedback history (via `Clear feedback history` in Settings → AI Feedback). This is too coarse — the user can't say "I changed my mind about THIS specific signal."

Both gaps were filed in C5 PRD §"Enhancements (future C5.b/c/d/e)" as deliberate v1 cuts.

## Business Objective

Improve recommendation calibration over multi-month windows (D1.a) + give power users a mechanical-control surface that builds trust in the loop's behavior (D1.d). Together they answer the "how does the AI improve over time?" user-research observation from the 2026-05-24 UX deep-dive.

---

## Success Metrics

Per 2026-04-21 Gemini Tier 2.3 convention. All metrics carry T1/T2/T3 tier labels.

| Metric | Tier | Baseline | Target | Window |
|---|---|---|---|---|
| `home_ai_feedback_signal_unsuppressed_by_trend` events per WAU | T1 | 0 | ≥ 0.05 at T+60d | 60d |
| Signal un-suppression-vs-suppression ratio (un-suppressed / newly suppressed) | T1 | nil | 0.10 ≤ ratio ≤ 0.40 (loop is calibrating, not thrashing) | 60d |
| `home_ai_feedback_suppressed_detail_opened` events per WAU | T1 | 0 | ≥ 0.05 per WAU at T+30d | 30d |
| Manual un-suppression rate (`signal_manually_unsuppressed` / `suppressed_detail_opened`) | T1 | nil | 0.10 ≤ rate ≤ 0.50 | 30d |
| Permanent-blacklist rate (`signal_blacklisted_permanently` / `suppressed_detail_opened`) | T1 | nil | ≤ 0.20 (high = overreach signal) | 30d |
| Acceptance-rate variance across users (per-segment) | T2 | post-C5 baseline computed at D1.a ship | ≥ 15 percent increase post-D1.a | 60d |
| Settings → AI Feedback opt-out rate vs pre-D1.d baseline | T2 | post-C5 baseline | ≤ pre-D1.d rate (transparency should NOT erode trust) | 30d |

## Kill Criteria

Any of the following at T+14d/T+30d flips the loop opt-out-default-FALSE pending recalibration:

- Acceptance-rate variance DECREASES after D1.a (trend detection making the loop noisier, not sharper)
- Manual un-suppression rate < 0.05 at T+30d (UX too hidden or feature unused)
- Permanent-blacklist rate > 0.20 (transparency UX over-corrects; users wholesale-blacklisting > suppressing — signal of mis-tuned reinforcement)
- Settings opt-out rate vs pre-D1.d baseline INCREASES (transparency undermined trust instead of building it)
- Crash rate on `SuppressedSignalDetailScreen` > 0.5% of opens
- Any regression in C5 metrics (`home_ai_feedback_submitted` per WAU declines)

---

## Requirements

### User stories

- **US-1.** As a user whose acceptance pattern has shifted (e.g., started accepting nutrition signals 30 days ago after dismissing them earlier), the AI engine adapts within ~7 days because recent feedback outweighs old.
- **US-2.** As a user whose signal was suppressed 60 days ago (and I've since changed my mind), the recommendation can re-surface naturally as time-decay erodes the older dismissals.
- **US-3.** As any user looking at `Settings → AI Feedback`, I can tap a suppressed signal and see the 3+ dismissals that triggered suppression (dates + optional reasons).
- **US-4.** As a user, I can un-suppress a single signal manually without clearing my entire feedback history.
- **US-5.** As a user, I can permanently blacklist a signal (overrides the 30-day rehabilitation window).
- **US-6.** As a user, the un-suppress / blacklist decisions persist across app restarts.

### FROZEN constants (changing requires re-Phase-1)

| Constant | Value | Rationale |
|---|---|---|
| `timeDecayLambda` | `0.0231 day^-1` (half-life = 30 days) | Matches the existing `dismissalSuppressionThreshold` 30-day window — older feedback decays to 50 percent weight at the suppression boundary |
| `trendDetectionWindow` | 60 days | 2× the 30-day suppression window; long enough for legitimate behavior shifts to register without thrashing |
| `trendUnsuppressionAcceptanceFloor` | 0.50 | Trend-informed un-suppression only fires when last-7-day acceptanceRate(segment) ≥ 0.50 (cannot un-suppress purely from time decay; must see active acceptance) |
| `manualUnsuppressionPersistence` | 14 days | A manually un-suppressed signal stays surfaceable for 14 days before re-evaluating against current dismissal history |
| `permanentBlacklistRevocation` | "via `Clear feedback history`" | Blacklist persists indefinitely; only the existing GDPR clear-all wipes it |
| `analyticsReinforcementMode` | `confidenceTierOnly` (inherited from C5) | D1.a still operates on confidence tiers, not signal synthesis |

### Reinforcement-loop algorithm extensions (FROZEN)

```text
For each signal in recommendation.signals (for segment S):
  let suppression_score = Σ over dismissals(d) where d.signal == s and d.segment == S:
                              exp(-timeDecayLambda * days_since(d.timestamp))
  
  if suppression_score >= 3 AND not in manual_unsuppression_window:
    if user_has_blacklisted(s, S):
      SUPPRESS (no further evaluation)
    else if last_7d_acceptanceRate(S) >= trendUnsuppressionAcceptanceFloor:
      let un_suppression = TRUE
      fire home_ai_feedback_signal_unsuppressed_by_trend
    else:
      apply existing C5 suppression
  else:
    apply existing C5 logic
```

The reinforcement loop runs in the existing `AIOrchestrator.applyReinforcementLoop()` block. D1.a adds:
1. New helper `RecommendationMemory.timeDecayedSuppressionScore(for: segment, signal: String) -> Double`
2. New helper `RecommendationMemory.last7DayAcceptanceRate(for: segment) -> Double?`
3. New helper `RecommendationMemory.isManuallyUnsuppressed(_ signal: String, in: AISegment) -> Bool`
4. New helper `RecommendationMemory.isBlacklisted(_ signal: String, in: AISegment) -> Bool`
5. New `AcceptanceTrendDetector` class as a pure-function wrapper around the four helpers above

### Three new surfaces

#### Surface 1 — `AIOrchestrator` trend-informed un-suppression (D1.a)

Pure-function extension to `applyReinforcementLoop()`. No new public APIs; existing callers transparently get the new behavior. The trend-detection block runs after the existing suppression-check; if a signal would be suppressed under C5 logic but the trend-detector says `last_7d_acceptanceRate ≥ 0.50`, the un-suppression fires + emits the new analytics event.

#### Surface 2 — `SuppressedSignalDetailScreen` view (D1.d)

New Settings v2 sub-screen pushed from `AIFeedbackSettingsScreen` when the user taps a row in "Currently Suppressed". Detail screen shows:

```text
┌──────────────────────────────────────┐
│  protein_below                       │
│  Recovery segment                    │
├──────────────────────────────────────┤
│  Why suppressed                      │
│                                      │
│  3 dismissals in last 30 days:       │
│  • 2026-05-20 — not_relevant         │
│  • 2026-05-25 — already_aware        │
│  • 2026-05-29 — (no reason)          │
│                                      │
│  Time-decay weight: 2.1 / 3.0        │
│  (oldest dismissal 13 days old)      │
├──────────────────────────────────────┤
│  Last 7 days acceptance rate         │
│  Recovery segment: 0.45 (3 of 7)     │
│  Below the 0.50 floor for            │
│  automatic un-suppression            │
├──────────────────────────────────────┤
│  [ Un-suppress this signal ]         │
│   Stays surfaceable for 14 days      │
│                                      │
│  [ Blacklist permanently ]           │
│   Cannot be re-suppressed without    │
│   Clear feedback history             │
└──────────────────────────────────────┘
```

Both buttons fire confirmation dialogs. Each emits the relevant analytics event on confirm.

#### Surface 3 — `AIFeedbackSettingsScreen` row-tap routing (D1.d)

Existing screen's "Currently Suppressed" section gets `NavigationLink` wiring so each suppressed-signal row pushes the new `SuppressedSignalDetailScreen` for that signal.

### Settings copy

| Surface | Copy |
|---|---|
| Detail screen title | "Suppressed signal" |
| Detail header | `{signal_human_readable}` — `{segment.capitalized}` segment |
| "Why suppressed" section title | "Why suppressed" |
| Dismissals subtitle | "{N} dismissals in last 30 days" |
| Time-decay weight subtitle | "Time-decay weight: {weight} / {threshold}" |
| "Last 7 days" section title | "Last 7 days acceptance rate" |
| Floor explanation | "Below the {floor} floor for automatic un-suppression" / "At/above the {floor} floor — should auto-un-suppress on next refresh" |
| Un-suppress button | "Un-suppress this signal" |
| Un-suppress description | "Stays surfaceable for 14 days, then re-evaluates against dismissal history" |
| Blacklist button | "Blacklist permanently" |
| Blacklist description | "Cannot be re-suppressed without Clear feedback history" |
| Un-suppress confirm | "Un-suppress {signal}? It can re-surface on the next refreshRecommendations pass." |
| Blacklist confirm | "Blacklist {signal}? This signal will never be shown again until you Clear feedback history." |

---

## Technical Approach

### New source files

- `FitTracker/AI/AcceptanceTrendDetector.swift` — pure-function helper providing time-decay scoring + 7-day acceptance rate + manual-un-suppression + blacklist checks. All static methods; no state.
- `FitTracker/Views/Settings/v2/Screens/SuppressedSignalDetailScreen.swift` — Settings detail screen for a single suppressed signal.

### Modified source files

- `FitTracker/AI/RecommendationMemory.swift` — add 4 new helper methods:
  - `timeDecayedSuppressionScore(for:signal:within:now:) -> Double`
  - `last7DayAcceptanceRate(for:within:now:) -> Double?`
  - `isManuallyUnsuppressed(_ signal:in:within:now:) -> Bool` (reads from new `manualUnsuppressions: [ManualUnsuppression]` field)
  - `isBlacklisted(_ signal:in:) -> Bool` (reads from new `blacklistedSignals: [BlacklistedSignal]` field)
  - `recordManualUnsuppression(signal:segment:now:)` 
  - `recordBlacklist(signal:segment:now:)`
- `FitTracker/AI/RecommendationFeedbackController.swift` — expose the new query methods via the env-object facade
- `FitTracker/AI/AIOrchestrator.swift` — extend `applyReinforcementLoop()` to use `AcceptanceTrendDetector` for time-decay + trend-informed un-suppression
- `FitTracker/Views/Settings/v2/Screens/AIFeedbackSettingsScreen.swift` — wire suppressed-signal rows as `NavigationLink`s
- `FitTracker/Services/Analytics/AnalyticsService.swift` — add 3 new `logHomeAiFeedback*` methods
- `FitTracker/Services/Analytics/AnalyticsProvider.swift` — add 3 new event constants + 3 new param constants (`signal`, `prior_dismissal_count`, `days_since_last_dismiss` — `signal` already exists per C5)
- `FitTracker.xcodeproj/project.pbxproj` — wire 2 new source files + 1 new test file group

### Data model extensions (`RecommendationMemory`)

Two new persisted fields (UserDefaults-backed alongside existing `outcomes`):

```swift
struct ManualUnsuppression: Codable, Sendable {
    let signal: String
    let segment: String
    let timestamp: Date  // re-evaluation window: 14 days from this
}

struct BlacklistedSignal: Codable, Sendable {
    let signal: String
    let segment: String
    let timestamp: Date  // informational; persists until clearAll
}

@MainActor
final class RecommendationMemory: @unchecked Sendable {
    // existing
    private var outcomes: [RecommendationOutcome] = []
    // NEW
    private var manualUnsuppressions: [ManualUnsuppression] = []
    private var blacklistedSignals: [BlacklistedSignal] = []
    // ...
}
```

Both new fields are wiped by the existing `clearAll()` GDPR path. No new privacy surface — same UserDefaults bucket, same PII-free shape (segment + signal-ID + timestamp only).

### Branch isolation discipline

- All work on `feature/adaptive-intelligence-next-pass` (Mode C compliant)
- No infra-path edits (no `.github/workflows/*`, no `scripts/*`, no `CLAUDE.md`) — Mode B not triggered

---

## Analytics Events

3 new events screen-prefixed `home_` per 2026-04-08 project convention. Join the existing `home_ai_feedback_signal_suppressed` / `_segment_boosted` / `_history_cleared` from C5.

| Event | Trigger | Params |
|---|---|---|
| `home_ai_feedback_signal_unsuppressed_by_trend` | Reinforcement loop un-suppresses a signal due to trend detection | `segment`, `signal`, `prior_dismissal_count` (int 3+), `days_since_last_dismiss` (int) |
| `home_ai_feedback_suppressed_detail_opened` | User opens `SuppressedSignalDetailScreen` for any signal | `segment`, `signal`, `dismissal_count` |
| `home_ai_feedback_signal_manually_unsuppressed` | User confirms un-suppress on the detail screen | `segment`, `signal`, `via_trend` (bool — `false` if user manually overrode without the trend criterion being met) |
| `home_ai_feedback_signal_blacklisted_permanently` | User confirms blacklist on the detail screen | `segment`, `signal`, `dismissal_count` |

The existing C5 events stay unchanged. The 4th event above (`blacklisted_permanently`) is needed to track the kill-criterion permanent-blacklist rate.

---

## Phased Rollout

Single-PR Feature ship (no phased rollout for this scope). Phase 4 lands all 2 new files + 6 modified files + tests. Post-merge:

- T+7d: first metrics readout (un-suppression event volume, detail-screen open rate)
- T+14d: kill-criteria evaluation #1 (variance + un-suppression-vs-suppression ratio sanity)
- T+30d: full review (UX adoption, opt-out rate vs pre-D1.d baseline)
- T+60d: D1.a effectiveness review (acceptance-rate variance increase ≥ 15 percent target)

---

## Dependencies

All shipped as of 2026-06-02:

| Dependency | Source | Status |
|---|---|---|
| C5 RecommendationMemory env-object (`RecommendationFeedbackController`) | PR #572 | ✅ shipped 2026-06-02 |
| C5 reinforcement-loop block in `AIOrchestrator.applyReinforcementLoop` | PR #572 | ✅ shipped |
| C5 `AIFeedbackSettingsScreen` with `Currently Suppressed` section | PR #572 | ✅ shipped |
| Settings v2 navigation patterns (`SettingsDetailScaffold`) | PR #550 | ✅ shipped |
| AnalyticsService event-firing infrastructure | PR #79+ | ✅ shipped |

**No new infrastructure required.** All deps shipped at v7.9 baseline.

---

## GDPR / Privacy

- **All new data stays on-device.** `manualUnsuppressions` + `blacklistedSignals` are UserDefaults-backed alongside existing `outcomes` — same PII-free shape (segment + signal-ID + timestamp).
- **No server-side aggregation.** Trend detection is per-user only.
- **`clearAll()` wipes both new fields** — existing GDPR `Clear feedback history` reset path covers D1.a + D1.d state without modification.
- **No new analytics fields carry PII or free-text.** Signal-IDs are pre-existing canonical strings (e.g., `protein_below`, `elevated_resting_hr`).
- **DPIA delta: NONE.** D1 v1 ships under the existing C5 GDPR record-keeping; no new data category or processing purpose.

---

## Risks

| Risk | Impact | Mitigation |
|---|---|---|
| **Trend over-correction** — last-7-day acceptance rate is noisy with low sample sizes | False un-suppression | Floor of 0.50 + require ≥3 outcomes in last 7 days before trend triggers (implemented via `last7DayAcceptanceRate` returning nil below quorum) |
| **Time-decay tuning miscalibrated** — half-life 30 days could prove too fast or slow | Loop thrashes or stays stale | Phase 4 ships with the FROZEN constants but `AcceptanceTrendDetector` is parameterized; T+30d review can re-Phase-1 if needed |
| **Blacklist abused** — user blacklists everything | Recommendation engine empty | Kill criterion: blacklist rate > 0.20 triggers UX review |
| **Detail screen too technical** — time-decay weight + 7-day rate too engineer-y for end users | Settings reads as bureaucratic | UX simplification path: hide the numeric weight; show only "🟡 suppressed because 3 dismissals" / "🟢 trending positive — should auto-un-suppress soon" |
| **Concurrent C5/D1 reinforcement-loop runs** | Race on `RecommendationMemory.outcomes` | Existing `NSLock` in `RecommendationMemory` protects both pre + post D1 — no change needed |
| **Test flake on `last7DayAcceptanceRate`** — injectable `now:` parameter matters | CI noise | All new helpers accept `now: Date = Date()` for deterministic test seeding (matches C5's `frequentlyDismissedSignals` pattern) |

---

## Open Questions

| # | Question | Decision |
|---|---|---|
| OQ-1 | Should manually un-suppressed signals show a visual badge ("you re-allowed this") in subsequent recommendations? | **No for v1.** Adds visual noise. C5.d / D1 follow-on can revisit if users explicitly ask. |
| OQ-2 | Blacklist scope — per-segment (e.g., `protein_below` blacklisted only for nutrition) or global (across all segments)? | **Per-segment.** A signal-string can legitimately appear in different segments with different valences. Per-segment scope matches the existing acceptance-rate computation. |
| OQ-3 | Should trend-informed un-suppression require both time-decay erosion AND last-7d acceptance? | **Both, AND-gated.** Either alone is too noisy. The AND-gate makes the signal "you used to dislike this AND you're actively engaging now." |
| OQ-4 | What happens to a signal that was un-suppressed-by-trend, then dismissed 3 more times? | **Re-suppression on the next refresh.** The 14-day window applies only to MANUAL un-suppressions. Trend un-suppressions re-evaluate every refresh. |
| OQ-5 | Free-text "blacklist reason"? | **No.** Inferable from the dismissal-reason history already shown in the detail screen. |
| OQ-6 | Should the detail screen show OTHER signals related to this one (e.g., if user blacklists `protein_below`, suggest also `nutrition_macro_mismatch`)? | **No for v1.** That's the D1.c (AI-suggested replacement) sub-feature, deferred to v8.0+. |

---

## Phased v8.0+ deferrals (NOT in v1 D1)

| Deferred | Scope | Why deferred |
|---|---|---|
| **D1.b — Cohort priors** (k≥20 federated avg) | Per-cohort acceptance baseline for cold-start users | Backend + DPIA delta; HADF Phase 2-bis block C cohort infra still maturing |
| **D1.c — AI-suggested replacement** when signal blacklisted | Mapping table or LLM gateway | Needs LLM gateway Phase 0 separately |
| **D1.e — Cross-segment trend correlation** | "User trending up in training but down in nutrition" | Adds query complexity; D1.a's per-segment scope is enough for v1 |

---

## Phase transition criteria

| From → To | Criterion |
|---|---|
| research → prd | ✅ done (this PR) |
| prd → tasks | Operator approves PRD (frozen constants + 4 analytics events + Settings copy + algorithm) |
| tasks → implement | Tasks broken into ~10 discrete units (estimate) |
| implement → test | Build green; new test suite (~18 tests targeting ≥90% coverage on new files) passes |
| test → review | `make ui-audit` P0=0; coverage thresholds met |
| review → merge | `/ux pre-merge-review` + `/design pre-merge-review` both pass |
| merge → complete | PR merged; backlog Planned row 4.5 struck; FEATURE_CLOSURE_COMPLETENESS gate passes |

---

## Cross-references

- Phase 0 research: [`.claude/features/adaptive-intelligence-next-pass/research.md`](../../.claude/features/adaptive-intelligence-next-pass/research.md)
- C5 ai-user-feedback-loop predecessor: [`docs/case-studies/ai-user-feedback-loop-case-study.md`](../case-studies/ai-user-feedback-loop-case-study.md) (closed audit UI-024; built the foundation D1 extends)
- C5 PR: <https://github.com/Regevba/FitTracker2/pull/572> (merged `ec5dff9`)
- Backlog row: `docs/product/backlog.md` Planned RICE row 4.5
- Sibling C5 PRD: `docs/product/prd/ai-user-feedback-loop.md`
- Sibling C6 (training-program-customization) PRD: in flight per sequence
- Sibling C3 (exercise-search-filter) PRD: in flight per sequence
