// FitTracker/Views/Settings/v2/Screens/HealthDevicesSettingsScreen.swift
// Settings v2 — Health & Devices detail screen.
// Extracted from SettingsView.swift in Audit M-1a (UI-002 decomposition).

import SwiftUI

struct HealthDevicesSettingsScreen: View {
    @EnvironmentObject private var healthService: HealthKitService
    @EnvironmentObject private var watchService: WatchConnectivityService

    var body: some View {
        SettingsDetailScaffold(
            title: SettingsCategory.healthDevices.title,
            subtitle: "See whether health data access is active, whether your Apple Watch is reachable, and which connected sources are currently feeding the app."
        ) {
            SettingsSectionCard(title: "Connection Status", eyebrow: "Devices") {
                SettingsValueRow(title: "HealthKit", value: healthService.isAuthorized ? "Authorized" : "Not Authorized")
                SettingsValueRow(title: "Apple Watch", value: watchService.status.label)
                SettingsSupportingText(healthSummary)
                SettingsSupportingText(watchSummary)
            }

            SettingsSectionCard(title: "Actions", eyebrow: "Devices") {
                Button {
                    Task { try? await healthService.requestAuthorization() }
                } label: {
                    SettingsActionLabel(
                        title: "Re-authorize HealthKit",
                        subtitle: "Refresh the current HealthKit permissions and reconnect read access.",
                        icon: "heart.text.square.fill",
                        tint: AppColor.Accent.recovery
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle(SettingsCategory.healthDevices.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var healthSummary: String {
        healthService.isAuthorized
            ? "HealthKit is connected, so compatible body, recovery, and activity metrics can flow into \(AppBrand.name)."
            : "HealthKit is not authorized yet, so recovery and body signals depend on manual entry and imported device data."
    }

    private var watchSummary: String {
        switch watchService.status {
        case .connected:
            return "Your Apple Watch is reachable right now and can provide live workout-related context."
        case .offline:
            return "Your watch is paired, but it is not currently reachable. This is common when the watch app is not active."
        case .notPaired:
            return "No paired Apple Watch is detected for this iPhone."
        case .appNotInstalled:
            return "A paired watch was found, but the watch companion app is not installed."
        }
    }
}
