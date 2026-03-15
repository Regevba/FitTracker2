// Views/RootTabView.swift
// 4-tab navigation: Main · Training Plan · Nutrition · Stats
// Top bar: screen title (left) + account avatar button (right) on every screen
// Adaptive: tab bar on iPhone, sidebar on iPad/macOS

import SwiftUI

enum AppTab: String, CaseIterable, Hashable {
    case main       = "Home"
    case training   = "Training Plan"
    case nutrition  = "Nutrition"
    case stats      = "Stats"

    var icon: String {
        switch self {
        case .main:      "house.fill"
        case .training:  "figure.strengthtraining.traditional"
        case .nutrition: "leaf.fill"
        case .stats:     "chart.bar.fill"
        }
    }
}

struct RootTabView: View {

    @EnvironmentObject var signIn:        SignInService
    @EnvironmentObject var biometricAuth: AuthManager
    @EnvironmentObject var dataStore:     EncryptedDataStore
    @EnvironmentObject var healthService: HealthKitService
    @EnvironmentObject var cloudSync:     CloudKitSyncService
    @EnvironmentObject var programStore:  TrainingProgramStore
    @EnvironmentObject var settings:      AppSettings

    @Environment(\.horizontalSizeClass) var sizeClass

    @State private var selectedTab:    AppTab = .main
    @State private var showAccount             = false

    var body: some View {
        Group {
            #if os(iOS)
            if sizeClass == .regular { iPadLayout } else { iPhoneLayout }
            #elseif os(macOS)
            iPadLayout
            #endif
        }
        .task {
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
                .environmentObject(settings)
                .presentationDetents([.large])
                .presentationCornerRadius(24)
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
        .tint(.blue)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(Color.white.opacity(0.92), for: .tabBar)
        .toolbarColorScheme(.light, for: .tabBar)
    }

    // ── iPad / macOS sidebar ──────────────────────────────
    private var iPadLayout: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.title3.weight(.semibold)).foregroundStyle(.green)
                    Text("FitTracker")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16).padding(.vertical, 12)

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

                VStack(spacing: 10) {
                    HStack(spacing: 6) {
                        Circle().fill(syncColor).frame(width: 6, height: 6)
                        Text(cloudSync.status.rawValue).font(.caption2).foregroundStyle(.secondary)
                        Spacer()
                    }
                    Button { showAccount = true } label: {
                        HStack(spacing: 10) {
                            avatarBadge(30)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(signIn.currentSession?.displayName ?? "Regev")
                                    .font(.caption.weight(.semibold)).lineLimit(1)
                                Text(signIn.currentSession?.email ?? "")
                                    .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "ellipsis").font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(10)
                        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12).padding(.bottom, 16)
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
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white.opacity(0.92))
                    .frame(width: 46, height: 46)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.34))
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.45), lineWidth: 1)
                            )
                    )
                    .shadow(color: .black.opacity(0.08), radius: 10, y: 5)
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
        case .main:      MainScreenView(selectedTab: $selectedTab)
        case .training:  TrainingPlanView()
        case .nutrition: NutritionView()
        case .stats:     StatsView()
        }
    }

    // ── Avatar badge ──────────────────────────────────────
    private func avatarBadge(_ size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [.green.opacity(0.8), .mint.opacity(0.6)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: size, height: size)
            Text(signIn.currentSession?.initials ?? "R")
                .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
                .foregroundStyle(.black)
        }
    }

    private var syncColor: Color {
        switch cloudSync.status {
        case .idle: .green; case .syncing: .orange
        case .failed: .red; case .offline, .disabled: .secondary
        }
    }
}
