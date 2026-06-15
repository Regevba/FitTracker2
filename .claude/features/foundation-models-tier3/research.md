# Research & Discovery — foundation-models-tier3

**Work type:** Feature · **has_ui:** true · **requires_analytics:** true
**Framework:** v7.10 · **Created:** 2026-06-15
**Approved plan:** `/Users/regevbarak/.claude/plans/curried-exploring-kahn.md`

## 1. What is this solution?

Light up the AI engine's **Tier 3 (on-device personalization)** for real, replacing the
placeholder `FoundationModelService`, and wire the long-dormant `escalate_to_llm`
path to Apple's **Private Cloud Compute (PCC)** language model. Two phases:

- **Phase 1 (Tier 3a):** real on-device `LanguageModelSession` personalization producing a
  typed `@Generable` result — curated/re-prioritized signals + a short natural-language
  coaching `summary` + confidence.
- **Phase 2 (Tier 3b):** when `escalateToLLM` is true and confidence stays low, run an
  on-device `PrivateCloudComputeLanguageModel` session (reasoning-capable, 32K ctx).

## 2. Why this approach?

Tier 3 is a **stub today**: `FoundationModelService.adapt()` carries a `#warning`, never
imports `FoundationModels`, and returns a hardcoded `confidence = 0.5`
([FoundationModelService.swift:88-91](../../../FitTracker/AI/FoundationModelService.swift#L88-L91)).
The comment says "until iOS 26 SDK ships" — but iOS 26 shipped ~Sept 2025, and the WWDC26
(2026-06-09) expansion went further. **The stub is ~1 year behind its own assumption.**

Separately, `escalate_to_llm` is plumbed end-to-end
([insight_service.py:57](../../../ai-engine/app/services/insight_service.py#L57) →
[AITypes.swift:99](../../../FitTracker/AI/AITypes.swift#L99)) but does nothing — it was
blocked on "DPA + provider + cost budget" ([config.py:14-15](../../../ai-engine/app/config.py#L14-L15)).

**User pain addressed:** AI insights are currently population-level signal strings only; there
is no personalized, plain-language coaching layer despite the architecture being built for it.

## 3. Why this over alternatives?

| Approach | Pros | Cons | Effort | Chosen? |
|---|---|---|---|---|
| **On-device FM (Tier 3a) + PCC escalation (Tier 3b)** | Free (PCC <2M dl), no API key, no DPA, no prompt storage; fits privacy posture; uses existing protocol seam | Device-only live path; non-deterministic output | M | **✅** |
| Server-side LLM (Claude/Gemini via backend) | Frontier quality | Needs DPA + API key + cost budget; PCC unreachable from Railway Linux backend; keeps the existing blocker | M-L | ❌ |
| Third-party on-device (`AnthropicLanguageModel`) | Frontier quality, same Swift API | Per-token billed, OAuth + Keychain, DPA still required | M | ❌ |
| Leave stub as-is | Zero work | Tier 3 stays dead; escalation stays dead | — | ❌ |

Decisions confirmed with operator 2026-06-15: **Hybrid `@Generable`** output · **On-device PCC**
escalation · **one feature, Tier 3a then Tier 3b**.

## 4. External sources (WWDC research, 2026-06-15)

- [What's new in the Foundation Models framework — WWDC26](https://developer.apple.com/videos/play/wwdc2026/241/) — PCC model, reasoning, vision input, third-party providers, Dynamic Profiles, `model.contextSize`/`tokenCount`, Evaluations framework.
- [Meet the Foundation Models framework — WWDC25](https://developer.apple.com/videos/play/wwdc2025/286/) — `LanguageModelSession`, guided generation (`@Generable`/`@Guide`), streaming, tool calling.
- [MacRumors — 2026 Platforms SOTU](https://www.macrumors.com/2026/06/09/apple-outlines-major-ai-and-developer-tool-updates/) — free PCC under 2M downloads; swap providers without code changes; open-source plan.
- [Exploring the Foundation Models framework — Create with Swift](https://www.createwithswift.com/exploring-the-foundation-models-framework/) — exact availability/`respond`/`@Generable` API surface.

**Confirmed API surface:** `import FoundationModels`; `SystemLanguageModel.default.availability` →
`.available`/`.unavailable(reason)`; `LanguageModelSession(model:guardrails:tools:instructions:)`;
`respond(to:generating:includeSchemaInPrompt:options:)`; `@Generable`/`@Guide(.count/.anyOf/description)`;
PCC via `PrivateCloudComputeLanguageModel()` + `ContextOptions(reasoningLevel: .light/.deep)`.

## 5. Market examples

On-device LLM personalization is the WWDC25/26 reference pattern; Apple's own apps (Notes
summarization, Messages, Photos memories) use the same `SystemLanguageModel`/PCC split.
FitMe's federated **cohort** layer (k-anonymity population stats) is a differentiator the FM
framework does NOT provide — they are complementary, not redundant.

## 6. UI

New surface: a natural-language `summary` headline on the AI recommendation cards
([AIRecommendationCard.swift](../../../FitTracker/Views/AI/AIRecommendationCard.swift),
[AIInsightCard.swift](../../../FitTracker/Views/AI/AIInsightCard.swift)). Rendered only when
non-nil; existing signal-string body is retained beneath it. Semantic tokens only (keeps
`make ui-audit` P0=0). Full spec produced in Phase 3.

## 7. Data & demand signals

- The architecture was pre-built for Tier 3 (protocol seam, `escalateToLLM` boolean, `buildPrivateContext`) — strong internal signal the capability was always intended.
- HADF Phase 3A T5a already emits `logAiInferenceCompleted(sourceTier:)` — the `on_device`/`pcc` tiers will finally produce real telemetry instead of always `cloud`/`local_fallback`.

## 8. Technical feasibility

- ✅ **Verified 2026-06-15:** Xcode 26.5 / iOS 26.5 SDK present; `FoundationModels.framework` is in the SDK → both Tier 3a (iOS 26) and Tier 3b PCC (iOS 26.4+) can compile and be exercised here.
- Deployment target stays `IPHONEOS_DEPLOYMENT_TARGET = 17.0`; all new code is `@available`-gated.
- **Risks:** non-deterministic output (mitigated by `@Generable` typed contract + signal-intersection anti-hallucination filter); device-only live path (unit tests use protocol mocks); **PCC privacy surface** (escalation context leaves the device to Apple PCC — must be documented in PRD/GDPR); confirm PCC entitlement at build time.

## 9. Proposed success metrics (drafted; finalized in PRD)

- **Primary:** Tier-3 adoption — % of AI insight refreshes whose terminal `source_tier ∈ {on_device, pcc}` (baseline 0%, target ≥ 60% on capable devices).
- **Secondary:** on-device inference p50 latency; summary-present rate; AI insight tap-through rate (does the coaching summary increase engagement).
- **Guardrails:** crash-free > 99.5%; no regression in cloud/local fallback; `make ui-audit` P0=0; ai-engine golden-set unaffected.
- **Kill criteria:** drafted in PRD (e.g., on-device p50 latency exceeds budget, or summary quality fails manual eval).

## 10. Decision

**Recommended:** proceed with the two-phase on-device + PCC approach (Hybrid `@Generable`).
Route through the full Feature lifecycle (AIOrchestrator.swift is a high-risk file). This is an
**AI-touching feature** → the eval-coverage gate applies; the deterministic ai-engine golden
set is unaffected (no backend behavior change), and on-device generative output is bounded by
the typed contract + signal filter (Apple's new Evaluations framework noted as a future tool).
