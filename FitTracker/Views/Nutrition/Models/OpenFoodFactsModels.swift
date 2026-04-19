// FitTracker/Views/Nutrition/Models/OpenFoodFactsModels.swift
// Open Food Facts API DTOs + parsed FoodProduct view model.
// Extracted from MealEntrySheet.swift in Audit M-2a (UI-004 decomposition).

import Foundation

// Audit UI-017: visibility bumped from `private` to internal so
// FoodSearchService can decode these. Otherwise unchanged.
struct OFFSearchResponse: Decodable {
    var products: [OFFProduct]
}

struct OFFProductResponse: Decodable {
    var product: OFFProduct?
}

struct OFFProduct: Decodable {
    var product_name: String?

    struct Nutriments: Decodable {
        var energyKcal100g: Double?
        var proteins100g:   Double?
        var carbohydrates100g: Double?
        var fat100g:        Double?

        enum CodingKeys: String, CodingKey {
            case energyKcal100g    = "energy-kcal_100g"
            case proteins100g      = "proteins_100g"
            case carbohydrates100g = "carbohydrates_100g"
            case fat100g           = "fat_100g"
        }
    }
    var nutriments: Nutriments?
}

// ─────────────────────────────────────────────────────────
// MARK: – Parsed food product (view model)
// ─────────────────────────────────────────────────────────

// Audit UI-017: visibility bumped from `private` to internal so
// FoodSearchService can produce these. Otherwise unchanged.
struct FoodProduct: Identifiable {
    let id = UUID()
    var name:             String
    var caloriesPer100g:  Double?
    var proteinPer100g:   Double?
    var carbsPer100g:     Double?
    var fatPer100g:       Double?
    var referenceGrams:   Double = 100
    var source:           MealEntrySource = .search
    var sourceDescription: String = "Open Food Facts"
    var searchAliases:    [String] = []

    init?(from raw: OFFProduct) {
        name             = raw.product_name ?? ""
        caloriesPer100g  = raw.nutriments?.energyKcal100g.flatMap    { $0 > 0 ? $0 : nil }
        proteinPer100g   = raw.nutriments?.proteins100g.flatMap       { $0 > 0 ? $0 : nil }
        carbsPer100g     = raw.nutriments?.carbohydrates100g.flatMap  { $0 > 0 ? $0 : nil }
        fatPer100g       = raw.nutriments?.fat100g.flatMap            { $0 > 0 ? $0 : nil }
        source = .barcode
        sourceDescription = "Open Food Facts barcode or text search"
        searchAliases = [name]
        return  // always succeed — caller filters empty names in UI
    }

    init(
        name: String,
        caloriesPer100g: Double?,
        proteinPer100g: Double?,
        carbsPer100g: Double?,
        fatPer100g: Double?,
        aliases: [String]
    ) {
        self.name = name
        self.caloriesPer100g = caloriesPer100g
        self.proteinPer100g = proteinPer100g
        self.carbsPer100g = carbsPer100g
        self.fatPer100g = fatPer100g
        self.referenceGrams = 100
        self.source = .search
        self.sourceDescription = "Built-in reference food"
        self.searchAliases = aliases
    }

    static let referenceFoods: [FoodProduct] = [
        .init(name: "White Rice / אורז לבן", caloriesPer100g: 130, proteinPer100g: 2.4, carbsPer100g: 28.2, fatPer100g: 0.3, aliases: ["white rice", "rice", "אורז", "אורז לבן"]),
        .init(name: "Chicken Breast / חזה עוף", caloriesPer100g: 165, proteinPer100g: 31.0, carbsPer100g: 0, fatPer100g: 3.6, aliases: ["chicken breast", "chicken", "חזה עוף", "עוף"]),
        .init(name: "Greek Yogurt / יוגורט יווני", caloriesPer100g: 97, proteinPer100g: 9.0, carbsPer100g: 3.9, fatPer100g: 5.0, aliases: ["greek yogurt", "יוגורט יווני", "יוגורט"]),
        .init(name: "Oats / שיבולת שועל", caloriesPer100g: 389, proteinPer100g: 16.9, carbsPer100g: 66.3, fatPer100g: 6.9, aliases: ["oats", "oatmeal", "שיבולת שועל", "קוואקר"]),
        .init(name: "Egg / ביצה", caloriesPer100g: 143, proteinPer100g: 12.6, carbsPer100g: 0.7, fatPer100g: 9.5, aliases: ["egg", "eggs", "ביצה", "ביצים"])
    ]
}
