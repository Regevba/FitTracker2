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
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            GeometryReader { geo in
                HStack(spacing: 2) {
                    let proteinWidth = geo.size.width * (protein * proteinKcal / max(totalForBar, 1))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppColor.Accent.recovery)
                        .frame(width: max(proteinWidth, 2))

                    let carbsWidth = geo.size.width * (carbs * carbsKcal / max(totalForBar, 1))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppColor.Chart.body)
                        .frame(width: max(carbsWidth, 2))

                    let fatWidth = geo.size.width * (fat * fatKcal / max(totalForBar, 1))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppColor.Chart.nutritionFat)
                        .frame(width: max(fatWidth, 2))

                    let remaining = geo.size.width * (remainingCalories / max(totalForBar, 1))
                    if remaining > 2 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppColor.Surface.tertiary)
                            .frame(width: remaining)
                    }
                }
            }
            .frame(height: 14)

            HStack(alignment: .top, spacing: AppSpacing.large) {
                macroLabel("Protein", value: protein, target: targetProteinG, color: AppColor.Accent.recovery)
                macroLabel("Carbs", value: carbs, target: targetCarbsG, color: AppColor.Chart.body)
                macroLabel("Fat", value: fat, target: targetFatG, color: AppColor.Chart.nutritionFat)
                Spacer()
                Text("\(Int(consumedCalories)) / \(targetCalories) kcal")
                    .font(AppText.captionStrong)
                    .foregroundStyle(AppColor.Text.secondary)
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
                    .font(AppText.captionStrong)
                    .foregroundStyle(AppColor.Text.secondary)
            }
            Text("\(Int(value))g")
                .font(AppText.callout)
                .foregroundStyle(AppColor.Text.primary)
            Text("Target \(Int(target))g")
                .font(AppText.caption)
                .foregroundStyle(AppColor.Text.secondary)
        }
    }
}

#if DEBUG
struct MacroTargetBar_Previews: PreviewProvider {
    static var previews: some View {
        MacroTargetBar(protein: 120, carbs: 180, fat: 55, targetCalories: 1900, targetProteinG: 130, targetCarbsG: 170, targetFatG: 55)
            .padding()
            .background(AppGradient.screenBackground)
    }
}
#endif
