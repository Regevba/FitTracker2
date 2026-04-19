// FitTracker/Views/Settings/v2/Screens/TrainingNutritionSettingsScreen.swift
// Settings v2 — Training & Nutrition detail screen.
// Extracted from SettingsView.swift in Audit M-1a (UI-002 decomposition).

import SwiftUI

struct TrainingNutritionSettingsScreen: View {
    @EnvironmentObject private var dataStore: EncryptedDataStore

    var body: some View {
        SettingsDetailScaffold(
            title: SettingsCategory.trainingNutrition.title,
            subtitle: "Tune the strategy that drives your nutrition recommendations and the thresholds used for training and readiness logic."
        ) {
            SettingsSectionCard(title: "HR & Intervals", eyebrow: "Training") {
                SettingsSliderRow(
                    title: "Zone 2 Lower HR",
                    valueText: "\(dataStore.userPreferences.zone2LowerHR) bpm",
                    value: Binding(
                        get: { Double(dataStore.userPreferences.zone2LowerHR) },
                        set: {
                            let newValue = Int($0)
                            dataStore.userPreferences.zone2LowerHR = min(newValue, dataStore.userPreferences.zone2UpperHR - 1)
                        }
                    ),
                    range: 80...160
                ) {
                    Task { await dataStore.persistToDisk() }
                }

                SettingsSliderRow(
                    title: "Zone 2 Upper HR",
                    valueText: "\(dataStore.userPreferences.zone2UpperHR) bpm",
                    value: Binding(
                        get: { Double(dataStore.userPreferences.zone2UpperHR) },
                        set: {
                            let newValue = Int($0)
                            dataStore.userPreferences.zone2UpperHR = max(newValue, dataStore.userPreferences.zone2LowerHR + 1)
                        }
                    ),
                    range: 90...180
                ) {
                    Task { await dataStore.persistToDisk() }
                }
            }

            SettingsSectionCard(title: "Readiness Thresholds", eyebrow: "Training") {
                SettingsSliderRow(
                    title: "Readiness HR Threshold",
                    valueText: "\(dataStore.userPreferences.hrReadyThreshold) bpm",
                    value: Binding(
                        get: { Double(dataStore.userPreferences.hrReadyThreshold) },
                        set: { dataStore.userPreferences.hrReadyThreshold = Int($0) }
                    ),
                    range: 40...80
                ) {
                    Task { await dataStore.persistToDisk() }
                }

                SettingsSliderRow(
                    title: "Readiness HRV Threshold",
                    valueText: "\(Int(dataStore.userPreferences.hrvReadyThreshold)) ms",
                    value: $dataStore.userPreferences.hrvReadyThreshold,
                    range: 10...80
                ) {
                    Task { await dataStore.persistToDisk() }
                }
            }
        }
        .navigationTitle(SettingsCategory.trainingNutrition.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var nutritionGoalModeBinding: Binding<NutritionGoalMode> {
        Binding(
            get: { dataStore.userPreferences.nutritionGoalMode },
            set: {
                dataStore.userPreferences.nutritionGoalMode = $0
                Task { await dataStore.persistToDisk() }
            }
        )
    }
}
