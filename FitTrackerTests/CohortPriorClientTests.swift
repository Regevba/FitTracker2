// FitTrackerTests/CohortPriorClientTests.swift
//
// CohortPriorClient — three tests covering the contract:
//   1. POST payload contains ONLY {type, hour, tapped} — no PII leak
//   2. Network errors propagate (caller swallows / surfaces as appropriate)
//   3. fetchPriors decodes the canonical response shape
//
// `MockURLSession` is the test double — captures last request, supports
// canned responses + injected errors, never hits the network.

import XCTest
@testable import FitTracker

@MainActor
final class CohortPriorClientTests: XCTestCase {

    // MARK: - 1) no-PII payload

    func testRecordEvent_payloadContainsOnlyAllowedKeys() async throws {
        let session = MockURLSession()
        let client = CohortPriorClient(
            baseURL: URL(string: "https://test.local")!,
            session: session
        )

        try await client.recordEvent(type: .nutritionGap, hour: 16, tapped: true)

        let request = try XCTUnwrap(session.lastRequest)
        let body = try XCTUnwrap(request.httpBody)
        let json = try JSONSerialization.jsonObject(with: body) as? [String: Any] ?? [:]

        XCTAssertEqual(
            Set(json.keys),
            Set(["type", "hour", "tapped"]),
            "Payload must contain only {type, hour, tapped} — no PII"
        )
        XCTAssertEqual(json["type"] as? String, "nutrition_gap")
        XCTAssertEqual(json["hour"] as? Int, 16)
        XCTAssertEqual(json["tapped"] as? Bool, true)
    }

    // MARK: - 2) network error propagates

    func testRecordEvent_networkError_propagates() async {
        let session = MockURLSession()
        session.error = URLError(.notConnectedToInternet)
        let client = CohortPriorClient(
            baseURL: URL(string: "https://test.local")!,
            session: session
        )

        do {
            try await client.recordEvent(type: .nutritionGap, hour: 16, tapped: true)
            XCTFail("Should have thrown")
        } catch is URLError {
            // Expected — caller (FitTrackerApp) is responsible for catch/swallow.
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - 3) fetchPriors decodes the wire format

    func testFetchPriors_decodesResponse() async throws {
        let session = MockURLSession()
        session.canned = """
        {
          "priors": { "nutrition_gap": { "16": 0.34, "17": 0.41 } },
          "kill_flags": ["engagement"]
        }
        """.data(using: .utf8)!

        let client = CohortPriorClient(
            baseURL: URL(string: "https://test.local")!,
            session: session
        )

        let response = try await client.fetchPriors()
        XCTAssertEqual(response.priors["nutrition_gap"]?["17"], 0.41)
        XCTAssertEqual(response.priors["nutrition_gap"]?["16"], 0.34)
        XCTAssertEqual(response.killFlags, ["engagement"])
    }
}


// MARK: - Mock

/// Deterministic test double — captures the most recent request, supports
/// canned response bodies + injected errors. Never hits the network.
private final class MockURLSession: URLSessionProtocol {
    var lastRequest: URLRequest?
    var error: Error?
    var canned: Data = Data()

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        if let e = error { throw e }
        let status = canned.isEmpty ? 204 : 200
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: status,
            httpVersion: nil,
            headerFields: nil
        )!
        return (canned, response)
    }
}
