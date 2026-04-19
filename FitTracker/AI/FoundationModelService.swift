// AI/FoundationModelService.swift
// On-device personalisation layer using Apple Foundation Models (iOS 26+).
// Protocol-driven for testability — inject FoundationModelProtocol in XCTest.
// FallbackFoundationModel handles pre-iOS 26 devices by returning confidence 0,
// which means AIOrchestrator keeps the unpersonalised baseline recommendation.

import Foundation

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
// MARK: – Live Foundation Models service (iOS 26+)
// ─────────────────────────────────────────────────────────

/// Live on-device inference using Apple Foundation Models.
/// Only available on iOS 26+ — the build target gates this with
/// #available checks in AIOrchestrator. On earlier OS versions
/// AIOrchestrator injects FallbackFoundationModel instead.
@available(iOS 26, *)
public final class FoundationModelService: FoundationModelProtocol {
    public var isAvailable: Bool { true }

    public init() {}

    public func adapt(
        recommendation: AIRecommendation,
        snapshot: LocalUserSnapshot
    ) async throws -> (recommendation: AIRecommendation, confidence: Double) {
        // Build a private context string from the user's full local snapshot.
        // This context never leaves the device — it is only consumed by
        // the on-device Foundation Models inference pipeline.
        let context = buildPrivateContext(snapshot: snapshot, recommendation: recommendation)

        // NOTE: Replace the placeholder below with the real
        // FoundationModels.LanguageModel API once the iOS 26 SDK is available.
        // The protocol ensures all callers are decoupled from this implementation.
        //
        // Example (iOS 26 SDK):
        //   let model = LanguageModel.default
        //   let session = LanguageModelSession(model: model)
        //   let response = try await session.respond(to: context)
        //   let adapted = parseAdaptedRecommendation(from: response.content, base: recommendation)
        //   return (adapted, response.confidence ?? 0.8)
        //
        // Placeholder until SDK ships — confidence 0.5 signals partial personalisation
        #warning("Placeholder: replace with real FoundationModels API when iOS 26 SDK ships")
        _ = context
        let adapted = applyLocalAdjustments(recommendation: recommendation, snapshot: snapshot)
        return (adapted, 0.5)
    }

    // ── Private helpers ────────────────────────────────────

    /// Build the on-device prompt context. The full biometric payload is
    /// inlined into the prompt for the inference engine — but if the caller
    /// wants a string suitable for *logging* (audit DEEP-AI-012), it must use
    /// `redactedForLogging: true` to scrub raw RHR/sleep/stress values.
    /// Production code paths that touch the inference engine pass `false`;
    /// any debug/diagnostic emission must pass `true`.
    private func buildPrivateContext(
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
            // Goal-aware emphasis: tell the LLM what to prioritize.
            // Audit AI-014: parse the snake_case primaryGoal via the
            // dedicated initializer (rawValue init never matched).
            let goalMode = NutritionGoalMode(primaryGoalString: goal) ?? .fatLoss
            let profile = GoalProfile.forGoal(goalMode)
            if let segment = AISegment(rawValue: recommendation.segment),
               let emphasis = profile.messagingEmphasis[segment] {
                lines.append("Goal emphasis: \(emphasis)")
            }
            let drivers = profile.primaryDrivers.map { "\($0.metric) (\($0.direction.rawValue), weight \($0.weight))" }
            lines.append("Primary drivers: \(drivers.joined(separator: "; "))")
        }
        if let phase = snapshot.programPhase     { lines.append("Phase: \(phase)") }

        // Audit DEEP-AI-012: when this string is destined for a log sink,
        // scrub raw biometric values — keep only a presence indicator.
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

    private func applyLocalAdjustments(
        recommendation: AIRecommendation,
        snapshot: LocalUserSnapshot
    ) -> AIRecommendation {
        // Rule-based local adjustments layered on top of cloud signals.
        // Keeps PII local while enriching the cloud's population signal.
        var signals = recommendation.signals

        if let sleep = snapshot.avgSleepHours, sleep < 6 {
            signals.append("local_sleep_deprivation_deload_advised")
        }
        if let stress = snapshot.stressLevel, stress == "high" {
            signals.append("local_high_stress_reduce_volume")
        }
        if let hr = snapshot.restingHeartRate, hr > 80 {
            signals.append("local_elevated_rhr_monitor_recovery")
        }

        // Readiness-based signals
        if let score = snapshot.readinessScore, score < 30 {
            signals.append("readiness_critical_low")
        }
        if let flags = snapshot.fatigueFlags, flags.contains("hydrationWarning") {
            signals.append("hydration_warning_active")
        }

        return AIRecommendation(
            segment:       recommendation.segment,
            signals:       signals,
            confidence:    recommendation.confidence,
            escalateToLLM: recommendation.escalateToLLM,
            supportingData: recommendation.supportingData
        )
    }
}
