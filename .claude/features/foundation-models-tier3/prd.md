# PRD — foundation-models-tier3

**Status:** draft (Phase 1) · **Work type:** Feature · **has_ui:** true · **requires_analytics:** true
**Framework:** v7.10 · **Author:** Claude (Opus 4.8) + operator · **Date:** 2026-06-15
**Research:** [research.md](research.md) · **Approved plan:** `/Users/regevbarak/.claude/plans/curried-exploring-kahn.md`

## 1. Problem

The AI engine's **Tier 3 (on-device personalization)** is a placeholder: `FoundationModelService.adapt()`
returns a hardcoded `confidence = 0.5` and never calls Apple's Foundation Models. Separately, the
`escalate_to_llm` path is plumbed end-to-end but inert — blocked on a DPA/provider/cost decision that
WWDC26's free, key-less **Private Cloud Compute** model now removes. Users see population-level signal
strings only; there is no personalized, plain-language coaching layer the architecture was built to deliver.

## 2. Goals / Non-goals

**Goals**
- G1 — Replace the Tier-3 stub with a real on-device `LanguageModelSession` producing a typed `@Generable`
  result: curated/re-prioritized signals + a short natural-language `summary` + confidence (Tier 3a).
- G2 — Wire `escalateToLLM` to an on-device `PrivateCloudComputeLanguageModel` session when on-device
  confidence stays below threshold (Tier 3b).
- G3 — Surface the `summary` in the AI recommendation cards; emit honest telemetry for the new tiers.

**Non-goals**
- Server-side LLM calls / third-party providers (Claude/Gemini) — explicitly rejected (keeps DPA blocker).
- Vision/multimodal input, Dynamic Profiles, tool-calling — future candidates, out of scope.
- Per-platform coverage percentages, Apple Evaluations-framework integration — noted as follow-ups.
- Any change to the deterministic ai-engine rule engine or its golden set.

## 3. Scope (two phases of one feature)

- **Phase 1 (Tier 3a):** `summary` field on `AIRecommendation`; `@Generable PersonalizedInsight`;
  real `FoundationModelService.adapt()`; anti-hallucination signal filter; card UI; `aiSummaryGenerated`
  analytics; protocol-mock tests.
- **Phase 2 (Tier 3b):** `PCCEscalationProtocol` + live `PrivateCloudComputeLanguageModel` impl;
  orchestrator wiring gated on `escalateToLLM` + low confidence + availability; backend comment-only
  disposition; tests.

## 4. AI Behaviors (eval-coverage gate — AI-touching feature)

| ID | Behavior | Eval coverage (min) |
|---|---|---|
| AB1 | On-device personalization: baseline → curated signals + summary + confidence | 3 golden I/O (mock model) + 2 quality heuristics + 1 edge (empty signals) |
| AB2 | Anti-hallucination filter: only signals in the allowed set survive | 3 golden I/O (incl. injected fake signal) + 1 edge (all-hallucinated → baseline) |
| AB3 | Tier selection: on_device used only when confidence ≥ threshold; else baseline | 3 golden I/O (above/below/at 0.4) |
| AB4 | PCC escalation fires only when escalateToLLM true + low confidence + available | 3 golden I/O + 1 edge (PCC throws → fall back to Tier 3a) |

The **live model** path (real `SystemLanguageModel` / PCC) is device-only → manual verification, not XCTest.
The deterministic ai-engine golden set is **unaffected** (no backend behavior change) and auto-passes its gate.
Apple's Evaluations framework is the proper future tool for live generative-quality measurement (out of scope).

## 5. Success Metrics

**Primary**
- Tier-3 adoption rate = % of AI insight refreshes whose terminal `source_tier ∈ {on_device, pcc}`.
  - Baseline: **0%** (stub never qualifies; orchestrator keeps baseline at confidence 0.5 < 0.4? — see note).
  - Target: **≥ 60%** of refreshes on Apple-Intelligence-capable devices within 30 days.
  - Source: T1 (instrumented) via `logAiInferenceCompleted(source_tier:)`.

> Note: today the stub returns 0.5 ≥ 0.4 so it technically marks `on_device`, but the output is a fixed
> rule-tweak, not model output — i.e. the metric is currently *vacuous*. Real Tier 3a makes it meaningful.
> Baseline is therefore "0% real on-device personalization."

**Secondary (2–3)**
- On-device inference p50 latency (ms) — T1 via `duration_ms`.
- Summary-present rate = % of `on_device`/`pcc` refreshes that produced a non-nil `summary` — T1 via `aiSummaryGenerated`.
- AI insight tap-through rate (`home_ai_insight_tap` / `home_ai_insight_shown`) — does the summary lift engagement — T1.

**Guardrails (must not degrade)**
- Crash-free rate > 99.5%; cold start < 2s.
- Cloud/local fallback path unchanged (no new failure when model unavailable/offline).
- `make ui-audit` P0 = 0; `make tokens-check` green.
- ai-engine golden-set + segment tests still pass.

**Leading indicators (≤ 1 week):** `source_tier` distribution shifts toward `on_device`; summary-present rate > 0.
**Lagging (30/60/90d):** AI insight tap-through lift; retention of AI-sheet openers.

**Instrumentation plan:** reuse `logAiInferenceCompleted`; add `logAiSummaryGenerated`. No backend metrics
(server-side TTFT/TPS is T5b, out of scope). Baselines recorded at Phase 5.

