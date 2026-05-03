// FitTracker/Services/Reminders/CohortPriorClient.swift
//
// HTTP client for the AI-engine reminder-cohort endpoints.
//
// Two methods:
//   • POST /reminder-cohort-event   — fire-and-forget write of a (type, hour, tapped)
//                                     observation. Payload contains *only* those three
//                                     keys; no userId, deviceId, locale, or timestamp
//                                     leaks to the cohort surface (GDPR posture per
//                                     spec §6).
//   • GET  /reminder-cohort-priors  — read the population prior + kill-flag list.
//
// Errors are propagated to the caller (`FitTrackerApp`, Task 10) so the
// caller can decide whether to swallow (PR 1, no UI surface) or surface
// (PR 3, "Why this time?" affordance).
//
// `URLSessionProtocol` injection lets unit tests substitute a deterministic
// mock without hitting the real network.

import Foundation


// MARK: - Session injection seam

protocol URLSessionProtocol {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionProtocol {}


// MARK: - Wire-format response

/// Server-side response shape for `GET /reminder-cohort-priors`.
///
/// `priors` is a per-type histogram: `priors["nutrition_gap"]["16"] = 0.34`
/// means the cohort taps that type at hour 16 about 34% of the time.
/// `killFlags` is a list of `ReminderType.rawValue` strings whose per-type
/// metric crossed the kill threshold; the client should revert those types
/// to their static fire times until the flag clears.
struct CohortPriorResponse: Codable {
    let priors: [String: [String: Double]]
    let killFlags: [String]

    enum CodingKeys: String, CodingKey {
        case priors
        case killFlags = "kill_flags"
    }
}


// MARK: - Client

final class CohortPriorClient {

    private let baseURL: URL
    private let session: URLSessionProtocol

    init(baseURL: URL, session: URLSessionProtocol = URLSession.shared) {
        self.baseURL = baseURL
        self.session = session
    }

    /// POST `/reminder-cohort-event` with the minimum-PII payload.
    ///
    /// Per spec §6 the payload MUST contain only `{type, hour, tapped}`.
    /// Adding any caller-identifying field here would void the cohort
    /// surface's GDPR posture; the test `testRecordEvent_payloadContainsOnlyAllowedKeys`
    /// asserts the keyset on every change.
    func recordEvent(type: ReminderType, hour: Int, tapped: Bool) async throws {
        precondition((0..<24).contains(hour), "hour must be in 0..<24")
        let url = baseURL.appendingPathComponent("reminder-cohort-event")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload: [String: Any] = [
            "type":   type.rawValue,
            "hour":   hour,
            "tapped": tapped,
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        _ = try await session.data(for: req)
    }

    /// GET `/reminder-cohort-priors`. Returns the population prior + kill flags.
    func fetchPriors() async throws -> CohortPriorResponse {
        let url = baseURL.appendingPathComponent("reminder-cohort-priors")
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        let (data, _) = try await session.data(for: req)
        return try JSONDecoder().decode(CohortPriorResponse.self, from: data)
    }
}
