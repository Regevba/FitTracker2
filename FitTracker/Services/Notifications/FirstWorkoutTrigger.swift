// Services/Notifications/FirstWorkoutTrigger.swift
//
// Tracks the first-workout-completed event for the push-notifications-v2
// permission-priming trigger. Per ux-foundations.md §5.3 + PRD PN-4, the
// priming surface is shown after the user invests ≥30 min in a workout — NOT
// at first-app-open — to maximize Progressive Profiling (#12) and opt-in rate.
//
// The trigger fires exactly once per device install:
//   - Persistent flag in UserDefaults marks completion
//   - Subsequent workout completions are no-ops
//
// Owned by: push-notifications-v2 (FIT-23). Wired by FitTrackerApp.swift (T6)
// and called by TrainingPlanView v2 SessionCompletionSheet's `onDone` callback.

import Foundation

extension Notification.Name {
    /// Posted ONCE when the user completes their first workout on this device.
    /// Subscribers (FitTrackerApp) present the notification permission priming sheet.
    static let fitMeFirstWorkoutCompleted = Notification.Name("fitme.first_workout.completed")
}

enum FirstWorkoutTrigger {

    private static let completedKey = "ft.first_workout.completed_at"

    /// Returns `true` if this device has already recorded a first-workout completion.
    static var hasCompleted: Bool {
        UserDefaults.standard.object(forKey: completedKey) != nil
    }

    /// Records a workout completion. Posts `.fitMeFirstWorkoutCompleted` only on the
    /// FIRST call per device install. Subsequent calls are no-ops.
    ///
    /// Call from any post-workout-save call site. Currently wired from
    /// TrainingPlanView v2 SessionCompletionSheet `onDone`.
    static func mark(at date: Date = Date()) {
        guard !hasCompleted else { return }
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: completedKey)
        NotificationCenter.default.post(name: .fitMeFirstWorkoutCompleted, object: nil)
    }

    #if DEBUG
    /// Test-only: clears the completion flag so subsequent `mark()` calls fire
    /// the notification again. Used by T14 reachability gate XCTests.
    static func _resetForTesting() {
        UserDefaults.standard.removeObject(forKey: completedKey)
    }
    #endif
}
