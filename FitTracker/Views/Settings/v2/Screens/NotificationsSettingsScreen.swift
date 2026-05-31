// FitTracker/Views/Settings/v2/Screens/NotificationsSettingsScreen.swift
// Settings v2 — Notifications detail screen (L349 backlog).
// 6 per-type toggles + master switch + daily-cap stepper, all backed by
// ReminderPreferencesStore (v2 UserDefaults-backed).
//
// NOTE: this commit ships the storage + UI surface. The ReminderScheduler
// integration that consults `isEnabled(for:)` before dispatching is a
// follow-up (see PR description).

import SwiftUI

struct NotificationsSettingsScreen: View {
    @EnvironmentObject private var preferences: ReminderPreferencesStore
    @EnvironmentObject private var analytics: AnalyticsService

    var body: some View {
        SettingsDetailScaffold(
            title: SettingsCategory.notifications.title,
            subtitle: "Choose which reminders may fire and how many you receive per day."
        ) {
            SettingsSectionCard(title: "Master Switch", eyebrow: "All Reminders") {
                Toggle(isOn: $preferences.masterEnabled) {
                    VStack(alignment: .leading, spacing: AppSpacing.micro) {
                        Text("Enable reminders")
                            .font(AppText.body)
                            .foregroundStyle(AppColor.Text.primary)
                        Text("Turn this off to silence every reminder type below in one place.")
                            .font(AppText.caption)
                            .foregroundStyle(AppColor.Text.secondary)
                    }
                }
                .tint(AppColor.Brand.primary)
                .accessibilityLabel("Master reminder switch")
            }

            SettingsSectionCard(title: "Per-Reminder Type", eyebrow: "Pick Your Mix") {
                reminderToggle(
                    title: "Connect HealthKit",
                    detail: "Unlocks your readiness score (max 3 lifetime).",
                    isOn: $preferences.healthKitConnectEnabled
                )
                reminderToggle(
                    title: "Create Account",
                    detail: "Back up your data to the cloud (max 3 lifetime).",
                    isOn: $preferences.accountRegistrationEnabled
                )
                reminderToggle(
                    title: "Nutrition Check-in",
                    detail: "Protein gap nudges when daily target is at risk.",
                    isOn: $preferences.nutritionGapEnabled
                )
                reminderToggle(
                    title: "Training Day",
                    detail: "10 AM heads-up on scheduled training days.",
                    isOn: $preferences.trainingDayEnabled
                )
                reminderToggle(
                    title: "Rest Day",
                    detail: "Encouragement on planned rest days.",
                    isOn: $preferences.restDayEnabled
                )
                reminderToggle(
                    title: "Re-engagement",
                    detail: "Gentle nudge after extended inactivity (max 3 lifetime).",
                    isOn: $preferences.engagementEnabled
                )
            }
            .disabled(!preferences.masterEnabled)
            .opacity(preferences.masterEnabled ? 1.0 : 0.55)

            SettingsSectionCard(title: "Frequency Cap", eyebrow: "Per Day") {
                Stepper(value: $preferences.dailyCap, in: 0...5) {
                    VStack(alignment: .leading, spacing: AppSpacing.micro) {
                        Text("Max \(preferences.dailyCap) reminder\(preferences.dailyCap == 1 ? "" : "s") per day")
                            .font(AppText.body)
                            .foregroundStyle(AppColor.Text.primary)
                        Text("Total across all enabled types. Default is 2.")
                            .font(AppText.caption)
                            .foregroundStyle(AppColor.Text.secondary)
                    }
                }
                .accessibilityLabel("Daily reminder cap")
                .accessibilityValue("\(preferences.dailyCap) per day")
            }

            SettingsSectionCard(title: "How This Works", eyebrow: "About") {
                SettingsSupportingText("Reminders are scheduled on your device only and never sent to a server. The master switch overrides every per-type toggle. The daily cap further limits total firings even if multiple types are enabled.\n\nIntegration with the reminder scheduler ships in a follow-up update — toggles below are read by the system but do not yet block scheduling. Disable the master switch to silence everything in the meantime.")
            }
        }
        .navigationTitle(SettingsCategory.notifications.title)
        .navigationBarTitleDisplayMode(.inline)
        .analyticsScreen(AnalyticsScreen.settingsNotifications)
    }

    // MARK: - Row builder

    @ViewBuilder
    private func reminderToggle(title: String, detail: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: AppSpacing.micro) {
                Text(title)
                    .font(AppText.body)
                    .foregroundStyle(AppColor.Text.primary)
                Text(detail)
                    .font(AppText.caption)
                    .foregroundStyle(AppColor.Text.secondary)
            }
        }
        .tint(AppColor.Brand.primary)
        .accessibilityLabel(title)
        .accessibilityHint(detail)
    }
}
