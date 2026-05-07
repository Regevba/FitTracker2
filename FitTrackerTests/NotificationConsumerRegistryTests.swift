// FitTrackerTests/NotificationConsumerRegistryTests.swift
// T13 — push-notifications-v2 unit tests for NotificationConsumerRegistry.
// Idempotent registration + URL/type/ID lookup + collision detection.

import XCTest
@testable import FitTracker

@MainActor
final class NotificationConsumerRegistryTests: XCTestCase {

    override func setUp() {
        super.setUp()
        NotificationConsumerRegistry.shared.reset()
    }

    override func tearDown() {
        NotificationConsumerRegistry.shared.reset()
        super.tearDown()
    }

    // MARK: T13/CR-1 — Registration

    func testRegisterStoresConsumerEntry() {
        let consumer = makeConsumer(id: "test.alpha", urls: ["fitme://nav/training"])
        XCTAssertTrue(NotificationConsumerRegistry.shared.register(consumer))
        XCTAssertEqual(NotificationConsumerRegistry.shared.consumer(forID: "test.alpha"), consumer)
    }

    func testRegisterIdempotentForSameID() {
        let v1 = makeConsumer(id: "test.alpha", urls: ["fitme://nav/training"])
        let v2 = makeConsumer(id: "test.alpha", urls: ["fitme://nav/training"], displayName: "v2")
        XCTAssertTrue(NotificationConsumerRegistry.shared.register(v1))
        XCTAssertTrue(NotificationConsumerRegistry.shared.register(v2),
                      "Same-ID re-register replaces in place (last write wins)")
        XCTAssertEqual(NotificationConsumerRegistry.shared.consumer(forID: "test.alpha")?.displayName, "v2")
    }

    func testRegisterRejectsCollisionFromDifferentID() {
        let alpha = makeConsumer(id: "test.alpha", urls: ["fitme://nav/training"])
        let beta  = makeConsumer(id: "test.beta",  urls: ["fitme://nav/training"]) // collides
        XCTAssertTrue(NotificationConsumerRegistry.shared.register(alpha))
        XCTAssertFalse(NotificationConsumerRegistry.shared.register(beta),
                       "Different-ID consumer claiming the same URL must be rejected")
        XCTAssertEqual(NotificationConsumerRegistry.shared.consumer(forID: "test.alpha"), alpha,
                       "Original claim is preserved on rejection")
        XCTAssertNil(NotificationConsumerRegistry.shared.consumer(forID: "test.beta"))
    }

    // MARK: T13/CR-2 — Lookup

    func testLookupByURLPrefix() {
        let consumer = makeConsumer(id: "test.alpha", urls: ["fitme://nav/training"])
        NotificationConsumerRegistry.shared.register(consumer)

        // Exact match
        let match = NotificationConsumerRegistry.shared.consumer(forURL: URL(string: "fitme://nav/training")!)
        XCTAssertEqual(match?.id, "test.alpha")

        // Prefix match (URL has additional path segments)
        let prefixMatch = NotificationConsumerRegistry.shared.consumer(forURL: URL(string: "fitme://nav/training/today")!)
        XCTAssertEqual(prefixMatch?.id, "test.alpha", "Prefix match should resolve to alpha")

        // No match
        XCTAssertNil(NotificationConsumerRegistry.shared.consumer(forURL: URL(string: "fitme://nav/stats")!))
    }

    func testLookupByTypeIdentifier() {
        let consumer = makeConsumer(
            id: "test.alpha",
            urls: ["fitme://nav/training"],
            types: ["typeA", "typeB"]
        )
        NotificationConsumerRegistry.shared.register(consumer)

        XCTAssertEqual(NotificationConsumerRegistry.shared.consumer(forType: "typeA")?.id, "test.alpha")
        XCTAssertEqual(NotificationConsumerRegistry.shared.consumer(forType: "typeB")?.id, "test.alpha")
        XCTAssertNil(NotificationConsumerRegistry.shared.consumer(forType: "unknown"))
    }

    // MARK: T13/CR-3 — Inventory

    func testAllURLPatternsAggregatesAcrossConsumers() {
        let alpha = makeConsumer(id: "test.alpha", urls: ["fitme://nav/training"])
        let beta  = makeConsumer(id: "test.beta",  urls: ["fitme://nav/stats", "fitme://nav/nutrition"])
        NotificationConsumerRegistry.shared.register(alpha)
        NotificationConsumerRegistry.shared.register(beta)

        let all = NotificationConsumerRegistry.shared.allURLPatterns()
        XCTAssertEqual(Set(all), Set([
            "fitme://nav/training",
            "fitme://nav/stats",
            "fitme://nav/nutrition",
        ]))
    }

    // MARK: - Helper

    private func makeConsumer(
        id: String,
        urls: [String],
        types: [String] = ["defaultType"],
        displayName: String = "Test Consumer"
    ) -> NotificationConsumerRegistry.Consumer {
        NotificationConsumerRegistry.Consumer(
            id: id,
            displayName: displayName,
            typeIdentifiers: types,
            urlPatterns: urls,
            primaryCapTag: .standard
        )
    }
}
