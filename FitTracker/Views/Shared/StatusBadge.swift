import SwiftUI

/// A simple pill badge displaying text with a coloured background.
struct StatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(AppText.captionStrong)
            .foregroundStyle(color)
            .padding(.vertical, AppSpacing.xxxSmall)
            .padding(.horizontal, AppSpacing.xxSmall)
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
        VStack(spacing: AppSpacing.xSmall) {
            HStack(spacing: AppSpacing.xxSmall) {
                StatusBadge(text: "Active", color: .status.success)
                StatusBadge(text: "Pending", color: .status.warning)
                StatusBadge(text: "Error", color: .status.error)
            }

            HStack(spacing: AppSpacing.xxSmall) {
                StatusBadge(text: "Completed", color: .accent.cyan)
                StatusBadge(text: "Premium", color: .accent.gold)
                StatusBadge(text: "Featured", color: .accent.purple)
            }
        }
        .padding()
        .background(AppColor.Border.hairline)
    }
}
#endif
