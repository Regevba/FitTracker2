// FitTracker/Views/Profile/ProfileView.swift
// Unified profile tab — the user's personal control center.
// Hero section + readiness + body comp + settings access + sign out.

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var dataStore: EncryptedDataStore
    @EnvironmentObject var healthService: HealthKitService
    @EnvironmentObject var signIn: SignInService
    @EnvironmentObject var analytics: AnalyticsService
    @EnvironmentObject var aiOrchestrator: AIOrchestrator

    @State private var showGoalEditor = false
    @State private var showSettings = false
    @State private var showSignOutAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppGradient.screenBackground
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.medium) {
                        // Hero
                        ProfileHeroSection(
                            displayName: displayName,
                            email: signIn.activeSession?.email,
                            fitnessGoal: dataStore.userProfile.fitnessGoal,
                            programPhase: dataStore.userProfile.currentPhase,
                            daysSinceStart: dataStore.userProfile.daysSinceStart,
                            streakDays: dataStore.supplementStreak,
                            totalWorkouts: workoutCount,
                            onGoalTap: { showGoalEditor = true },
                            onAvatarTap: { analytics.logProfileAvatarTap() }
                        )

                        // Readiness snapshot
                        readinessSection

                        // Body composition
                        ProfileBodyCompCard(
                            currentWeight: latestBiometrics?.weightKg,
                            currentBF: latestBiometrics?.bodyFatPercent,
                            currentLeanMass: latestBiometrics?.leanBodyMassKg,
                            targetWeightMin: dataStore.userProfile.targetWeightMin,
                            targetWeightMax: dataStore.userProfile.targetWeightMax,
                            targetBFMin: dataStore.userProfile.targetBFMin,
                            targetBFMax: dataStore.userProfile.targetBFMax,
                            startBF: dataStore.userProfile.startBodyFatPct,
                            onTap: { analytics.logProfileBodyCompTap() }
                        )

                        // AI coaching insight
                        AIInsightCard()

                        // Settings access
                        settingsButton

                        // Sign out
                        signOutButton
                    }
                    .padding(.horizontal, AppSpacing.medium)
                    .padding(.bottom, AppSpacing.xLarge)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            analytics.logProfileTabViewed(source: "tab_bar")
        }
        .sheet(isPresented: $showGoalEditor) {
            GoalEditorSheet()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .alert("Sign Out", isPresented: $showSignOutAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                Task { await signIn.signOut() }
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }

    // MARK: - Readiness Section

    @ViewBuilder
    private var readinessSection: some View {
        let result = dataStore.readinessResult(for: Date(), fallbackMetrics: healthService.latest)

        Button {
            analytics.logProfileReadinessTap()
        } label: {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                Text("Today's Readiness")
                    .font(AppText.subheading)
                    .foregroundStyle(AppColor.Text.primary)

                if let result {
                    HStack {
                        Text("\(result.overallScore)")
                            .font(AppText.sectionTitle)
                            .foregroundStyle(AppColor.Text.primary)
                        Text(result.recommendation.rawValue)
                            .font(AppText.caption)
                            .foregroundStyle(AppColor.Text.secondary)
                            .padding(.horizontal, AppSpacing.small)
                            .padding(.vertical, AppSpacing.xxxSmall)
                            .background(AppColor.Surface.secondary, in: Capsule())
                        Spacer()
                        Text(result.confidence.rawValue.capitalized)
                            .font(AppText.caption)
                            .foregroundStyle(AppColor.Text.tertiary)
                    }

                    // Component mini-bars (decorative detail — parent button label covers readiness summary)
                    VStack(spacing: AppSpacing.xxxSmall) {
                        componentBar(label: "HRV", score: result.hrvScore, color: AppColor.Chart.hrv)
                        componentBar(label: "Sleep", score: result.sleepScore, color: AppColor.Accent.sleep)
                        componentBar(label: "Load", score: result.trainingLoadScore, color: AppColor.Brand.primary)
                        componentBar(label: "RHR", score: result.rhrScore, color: AppColor.Chart.heartRate)
                    }
                    .accessibilityHidden(true)
                } else {
                    Text("Log biometrics to see your readiness score")
                        .font(AppText.caption)
                        .foregroundStyle(AppColor.Text.tertiary)
                }
            }
            .padding(AppSpacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.Surface.primary, in: RoundedRectangle(cornerRadius: AppRadius.card))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(result.map { "Today's readiness: \($0.overallScore) out of 100. \($0.recommendation.rawValue). HRV \(Int($0.hrvScore)), Sleep \(Int($0.sleepScore)), Load \(Int($0.trainingLoadScore)), RHR \(Int($0.rhrScore))." } ?? "Readiness not available. Log biometrics to see your score.")
        .accessibilityHint("Double tap to view full readiness details")
    }

    // MARK: - Settings Button

    private var settingsButton: some View {
        Button {
            analytics.logProfileSettingsSectionOpened(section: "all")
            showSettings = true
        } label: {
            HStack {
                Image(systemName: AppIcon.settings)
                    .foregroundStyle(AppColor.Text.secondary)
                Text("Settings")
                    .font(AppText.body)
                    .foregroundStyle(AppColor.Text.primary)
                Spacer()
                Image(systemName: AppIcon.forward)
                    .font(AppText.caption)
                    .foregroundStyle(AppColor.Text.tertiary)
            }
            .padding(AppSpacing.medium)
            .background(AppColor.Surface.primary, in: RoundedRectangle(cornerRadius: AppRadius.card))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Settings")
        .accessibilityHint("Double tap to open settings")
    }

    // MARK: - Sign Out

    private var signOutButton: some View {
        Button {
            showSignOutAlert = true
        } label: {
            Text("Sign Out")
                .font(AppText.body)
                .foregroundStyle(AppColor.Status.error)
                .frame(maxWidth: .infinity)
                .padding(AppSpacing.medium)
                .background(AppColor.Surface.primary, in: RoundedRectangle(cornerRadius: AppRadius.card))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Sign out")
        .accessibilityHint("Double tap to confirm sign out")
    }

    // MARK: - Helpers

    private var displayName: String {
        if let dn = dataStore.userProfile.displayName { return dn }
        if let sn = signIn.activeSession?.displayName { return sn }
        let name = dataStore.userProfile.name
        return name.isEmpty ? "FitMe User" : name
    }

    private var latestBiometrics: DailyBiometrics? {
        dataStore.dailyLogs.last?.biometrics
    }

    private var workoutCount: Int {
        dataStore.dailyLogs.filter { !$0.exerciseLogs.isEmpty || !$0.cardioLogs.isEmpty }.count
    }

    private func componentBar(label: String, score: Double, color: Color) -> some View {
        HStack(spacing: AppSpacing.xSmall) {
            Text(label)
                .font(AppText.caption)
                .foregroundStyle(AppColor.Text.secondary)
                .frame(width: 40, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: AppRadius.button)
                        .fill(AppColor.Surface.secondary)
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: AppRadius.button)
                        .fill(color)
                        .frame(width: geo.size.width * min(1, score / 100), height: 6)
                }
            }
            .frame(height: 6)
            Text("\(Int(score))")
                .font(AppText.monoCaption)
                .foregroundStyle(AppColor.Text.tertiary)
                .frame(width: 24, alignment: .trailing)
        }
    }
}
