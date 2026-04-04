// Services/DataExportService.swift
// Generates a JSON export of all user data for GDPR Article 20 compliance.
// Export includes: profile, preferences, daily logs, weekly snapshots, meal templates.

import Foundation
import SwiftUI

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
        ]
    }

    var totalRecords: Int {
        recordCounts.reduce(0) { $0 + $1.count }
    }

    // MARK: - Export

    /// Generate JSON export and return file URL
    func generateExport() async {
        isExporting = true
        exportError = nil
        exportURL = nil

        analytics.logDataExportRequested()

        do {
            // Build export dictionary
            let export: [String: Any] = [
                "exportVersion": "1.0",
                "exportDate": ISO8601DateFormatter().string(from: Date()),
                "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
                "profile": encodeProfile(),
                "preferences": encodePreferences(),
                "dailyLogs": encodeDailyLogs(),
                "weeklySnapshots": encodeWeeklySnapshots(),
                "recordCount": totalRecords,
            ]

            // Serialize to JSON
            let jsonData = try JSONSerialization.data(withJSONObject: export, options: [.prettyPrinted, .sortedKeys])

            // Write to temp file
            let dateStr = Self.fileDateFormatter.string(from: Date())
            let fileName = "fitme-export-\(dateStr).json"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            try jsonData.write(to: tempURL)

            exportURL = tempURL
            isExporting = false

            analytics.logDataExportCompleted(sizeBytes: jsonData.count, recordCount: totalRecords)

        } catch {
            exportError = error.localizedDescription
            isExporting = false
        }
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
            "unitSystem": p.unitSystem.rawValue,
            "nutritionGoalMode": p.nutritionGoalMode.rawValue,
            "zone2LowerHR": p.zone2LowerHR,
            "zone2UpperHR": p.zone2UpperHR,
            "hrReadyThreshold": p.hrReadyThreshold,
            "hrvReadyThreshold": p.hrvReadyThreshold,
        ]
    }

    private func encodeDailyLogs() -> [[String: Any]] {
        dataStore.dailyLogs.map { log in
            var dict: [String: Any] = [
                "date": ISO8601DateFormatter().string(from: log.date),
            ]
            // Training data (if present)
            if !log.trainingLog.exercises.isEmpty {
                dict["training"] = [
                    "dayType": log.trainingLog.dayType.rawValue,
                    "exerciseCount": log.trainingLog.exercises.count,
                    "totalSets": log.trainingLog.exercises.reduce(0) { $0 + $1.sets.count },
                    "durationSeconds": log.trainingLog.durationSeconds,
                    "completed": log.trainingLog.isComplete,
                ]
            }
            // Nutrition data (if present)
            if !log.nutritionLog.meals.isEmpty {
                dict["nutrition"] = [
                    "mealCount": log.nutritionLog.meals.count,
                    "totalCalories": log.nutritionLog.totalCalories,
                    "totalProtein": log.nutritionLog.totalProtein,
                    "totalCarbs": log.nutritionLog.totalCarbs,
                    "totalFat": log.nutritionLog.totalFat,
                ]
            }
            // Biometrics (if present)
            if let bio = log.biometrics {
                var bioDict: [String: Any] = [:]
                if let w = bio.weightKg { bioDict["weightKg"] = w }
                if let bf = bio.bodyFatPct { bioDict["bodyFatPct"] = bf }
                if let hr = bio.restingHR { bioDict["restingHR"] = hr }
                if let hrv = bio.hrv { bioDict["hrv"] = hrv }
                if let sleep = bio.sleepHours { bioDict["sleepHours"] = sleep }
                if !bioDict.isEmpty { dict["biometrics"] = bioDict }
            }
            return dict
        }
    }

    private func encodeWeeklySnapshots() -> [[String: Any]] {
        dataStore.weeklySnapshots.map { snap in
            [
                "weekStart": ISO8601DateFormatter().string(from: snap.weekStart),
                "avgWeight": snap.avgWeight as Any,
                "avgBodyFat": snap.avgBodyFat as Any,
                "trainingDays": snap.trainingDays,
                "adherenceScore": snap.adherenceScore,
            ]
        }
    }

    private static let fileDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
