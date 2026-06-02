// AI/RecommendationFeedbackController.swift
// C5 ai-user-feedback-loop (2026-06-01)
//
// Thin @MainActor ObservableObject facade exposing RecommendationMemory to
// SwiftUI views. Publishes totalCount for reactive Settings UI. Owns the
// per-segment computed properties so views don't reach into RecommendationMemory
// directly.
//
// Promotes RecommendationMemory from a per-AIOrchestrator-instance member to an
// app-lifecycle @StateObject + env-object — closes audit UI-024 (deferred
// 2026-04-10 in AIInsightCard.swift:230-235).

import Foundation

@MainActor
final class RecommendationFeedbackController: ObservableObject {

    let memory: RecommendationMemory

    @Published private(set) var totalCount: Int = 0

    init(memory: RecommendationMemory = RecommendationMemory()) {
        self.memory = memory
        self.totalCount = memory.totalCount
    }

    // MARK: - Record

    func record(outcome: RecommendationOutcome) {
        memory.record(outcome: outcome)
        totalCount = memory.totalCount
    }

    // MARK: - Query passthroughs

    func acceptanceRate(for segment: AISegment) -> Double? {
        memory.acceptanceRate(for: segment)
    }

    func frequentlyDismissedSignals(for segment: AISegment) -> [String] {
        memory.frequentlyDismissedSignals(for: segment)
    }

    func outcomes(for segment: AISegment) -> [RecommendationOutcome] {
        memory.outcomes(for: segment)
    }

    // MARK: - D1 passthroughs (manual un-suppress + blacklist)

    func isManuallyUnsuppressed(signal: String, in segment: AISegment, now: Date = Date()) -> Bool {
        memory.isManuallyUnsuppressed(signal: signal, in: segment, now: now)
    }

    func manualUnsuppressions(for segment: AISegment, now: Date = Date()) -> [ManualUnsuppression] {
        memory.manualUnsuppressions(for: segment, now: now)
    }

    func isBlacklisted(signal: String, in segment: AISegment) -> Bool {
        memory.isBlacklisted(signal: signal, in: segment)
    }

    func blacklistedSignals(for segment: AISegment) -> [BlacklistedSignal] {
        memory.blacklistedSignals(for: segment)
    }

    /// Persists a manual un-suppression (14d window). `viaTrend` records whether
    /// the AcceptanceTrendDetector criterion fired at the moment of the user
    /// action (audit only — has no behavioral effect).
    func recordManualUnsuppression(
        signal: String,
        in segment: AISegment,
        viaTrend: Bool,
        timestamp: Date = Date()
    ) {
        memory.recordManualUnsuppression(
            signal: signal, in: segment, viaTrend: viaTrend, timestamp: timestamp)
        objectWillChange.send()
    }

    /// Permanently blacklists `signal` for `segment`. Idempotent.
    func recordBlacklist(
        signal: String,
        in segment: AISegment,
        dismissalCount: Int,
        timestamp: Date = Date()
    ) {
        memory.recordBlacklist(
            signal: signal, in: segment, dismissalCount: dismissalCount, timestamp: timestamp)
        objectWillChange.send()
    }

    // MARK: - GDPR

    func clearAll() {
        memory.clearAll()
        totalCount = 0
    }
}
