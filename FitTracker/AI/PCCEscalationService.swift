// AI/PCCEscalationService.swift
// Tier 3b (foundation-models-tier3): on-device-initiated escalation to Apple
// Private Cloud Compute. When the cohort backend sets `escalate_to_llm` AND the
// on-device Tier-3a result is still low-confidence, AIOrchestrator runs a
// reasoning-capable PCC session (32K context, no API key, no DPA — Apple does
// not retain prompts). Protocol-driven for testability; NoOpPCCEscalation is the
// pre-iOS-26.4 / framework-absent fallback (confidence 0 → keep Tier-3a result).

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// ─────────────────────────────────────────────────────────
// MARK: – Shared prompt context (used by Tier 3a + Tier 3b)
// ─────────────────────────────────────────────────────────

/// Builds the on-device personalisation prompt from a recommendation + snapshot.
/// Shared by FoundationModelService (Tier 3a) and PCCEscalationService (Tier 3b)
/// so both tiers feed the model the same private context. The full payload is
/// inlined for the inference engine only — it never leaves the device for Tier 3a;
/// for Tier 3b it goes to Apple PCC (no retention) per the documented disposition.
public enum Tier3PromptContext {

    /// - Parameter redactedForLogging: when true (audit DEEP-AI-012), scrub raw
    ///   RHR/sleep/stress/readiness values — keep only presence indicators.
    public static func build(
        snapshot: LocalUserSnapshot,
        recommendation: AIRecommendation,
        redactedForLogging: Bool = false
    ) -> String {
        var lines: [String] = ["[FitTracker on-device personalisation context]"]
        lines.append("Segment: \(recommendation.segment)")
        lines.append("Cloud signals: \(recommendation.signals.joined(separator: ", "))")
        lines.append("Cohort confidence: \(recommendation.confidence)")

        if let goal = snapshot.primaryGoal {
            lines.append("Goal: \(goal)")
            let goalMode = NutritionGoalMode(primaryGoalString: goal) ?? .fatLoss
            let profile = GoalProfile.forGoal(goalMode)
            if let segment = AISegment(rawValue: recommendation.segment),
               let emphasis = profile.messagingEmphasis[segment] {
                lines.append("Goal emphasis: \(emphasis)")
            }
            let drivers = profile.primaryDrivers.map { "\($0.metric) (\($0.direction.rawValue), weight \($0.weight))" }
            lines.append("Primary drivers: \(drivers.joined(separator: "; "))")
        }
        if let phase = snapshot.programPhase { lines.append("Phase: \(phase)") }

        if redactedForLogging {
            if snapshot.avgSleepHours    != nil { lines.append("Sleep: <redacted>") }
            if snapshot.stressLevel      != nil { lines.append("Stress: <redacted>") }
            if snapshot.restingHeartRate != nil { lines.append("RHR: <redacted>") }
        } else {
            if let sleep = snapshot.avgSleepHours    { lines.append("Sleep: \(sleep)h avg") }
            if let stress = snapshot.stressLevel     { lines.append("Stress: \(stress)") }
            if let hr = snapshot.restingHeartRate    { lines.append("RHR: \(hr)bpm") }
        }

        if let score = snapshot.readinessScore {
            if redactedForLogging {
                lines.append("Readiness score: <redacted>/100")
            } else {
                lines.append("Readiness score: \(score)/100 (confidence: \(snapshot.readinessConfidence ?? "unknown"))")
                lines.append("Recommended intensity: \(snapshot.readinessRecommendation ?? "unknown")")
            }
            if let flags = snapshot.fatigueFlags, !flags.isEmpty {
                lines.append("Fatigue warnings: \(flags.joined(separator: ", "))")
            }
        }

        return lines.joined(separator: "\n")
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – Protocol (testability seam)
// ─────────────────────────────────────────────────────────

/// Tier 3b escalation seam. Mirrors FoundationModelProtocol so it can be mocked
/// in XCTest without the FoundationModels SDK or a network round-trip.
public protocol PCCEscalationProtocol: Sendable {
    /// Run a Private Cloud Compute escalation for a low-confidence recommendation.
    /// - Returns: (escalatedRecommendation, confidence). Confidence below the
    ///   orchestrator's personalisation threshold means the escalation is NOT
    ///   preferred — the Tier-3a result is kept instead.
    func escalate(
        recommendation: AIRecommendation,
        snapshot: LocalUserSnapshot
    ) async throws -> (recommendation: AIRecommendation, confidence: Double)

    /// Whether PCC escalation is available (iOS 26.4+, Apple Intelligence on, network).
    var isAvailable: Bool { get }
}

// ─────────────────────────────────────────────────────────
// MARK: – NoOp fallback (pre-iOS 26.4 / unavailable)
// ─────────────────────────────────────────────────────────

/// Injected when PCC is unavailable. Confidence 0 → orchestrator keeps the
/// Tier-3a result and never marks the tier as `pcc`.
public struct NoOpPCCEscalation: PCCEscalationProtocol {
    public var isAvailable: Bool { false }
    public init() {}
    public func escalate(
        recommendation: AIRecommendation,
        snapshot: LocalUserSnapshot
    ) async throws -> (recommendation: AIRecommendation, confidence: Double) {
        return (recommendation, 0.0)
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – Live PCC escalation (iOS 26.4+)
// ─────────────────────────────────────────────────────────

/// Live escalation via Apple Private Cloud Compute.
///
/// ⚠️ SDK-GAP (verified 2026-06-15, Xcode 26.5 / iOS 26.5 SDK): the WWDC26-
/// announced PCC API (`PrivateCloudComputeLanguageModel`, `ContextOptions`,
/// `reasoningLevel`) is NOT present in the shipping FoundationModels SDK — the
/// framework exposes only `SystemLanguageModel`. The live PCC call is therefore
/// gated behind the `FOUNDATION_MODELS_PCC` compile flag (undefined → excluded),
/// and this service no-ops (isAvailable=false → orchestrator keeps the Tier-3a
/// result) until Apple ships the symbols. The protocol seam, orchestrator gating
/// (Tier 3b), and the mock-based tests are all live now; flipping the flag once
/// the SDK exposes PCC activates the real path with no other change.
@available(iOS 26.4, *)
public final class PCCEscalationService: PCCEscalationProtocol {

    public init() {}

    public var isAvailable: Bool {
        #if FOUNDATION_MODELS_PCC && canImport(FoundationModels)
        if case .available = PrivateCloudComputeLanguageModel().availability { return true }
        return false
        #else
        return false  // PCC API not in the shipping SDK — see SDK-GAP note above.
        #endif
    }

    public func escalate(
        recommendation: AIRecommendation,
        snapshot: LocalUserSnapshot
    ) async throws -> (recommendation: AIRecommendation, confidence: Double) {
        #if FOUNDATION_MODELS_PCC && canImport(FoundationModels)
        guard isAvailable else { return (recommendation, 0.0) }

        let context = Tier3PromptContext.build(snapshot: snapshot, recommendation: recommendation)
        let allowed = Set(recommendation.signals).union(Tier3SignalFilter.knownLocalVocabulary)

        do {
            let model = PrivateCloudComputeLanguageModel()
            let session = LanguageModelSession(model: model, instructions: { Self.instructions })
            let response = try await session.respond(
                to: context,
                generating: PersonalizedInsight.self,
                options: GenerationOptions(temperature: 0.3),
                contextOptions: ContextOptions(reasoningLevel: .light)
            )
            let insight = response.content

            let signals = Tier3SignalFilter.filterToAllowedSignals(
                insight.prioritizedSignals,
                allowed: allowed,
                baseline: recommendation.signals
            )
            let trimmed = insight.summary.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            let escalated = AIRecommendation(
                segment:        recommendation.segment,
                signals:        signals,
                confidence:     recommendation.confidence,
                escalateToLLM:  recommendation.escalateToLLM,
                supportingData: recommendation.supportingData,
                summary:        trimmed.isEmpty ? nil : trimmed
            )
            return (escalated, Tier3SignalFilter.clampConfidence(insight.confidence))
        } catch {
            // Offline / guardrail / decode failure → keep the Tier-3a result.
            return (recommendation, 0.0)
        }
        #else
        // PCC API unavailable in this SDK — behave as a no-op escalation.
        return (recommendation, 0.0)
        #endif
    }

    #if FOUNDATION_MODELS_PCC && canImport(FoundationModels)
    private static let instructions: String = """
    You are FitMe's fitness coach running on Apple Private Cloud Compute. The \
    on-device model was uncertain, so reason carefully about the user's private \
    context and the provided signal keys, then pick the 1–5 most relevant signals \
    and write a short, encouraging, second-person coaching note. Follow \
    "celebration not guilt": never judgmental. Do NOT invent new signal keys. \
    Never make medical claims, give diagnoses, or cite numeric health metrics.
    """
    #endif
}
