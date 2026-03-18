import SwiftUI

/// A container card that wraps a Swift Charts chart with a consistent header.
struct ChartCard<Content: View>: View {
    let title: String
    let periodLabel: String        // e.g. "Last 7 days"
    var trendDelta: Double? = nil  // if non-nil, shows a TrendIndicator
    var positiveIsGood: Bool = true
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(AppType.headline)
                        .foregroundStyle(Color.appTextPrimary)

                    Text(periodLabel)
                        .font(AppType.caption)
                        .foregroundColor(Color.appTextSecondary)
                }

                Spacer()

                if let trendDelta = trendDelta {
                    TrendIndicator(delta: trendDelta, positiveIsGood: positiveIsGood)
                } else {
                    Text("Trend")
                        .font(AppType.caption)
                        .foregroundColor(Color.appTextSecondary)
                        .padding(.vertical, 3)
                        .padding(.horizontal, 9)
                        .background(Color.appSurface.opacity(0.9), in: Capsule())
                }
            }

            content()
        }
        .padding(14)
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.appStroke, lineWidth: 1)
        )
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
