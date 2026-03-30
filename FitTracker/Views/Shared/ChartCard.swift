import SwiftUI

/// A container card that wraps a Swift Charts chart with a consistent header.
struct ChartCard<Content: View>: View {
    let title: String
    let periodLabel: String        // e.g. "Last 7 days"
    var trendDelta: Double? = nil  // if non-nil, shows a TrendIndicator
    var positiveIsGood: Bool = true
    @ViewBuilder let content: () -> Content

    var body: some View {
        AppCard(tone: .standard) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(AppText.sectionTitle)
                            .foregroundStyle(AppColor.Text.primary)

                        Text(periodLabel)
                            .font(AppText.caption)
                            .foregroundStyle(AppColor.Text.secondary)
                    }

                    Spacer()

                    if let trendDelta = trendDelta {
                        TrendIndicator(delta: trendDelta, positiveIsGood: positiveIsGood)
                    } else {
                        Text("Trend")
                            .font(AppText.caption)
                            .foregroundStyle(AppColor.Text.secondary)
                            .padding(.vertical, 3)
                            .padding(.horizontal, AppSpacing.xxSmall)
                            .background(AppColor.Surface.materialLight, in: Capsule())
                    }
                }

                content()
            }
        }
        .accessibilityElement(children: .contain)
    }
}

#if DEBUG
struct ChartCard_Previews: PreviewProvider {
    static var previews: some View {
        ChartCard(
            title: "Weekly Activity",
            periodLabel: "Last 7 days",
            trendDelta: 12.5,
            positiveIsGood: true
        ) {
            Text("Chart content goes here")
                .frame(height: 200)
        }
    }
}
#endif
