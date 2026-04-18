// AI/AIEngineClient.swift
// URLSession-based client for the FitTracker AI engine (Python FastAPI).
// Protocol-driven for testability — swap AIEngineClientProtocol in XCTest
// using URLProtocol mocks without hitting a live server.

import Foundation

// ─────────────────────────────────────────────────────────
// MARK: – Protocol (testability seam)
// ─────────────────────────────────────────────────────────

public protocol AIEngineClientProtocol: Sendable {
    func fetchInsight(
        segment: AISegment,
        payload: [String: String],
        jwt: String
    ) async throws -> AIRecommendation
}

// ─────────────────────────────────────────────────────────
// MARK: – Live URLSession implementation
// ─────────────────────────────────────────────────────────

public final class AIEngineClient: AIEngineClientProtocol {

    private let baseURL: URL
    private let session: URLSession

    /// - Parameter baseURL: Railway deployment URL, e.g. https://fittracker-ai.up.railway.app
    public init(
        baseURL: URL,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
    }

    public func fetchInsight(
        segment: AISegment,
        payload: [String: String],
        jwt: String
    ) async throws -> AIRecommendation {
        // Audit AI-013 / DEEP-AI-006: lightweight JWT expiry pre-check. The
        // server still validates signature + expiry — this just avoids a
        // round-trip when the token is locally provably expired. A token
        // we can't decode is treated as valid (server is the source of truth).
        if Self.isExpired(jwt: jwt) {
            throw AIEngineError.unauthorised
        }

        let url = baseURL
            .appendingPathComponent("v1")
            .appendingPathComponent(segment.rawValue)
            .appendingPathComponent("insight")

        var request = URLRequest(url: url, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw AIEngineError.invalidResponse
        }

        switch http.statusCode {
        case 200:
            let decoder = JSONDecoder()
            return try decoder.decode(AIRecommendation.self, from: data)
        case 401, 403:
            throw AIEngineError.unauthorised
        case 429:
            throw AIEngineError.rateLimited
        default:
            throw AIEngineError.serverError(statusCode: http.statusCode)
        }
    }
}

// MARK: - JWT helpers

extension AIEngineClient {
    /// Decode the unsigned middle segment of a JWT and return true if the
    /// `exp` claim is in the past. Tokens we can't parse are treated as
    /// non-expired (the server is the source of truth for signature + expiry).
    static func isExpired(jwt: String, now: Date = Date()) -> Bool {
        let parts = jwt.split(separator: ".")
        guard parts.count == 3 else { return false }
        let payloadSegment = String(parts[1])
        // JWT uses base64url; pad to a multiple of 4 and translate URL-safe chars.
        var padded = payloadSegment
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = padded.count % 4
        if remainder > 0 { padded += String(repeating: "=", count: 4 - remainder) }
        guard
            let data = Data(base64Encoded: padded),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let exp = (json["exp"] as? NSNumber)?.doubleValue ?? (json["exp"] as? Double)
        else {
            return false
        }
        return Date(timeIntervalSince1970: exp) <= now
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – Error types
// ─────────────────────────────────────────────────────────

public enum AIEngineError: Error, Sendable {
    case invalidResponse
    case unauthorised
    case rateLimited
    case serverError(statusCode: Int)
    case encodingFailed
}
