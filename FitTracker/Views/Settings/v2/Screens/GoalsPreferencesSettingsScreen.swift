// FitTracker/Views/Settings/v2/Screens/GoalsPreferencesSettingsScreen.swift
// Settings v2 — Goals & Preferences detail screen.
// Extracted from SettingsView.swift in Audit M-1a (UI-002 decomposition).

import SwiftUI

struct GoalsPreferencesSettingsScreen: View {
    @EnvironmentObject private var dataStore: EncryptedDataStore
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        SettingsDetailScaffold(
            title: SettingsCategory.goalsPreferences.title,
            subtitle: "Personalize the app’s presentation, choose how stats are surfaced, and keep body-composition targets in one place."
        ) {
            SettingsSectionCard(title: "Profile Snapshot", eyebrow: "Goals") {
                SettingsValueRow(title: "Name", value: dataStore.userProfile.name)
                SettingsValueRow(title: "Recovery Start", value: Self.recoveryStartFormatter.string(from: dataStore.userProfile.recoveryStart))
                SettingsValueRow(title: "Phase", value: dataStore.userProfile.currentPhase.rawValue)
                SettingsValueRow(title: "Recovery Day", value: "Day \(dataStore.userProfile.daysSinceStart)")
            }

            SettingsSectionCard(title: "Body Goals", eyebrow: "Goals") {
                SettingsNumericFieldRow(title: "Goal Weight Min", suffix: settings.unitSystem.weightLabel(), value: goalWeightMinBinding)
                SettingsNumericFieldRow(title: "Goal Weight Max", suffix: settings.unitSystem.weightLabel(), value: goalWeightMaxBinding)
                SettingsNumericFieldRow(title: "Goal Body Fat Min", suffix: "%", value: goalBodyFatMinBinding)
                SettingsNumericFieldRow(title: "Goal Body Fat Max", suffix: "%", value: goalBodyFatMaxBinding)
            }

            SettingsSectionCard(title: "Units", eyebrow: "Preferences") {
                SettingsChoiceGrid(options: UnitSystem.allCases, selection: $settings.unitSystem) { system in
                    SettingsSelectionTile(
                        title: system.rawValue,
                        subtitle: system == .metric ? "kg · cm · km" : "lbs · in · mi",
                        isSelected: settings.unitSystem == system,
                        tint: AppColor.Accent.achievement
                    )
                }
            }

            SettingsSectionCard(title: "Appearance", eyebrow: "Preferences") {
                SettingsChoiceGrid(options: AppAppearance.allCases, selection: $settings.appearance) { mode in
                    SettingsSelectionTile(
                        title: mode.rawValue,
                        subtitle: mode == .system ? "Follow the device setting" : "Force \(mode.rawValue.lowercased()) mode",
                        isSelected: settings.appearance == mode,
                        tint: AppColor.Accent.sleep
                    )
                }
            }

            SettingsSectionCard(title: "Stats Carousel", eyebrow: "Preferences") {
                SettingsSupportingText("Weight and Body Fat stay pinned on the stats screen. Choose which extra metrics appear in Track More.")

                ForEach(statsMetricOptions) { metric in
                    Button {
                        toggleStatsMetric(metric)
                    } label: {
                        HStack(spacing: AppSpacing.xSmall) {
                            Image(systemName: metric.icon)
                                .font(AppText.captionStrong)
                                .foregroundStyle(metric.tint)
                                .frame(width: 20)

                            Text(metric.title)
                                .font(AppText.body)
                                .foregroundStyle(AppColor.Text.primary)

                            Spacer()

                            Image(systemName: isStatsMetricVisible(metric) ? "checkmark.circle.fill" : "circle")
                                .font(AppText.sectionTitle)
                                .foregroundStyle(isStatsMetricVisible(metric) ? metric.tint : AppColor.Text.tertiary)
                        }
                        .padding(.vertical, AppSpacing.xxxSmall)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(metric.title)
                    .accessibilityValue(isStatsMetricVisible(metric) ? "Shown in carousel" : "Hidden from carousel")
                    .accessibilityHint("Double tap to toggle whether \(metric.title) appears in the stats carousel.")
                }

                Button("Reset Recommended Metrics") {
                    dataStore.userPreferences.preferredStatsCarouselMetrics = UserPreferences.defaultStatsCarouselMetrics
                    Task { await dataStore.persistToDisk() }
                }
                .font(AppText.chip)
                .foregroundStyle(AppColor.Accent.primary)
                .accessibilityLabel("Reset recommended metrics")
                .accessibilityHint("Restore the default set of metrics shown in the stats carousel.")
            }
        }
        .navigationTitle(SettingsCategory.goalsPreferences.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private static let recoveryStartFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private var goalWeightMinBinding: Binding<Double> {
        Binding(
            get: { dataStore.userProfile.targetWeightMin },
            set: {
                dataStore.userProfile.targetWeightMin = $0
                Task { await dataStore.persistToDisk() }
            }
        )
    }

    private var goalWeightMaxBinding: Binding<Double> {
        Binding(
            get: { dataStore.userProfile.targetWeightMax },
            set: {
                dataStore.userProfile.targetWeightMax = $0
                Task { await dataStore.persistToDisk() }
            }
        )
    }

    private var goalBodyFatMinBinding: Binding<Double> {
        Binding(
            get: { dataStore.userProfile.targetBFMin },
            set: {
                dataStore.userProfile.targetBFMin = $0
                Task { await dataStore.persistToDisk() }
            }
        )
    }

    private var goalBodyFatMaxBinding: Binding<Double> {
        Binding(
            get: { dataStore.userProfile.targetBFMax },
            set: {
                dataStore.userProfile.targetBFMax = $0
                Task { await dataStore.persistToDisk() }
            }
        )
    }

    private var statsMetricOptions: [StatsFocusMetric] {
        StatsFocusMetric.allCases.filter { !$0.isPermanent }
    }

    private func isStatsMetricVisible(_ metric: StatsFocusMetric) -> Bool {
        dataStore.userPreferences.preferredStatsCarouselMetrics.contains(metric.rawValue)
    }

    private func toggleStatsMetric(_ metric: StatsFocusMetric) {
        var metrics = dataStore.userPreferences.preferredStatsCarouselMetrics

        if let index = metrics.firstIndex(of: metric.rawValue) {
            guard metrics.count > 1 else { return }
            metrics.remove(at: index)
        } else {
            metrics.append(metric.rawValue)
        }

        dataStore.userPreferences.preferredStatsCarouselMetrics = metrics
        Task { await dataStore.persistToDisk() }
    }
}
