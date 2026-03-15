// Views/Settings/SettingsView.swift

import SwiftUI

struct SettingsView: View {

    @EnvironmentObject var dataStore:     EncryptedDataStore
    @EnvironmentObject var healthService: HealthKitService
    @EnvironmentObject var cloudSync:     CloudKitSyncService
    @EnvironmentObject var settings:      AppSettings

    @State private var showResetAlert = false

    var body: some View {
        settingsForm
    }

    private var settingsForm: some View {
        Form {
            // Profile section
            Section("Profile") {
                LabeledContent("Name",           value: dataStore.userProfile.name)
                LabeledContent("Recovery Start", value: Self.recoveryStartFormatter.string(from: dataStore.userProfile.recoveryStart))
                LabeledContent("Phase",          value: dataStore.userProfile.currentPhase.rawValue)
                LabeledContent("Recovery Day",   value: "Day \(dataStore.userProfile.daysSinceStart)")
                LabeledContent("Goal Weight",    value: "\(Int(dataStore.userProfile.targetWeightMin))–\(Int(dataStore.userProfile.targetWeightMax)) kg")
                LabeledContent("Goal Body Fat",  value: "\(Int(dataStore.userProfile.targetBFMin))–\(Int(dataStore.userProfile.targetBFMax))%")
            }

            // Health & Watch section
            Section("Health & Watch") {
                LabeledContent("HealthKit", value: healthService.isAuthorized ? "Authorized ✓" : "Not authorized")
                LabeledContent("Apple Watch", value: "Background delivery active")
                Button("Re-authorize HealthKit") {
                    Task { try? await healthService.requestAuthorization() }
                }
            }

            // iCloud Sync section
            Section("iCloud Sync") {
                LabeledContent("Status",  value: cloudSync.status.rawValue)
                LabeledContent("iCloud",  value: cloudSync.iCloudAvailable ? "Available ✓" : "Unavailable")
                if let last = cloudSync.lastSyncDate {
                    LabeledContent("Last Sync", value: Self.lastSyncFormatter.string(from: last))
                }
                Button("Sync Now") {
                    Task { await cloudSync.pushPendingChanges(dataStore: dataStore) }
                }
                Button("Fetch from iCloud") {
                    Task { await cloudSync.fetchChanges(dataStore: dataStore) }
                }
            }

            // Security section
            Section("Security") {
                LabeledContent("Encryption",      value: "AES-256-GCM + ChaCha20-Poly1305")
                LabeledContent("Key Storage",     value: "Keychain (biometric-protected)")
                LabeledContent("Cloud Storage",   value: "Encrypted before upload ✓")
                LabeledContent("Data Protection", value: "NSFileProtectionCompleteUnlessOpen")
                LabeledContent("Platforms",       value: "iOS · iPadOS · macOS only")
            }

            // Preferences section (moved from AccountPanelView)
            Section("Preferences") {
                // Unit system picker
                VStack(alignment: .leading, spacing: 10) {
                    Label("Units", systemImage: "ruler")
                        .font(.subheadline.weight(.medium))
                    HStack(spacing: 8) {
                        ForEach(UnitSystem.allCases, id: \.self) { system in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    settings.unitSystem = system
                                }
                            } label: {
                                VStack(spacing: 4) {
                                    Text(system.rawValue).font(.subheadline.weight(.semibold))
                                    Text(system == .metric ? "kg · cm · km" : "lbs · in · mi")
                                        .font(.system(size: 10)).opacity(0.7)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .foregroundStyle(settings.unitSystem == system ? .white : .primary)
                                .background(
                                    settings.unitSystem == system ? Color.green : Color.secondary.opacity(0.1),
                                    in: RoundedRectangle(cornerRadius: 10)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.vertical, 4)

                // Appearance picker
                VStack(alignment: .leading, spacing: 10) {
                    Label("Appearance", systemImage: "paintpalette")
                        .font(.subheadline.weight(.medium))
                    HStack(spacing: 8) {
                        ForEach(AppAppearance.allCases, id: \.self) { mode in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    settings.appearance = mode
                                }
                            } label: {
                                VStack(spacing: 5) {
                                    Image(systemName: mode.icon).font(.title3)
                                    Text(mode.rawValue).font(.caption2.weight(.medium))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .foregroundStyle(settings.appearance == mode ? .white : .primary)
                                .background(
                                    settings.appearance == mode ? Color.green : Color.secondary.opacity(0.1),
                                    in: RoundedRectangle(cornerRadius: 10)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            // Nutrition section
            Section("Nutrition") {
                ForEach(dataStore.userProfile.mealSlotNames.indices, id: \.self) { i in
                    TextField("Slot \(i+1)", text: Binding(
                        get: { dataStore.userProfile.mealSlotNames.indices.contains(i) ? dataStore.userProfile.mealSlotNames[i] : "Meal \(i+1)" },
                        set: {
                            while dataStore.userProfile.mealSlotNames.count <= i {
                                dataStore.userProfile.mealSlotNames.append("Meal \(dataStore.userProfile.mealSlotNames.count + 1)")
                            }
                            dataStore.userProfile.mealSlotNames[i] = $0
                            Task { await dataStore.persistToDisk() }
                        }
                    ))
                }
            }

            // Training section
            Section("Training") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Zone 2 Lower HR: \(dataStore.userPreferences.zone2LowerHR) bpm")
                    Slider(value: Binding(
                        get: { Double(dataStore.userPreferences.zone2LowerHR) },
                        set: {
                            let newVal = Int($0)
                            dataStore.userPreferences.zone2LowerHR = min(newVal, dataStore.userPreferences.zone2UpperHR - 1)
                        }
                    ), in: 80...160, step: 1) { _ in
                        Task { await dataStore.persistToDisk() }
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Zone 2 Upper HR: \(dataStore.userPreferences.zone2UpperHR) bpm")
                    Slider(value: Binding(
                        get: { Double(dataStore.userPreferences.zone2UpperHR) },
                        set: {
                            let newVal = Int($0)
                            dataStore.userPreferences.zone2UpperHR = max(newVal, dataStore.userPreferences.zone2LowerHR + 1)
                        }
                    ), in: 90...180, step: 1) { _ in
                        Task { await dataStore.persistToDisk() }
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Readiness HR Threshold: \(dataStore.userPreferences.hrReadyThreshold) bpm")
                    Slider(value: Binding(
                        get: { Double(dataStore.userPreferences.hrReadyThreshold) },
                        set: { dataStore.userPreferences.hrReadyThreshold = Int($0) }
                    ), in: 40...80, step: 1) { _ in
                        Task { await dataStore.persistToDisk() }
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Readiness HRV Threshold: \(dataStore.userPreferences.hrvReadyThreshold, specifier: "%.0f") ms")
                    Slider(value: $dataStore.userPreferences.hrvReadyThreshold, in: 10...80, step: 1) { _ in
                        Task { await dataStore.persistToDisk() }
                    }
                }
            }

            // Data section
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
            Text("This permanently removes all locally stored logs. Data will be restored from iCloud on the next sync. To permanently delete, remove FitTracker from your iCloud account in iOS Settings.")
        }
    }

    private static let lastSyncFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()

    private static let recoveryStartFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()
}
