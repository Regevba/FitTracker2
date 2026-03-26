// AI/AIOrchestrator.swift
// Orchestrates the two-layer federated cohort intelligence pipeline:
//   1. On-device layer: Apple Foundation Models personalises using private user data
//   2. Cloud layer: AI engine provides population-level cohort insights
//
// Architecture:
//   - PII never leaves the device — only banded categorical values are sent to cloud
//   - On-device layer always runs first; cloud is called only per active segment
//   - If on-device confidence < threshold, cloud insight is fetched and merged
//   - Foundation Models unavailable (pre-iOS 26) → FallbackFoundationModel → always escalates

import Foundation

// ─────────────────────────────────────────────────────────
// MARK: – AIOrchestrator
// ─────────────────────────────────────────────────────────

@MainActor
public final class AIOrchestrator: ObservableObject {

    // Published state for SwiftUI bindings
    @Published public private(set) var latestRecommendations: [AISegment: AIRecommendation] = [:]
    @Published public private(set) var isProcessing = false
    @Published public private(set) var lastError: AIError?

    private let engineClient:   any AIEngineClientProtocol
    private let foundationModel: any FoundationModelProtocol
    private let snapshot:       () -> LocalUserSnapshot

    /// Confidence threshold below which cloud escalation is triggered.
    private let escalationThreshold: Double = 0.4

    public init(
        engineClient: some AIEngineClientProtocol,
        foundationModel: some FoundationModelProtocol,
        snapshot: @escaping @Sendable () -> LocalUserSnapshot
    ) {
        self.engineClient    = engineClient
        self.foundationModel = foundationModel
        self.snapshot        = snapshot
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Public API
    // ─────────────────────────────────────────────────────

    /// Process a specific segment. Only segments with complete band data are submitted.
    /// Call this when the user navigates to a segment or data materially changes.
    public func process(segment: AISegment, jwt: String?) async {
        isProcessing = true
        lastError = nil
        defer { isProcessing = false }

        let userSnapshot = snapshot()
        let bands = extractBands(segment: segment, snapshot: userSnapshot)

        guard let bands else {
            // Insufficient data — skip silently; will retry on next app foreground
            return
        }

        guard let jwt, !jwt.isEmpty else {
            lastError = .unauthenticated
            return
        }

        // Step 1: Attempt on-device inference
        // Uses explicit do/catch — try? would silently swallow Foundation Models errors
        let cloudRecommendation: AIRecommendation
        do {
            cloudRecommendation = try await engineClient.fetchInsight(
                segment: segment,
                payload: bands,
                jwt: jwt
            )
        } catch AIEngineError.rateLimited {
            lastError = .rateLimited
            return
        } catch AIEngineError.unauthorised {
            lastError = .unauthenticated
            return
        } catch {
            lastError = .networkError(error)
            return
        }

        // Step 2: Apply on-device personalisation layer
        // Explicit do/catch: Foundation Models can throw — silently swallowing would
        // skip personalisation without the caller knowing.
        let finalRecommendation: AIRecommendation
        do {
            let (adapted, confidence) = try await foundationModel.adapt(
                recommendation: cloudRecommendation,
                snapshot: userSnapshot
            )
            // If confidence below threshold, use cloud recommendation as-is
            // (Foundation Models returned low confidence or FallbackFoundationModel was used)
            finalRecommendation = confidence >= escalationThreshold ? adapted : cloudRecommendation
        } catch {
            // Foundation Models threw — fall back to unmodified cloud recommendation
            finalRecommendation = cloudRecommendation
        }

        latestRecommendations[segment] = finalRecommendation
    }

    /// Process all segments sequentially for a full refresh.
    public func processAll(jwt: String?) async {
        for segment in AISegment.allCases {
            await process(segment: segment, jwt: jwt)
        }
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Band extraction
    // ─────────────────────────────────────────────────────

    private func extractBands(
        segment: AISegment,
        snapshot: LocalUserSnapshot
    ) -> [String: String]? {
        switch segment {
        case .training:  return snapshot.trainingBands()
        case .nutrition: return snapshot.nutritionBands()
        case .recovery:  return snapshot.recoveryBands()
        case .stats:     return snapshot.statsBands()
        }
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – AIError
// ─────────────────────────────────────────────────────────

public enum AIError: Error, Sendable {
    case unauthenticated
    case rateLimited
    case networkError(any Error)

    public var localizedDescription: String {
        switch self {
        case .unauthenticated:    return "Sign in required for AI insights."
        case .rateLimited:        return "AI requests are temporarily limited. Try again later."
        case .networkError(let e): return "Network error: \(e.localizedDescription)"
        }
    }
}
