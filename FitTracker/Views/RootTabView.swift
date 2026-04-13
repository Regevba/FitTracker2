// Views/RootTabView.swift
// 5-tab navigation: Main · Training Plan · Nutrition · Stats · Profile
// Top bar: screen title (left) + account avatar button (right) on every screen
// Adaptive: tab bar on iPhone, sidebar on iPad/macOS

import SwiftUI

enum AppTab: String, CaseIterable, Hashable {
    case main       = "Home"
    case training   = "Training Plan"
    case nutrition  = "Nutrition"
    case stats      = "Stats"
    case profile    = "Profile"

    var icon: String {
        switch self {
        case .main:      "house.fill"
        case .training:  "figure.strengthtraining.traditional"
        case .nutrition: "leaf.fill"
        case .stats:     "chart.bar.fill"
        case .profile:   "person.circle.fill"
        }
    }
}

struct RootTabView: View {

    @EnvironmentObject var signIn:        SignInService
    @EnvironmentObject var biometricAuth: AuthManager
    @EnvironmentObject var dataStore:     EncryptedDataStore
    @EnvironmentObject var healthService: HealthKitService
    @EnvironmentObject var cloudSync:     CloudKitSyncService
    @EnvironmentObject var supabaseSync:  SupabaseSyncService
    @EnvironmentObject var programStore:  TrainingProgramStore
    @EnvironmentObject var settings:      AppSettings

    @Environment(\.horizontalSizeClass) var sizeClass

    @State private var selectedTab:    AppTab
    @State private var showAccount             = false
    @State private var pendingStatsMetric: StatsFocusMetric?

    init() {
        _selectedTab = State(initialValue: Self.reviewSelectedTab)
    }

    var body: some View {
        Group {
            #if os(iOS)
            if sizeClass == .regular { iPadLayout } else { iPhoneLayout }
            #elseif os(macOS)
            iPadLayout
            #endif
        }
        .onAppear {
            if Self.isReviewMode {
                selectedTab = Self.reviewSelectedTab
            }
        }
        .task {
            guard !Self.isReviewMode else { return }
            try? await healthService.requestAuthorization()
        }
        .alert("Data Load Error", isPresented: Binding(
            get: { dataStore.loadError != nil },
            set: { if !$0 { dataStore.loadError = nil } }
        )) {
            Button("OK", role: .cancel) { dataStore.loadError = nil }
        } message: {
            Text(dataStore.loadError ?? "")
        }
        .sheet(isPresented: $showAccount) {
            AccountPanelView()
                .environmentObject(signIn)
                .environmentObject(biometricAuth)
                .environmentObject(dataStore)
                .environmentObject(healthService)
                .environmentObject(cloudSync)
                .environmentObject(supabaseSync)
                .environmentObject(settings)
                .presentationDetents([.large])
                .presentationCornerRadius(AppSheet.standardCornerRadius)
                .analyticsScreen(AnalyticsScreen.settingsAccount)
        }
    }

