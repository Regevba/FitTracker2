// FitTracker/DesignSystem/AppComponents.swift
// Lower-level design system primitives: chips, filters, sheets, stat rows, segments, progress rings.
// These are atomic/molecule-level components that compose into larger patterns.
//
// Split rationale:
//   This file:                              Atomic/molecule components (picker, filter, ring, stat row)
//   Views/Shared/AppDesignSystemComponents: Composite components (card, button, menu row, selection tile, input shell)
//
// Both files reference AppTheme.* only — never AppPalette or raw values.
import SwiftUI

// MARK: - AppPickerChip
// Single selectable chip for filters and day selectors.
// Usage: AppPickerChip(label: "Push", isSelected: $selected) { ... }
struct AppPickerChip: View {
    let label: String
    let isSelected: Bool
    let accessibilityLabel: String?
    let action: () -> Void

    init(
        label: String,
        isSelected: Bool,
        accessibilityLabel: String? = nil,
        action: @escaping () -> Void
    ) {
        self.label = label
        self.isSelected = isSelected
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(AppText.chip)
                .foregroundStyle(isSelected ? AppColor.Text.inversePrimary : AppColor.Text.primary)
                .padding(.horizontal, AppSpacing.small)
                .padding(.vertical, AppSpacing.xxSmall)
                .background(
                    isSelected ? AppColor.Accent.primary : AppColor.Surface.secondary,
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel ?? label)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .animation(reduceMotion ? .none : AppSpring.snappy, value: isSelected)
    }
}

// MARK: - AppFilterBar
// Horizontal scrollable row of AppPickerChips.
// Usage: AppFilterBar(options: ["All", "Push", "Pull"], selection: $filter)
struct AppFilterBar: View {
    let options: [String]
    @Binding var selection: String
    var accessibilityLabel: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.xxSmall) {
                ForEach(options, id: \.self) { option in
                    AppPickerChip(
                        label: option,
                        isSelected: selection == option
                    ) {
                        selection = option
                    }
                }
            }
            .padding(.horizontal, AppSpacing.small)
        }
        .accessibilityLabel(accessibilityLabel ?? "Filter")
    }
}

// MARK: - AppSheetShell
// Standard bottom-sheet container with title + content + primary action.
// Usage: AppSheetShell(title: "Add Meal", primaryLabel: "Save") { ... save ... } content: { ... }
struct AppSheetShell<Content: View>: View {
    let title: String
    let primaryLabel: String
    var isDestructive: Bool = false
    var onDismiss: (() -> Void)?
    let primaryAction: () -> Void
    let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            Capsule()
                .fill(AppColor.Border.strong)
                .frame(width: 36, height: 4)
                .padding(.top, AppSpacing.xSmall)
                .padding(.bottom, AppSpacing.xxSmall)

            // Header
            HStack {
                Text(title)
                    .font(AppText.pageTitle)
                    .foregroundStyle(AppColor.Text.primary)
                Spacer()
                if let onDismiss {
                    Button(action: onDismiss) {
                        Image(systemName: AppIcon.closeCircle)
                            .font(AppText.titleMedium)
                            .foregroundStyle(AppColor.Text.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Dismiss")
                }
            }
            .padding(.horizontal, AppSpacing.small)
            .padding(.bottom, AppSpacing.xSmall)

            Divider().opacity(0.4)

            // Content
            content()
                .padding(.horizontal, AppSpacing.small)

            // Primary action
            Button(action: primaryAction) {
                Text(primaryLabel)
                    .font(AppText.button)
                    .foregroundStyle(isDestructive ? AppColor.Status.error : AppColor.Text.inversePrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.small)
                    .background(
                        isDestructive ? AppColor.Status.error.opacity(0.12) : AppColor.Accent.primary,
                        in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, AppSpacing.small)
            .padding(.top, AppSpacing.xSmall)
            .padding(.bottom, AppSpacing.medium)
        }
        .background(AppColor.Surface.elevated, in: RoundedRectangle(cornerRadius: AppSheet.standardCornerRadius, style: .continuous))
    }
}

// MARK: - AppStatRow
// Label + value row for settings detail and profile stats.
// Usage: AppStatRow(label: "Weight", value: "82.5 kg", icon: "scalemass.fill")
struct AppStatRow: View {
    let label: String
    let value: String
    var icon: String?
    var valueColor: Color?
    var accessibilityLabel: String?

