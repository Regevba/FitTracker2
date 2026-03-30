// Views/Nutrition/MealSectionView.swift

import SwiftUI

struct MealSectionView: View {
    @Binding var nutritionLog: NutritionLog
    let suggestedMealNumber: Int
    var mealSlotNames: [String]
    let onTapMeal: (Int) -> Void  // called with mealNumber (1-4) when meal card is tapped

    private var displayedMealNumbers: [Int] {
        let highestLoggedMeal = nutritionLog.meals.map(\.mealNumber).max() ?? 0
        let visibleMax = max(4, highestLoggedMeal)
        return Array(1...visibleMax)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("MEALS")
                    .font(AppText.monoLabel)
                    .foregroundStyle(AppColor.Text.tertiary)
                    .tracking(1.6)
                Text("Fast log from saved meals, barcode, or a nutrition label photo.")
                    .font(AppText.subheading)
                    .foregroundStyle(AppColor.Text.secondary)
            }

            ForEach(displayedMealNumbers, id: \.self) { mealNumber in
                let entry = nutritionLog.meals.first(where: { $0.mealNumber == mealNumber })
                MealCard(mealNumber: mealNumber, entry: entry, isSuggested: mealNumber == suggestedMealNumber, mealSlotNames: mealSlotNames) {
                    onTapMeal(mealNumber)
                }

                if mealNumber != displayedMealNumbers.last {
                    Divider().opacity(0.35)
                }
            }
        }
    }
}

// MARK: - MealCard

private struct MealCard: View {
    let mealNumber: Int
    let entry: MealEntry?
    let isSuggested: Bool
    let mealSlotNames: [String]
    let onTap: () -> Void

    private var defaultName: String {
        let index = mealNumber - 1
        if mealSlotNames.indices.contains(index) {
            return mealSlotNames[index]
        }
        return "Meal \(mealNumber)"
    }

    private var displayName: String {
        if let entry, !entry.name.isEmpty {
            return entry.name
        }
        return defaultName
    }

    private var borderColor: Color {
        if entry?.status == .completed {
            return Color.status.success
        }
        if isSuggested {
            return Color.accent.cyan.opacity(0.24)
        }
        return Color.clear
    }

    private var borderWidth: CGFloat {
        if entry?.status == .completed {
            return 1.5
        }
        return isSuggested ? 1.3 : 1.0
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(entry != nil ? AppColor.Brand.warmSoft.opacity(0.2) : AppColor.Surface.materialStrong)
                        .frame(width: 40, height: 40)
                    Text("\(mealNumber)")
                        .font(AppType.body)
                        .foregroundStyle(entry != nil ? AppColor.Brand.warm : AppColor.Text.secondary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(displayName)
                        .font(AppType.body)
                        .foregroundStyle(entry != nil ? AppColor.Text.primary : AppColor.Text.secondary)

                    if let entry {
                        HStack(spacing: 8) {
                            if let calories = entry.calories {
                                Text("\(Int(calories)) kcal")
                                    .font(AppType.subheading)
                                    .foregroundStyle(AppColor.Brand.warm)
                            }
                            if let protein = entry.proteinG {
                                Text("\(Int(protein))g protein")
                                    .font(AppType.subheading)
                                    .foregroundStyle(Color.accent.cyan)
                            }
                            if let time = entry.eatenAt {
                                Text(Self.timeFormatter.string(from: time))
                                    .font(AppType.caption)
                                    .foregroundStyle(AppColor.Text.secondary)
                            }
                        }
                    } else {
                        Text(isSuggested ? "Suggested next meal" : "Tap to log")
                            .font(AppType.subheading)
                            .foregroundStyle(isSuggested ? Color.accent.cyan : AppColor.Text.secondary.opacity(0.6))
                    }
                }

                Spacer()

                if entry?.status == .completed {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.status.success)
                        .font(AppType.body)
                } else {
                    Image(systemName: "chevron.right")
                        .font(AppType.caption)
                        .foregroundStyle(AppColor.Text.secondary.opacity(0.5))
                }
            }
            .padding(.horizontal, AppSpacing.xxxSmall)
            .padding(.vertical, AppSpacing.xxxSmall)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.small)
                    .strokeBorder(borderColor, lineWidth: borderWidth)
            )
            .opacity(entry == nil ? 0.75 : 1.0)
        }
        .buttonStyle(.plain)
    }
}
