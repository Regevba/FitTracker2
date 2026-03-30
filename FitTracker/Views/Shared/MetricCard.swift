import SwiftUI

/// Displays a single metric with icon, value, unit, optional trend delta, and status dot.
struct MetricCard: View {
    let icon: String          // SF Symbol name, e.g. "scalemass.fill"
    let label: String         // e.g. "Weight"
    let value: String         // e.g. "67.3"
    let unit: String?         // e.g. "kg" — optional
    let trendDelta: String?   // e.g. "↓ 0.5" — optional
    let statusColor: Color    // dot colour: Color.status.success / warning / error

    var body: some View {
        AppCard(tone: .standard, contentPadding: 12) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    HStack(spacing: 6) {
                        Image(systemName: icon)
                            .font(AppText.captionStrong)
                        Text(label)
                            .font(AppType.caption)
                            .textCase(.uppercase)
                    }
                    .foregroundStyle(AppColor.Text.secondary)

                    Spacer()

                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                }

                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(value)
                        .font(AppText.metric)
                        .lineLimit(1)

                    if let unit = unit {
                        Text(unit)
                            .font(AppType.caption)
                            .foregroundStyle(AppColor.Text.secondary)
                    }
                }

                if let trendDelta = trendDelta {
                    Text(trendDelta)
                        .font(AppType.caption)
                        .foregroundStyle(statusColor)
                } else {
                    Text("No change signal yet")
                        .font(AppType.caption)
                        .foregroundStyle(AppColor.Text.secondary)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: String {
        var parts = [value]
        if let unit {
            parts.append(unit)
        }
        if let trendDelta {
            parts.append(trendDelta)
        }
        return parts.joined(separator: " ")
    }
}

#if DEBUG
struct MetricCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            MetricCard(
                icon: "scalemass.fill",
                label: "Weight",
                value: "67.3",
                unit: "kg",
                trendDelta: "↓ 0.5",
                statusColor: .status.success
            )

            MetricCard(
                icon: "heart.fill",
                label: "Resting HR",
                value: "58",
                unit: "bpm",
                trendDelta: nil,
                statusColor: .status.warning
            )

            MetricCard(
                icon: "flame.fill",
                label: "Calories",
                value: "2400",
                unit: nil,
                trendDelta: "↑ 120",
                statusColor: .status.error
            )
        }
        .padding()
        .background(Color.black.opacity(0.05))
    }
}
#endif
