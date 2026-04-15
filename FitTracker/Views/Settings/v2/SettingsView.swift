// FitTracker/Views/Settings/v2/SettingsView.swift
// Settings v2 — UX Foundations alignment pass (2026-04-10)
// See .claude/features/settings-v2/v2-audit-report.md

import SwiftUI
import LocalAuthentication

private enum SettingsCategory: String, CaseIterable, Hashable, Identifiable {
    case accountSecurity
    case healthDevices
    case goalsPreferences
    case trainingNutrition
    case dataSync

    var id: String { rawValue }

    var title: String {
        switch self {
        case .accountSecurity: "Account & Security"
        case .healthDevices: "Health & Devices"
        case .goalsPreferences: "Goals & Preferences"
        case .trainingNutrition: "Training & Nutrition"
        case .dataSync: "Data & Sync"
        }
    }

    var subtitle: String {
        switch self {
        case .accountSecurity: "Sign-in, biometrics, passkeys, and device protection."
        case .healthDevices: "HealthKit, Apple Watch status, and connected data sources."
        case .goalsPreferences: "Units, appearance, stats layout, and body goals."
        case .trainingNutrition: "Nutrition mode, meal slots, and readiness thresholds."
        case .dataSync: "Cloud sync, local data counts, and destructive actions."
        }
    }

    var icon: String {
        switch self {
        case .accountSecurity: "lock.shield.fill"
        case .healthDevices: "heart.text.square.fill"
        case .goalsPreferences: "slider.horizontal.3"
        case .trainingNutrition: "figure.run.circle.fill"
        case .dataSync: "arrow.triangle.2.circlepath.icloud.fill"
        }
    }

    var tint: Color {
        switch self {
        case .accountSecurity: AppColor.Accent.primary
        case .healthDevices: AppColor.Accent.recovery
        case .goalsPreferences: AppColor.Accent.achievement
        case .trainingNutrition: AppColor.Accent.sleep
        case .dataSync: AppColor.Status.success
        }
    }
}

private struct SettingsSummaryBadge: Identifiable {
    let title: String
    let tint: Color

    var id: String { title }
}

private enum SettingsReviewDestination: String, Hashable {
    case deleteAccount = "delete-account"
    case exportData = "export-data"
}

struct SettingsView: View {
    @EnvironmentObject var signIn: SignInService
    @EnvironmentObject var biometricAuth: AuthManager
    @EnvironmentObject var dataStore: EncryptedDataStore
    @EnvironmentObject var healthService: HealthKitService
    @EnvironmentObject var cloudSync: CloudKitSyncService
    @EnvironmentObject var supabaseSync: SupabaseSyncService
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var watchService: WatchConnectivityService
    @EnvironmentObject var analytics: AnalyticsService

    @State private var navigationPath = NavigationPath()
    @State private var showResetAlert = false
    @State private var didApplyReviewRoute = false

