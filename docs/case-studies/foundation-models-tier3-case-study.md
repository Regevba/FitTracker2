---
title: "foundation-models-tier3 — real on-device Apple Foundation Models for AI Tier 3, with an SDK-gated PCC escalation path"
date: 2026-06-15
date_written: 2026-06-18
framework_version: v7.10
work_type: feature
dispatch_pattern: single-agent-serial
primary_metric: "Tier-3 adoption rate = % of AI insight refreshes whose terminal source_tier ∈ {on_device, pcc}; baseline 0% (real on-device personalization) → target ≥60% on Apple-Intelligence-capable devices within 30 days"
success_metrics:
  - "Primary (T1 instrumented via logAiInferenceCompleted(source_tier:)): real on-device personalization replaces the confidence=0.5 stub; baseline 0% real → ≥60% target on capable devices @ 30d (measured at first review 2026-06-29)"
  - "Secondary (T1): on-device inference p50 latency (duration_ms); summary-present rate (aiSummaryGenerated non-nil); AI-insight tap-through lift (home_ai_insight_tap / home_ai_insight_shown)"
  - "Engineering (T1 measured at ship): 27/27 unit tests pass incl. AB1–AB3 eval coverage (golden I/O + anti-hallucination filter + tier-selection); make ui-audit P0=0; tokens-check green; ai-engine golden set unaffected"
kill_criteria: "KC1 — on-device inference p50 latency > 3000 ms on a capable device → revert Tier 3a to baseline-keeping. KC2 — manual quality eval (sample 20) shows >20% summaries with medical claims / hallucinated metrics bypassing the filter → disable summary surfacing. KC3 — crash-free rate < 99.5% attributable to Foundation Models calls → revert."
kill_criteria_resolution: "Post-launch criteria evaluated at the first metrics review 2026-06-29 (T+14d) then 30/60/90d. As of closure NONE have fired: Tier 3a is on-device-only (no network round-trip), 27/27 unit tests pass incl. AB1–AB3 anti-hallucination/tier-selection eval coverage, and ui-audit P0=0. Tier 3b (Private Cloud Compute) live path is flag-gated OFF (FOUNDATION_MODELS_PCC) because the WWDC26 PCC API is absent from the iOS 26.5 SDK — it no-ops until the SDK ships and therefore cannot trip a kill criterion. Disposition: kept; metrics review continues on cadence."
tier_tags_present: true
platforms_tested:
  ios: true
  web: false
  backend: false
  ai: true
related_prs:
  - 724
  - 725
pr_citation_exempt:
  - pr_number: 725
    reason: "ai-engine README documentation PR — companion to code PR #724; not the feature's merge PR, so it is not recorded in phases.merge.pr_number"
---

# foundation-models-tier3 — on-device Foundation Models for AI Tier 3

> **One-line:** Replaced the AI engine's Tier-3 on-device personalization stub
> (a hardcoded `confidence = 0.5` that never called a model) with a real
> `LanguageModelSession` producing a typed `@Generable` result, and built the
> Tier 3b Private Cloud Compute escalation path as flag-gated architecture that
> no-ops until the WWDC26 PCC API ships in a future SDK.

## Context

The AI engine ships a deterministic `InsightService` rule engine (population-level
signal strings). The architecture always reserved **Tier 3** for on-device
personalization and an `escalate_to_llm` path for harder cases — but both were
inert: Tier 3 was a stub, and the escalation path was blocked on a
DPA/provider/cost decision. WWDC26's free, key-less **Private Cloud Compute**
model removes the escalation blocker; Apple's on-device **Foundation Models**
(`LanguageModelSession` + `@Generable`) make Tier 3a buildable with zero key and
zero network.

## What shipped (PR #724 — code; PR #725 — ai-engine README)

**Tier 3a (live, on-device):**
- `FoundationModelService.adapt()` now opens a real on-device `LanguageModelSession`
  and returns a typed `@Generable PersonalizedInsight`: curated/re-prioritized
  signals + a short natural-language `summary` + a confidence value.
- **Anti-hallucination signal filter** — only signals in the allowed set survive;
  an injected fake signal is dropped, an all-hallucinated result falls back to
  baseline (AB2 eval coverage).
- **Tier selection** — `on_device` is used only when confidence ≥ threshold (0.4),
  else baseline (AB3 eval coverage).
- `summary` surfaced in the AI recommendation cards; `ai_summary_generated`
  analytics (`segment`, `source_tier`, `duration_ms`).

**Tier 3b (architecture, flag-gated OFF):**
- `PCCEscalationService` + `PCCEscalationProtocol`; orchestrator wiring gated on
  `escalateToLLM` + low on-device confidence + availability.
- Live `PrivateCloudComputeLanguageModel` path is behind `FOUNDATION_MODELS_PCC`
  (default **off**). **Empirical limitation:** the WWDC26 PCC API is **absent
  from the iOS 26.5 SDK** — verified by grepping the `.swiftinterface`. The path
  compiles (build-safety `@available`-gated) but no-ops until the SDK ships.

All new code is `@available`-gated (iOS 26 for Tier 3a, 26.4 for Tier 3b);
deployment target stays 17.0, so non-capable devices keep the existing baseline
path unchanged.

## Outcome

| Dimension | Before | After |
|---|---|---|
| Tier-3 on-device path | stub (`confidence = 0.5`, no model) — metric vacuous | real `LanguageModelSession` → `@Generable` summary + confidence |
| `escalate_to_llm` | plumbed but inert (DPA-blocked) | PCC architecture in place, flag-gated, SDK-pending |
| Unit tests | — | **27/27 pass** incl. AB1–AB3 eval coverage (T1) |
| `make ui-audit` | — | **P0 = 0** (T1) |
| Primary adoption metric | 0% real on-device | first review **2026-06-29** (T+14d), then 30/60/90d |

## Lessons

1. **Grep the `.swiftinterface` before asserting an API is buildable.** The PCC
   live path was designed against the WWDC26 announcement; the API isn't in the
   26.5 SDK. Flag-gating the live path (rather than blocking the whole feature on
   it) let Tier 3a ship real value now while Tier 3b waits for the SDK — a clean
   split that keeps the build green and the kill criteria un-trippable for the
   gated half.
2. **A "working" metric can be vacuous.** The old stub technically marked
   `source_tier = on_device` (0.5 ≥ 0.4) — so the adoption metric read >0% while
   delivering zero real personalization. The honest baseline is "0% *real*
   on-device personalization," recorded as such.

## Provenance

- **Code:** PR #724 (`feat: on-device Foundation Models Tier 3a + PCC escalation, flag-gated`), merged 2026-06-15.
- **Docs:** PR #725 (ai-engine README — document on-device Tier 3), merged 2026-06-15.
- **Closure:** this case study + state.json reconciliation (the code landed via #724 before the testing/review/docs phases were recorded — closed here per `FEATURE_CLOSURE_COMPLETENESS`).
- **Tracker:** Linear FIT-198.
- **Follow-ups:** fitme-story showcase MDX (publication rule); first metrics review 2026-06-29; Tier 3b live-path enablement when the PCC SDK ships.
