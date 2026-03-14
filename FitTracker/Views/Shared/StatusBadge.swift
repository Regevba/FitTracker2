import SwiftUI

/// A simple pill badge displaying text with a coloured background.
struct StatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(AppType.caption)
            .foregroundColor(color)
            .padding(.vertical, 4)
            .padding(.horizontal, 10)
            .background(color.opacity(0.2))
            .clipShape(Capsule())
    }
}

#Preview {
    VStack(spacing: 12) {
        HStack(spacing: 8) {
            StatusBadge(text: "Active", color: .status.success)
            StatusBadge(text: "Pending", color: .status.warning)
            StatusBadge(text: "Error", color: .status.error)
        }

        HStack(spacing: 8) {
            StatusBadge(text: "Completed", color: .accent.cyan)
            StatusBadge(text: "Premium", color: .accent.gold)
            StatusBadge(text: "Featured", color: .accent.purple)
        }
    }
    .padding()
    .background(Color.black.opacity(0.05))
}
