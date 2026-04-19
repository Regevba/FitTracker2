// FitTracker/Views/Settings/v2/Screens/DataSyncSettingsScreen.swift
// Settings v2 — Data & Sync detail screen.
// Extracted from SettingsView.swift in Audit M-1a (UI-002 decomposition).

import SwiftUI

struct DataSyncSettingsScreen: View {
    @EnvironmentObject private var dataStore: EncryptedDataStore
    @EnvironmentObject private var cloudSync: CloudKitSyncService
    @EnvironmentObject private var analytics: AnalyticsService
    @Binding var showResetAlert: Bool

    var body: some View {
        SettingsDetailScaffold(
            title: SettingsCategory.dataSync.title,
            subtitle: "Monitor iCloud sync health, manually trigger transfers when needed, and manage local storage carefully."
        ) {
            SettingsSectionCard(title: "Sync Status", eyebrow: "Sync") {
                SettingsValueRow(title: "Status", value: cloudSync.status.rawValue)
                SettingsValueRow(title: "iCloud", value: cloudSync.iCloudAvailable ? "Available" : "Unavailable")
                if let lastSyncDate = cloudSync.lastSyncDate {
                    SettingsValueRow(title: "Last Sync", value: Self.lastSyncFormatter.string(from: lastSyncDate))
                }

                Button {
                    Task { await cloudSync.pushPendingChanges(dataStore: dataStore) }
                } label: {
                    SettingsActionLabel(
                        title: "Sync Now",
                        subtitle: "Push local encrypted changes to your private iCloud database.",
                        icon: "icloud.and.arrow.up.fill",
                        tint: AppColor.Status.success
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Sync now")
                .accessibilityHint("Push local changes to iCloud")

                Button {
                    Task { await cloudSync.fetchChanges(dataStore: dataStore) }
                } label: {
                    SettingsActionLabel(
                        title: "Fetch from iCloud",
                        subtitle: "Download the latest encrypted changes from your account.",
                        icon: "icloud.and.arrow.down.fill",
                        tint: AppColor.Accent.recovery
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Fetch from iCloud")
                .accessibilityHint("Download latest data from your iCloud account")
            }

            SettingsSectionCard(title: "Local Storage", eyebrow: "Data") {
                SettingsValueRow(title: "Daily Logs", value: "\(dataStore.dailyLogs.count) entries")
                SettingsValueRow(title: "Weekly Snapshots", value: "\(dataStore.weeklySnapshots.count) entries")
            }

            SettingsSectionCard(title: "Analytics", eyebrow: "Privacy") {
                Toggle(isOn: Binding(
                    get: { analytics.consent.gdprConsent == .granted },
                    set: { enabled in
                        if enabled {
                            analytics.consent.regrantConsent()
                            analytics.syncConsentToProvider()
                            analytics.logSettingsChanged(settingName: "analytics", newValue: "enabled")
                        } else {
                            analytics.consent.revokeConsent()
                            analytics.syncConsentToProvider()
                        }
                    }
                )) {
                    VStack(alignment: .leading, spacing: AppSpacing.micro) {
                        Text("App Analytics")
                            .font(AppText.body)
                            .foregroundStyle(AppColor.Text.primary)
                        Text("Help improve FitMe by sharing anonymous usage data. No health data is ever shared.")
                            .font(AppText.caption)
                            .foregroundStyle(AppColor.Text.tertiary)
                    }
                }
                .tint(AppColor.Brand.primary)
            }

            SettingsSectionCard(title: "Data Portability", eyebrow: "GDPR") {
                NavigationLink {
                    ExportDataView()
                        .environmentObject(DataExportService(
                            dataStore: dataStore,
                            analytics: analytics
                        ))
                        .environmentObject(analytics)
                } label: {
                    SettingsActionLabel(
                        title: "Export My Data",
                        subtitle: "Download all your data as a JSON file.",
                        icon: "square.and.arrow.up.fill",
                        tint: AppColor.Accent.primary
                    )
                }
                .buttonStyle(.plain)
            }

            SettingsSectionCard(title: "Danger Zone", eyebrow: "Data") {
                SettingsSupportingText("Delete local logs only if you understand they will repopulate from iCloud on the next fetch. Permanent deletion requires removing the data from your iCloud account as well.")

                Button(role: .destructive) {
                    showResetAlert = true
                } label: {
                    SettingsActionLabel(
                        title: "Delete All Local Data",
                        subtitle: "Remove all daily logs and snapshots from this device.",
                        icon: "trash.fill",
                        tint: AppColor.Status.error
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete all local data")
                .accessibilityHint("Permanently removes all local logs and snapshots from this device. This action cannot be undone.")
            }
        }
        .navigationTitle(SettingsCategory.dataSync.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private static let lastSyncFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}
