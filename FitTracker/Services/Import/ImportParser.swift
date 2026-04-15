import Foundation

// Protocol for all import parsers
protocol ImportParser {
    func canParse(_ input: String) -> Bool
    func parse(_ input: String) throws -> ImportedPlan
}

// Imported plan model
struct ImportedPlan: Codable {
    let name: String
    var days: [ImportedDay]
}

struct ImportedDay: Codable {
    let name: String // e.g. "Day 1 — Push"
    var exercises: [ImportedExercise]
}

struct ImportedExercise: Codable {
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
