import SwiftUI

/// A single supplement row with checkbox, name, dose, and expandable details.
struct SupplementItemRow: View {

    let supplement:  SupplementDefinition
    let isTaken:     Bool
    let accentColor: Color
    let onToggle:    (Bool) -> Void

    @State private var expanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            Button {
                HapticFeedback.impact()
                onToggle(!isTaken)
            } label: {
                HStack(spacing: AppSpacing.xSmall) {
                    // Checkbox
                    ZStack {
                        RoundedRectangle(cornerRadius: AppRadius.xSmall)
                            .stroke(isTaken ? accentColor : AppColor.Border.subtle, lineWidth: 1.5)
                            .frame(width: AppSize.iconBadge, height: AppSize.iconBadge)
                        if isTaken {
                            Image(systemName: "checkmark")
                                .font(AppText.captionStrong)
                                .foregroundStyle(accentColor)
                        }
                    }

                    // Supplement info
                    VStack(alignment: .leading, spacing: AppSpacing.micro) {
                        HStack(spacing: AppSpacing.xxSmall) {
                            Text(supplement.name)
                                .font(AppText.callout)
                                .strikethrough(isTaken, color: accentColor)
                                .foregroundStyle(isTaken ? AppColor.Text.secondary : AppColor.Text.primary)
                            Text(supplement.dose)
                                .font(AppText.monoLabel)
                                .foregroundStyle(accentColor)
                                .padding(.horizontal, AppSpacing.xxxSmall)
                                .padding(.vertical, AppSpacing.micro)
                                .background(accentColor.opacity(AppOpacity.subtle), in: Capsule())
                        }
                        Text(supplement.timing.rawValue)
                            .font(AppText.caption)
                            .foregroundStyle(AppColor.Text.secondary)
                    }

                    Spacer()

                    // Info expand toggle
                    Button {
                        withAnimation(reduceMotion ? .none : AppMotion.quickInteraction) {
                            expanded.toggle()
                        }
                    } label: {
                        Image(systemName: "info.circle")
                            .font(AppText.caption)
                            .foregroundStyle(AppColor.Text.secondary)
                    }
                    .accessibilityLabel("Supplement details")
                    .accessibilityHint("Toggle \(supplement.name) details")
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, AppSpacing.xSmall)
                .padding(.vertical, AppSpacing.xSmall)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(supplement.name), \(supplement.dose)")
            .accessibilityValue(isTaken ? "Taken" : "Not taken")
            .accessibilityHint("Double tap to toggle")

            // Expandable benefit / notes
            if expanded {
                VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {
                    Text(supplement.benefit)
                        .font(AppText.caption)
                        .foregroundStyle(AppColor.Text.secondary)
                    HStack(spacing: AppSpacing.xxxSmall) {
                        Image(systemName: "clock")
                            .font(AppText.caption)
                            .foregroundStyle(AppColor.Text.tertiary)
                        Text(supplement.notes)
                            .font(AppText.caption)
                            .foregroundStyle(AppColor.Text.tertiary)
                    }
                }
                .padding(.horizontal, AppSpacing.supplementDetailIndent)
                .padding(.bottom, AppSpacing.xxSmall)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(accentColor.opacity(0.03))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}
