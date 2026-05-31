// Services/DataExportService.swift
// Generates JSON / CSV export of user data.
// JSON = GDPR Article 20 (full portability, all data types).
// CSV  = analytical companion — daily logs flat, one row per day (spreadsheet-friendly).

import Foundation
import SwiftUI

/// Export format choice for the data export UI.
enum DataExportFormat: String {
    case json
    case csv
}

@MainActor
final class DataExportService: ObservableObject {

    // MARK: - Published State

    @Published private(set) var isExporting = false
    @Published private(set) var exportError: String?
    @Published var exportURL: URL?

    // MARK: - Dependencies

    private let dataStore: EncryptedDataStore
    private let analytics: AnalyticsService

    // MARK: - Init

    init(dataStore: EncryptedDataStore, analytics: AnalyticsService) {
        self.dataStore = dataStore
        self.analytics = analytics
    }

    // MARK: - Data Summary

    var recordCounts: [(label: String, count: Int)] {
        [
            ("Profile", 1),
            ("Daily Logs", dataStore.dailyLogs.count),
            ("Weekly Snapshots", dataStore.weeklySnapshots.count),
            ("Preferences", 1),
            ("Imported Training Plans", dataStore.importedTrainingPlans.count),
        ]
    }

    var totalRecords: Int {
        recordCounts.reduce(0) { $0 + $1.count }
    }

    // MARK: - Export

    /// Generate JSON export and return file URL (GDPR Article 20 — full data portability).
    func generateExport() async {
        await generateExport(format: .json)
    }

    /// Generate an export in the requested format.
    /// JSON: full nested object covering all data types (GDPR portability).
    /// CSV:  daily logs only, one row per day across 23 metric columns
    ///       (analytical / spreadsheet-friendly companion to JSON).
    func generateExport(format: DataExportFormat) async {
        isExporting = true
        exportError = nil
        exportURL = nil

        analytics.logDataExportRequested()

        do {
            let dateStr = Self.fileDateFormatter.string(from: Date())
            let tempURL: URL
            let dataSize: Int

            switch format {
            case .json:
                let export: [String: Any] = [
                    "exportVersion": "1.0",
                    "exportDate": ISO8601DateFormatter().string(from: Date()),
                    "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
                    "profile": encodeProfile(),
                    "preferences": encodePreferences(),
                    "dailyLogs": encodeDailyLogs(),
                    "weeklySnapshots": encodeWeeklySnapshots(),
                    "importedTrainingPlans": encodeImportedTrainingPlans(),
                    "recordCount": totalRecords,
                ]
                let jsonData = try JSONSerialization.data(withJSONObject: export, options: [.prettyPrinted, .sortedKeys])
                let fileName = "fitme-export-\(dateStr).json"
                tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                try jsonData.write(to: tempURL)
                dataSize = jsonData.count

            case .csv:
                let csvString = generateDailyLogsCSV()
                let fileName = "fitme-export-\(dateStr).csv"
                tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                let csvData = Data(csvString.utf8)
                try csvData.write(to: tempURL)
                dataSize = csvData.count
            }

            exportURL = tempURL
            isExporting = false

            analytics.logDataExportCompleted(sizeBytes: dataSize, recordCount: totalRecords)

        } catch {
            exportError = error.localizedDescription
            isExporting = false
        }
    }

    // MARK: - CSV serializer

    /// Produce a CSV string with one row per daily log, 23 columns covering
    /// phase / readiness / biometrics / nutrition / training. RFC 4180-style
    /// field quoting (commas, newlines, double quotes escaped). Header row
    /// included. UTF-8 (no BOM) when callers write to disk.
    func generateDailyLogsCSV() -> String {
        let header = [
            "date", "phase", "dayType", "recoveryDay", "completionPct",
            "weightKg", "bodyFatPercent", "restingHR", "hrv", "sleepHours",
            "mealCount", "totalCalories", "totalProteinG", "totalCarbsG", "totalFatG", "waterML",
            "exerciseCount", "cardioCount", "totalSets", "totalVolume", "cardioMinutes",
            "completedTaskCount", "notes",
        ].joined(separator: ",")

        let rows = dataStore.dailyLogs.map(Self.csvRow(for:))

        return ([header] + rows).joined(separator: "\n") + "\n"
    }

