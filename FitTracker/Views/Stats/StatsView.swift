// Views/Stats/StatsView.swift
// Tab 4: Stats — placeholder for now, scaffolded for future charts

import SwiftUI
import Charts

struct StatsView: View {

    @EnvironmentObject var dataStore:     EncryptedDataStore
    @EnvironmentObject var healthService: HealthKitService

    private let bgOrange1 = Color.appOrange1
    private let bgOrange2 = Color.appOrange2

    var body: some View {
        ZStack {
        LinearGradient(colors: [bgOrange1, bgOrange2],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()

        VStack(spacing: 0) {
            // ── Coming soon state ────────────────────────
            Spacer()
            VStack(spacing: 20) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.blue)

                VStack(spacing: 8) {
                    Text("Stats coming soon")
                        .font(.title3.bold())
                        .foregroundStyle(.secondary)
                    Text("Keep logging your training, supplements,\nand biometrics. Charts and trends will\nappear here as data builds up.")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }

                // Show a tiny summary if there's any data
                if !dataStore.dailyLogs.isEmpty {
                    dataPreviewCard
                }
            }
            .padding(40)
            Spacer()
        }
        } // ZStack
        .navigationTitle("Stats")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var dataPreviewCard: some View {
        VStack(spacing: 12) {
            Text("DATA COLLECTED SO FAR")
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
                .tracking(1.5)

            HStack(spacing: 0) {
                StatPreviewPill(value: "\(dataStore.dailyLogs.count)", label: "Days logged")
                Divider().frame(height: 30)
                StatPreviewPill(value: "\(totalSets)", label: "Sets logged")
                Divider().frame(height: 30)
                StatPreviewPill(value: "\(totalCardioSessions)", label: "Cardio sessions")
            }
        }
        .padding(16)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
    }

    private var totalSets: Int {
        dataStore.dailyLogs.flatMap { $0.exerciseLogs.values }.map { $0.sets.count }.reduce(0, +)
    }

    private var totalCardioSessions: Int {
        dataStore.dailyLogs.map { $0.cardioLogs.count }.reduce(0, +)
    }
}

struct StatPreviewPill: View {
    let value: String; let label: String
    var body: some View {
        VStack(spacing: 3) {
            Text(value).font(.system(.title2, design: .monospaced, weight: .bold)).foregroundStyle(.green)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – Settings View
// ─────────────────────────────────────────────────────────

struct SettingsView: View {

    @EnvironmentObject var dataStore:     EncryptedDataStore
    @EnvironmentObject var healthService: HealthKitService
    @EnvironmentObject var cloudSync:     CloudKitSyncService
    @EnvironmentObject var settings:      AppSettings

    @State private var showResetAlert = false

    var body: some View {
        #if os(macOS)
        NavigationStack { settingsForm }
        #else
        settingsForm
        #endif
    }

    private var settingsForm: some View {
        Form {
            Section("Profile") {
                LabeledContent("Name",          value: dataStore.userProfile.name)
                LabeledContent("Recovery Start", value: "Jan 29, 2026")
                LabeledContent("Phase",         value: dataStore.userProfile.currentPhase.rawValue)
                LabeledContent("Recovery Day",  value: "Day \(dataStore.userProfile.daysSinceStart)")
                LabeledContent("Goal Weight",   value: "\(Int(dataStore.userProfile.targetWeightMin))–\(Int(dataStore.userProfile.targetWeightMax)) kg")
                LabeledContent("Goal Body Fat", value: "\(Int(dataStore.userProfile.targetBFMin))–\(Int(dataStore.userProfile.targetBFMax))%")
            }

            Section("Apple Health") {
                LabeledContent("HealthKit", value: healthService.isAuthorized ? "Authorized ✓" : "Not authorized")
                LabeledContent("Apple Watch", value: "Background delivery active")
                Button("Re-authorize HealthKit") {
                    Task { try? await healthService.requestAuthorization() }
                }
            }

            Section("iCloud Sync") {
                LabeledContent("Status",     value: cloudSync.status.rawValue)
                LabeledContent("iCloud",     value: cloudSync.iCloudAvailable ? "Available ✓" : "Unavailable")
                if let last = cloudSync.lastSyncDate {
                    LabeledContent("Last Sync", value: lastSyncFormatted(last))
                }
                Button("Sync Now") {
                    Task { await cloudSync.pushPendingChanges(dataStore: dataStore) }
                }
                Button("Fetch from iCloud") {
                    Task { await cloudSync.fetchChanges(dataStore: dataStore) }
                }
            }

            Section("Security") {
                LabeledContent("Encryption",      value: "AES-256-GCM + ChaCha20-Poly1305")
                LabeledContent("Key Storage",     value: "Keychain (biometric-protected)")
                LabeledContent("Cloud Storage",   value: "Encrypted before upload ✓")
                LabeledContent("Data Protection", value: "NSFileProtectionCompleteUnlessOpen")
                LabeledContent("Platforms",       value: "iOS · iPadOS · macOS only")
            }

            Section("Data") {
                LabeledContent("Daily Logs",       value: "\(dataStore.dailyLogs.count) entries")
                LabeledContent("Weekly Snapshots", value: "\(dataStore.weeklySnapshots.count) entries")
                Button("Delete All Local Data", role: .destructive) {
                    showResetAlert = true
                }
            }
        }
        .navigationTitle("Settings")
        .alert("Delete All Data?", isPresented: $showResetAlert) {
            Button("Delete", role: .destructive) {
                dataStore.dailyLogs = []
                dataStore.weeklySnapshots = []
                Task { await dataStore.persistToDisk() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes all locally stored logs. iCloud copies are not deleted.")
        }
    }

    private func lastSyncFormatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .short; f.timeStyle = .short
        return f.string(from: date)
    }
}