    private let dashboardColumns = [
        GridItem(.flexible(), spacing: AppSpacing.xSmall, alignment: .top),
        GridItem(.flexible(), spacing: AppSpacing.xSmall, alignment: .top),
    ]

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                AppGradient.screenBackground
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: AppSpacing.large) {
                        SettingsHomeHeader(
                            title: "Settings",
                            subtitle: "Everything is grouped by area so device access, goals, and sync controls stay easy to find."
                        )

                        NavigationLink(value: SettingsCategory.accountSecurity) {
                            SettingsCategoryCard(
                                category: .accountSecurity,
                                summary: SettingsCategory.accountSecurity.subtitle,
                                badges: summaryBadges(for: .accountSecurity),
                                featured: true
                            )
                        }
                        .buttonStyle(.plain)

                        LazyVGrid(columns: dashboardColumns, spacing: AppSpacing.xSmall) {
                            ForEach(SettingsCategory.allCases.filter { $0 != .accountSecurity }) { category in
                                NavigationLink(value: category) {
                                    SettingsCategoryCard(
                                        category: category,
                                        summary: category.subtitle,
                                        badges: summaryBadges(for: category),
                                        featured: false
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.medium)
                    .padding(.top, AppSpacing.small)
                    .padding(.bottom, AppSpacing.large)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: SettingsCategory.self) { category in
                switch category {
                case .accountSecurity:
                    AccountSecuritySettingsScreen()
                        .environmentObject(signIn)
                        .environmentObject(dataStore)
                        .environmentObject(cloudSync)
                        .environmentObject(supabaseSync)
                        .environmentObject(settings)
                        .environmentObject(biometricAuth)
                        .environmentObject(analytics)
                case .healthDevices:
                    HealthDevicesSettingsScreen()
                        .environmentObject(healthService)
                        .environmentObject(watchService)
                case .goalsPreferences:
                    GoalsPreferencesSettingsScreen()
                        .environmentObject(dataStore)
                        .environmentObject(settings)
                case .trainingNutrition:
                    TrainingNutritionSettingsScreen()
                        .environmentObject(dataStore)
                case .dataSync:
                    DataSyncSettingsScreen(showResetAlert: $showResetAlert)
                        .environmentObject(dataStore)
                        .environmentObject(cloudSync)
                        .environmentObject(analytics)
                }
            }
            .navigationDestination(for: SettingsReviewDestination.self) { destination in
                switch destination {
                case .deleteAccount:
                    deleteAccountDestination
                case .exportData:
                    exportDataDestination
                }
            }
            .alert("Delete All Data?", isPresented: $showResetAlert) {
                Button("Delete", role: .destructive) {
                    dataStore.dailyLogs = []
                    dataStore.weeklySnapshots = []
                    Task { await dataStore.persistToDisk() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently removes all locally stored logs. Data will be restored from iCloud on the next sync. To permanently delete, remove \(AppBrand.name) from your iCloud account in iOS Settings.")
            }
            .onAppear {
                applyReviewRouteIfNeeded()
            }
        }
    }

    @ViewBuilder
    private var deleteAccountDestination: some View {
        DeleteAccountView()
            .environmentObject(AccountDeletionService(
                dataStore: dataStore,
                cloudSync: cloudSync,
                supabaseSync: supabaseSync,
                signIn: signIn,
                analytics: analytics
            ))
            .environmentObject(analytics)
    }

    @ViewBuilder
    private var exportDataDestination: some View {
        ExportDataView()
            .environmentObject(DataExportService(
                dataStore: dataStore,
                analytics: analytics
            ))
            .environmentObject(analytics)
    }

    private func summaryBadges(for category: SettingsCategory) -> [SettingsSummaryBadge] {
        switch category {
        case .accountSecurity:
            let provider = signIn.currentSession?.provider.rawValue ?? "No Session"
            let biometric = settings.requireBiometricUnlockOnReopen ? "Biometric Reopen On" : "Biometric Reopen Off"
            return [
                SettingsSummaryBadge(title: provider, tint: AppColor.Accent.primary),
                SettingsSummaryBadge(
                    title: biometric,
                    tint: settings.requireBiometricUnlockOnReopen ? AppColor.Status.success : AppColor.Status.warning
                ),
            ]
        case .healthDevices:
            let health = healthService.isAuthorized ? "HealthKit On" : "HealthKit Off"
            return [
                SettingsSummaryBadge(title: health, tint: healthService.isAuthorized ? AppColor.Status.success : AppColor.Status.warning),
                SettingsSummaryBadge(title: watchService.status.label, tint: watchService.status.dotColor),
            ]
        case .goalsPreferences:
            return [
                SettingsSummaryBadge(title: settings.unitSystem.rawValue, tint: AppColor.Accent.achievement),
                SettingsSummaryBadge(title: settings.appearance.rawValue, tint: AppColor.Accent.sleep),
            ]
        case .trainingNutrition:
            return [
                SettingsSummaryBadge(title: dataStore.userPreferences.nutritionGoalMode.shortLabel, tint: AppColor.Accent.sleep),
                SettingsSummaryBadge(
                    title: "Zone 2 \(dataStore.userPreferences.zone2LowerHR)-\(dataStore.userPreferences.zone2UpperHR)",
                    tint: AppColor.Accent.recovery
                ),
            ]
        case .dataSync:
            return [
                SettingsSummaryBadge(title: cloudSync.status.rawValue, tint: syncTint),
                SettingsSummaryBadge(title: "\(dataStore.dailyLogs.count) Logs", tint: AppColor.Accent.primary),
            ]
        }
    }

    private var syncTint: Color {
        switch cloudSync.status {
        case .idle:
            return AppColor.Status.success
        case .syncing:
            return AppColor.Status.warning
        case .failed:
            return AppColor.Status.error
        case .offline, .disabled:
            return AppColor.Text.secondary
        }
    }

    private var reviewSettingsDestination: SettingsReviewDestination? {
        guard isSettingsReviewMode else { return nil }
        let rawValue = ProcessInfo.processInfo.environment["FITTRACKER_REVIEW_SETTINGS_DESTINATION"]?.lowercased()
        return SettingsReviewDestination(rawValue: rawValue ?? "")
    }

    private var isSettingsReviewMode: Bool {
        ProcessInfo.processInfo.environment["FITTRACKER_REVIEW_AUTH"]?.lowercased() == "settings"
            || ProcessInfo.processInfo.environment["FITTRACKER_REVIEW_SETTINGS"] == "1"
            || ProcessInfo.processInfo.environment["FITTRACKER_REVIEW_TAB"]?.lowercased() == "settings"
            || ProcessInfo.processInfo.arguments.contains("--review-settings")
    }

    private func applyReviewRouteIfNeeded() {
        guard !didApplyReviewRoute else { return }
        didApplyReviewRoute = true
        guard let destination = reviewSettingsDestination else { return }

        navigationPath.append(reviewRootCategory(for: destination))
        navigationPath.append(destination)
    }

    private func reviewRootCategory(for destination: SettingsReviewDestination) -> SettingsCategory {
        switch destination {
        case .deleteAccount:
            return .accountSecurity
        case .exportData:
            return .dataSync
        }
    }
}

private struct AccountSecuritySettingsScreen: View {
    @EnvironmentObject private var signIn: SignInService
    @EnvironmentObject private var dataStore: EncryptedDataStore
    @EnvironmentObject private var cloudSync: CloudKitSyncService
    @EnvironmentObject private var supabaseSync: SupabaseSyncService
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var biometricAuth: AuthManager
    @EnvironmentObject private var analytics: AnalyticsService

    var body: some View {
        SettingsDetailScaffold(
            title: SettingsCategory.accountSecurity.title,
            subtitle: "Manage how your account opens, how credentials are stored, and which protections are active on this device."
        ) {
            SettingsSectionCard(title: "Account Identity", eyebrow: "Account") {
                SettingsValueRow(title: "Sign-In Method", value: signIn.currentSession?.provider.rawValue ?? "Unavailable")
                SettingsValueRow(title: "Name", value: signIn.currentSession?.displayName ?? "—")
                SettingsValueRow(title: "Email", value: signIn.currentSession?.email ?? "—")
                SettingsValueRow(title: "Phone", value: signIn.currentSession?.phone ?? "—")
            }

            SettingsSectionCard(title: "Access on Reopen", eyebrow: "Security") {
                Toggle(isOn: $settings.requireBiometricUnlockOnReopen) {
                    VStack(alignment: .leading, spacing: AppSpacing.xxxSmall) {
                        Text("Require \(biometricUnlockLabel) on Reopen")
                            .font(AppText.button)
                            .foregroundStyle(AppColor.Text.primary)
                        Text("When off, \(AppBrand.name) stays unlocked while the app remains in memory.")
                            .font(AppText.subheading)
                            .foregroundStyle(AppColor.Text.secondary)
                    }
                }
                .tint(AppColor.Accent.primary)
                .disabled(!biometricsAvailable)

                if !biometricsAvailable {
                    SettingsSupportingText("Biometric unlock is unavailable on this device. Set up Face ID or Touch ID to protect reopen access.")
                }

                Button {
                    signIn.addPasskeyForCurrentUser()
                } label: {
                    SettingsActionLabel(
                        title: signIn.currentSession?.provider == .passkey ? "Create Another Passkey" : "Add Passkey",
                        subtitle: signIn.isPasskeyConfigured ? "Register a passkey for quick passwordless sign in." : "Passkey setup requires a valid relying party configuration.",
                        icon: "key.fill",
                        tint: AppColor.Accent.sleep,
                        trailing: signIn.isLoading ? .progress : .chevron
                    )
                }
                .buttonStyle(.plain)
                .disabled(signIn.isLoading || !signIn.isPasskeyConfigured)
            }

            SettingsSectionCard(title: "Protection Summary", eyebrow: "Security") {
                SettingsValueRow(title: "Encryption", value: "AES-256-GCM + ChaCha20-Poly1305")
                SettingsValueRow(title: "Key Storage", value: "Keychain with biometric protection")
                SettingsValueRow(title: "Cloud Storage", value: "Encrypted locally before upload")
                SettingsValueRow(title: "Data Protection", value: "NSFileProtectionCompleteUnlessOpen")
            }

            SettingsSectionCard(title: "Account", eyebrow: "GDPR") {
                NavigationLink {
                    DeleteAccountView()
                        .environmentObject(AccountDeletionService(
                            dataStore: dataStore,
                            cloudSync: cloudSync,
                            supabaseSync: supabaseSync,
                            signIn: signIn,
                            analytics: analytics
                        ))
                        .environmentObject(analytics)
                } label: {
                    SettingsActionLabel(
                        title: "Delete Account",
                        subtitle: "Schedule permanent deletion of your account and all data.",
                        icon: "trash.fill",
                        tint: AppColor.Status.error
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle(SettingsCategory.accountSecurity.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var biometricsAvailable: Bool {
        let ctx = LAContext()
        var error: NSError?
        return ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    private var biometricUnlockLabel: String {
        let ctx = LAContext()
        var error: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return biometricAuth.biometricName
        }
        switch ctx.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        default: return "Biometric Unlock"
        }
    }
}

private struct HealthDevicesSettingsScreen: View {
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

private struct GoalsPreferencesSettingsScreen: View {
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
                }

                Button("Reset Recommended Metrics") {
                    dataStore.userPreferences.preferredStatsCarouselMetrics = UserPreferences.defaultStatsCarouselMetrics
                    Task { await dataStore.persistToDisk() }
                }
                .font(AppText.chip)
                .foregroundStyle(AppColor.Accent.primary)
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

private struct TrainingNutritionSettingsScreen: View {
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

private struct DataSyncSettingsScreen: View {
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

private struct SettingsHomeHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {
            Text(title)
                .font(AppText.hero)
                .foregroundStyle(AppColor.Text.primary)

            Text(subtitle)
                .font(AppText.body)
                .foregroundStyle(AppColor.Text.secondary)
        }
    }
}

private struct SettingsCategoryCard: View {
    let category: SettingsCategory
    let summary: String
    let badges: [SettingsSummaryBadge]
    let featured: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
            HStack(alignment: .top) {
                Image(systemName: category.icon)
                    .font(featured ? AppText.sectionTitle : AppText.callout)
                    .foregroundStyle(category.tint)
                    .frame(width: 34, height: 34)
                    .background(category.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: AppRadius.small))

                Spacer(minLength: 12)

                Image(systemName: "chevron.right")
                    .font(AppText.captionStrong)
                    .foregroundStyle(AppColor.Text.tertiary)
            }

            VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {
                Text(category.title)
                    .font(featured ? AppText.sectionTitle : AppText.button)
                    .foregroundStyle(AppColor.Text.primary)
                    .multilineTextAlignment(.leading)

                Text(summary)
                    .font(AppText.subheading)
                    .foregroundStyle(AppColor.Text.secondary)
                    .lineLimit(featured ? 2 : 3)
                    .multilineTextAlignment(.leading)
            }

            if !badges.isEmpty {
                FlexibleBadgeRow(badges: badges)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(featured ? AppSpacing.small : AppSpacing.small)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .fill(AppColor.Surface.elevated.opacity(featured ? 0.96 : 0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.large)
                        .stroke(AppColor.Border.subtle, lineWidth: 1)
                )
        )
        .shadow(color: AppShadow.cardColor, radius: AppShadow.cardRadius, y: AppShadow.cardYOffset)
    }
}

private struct FlexibleBadgeRow: View {
    let badges: [SettingsSummaryBadge]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: AppSpacing.xxSmall) {
                ForEach(badges) { badge in
                    SettingsBadgeView(badge: badge)
                }
            }

            VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {
                ForEach(badges) { badge in
                    SettingsBadgeView(badge: badge)
                }
            }
        }
    }
}

private struct SettingsBadgeView: View {
    let badge: SettingsSummaryBadge

    var body: some View {
        HStack(spacing: AppSpacing.xxSmall) {
            Circle()
                .fill(badge.tint)
                .frame(width: 6, height: 6)
            Text(badge.title)
                .font(AppText.captionStrong)
        }
        .foregroundStyle(badge.tint)
        .padding(.horizontal, AppSpacing.xxSmall)
        .padding(.vertical, AppSpacing.xxSmall)
        .background(badge.tint.opacity(0.12), in: Capsule())
    }
}

struct SettingsDetailScaffold<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            AppGradient.screenBackground
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.large) {
                    SettingsHomeHeader(title: title, subtitle: subtitle)
                    content
                }
                .padding(.horizontal, AppSpacing.medium)
                .padding(.top, AppSpacing.small)
                .padding(.bottom, AppSpacing.large)
            }
        }
    }
}

