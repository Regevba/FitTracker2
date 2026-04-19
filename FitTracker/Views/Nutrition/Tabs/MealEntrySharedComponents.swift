// FitTracker/Views/Nutrition/Tabs/MealEntrySharedComponents.swift
// Shared view helpers used by 2+ Meal Entry tabs.
// Extracted from MealEntrySheet.swift in Audit M-2b (UI-004 decomposition).

import SwiftUI

// Pretty-prints a numeric meal value: integers as Int, decimals to 1 fraction digit.
// Free helper so both the VM and the parsed-metric tile can use the same logic.
func formatMealValue(_ v: Double) -> String {
    v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
}

// Labelled text field used by the Smart and Manual tabs.
struct MealEntryField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var isNumeric: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {
            AppFieldLabel(title: label)
            AppInputShell {
                TextField(placeholder, text: $text)
                    .font(AppText.body)
                    .foregroundStyle(AppColor.Text.primary)
                    #if canImport(UIKit)
                    .keyboardType(isNumeric ? .decimalPad : .default)
                    #endif
            }
        }
    }
}

// Tinted action button label used by the Smart tab (Take Photo / Choose Photo).
struct SmartActionLabel: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: AppSpacing.xxSmall) {
            Image(systemName: systemImage)
            Text(title)
        }
        .font(.caption.weight(.semibold))
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xSmall)
        .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: AppRadius.small))
        .foregroundStyle(tint)
    }
}

// Single metric tile in the parsed-label result panel (Smart tab).
struct ParsedMetricView: View {
    let title: String
    let value: Double?
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.micro) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(AppColor.Text.secondary)
            Text(value.map { formatMealValue($0) } ?? "—")
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
