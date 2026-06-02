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

// MARK: - ManualUnsuppression (D1.d transparency UX)

/// User explicitly un-suppressed a previously frequently-dismissed signal.
/// Lasts `manualUnsuppressionPersistenceSeconds` (14d default) then expires.
/// `viaTrend == true` means the un-suppression was AND-gated against the
/// 7d acceptance-trend criterion at the moment of the user action — useful for
/// post-hoc audit of "was the suggestion in good shape when the user re-enabled it".
struct ManualUnsuppression: Codable, Sendable, Identifiable {
    let id: UUID
    let segment: String
    let signal: String
    let timestamp: Date
    let viaTrend: Bool

    init(segment: String, signal: String, viaTrend: Bool, timestamp: Date = Date()) {
        self.id = UUID()
        self.segment = segment
        self.signal = signal
        self.viaTrend = viaTrend
        self.timestamp = timestamp
    }
}

// MARK: - BlacklistedSignal (D1.d permanent suppression)

/// User explicitly blacklisted a signal permanently. Revoked only by `clearAll()`.
/// `dismissalCountAtBlacklist` is captured for analytics/audit.
struct BlacklistedSignal: Codable, Sendable, Identifiable {
    let id: UUID
    let segment: String
    let signal: String
    let timestamp: Date
    let dismissalCountAtBlacklist: Int

    init(segment: String, signal: String, dismissalCount: Int, timestamp: Date = Date()) {
        self.id = UUID()
        self.segment = segment
        self.signal = signal
        self.dismissalCountAtBlacklist = dismissalCount
        self.timestamp = timestamp
    }
}

// MARK: - RecommendationMemory

final class RecommendationMemory: @unchecked Sendable {

    private let storageKey = "fitme.ai.recommendation_memory"
    private let manualUnsuppressionsKey = "fitme.ai.recommendation_memory.manual_unsuppressions"
    private let blacklistedSignalsKey = "fitme.ai.recommendation_memory.blacklisted_signals"
    private let maxEntriesPerSegment = 200
    /// D1 PRD-frozen constant: manual un-suppression persists 14 days, then expires.
    static let manualUnsuppressionPersistenceSeconds: TimeInterval = 14 * 24 * 60 * 60

    private var outcomes: [RecommendationOutcome] = []
    private var manualUnsuppressions: [ManualUnsuppression] = []
    private var blacklistedSignals: [BlacklistedSignal] = []
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
    /// C5 (2026-06-01) — `within` filters to the last N seconds of dismissals so users can
    /// "rehabilitate" suppressed signals over time. Defaults to 30 days; injectable `now`
    /// keeps tests deterministic.
    func frequentlyDismissedSignals(
        for segment: AISegment,
        threshold: Int = 3,
        within window: TimeInterval = 30 * 24 * 60 * 60,
        now: Date = Date()
    ) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        let dismissed = outcomes.filter {
            $0.segment == segment.rawValue
            && $0.action == .dismissed
            && now.timeIntervalSince($0.timestamp) <= window
        }
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

    // MARK: - D1 Manual Un-suppression (transparency UX)