struct SettingsSectionCard<Content: View>: View {
    let title: String
    let eyebrow: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
            VStack(alignment: .leading, spacing: AppSpacing.xxxSmall) {
                Text(eyebrow.uppercased())
                    .font(AppText.captionStrong)
                    .tracking(1.1)
                    .foregroundStyle(AppColor.Text.tertiary)
                Text(title)
                    .font(AppText.sectionTitle)
                    .foregroundStyle(AppColor.Text.primary)
            }

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.small)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .fill(AppColor.Surface.elevated.opacity(0.96))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.large)
                        .stroke(AppColor.Border.subtle, lineWidth: 1)
                )
        )
        .shadow(color: AppShadow.cardColor, radius: AppShadow.cardRadius, y: AppShadow.cardYOffset)
    }
}

struct SettingsValueRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xSmall) {
            Text(title)
                .font(AppText.body)
                .foregroundStyle(AppColor.Text.primary)
            Spacer()
            Text(value)
                .font(AppText.chip)
                .foregroundStyle(AppColor.Text.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct SettingsSupportingText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(AppText.subheading)
            .foregroundStyle(AppColor.Text.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private enum SettingsActionTrailing {
    case chevron
    case progress
}

private struct SettingsActionLabel: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    var trailing: SettingsActionTrailing = .chevron

    var body: some View {
        HStack(spacing: AppSpacing.xSmall) {
            Image(systemName: icon)
                .font(AppText.captionStrong)
                .foregroundStyle(tint)
                .frame(width: 26, height: 26)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: AppRadius.xSmall))

            VStack(alignment: .leading, spacing: AppSpacing.micro) {
                Text(title)
                    .font(AppText.button)
                    .foregroundStyle(AppColor.Text.primary)
                Text(subtitle)
                    .font(AppText.subheading)
                    .foregroundStyle(AppColor.Text.secondary)
                    .multilineTextAlignment(.leading)
            }

            Spacer()

            switch trailing {
            case .chevron:
                Image(systemName: "chevron.right")
                    .font(AppText.captionStrong)
                    .foregroundStyle(AppColor.Text.tertiary)
            case .progress:
                FitMeLogoLoader(mode: .rotate, size: .small)
            }
        }
        .padding(.vertical, AppSpacing.xxxSmall)
    }
}

