// Services/WatchConnectivityService.swift
// Tracks Apple Watch reachability and exposes a simple connected/offline status.
// Conditions that cause "Offline":
//   - iPhone or Watch Bluetooth is off
//   - Watch is on its charger (app not running in foreground)
//   - Not in an active training session that keeps the watch app alive
//   - Watch app not installed / watch not paired

import Foundation
import SwiftUI
#if os(iOS)
import WatchConnectivity
#endif

// ─────────────────────────────────────────────────────────
// MARK: – Notification names for Watch ↔ Phone events
// ─────────────────────────────────────────────────────────

extension Notification.Name {
    static let watchRequestedTodayData   = Notification.Name("ft.watchRequestedTodayData")
    static let watchSentSetCompletions   = Notification.Name("ft.watchSentSetCompletions")
    static let watchSentSupplementToggle = Notification.Name("ft.watchSentSupplementToggle")
}

// ─────────────────────────────────────────────────────────
// MARK: – Watch status
// ─────────────────────────────────────────────────────────

enum WatchStatus {
    case connected
    case offline
    case notPaired
    case appNotInstalled

    var label: String {
        switch self {
        case .connected:      "Connected"
        case .offline:        "Offline"
        case .notPaired:      "No Watch"
        case .appNotInstalled: "App Not Installed"
        }
    }

    var dotColor: Color {
        self == .connected ? .green : Color.primary.opacity(0.3)
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – Service
// ─────────────────────────────────────────────────────────

@MainActor
final class WatchConnectivityService: NSObject, ObservableObject {

    @Published var status: WatchStatus = .offline

    override init() {
        super.init()
        #if os(iOS)
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
        #endif
    }

    // ── Internal update ───────────────────────────────────
    #if os(iOS)
    fileprivate func refreshStatus() {
        let session = WCSession.default
        guard session.activationState == .activated else {
            status = .offline
            return
        }
        guard session.isPaired else {
            status = .notPaired
            return
        }
        guard session.isWatchAppInstalled else {
            status = .appNotInstalled
            return
        }
        status = session.isReachable ? .connected : .offline
    }

    // ── Send today's data to Watch ────────────────────────

    /// Push today's exercise list and supplement stack to the paired Watch.
    func sendTodayData(exercises: [ExerciseDefinition],
                       supplements: [SupplementDefinition]) {
        guard WCSession.default.isReachable else { return }

        let watchExercises = exercises.map { ex in
            ["id": ex.id, "name": ex.name,
             "sets": ex.targetSets, "reps": ex.targetReps,
             "category": ex.category.rawValue]
        }
        let watchSupplements = supplements.map { s in
            ["id": s.id, "name": s.name,
             "dose": s.dose, "timing": s.timing.rawValue]
        }

        guard let exData   = try? JSONSerialization.data(withJSONObject: watchExercises),
              let suppData = try? JSONSerialization.data(withJSONObject: watchSupplements) else { return }

        WCSession.default.sendMessage(
            ["exercises": exData, "supplements": suppData],
            replyHandler: nil
        )
    }

    /// Push live HealthKit metrics to the Watch display.
    func sendLiveMetrics(heartRate: Double?, hrv: Double?,
                          calories: Double?, steps: Int?) {
        guard WCSession.default.isReachable else { return }
        var msg: [String: Any] = [:]
        if let hr  = heartRate { msg["heartRate"] = hr }
        if let h   = hrv       { msg["hrv"]       = h }
        if let cal = calories  { msg["calories"]  = cal }
        if let s   = steps     { msg["steps"]     = s }
        guard !msg.isEmpty else { return }
        WCSession.default.sendMessage(msg, replyHandler: nil)
    }
    #endif
}

// ─────────────────────────────────────────────────────────
// MARK: – WCSessionDelegate (iOS only)
// ─────────────────────────────────────────────────────────

#if os(iOS)
extension WatchConnectivityService: WCSessionDelegate {

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor [weak self] in self?.refreshStatus() }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor [weak self] in self?.refreshStatus() }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        Task { @MainActor [weak self] in self?.refreshStatus() }
    }

    nonisolated func session(_ session: WCSession,
                              didReceiveMessage message: [String: Any]) {
        // Handle Watch → Phone messages
        Task { @MainActor in
            // "request": "todayData" — Watch is asking for today's data
            if (message["request"] as? String) == "todayData" {
                // Caller needs to hook up dataStore; logged in RootTabView via .task
                NotificationCenter.default.post(name: .watchRequestedTodayData, object: nil)
            }
            // Set completions from Watch
            if let data = message["setCompletions"] as? Data {
                NotificationCenter.default.post(name: .watchSentSetCompletions, object: data)
            }
            // Supplement toggle from Watch
            if let suppID = message["suppToggle"] as? String,
               let checked = message["checked"] as? Bool {
                NotificationCenter.default.post(
                    name: .watchSentSupplementToggle,
                    object: ["id": suppID, "checked": checked]
                )
            }
        }
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Re-activate after handoff (e.g. when user switches paired watches)
        WCSession.default.activate()
    }
}
#endif
