// Services/MilestoneDetector.swift
// Audit UI-018 + UI-006: business logic + state previously held inline as
// @State in MainScreenView (v2). Extracted to an ObservableObject so the
// view layer stays focused on presentation; the detector owns the
// "have-we-shown-this-milestone-yet" memory and the milestone-presentation
// state (title/message + dismissal). Keeps the view's @State count below
// the 500-line / 12-var refactor threshold.
//
// Pure Swift, no UIKit imports — testable in isolation.

import SwiftUI

/// Owns milestone detection + presentation state for the home screen.
/// The view binds to `presentedMilestone` for modal presentation; calls
/// `evaluate(streakMilestone:currentPhase:)` once per data refresh; and
/// calls `dismissPresented()` when the user taps through the modal.
@MainActor
final class MilestoneDetector: ObservableObject {

    /// Currently-presented milestone (nil = nothing to show). The view
    /// observes this for `.fullScreenCover` presentation.
    @Published var presentedMilestone: Milestone?

    /// Last streak milestone we've already shown — prevents re-showing the
    /// same number on every data refresh.
    private var lastShownStreak: Int = 0

    /// Last program phase we've recorded — set on first evaluate, then a
    /// transition triggers a phase milestone.
    private var lastShownPhase: ProgramPhase?

    struct Milestone: Equatable {
        let title: String
        let message: String
    }

    /// Evaluate whether a new milestone should be presented.
    /// - Parameters:
    ///   - streakMilestone: the next streak threshold reached (e.g. 7, 30, 100), or nil
    ///   - currentPhase: the user's current program phase (used to detect phase transitions)
    /// - Returns: true if a new milestone was set on `presentedMilestone`
    @discardableResult
    func evaluate(streakMilestone: Int?, currentPhase: ProgramPhase) -> Bool {
        // Don't double-present
        guard presentedMilestone == nil else { return false }

        // Streak milestone takes precedence
        if let milestone = streakMilestone, milestone != lastShownStreak {
            lastShownStreak = milestone
            presentedMilestone = Milestone(
                title: "\(milestone)-Day Streak!",
                message: "\(milestone) days straight. Consistency beats intensity every time."
            )
            return true
        }

        // Phase transition (skip the very first evaluate — that's just baseline capture)
        guard let lastPhase = lastShownPhase else {
            lastShownPhase = currentPhase
            return false
        }
        if currentPhase != lastPhase {
            lastShownPhase = currentPhase
            presentedMilestone = Milestone(
                title: "Phase Complete!",
                message: "Welcome to \(currentPhase.rawValue). A new chapter begins."
            )
            return true
        }
        return false
    }

    /// Clear the presented milestone (called when the modal is dismissed).
    /// Memory of `lastShownStreak` and `lastShownPhase` persists so the
    /// same milestone won't re-trigger.
    func dismissPresented() {
        presentedMilestone = nil
    }
}