private struct SettingsSelectionTile: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {
            Text(title)
                .font(AppText.button)
                .foregroundStyle(isSelected ? AppColor.Text.inversePrimary : AppColor.Text.primary)
            Text(subtitle)
                .font(AppText.caption)
                .foregroundStyle(isSelected ? AppColor.Text.inversePrimary : AppColor.Text.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, AppSpacing.xxSmall)
        .padding(.horizontal, AppSpacing.xSmall)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .fill(isSelected ? tint : AppColor.Surface.materialStrong)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .stroke(isSelected ? tint.opacity(0.18) : AppColor.Border.subtle, lineWidth: 1)
        )
    }
}

private struct SettingsChoiceGrid<Option: Hashable, Tile: View>: View {
    let options: [Option]
    @Binding var selection: Option
    let tile: (Option) -> Tile

    private let columns = [
        GridItem(.flexible(), spacing: AppSpacing.xxSmall, alignment: .top),
        GridItem(.flexible(), spacing: AppSpacing.xxSmall, alignment: .top),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: AppSpacing.xxSmall) {
            ForEach(options, id: \.self) { option in
                Button {
                    selection = option
                } label: {
                    tile(option)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(option)")
                .accessibilityValue(option == selection ? "Selected" : "Not selected")
                .accessibilityAddTraits(option == selection ? [.isSelected] : [])
            }
        }
    }
}

private struct SettingsNumericFieldRow: View {
    let title: String
    let suffix: String
    @Binding var value: Double

    var body: some View {
        HStack(spacing: AppSpacing.xSmall) {
            Text(title)
                .font(AppText.body)
                .foregroundStyle(AppColor.Text.primary)
            Spacer()
            TextField(
                title,
                value: $value,
                format: .number.precision(.fractionLength(0...1))
            )
            .multilineTextAlignment(.trailing)
            .keyboardType(.decimalPad)
            .textFieldStyle(.roundedBorder)
            .frame(width: 96)
            Text(suffix)
                .font(AppText.chip)
                .foregroundStyle(AppColor.Text.secondary)
        }
    }
}

private struct SettingsSliderRow: View {
    let title: String
    let valueText: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let onCommit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {
            HStack {
                Text(title)
                    .font(AppText.body)
                    .foregroundStyle(AppColor.Text.primary)
                Spacer()
                Text(valueText)
                    .font(AppText.chip)
                    .foregroundStyle(AppColor.Text.secondary)
            }

            Slider(
                value: $value,
                in: range,
                step: 1
            ) { _ in
                onCommit()
            }
            .tint(AppColor.Accent.primary)
        }
    }
}
