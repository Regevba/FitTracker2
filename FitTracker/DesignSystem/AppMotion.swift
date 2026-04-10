// FitTracker/DesignSystem/AppMotion.swift
// Motion tokens — duration, spring, and easing constants.
// Use these instead of inline animation literals.
// Reduce-motion helpers respect UIAccessibility.isReduceMotionEnabled.
import SwiftUI

// MARK: - Duration
enum AppDuration {
    /// Instant feedback: button press, toggle — 100 ms
    static let instant:  Double = 0.10
    /// Micro: icon swap, badge update — 150 ms
    static let micro:    Double = 0.15
    /// Short: chip appear, row highlight — 200 ms
    static let short:    Double = 0.20
    /// Standard: card appear, sheet expand — 300 ms
    static let standard: Double = 0.30
    /// Long: page transition, onboarding — 450 ms
    static let long:     Double = 0.45
    /// Extra-long: celebration, milestone — 600 ms
    static let xLong:    Double = 0.60
}

// MARK: - Spring presets
enum AppSpring {
    /// Snappy: interactive controls
    static let snappy   = Animation.spring(response: 0.30, dampingFraction: 0.72)
    /// Bouncy: achievement, milestone
    static let bouncy   = Animation.spring(response: 0.45, dampingFraction: 0.60)
    /// Smooth: card transitions
    static let smooth   = Animation.spring(response: 0.40, dampingFraction: 0.85)
    /// Stiff: overlay/sheet dismiss
    static let stiff    = Animation.spring(response: 0.25, dampingFraction: 0.90)
    /// Progress: animated progress bars — softer, slower spring for visual indicators
    static let progress = Animation.spring(response: 0.55, dampingFraction: 0.80)
}

// MARK: - Easing
enum AppEasing {
    static let standard  = Animation.easeInOut(duration: AppDuration.standard)
    static let short     = Animation.easeInOut(duration: AppDuration.short)
    static let instant   = Animation.easeOut(duration: AppDuration.instant)
    static let linear    = Animation.linear(duration: AppDuration.standard)
}

// MARK: - Reduce-motion helpers
extension Animation {
    /// Returns `self` normally; returns `.instant` if reduce motion is on.
    var accessibilityAdapted: Animation {
        UIAccessibility.isReduceMotionEnabled ? .easeOut(duration: 0.01) : self
    }
}

/// Conditional animation modifier — applies `animation` unless reduce motion is enabled.
struct MotionSafe: ViewModifier {
    let animation: Animation
    let value: AnyHashable

    func body(content: Content) -> some View {
        if UIAccessibility.isReduceMotionEnabled {
            content
        } else {
            content.animation(animation, value: value)
        }
    }
}

extension View {
    func motionSafe<V: Hashable>(_ animation: Animation, value: V) -> some View {
        modifier(MotionSafe(animation: animation, value: AnyHashable(value)))
    }
}

// MARK: - Loading animation presets
/// Branded loading animation modes for the FitMeLogoLoader.
/// Each preset is tuned for a specific loading context.
enum AppLoadingAnimation {
    /// Breathing pulse: logo scales 0.92→1.08 with easeInOut, 1.2s cycle.
    /// Use for: calculating, processing, AI thinking.
    static let breathe = Animation.easeInOut(duration: 1.2).repeatForever(autoreverses: true)

    /// Gentle rotation: logo rotates 360° continuously, 2.0s cycle.
    /// Use for: syncing, uploading, downloading.
    static let rotate = Animation.linear(duration: 2.0).repeatForever(autoreverses: false)

    /// Quick pulse: logo scales 1.0→1.15 and bounces back, single shot.
    /// Use for: success confirmation, data received.
    static let confirmPulse = Animation.spring(response: 0.3, dampingFraction: 0.5)

    /// Shimmer: opacity oscillates 0.4→1.0, 0.8s cycle.
    /// Use for: waiting, background refresh.
    static let shimmer = Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)
}
