// FitTrackerTests/PushNotificationsReachabilityTests.swift
// T14 — Reachability gate (push-notifications-v2). Codifies the v1 UI-016
// partial-ship lesson into a mechanical check: every user-facing entry point
// in the PRD must be reachable from a real navigation path, not just a
// unit-test harness on the substrate.
//
// 3 cases (P0, non-skippable per PRD §"Test & Eval Requirements"):
//   1. Priming-trigger reachability — FirstWorkoutTrigger.mark() fires the
//      .fitMeFirstWorkoutCompleted notification exactly once per device
//      install. FitTrackerApp's `.onReceive` for this notification is the
//      wire that drives the priming sheet presentation; if the trigger
//      didn't fire, no priming sheet would ever appear (v1's UI-016 mode).
//   2. URL routing reachability — every URL pattern registered with
//      NotificationConsumerRegistry resolves to a DeepLinkAction, and a
//      real Combine subscriber observes pendingDeepLink emission.
//   3. Notification-source routing — DeepLinkRouter.handle(url, source: .notification)
//      routes end-to-end (URL → action → subscriber receives), simulating
//      what happens when a notification is tapped and the consumer delegate
//      hands the URL to the platform router.

import XCTest
import Combine
@testable import FitTracker

@MainActor
final class PushNotificationsReachabilityTests: XCTestCase {

    private var cancellables: Set<AnyCancellable> = []

    override func setUp() {
        super.setUp()
        FirstWorkoutTrigger._resetForTesting()
        DeepLinkRouter.shared.consume()
        DeepLinkRouter.shared._resetDedupForTesting()
        NotificationConsumerRegistry.shared.reset()
        cancellables.removeAll()
    }

    override func tearDown() {
        FirstWorkoutTrigger._resetForTesting()
        DeepLinkRouter.shared.consume()
        DeepLinkRouter.shared._resetDedupForTesting()
        NotificationConsumerRegistry.shared.reset()
        cancellables.removeAll()
        super.tearDown()
    }

    // MARK: T14/RG-1 — Priming-trigger reachability

    /// FirstWorkoutTrigger.mark() posts .fitMeFirstWorkoutCompleted exactly once.
    /// Subsequent calls are no-ops (a second workout doesn't re-prime).
    /// This is the wire that, if missing in v1, was what made UI-016 happen.
    func test_firstWorkoutTrigger_postsExactlyOnce() {
        XCTAssertFalse(FirstWorkoutTrigger.hasCompleted, "Pre-state: not completed")

        var observedCount = 0
        let observer = NotificationCenter.default.addObserver(
            forName: .fitMeFirstWorkoutCompleted,
            object: nil,
            queue: nil
        ) { _ in
            observedCount += 1
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        FirstWorkoutTrigger.mark()
        XCTAssertEqual(observedCount, 1, "First mark() must fire the notification")
        XCTAssertTrue(FirstWorkoutTrigger.hasCompleted, "Flag must persist")

        // Second call — no-op (idempotent + doesn't re-fire)
        FirstWorkoutTrigger.mark()
        XCTAssertEqual(observedCount, 1, "Second mark() must NOT re-fire (idempotent)")
    }

    // MARK: T14/RG-2 — URL routing reachability (parameterized)

    /// Every URL pattern registered with NotificationConsumerRegistry resolves
    /// to a DeepLinkAction. A real Combine subscriber observes the pendingDeepLink
    /// emission — this is the test that, had it existed for smart-reminders,
    /// would have caught the .fitMeReminderTapped no-consumer gap surfaced in
    /// research §6.1 of push-notifications-v2.
    func test_everyRegisteredURL_routes_andSubscriberObservesEmission() {
        // Register the v2 platform's first consumer (readinessAlert).
        // In production, FitTrackerApp registers this at app init.
        NotificationConsumerRegistry.shared.register(
            ReadinessAlertObserver.consumerRegistration
        )

        // Subscribe with Combine — this simulates the SwiftUI root's
        // .onChange(of:) binding from RootTabView (T6).
        var observed: [DeepLinkAction] = []
        DeepLinkRouter.shared.$pendingDeepLink
            .compactMap { $0 }
            .sink { action in observed.append(action) }
            .store(in: &cancellables)

        // For each registered URL pattern, route through DeepLinkRouter
        let patterns = NotificationConsumerRegistry.shared.allURLPatterns()
        XCTAssertFalse(patterns.isEmpty, "Registry must have at least one pattern after registration")

        for pattern in patterns {
            DeepLinkRouter.shared._resetDedupForTesting()
            DeepLinkRouter.shared.consume()
            guard let url = URL(string: pattern) else {
                XCTFail("Registered pattern is not a valid URL: \(pattern)")
                continue
            }
            let outcome = DeepLinkRouter.shared.handle(url: url, source: .url)
            XCTAssertEqual(outcome, .succeeded, "Routing must succeed for registered pattern \(pattern)")
        }

        // Subscriber must have received as many actions as registered patterns
        XCTAssertEqual(observed.count, patterns.count,
                       "SwiftUI subscriber must observe one DeepLinkAction emission per routed pattern")
    }

    // MARK: T14/RG-3 — Notification-source end-to-end

    /// Simulates the notification-tap path. ReminderNotificationDelegate
    /// receives a UNNotificationResponse, extracts the deepLink, and (in v2)
    /// hands it to DeepLinkRouter.handle(url, source: .notification). The
    /// router emits pendingDeepLink; the SwiftUI subscriber observes navigation.
    /// Asserts the full pipeline lands on the expected destination.
    func test_notificationSource_routesEndToEnd_toExpectedDestination() {
        // Wire a Combine subscriber (the SwiftUI root analog)
        var observed: DeepLinkAction?
        DeepLinkRouter.shared.$pendingDeepLink
            .compactMap { $0 }
            .sink { action in observed = action }
            .store(in: &cancellables)

        // Simulate a notification tap with the deep-link payload that smart-reminders
        // would attach (per ReminderType.deepLink for trainingDay)
        let url = URL(string: "fitme://nav/training")!
        let outcome = DeepLinkRouter.shared.handle(url: url, source: .notification)

        XCTAssertEqual(outcome, .succeeded)
        XCTAssertEqual(observed, .navigateToTab(.training),
                       "End-to-end: notification source → DeepLinkRouter → subscriber landing on expected destination")
    }
}
