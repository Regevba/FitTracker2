import SwiftUI

/// Reusable progress bar component using design system tokens.
/// Replaces inline GeometryReader progress bars throughout the app.
struct ProgressBar: View {
    let progress: Double
    let color: Color
    var height: CGFloat = 6
    var backgroundColor: Color = AppColor.Surface.tertiary

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: AppRadius.micro)
                    .fill(backgroundColor)
                    .frame(height: height)

                RoundedRectangle(cornerRadius: AppRadius.micro)
                    .fill(color)
                    .frame(width: geo.size.width * min(max(progress, 0), 1), height: height)
                    .animation(reduceMotion ? .none : AppSpring.progress, value: progress)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Accessibility wrapper

extension ProgressBar {
    /// Adds VoiceOver label and value to the progress bar.
    func accessibilityProgress(label: String, value: String) -> some View {
        self
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityValue(value)
    }
}
