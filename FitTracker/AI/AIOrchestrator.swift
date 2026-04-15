// AI/AIOrchestrator.swift
// Orchestrates the federated cohort intelligence pipeline:
//   1. Build a local baseline recommendation from on-device data
//   2. Prefer cloud cohort insight when a valid backend JWT is available
//   3. Apply on-device personalisation using private user data
//   4. Validate confidence and attach goal context before surfacing
//
// Architecture:
//   - PII never leaves the device — only banded categorical values are sent to cloud
//   - A local baseline always exists, even when cloud auth is unavailable
//   - Cloud is called only when a segment has enough banded data and a valid JWT
//   - Foundation Models unavailable (pre-iOS 26) → FallbackFoundationModel → skips personalisation

import Foundation

// ─────────────────────────────────────────────────────────
// MARK: – AIOrchestrator
// ─────────────────────────────────────────────────────────

@MainActor
public final class AIOrchestrator: ObservableObject {

    // Published state for SwiftUI bindings
    @Published public private(set) var latestRecommendations: [AISegment: AIRecommendation] = [:]
    @Published private(set) var validatedRecommendations: [AISegment: ValidatedRecommendation] = [:]
    @Published public private(set) var isProcessing = false
    @Published public private(set) var lastError: AIError?

    private let engineClient:   any AIEngineClientProtocol
    private let foundationModel: any FoundationModelProtocol
    private let snapshot:       () -> LocalUserSnapshot
    let goalMode:               () -> NutritionGoalMode

    /// Minimum on-device confidence required to use personalised result.
    /// Below this threshold the unmodified cloud recommendation is used instead.
    private let personalisationThreshold: Double = 0.4

    /// Adapters used in the last build — retained for validation.
    private var lastAdapters: [any AIInputAdapter] = []

    init(
        engineClient: some AIEngineClientProtocol,
        foundationModel: some FoundationModelProtocol,
        snapshot: @escaping @Sendable () -> LocalUserSnapshot,
        goalMode: @escaping @Sendable () -> NutritionGoalMode
    ) {
        self.engineClient    = engineClient
        self.foundationModel = foundationModel
        self.snapshot        = snapshot
        self.goalMode        = goalMode
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Public API
    // ─────────────────────────────────────────────────────

    /// Clear all cached recommendations (called on sign-out).
    public func clearRecommendations() {
        latestRecommendations = [:]
        validatedRecommendations = [:]
        lastError = nil
    }

    public func process(segment: AISegment, jwt: String?, overrideSnapshot: LocalUserSnapshot? = nil) async {
        isProcessing = true
        lastError = nil
        defer { isProcessing = false }

        let userSnapshot = overrideSnapshot ?? snapshot()
        let goalProfile = GoalProfile.forGoal(goalMode())
        let bands = extractBands(segment: segment, snapshot: userSnapshot)
        let localRecommendation = AIRecommendation.localFallback(for: segment, snapshot: userSnapshot, goalProfile: goalProfile)
        let baseRecommendation: AIRecommendation
        if let jwt, jwt.looksLikeJWT, let bands {
            do {
                baseRecommendation = try await engineClient.fetchInsight(
                    segment: segment,
                    payload: bands,
                    jwt: jwt
                )
            } catch AIEngineError.rateLimited {
                lastError = .rateLimited
                baseRecommendation = localRecommendation
            } catch AIEngineError.unauthorised {
                lastError = .unauthenticated
                baseRecommendation = localRecommendation
            } catch {
                lastError = .networkError(error)
                baseRecommendation = localRecommendation
            }
        } else {
            baseRecommendation = localRecommendation
            if bands == nil {
                lastError = .insufficientData
            }
        }

        let finalRecommendation: AIRecommendation
        do {
            let (adapted, confidence) = try await foundationModel.adapt(
                recommendation: baseRecommendation,
                snapshot: userSnapshot
            )
            finalRecommendation = confidence >= personalisationThreshold ? adapted : baseRecommendation
        } catch {
            finalRecommendation = baseRecommendation
        }

        latestRecommendations[segment] = finalRecommendation

        // Validate and attach goal context
        let validated = ValidatedRecommendation.validate(
            recommendation: finalRecommendation,
            snapshot: userSnapshot,
            adapters: lastAdapters,
            goalProfile: goalProfile
        )
        validatedRecommendations[segment] = validated
    }

    /// Process all segments sequentially for a full refresh.
    /// - Parameter snapshot: Live snapshot built from stores (HealthKit, profile, training).
    ///   When nil, falls back to the closure provided at init time.
    public func processAll(jwt: String?, snapshot: LocalUserSnapshot? = nil) async {
        for segment in AISegment.allCases {
            await process(segment: segment, jwt: jwt, overrideSnapshot: snapshot)
        }
    }

    /// Update the adapters list (called by AISnapshotBuilder after building).
    func setAdapters(_ adapters: [any AIInputAdapter]) {
        lastAdapters = adapters
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

private extension String {
    var looksLikeJWT: Bool {
        split(separator: ".").count == 3
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – AIError
// ─────────────────────────────────────────────────────────

public enum AIError: Error, Sendable {
    case unauthenticated
    case rateLimited
    case networkError(any Error)
    case insufficientData

    public var localizedDescription: String {
        switch self {
        case .unauthenticated:    return "Cloud AI is unavailable until a backend-authenticated session is active."
        case .rateLimited:        return "AI requests are temporarily limited. Try again later."
        case .networkError(let e): return "Network error: \(e.localizedDescription)"
        case .insufficientData:   return "Not enough tracking data yet to generate AI insights. Keep logging!"
        }
    }
}
