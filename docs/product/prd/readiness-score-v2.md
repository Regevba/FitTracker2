# PRD: Readiness Score v2 (Feature)

> **ID:** readiness-score-v2 | **Status:** Shipped | **Priority:** P1
> **Parent:** 18.3 Recovery & Biometrics (shipped) | **Sibling formula PRD:** [`readiness-score-formula-v2.md`](./readiness-score-formula-v2.md)
> **Work Type:** Enhancement (4-phase: Tasks → Implement → Test → Merge) | **GitHub Issue:** #71 (FIT-34)
> **State tracking:** [`.claude/features/readiness-score-v2/state.json`](../../../.claude/features/readiness-score-v2/state.json) (current_phase: complete)
> **Last Updated:** 2026-04-26

---

## Purpose

Ship the evidence-based, goal-aware Readiness Score formula as a usable feature on the Home / Today screen. This PRD describes the **feature deliverable** (the user-facing surface, the `ReadinessEngine` service, the analytics events, and the test coverage). The scientific foundation — formula derivation, weighting choices, citations, and alternatives considered — lives in the sibling formula PRD: [`readiness-score-formula-v2.md`](./readiness-score-formula-v2.md). This document does not duplicate that content; it cross-references it.

## Business Objective

Replace the v1 readiness score (40% HRV + 30% RHR + 30% sleep) with a 5-component, goal-aware score that the AI engine, the Home recommendation provider, and the user can all reason about. Net effect: less generic "go/no-go" guidance; richer "what type of training, at what intensity, why" output.

## Scope of the Feature (vs the Formula PRD)

| In scope (this PRD) | Out of scope (covered by formula PRD) |
|---|---|
| The user-facing `ReadinessCard` component breakdown | Why each component carries its specific weight |
| `ReadinessEngine.compute()` API surface | Literature review and citation set (20+ refs) |
| Analytics events (`home_readiness_*`) | Commercial system comparison (WHOOP / Oura / Polar / Garmin) |
| Test coverage (`ReadinessEngineTests`) | Honest limitations of the underlying evidence |
| Backward-compatibility shim in `EncryptionService` | Goal-specific weight derivation rationale |

## What Shipped (PR #78, merged 2026-04-10, commit context: post-merge fixes 9069c45 → 52a5d06)

### Code

| File | Action |
|------|--------|
| `FitTracker/Services/ReadinessEngine.swift` | New — pure-function 5-component engine |
| `FitTracker/Models/DomainModels.swift` | Added `ReadinessResult`, `ReadinessConfidence`, `BodyCompFlag`, `TrainingRecommendation` |
| `FitTracker/Services/Encryption/EncryptionService.swift` | Modified (high-risk file) — `readinessScore(for:fallbackMetrics:)` delegates to ReadinessEngine; signature preserved for backward compatibility |
| `FitTracker/Views/Shared/ReadinessCard.swift` | Modified — 5-component mini-bars + confidence badge + info popover |
| `FitTracker/Services/HomeRecommendationProvider.swift` | Modified — consumes `TrainingRecommendation` enum |
| `FitTrackerTests/ReadinessEngineTests.swift` | New — 20 tests (9 original + 11 regression for C1-C4 + H1) |

### Five components shipped
1. **HRV** (35% base) — `ln(SDNN)` deviation from 7-day EWMA
2. **Sleep Quality** (25% base) — composite duration + deep% + REM%
3. **Training Load / ACWR** (20% base) — EWMA acute:chronic via session RPE
4. **Resting HR** (15% base) — deviation from 7-day rolling average
5. **Body Composition** (5% base) — binary suppressors (overnight weight, visceral fat trend)

Goal modes: `general`, `fatLoss`, `muscleGain`, `maintain` — each with its own weight vector.

### Analytics events instrumented

| Event | Trigger |
|-------|---------|
| `home_readiness_score_computed` | Readiness score computed on home load |
| `home_readiness_component_tap` | User taps a component mini-bar |
| `home_readiness_recommendation_shown` | Recommendation displayed |

## Success Metrics

| Metric | Baseline | Target | Instrumentation |
|--------|----------|--------|-----------------|
| Readiness score correlation with self-reported energy | N/A — pre-launch (T2 — Declared, 2026-04-26) | r > 0.6 (T2 — Declared) | In-app feedback prompt (future) |
| Component breakdown views per readiness card view | 0% (T2 — Declared, 2026-04-26) | >30% (T2 — Declared) | `home_readiness_component_tap` event |
| Training recommendation adherence ("rest day" followed) | N/A — pre-launch (T2 — Declared, 2026-04-26) | >60% (T2 — Declared) | Cross-ref readiness + training log |
| Crash-free rate (guardrail) | >99.5% (T1 — Instrumented, Sentry) | >99.5% (T1) | Sentry |
| Cold start time (guardrail) | <2s (T1 — Instrumented) | <2s (T1) | App launch timer |
| Home screen load time (guardrail) | <500ms (T2 — Declared, 2026-04-26) | <500ms (T2 — Declared) | Performance profiler |
| Kill criteria | Self-reported readiness correlation goes negative OR user override rate >80% sustained 30 days OR readiness computation adds >100ms to home screen load sustained 14 days → revert to v1 simple formula and disable component breakdown UI (T2 — Declared, 2026-04-26) | — | Adherence telemetry + perf timers |

## Cross-References

- **Scientific foundation (the why):** [`docs/product/prd/readiness-score-formula-v2.md`](./readiness-score-formula-v2.md)
- **Parent feature initiative:** [`docs/product/prd/adaptive-intelligence-initiative.md`](./adaptive-intelligence-initiative.md)
- **Downstream consumer:** [`docs/product/prd/ai-engine-v2.md`](./ai-engine-v2.md) (AIOrchestrator now consumes `ReadinessResult`)
- **State tracking:** [`.claude/features/readiness-score-v2/state.json`](../../../.claude/features/readiness-score-v2/state.json)
- **GitHub:** issue #71, FIT-34, PR #78

## Status Note (2026-04-26)

This standalone feature PRD was created on 2026-04-26 to satisfy CLAUDE.md non-negotiable rule #2 ("No PRD without success metrics"). The work itself shipped on 2026-04-10 (PR #78) — the gap was strictly documentation: there was a formula PRD and a feature state.json, but no feature-level PRD pointing at them. This document closes that loop. Tagged T2 — Declared throughout where metrics are author-asserted (not pulled from a deterministic source).
