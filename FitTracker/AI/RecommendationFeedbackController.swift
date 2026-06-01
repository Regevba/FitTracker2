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

    // MARK: - GDPR

    func clearAll() {
        memory.clearAll()
        totalCount = 0
    }
}
