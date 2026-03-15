import SwiftUI

/// Consistent section title header with optional action.
struct SectionHeader: View {
    let title: String
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(AppType.caption)
                .textCase(.uppercase)
                .tracking(1.5)
                .foregroundStyle(.secondary)

            Spacer()

            if let actionLabel = actionLabel {
                Button(action: { action?() }) {
                    Text(actionLabel)
                        .font(AppType.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
struct SectionHeader_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            SectionHeader(title: "Today's Metrics")

            SectionHeader(
                title: "Recent Workouts",
                actionLabel: "View All",
                action: { print("View All tapped") }
            )

            SectionHeader(title: "Health Data")
        }
        .padding()
        .background(Color.black.opacity(0.05))
    }
}
#endif