    /// Returns true when the user has manually un-suppressed `signal` for `segment`
    /// within the 14d persistence window. Expired entries are pruned lazily on read.
    func isManuallyUnsuppressed(
        signal: String,
        in segment: AISegment,
        now: Date = Date()
    ) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return manualUnsuppressions.contains {
            $0.signal == signal
            && $0.segment == segment.rawValue
            && now.timeIntervalSince($0.timestamp) <= Self.manualUnsuppressionPersistenceSeconds
        }
    }

    /// All non-expired manual un-suppressions for `segment`. Useful for Settings UI.
    func manualUnsuppressions(
        for segment: AISegment,
        now: Date = Date()
    ) -> [ManualUnsuppression] {
        lock.lock()
        defer { lock.unlock() }
        return manualUnsuppressions.filter {
            $0.segment == segment.rawValue
            && now.timeIntervalSince($0.timestamp) <= Self.manualUnsuppressionPersistenceSeconds
        }
    }

    /// User confirmed "Un-suppress this signal" on the detail screen.
    /// `viaTrend` records whether the 7d acceptance-trend criterion was also met
    /// at the moment of the un-suppression (AND-gate audit).
    func recordManualUnsuppression(
        signal: String,
        in segment: AISegment,
        viaTrend: Bool,
        timestamp: Date = Date()
    ) {
        lock.lock()
        defer { lock.unlock() }
        manualUnsuppressions.append(
            ManualUnsuppression(
                segment: segment.rawValue,
                signal: signal,
                viaTrend: viaTrend,
                timestamp: timestamp
            )
        )
        saveManualUnsuppressions()
    }

    // MARK: - D1 Blacklist (permanent suppression)

    /// Returns true when `signal` is permanently blacklisted for `segment`.
    /// No time decay — only `clearAll()` revokes a blacklist.
    func isBlacklisted(signal: String, in segment: AISegment) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return blacklistedSignals.contains {
            $0.signal == signal && $0.segment == segment.rawValue
        }
    }

    /// All blacklisted signals for `segment`. Useful for Settings UI.
    func blacklistedSignals(for segment: AISegment) -> [BlacklistedSignal] {
        lock.lock()
        defer { lock.unlock() }
        return blacklistedSignals.filter { $0.segment == segment.rawValue }
    }

    /// User confirmed "Blacklist permanently" on the detail screen.
    /// Idempotent: if the signal is already blacklisted for this segment, no-op.
    func recordBlacklist(
        signal: String,
        in segment: AISegment,
        dismissalCount: Int,
        timestamp: Date = Date()
    ) {
        lock.lock()
        defer { lock.unlock() }
        let alreadyBlacklisted = blacklistedSignals.contains {
            $0.signal == signal && $0.segment == segment.rawValue
        }
        guard !alreadyBlacklisted else { return }
        blacklistedSignals.append(
            BlacklistedSignal(
                segment: segment.rawValue,
                signal: signal,
                dismissalCount: dismissalCount,
                timestamp: timestamp
            )
        )
        saveBlacklistedSignals()
    }

    // MARK: - GDPR / Account Deletion

    func clearAll() {
        lock.lock()
        defer { lock.unlock() }
        outcomes = []
        manualUnsuppressions = []
        blacklistedSignals = []
        UserDefaults.standard.removeObject(forKey: storageKey)
        UserDefaults.standard.removeObject(forKey: manualUnsuppressionsKey)
        UserDefaults.standard.removeObject(forKey: blacklistedSignalsKey)
    }

    // MARK: - Persistence (plain UserDefaults)

    private func save() {
        guard let data = try? JSONEncoder().encode(outcomes) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func saveManualUnsuppressions() {
        guard let data = try? JSONEncoder().encode(manualUnsuppressions) else { return }
        UserDefaults.standard.set(data, forKey: manualUnsuppressionsKey)
    }

    private func saveBlacklistedSignals() {
        guard let data = try? JSONEncoder().encode(blacklistedSignals) else { return }
        UserDefaults.standard.set(data, forKey: blacklistedSignalsKey)
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let loaded = try? JSONDecoder().decode([RecommendationOutcome].self, from: data) {
            outcomes = loaded
        }
        // Backward-compat: D1 fields use separate keys so pre-D1 stores load fine.
        if let data = UserDefaults.standard.data(forKey: manualUnsuppressionsKey),
           let loaded = try? JSONDecoder().decode([ManualUnsuppression].self, from: data) {
            manualUnsuppressions = loaded
        }
        if let data = UserDefaults.standard.data(forKey: blacklistedSignalsKey),
           let loaded = try? JSONDecoder().decode([BlacklistedSignal].self, from: data) {
            blacklistedSignals = loaded
        }
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
