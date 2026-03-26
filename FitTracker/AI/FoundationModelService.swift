// AI/FoundationModelService.swift
// On-device personalisation layer using Apple Foundation Models (iOS 26+).
// Protocol-driven for testability — inject FoundationModelProtocol in XCTest.
// FallbackFoundationModel handles pre-iOS 26 devices by returning confidence 0,
// which causes AIOrchestrator to always escalate to the cloud AI engine.

import Foundation

// ─────────────────────────────────────────────────────────
// MARK: – Protocol (testability seam)
// ─────────────────────────────────────────────────────────

/// Abstraction over Apple Foundation Models for on-device inference.
/// Conforming types must be Sendable for safe use across Swift concurrency.
public protocol FoundationModelProtocol: Sendable {
    /// Run on-device inference with the given prompt context.
    /// - Returns: (adaptedRecommendation, confidence) where confidence ∈ [0, 1].
    ///            confidence == 0 signals that the model could not process the request
    ///            and the caller must escalate to the cloud AI engine.
    func adapt(
        recommendation: AIRecommendation,
        snapshot: LocalUserSnapshot
    ) async throws -> (recommendation: AIRecommendation, confidence: Double)

    /// Whether the Foundation Models framework is available on this device.
    var isAvailable: Bool { get }
}

// ─────────────────────────────────────────────────────────
// MARK: – FallbackFoundationModel (pre-iOS 26 / unavailable)
// ─────────────────────────────────────────────────────ation

/// Used on devices where Apple Foundation Models is unavailable (pre-iOS 26).
/// Returns confidence = 0.0, which causes AIOrchestrator to always escalate
/// to the cloud AI engine for personalisation.
public struct FallbackFoundationModel: FoundationModelProtocol {
    public var isAvailable: Bool { false }

    public init() {}

    public func adapt(
        recommendation: AIRecommendation,
        snapshot: LocalUserSnapshot
    ) async throws -> (recommendation: AIRecommendation, confidence: Double) {
        // Confidence 0 → orchestrator will escalate to cloud
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
        // Placeholder until SDK ships:
        _ = context
        let adapted = applyLocalAdjustments(recommendation: recommendation, snapshot: snapshot)
        return (adapted, 0.8)
    }

    // ── Private helpers ────────────────────────────────────

    private func buildPrivateContext(
        snapshot: LocalUserSnapshot,
        recommendation: AIRecommendation
    ) -> String {
        // Assembles a structured prompt from the user's private data.
        // Not transmitted to any external service.
        var lines: [String] = ["[FitTracker on-device personalisation context]"]
        lines.append("Segment: \(recommendation.segment)")
        lines.append("Cloud signals: \(recommendation.signals.joined(separator: ", "))")
        lines.append("Cohort confidence: \(recommendation.confidence)")

        if let goal = snapshot.primaryGoal       { lines.append("Goal: \(goal)") }
        if let phase = snapshot.programPhase     { lines.append("Phase: \(phase)") }
        if let sleep = snapshot.avgSleepHours    { lines.append("Sleep: \(sleep)h avg") }
        if let stress = snapshot.stressLevel     { lines.append("Stress: \(stress)") }
        if let hr = snapshot.restingHeartRate    { lines.append("RHR: \(hr)bpm") }

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

        return AIRecommendation(
            segment:       recommendation.segment,
            signals:       signals,
            confidence:    recommendation.confidence,
            escalateToLLM: recommendation.escalateToLLM,
            supportingData: recommendation.supportingData
        )
    }
}
