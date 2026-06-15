# Task Breakdown — foundation-models-tier3

PRD: [prd.md](prd.md) · Two phases of one feature. **Phase 1 = Tier 3a (T1–T8)**, **Phase 2 = Tier 3b (T9–T13)**.
Total estimated effort: ~4.5 dev-days. High-risk file: `AIOrchestrator.swift` (extra review in Phase 6).

## Phase 1 — Tier 3a (on-device personalization)

| ID | Title | Type | Skill | Effort | Depends on |
|----|-------|------|-------|--------|-----------|
| T1 | Add optional `summary: String?` to `AIRecommendation` (CodingKeys + explicit init w/ default; carry through `withConfidence`, `localFallback`) | backend | dev | 0.3 | — |
| T2 | Define `@available(iOS 26,*) @Generable struct PersonalizedInsight` (prioritizedSignals `.count(1...5)`, summary `@Guide`, confidence) | backend | dev | 0.2 | T1 |
| T3 | Extract pure `filterToAllowedSignals(_:allowed:)` anti-hallucination helper (testable without SDK) + clamp confidence | backend | dev | 0.3 | T1 |
| T4 | Rewrite `FoundationModelService.adapt()`: `import FoundationModels`, real `LanguageModelSession`, reuse `buildPrivateContext`, map `PersonalizedInsight`→`AIRecommendation` via T3, error→(baseline,0.0); `isAvailable` reads `SystemLanguageModel.default.availability` | backend | dev | 0.7 | T2, T3 |
| T5 | UI: render `summary` headline in `AIRecommendationCard` (+ prefer over `insightSubtitle` in `AIInsightCard`), semantic tokens only | ui | dev | 0.4 | T1 |
| T6 | Analytics: add `home_ai_summary_generated` event (`AnalyticsEvent` case + `AnalyticsService.logAiSummaryGenerated`) + CSV row; emit from orchestrator when summary non-nil | analytics | analytics | 0.3 | T1 |
| T7 | Tests: extend `ConfigurableFoundationModel` mock w/ summary; assert summary surfaces via `process()`; unit-test `filterToAllowedSignals` (AB1–AB3); analytics firing + consent gating test (AB) | test | qa | 0.6 | T4, T5, T6 |
| T8 | Phase-1 verify: `make verify-ios` (build + unit subset) + `make ui-audit` P0=0 + `make tokens-check` | test | qa | 0.3 | T7 |

## Phase 2 — Tier 3b (PCC escalation)

| ID | Title | Type | Skill | Effort | Depends on |
|----|-------|------|-------|--------|-----------|
| T9 | Add `PCCEscalationProtocol` (`escalate(recommendation:snapshot:)`) + `NoOpPCCEscalation` fallback; inject into `AIOrchestrator` + `FitTrackerApp` with `#available` selection | backend | dev | 0.4 | T4 |
| T10 | Live `@available(iOS 26.4,*)` PCC impl: `PrivateCloudComputeLanguageModel` + `LanguageModelSession`, `ContextOptions(reasoningLevel:.light)`, reuse T3 mapping; optional `response.usage` log | backend | dev | 0.6 | T9 |
| T11 | Orchestrator wiring: after Tier 3a, if `escalateToLLM` && post-3a confidence < threshold && PCC available → escalate, `source_tier="pcc"`; failure/offline → keep Tier-3a result | backend | dev | 0.4 | T9 |
| T12 | Backend disposition (comment-only): note `escalate_to_llm` now consumed on-device via PCC in `config.py` + `insight_service.py`; `llm_api_key` formally deprecated. No behavior change | docs | dev | 0.2 | — |
| T13 | Tests: mock `PCCEscalationProtocol`; assert escalation fires only when gated true (AB4) + fallback on throw; Settings PCC note copy task | test | qa | 0.5 | T11 |

## Notes
- **PCC privacy (PRD §7 DECIDED):** T-copy for the Settings → AI note is folded into T13; GDPR-doc update lands in Phase 8.
- **Eval gate:** T7 covers AB1–AB3; T13 covers AB4. Live-model path = manual device verification (recorded in Phase 5).
- **No ai-engine behavior change** → golden set auto-passes (verified in T8/Phase 5).
- Ready set at Phase 4 start: T1 (no deps). big.LITTLE: T1/T2/T3/T6/T12 lightweight; T4/T11 heavyweight (AIOrchestrator/FoundationModelService logic).