**Review cadence:** first review **2026-06-29** (T+14d after merge), then 30/60/90d.

**Kill criteria**
- KC1 — On-device inference p50 latency > **3000 ms** on a capable device (worse than a cloud round-trip) → revert Tier 3a to baseline-keeping.
- KC2 — Summary manual-eval quality (sample of 20) shows > 20% with medical claims / hallucinated metrics that bypass the filter → disable summary surfacing.
- KC3 — Crash-free drops below 99.5% attributable to FM calls → revert.
- **kill_criteria_resolution** to be recorded at closure (required by FEATURE_CLOSURE_COMPLETENESS gate).

## 6. Analytics Spec (GA4) — requires_analytics = true

**New event (1):**

| Event | Category | GA4 type | Trigger | Parameters | Conversion |
|---|---|---|---|---|---|
| `ai_summary_generated` | ai | custom | Global (AI pipeline — orchestrator) | `segment`, `source_tier`, `duration_ms` | no |

**Scope correction (impl):** the event is **global, unprefixed** — it mirrors its sibling
`ai_inference_completed`, which fires from `AIOrchestrator` (not a screen interaction). Per CLAUDE.md the
screen-prefix rule covers *screen interactions*; cross-screen pipeline events stay global. The earlier
draft name `home_ai_summary_generated` was wrong and is superseded.

**New parameters:** none — reuses existing `segment`, `source_tier`, `duration_ms` (all in `AnalyticsParam`).
**New screens:** none. **New user properties:** none.

**Naming Validation Checklist**
- [x] snake_case, lowercase — `ai_summary_generated`
- [x] ≤ 40 chars (20)
- [x] global/unprefixed — correct for an orchestrator-fired pipeline event (matches `ai_inference_completed`); screen-prefix rule N/A
- [x] no reserved prefix (`ga_`/`firebase_`/`google_`)
- [x] no duplicate vs existing `AnalyticsEvent`
- [x] no PII in any parameter
- [x] param values ≤ 100 chars; ≤ 25 params/event
- [x] total custom user properties unchanged (≤ 25); CSV row added at `analytics-taxonomy.csv`

`analytics_spec_complete` → set true on PRD approval.

## 7. PCC Privacy-Surface Disposition (decision needed at approval)

Tier 3a keeps PII fully on-device (matches current posture). **Tier 3b sends the personalization context to
Apple's Private Cloud Compute** — Apple does not store prompts, but the data *leaves the device*. This is a
genuine change from "PII never leaves the device" for the escalation case.

Required regardless: PRD + `docs/` GDPR note documenting the PCC data flow.

**DECIDED (operator, 2026-06-15): Document + settings note.** A GDPR/privacy doc describes the PCC data
flow and a one-line note is added in Settings → AI. **No separate consent gate** — Tier 3b inherits the
device's Apple Intelligence setting (PCC is on-by-default with Apple Intelligence and stores no prompts).
This becomes a Phase 2 task (docs/settings copy) and a Phase 8 GDPR-doc update; it is NOT a consent-plumbing task.

## 8. Rollout / reversibility

- All new code `@available`-gated (iOS 26 for Tier 3a, 26.4 for Tier 3b PCC); deployment target stays 17.0.
- Feature is additive behind the existing `FoundationModelProtocol` seam; reverting = inject `FallbackFoundationModel` / `NoOpPCCEscalation`.
- Tier 3b gated on `escalateToLLM` → bounded blast radius.

## 9. Risks

Non-determinism (mitigated by `@Generable` + signal filter); device-only live verification; PCC entitlement
(confirm at build); summary quality (KC2 + manual eval). See research.md §8.

## 10. SDK-gap finding (added 2026-06-15, during Phase 4)

**The WWDC26 Private Cloud Compute API is not in the shipping iOS 26.5 SDK.** Verified against
`FoundationModels.swiftinterface` (Xcode 26.5): the framework exposes only `SystemLanguageModel`
(+ `LanguageModelSession`, `@Generable`, `respond(to:generating:options:)`, `UseCase`). There is
**no** `PrivateCloudComputeLanguageModel`, `ContextOptions`, `reasoningLevel`, or `LanguageModel`
provider protocol — the WWDC26 (2026-06-09) press coverage these were sourced from describes
announced features not present in this SDK seed.

**Impact + disposition:**
- **Tier 3a (on-device, `SystemLanguageModel`)** — real, shipped, 23 tests green (commit `2068044`). Unaffected.
- **Tier 3b (PCC)** — the full architecture ships (protocol seam, `NoOpPCCEscalation`, orchestrator
  gating, FitTrackerApp injection, 4 mock-based tests, all green). The **live PCC call is gated behind
  the `FOUNDATION_MODELS_PCC` compile flag (undefined → excluded)**; the service no-ops at runtime
  (`escalateToLLM` stays inert, no behavior change vs. pre-feature) until the SDK exposes the symbols.
  Flipping the flag activates the real path with no other code change.
- **Primary metric correction:** until the flag is enabled, terminal `source_tier` can be
  `on_device` (Tier 3a) but never `pcc`. The 60% Tier-3 adoption target is carried by Tier 3a alone
  for now; `pcc` contribution is 0 by construction.
- **Lesson (process):** Phase-0 feasibility confirmed the framework existed but not that the specific
  symbols did. Forward rule: grep the actual `.swiftinterface` for required symbols before asserting
  an API is buildable — don't rely on release-announcement coverage.
