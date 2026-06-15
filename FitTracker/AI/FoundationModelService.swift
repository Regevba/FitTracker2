// AI/FoundationModelService.swift
// On-device personalisation layer using Apple Foundation Models (iOS 26+).
// Protocol-driven for testability — inject FoundationModelProtocol in XCTest.
// FallbackFoundationModel handles pre-iOS 26 devices by returning confidence 0,
// which means AIOrchestrator keeps the unpersonalised baseline recommendation.
//
// foundation-models-tier3 (Tier 3a): adapt() now drives the real on-device
// LanguageModelSession with guided generation (@Generable PersonalizedInsight),
// producing a curated signal list + a natural-language coaching summary. The
// `#if canImport(FoundationModels)` guard keeps the build green on toolchains
// without the framework (matches the project's #if canImport(Figma) convention).

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// ─────────────────────────────────────────────────────────
// MARK: – Protocol (testability seam)
// ─────────────────────────────────────────────────────────

/// Abstraction over Apple Foundation Models for on-device inference.
/// Conforming types must be Sendable for safe use across Swift concurrency.
public protocol FoundationModelProtocol: Sendable {
    /// Run on-device inference with the given prompt context.
    /// - Returns: (adaptedRecommendation, confidence) where confidence ∈ [0, 1].
    ///            confidence below `personalisationThreshold` (0.4) signals that the
    ///            adapted result should NOT be preferred — `AIOrchestrator` keeps the
    ///            baseline cloud/local recommendation instead. (Foundation Model is
    ///            Tier 3 — post-cloud personalisation, not a cloud fallback.)
    func adapt(
        recommendation: AIRecommendation,
        snapshot: LocalUserSnapshot
    ) async throws -> (recommendation: AIRecommendation, confidence: Double)

    /// Whether the Foundation Models framework is available on this device.
    var isAvailable: Bool { get }
}

// ─────────────────────────────────────────────────────────
// MARK: – Tier-3 signal filter (SDK-independent, unit-testable)
// ─────────────────────────────────────────────────────────

/// Anti-hallucination guard for on-device output. The generative model may
/// return signal strings that aren't part of the known vocabulary; downstream
/// UI/analytics/feedback all key off signal strings, so we keep ONLY signals
/// that already exist in the allowed set (baseline ∪ known local vocabulary).
/// This type has NO availability gate so it can be unit-tested without the
/// Foundation Models SDK (covers AB2/AB3 in the PRD eval plan).
public enum Tier3SignalFilter {

    /// The local-enrichment signals `adapt()` is allowed to introduce on top of
    /// the baseline (mirrors the deterministic `applyLocalAdjustments` vocabulary).
    public static let knownLocalVocabulary: Set<String> = [
        "local_sleep_deprivation_deload_advised",
        "local_high_stress_reduce_volume",
        "local_elevated_rhr_monitor_recovery",
        "readiness_critical_low",
        "hydration_warning_active",
    ]

    /// Keep only proposed signals present in `allowed`, preserving order and
    /// dropping duplicates. Returns the baseline signals unchanged if the filter
    /// would otherwise empty the list (never surface a signal-less recommendation).
    public static func filterToAllowedSignals(
        _ proposed: [String],
        allowed: Set<String>,
        baseline: [String]
    ) -> [String] {
        var seen = Set<String>()
        let kept = proposed.filter { allowed.contains($0) && seen.insert($0).inserted }
        return kept.isEmpty ? baseline : kept
    }

