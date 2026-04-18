// FitTracker/Views/Profile/ProfileView.swift
// Simplified profile — hero + summary cards + appearance + sign out.
// Opened from hamburger menu on all screens.

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var dataStore: EncryptedDataStore
    @EnvironmentObject var signIn: SignInService
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var analytics: AnalyticsService
    @EnvironmentObject var cloudSync: CloudKitSyncService
    @Environment(\.dismiss) var dismiss

    @State private var showGoalEditor = false
    @State private var showSettings = false
    @State private var showAppearance = false
    @State private var showSignOutAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppGradient.screenBackground
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.medium) {
                        // 1. Hero
                        ProfileHeroSection(
                            displayName: displayName,
                            age: dataStore.userProfile.age,
                            heightCm: dataStore.userProfile.heightCm,
                            experienceLevel: dataStore.userProfile.experienceLevel,
                            fitnessGoal: dataStore.userProfile.fitnessGoal,
                            programPhase: dataStore.userProfile.currentPhase,
                            daysSinceStart: dataStore.userProfile.daysSinceStart,
                            onGoalTap: { showGoalEditor = true },
                            onAvatarTap: { analytics.logProfileAvatarTap() }
                        )

                        // 2. Goals & Training card
                        GoalsTrainingCard(
                            fitnessGoal: dataStore.userProfile.fitnessGoal,
                            targetWeightMin: dataStore.userProfile.targetWeightMin,
                            targetWeightMax: dataStore.userProfile.targetWeightMax,
                            trainingDaysPerWeek: dataStore.userProfile.trainingDaysPerWeek ?? 4,
                            onTap: {
                                analytics.logProfileSettingsSectionOpened(section: "goals_training")
                                showGoalEditor = true
                            }
                        )

                        // 3. Account & Data card
                        AccountDataCard(
                            signInProvider: signIn.activeSession?.provider.rawValue,
                            biometricEnabled: settings.requireBiometricUnlockOnReopen,
                            syncStatus: cloudSync.status.rawValue,
                            onTap: {
                                analytics.logProfileSettingsSectionOpened(section: "account_data")
                                showSettings = true
                            }
                        )

                        // 4. Appearance & Units row
                        appearanceRow

                        // 5. Sign Out
                        signOutButton

                        // 6. About footer
                        aboutFooter
                    }
                    .padding(.horizontal, AppSpacing.medium)
                    .padding(.bottom, AppSpacing.xLarge)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(AppText.iconCompact)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(AppColor.Text.tertiary)
                    }
                    .accessibilityLabel("Close profile")
                }
            }
        }
        .onAppear {
            analytics.logProfileTabViewed(source: "hamburger_menu")
        }
        .sheet(isPresented: $showGoalEditor) {
            GoalEditorSheet()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showAppearance) {
            AppearanceUnitsSheet()
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

    // MARK: - Appearance Row

    private var appearanceRow: some View {
        Button {
            showAppearance = true
        } label: {
            HStack(spacing: AppSpacing.small) {
                Image(systemName: "paintpalette.fill")
                    .font(AppText.titleMedium)
                    .foregroundStyle(AppColor.Accent.sleep)
                    .frame(width: 36, height: 36)
                    .background(AppColor.Accent.sleep.opacity(0.12), in: RoundedRectangle(cornerRadius: AppRadius.small))

                Text("Appearance & Units")
                    .font(AppText.callout)
                    .foregroundStyle(AppColor.Text.primary)

                Spacer(minLength: 0)

                Text(appearanceSummary)
                    .font(AppText.caption)
                    .foregroundStyle(AppColor.Text.secondary)

                Image(systemName: "chevron.right")
                    .font(AppText.caption)
                    .foregroundStyle(AppColor.Text.tertiary)
            }
            .padding(AppSpacing.medium)
            .background(AppColor.Surface.primary, in: RoundedRectangle(cornerRadius: AppRadius.card))
            .shadow(color: AppShadow.cardColor, radius: AppShadow.cardRadius, y: AppShadow.cardYOffset)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Appearance and Units")
        .accessibilityValue(appearanceSummary)
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

    // MARK: - About Footer

    private var aboutFooter: some View {
        VStack(spacing: AppSpacing.xxxSmall) {
            Text("FitMe v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                .font(AppText.caption)
                .foregroundStyle(AppColor.Text.tertiary)
            HStack(spacing: AppSpacing.xSmall) {
                Text("Terms")
                Text("·")
                Text("Privacy")
                Text("·")
                Text("Support")
            }
            .font(AppText.caption)
            .foregroundStyle(AppColor.Text.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, AppSpacing.small)
    }

    // MARK: - Helpers

    private var displayName: String {
        if let dn = dataStore.userProfile.displayName { return dn }
        if let sn = signIn.activeSession?.displayName { return sn }
        let name = dataStore.userProfile.name
        return name.isEmpty ? "FitMe User" : name
    }

    private var appearanceSummary: String {
        let theme = settings.appearance.rawValue
        let units = settings.unitSystem.rawValue
        return "\(theme) · \(units)"
    }
}
