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

    // C5 ai-user-feedback-loop reinforcement-loop wires. All optional so
    // existing test paths that construct AIOrchestrator without the trio
    // continue to work (memory == nil short-circuits the loop). Mutable so
    // FitTrackerApp can late-inject the env-objects-resolved values after
    // the @StateObject closure has returned, same pattern as `goalMode`
    // late-injection at line ~324.
    private var feedbackMemory: RecommendationMemory?
    private var feedbackSettings: AppSettings?
    private var analytics: AnalyticsService?

    init(
        engineClient: some AIEngineClientProtocol,
        foundationModel: some FoundationModelProtocol,
        snapshot: @escaping @Sendable () -> LocalUserSnapshot,
        goalMode: @escaping @Sendable () -> NutritionGoalMode,
        feedbackMemory: RecommendationMemory? = nil,
        feedbackSettings: AppSettings? = nil,
        analytics: AnalyticsService? = nil
    ) {
        self.engineClient    = engineClient
        self.foundationModel = foundationModel
        self.snapshot        = snapshot
        self.goalMode        = goalMode
        self.feedbackMemory   = feedbackMemory
        self.feedbackSettings = feedbackSettings
        self.analytics        = analytics
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
        // HADF Phase 3A T5a — honest client-side inference observability. We
        // measure end-to-end wall-time + which substrate produced the final
        // recommendation. We do NOT measure ttft/tps (no client streaming
        // boundary; provider/model are server-side) — that is T5b (server-side).
        let inferenceStart = Date()
        var inferenceSourceTier = "local_fallback"
        let baseRecommendation: AIRecommendation
        if let jwt, jwt.looksLikeJWT, let bands {
            do {
                baseRecommendation = try await engineClient.fetchInsight(
                    segment: segment,
                    payload: bands,
                    jwt: jwt
                )
                inferenceSourceTier = "cloud"
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
                if confidence >= personalisationThreshold {
                    finalRecommendation = adapted
                    inferenceSourceTier = "on_device"
                } else {
                    finalRecommendation = baseRecommendation
                }
            } catch {
                finalRecommendation = baseRecommendation
            }
        } else {
            finalRecommendation = baseRecommendation
        }

        // HADF Phase 3A T5a — emit honest inference observability (advisory;
        // optional-chained so it no-ops when analytics isn't wired, preserving
        // existing test paths). duration_ms = end-to-end wall-time; source_tier
        // = terminal substrate (cloud / on_device / local_fallback).
        analytics?.logAiInferenceCompleted(
            segment: segment.rawValue,
            sourceTier: inferenceSourceTier,
            durationMs: Int(Date().timeIntervalSince(inferenceStart) * 1000)
        )

        // C5 ai-user-feedback-loop reinforcement-loop block — apply per-segment
        // confidence-tier adjustment from RecommendationMemory before publishing.
        // Gated on AppSettings.aiFeedbackLoopEnabled (default ON).
        let publishedRecommendation = applyReinforcementLoop(
            recommendation: finalRecommendation,
            segment: segment
        )

        latestRecommendations[segment] = publishedRecommendation

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
            recommendation: publishedRecommendation,
            snapshot: userSnapshot,
            adapters: lastAdapters,
            goalProfile: goalProfile
        )
        validatedRecommendations[segment] = validated
    }

    // MARK: - C5 reinforcement loop

    /// Apply per-signal-per-segment confidence-tier adjustment based on user feedback history.
    /// - Suppresses (downgrades) when >=3 dismissals within 30 days for a signal in this segment.
    /// - Boosts (upgrades) when acceptanceRate > 0.70 with >=5 outcomes in this segment.
    /// - No-op when feedbackMemory/feedbackSettings missing OR user disabled the loop.
    private func applyReinforcementLoop(
        recommendation: AIRecommendation,
        segment: AISegment
    ) -> AIRecommendation {
        guard let memory = feedbackMemory,
              feedbackSettings?.aiFeedbackLoopEnabled ?? true
        else {
            return recommendation
        }
        let dismissed = memory.frequentlyDismissedSignals(for: segment)
        let touched = recommendation.signals.filter { dismissed.contains($0) }
        if !touched.isEmpty {
            // D1 — partition touched into blacklist + manual-unsuppress + trend-unsuppress
            // + still-suppressible. Only the latter two (blacklist + still-suppressible)
            // trigger the C5 downgrade; the override paths skip it.
            let segmentOutcomes = memory.outcomes(for: segment)
            let now = Date()

            let blacklisted = touched.filter { memory.isBlacklisted(signal: $0, in: segment) }
            let manuallyUnsuppressed = touched.filter {
                !blacklisted.contains($0)
                && memory.isManuallyUnsuppressed(signal: $0, in: segment, now: now)
            }
            let trendUnsuppressed = touched.filter {
                !blacklisted.contains($0)
                && !manuallyUnsuppressed.contains($0)
                && AcceptanceTrendDetector.shouldUnsuppressByTrend(
                    signal: $0, segment: segment, outcomes: segmentOutcomes, now: now)
            }
            let stillSuppressible = touched.filter {
                !blacklisted.contains($0)
                && !manuallyUnsuppressed.contains($0)
                && !trendUnsuppressed.contains($0)
            }

            // Newly trend-detected — fire analytics + persist a 14d auto-unsuppression
            // so the same signal isn't immediately re-evaluated on the next call.
            for signal in trendUnsuppressed {
                analytics?.logHomeAiFeedbackSignalUnsuppressedByTrend(
                    segment: segment.rawValue,
                    signal: signal,
                    priorDismissalCount: AcceptanceTrendDetector.priorDismissalCount(
                        signal: signal, segment: segment, outcomes: segmentOutcomes),
                    daysSinceLastDismiss: AcceptanceTrendDetector.daysSinceLastDismiss(
                        signal: signal, segment: segment, outcomes: segmentOutcomes, now: now)
                )
                memory.recordManualUnsuppression(
                    signal: signal, in: segment, viaTrend: true, timestamp: now)
            }

            // Suppression fires only when at least one touched signal is blacklisted
            // OR still-suppressible (i.e. not covered by manual / trend overrides).
            let suppressingSignals = blacklisted + stillSuppressible
            if !suppressingSignals.isEmpty {
                analytics?.logHomeAiFeedbackSignalSuppressed(
                    segment: segment.rawValue,
                    signal: suppressingSignals[0],
                    dismissalCount: dismissed.count
                )
                return recommendation.withConfidence(Self.downgradeConfidence(recommendation.confidence))
            }
            // All touched signals were overridden — no downgrade.
            return recommendation
        }
        if let rate = memory.acceptanceRate(for: segment), rate > 0.70 {
            let outcomeCount = memory.outcomes(for: segment).filter { $0.action != .ignored }.count
            analytics?.logHomeAiFeedbackSegmentBoosted(
                segment: segment.rawValue,
                acceptanceRate: Int(rate * 100),
                outcomeCount: outcomeCount
            )
            return recommendation.withConfidence(Self.upgradeConfidence(recommendation.confidence))
        }
        return recommendation
    }

    /// Maps current confidence to one tier lower (high→medium, medium→low, low→suppressed-but-still-shown).
    /// Tier thresholds match ValidatedRecommendation.ConfidenceLevel — values land mid-band.
    static func downgradeConfidence(_ current: Double) -> Double {
        switch current {
        case 0.7...:     return 0.5   // high → medium
        case 0.4..<0.7:  return 0.3   // medium → low
        default:         return max(0.0, current - 0.1) // low → lower, capped at 0
        }
    }

    /// Maps current confidence to one tier higher (low→medium, medium→high, high stays).
    static func upgradeConfidence(_ current: Double) -> Double {
        switch current {
        case ..<0.4:     return 0.5   // low → medium
        case 0.4..<0.7:  return 0.75  // medium → high
        default:         return current // high stays high
        }
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

    /// Late-injection of the C5 reinforcement-loop wires (memory, settings, analytics).
    /// Called by FitTrackerApp once the @StateObject env-objects have resolved.
    func setFeedbackHooks(
        memory: RecommendationMemory?,
        settings: AppSettings?,
        analytics: AnalyticsService?
    ) {
        self.feedbackMemory = memory
        self.feedbackSettings = settings
        self.analytics = analytics
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
