import SwiftUI

/// A container card that wraps a Swift Charts chart with a consistent header.
struct ChartCard<Content: View>: View {
    let title: String
    let periodLabel: String        // e.g. "Last 7 days"
    var trendDelta: Double? = nil  // if non-nil, shows a TrendIndicator
    var positiveIsGood: Bool = true
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(AppType.headline)

                Spacer()

                if let trendDelta = trendDelta {
                    TrendIndicator(delta: trendDelta, positiveIsGood: positiveIsGood)
                }
            }
            .padding(.bottom, 8)

            Text(periodLabel)
                .font(AppType.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 12)

            content()
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
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
