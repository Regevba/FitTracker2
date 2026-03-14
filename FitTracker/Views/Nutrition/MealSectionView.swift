// Views/Nutrition/MealSectionView.swift

import SwiftUI

struct MealSectionView: View {
    @Binding var nutritionLog: NutritionLog
    let onTapMeal: (Int) -> Void  // called with mealNumber (1-4) when meal card is tapped

    var body: some View {
        VStack(spacing: 12) {
            ForEach(1...4, id: \.self) { mealNumber in
                let entry = nutritionLog.meals.first(where: { $0.mealNumber == mealNumber })
                MealCard(mealNumber: mealNumber, entry: entry) {
                    onTapMeal(mealNumber)
                }
            }

            // "+ Add Meal" footer button
            Button {
                onTapMeal(0)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(AppType.body)
                        .foregroundStyle(Color.accent.cyan)
                    Text("Add Meal")
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
        return Color.secondary.opacity(0.15)
    }

    private var borderWidth: CGFloat {
        entry?.status == .completed ? 1.5 : 1.0
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
                        Text("Tap to log")
                            .font(AppType.subheading)
                            .foregroundStyle(Color.secondary.opacity(0.6))
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
                    .fill(Color(UIColor.secondarySystemBackground))
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
