import SwiftUI

/// A simple pill badge displaying text with a coloured background.
struct StatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(AppText.captionStrong)
            .foregroundStyle(color)
            .padding(.vertical, 5)
            .padding(.horizontal, 10)
            .background(color.opacity(0.16), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(color.opacity(0.18), lineWidth: 1)
            )
            .clipShape(Capsule())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(text)
    }
}

#if DEBUG
struct StatusBadge_Previews: PreviewProvider {
    static var previews: some View {
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
}
#endif
