// FitTracker/Views/Settings/v2/Screens/DataSourcesScreen.swift
// Settings v2 — Data Sources (garmin-health-connection / fitbit-health-connection, Tier 1).
// Shows which wearable sources (Garmin, Fitbit) are relaying recovery signals into
// FitMe through Apple Health, and guides the user to connect ones that aren't.
// Tier 1 = HealthKit relay only; no vendor API / OAuth (deferred Tier 2).
// Spec: .claude/features/garmin-health-connection/ux-spec.md

import SwiftUI
import UIKit

// MARK: - View Model

@MainActor
final class DataSourcesViewModel: ObservableObject {
    @Published private(set) var presences: [SourcePresence] = []
    @Published private(set) var isLoading = true

    private let probe: HealthKitSourceProbe

    init(probe: HealthKitSourceProbe = .live()) {
        self.probe = probe
    }

    func refresh() async {
        isLoading = true
        presences = await probe.presenceForAllSources()
        isLoading = false
    }

    func presence(for source: DataSource) -> SourcePresence {
        presences.first { $0.source == source } ?? .empty(source)
    }
}

// MARK: - Screen

struct DataSourcesScreen: View {
    @EnvironmentObject private var healthService: HealthKitService
    @EnvironmentObject private var analytics: AnalyticsService
    @StateObject private var model = DataSourcesViewModel()

    @State private var connectingSource: DataSource?
    @State private var connectStartedAt: Date?
    @State private var loggedDetections: Set<DataSource> = []

    var body: some View {
        Group {
            if healthService.isAuthorized {
                connectedContent
            } else {
                healthNotGrantedContent
            }
        }
        .navigationTitle("Data Sources")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { analytics.logSettingsDataSourcesViewed() }
        .task {
            await model.refresh()
            logDetections()
        }
        .sheet(item: $connectingSource, onDismiss: handleConnectDismiss) { source in
            ConnectGuidanceView(source: source)
                .onAppear {
                    connectStartedAt = Date()
                    analytics.logSettingsDataSourceConnectStarted(source: source.rawValue)
                }
        }
    }

    // MARK: Connected (HealthKit authorized)

    private var connectedContent: some View {
        SettingsDetailScaffold(
            title: "Data Sources",
            subtitle: "Bring your wearable's recovery data into \(AppBrand.name) through Apple Health."
        ) {
            SettingsSectionCard(title: "Connected sources", eyebrow: "Sources") {
                ForEach(DataSource.allCases) { source in
                    DataSourceRow(presence: model.presence(for: source)) {
                        connectingSource = source
                        lastConnecting = source
                        if !model.presence(for: source).isActive {
                            analytics.logSettingsDataSourceEmptyStateShown(
                                source: source.rawValue,
                                missing: ReadinessSignal.allCases.map(\.shortLabel).joined(separator: ","),
                                reason: "not_connected"
                            )
                        }
                    }
                    if source != DataSource.allCases.last {
                        Divider().overlay(AppColor.Border.hairline)
                    }
                }
            }

            SettingsSectionCard(title: "How this works", eyebrow: "About") {
                SettingsValueRow(
                    title: "Apple Health",
                    value: healthService.isAuthorized ? "Connected" : "Not granted"
                )
                SettingsSupportingText(
                    "\(AppBrand.name) reads recovery data your Garmin or Fitbit already shares with Apple Health — no separate login. Turn on Apple Health sync in the Garmin Connect or Fitbit app and your readiness score updates automatically."
                )
            }
        }
    }

    // MARK: HealthKit not granted

    private var healthNotGrantedContent: some View {
        SettingsDetailScaffold(
            title: "Data Sources",
            subtitle: "Connect Apple Health to bring your wearable's recovery data into \(AppBrand.name)."
        ) {
            EmptyStateView(
                icon: "heart.text.square",
                title: "Connect Apple Health",
                subtitle: "\(AppBrand.name) reads Garmin and Fitbit recovery data through Apple Health. Allow access to get started.",
                ctaLabel: "Allow Access",
                ctaAction: { Task { try? await healthService.requestAuthorization() } }
            )
        }
    }

    // MARK: Analytics helpers

    private func logDetections() {
        for source in DataSource.allCases {
            let presence = model.presence(for: source)
            guard presence.isActive, !loggedDetections.contains(source) else { continue }
            loggedDetections.insert(source)
            analytics.logSettingsDataSourceDetected(
                source: source.rawValue,
                signals: presence.signalsPresent.map(\.shortLabel).joined(separator: ",")
            )
        }
    }

