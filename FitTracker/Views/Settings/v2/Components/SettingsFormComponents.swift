// FitTracker/Views/Settings/v2/Components/SettingsFormComponents.swift
// Settings v2 — shared form components (action label, selection tile, choice grid, numeric field, slider).
// Extracted from SettingsView.swift in Audit M-1b (UI-002 decomposition).

import SwiftUI

enum SettingsActionTrailing {
    case chevron
    case progress
}

struct SettingsActionLabel: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    var trailing: SettingsActionTrailing = .chevron

    var body: some View {
        HStack(spacing: AppSpacing.xSmall) {
            Image(systemName: icon)
                .font(AppText.captionStrong)
                .foregroundStyle(tint)
                .frame(width: 26, height: 26)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: AppRadius.xSmall))

            VStack(alignment: .leading, spacing: AppSpacing.micro) {
                Text(title)
                    .font(AppText.button)
                    .foregroundStyle(AppColor.Text.primary)
                Text(subtitle)
                    .font(AppText.subheading)
                    .foregroundStyle(AppColor.Text.secondary)
                    .multilineTextAlignment(.leading)
            }

            Spacer()

            switch trailing {
            case .chevron:
                Image(systemName: "chevron.right")
                    .font(AppText.captionStrong)
                    .foregroundStyle(AppColor.Text.tertiary)
            case .progress:
                FitMeLogoLoader(mode: .rotate, size: .small)
            }
        }
        .padding(.vertical, AppSpacing.xxxSmall)
    }
}

struct SettingsSelectionTile: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {
            Text(title)
                .font(AppText.button)
                .foregroundStyle(isSelected ? AppColor.Text.inversePrimary : AppColor.Text.primary)
            Text(subtitle)
                .font(AppText.caption)
                .foregroundStyle(isSelected ? AppColor.Text.inversePrimary : AppColor.Text.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, AppSpacing.xxSmall)
        .padding(.horizontal, AppSpacing.xSmall)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .fill(isSelected ? tint : AppColor.Surface.materialStrong)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .stroke(isSelected ? tint.opacity(0.18) : AppColor.Border.subtle, lineWidth: 1)
        )
    }
}

struct SettingsChoiceGrid<Option: Hashable, Tile: View>: View {
    let options: [Option]
    @Binding var selection: Option
    let tile: (Option) -> Tile

    private let columns = [
        GridItem(.flexible(), spacing: AppSpacing.xxSmall, alignment: .top),
        GridItem(.flexible(), spacing: AppSpacing.xxSmall, alignment: .top),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: AppSpacing.xxSmall) {
            ForEach(options, id: \.self) { option in
                Button {
                    selection = option
                } label: {
                    tile(option)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(option)")
                .accessibilityValue(option == selection ? "Selected" : "Not selected")
                .accessibilityAddTraits(option == selection ? [.isSelected] : [])
            }
        }
    }
}

struct SettingsNumericFieldRow: View {
    let title: String
    let suffix: String
    @Binding var value: Double

    var body: some View {
        HStack(spacing: AppSpacing.xSmall) {
            Text(title)
                .font(AppText.body)
                .foregroundStyle(AppColor.Text.primary)
            Spacer()
            TextField(
                title,
                value: $value,
                format: .number.precision(.fractionLength(0...1))
            )
            .multilineTextAlignment(.trailing)
            .keyboardType(.decimalPad)
            .textFieldStyle(.roundedBorder)
            .frame(width: 96)
            Text(suffix)
                .font(AppText.chip)
                .foregroundStyle(AppColor.Text.secondary)
        }
    }
}

struct SettingsSliderRow: View {
    let title: String
    let valueText: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let onCommit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {
            HStack {
                Text(title)
                    .font(AppText.body)
                    .foregroundStyle(AppColor.Text.primary)
                Spacer()
                Text(valueText)
                    .font(AppText.chip)
                    .foregroundStyle(AppColor.Text.secondary)
            }

            Slider(
                value: $value,
                in: range,
                step: 1
            ) { _ in
                onCommit()
            }
            .tint(AppColor.Accent.primary)
        }
    }
}
