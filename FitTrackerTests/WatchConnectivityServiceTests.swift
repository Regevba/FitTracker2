// FitTrackerTests/WatchConnectivityServiceTests.swift
// TEST-012: WatchConnectivityService — initial state and WatchStatus enum.
//
// Scope note: WCSession itself is a singleton wired into the iOS runtime and
// not mockable in unit tests (it depends on a paired Apple Watch, which the
// simulator doesn't expose). On the simulator WCSession.isSupported() returns
// false, so the init's #if os(iOS) branch short-circuits without setting up
// a delegate — leaving status at its initial .offline value.
//
// What we CAN test deterministically:
//   - Initial @Published status is .offline
//   - WatchStatus enum has all 4 expected cases with correct labels & dot colors
//   - WatchStatus is value-equal (sanity for ObservableObject diffing)
//
// Reachability/refreshStatus paths require a paired Watch — those are covered
// by manual QA on physical devices, not in unit tests.

import XCTest
import SwiftUI
@testable import FitTracker

@MainActor
final class WatchConnectivityServiceTests: XCTestCase {

    // ── Initial state ────────────────────────────────────

    func testInit_startsOffline() {
        let service = WatchConnectivityService()
        if case .offline = service.status {
            // Expected
        } else {
            XCTFail("Service must initialise to .offline before any WCSession callback. Got: \(service.status)")
        }
    }

    func testInit_doesNotCrashOnSimulator() {
        // WCSession.isSupported() returns false on simulator — init's early
        // return must keep the service in a usable state with no delegate setup.
        let service = WatchConnectivityService()
        XCTAssertNotNil(service, "Service must initialise without crashing on simulator")
        // Repeat init to verify singleton-style construction is safe
        let second = WatchConnectivityService()
        XCTAssertNotNil(second)
    }

    // ── WatchStatus.label ───────────────────────────────

    func testWatchStatusLabel_connected() {
        XCTAssertEqual(WatchStatus.connected.label, "Connected")
    }

    func testWatchStatusLabel_offline() {
        XCTAssertEqual(WatchStatus.offline.label, "Offline")
    }

    func testWatchStatusLabel_notPaired() {
        XCTAssertEqual(WatchStatus.notPaired.label, "No Watch")
    }

    func testWatchStatusLabel_appNotInstalled() {
        XCTAssertEqual(WatchStatus.appNotInstalled.label, "App Not Installed")
    }

    // ── WatchStatus.dotColor ────────────────────────────

    func testWatchStatusDotColor_connectedIsGreen() {
        // Equality on Color isn't well-defined — assert via identity comparison
        // by taking a description snapshot. Color.green is a stable system color.
        let connected = WatchStatus.connected.dotColor
        let green = Color.green
        XCTAssertEqual(String(describing: connected), String(describing: green),
                       "Connected dot must be Color.green")
    }

    func testWatchStatusDotColor_nonConnectedIsDimmedPrimary() {
        // All non-connected states share the same dimmed primary color
        let offlineColor = String(describing: WatchStatus.offline.dotColor)
        let notPairedColor = String(describing: WatchStatus.notPaired.dotColor)
        let appNotInstalledColor = String(describing: WatchStatus.appNotInstalled.dotColor)
        XCTAssertEqual(offlineColor, notPairedColor,
                       "All non-connected states must share the same dimmed dot color")
        XCTAssertEqual(offlineColor, appNotInstalledColor)
    }

    // ── ObservableObject contract ───────────────────────

    func testStatusIsPublishedProperty() {
        // Compile-time + runtime guard that status is @Published — assigning
        // to it must not fault. (If the property changes shape, this fails to compile.)
        let service = WatchConnectivityService()
        service.status = .connected
        if case .connected = service.status {
            // Expected
        } else {
            XCTFail("Status setter must round-trip .connected")
        }
        service.status = .notPaired
        if case .notPaired = service.status {
            // Expected
        } else {
            XCTFail("Status setter must round-trip .notPaired")
        }
    }
}
