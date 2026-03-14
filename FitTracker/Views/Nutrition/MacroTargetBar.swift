// Views/Nutrition/MacroTargetBar.swift
import SwiftUI

/// Stacked horizontal macro progress bar shown at the top of NutritionView.
struct MacroTargetBar: View {

    /// Consumed macros for the day
    let protein:   Double   // grams consumed
    let carbs:     Double   // grams consumed
    let fat:       Double   // grams consumed

    /// Targets
    let targetCalories: Int     // kcal target for the day
    let targetProteinG: Double  // grams target

    // kcal per gram
    private let proteinKcal = 4.0
    private let carbsKcal   = 4.0
    private let fatKcal     = 9.0

    private var consumedCalories: Double {
        protein * proteinKcal + carbs * carbsKcal + fat * fatKcal
    }
    private var remainingCalories: Double {
        max(0, Double(targetCalories) - consumedCalories)
    }
    private var totalForBar: Double {
        max(Double(targetCalories), consumedCalories)
    }

    var body: some View {
        VStack(spacing: 8) {
            // Stacked bar
            GeometryReader { geo in
                HStack(spacing: 2) {
                    // Protein segment
                    let proteinWidth = geo.size.width * (protein * proteinKcal / max(totalForBar, 1))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accent.cyan)
                        .frame(width: max(proteinWidth, 2))

                    // Carbs segment
                    let carbsWidth = geo.size.width * (carbs * carbsKcal / max(totalForBar, 1))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.appOrange1)
                        .frame(width: max(carbsWidth, 2))

                    // Fat segment
                    let fatWidth = geo.size.width * (fat * fatKcal / max(totalForBar, 1))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accent.purple)
                        .frame(width: max(fatWidth, 2))

                    // Remaining (grey)
                    let remaining = geo.size.width * (remainingCalories / max(totalForBar, 1))
                    if remaining > 2 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.2))
                            .frame(width: remaining)
                    }
                }
            }
            .frame(height: 14)

            // Legend row
            HStack(spacing: 12) {
                macroLabel("P", value: protein, unit: "g", color: Color.accent.cyan)
                macroLabel("C", value: carbs,   unit: "g", color: Color.appOrange1)
                macroLabel("F", value: fat,     unit: "g", color: Color.accent.purple)
                Spacer()
                // Total vs target
                Text("\(Int(consumedCalories)) / \(targetCalories) kcal")
                    .font(AppType.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }

    private func macroLabel(_ letter: String, value: Double, unit: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text("\(letter) \(Int(value))\(unit)")
                .font(AppType.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    MacroTargetBar(protein: 120, carbs: 180, fat: 55, targetCalories: 1900, targetProteinG: 130)
        .padding()
        .background(Color.appOrange2)
}