    /// Renders a single daily log as one CSV row. Split out from
    /// `generateDailyLogsCSV()` so the Swift type-checker does not have to
    /// resolve a 23-element heterogeneous array literal in one pass — that
    /// hit the "compiler is unable to type-check this expression in
    /// reasonable time" limit on iOS Simulator builds.
    static func csvRow(for log: DailyLog) -> String {
        let bio = log.biometrics
        let nut = log.nutritionLog
        let exerciseLogs = Array(log.exerciseLogs.values)
        let cardioLogs = Array(log.cardioLogs.values)

        // Pre-compute optional + reduce helpers as plain strings before
        // assembling the array literal — keeps each line trivially typeable.
        // recoveryDay is `Int` (days-since-program-start counter), not Bool.
        // `String($0)` (closure form) avoids the multi-init overload
        // ambiguity that `String.init` triggers when mapping Optional<Double>.
        let dateStr = ISO8601DateFormatter().string(from: log.date)
        let recovery = String(log.recoveryDay)
        let completion = String(log.completionPct)

        let weightKg = bio.weightKg.map { String($0) } ?? ""
        let bodyFat = bio.bodyFatPercent.map { String($0) } ?? ""
        let restingHR = bio.effectiveRestingHR.map { String($0) } ?? ""
        let hrv = bio.effectiveHRV.map { String($0) } ?? ""
        let sleep = bio.effectiveSleep.map { String($0) } ?? ""

        let mealCount = String(nut.meals.count)
        let calories = nut.resolvedCalories.map { String($0) } ?? ""
        let protein = nut.resolvedProteinG.map { String($0) } ?? ""
        let carbs = nut.resolvedCarbsG.map { String($0) } ?? ""
        let fat = nut.resolvedFatG.map { String($0) } ?? ""
        let water = nut.waterML.map { String($0) } ?? ""

        let exerciseCount = String(exerciseLogs.count)
        let cardioCount = String(cardioLogs.count)
        let totalSets = String(exerciseLogs.reduce(0) { $0 + $1.sets.count })
        let totalVolume = String(exerciseLogs.reduce(0) { $0 + $1.totalVolume })
        let cardioMins = String(cardioLogs.compactMap(\.durationMinutes).reduce(0, +))
        let completedTasks = String(log.taskStatuses.values.filter { $0 == .completed }.count)

        let fields: [String] = [
            dateStr, log.phase.rawValue, log.dayType.rawValue, recovery, completion,
            weightKg, bodyFat, restingHR, hrv, sleep,
            mealCount, calories, protein, carbs, fat, water,
            exerciseCount, cardioCount, totalSets, totalVolume, cardioMins,
            completedTasks, log.notes,
        ]

        return fields.map(Self.csvEscape).joined(separator: ",")
    }

