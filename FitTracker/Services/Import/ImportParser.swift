import Foundation

// Protocol for all import parsers
protocol ImportParser {
    func canParse(_ input: String) -> Bool
    func parse(_ input: String) throws -> ImportedPlan
}

// Imported plan model
struct ImportedPlan: Codable, Equatable {
    let name: String
    var days: [ImportedDay]
}

struct ImportedDay: Codable, Equatable {
    let name: String // e.g. "Day 1 — Push"
    var exercises: [ImportedExercise]
}

struct ImportedExercise: Codable, Equatable {
    let rawName: String
    let sets: Int
    let reps: String // "8" or "8-10"
    let restSeconds: Int?
    var mappedExerciseId: String? // FitMe exercise ID after mapping
    var mappingConfidence: Double? // 0.0 - 1.0
}

// CSV Parser (T1)
struct CSVImportParser: ImportParser {
    func canParse(_ input: String) -> Bool {
        // Check for comma-separated structure with header row
        let lines = input.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard lines.count >= 2 else { return false }
        return lines[0].contains(",") && lines[0].lowercased().contains("exercise")
    }

    func parse(_ input: String) throws -> ImportedPlan {
        let lines = input.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard lines.count >= 2 else { throw ImportError.emptyInput }

        var exercises: [ImportedExercise] = []
        for line in lines.dropFirst() {
            let cols = line.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            guard cols.count >= 2 else { continue }
            exercises.append(ImportedExercise(
                rawName: cols[0],
                sets: Int(cols.safe(1) ?? "") ?? 3,
                reps: cols.safe(2) ?? "8",
                restSeconds: Int(cols.safe(3) ?? ""),
                mappedExerciseId: nil,
                mappingConfidence: nil
            ))
        }

        return ImportedPlan(
            name: "Imported Plan",
            days: [ImportedDay(name: "Day 1", exercises: exercises)]
        )
    }
}

// JSON Parser (T2)
struct JSONImportParser: ImportParser {
    func canParse(_ input: String) -> Bool {
        guard let data = input.data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: data)) != nil
    }

    func parse(_ input: String) throws -> ImportedPlan {
        guard let data = input.data(using: .utf8) else { throw ImportError.emptyInput }

        // Try direct ImportedPlan decode first
        if let plan = try? JSONDecoder().decode(ImportedPlan.self, from: data) {
            return plan
        }

        // Try array-of-exercises format
        if let exercises = try? JSONDecoder().decode([ImportedExercise].self, from: data) {
            return ImportedPlan(name: "Imported Plan", days: [ImportedDay(name: "Day 1", exercises: exercises)])
        }

        throw ImportError.parsingFailed("JSON structure not recognized")
    }
}

// Markdown Parser (T3)
struct MarkdownImportParser: ImportParser {
    func canParse(_ input: String) -> Bool {
        // Detect markdown tables or numbered exercise lists
        let lines = input.components(separatedBy: .newlines)
        let hasTable = lines.contains { $0.contains("|") && $0.contains("---") }
        let hasNumberedList = lines.contains { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let first = trimmed.first, first.isNumber else { return false }
            return trimmed.contains(".") || trimmed.contains(")")
        }
        return hasTable || hasNumberedList
    }

    func parse(_ input: String) throws -> ImportedPlan {
        let lines = input.components(separatedBy: .newlines).filter { !$0.isEmpty }

        // Try table format first
        if lines.contains(where: { $0.contains("|") }) {
            return try parseTable(lines)
        }

        // Try numbered list format
        return try parseNumberedList(lines)
    }

    private func parseTable(_ lines: [String]) throws -> ImportedPlan {
        var exercises: [ImportedExercise] = []
        for line in lines {
            let cols = line.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            guard cols.count >= 2 else { continue }
            guard !cols[0].contains("---") else { continue } // Skip separator
            guard !cols[0].lowercased().contains("exercise") else { continue } // Skip header

            exercises.append(ImportedExercise(
                rawName: cols[0],
                sets: cols.count > 1 ? (Int(cols[1]) ?? 3) : 3,
                reps: cols.count > 2 ? cols[2] : "8",
                restSeconds: cols.count > 3 ? Int(cols[3]) : nil,
                mappedExerciseId: nil,
                mappingConfidence: nil
            ))
        }
        guard !exercises.isEmpty else { throw ImportError.parsingFailed("No exercises found in table") }
        return ImportedPlan(name: "Imported Plan", days: [ImportedDay(name: "Day 1", exercises: exercises)])
    }

    private func parseNumberedList(_ lines: [String]) throws -> ImportedPlan {
        var exercises: [ImportedExercise] = []
        for line in lines {
            // Match "1. Bench Press 3x8" or "1) Squat - 4 sets x 6 reps"
            let cleaned = line.replacingOccurrences(of: #"^\d+[\.\)]\s*"#, with: "", options: .regularExpression)
            guard !cleaned.isEmpty else { continue }

            let parts = cleaned.components(separatedBy: CharacterSet(charactersIn: "-–—×x")).map { $0.trimmingCharacters(in: .whitespaces) }
            exercises.append(ImportedExercise(
                rawName: parts[0],
                sets: parts.count > 1 ? (Int(parts[1].filter(\.isNumber)) ?? 3) : 3,
                reps: parts.count > 2 ? parts[2].filter { $0.isNumber || $0 == "-" } : "8",
                restSeconds: nil,
                mappedExerciseId: nil,
                mappingConfidence: nil
            ))
        }
        guard !exercises.isEmpty else { throw ImportError.parsingFailed("No exercises found in list") }
        return ImportedPlan(name: "Imported Plan", days: [ImportedDay(name: "Day 1", exercises: exercises)])
    }
}

enum ImportError: Error, LocalizedError {
    case emptyInput
    case unsupportedFormat
    case parsingFailed(String)

    var errorDescription: String? {
        switch self {
        case .emptyInput: "No content to import"
        case .unsupportedFormat: "This format isn't supported yet"
        case .parsingFailed(let detail): "Couldn't parse: \(detail)"
        }
    }
}

private extension Array where Element == String {
    func safe(_ index: Int) -> String? {
        indices.contains(index) ? self[index] : nil
    }
}
