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
