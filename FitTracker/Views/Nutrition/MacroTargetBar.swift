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
    let targetCarbsG: Double
    let targetFatG: Double

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
        VStack(alignment: .leading, spacing: 12) {
            GeometryReader { geo in
                HStack(spacing: 2) {
                    let proteinWidth = geo.size.width * (protein * proteinKcal / max(totalForBar, 1))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accent.cyan)
                        .frame(width: max(proteinWidth, 2))

                    let carbsWidth = geo.size.width * (carbs * carbsKcal / max(totalForBar, 1))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.appOrange2)
                        .frame(width: max(carbsWidth, 2))

                    let fatWidth = geo.size.width * (fat * fatKcal / max(totalForBar, 1))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(red: 0.60, green: 0.35, blue: 0.15))
                        .frame(width: max(fatWidth, 2))

                    let remaining = geo.size.width * (remainingCalories / max(totalForBar, 1))
                    if remaining > 2 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.26))
                            .frame(width: remaining)
                    }
                }
            }
            .frame(height: 14)

            HStack(alignment: .top, spacing: 18) {
                macroLabel("Protein", value: protein, target: targetProteinG, color: Color.accent.cyan)
                macroLabel("Carbs", value: carbs, target: targetCarbsG, color: Color.appOrange2)
                macroLabel("Fat", value: fat, target: targetFatG, color: Color(red: 0.60, green: 0.35, blue: 0.15))
                Spacer()
                Text("\(Int(consumedCalories)) / \(targetCalories) kcal")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Macro targets")
        .accessibilityValue("\(Int(protein)) grams protein, \(Int(carbs)) grams carbs, \(Int(fat)) grams fat, \(Int(consumedCalories)) of \(targetCalories) calories")
    }

    private func macroLabel(_ title: String, value: Double, target: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text("\(Int(value))g")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Text("Target \(Int(target))g")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

#if DEBUG
struct MacroTargetBar_Previews: PreviewProvider {
    static var previews: some View {
        MacroTargetBar(protein: 120, carbs: 180, fat: 55, targetCalories: 1900, targetProteinG: 130, targetCarbsG: 170, targetFatG: 55)
            .padding()
            .background(Color.appOrange2)
    }
}
#endif
