// Services/Notifications/NotificationConsumerRegistry.swift
//
// Registration mechanism for the notification platform layer. Consumers
// (smart-reminders, ReadinessAlertObserver, future modules) register their
// type identifiers + URL patterns + cap contributions at app-init time. The
// registry is queried by:
//   - DeepLinkRouter — "given URL X, which consumer + action?"
//   - Analytics — "given a delivered notification's userInfo, which consumer fired it?"
//
// Owned by: push-notifications-v2 (FIT-23).
//
// Registration is idempotent for the same `id` (last-write-wins). Registration
// from a DIFFERENT id claiming a URL pattern already owned is REJECTED (returns
// false). This prevents two consumers from silently colliding on the same URL.

import Foundation

@MainActor
final class NotificationConsumerRegistry: ObservableObject {

    static let shared = NotificationConsumerRegistry()

    /// A registered notification consumer.
    ///
    /// `urlPatterns` is matched by prefix when DeepLinkRouter resolves an incoming URL.
    /// Use the most specific prefix that uniquely identifies your consumer's URL space.
    struct Consumer: Equatable {
        let id: String
        let displayName: String
        let typeIdentifiers: [String]
        let urlPatterns: [String]
        let primaryCapTag: NotificationTag
    }

    private(set) var consumers: [String: Consumer] = [:]

    private init() {}

    // MARK: Registration

    /// Registers (or replaces) a consumer.
    ///
    /// Returns `true` on success. Returns `false` if any of `consumer.urlPatterns`
    /// is already claimed by a *different* consumer ID — the existing claim is
    /// preserved and no partial registration occurs.
    @discardableResult
    func register(_ consumer: Consumer) -> Bool {
        // Check pattern collisions with other consumer IDs only
        for pattern in consumer.urlPatterns {
            for (otherID, other) in consumers where otherID != consumer.id {
                if other.urlPatterns.contains(pattern) {
                    return false
                }
            }
        }
        consumers[consumer.id] = consumer
        return true
    }

    /// Removes a consumer's registration. Idempotent.
    func unregister(consumerID: String) {
        consumers.removeValue(forKey: consumerID)
    }

    /// Wipes the registry. Test-only / sign-out / app-reset scenarios.
    func reset() {
        consumers.removeAll()
    }

    // MARK: Lookup

    func consumer(forID id: String) -> Consumer? {
        consumers[id]
    }

    /// Returns the consumer whose URL pattern table prefix-matches the given URL.
    /// Returns `nil` if no consumer claims this URL space.
    func consumer(forURL url: URL) -> Consumer? {
        let s = url.absoluteString
        return consumers.values.first { c in
            c.urlPatterns.contains { pattern in s.hasPrefix(pattern) }
        }
    }

    /// Returns the consumer whose type identifier list contains the given identifier.
    /// Used for analytics attribution on notification taps.
    func consumer(forType typeIdentifier: String) -> Consumer? {
        consumers.values.first { $0.typeIdentifiers.contains(typeIdentifier) }
    }

    // MARK: Inventory

    /// All registered URL patterns across all consumers, deduplicated.
    /// Useful for `/ux preflight`-style tests that enumerate every registered URL.
    func allURLPatterns() -> [String] {
        Array(Set(consumers.values.flatMap(\.urlPatterns))).sorted()
    }

    /// All registered consumer IDs.
    func allConsumerIDs() -> [String] {
        consumers.keys.sorted()
    }
}
