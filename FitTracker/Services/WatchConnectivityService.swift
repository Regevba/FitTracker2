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
// MARK: – Watch status
// ─────────────────────────────────────────────────────────

enum WatchStatus {
    case connected
    case offline
    case notPaired

    var label: String {
        switch self {
        case .connected: "Connected"
        case .offline:   "Offline"
        case .notPaired: "No Watch"
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
        status = session.isReachable ? .connected : .offline
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

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Re-activate after handoff (e.g. when user switches paired watches)
        WCSession.default.activate()
    }
}
#endif
