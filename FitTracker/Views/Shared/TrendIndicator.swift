import SwiftUI

/// A coloured pill showing a numeric delta.
struct TrendIndicator: View {
    let delta: Double        // e.g. 0.12 = 12%
    let positiveIsGood: Bool // true for HRV (up=good), false for weight/BF (down=good)
    var isPercent: Bool = true

    var statusColor: Color {
        if delta > 0 && positiveIsGood {
            return .status.success
        } else if delta < 0 && !positiveIsGood {
            return .status.success
        } else if delta == 0 {
            return .status.warning
        } else {
            return .status.error
        }
    }

    var displayText: String {
        let arrow = delta >= 0 ? "↑" : "↓"
        let absoluteValue = abs(delta)

        if isPercent {
            return String(format: "%@ %.0f%%", arrow, absoluteValue * 100)
        } else {
            return String(format: "%@ %.2f", arrow, absoluteValue)
        }
    }

    var body: some View {
        Text(displayText)
            .font(AppType.caption)
            .foregroundColor(statusColor)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(statusColor.opacity(0.16))
            .overlay(
                Capsule()
                    .stroke(statusColor.opacity(0.24), lineWidth: 1)
            )
            .clipShape(Capsule())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Trend")
            .accessibilityValue(displayText)
    }
}

#if DEBUG
struct TrendIndicator_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                TrendIndicator(delta: 0.12, positiveIsGood: true)
                TrendIndicator(delta: -0.04, positiveIsGood: false)
                TrendIndicator(delta: 0.0, positiveIsGood: true)
            }

            HStack(spacing: 12) {
                TrendIndicator(delta: -0.08, positiveIsGood: true)
                TrendIndicator(delta: 0.05, positiveIsGood: false)
            }

            HStack(spacing: 12) {
                TrendIndicator(delta: 0.15, positiveIsGood: false, isPercent: false)
                TrendIndicator(delta: -2.5, positiveIsGood: false, isPercent: false)
            }
        }
        .padding()
        .background(Color.black.opacity(0.05))
    }
}
#endif
