// FitTracker/Views/Training/v2/RestTimerView.swift
// Bottom-bar rest timer for active workout sessions.
// Display-only — countdown logic lives in the parent view model.
import SwiftUI

struct RestTimerView: View {
    let remainingSeconds: Int
    let totalSeconds: Int
    let isActive: Bool
    let onSkip: () -> Void
    let onComplete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Derived state

    private var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(remainingSeconds) / Double(totalSeconds)
    }

    private var formattedTime: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }

    // MARK: - Body

    var body: some View {
        if isActive {
            timerBar
                .transition(.move(edge: .bottom))
                .onAppear {
                    if remainingSeconds <= 0 {
                        onComplete()
                    }
                }
                .onChange(of: remainingSeconds) { _, newValue in
                    if newValue <= 0 {
                        onComplete()
                    }
                }
        }
    }

    // MARK: - Timer bar

    private var timerBar: some View {
        HStack(spacing: AppSpacing.xSmall) {
            // Timer icon
            Image(systemName: "timer")
                .font(AppText.iconSmall)
                .foregroundStyle(AppColor.Accent.primary)

            // Countdown
            Text(formattedTime)
                .font(AppText.monoMetric)
                .foregroundStyle(AppColor.Text.primary)
                .contentTransition(.numericText())
                .motionSafe(AppSpring.snappy, value: remainingSeconds)

            // Progress bar
            progressBar

            // Skip button
            Button(action: onSkip) {
                Text("Skip")
                    .font(AppText.chip)
                    .foregroundStyle(AppColor.Accent.primary)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Skips the rest timer")
        }
        .padding(AppSpacing.small)
        .background(AppColor.Surface.elevated)
        .shadow(
            color: AppShadow.cardColor,
            radius: AppShadow.cardRadius,
            x: 0,
            y: -AppShadow.cardYOffset
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Rest timer")
        .accessibilityValue("\(formattedTime) remaining")
    }

    // MARK: - Progress bar

    private var progressBar: some View {
        GeometryReader { geometry in
            Capsule()
                .fill(AppColor.Surface.tertiary)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(AppColor.Accent.primary)
                        .frame(width: geometry.size.width * progress)
                        .motionSafe(AppSpring.snappy, value: progress)
                }
        }
        .frame(height: AppSize.progressBarHeight)
        .clipShape(Capsule())
        .accessibilityHidden(true)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Rest Timer — Active") {
    VStack {
        Spacer()
        RestTimerView(
            remainingSeconds: 75,
            totalSeconds: 90,
            isActive: true,
            onSkip: {},
            onComplete: {}
        )
    }
    .background(AppColor.Background.appPrimary)
}

#Preview("Rest Timer — Near End") {
    VStack {
        Spacer()
        RestTimerView(
            remainingSeconds: 5,
            totalSeconds: 90,
            isActive: true,
            onSkip: {},
            onComplete: {}
        )
    }
    .background(AppColor.Background.appPrimary)
}

#Preview("Rest Timer — Inactive") {
    VStack {
        Spacer()
        RestTimerView(
            remainingSeconds: 45,
            totalSeconds: 90,
            isActive: false,
            onSkip: {},
            onComplete: {}
        )
    }
    .background(AppColor.Background.appPrimary)
}
#endif
