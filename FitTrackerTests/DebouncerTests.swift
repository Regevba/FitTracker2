// FitTrackerTests/DebouncerTests.swift
// Tests for Debouncer utility extracted from SupabaseSyncService.
// Covers the coalescing behavior that prevents concurrent fetch storms.

import XCTest
@testable import FitTracker

@MainActor
final class DebouncerTests: XCTestCase {

    // MARK: - Single call fires after delay

    func testSingleCall_firesActionAfterDelay() async throws {
        let debouncer = Debouncer(delayMilliseconds: 50)
        let expectation = expectation(description: "action fires")
        var fireCount = 0

        debouncer.call {
            await MainActor.run {
                fireCount += 1
                expectation.fulfill()
            }
        }

        XCTAssertTrue(debouncer.hasPending, "Action must be pending immediately after call")
        await fulfillment(of: [expectation], timeout: 0.5)
        XCTAssertEqual(fireCount, 1)
    }

    // MARK: - Multiple rapid calls coalesce to one

    func testRapidCalls_coalesceIntoSingleFire() async throws {
        let debouncer = Debouncer(delayMilliseconds: 50)
        let counter = ActorCounter()

        // Fire 5 rapid calls
        for _ in 0..<5 {
            debouncer.call {
                await counter.increment()
            }
        }

        try await Task.sleep(for: .milliseconds(200))
        let count = await counter.value
        XCTAssertEqual(count, 1,
                       "5 rapid calls must coalesce into 1 fire, not 5")
    }

    // MARK: - Cancel prevents firing

    func testCancel_preventsAction() async throws {
        let debouncer = Debouncer(delayMilliseconds: 50)
        let counter = ActorCounter()

        debouncer.call {
            await counter.increment()
        }
        XCTAssertTrue(debouncer.hasPending)

        debouncer.cancel()
        XCTAssertFalse(debouncer.hasPending, "hasPending must be false after cancel")

        try await Task.sleep(for: .milliseconds(150))
        let count = await counter.value
        XCTAssertEqual(count, 0, "Cancelled action must never fire")
    }

    // MARK: - Second call after delay fires independently

    func testCall_afterPreviousFired_firesAgain() async throws {
        let debouncer = Debouncer(delayMilliseconds: 30)
        let counter = ActorCounter()

        debouncer.call { await counter.increment() }
        try await Task.sleep(for: .milliseconds(100))
        debouncer.call { await counter.increment() }
        try await Task.sleep(for: .milliseconds(100))

        let count = await counter.value
        XCTAssertEqual(count, 2, "Two calls separated by > delay should both fire")
    }
}

// MARK: - Test helper

private actor ActorCounter {
    private(set) var value = 0

    func increment() {
        value += 1
    }
}