    var body: some View {
        HStack(spacing: AppSpacing.xSmall) {
            if let icon {
                Image(systemName: icon)
                    .font(AppText.callout)
                    .foregroundStyle(AppColor.Accent.primary)
                    .frame(width: 24)
            }
            Text(label)
                .font(AppText.body)
                .foregroundStyle(AppColor.Text.primary)
            Spacer()
            Text(value)
                .font(AppText.body)
                .foregroundStyle(valueColor ?? AppColor.Text.secondary)
        }
        .padding(.vertical, AppSpacing.xxSmall)
        .accessibilityLabel(accessibilityLabel ?? "\(label): \(value)")
        .accessibilityElement(children: .combine)
    }
}

// MARK: - AppSegmentedControl
// Token-based segmented picker.
// Usage: AppSegmentedControl(options: ["Week", "Month", "Year"], selection: $period)
struct AppSegmentedControl: View {
    let options: [String]
    @Binding var selection: String
    var accessibilityLabel: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var animation

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { option in
                let isSelected = selection == option
                Button {
                    selection = option
                } label: {
                    Text(option)
                        .font(AppText.captionStrong)
                        .foregroundStyle(isSelected ? AppColor.Text.primary : AppColor.Text.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.xxSmall)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: AppRadius.xSmall, style: .continuous)
                                    .fill(AppColor.Surface.elevated)
                                    .matchedGeometryEffect(id: "segment", in: animation)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .padding(AppSpacing.micro)
        .background(AppColor.Surface.materialLight, in: RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous))
        .animation(reduceMotion ? .none : AppSpring.snappy, value: selection)
        .accessibilityLabel(accessibilityLabel ?? "Segment")
    }
}

// MARK: - AppProgressRing
// Circular progress indicator for goal completion and readiness.
// Usage: AppProgressRing(value: 0.78, color: AppColor.Accent.primary, label: "78%")
struct AppProgressRing: View {
    let value: Double      // 0.0 – 1.0
    let color: Color
    var label: String?
    var lineWidth: CGFloat = 6
    var accessibilityLabel: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animatedValue: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: animatedValue)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if let label {
                Text(label)
                    .font(AppText.captionStrong)
                    .foregroundStyle(AppColor.Text.primary)
            }
        }
        .onAppear {
            if reduceMotion {
                animatedValue = value
            } else {
                withAnimation(AppEasing.standard) {
                    animatedValue = value
                }
            }
        }
        .onChange(of: value) { _, newValue in
            if reduceMotion {
                animatedValue = newValue
            } else {
                withAnimation(AppSpring.smooth) {
                    animatedValue = newValue
                }
            }
        }
        .accessibilityLabel(accessibilityLabel ?? (label.map { "Progress: \($0)" } ?? "Progress: \(Int(value * 100))%"))
    }
}

