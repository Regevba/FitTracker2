// FitTracker/Views/Settings/v2/SettingsView.swift
// Settings v2 — UX Foundations alignment pass (2026-04-10)
// See .claude/features/settings-v2/v2-audit-report.md

import SwiftUI
import LocalAuthentication

enum SettingsCategory: String, CaseIterable, Hashable, Identifiable {
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

struct SettingsHomeHeader: View {
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

