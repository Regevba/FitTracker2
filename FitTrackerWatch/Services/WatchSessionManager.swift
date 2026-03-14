// FitTrackerWatch/Services/WatchSessionManager.swift
// WCSession delegate — bidirectional phone ↔ watch communication
// Receives: today's exercise list, supplement list
// Sends: set completions, supplement toggles

import Foundation
import WatchConnectivity
import SwiftUI

// ─────────────────────────────────────────────────────────
// MARK: – Shared data models (lightweight, watch-side)
// ─────────────────────────────────────────────────────────

struct WatchExercise: Identifiable, Codable {
    var id:       String
    var name:     String
    var sets:     Int
    var reps:     String
    var category: String
    var isCompleted: Bool = false
}

struct WatchSupplement: Identifiable, Codable {
    var id:         String
    var name:       String
    var dose:       String
    var timing:     String   // "morning" or "evening"
    var isChecked:  Bool = false
}

struct WatchSetEntry: Codable {
    var exerciseID: String
    var setNumber:  Int
    var weightKg:   Double?
    var reps:       Int?
    var timestamp:  Date = Date()
}

// ─────────────────────────────────────────────────────────
// MARK: – Watch Session Manager
// ─────────────────────────────────────────────────────────

@MainActor
final class WatchSessionManager: NSObject, ObservableObject {

    @Published var exercises:          [WatchExercise]    = []
    @Published var supplements:        [WatchSupplement]  = []
    @Published var completedSets:      [WatchSetEntry]    = []
    @Published var isPhoneReachable:   Bool               = false

    // Live metrics from HealthKit (pushed by phone or Watch HKWorkout session)
    @Published var currentHR:          Double?
    @Published var currentHRV:         Double?
    @Published var calories:           Double?
    @Published var steps:              Int?
    @Published var sessionElapsed:     TimeInterval       = 0
    @Published var isSessionActive:    Bool               = false

    private var sessionTimer: Timer?
    private var sessionStart: Date?

    override init() {
        super.init()
        #if os(watchOS)
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
        #endif
    }

    // ── Session control ───────────────────────────────────

    func startSession() {
        isSessionActive = true
        sessionStart = Date()
        sessionElapsed = 0
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let start = self.sessionStart else { return }
                self.sessionElapsed = Date().timeIntervalSince(start)
            }
        }
    }

    func endSession() {
        isSessionActive = false
        sessionTimer?.invalidate()
        sessionTimer = nil
        // Send all logged sets back to phone
        sendCompletionsToPhone()
    }

    // ── Set logging ───────────────────────────────────────

    func logSet(exerciseID: String, setNumber: Int, weightKg: Double?, reps: Int?) {
        let entry = WatchSetEntry(exerciseID: exerciseID, setNumber: setNumber,
                                   weightKg: weightKg, reps: reps)
        completedSets.append(entry)
        // Mark exercise as completed if all sets done
        if let idx = exercises.firstIndex(where: { $0.id == exerciseID }) {
            let doneSets = completedSets.filter { $0.exerciseID == exerciseID }.count
            if doneSets >= exercises[idx].sets {
                exercises[idx].isCompleted = true
            }
        }
    }

    // ── Supplement toggle ─────────────────────────────────

    func toggleSupplement(_ id: String) {
        if let idx = supplements.firstIndex(where: { $0.id == id }) {
            supplements[idx].isChecked.toggle()
            sendSupplementToggle(id: id, checked: supplements[idx].isChecked)
        }
    }

    // ── WCSession messaging ───────────────────────────────

    private func sendCompletionsToPhone() {
        guard WCSession.default.isReachable,
              let data = try? JSONEncoder().encode(completedSets) else { return }
        WCSession.default.sendMessage(["setCompletions": data], replyHandler: nil)
    }

    private func sendSupplementToggle(id: String, checked: Bool) {
        guard WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(["suppToggle": id, "checked": checked], replyHandler: nil)
    }

    func requestTodayData() {
        guard WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(["request": "todayData"], replyHandler: nil)
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – WCSessionDelegate
// ─────────────────────────────────────────────────────────

extension WatchSessionManager: WCSessionDelegate {

    nonisolated func session(_ session: WCSession,
                              activationDidCompleteWith state: WCSessionActivationState,
                              error: Error?) {
        Task { @MainActor in
            self.isPhoneReachable = session.isReachable
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isPhoneReachable = session.isReachable
            if session.isReachable { self.requestTodayData() }
        }
    }

    nonisolated func session(_ session: WCSession,
                              didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            // Receive today's exercise + supplement list from phone
            if let exData = message["exercises"] as? Data,
               let exList = try? JSONDecoder().decode([WatchExercise].self, from: exData) {
                self.exercises = exList
            }
            if let suppData = message["supplements"] as? Data,
               let suppList = try? JSONDecoder().decode([WatchSupplement].self, from: suppData) {
                self.supplements = suppList
            }
            // Live metrics
            if let hr = message["heartRate"] as? Double { self.currentHR = hr }
            if let hrv = message["hrv"] as? Double { self.currentHRV = hrv }
            if let cal = message["calories"] as? Double { self.calories = cal }
            if let steps = message["steps"] as? Int { self.steps = steps }
        }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
    #endif
}
