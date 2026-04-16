import Foundation

struct ExerciseMapper {
    // Confidence tiers for UI display
    static let autoAcceptThreshold: Double = 0.95
    static let reviewThreshold: Double = 0.70
    // >= 0.95: auto-accept (green check)
    // 0.70-0.94: needs review (orange pencil)
    // < 0.70: unmatched (red warning)

    // Map raw exercise name to FitMe exercise ID with confidence score
    func map(_ rawName: String) -> (exerciseId: String?, confidence: Double) {
        let normalized = rawName.lowercased().trimmingCharacters(in: .whitespaces)

        // Exact match
        if let id = aliases[normalized] {
            return (id, 1.0)
        }

        // Fuzzy match — check if any alias is contained in the input
        for (alias, id) in aliases {
            if normalized.contains(alias) || alias.contains(normalized) {
                return (id, 0.85)
            }
        }

        // Partial word match
        let words = Set(normalized.components(separatedBy: .whitespaces))
        var bestMatch: (String, Double) = ("", 0)
        for (alias, id) in aliases {
            let aliasWords = Set(alias.components(separatedBy: .whitespaces))
            let overlap = Double(words.intersection(aliasWords).count) / Double(max(words.count, aliasWords.count))
            if overlap > bestMatch.1 {
                bestMatch = (id, overlap)
            }
        }

        if bestMatch.1 >= 0.5 {
            return (bestMatch.0, bestMatch.1)
        }

        return (nil, 0)
    }

    // Common aliases for the 87-exercise library
    // Maps lowercase alias → FitMe exercise identifier
    private let aliases: [String: String] = [
        "bench press": "bench_press",
        "flat bench": "bench_press",
        "barbell bench": "bench_press",
        "incline bench": "incline_bench_press",
        "incline db press": "incline_db_press",
        "overhead press": "overhead_press",
        "ohp": "overhead_press",
        "military press": "overhead_press",
        "lateral raise": "lateral_raises",
        "lateral raises": "lateral_raises",
        "side raises": "lateral_raises",
        "squat": "barbell_squat",
        "back squat": "barbell_squat",
        "barbell squat": "barbell_squat",
        "front squat": "front_squat",
        "deadlift": "deadlift",
        "conventional deadlift": "deadlift",
        "romanian deadlift": "romanian_deadlift",
        "rdl": "romanian_deadlift",
        "pull up": "pull_ups",
        "pull-up": "pull_ups",
        "pullup": "pull_ups",
        "chin up": "chin_ups",
        "chin-up": "chin_ups",
        "barbell row": "barbell_rows",
        "bent over row": "barbell_rows",
        "dumbbell row": "dumbbell_rows",
        "db row": "dumbbell_rows",
        "bicep curl": "bicep_curls",
        "barbell curl": "bicep_curls",
        "dumbbell curl": "bicep_curls",
        "tricep pushdown": "tricep_pushdowns",
        "cable pushdown": "tricep_pushdowns",
        "leg press": "leg_press",
        "leg curl": "leg_curls",
        "leg extension": "leg_extensions",
        "calf raise": "calf_raises",
        "plank": "plank",
        "face pull": "face_pulls",
    ]
}