    /// Clamp a model-reported confidence into the valid [0, 1] range.
    public static func clampConfidence(_ value: Double) -> Double {
        guard value.isFinite else { return 0.0 }
        return min(max(value, 0.0), 1.0)
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – FallbackFoundationModel (pre-iOS 26 / unavailable)
// ─────────────────────────────────────────────────────────

/// Used on devices where Apple Foundation Models is unavailable (pre-iOS 26).
/// Returns confidence = 0.0, which causes AIOrchestrator to keep the
/// baseline recommendation without additional personalisation.
public struct FallbackFoundationModel: FoundationModelProtocol {
    public var isAvailable: Bool { false }

    public init() {}

    public func adapt(
        recommendation: AIRecommendation,
        snapshot: LocalUserSnapshot
    ) async throws -> (recommendation: AIRecommendation, confidence: Double) {
        // Confidence 0 → orchestrator keeps unpersonalised baseRecommendation
        // (Foundation Model is post-cloud Tier 3, not a cloud fallback path.)
        return (recommendation, 0.0)
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – PersonalizedInsight (guided-generation output, iOS 26+)
// ─────────────────────────────────────────────────────────

#if canImport(FoundationModels)
/// Typed output of the on-device model. Guided generation forces the model to
/// fill this struct rather than return free text, so the contract is stable.
@available(iOS 26, *)
@Generable
struct PersonalizedInsight {
    @Guide(description: "1 to 5 of the most relevant signal keys, most important first")
    let prioritizedSignals: [String]

    @Guide(description: "A second-person coaching note under 160 characters. Encouraging, never judgmental. No medical claims, no diagnoses, no numeric health metrics.")
    let summary: String

    @Guide(description: "Confidence from 0.0 to 1.0 that this personalisation is well-supported by the user's data")
    let confidence: Double
}
#endif

// ─────────────────────────────────────────────────────────
// MARK: – Live Foundation Models service (iOS 26+)
// ─────────────────────────────────────────────────────────

/// Live on-device inference using Apple Foundation Models.
/// Only available on iOS 26+ — the build target gates this with
/// #available checks in AIOrchestrator. On earlier OS versions
/// AIOrchestrator injects FallbackFoundationModel instead.
@available(iOS 26, *)
public final class FoundationModelService: FoundationModelProtocol {

    public init() {}

    /// Reflects the live model state. When the framework can't be imported, or
    /// the system model isn't ready (device ineligible, Apple Intelligence off,
    /// model downloading), this is false and AIOrchestrator keeps the baseline.
    public var isAvailable: Bool {
        #if canImport(FoundationModels)
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
        #else
        return false
        #endif
    }

    public func adapt(
        recommendation: AIRecommendation,
        snapshot: LocalUserSnapshot
    ) async throws -> (recommendation: AIRecommendation, confidence: Double) {
        #if canImport(FoundationModels)
        guard isAvailable else { return (recommendation, 0.0) }

        // The full biometric payload is inlined into the prompt for the
        // on-device engine ONLY — it never leaves the device. Shared builder
        // (Tier3PromptContext) is reused by the Tier-3b PCC path.
        let context = Tier3PromptContext.build(snapshot: snapshot, recommendation: recommendation)
        let allowed = Set(recommendation.signals).union(Tier3SignalFilter.knownLocalVocabulary)

        do {
            let session = LanguageModelSession(instructions: { Self.instructions })
            let response = try await session.respond(
                to: context,
                generating: PersonalizedInsight.self,
                options: GenerationOptions(temperature: 0.3)
            )
            let insight = response.content

            let signals = Tier3SignalFilter.filterToAllowedSignals(
                insight.prioritizedSignals,
                allowed: allowed,
                baseline: recommendation.signals
            )
            let trimmedSummary = insight.summary.trimmingCharacters(in: .whitespacesAndNewlines)
            let adapted = AIRecommendation(
                segment:        recommendation.segment,
                signals:        signals,
                confidence:     recommendation.confidence,
                escalateToLLM:  recommendation.escalateToLLM,
                supportingData: recommendation.supportingData,
                summary:        trimmedSummary.isEmpty ? nil : trimmedSummary
            )
            return (adapted, Tier3SignalFilter.clampConfidence(insight.confidence))
        } catch {
            // Guardrail trip / context-window / decode failure → keep baseline.
            // Confidence 0 makes AIOrchestrator prefer the unmodified recommendation.
            return (recommendation, 0.0)
        }
        #else
        return (recommendation, 0.0)
        #endif
    }

    // ── Private helpers ────────────────────────────────────

    /// System instructions for the on-device session. Pinned here (not in the
    /// per-call prompt) so the behaviour contract is explicit and auditable.
    private static let instructions: String = """
    You are FitMe's on-device fitness coach. Given a user's private context and \
    a set of population-derived signal keys, pick the 1–5 most relevant signals \
    and write a short, encouraging, second-person coaching note. Follow \
    "celebration not guilt": never judgmental. Do NOT invent new signal keys — \
    only reuse keys from the provided context. Never make medical claims, give \
    diagnoses, or cite numeric health metrics.
    """

    // Prompt context is built by the shared `Tier3PromptContext.build(...)`
    // (see PCCEscalationService.swift) — reused by both Tier 3a and Tier 3b.
}
