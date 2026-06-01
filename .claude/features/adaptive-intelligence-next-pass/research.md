# D1 — Adaptive Intelligence Next Pass — Phase 0 Research

> **Feature type:** Feature (9-phase) — research-heavy, cross-platform
> **RICE:** 4.5 (research-heavy + cross-platform → confidence 0.45 dragged the score down)
> **Backlog source:** `docs/product/backlog.md` Planned table row 4.5
> **Sequence position:** D1 (post C2/C4/C5 ship 2026-06-01, post C3 + C6 + E4 in this session)

## 1. Problem framing — what D1 is, what it isn't

C5 (`ai-user-feedback-loop`, PR #572) closes the **per-user on-device reinforcement loop**: thumbs-up/down taps → `RecommendationMemory` → `AIOrchestrator` confidence-tier adjustment per segment. D1 is the **next layer on top** of that loop.

D1 is not:
- A rewrite of `AIOrchestrator`
- A replacement for `HADF Phase 2 clustering` (shipped 2026-05-01)
- A new ML model in itself
- A "build a chatbot" feature

D1 is **research into how to make the existing feedback signal more useful over time**, with cross-platform (iOS + backend) and privacy implications that require Phase 0 enumeration BEFORE PRD-level commitment.

## 2. The four candidate sub-features

Phase 0's job is to enumerate, not pre-commit. Phase 1 PRD picks 2 of these for the v1 D1 ship.

### 2.1 D1.a — Pure on-device extension (time-decay + trend detection)

**Scope:** Extend `RecommendationMemory` with:
- Time-decay weighting on outcomes (recent feedback weighted more than 30-day-old feedback)
- Per-user trend detection (signal acceptance rate trending UP / DOWN / FLAT over 60-day window)
- Trend-informed confidence adjustment in `AIOrchestrator` (e.g., signal that was suppressed 60 days ago but accepted recently → un-suppress)

**Privacy:** zero server-side. Pure on-device.
**Effort:** ~2 person-days (extension of C5 surface; no new infrastructure).
**Risk:** low — extends C5's existing API surface.
**Dependencies:** C5 reaches `implementation` complete.

**Why it's attractive:** highest privacy posture, lowest effort, closes the time-decay gap explicitly called out as out-of-scope in C5 PRD §"Enhancements (future C5.b)".

### 2.2 D1.b — Cohort-level adoption signal

**Scope:** anonymous aggregated cohort stats shared via the existing AI engine backend (`fittracker-ai-production.up.railway.app`):
- Each user's `RecommendationMemory.acceptanceRate(for: segment)` rolls up to a cohort-level mean (k≥20 minimum cohort, federated avg)
- Per-segment "this cohort accepts 73% of nutrition recommendations" surfaces to new users as a prior
- New users get sane baseline confidence BEFORE accumulating their own feedback

**Privacy:** banded values + k-anonymity (k≥20). Same banding model as `HADF Phase 2` clustering inputs. No per-user data leaves device. Requires backend extension (cohort_priors table + nightly aggregation job).
**Effort:** ~4 person-days (backend + iOS client + privacy review).
**Risk:** medium — backend touch + needs k≥20 fallback when cohort is too small.
**Dependencies:** C5 reaches `complete`; backend cohort_priors infrastructure (currently in flight under `HADF Phase 2-bis` block C work).

**Why it's attractive:** solves cold-start problem (new users have nil acceptance rate for 5+ outcomes — D1.b gives them a sensible baseline).

### 2.3 D1.c — AI-suggested replacement

**Scope:** when a signal is suppressed, surface an alternative:
- `"protein_below" dismissed 3x → suggest "meal_timing_late" instead`
- Mapping table OR LLM call: Phase 0 decides. Mapping table = pre-computed at engineering time, ~30-50 signal-pair mappings; LLM = runtime, opens latency + cost questions.

**Privacy:** depends on architecture. Mapping table is offline + pre-computed → privacy-safe. LLM call needs banded context only (segment + signal-ID + 3 dismissed peers).
**Effort:** mapping table = ~2 person-days. LLM = ~4 person-days + backend wiring.
**Risk:** medium-high — UX subtlety in "we noticed you don't like X, try Y" copy. Mapping table risks staleness as catalog evolves.
**Dependencies:** C5 reaches `complete`; either signal-pair mapping table OR an LLM gateway (the latter currently doesn't exist in FT2 — would be new infra).

**Why it's attractive:** real differentiator — moves from "we suppress what you don't like" to "we replace it with something better."

### 2.4 D1.d — Suppression transparency UX

**Scope:** new affordance in Settings → AI Feedback → tap a suppressed signal to see:
- Why suppressed: list the 3 dismissals + their dates + reasons (if user picked one)
- Option to un-suppress manually
- Option to "blacklist permanently" (overrides the 30-day rehabilitation window)

**Privacy:** all on-device, already-stored data. Zero new privacy surface.
**Effort:** ~1.5 person-days (Settings screen extension + 1 new analytics event).
**Risk:** low — UX surface extension.
**Dependencies:** C5 reaches `implementation` complete.

**Why it's attractive:** addresses the "trust transparency" concern raised in C5 PRD §"Risks" — gives users mechanical control over what their feedback did.

## 3. Decision matrix

| Sub-feature | Effort | Risk | Privacy | C5-dep depth | Strategic value |
|---|---|---|---|---|---|
| D1.a (time-decay + trend) | 2pd | low | best | shallow | high — closes C5.b out-of-scope |
| D1.b (cohort prior) | 4pd | medium | good | shallow | high — solves cold-start |
| D1.c (replacement) | 2-4pd | med-high | depends | shallow | very high — differentiator |
| D1.d (transparency UX) | 1.5pd | low | best | shallow | medium — trust signal |

**Recommended pairing for v1 D1 ship:** D1.a + D1.d. Together they:
- Stay 100% on-device (privacy-safest)
- Total ~3.5 person-days (matches RICE estimate of ~5 person-days with buffer)
- Pair naturally: D1.a calibrates the loop more sharply; D1.d makes the calibration visible to users
- Don't require backend changes — can ship within FT2 only

**D1.b deferred to v8.0:** waits for `HADF Phase 2-bis` block C backend cohort priors infrastructure to mature.

**D1.c deferred to v8.0+:** mapping-table is too brittle; LLM gateway is new infra deserving its own Phase 0.

## 4. Cross-platform considerations

| Platform | D1.a | D1.b | D1.c | D1.d |
|---|---|---|---|---|
| iOS | yes | client | client | yes |
| Backend | — | yes (cohort_priors table + aggregation job) | yes if LLM | — |
| Privacy review | — | YES — k-anonymity verification | YES if LLM | — |
| GDPR DPIA | — | data-flow update | data-flow update if LLM | — |

D1.a + D1.d shipping in v1 means **no backend touch**, no privacy review, no DPIA delta. Lowest-friction shipping path.

## 5. Success metrics

Per the 2026-04-21 Gemini Tier 2.3 convention.

### For D1.a (time-decay + trend)

| Metric | Tier | Baseline | Target | Window |
|---|---|---|---|---|
| Acceptance-rate sharpness (variance of per-segment rate across users) | T1 | — (baseline from post-C5 30d window) | ≥ 15% increase post-D1.a | 60d |
| Signal un-suppression events (`home_ai_feedback_signal_unsuppressed_by_trend`) | T1 | 0 | ≥ 5 per WAU per 60d | 60d |
| User-reported "AI is improving over time" (qualitative) | T3 | — | ≥ 1 positive operator observation | 60d |

### For D1.d (transparency UX)

| Metric | Tier | Baseline | Target | Window |
|---|---|---|---|---|
| Suppressed-signal-detail-opened events | T1 | 0 | ≥ 0.05 per WAU per 30d | 30d |
| Manual un-suppression rate (un-suppressed / detail-opened) | T1 | — | ≥ 0.10 | 30d |
| Blacklist rate (permanent-blacklist / detail-opened) | T1 | — | ≤ 0.20 (high = overreach) | 30d |

## 6. Kill criteria

- D1.a: variance of per-segment acceptance rate DECREASES post-D1.a (trend detection is making the loop noisier, not sharper)
- D1.d: opt-out rate from Settings → AI Feedback toggle increases vs. pre-D1.d baseline (transparency UX undermined trust instead of building it)
- Either: crash rate on suppressed-signal-detail screen > 0.5%
- Either: regression in C5 metrics (e.g., `home_ai_feedback_submitted` per WAU declines)

## 7. Phase 0 → Phase 1 prerequisites

Phase 0 → Phase 1 (PRD) is gated on operator decision answering:

1. **Sub-feature pick for v1 D1:** recommended D1.a + D1.d. Operator must approve or override.
2. **C5 PR #572 status:** must reach at least `phases.implementation.ended_at` before D1 PRD references C5's API surface.
3. **Phase E status:** PRD authoring CAN start in Phase E. Any new D1 enforcement gates wait for v7.9.1 build window (post 2026-06-04).
4. **No new infra commitment in v1 D1:** D1.a + D1.d stay 100% on-device. Backend / LLM additions deferred.

## 8. Phase 4 scope estimate (assuming D1.a + D1.d)

| Surface | New files | Modified files | LoC est |
|---|---|---|---|
| `RecommendationMemory` time-decay extension | — | `RecommendationMemory.swift` | ~40 |
| Trend-detection helper | `AcceptanceTrendDetector.swift` | — | ~80 |
| `AIOrchestrator` trend-informed un-suppression | — | `AIOrchestrator.swift` | ~30 |
| Suppressed-signal-detail screen | `SuppressedSignalDetailScreen.swift` | — | ~150 |
| Settings → AI Feedback row tap routing | — | `AIFeedbackSettingsScreen.swift` | ~25 |
| AnalyticsService + Provider | — | both | ~40 |
| Tests | 3 new test files | — | ~250 |

**Total estimate:** ~600 LoC (~3.5 person-days). Matches §3 recommendation.

## 9. Phase E discipline

D1 PRD authoring can start in Phase E. **No new gates ship during v7.9 Phase E.** If D1 implements during Phase E (≤2026-06-04), the implementation is added behind an opt-in flag with default OFF, and the enforcement promotion (if any) waits for v7.9.1 build window.

## 10. Out of scope for D1 v1 (explicit guards)

- D1.b cohort-level priors (deferred to v8.0 — waits for HADF Phase 2-bis block C)
- D1.c AI-suggested replacement (deferred to v8.0+ — needs LLM infra Phase 0 separately)
- Cross-platform sync of suppression state (not in C5 scope; D1.d stays on-device-only)
- Server-side aggregation of dismiss-reasons (privacy boundary per C5 PRD)
- Sharing suppression state between accounts (out of solo-mode scope)
- Per-cohort recommendation generation (signal generation stays AI engine's job; D1 only calibrates confidence)

## 11. New analytics events (3 — assuming D1.a + D1.d pair)

| Event | Source | Params |
|---|---|---|
| `home_ai_feedback_signal_unsuppressed_by_trend` | D1.a — AIOrchestrator | `segment`, `signal`, `prior_dismissal_count`, `days_since_last_dismiss` |
| `home_ai_feedback_suppressed_detail_opened` | D1.d — SuppressedSignalDetailScreen | `signal`, `dismissal_count` |
| `home_ai_feedback_signal_manually_unsuppressed` | D1.d — SuppressedSignalDetailScreen | `signal`, `via_trend` (bool) |

(The trend-detection events fire from `AIOrchestrator.refreshRecommendations` when a previously suppressed signal qualifies for un-suppression.)

## 12. Cross-references

- Backlog row: `docs/product/backlog.md` Planned table row 4.5
- Companion C5 (PR #572): closes UI-024 + ships the on-device reinforcement-loop foundation that D1 extends
- C5 PRD §"Enhancements (future C5.b/c/d/e)" — D1.a closes C5.b; D1.d closes C5.e
- HADF Phase 2 (PR #82, shipped 2026-05-01): k=5 clustering, silhouette 0.5566 — backend cohort infra reused IF D1.b ships in v8.0
- 2026-05-31 tier carryover plan §D — "D1 deferred to post-C work (natural pairing with C5)"
