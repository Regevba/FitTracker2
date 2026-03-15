import SwiftUI

/// Shown when a section has no data. Consistent no-data placeholder.
struct EmptyStateView: View {
    let icon: String         // SF Symbol, e.g. "chart.line.uptrend.xyaxis"
    let title: String        // e.g. "No data yet"
    let subtitle: String     // e.g. "Log a workout to see your stats here"
    var ctaLabel: String? = nil
    var ctaAction: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundColor(.secondary)

            Text(title)
                .font(AppType.headline)
                .foregroundColor(.primary)

            Text(subtitle)
                .font(AppType.subheading)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if let ctaLabel = ctaLabel, ctaAction != nil {
                Button(action: ctaAction ?? {}) {
                    Text(ctaLabel)
                        .font(AppType.body)
                }
                .foregroundColor(.orange)
            }
        }
        .padding(.horizontal, 24)
        .accessibilityElement(children: .contain)
    }
}

#if DEBUG
struct EmptyStateView_Previews: PreviewProvider {
    static var previews: some View {
        EmptyStateView(
            icon: "chart.line.uptrend.xyaxis",
            title: "No data yet",
            subtitle: "Log a workout to see your stats here"
        )
    }
}
#endif
