// Views/Nutrition/MealSectionView.swift

import SwiftUI

struct MealSectionView: View {
    @Binding var nutritionLog: NutritionLog
    let suggestedMealNumber: Int
    let onTapMeal: (Int) -> Void  // called with mealNumber (1-4) when meal card is tapped

    private var displayedMealNumbers: [Int] {
        let highestLoggedMeal = nutritionLog.meals.map(\.mealNumber).max() ?? 0
        let visibleMax = max(4, highestLoggedMeal)
        return Array(1...visibleMax)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Meals")
                    .font(.headline)
                Text("Fast log from your saved meals, or open a fresh slot.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(displayedMealNumbers, id: \.self) { mealNumber in
                let entry = nutritionLog.meals.first(where: { $0.mealNumber == mealNumber })
                MealCard(mealNumber: mealNumber, entry: entry, isSuggested: mealNumber == suggestedMealNumber) {
                    onTapMeal(mealNumber)
                }
            }

            // "+ Add Meal" footer button
            Button {
                onTapMeal(suggestedMealNumber)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(AppType.body)
                        .foregroundStyle(Color.accent.cyan)
                    Text(suggestedMealNumber > displayedMealNumbers.count ? "Add Meal \(suggestedMealNumber)" : "Add Another Meal")
                        .font(AppType.body)
                        .foregroundStyle(Color.accent.cyan)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.accent.cyan.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.accent.cyan.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - MealCard

private struct MealCard: View {
    let mealNumber: Int
    let entry: MealEntry?
    let isSuggested: Bool
    let onTap: () -> Void

    private var defaultName: String {
        switch mealNumber {
        case 1: return "Breakfast"
        case 2: return "Lunch"
        case 3: return "Dinner"
        case 4: return "Snacks"
        default: return "Meal \(mealNumber)"
        }
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
            return Color.accent.cyan.opacity(0.45)
        }
        return Color.secondary.opacity(0.15)
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
                // Meal number indicator
                ZStack {
                    Circle()
                        .fill(entry != nil ? Color.appOrange1.opacity(0.25) : Color.secondary.opacity(0.1))
                        .frame(width: 36, height: 36)
                    Text("\(mealNumber)")
                        .font(AppType.body)
                        .foregroundStyle(entry != nil ? Color.appOrange2 : Color.secondary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(displayName)
                        .font(AppType.body)
                        .foregroundStyle(entry != nil ? Color.primary : Color.secondary)

                    if let entry {
                        HStack(spacing: 8) {
                            if let calories = entry.calories {
                                Text("\(Int(calories)) kcal")
                                    .font(AppType.subheading)
                                    .foregroundStyle(Color.appOrange2)
                            }
                            if let protein = entry.proteinG {
                                Text("\(Int(protein))g protein")
                                    .font(AppType.subheading)
                                    .foregroundStyle(Color.accent.cyan)
                            }
                            if let time = entry.eatenAt {
                                Text(Self.timeFormatter.string(from: time))
                                    .font(AppType.caption)
                                    .foregroundStyle(Color.secondary)
                            }
                        }
                    } else {
                        Text(isSuggested ? "Suggested next meal" : "Tap to log")
                            .font(AppType.subheading)
                            .foregroundStyle(isSuggested ? Color.accent.cyan : Color.secondary.opacity(0.6))
                    }
                }

                Spacer()

                // Status indicator / chevron
                if entry?.status == .completed {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.status.success)
                        .font(AppType.body)
                } else {
                    Image(systemName: "chevron.right")
                        .font(AppType.caption)
                        .foregroundStyle(Color.secondary.opacity(0.5))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSuggested ? Color.accent.cyan.opacity(0.08) : Color(UIColor.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(borderColor, lineWidth: borderWidth)
            )
            .opacity(entry == nil ? 0.75 : 1.0)
        }
        .buttonStyle(.plain)
    }
}
