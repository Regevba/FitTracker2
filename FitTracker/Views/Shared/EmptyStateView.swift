import SwiftUI

/// Shown when a section has no data. Consistent no-data placeholder.
struct EmptyStateView: View {
    let icon: String         // SF Symbol, e.g. "chart.line.uptrend.xyaxis"
    let title: String        // e.g. "No data yet"
    let subtitle: String     // e.g. "Log a workout to see your stats here"
    var ctaLabel: String? = nil
    var ctaAction: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: AppSpacing.xxSmall) {
            Image(systemName: icon)
                .font(AppText.metric)
                .foregroundStyle(AppColor.Text.secondary)

            Text(title)
                .font(AppText.sectionTitle)
                .foregroundStyle(AppColor.Text.primary)

            Text(subtitle)
                .font(AppText.subheading)
                .foregroundStyle(AppColor.Text.secondary)
                .multilineTextAlignment(.center)

            if let ctaLabel = ctaLabel, ctaAction != nil {
                AppButton(title: ctaLabel, hierarchy: .tertiary, isFullWidth: false, action: ctaAction ?? {})
            }
        }
        .padding(.horizontal, AppSpacing.large)
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
