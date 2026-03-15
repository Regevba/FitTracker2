// Views/Settings/SettingsView.swift

import SwiftUI
import LocalAuthentication

struct SettingsView: View {

    @EnvironmentObject var signIn:        SignInService
    @EnvironmentObject var biometricAuth: AuthManager
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

            Section("Access") {
                if let session = signIn.currentSession {
                    LabeledContent("Sign-In Method", value: session.provider.rawValue)
                }
                Toggle(isOn: $settings.requireBiometricUnlockOnReopen) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Require \(biometricUnlockLabel) on Reopen")
                        Text("When off, FitTracker stays unlocked while the app remains in memory.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(!biometricsAvailable)

                if !biometricsAvailable {
                    Text("Biometric unlock is unavailable on this device. Set up Face ID or Touch ID to use FitTracker's encrypted app lock.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button {
                    signIn.addPasskeyForCurrentUser()
                } label: {
                    HStack {
                        Label(
                            signIn.currentSession?.provider == .passkey ? "Create Another Passkey" : "Add Passkey",
                            systemImage: "key.fill"
                        )
                        Spacer()
                        if signIn.isLoading {
                            ProgressView().scaleEffect(0.8)
                        }
                    }
                }
                .disabled(signIn.isLoading || !signIn.isPasskeyConfigured)

                if !signIn.isPasskeyConfigured {
                    Text("Passkey setup requires a valid `PasskeyRelyingPartyID` in the app configuration.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Security section
            Section("Security") {
                securitySummaryRow(
                    title: "Encryption",
                    detail: "AES-256-GCM + ChaCha20-Poly1305"
                )
                securitySummaryRow(
                    title: "Key Storage",
                    detail: "Keychain with biometric protection"
                )
                securitySummaryRow(
                    title: "Cloud Storage",
                    detail: "Encrypted locally before upload"
                )
                securitySummaryRow(
                    title: "Data Protection",
                    detail: "NSFileProtectionCompleteUnlessOpen"
                )
            }

            // iCloud Sync section
            Section("Sync") {
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
                Picker("Goal Mode", selection: Binding(
                    get: { dataStore.userPreferences.nutritionGoalMode },
                    set: {
                        dataStore.userPreferences.nutritionGoalMode = $0
                        Task { await dataStore.persistToDisk() }
                    }
                )) {
                    ForEach(NutritionGoalMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }

                TextField("Goal Weight Min", value: Binding(
                    get: { dataStore.userProfile.targetWeightMin },
                    set: {
                        dataStore.userProfile.targetWeightMin = $0
                        Task { await dataStore.persistToDisk() }
                    }
                ), format: .number.precision(.fractionLength(0...1)))

                TextField("Goal Weight Max", value: Binding(
                    get: { dataStore.userProfile.targetWeightMax },
                    set: {
                        dataStore.userProfile.targetWeightMax = $0
                        Task { await dataStore.persistToDisk() }
                    }
                ), format: .number.precision(.fractionLength(0...1)))

                TextField("Goal Body Fat Min", value: Binding(
                    get: { dataStore.userProfile.targetBFMin },
                    set: {
                        dataStore.userProfile.targetBFMin = $0
                        Task { await dataStore.persistToDisk() }
                    }
                ), format: .number.precision(.fractionLength(0...1)))

                TextField("Goal Body Fat Max", value: Binding(
                    get: { dataStore.userProfile.targetBFMax },
                    set: {
                        dataStore.userProfile.targetBFMax = $0
                        Task { await dataStore.persistToDisk() }
                    }
                ), format: .number.precision(.fractionLength(0...1)))

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

    private var biometricsAvailable: Bool {
        let ctx = LAContext()
        var error: NSError?
        return ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    private var biometricUnlockLabel: String {
        let ctx = LAContext()
        var error: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return "Face ID"
        }
        switch ctx.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        default: return "Biometric Unlock"
        }
    }

    private func securitySummaryRow(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.subheadline.weight(.medium))
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