    private func handleConnectDismiss() {
        guard let source = lastConnecting else { return }
        Task {
            await model.refresh()
            let presence = model.presence(for: source)
            if presence.isActive, !loggedDetections.contains(source) {
                loggedDetections.insert(source)
                let seconds = connectStartedAt.map { Int(Date().timeIntervalSince($0)) } ?? 0
                analytics.logSettingsDataSourceConnectCompleted(source: source.rawValue, timeToDetectSeconds: seconds)
            }
            connectStartedAt = nil
        }
    }

    // `connectingSource` is nil by dismiss time; capture the last value.
    @State private var lastConnecting: DataSource?
}

// MARK: - Source Row

private struct DataSourceRow: View {
    let presence: SourcePresence
    let onConnect: () -> Void

    private var source: DataSource { presence.source }

    var body: some View {
        Button(action: onConnect) {
            HStack(spacing: AppSpacing.small) {
                Image(systemName: source.iconSystemName)
                    .font(AppText.iconSmall)
                    .foregroundStyle(presence.isActive ? AppColor.Accent.recovery : AppColor.Text.tertiary)
                    .frame(width: AppSize.iconBadge, height: AppSize.iconBadge)

                VStack(alignment: .leading, spacing: AppSpacing.xxxSmall) {
                    Text(source.displayName)
                        .font(AppText.button)
                        .foregroundStyle(AppColor.Text.primary)
                    Text(statusLine)
                        .font(AppText.subheading)
                        .foregroundStyle(AppColor.Text.secondary)
                    if presence.isActive {
                        signalChips
                    }
                }

                Spacer(minLength: AppSpacing.xSmall)

                StatusBadge(text: statusBadgeText, color: statusColor)
            }
            .contentShape(Rectangle())
            .frame(minHeight: AppSize.tapTarget)
            .padding(.vertical, AppSpacing.xxSmall)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(source.displayName), \(statusBadgeText). \(statusLine)")
    }

    private var signalChips: some View {
        HStack(spacing: AppSpacing.xxxSmall) {
            ForEach(Array(orderedSignals), id: \.self) { signal in
                StatusBadge(text: signal.shortLabel, color: AppColor.Accent.recovery)
            }
        }
        .accessibilityHidden(true)  // folded into the row label
    }

    private var orderedSignals: [ReadinessSignal] {
        ReadinessSignal.allCases.filter { presence.signalsPresent.contains($0) }
    }

    private var statusLine: String {
        if presence.isActive {
            return "Syncing " + orderedSignals.map(\.shortLabel).joined(separator: ", ")
        }
        return "Not detected in Apple Health"
    }

    private var statusBadgeText: String { presence.isActive ? "Active" : "Set up" }

    private var statusColor: Color { presence.isActive ? AppColor.Status.success : AppColor.Text.tertiary }
}

// MARK: - Guided Connection Sheet

private struct ConnectGuidanceView: View {
    let source: DataSource
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SettingsDetailScaffold(
            title: "Connect \(source.displayName)",
            subtitle: "\(source.displayName) shares its recovery data with \(AppBrand.name) through Apple Health — no separate login."
        ) {
            SettingsSectionCard(title: "Three steps", eyebrow: "Setup") {
                stepRow(1, "Open the \(source.companionAppName) app on this iPhone.")
                stepRow(2, "Enable Apple Health permissions for HRV, resting heart rate, and sleep.")
                stepRow(3, "Return to \(AppBrand.name) — your readiness score updates automatically.")
            }

            Button {
                openHealthApp()
                dismiss()
            } label: {
                Text("Open Health App")
                    .font(AppText.button)
                    .foregroundStyle(AppColor.Text.inversePrimary)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: AppSize.ctaHeight)
                    .background(AppColor.Accent.primary, in: RoundedRectangle(cornerRadius: AppRadius.button))
            }
            .buttonStyle(.plain)

            Button("Done") { dismiss() }
                .font(AppText.button)
                .foregroundStyle(AppColor.Accent.primary)
                .frame(maxWidth: .infinity)
        }
    }

    private func stepRow(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.small) {
            Text("\(number)")
                .font(AppText.chip)
                .foregroundStyle(AppColor.Text.inversePrimary)
                .frame(width: AppSize.controlSmall, height: AppSize.controlSmall)
                .background(AppColor.Accent.primary, in: Circle())
            Text(text)
                .font(AppText.body)
                .foregroundStyle(AppColor.Text.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, AppSpacing.xxxSmall)
    }

    private func openHealthApp() {
        // Deep-link to the Health app where the OS allows; falls back harmlessly.
        if let url = URL(string: "x-apple-health://"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
}
