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
    var goalMode:               () -> NutritionGoalMode

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
        // Audit AI-012 / DEEP-AI-008: when called standalone, manage the
        // isProcessing flag here. When called from `processAll`, that wrapper
        // owns the flag so the UI doesn't flicker per-segment.
        let owns = !isProcessing
        if owns { isProcessing = true }
        lastError = nil
        defer { if owns { isProcessing = false } }

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

        // Audit AI-001 + DEEP-AI-009: defensively check `isAvailable` before
        // invoking the Foundation Model. The protocol abstracts iOS 26+
        // gating (see FoundationModelService), but a runtime guard ensures
        // we never attempt inference if the implementation reports it isn't
        // ready — for example a future iOS where the model is downloading.
        let finalRecommendation: AIRecommendation
        if foundationModel.isAvailable {
            do {
                let (adapted, confidence) = try await foundationModel.adapt(
                    recommendation: baseRecommendation,
                    snapshot: userSnapshot
                )
                finalRecommendation = confidence >= personalisationThreshold ? adapted : baseRecommendation
            } catch {
                finalRecommendation = baseRecommendation
            }
        } else {
            finalRecommendation = baseRecommendation
        }

        latestRecommendations[segment] = finalRecommendation

        // Validate and attach goal context.
        // Audit AI-011: if `setAdapters` hasn't been called yet (e.g., a test
        // path that calls `process` directly without going through the
        // app-wide `buildSnapshot` wrapper), bootstrap an empty-data adapter
        // list so the freshness/evidence chain doesn't crash on an empty
        // input. The empty adapters report `lastUpdated: nil`, which the
        // freshness computation already handles as a "no data" signal.
        if lastAdapters.isEmpty {
            lastAdapters = Self.bootstrapEmptyAdapters()
        }
        let validated = ValidatedRecommendation.validate(
            recommendation: finalRecommendation,
            snapshot: userSnapshot,
            adapters: lastAdapters,
            goalProfile: goalProfile
        )
        validatedRecommendations[segment] = validated
    }

    /// Build a default-state adapter list for the AI-011 bootstrap path.
    /// Each adapter is constructed with empty/default inputs and reports
    /// `lastUpdated: nil` so the validation evidence chain has at least one
    /// node per source even before the app wires the real adapter list via
    /// `setAdapters`.
    private static func bootstrapEmptyAdapters() -> [any AIInputAdapter] {
        let emptyProfile = UserProfile()
        let emptyPreferences = UserPreferences()
        return [
            ProfileAdapter(profile: emptyProfile, preferences: emptyPreferences, todayDayType: .restDay),
            HealthKitAdapter(liveMetrics: LiveMetrics(), recentLogs: [], profile: emptyProfile, readiness: nil),
            TrainingAdapter(recentLogs: [], todayDayType: .restDay),
            NutritionAdapter(
                latestLog: nil,
                goalPlan: emptyProfile.nutritionPlan(
                    currentWeightKg: emptyProfile.startWeightKg,
                    currentBodyFatPercent: emptyProfile.startBodyFatPct,
                    isTrainingDay: false,
                    preferences: emptyPreferences
                ),
                liveMetrics: LiveMetrics(),
                profile: emptyProfile
            ),
        ]
    }

    /// Process all segments sequentially for a full refresh.
    /// - Parameter snapshot: Live snapshot built from stores (HealthKit, profile, training).
    ///   When nil, falls back to the closure provided at init time.
    ///
    /// Audit AI-012 / DEEP-AI-008: hold `isProcessing` for the full batch so
    /// the UI shows a single in-flight indicator instead of flickering
    /// between segments as each `process(...)` call toggles the flag.
    public func processAll(jwt: String?, snapshot: LocalUserSnapshot? = nil) async {
        isProcessing = true
        defer { isProcessing = false }
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