// MARK: - AppMetricColumn
// Metric column: icon + title label, large value + unit, target line, missing-state CTA.
// Promoted from private `statusValueColumn` in MainScreenView (v1).
// Usage: AppMetricColumn(icon: "scalemass.fill", title: "WEIGHT", value: "82.5", unit: "kg", target: "Goal 80 kg", tintColor: .blue)
struct AppMetricColumn: View {
    let icon: String           // SF Symbol name
    let title: String          // e.g. "WEIGHT", "BODY FAT"
    let value: String?         // nil → empty / missing state
    let unit: String           // e.g. "kg", "%"
    let target: String?        // e.g. "Goal 80 kg"
    let tintColor: Color
    var onLogTap: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {
            // Icon + title row
            HStack(spacing: AppSpacing.xxSmall) {
                Image(systemName: icon)
                    .font(AppText.caption.weight(.bold))
                Text(title)
                    .font(AppText.caption)
            }
            .foregroundStyle(tintColor)

            if let value {
                // Filled state: value + unit
                HStack(alignment: .lastTextBaseline, spacing: AppSpacing.micro) {
                    Text(value)
                        .font(AppText.metricM)
                        .monospacedDigit()
                        .foregroundStyle(AppColor.Text.primary)
                    Text(unit)
                        .font(AppText.footnote.weight(.medium))
                        .foregroundStyle(AppColor.Text.tertiary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(title)
                .accessibilityValue("\(value) \(unit)")
            } else {
                // Empty / missing state: tappable Log CTA
                Button {
                    onLogTap?()
                } label: {
                    Text("Log")
                        .font(AppText.button)
                        .foregroundStyle(tintColor)
                        .padding(.horizontal, AppSpacing.small)
                        .padding(.vertical, AppSpacing.xxSmall)
                        .background(tintColor.opacity(0.14), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Log \(title)")
                .accessibilityHint("Opens the logging screen for \(title.lowercased())")
            }

            // Target line
            if let target {
                Text(target)
                    .font(AppText.footnote)
                    .foregroundStyle(value != nil ? AppColor.Text.tertiary : tintColor.opacity(0.88))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - AppMetricTile
// Compact metric tile: tinted icon + value + label with tinted background.
// Used in Home metrics row (HRV, RHR, Sleep, Steps).
// Promoted from private `metricTile` in MainScreenView (v1).
// Usage: AppMetricTile(icon: "heart.fill", value: "62", label: "RHR", tintColor: .red)
struct AppMetricTile: View {
    let icon: String           // SF Symbol name
    let value: String?         // nil → empty / missing state with "Log" CTA
    let label: String          // e.g. "RHR", "HRV", "Sleep"
    let tintColor: Color
    var onLogTap: (() -> Void)?
    var onTileTap: (() -> Void)?

    var body: some View {
        let tileContent = VStack(spacing: AppSpacing.xxSmall) {
            Image(systemName: icon)
                .font(AppText.iconMedium)
                .foregroundStyle(tintColor)

            if let value {
                Text(value)
                    .font(AppText.metricCompact)
                    .monospacedDigit()
                    .foregroundStyle(AppColor.Text.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } else {
                Button {
                    onLogTap?()
                } label: {
                    Text("Log")
                        .font(AppText.footnote)
                        .foregroundStyle(tintColor)
                }
                .buttonStyle(.plain)
            }

            Text(label)
                .font(AppText.caption)
                .foregroundStyle(AppColor.Text.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xSmall)
        .background(
            tintColor.opacity(0.12),
            in: RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
        )

        if value != nil, let onTileTap {
            Button(action: onTileTap) {
                tileContent
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(label)
            .accessibilityValue(value ?? "Empty")
            .accessibilityHint("Tap to view \(label) trends in Stats")
        } else {
            tileContent
                .accessibilityElement(children: .combine)
                .accessibilityLabel(label)
                .accessibilityValue(value ?? "Empty")
                .accessibilityHint(value == nil ? "Tap to log" : "")
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("AppPickerChip") {
    HStack(spacing: AppSpacing.xSmall) {
        AppPickerChip(label: "Default", isSelected: false) {}
        AppPickerChip(label: "Selected", isSelected: true) {}
    }
    .padding()
    .background(AppGradient.screenBackground)
}

#Preview("AppFilterBar") {
    AppFilterBar(
        options: ["All", "Today", "Week", "Month"],
        selection: .constant("Week")
    )
    .padding()
    .background(AppGradient.screenBackground)
}

#Preview("AppSegmentedControl") {
    VStack(spacing: AppSpacing.large) {
        AppSegmentedControl(
            options: ["Day", "Week", "Month"],
            selection: .constant("Week")
        )
        AppSegmentedControl(
            options: ["Push", "Pull", "Legs", "Rest"],
            selection: .constant("Push")
        )
    }
    .padding()
    .background(AppGradient.screenBackground)
}

#Preview("AppProgressRing") {
    HStack(spacing: AppSpacing.large) {
        AppProgressRing(value: 0.25, color: AppColor.Brand.primary, label: "25%")
            .frame(width: 64, height: 64)
        AppProgressRing(value: 0.6, color: AppColor.Status.warning, label: "60%")
            .frame(width: 64, height: 64)
        AppProgressRing(value: 1.0, color: AppColor.Status.success, label: "Done")
            .frame(width: 64, height: 64)
    }
    .padding()
    .background(AppGradient.screenBackground)
}

#Preview("AppMetricColumn – Filled") {
    HStack(spacing: AppSpacing.small) {
        AppMetricColumn(
            icon: "scalemass.fill",
            title: "WEIGHT",
            value: "82.5",
            unit: "kg",
            target: "Goal 80 kg",
            tintColor: .blue
        )
        AppMetricColumn(
            icon: "percent",
            title: "BODY FAT",
            value: "18.2",
            unit: "%",
            target: "Goal 15%",
            tintColor: .orange
        )
    }
    .padding()
    .background(AppGradient.screenBackground)
}

#Preview("AppMetricColumn – Missing") {
    HStack(spacing: AppSpacing.small) {
        AppMetricColumn(
            icon: "scalemass.fill",
            title: "WEIGHT",
            value: nil,
            unit: "kg",
            target: "No data today",
            tintColor: .blue,
            onLogTap: {}
        )
        AppMetricColumn(
            icon: "percent",
            title: "BODY FAT",
            value: nil,
            unit: "%",
            target: nil,
            tintColor: .orange,
            onLogTap: {}
        )
    }
    .padding()
    .background(AppGradient.screenBackground)
}

#Preview("AppMetricTile – Filled") {
    HStack(spacing: AppSpacing.xSmall) {
        AppMetricTile(icon: "waveform.path.ecg", value: "42", label: "HRV", tintColor: .purple)
        AppMetricTile(icon: "heart.fill", value: "62", label: "RHR", tintColor: .red)
        AppMetricTile(icon: "moon.fill", value: "7.5h", label: "Sleep", tintColor: .indigo)
        AppMetricTile(icon: "figure.walk", value: "8,241", label: "Steps", tintColor: .green)
    }
    .padding()
    .background(AppGradient.screenBackground)
}

#Preview("AppMetricTile – Empty") {
    HStack(spacing: AppSpacing.xSmall) {
        AppMetricTile(icon: "waveform.path.ecg", value: nil, label: "HRV", tintColor: .purple, onLogTap: {})
        AppMetricTile(icon: "heart.fill", value: nil, label: "RHR", tintColor: .red, onLogTap: {})
        AppMetricTile(icon: "moon.fill", value: "7.5h", label: "Sleep", tintColor: .indigo)
        AppMetricTile(icon: "figure.walk", value: nil, label: "Steps", tintColor: .green, onLogTap: {})
    }
    .padding()
    .background(AppGradient.screenBackground)
}

#Preview("AppStatRow") {
    VStack(spacing: AppSpacing.small) {
        AppStatRow(label: "Volume", value: "12,450 kg")
        AppStatRow(label: "Sets", value: "24")
        AppStatRow(label: "Duration", value: "1h 15m")
    }
    .padding()
    .background(AppGradient.screenBackground)
}
#endif
