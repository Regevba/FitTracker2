import SwiftUI

/// A card displaying a group of supplements (e.g., Morning or Evening stack)
/// with a header, progress indicator, and expandable individual rows.
struct SupplementStackCard: View {

    let stackTitle:      String
    let stackSubtitle:   String
    let supplements:     [SupplementDefinition]
    let stackStatus:     TaskStatus
    let individualStatus: [String: Bool]
    let accentColor:     Color
    let onStackStatus:   (TaskStatus) -> Void
    let onToggle:        (String, Bool) -> Void

    @State private var expanded = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var takenCount: Int {
        supplements.filter { individualStatus[$0.id] == true }.count
    }

    private var fraction: Double {
        supplements.count > 0 ? Double(takenCount) / Double(supplements.count) : 0
    }

    var body: some View {
        VStack(spacing: 0) {

            // ── Stack header ─────────────────────────────
            HStack(spacing: AppSpacing.xSmall) {
                VStack(alignment: .leading, spacing: AppSpacing.micro) {
                    Text(stackTitle)
                        .font(AppText.sectionTitle)
                        .foregroundStyle(AppColor.Text.primary)
                    Text(stackSubtitle)
                        .font(AppText.caption)
                        .foregroundStyle(AppColor.Text.secondary)
                }
                Spacer()
                StatusDropdown(status: stackStatus, onSelect: onStackStatus)
                Button {
                    withAnimation(reduceMotion ? .none : AppMotion.quickInteraction) {
                        expanded.toggle()
                    }
                } label: {
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(AppText.captionStrong)
                        .foregroundStyle(AppColor.Text.secondary)
                        .accessibilityLabel(expanded ? "Collapse" : "Expand")
                        .accessibilityHint(expanded ? "Hide supplement details" : "Show supplement details")
                }
            }
            .padding(AppSpacing.xSmall)
            .background(accentColor.opacity(AppOpacity.hover))

            // ── Progress bar ─────────────────────────────
            ProgressBar(
                progress: fraction,
                color: accentColor,
                height: 3,
                backgroundColor: accentColor.opacity(AppOpacity.disabled)
            )
            .accessibilityProgress(
                label: "\(stackTitle) supplement progress",
                value: "\(takenCount) of \(supplements.count) taken"
            )

            // ── Supplement rows ──────────────────────────
            if expanded {
                ForEach(supplements) { supp in
                    SupplementItemRow(
                        supplement: supp,
                        isTaken: individualStatus[supp.id] ?? false,
                        accentColor: accentColor
                    ) { taken in
                        onToggle(supp.id, taken)
                    }
                    if supp.id != supplements.last?.id {
                        Divider().padding(.leading, AppSpacing.supplementDetailIndent)
                    }
                }
            }
        }
        .background(AppColor.Surface.elevated, in: RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.small)
                .stroke(stackStatus == .completed ? accentColor.opacity(0.4) : Color.clear, lineWidth: 1)
        )
        .clipped()
    }
}