    // ── iPhone tab bar ────────────────────────────────────
    private var iPhoneLayout: some View {
        TabView(selection: $selectedTab) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                NavigationStack {
                    tabContent(tab)
                        .navigationTitle(tab.rawValue)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar { accountButton }
                }
                .tabItem { Label(tab.rawValue, systemImage: tab.icon) }
                .tag(tab)
            }
        }
        .tint(AppColor.Accent.secondary)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(AppColor.Surface.elevated, for: .tabBar)
        .toolbarColorScheme(.light, for: .tabBar)
    }

    // ── iPad / macOS sidebar ──────────────────────────────
    private var iPadLayout: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                HStack(spacing: AppSpacing.xxSmall) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(AppText.titleMedium)
                        .foregroundStyle(AppColor.Accent.recovery)
                    Text("FitTracker")
                        .font(AppText.sectionTitle)
                        .foregroundStyle(AppColor.Text.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppSpacing.small).padding(.vertical, AppSpacing.xSmall)

                Divider()

                List(AppTab.allCases, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        Label(tab.rawValue, systemImage: tab.icon)
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.sidebar)

                Divider()

                VStack(spacing: AppSpacing.xxSmall) {
                    HStack(spacing: AppSpacing.xxSmall) {
                        Circle().fill(syncColor).frame(width: 6, height: 6)
                        Text(cloudSync.status.rawValue)
                            .font(AppText.caption)
                            .foregroundStyle(AppColor.Text.secondary)
                        Spacer()
                    }
                    Button { showAccount = true } label: {
                        HStack(spacing: AppSpacing.xxSmall) {
                            avatarBadge(30)
                            VStack(alignment: .leading, spacing: AppSpacing.micro) {
                                Text(signIn.currentSession?.displayName ?? "Regev")
                                    .font(AppText.captionStrong)
                                    .foregroundStyle(AppColor.Text.primary)
                                    .lineLimit(1)
                                Text(signIn.currentSession?.email ?? "")
                                    .font(AppText.caption)
                                    .foregroundStyle(AppColor.Text.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "ellipsis")
                                .font(AppText.caption)
                                .foregroundStyle(AppColor.Text.secondary)
                        }
                        .padding(AppSpacing.xxSmall)
                        .background(AppColor.Surface.primary, in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                                .stroke(AppColor.Border.subtle, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, AppSpacing.xSmall).padding(.bottom, AppSpacing.small)
            }
        } detail: {
            NavigationStack {
                tabContent(selectedTab)
                    .navigationTitle(selectedTab.rawValue)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { accountButton }
            }
        }
    }

    // ── Shared account button ─────────────────────────────
    @ToolbarContentBuilder
    private var accountButton: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button { showAccount = true } label: {
                Image(systemName: "line.3.horizontal")
                    .font(AppText.titleMedium)
                    .foregroundStyle(AppColor.Text.inversePrimary)
                    .frame(width: 46, height: 46)
                    .background(
                        Circle()
                            .fill(AppColor.Surface.materialStrong)
                            .overlay(
                                Circle()
                                    .stroke(AppColor.Border.strong, lineWidth: 1)
                            )
                    )
                    .shadow(color: AppShadow.cardColor, radius: AppShadow.cardRadius, y: AppShadow.cardYOffset)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .tint(.clear)
            .accessibilityLabel("Account")
        }
    }

    // ── Tab content ───────────────────────────────────────
    @ViewBuilder
    private func tabContent(_ tab: AppTab) -> some View {
        switch tab {
        case .main:      MainScreenView(selectedTab: $selectedTab, statsMetric: $pendingStatsMetric)
        case .training:  TrainingPlanView().analyticsScreen(AnalyticsScreen.trainingPlan)
        case .nutrition: NutritionView().analyticsScreen(AnalyticsScreen.nutrition)
        case .stats:     StatsView(initialMetric: pendingStatsMetric)
                            .analyticsScreen(AnalyticsScreen.stats)
                            .onDisappear { pendingStatsMetric = nil }
        case .profile:   ProfileView()
        }
    }

    // ── Avatar badge ──────────────────────────────────────
    private func avatarBadge(_ size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [AppColor.Accent.recovery.opacity(0.88), AppColor.Brand.secondary.opacity(0.72)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
            Text(signIn.currentSession?.initials ?? "R")
                .font(AppText.captionStrong)
                .foregroundStyle(AppColor.Text.primary)
        }
    }

    private var syncColor: Color {
        switch cloudSync.status {
        case .idle: AppColor.Status.success
        case .syncing: AppColor.Status.warning
        case .failed: AppColor.Status.error
        case .offline, .disabled: AppColor.Text.tertiary
        }
    }

    private static var isReviewMode: Bool {
        ProcessInfo.processInfo.environment["FITTRACKER_REVIEW_AUTH"] == "authenticated"
    }

    private static var reviewSelectedTab: AppTab {
        switch ProcessInfo.processInfo.environment["FITTRACKER_REVIEW_TAB"]?.lowercased() {
        case "training": .training
        case "nutrition": .nutrition
        case "stats": .stats
        default: .main
        }
    }
}
