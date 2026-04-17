// FitTracker/Services/Utilities/Debouncer.swift
// Generic debouncer — coalesces rapid-fire calls into a single delayed action.
// Extracted from SupabaseSyncService so it's independently testable.
//
// Usage:
//   let debouncer = Debouncer(delayMilliseconds: 500)
//   debouncer.call { await fetchChanges() }   // starts 500ms timer
//   debouncer.call { await fetchChanges() }   // cancels first, starts new 500ms timer
//   // ... only the most recent closure fires after 500ms idle

import Foundation

/// Debounces async closures — each `call` cancels any pending action and starts a new delay.
/// Thread-safe via `@MainActor` isolation since realtime handlers already hop to the main actor.
@MainActor
final class Debouncer {
    private let delayMilliseconds: Int
    private var task: Task<Void, Never>?

    init(delayMilliseconds: Int) {
        self.delayMilliseconds = delayMilliseconds
    }

    /// Schedule an async action after the debounce interval.
    /// Any pending action is cancelled; only the most recent call's action fires.
    func call(_ action: @escaping @Sendable () async -> Void) {
        task?.cancel()
        task = Task {
            try? await Task.sleep(for: .milliseconds(delayMilliseconds))
            guard !Task.isCancelled else { return }
            await action()
        }
    }

    /// Cancel any pending action without firing it.
    func cancel() {
        task?.cancel()
        task = nil
    }

    /// True when there's a pending action scheduled.
    var hasPending: Bool {
        guard let task else { return false }
        return !task.isCancelled
    }
}
