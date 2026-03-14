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
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 8) {
                // Top row: icon + label
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                    Text(label)
                        .font(AppType.caption)
                        .textCase(.uppercase)
                }
                .foregroundColor(.secondary)

                // Middle: value + unit
                HStack(alignment: .baseline, spacing: 4) {
                    Text(value)
                        .font(AppType.display)
                        .lineLimit(1)

                    if let unit = unit {
                        Text(unit)
                            .font(AppType.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Bottom: trend delta (if present)
                if let trendDelta = trendDelta {
                    Text(trendDelta)
                        .font(AppType.caption)
                        .foregroundColor(statusColor)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Status dot at top-right
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .padding(12)
        }
        .background(Color.white.opacity(0.15))
        .cornerRadius(14)
    }
}

#Preview {
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