    /// RFC 4180 field escape: wrap in double-quotes if the field contains
    /// a comma, newline, carriage return, or double quote; escape internal
    /// double quotes by doubling them. Empty + plain alphanumeric fields
    /// pass through unquoted.
    ///
    /// Uses `unicodeScalars.contains(where:)` because Swift's grapheme-cluster
    /// `String.contains("\n")` returns false when the field contains `\r\n`
    /// — CRLF parses as a single CRLF grapheme cluster, neither `\n` alone
    /// nor `\r` alone matches it. Scalar-level scan sidesteps that.
    static func csvEscape(_ field: String) -> String {
        let needsEscape = field.unicodeScalars.contains(where: { scalar in
            scalar == "," || scalar == "\n" || scalar == "\r" || scalar == "\""
        })
        if needsEscape {
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
    }

    // MARK: - Encoders

    private func encodeProfile() -> [String: Any] {
        let p = dataStore.userProfile
        return [
            "name": p.name,
            "currentPhase": p.currentPhase.rawValue,
            "daysSinceStart": p.daysSinceStart,
            "targetWeightMin": p.targetWeightMin,
            "targetWeightMax": p.targetWeightMax,
            "targetBFMin": p.targetBFMin,
            "targetBFMax": p.targetBFMax,
        ]
    }

    private func encodePreferences() -> [String: Any] {
        let p = dataStore.userPreferences
        return [
            "unitSystem": UserDefaults.standard.string(forKey: "ft.unitSystem") ?? UnitSystem.metric.rawValue,
            "nutritionGoalMode": p.nutritionGoalMode.rawValue,
            "zone2LowerHR": p.zone2LowerHR,
            "zone2UpperHR": p.zone2UpperHR,
            "hrReadyThreshold": p.hrReadyThreshold,
            "hrvReadyThreshold": p.hrvReadyThreshold,
            "preferredStatsCarouselMetrics": p.preferredStatsCarouselMetrics,
        ]
    }

    private func encodeDailyLogs() -> [[String: Any]] {
        dataStore.dailyLogs.map { log in
            var dict: [String: Any] = [
                "date": ISO8601DateFormatter().string(from: log.date),
                "phase": log.phase.rawValue,
                "dayType": log.dayType.rawValue,
                "recoveryDay": log.recoveryDay,
                "completionPct": log.completionPct,
                "notes": log.notes,
            ]

            let exerciseLogs = Array(log.exerciseLogs.values)
            let cardioLogs = Array(log.cardioLogs.values)
            if !exerciseLogs.isEmpty || !cardioLogs.isEmpty {
                dict["training"] = [
                    "exerciseCount": exerciseLogs.count,
                    "cardioCount": cardioLogs.count,
                    "totalSets": exerciseLogs.reduce(0) { $0 + $1.sets.count },
                    "totalVolume": exerciseLogs.reduce(0) { $0 + $1.totalVolume },
                    "cardioMinutes": cardioLogs.compactMap(\.durationMinutes).reduce(0, +),
                    "completedTaskCount": log.taskStatuses.values.filter { $0 == .completed }.count,
                ]
            }

            if !log.nutritionLog.meals.isEmpty {
                dict["nutrition"] = [
                    "mealCount": log.nutritionLog.meals.count,
                    "totalCalories": log.nutritionLog.resolvedCalories as Any,
                    "totalProteinG": log.nutritionLog.resolvedProteinG as Any,
                    "totalCarbsG": log.nutritionLog.resolvedCarbsG as Any,
                    "totalFatG": log.nutritionLog.resolvedFatG as Any,
                    "waterML": log.nutritionLog.waterML as Any,
                ]
            }

            let bio = log.biometrics
            if bio.weightKg != nil ||
                bio.bodyFatPercent != nil ||
                bio.effectiveRestingHR != nil ||
                bio.effectiveHRV != nil ||
                bio.effectiveSleep != nil
            {
                var bioDict: [String: Any] = [:]
                if let w = bio.weightKg { bioDict["weightKg"] = w }
                if let bf = bio.bodyFatPercent { bioDict["bodyFatPercent"] = bf }
                if let hr = bio.effectiveRestingHR { bioDict["restingHeartRate"] = hr }
                if let hrv = bio.hrv { bioDict["hrv"] = hrv }
                if let sleep = bio.effectiveSleep { bioDict["sleepHours"] = sleep }
                if !bioDict.isEmpty { dict["biometrics"] = bioDict }
            }

            return dict
        }
    }

    /// GDPR Article 20 — exports the user's imported training plans as
    /// portable structured data. Each plan emits its identity, provenance,
    /// active flag, and every day's exercise list (raw + mapped names,
    /// sets/reps/rest). `sourceText` is included only when the user opted to
    /// retain it at import time (privacy-first default OFF).
    private func encodeImportedTrainingPlans() -> [[String: Any]] {
        dataStore.importedTrainingPlans.map { plan in
            var dict: [String: Any] = [
                "id": plan.id.uuidString,
                "name": plan.name,
                "createdAt": ISO8601DateFormatter().string(from: plan.createdAt),
                "lastModified": ISO8601DateFormatter().string(from: plan.lastModified),
                "source": plan.source.rawValue,
                "isActive": plan.isActive,
            ]
            if let raw = plan.sourceText { dict["sourceText"] = raw }
            dict["days"] = plan.days.map { day in
                [
                    "originalDayName": day.originalDayName,
                    "assignedDayType": day.assignedDayType.rawValue,
                    "exercises": day.exercises.map { entry in
                        var exDict: [String: Any] = [
                            "rawName": entry.rawName,
                            "sets": entry.sets,
                            "reps": entry.reps,
                        ]
                        if let mapped = entry.mappedExerciseId { exDict["mappedExerciseId"] = mapped }
                        if let conf = entry.mappingConfidence { exDict["mappingConfidence"] = conf }
                        if let rest = entry.restSeconds { exDict["restSeconds"] = rest }
                        return exDict
                    },
                ]
            }
            return dict
        }
    }

    private func encodeWeeklySnapshots() -> [[String: Any]] {
        dataStore.weeklySnapshots.map { snap in
            [
                "weekStart": ISO8601DateFormatter().string(from: snap.weekStart),
                "weekNumber": snap.weekNumber,
                "avgWeightKg": snap.avgWeightKg as Any,
                "avgBodyFatPct": snap.avgBodyFatPct as Any,
                "avgRestingHR": snap.avgRestingHR as Any,
                "avgHRV": snap.avgHRV as Any,
                "avgSleepHours": snap.avgSleepHours as Any,
                "avgProteinG": snap.avgProteinG as Any,
                "totalTrainingDays": snap.totalTrainingDays,
                "totalVolume": snap.totalVolume,
                "totalCardioMinutes": snap.totalCardioMinutes,
                "taskAdherence": snap.taskAdherence,
                "weightChange": snap.weightChange as Any,
                "bfChange": snap.bfChange as Any,
            ]
        }
    }

    private static let fileDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
