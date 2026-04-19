// FitTracker/Views/Nutrition/Parsing/NutritionLabelParser.swift
// Bilingual (English / Hebrew) nutrition label parser. Pure logic — no UI.
// Extracted from MealEntrySheet.swift in Audit M-2a (UI-004 decomposition).

import Foundation

enum ParsedNutritionLanguageHint {
    case english
    case hebrew
    case mixed
}

struct ParsedNutritionLabel {
    var referenceGrams: Double
    var calories: Double?
    var proteinG: Double?
    var carbsG: Double?
    var fatG: Double?
    var nameHint: String?
    var detectedLanguageHint: ParsedNutritionLanguageHint
}

enum NutritionLabelParser {
    static func parse(_ rawText: String, fallbackReferenceGrams: Double) -> ParsedNutritionLabel? {
        let normalized = rawText
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: ",", with: ".")
            .lowercased()

        let lines = normalized
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else { return nil }

        let referenceGrams = detectReferenceGrams(in: lines) ?? fallbackReferenceGrams
        let calories = extractCalories(in: lines)
        let protein = extractValue(in: lines, keywords: ["protein", "proteins", "חלבון", "חלבונים"])
        let carbs = extractValue(in: lines, keywords: ["carbs", "carbohydrate", "carbohydrates", "פחמימה", "פחמימות"])
        let fat = extractValue(in: lines, keywords: ["fat", "total fat", "שומן", "שומנים"])

        guard calories != nil || protein != nil || carbs != nil || fat != nil else { return nil }

        let languageHint: ParsedNutritionLanguageHint
        if normalized.contains(where: { $0.unicodeScalars.contains(where: { $0.value >= 0x0590 && $0.value <= 0x05FF }) }) {
            languageHint = normalized.contains("protein") || normalized.contains("fat") ? .mixed : .hebrew
        } else {
            languageHint = .english
        }

        return ParsedNutritionLabel(
            referenceGrams: referenceGrams,
            calories: calories,
            proteinG: protein,
            carbsG: carbs,
            fatG: fat,
            nameHint: lines.first(where: { !$0.contains("calories") && !$0.contains("חלבון") && !$0.contains("פחמ") && !$0.contains("שומן") }),
            detectedLanguageHint: languageHint
        )
    }

    private static func detectReferenceGrams(in lines: [String]) -> Double? {
        if lines.contains(where: { $0.contains("100g") || $0.contains("100 g") || $0.contains("100גרם") || $0.contains("100 גרם") || $0.contains("ל-100") }) {
            return 100
        }

        let referenceKeywords = ["serving", "serving size", "מנה", "כמות למנה", "portion"]
        for line in lines where referenceKeywords.contains(where: { line.contains($0) }) {
            if let grams = extractGrams(from: line) {
                return grams
            }
        }
        return nil
    }

    private static func extractCalories(in lines: [String]) -> Double? {
        for line in lines where ["calories", "energy", "kcal", "קלוריות", "אנרגיה"].contains(where: { line.contains($0) }) {
            let values = extractNumbers(from: line)
            if line.contains("kcal"), let kcal = values.last(where: { $0 < 1200 }) {
                return kcal
            }
            if let single = values.first {
                return single
            }
        }
        return nil
    }

    private static func extractValue(in lines: [String], keywords: [String]) -> Double? {
        for line in lines where keywords.contains(where: { line.contains($0) }) {
            if let value = extractNumbers(from: line).first {
                return value
            }
        }
        return nil
    }

    private static func extractGrams(from line: String) -> Double? {
        let pattern = #"(\d+(?:\.\d+)?)\s*(?:g|gr|gram|grams|גרם)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, options: [], range: nsRange),
              let range = Range(match.range(at: 1), in: line) else { return nil }
        return Double(String(line[range]))
    }

    private static func extractNumbers(from line: String) -> [Double] {
        let pattern = #"\d+(?:\.\d+)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }
        let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
        return regex.matches(in: line, options: [], range: nsRange).compactMap { match in
            guard let range = Range(match.range(at: 0), in: line) else { return nil }
            return Double(String(line[range]))
        }
    }
}
