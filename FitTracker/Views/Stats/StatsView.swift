// Views/Stats/StatsView.swift

import SwiftUI
import Charts

// MARK: – Supporting enums

enum StatsPeriod: String, CaseIterable {
    case sevenDays    = "7D"
    case thirtyDays   = "30D"
    case ninetyDays   = "90D"
    case allTime      = "All"

    var dateRange: (from: Date, to: Date) {
        let to = Date()
        switch self {
        case .sevenDays:   return (Calendar.current.date(byAdding: .day, value: -7, to: to)!, to)
        case .thirtyDays:  return (Calendar.current.date(byAdding: .day, value: -30, to: to)!, to)
        case .ninetyDays:  return (Calendar.current.date(byAdding: .day, value: -90, to: to)!, to)
        case .allTime:     return (Date.distantPast, to)
        }
    }
}

enum StatsCategory: String, CaseIterable {
    case body      = "Body"
    case training  = "Training"
    case recovery  = "Recovery"
    case nutrition = "Nutrition"
}

// MARK: – StatsView

struct StatsView: View {
    @EnvironmentObject var dataStore:     EncryptedDataStore
    @EnvironmentObject var healthService: HealthKitService

    @State private var period:   StatsPeriod   = .thirtyDays
    @State private var category: StatsCategory = .body

    private var dateRange: (from: Date, to: Date) { period.dateRange }

    var body: some View {
        ZStack {
            // Background gradient (same warm orange palette as rest of app)
            LinearGradient(
                colors: [Color.appOrange1, Color.appOrange2],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Period picker
                Picker("Period", selection: $period) {
                    ForEach(StatsPeriod.allCases, id: \.self) { p in
                        Text(p.rawValue).tag(p)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

                // Category tab buttons
                HStack(spacing: 0) {
                    ForEach(StatsCategory.allCases, id: \.self) { cat in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { category = cat }
                        } label: {
                            Text(cat.rawValue)
                                .font(AppType.body)
                                .foregroundStyle(category == cat ? Color.primary : Color.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    category == cat
                                        ? Color.white.opacity(0.25)
                                        : Color.clear
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                // Chart content area
                ScrollView {
                    LazyVStack(spacing: 16) {
                        switch category {
                        case .body:
                            bodySection
                        case .training:
                            trainingSection
                        case .recovery:
                            recoverySection
                        case .nutrition:
                            nutritionSection
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
        }
        .navigationTitle("Stats")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: – Stub sections (filled in subsequent steps)

    private var bodySection: some View {
        EmptyStateView(
            icon: "chart.line.uptrend.xyaxis",
            title: "Body Composition",
            subtitle: "Charts coming in the next build step"
        )
    }

    private var trainingSection: some View {
        EmptyStateView(
            icon: "dumbbell.fill",
            title: "Training Performance",
            subtitle: "Charts coming in the next build step"
        )
    }

    private var recoverySection: some View {
        EmptyStateView(
            icon: "waveform.path.ecg",
            title: "Recovery Metrics",
            subtitle: "Charts coming in the next build step"
        )
    }

    private var nutritionSection: some View {
        EmptyStateView(
            icon: "fork.knife",
            title: "Nutrition Adherence",
            subtitle: "Charts coming in the next build step"
        )
    }
}

struct StatPreviewPill: View {
    let value: String; let label: String
    var body: some View {
        VStack(spacing: 3) {
            Text(value).font(.system(.title2, design: .monospaced, weight: .bold)).foregroundStyle(Color.status.success)
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

    private static let lastSyncFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short; f.timeStyle = .short
        return f
    }()

    private func lastSyncFormatted(_ date: Date) -> String {
        Self.lastSyncFormatter.string(from: date)
    }
}
