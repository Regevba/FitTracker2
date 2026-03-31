import SwiftUI

/// Consistent section title header with optional action.
struct SectionHeader: View {
    let title: String
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(AppText.caption)
                .textCase(.uppercase)
                .tracking(1.5)
                .foregroundStyle(AppColor.Text.secondary)

            Spacer()

            if let actionLabel = actionLabel {
                Button(action: { action?() }) {
                    Text(actionLabel)
                        .font(AppText.caption)
                        .foregroundStyle(AppColor.Accent.primary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
struct SectionHeader_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: AppSpacing.small) {
            SectionHeader(title: "Today's Metrics")

            SectionHeader(
                title: "Recent Workouts",
                actionLabel: "View All",
                action: { print("View All tapped") }
            )

            SectionHeader(title: "Health Data")
        }
        .padding()
        .background(AppColor.Border.hairline)
    }
}
#endif
