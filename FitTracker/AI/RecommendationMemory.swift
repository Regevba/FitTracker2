// AI/RecommendationMemory.swift
// On-device store of recommendation outcomes (plain UserDefaults, not encrypted).
// Tracks what the user accepted, dismissed, or ignored to improve future recommendations.
// PII-free: only stores segment, signals, action, and timestamp.

import Foundation

// MARK: - UserAction

enum UserAction: String, Codable, Sendable {
    case accepted
    case dismissed
    case ignored
}

// MARK: - RecommendationOutcome

struct RecommendationOutcome: Codable, Sendable, Identifiable {
    let id: UUID
    let segment: String          // AISegment raw value
    let signals: [String]
    let confidenceLevel: String  // "high", "medium", "low"
    let source: String           // "cloud", "local", "personalised"
    let action: UserAction
    let dismissReason: String?   // only for dismissed
    let timestamp: Date

    init(segment: String, signals: [String], confidenceLevel: String, source: String, action: UserAction, dismissReason: String? = nil, timestamp: Date = Date()) {
        self.id = UUID()
        self.segment = segment
        self.signals = signals
        self.confidenceLevel = confidenceLevel
        self.source = source
        self.action = action
        self.dismissReason = dismissReason
        self.timestamp = timestamp
    }
}

// MARK: - RecommendationMemory

final class RecommendationMemory: @unchecked Sendable {

    private let storageKey = "fitme.ai.recommendation_memory"
    private let maxEntriesPerSegment = 200
    private var outcomes: [RecommendationOutcome] = []
    private let lock = NSLock()

    init() {
        load()
    }

    // MARK: - Record

    func record(outcome: RecommendationOutcome) {
        lock.lock()
        defer { lock.unlock() }

        outcomes.append(outcome)
        enforceLimit()
        save()
    }

    // MARK: - Query

    func outcomes(for segment: AISegment) -> [RecommendationOutcome] {
        lock.lock()
        defer { lock.unlock() }
        return outcomes.filter { $0.segment == segment.rawValue }
    }

    func acceptanceRate(for segment: AISegment) -> Double? {
        lock.lock()
        defer { lock.unlock() }
        let segmentOutcomes = outcomes.filter { $0.segment == segment.rawValue && $0.action != .ignored }
        guard segmentOutcomes.count >= 5 else { return nil }
        let accepted = segmentOutcomes.filter { $0.action == .accepted }.count
        return Double(accepted) / Double(segmentOutcomes.count)
    }

    /// Signals that were frequently dismissed — candidates for suppression or reframing.
    func frequentlyDismissedSignals(for segment: AISegment, threshold: Int = 3) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        let dismissed = outcomes.filter { $0.segment == segment.rawValue && $0.action == .dismissed }
        var signalCounts: [String: Int] = [:]
        for outcome in dismissed {
            for signal in outcome.signals {
                signalCounts[signal, default: 0] += 1
            }
        }
        return signalCounts.filter { $0.value >= threshold }.map(\.key)
    }

    /// Total stored outcomes.
    var totalCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return outcomes.count
    }

    // MARK: - GDPR / Account Deletion

    func clearAll() {
        lock.lock()
        defer { lock.unlock() }
        outcomes = []
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    // MARK: - Persistence (plain UserDefaults)

    private func save() {
        guard let data = try? JSONEncoder().encode(outcomes) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let loaded = try? JSONDecoder().decode([RecommendationOutcome].self, from: data)
        else { return }
        outcomes = loaded
    }

    /// LRU eviction: single pass to count per segment, then remove oldest excess entries.
    private func enforceLimit() {
        // Group indices by segment in one pass
        var segmentIndices: [String: [Int]] = [:]
        for (index, outcome) in outcomes.enumerated() {
            segmentIndices[outcome.segment, default: []].append(index)
        }
        var indicesToRemove: Set<Int> = []
        for (_, indices) in segmentIndices where indices.count > maxEntriesPerSegment {
            let excess = indices.count - maxEntriesPerSegment
            indicesToRemove.formUnion(indices.prefix(excess))
        }
        guard !indicesToRemove.isEmpty else { return }
        outcomes = outcomes.enumerated().compactMap { indicesToRemove.contains($0.offset) ? nil : $0.element }
    }
}
