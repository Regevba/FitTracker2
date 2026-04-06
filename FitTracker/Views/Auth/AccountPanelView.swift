// Views/Auth/AccountPanelView.swift
// Slide-out panel from the top-right account button.
// Structure:
//   1. Profile card  — avatar / name / email / phone / sign-in provider
//   2. Settings      — button that opens SettingsView as a sheet
//   3. Sign Out

import SwiftUI

struct AccountPanelView: View {

    @EnvironmentObject var signIn:    SignInService
    @EnvironmentObject var biometricAuth: AuthManager
    @EnvironmentObject var dataStore: EncryptedDataStore
    @EnvironmentObject var healthService: HealthKitService
    @EnvironmentObject var cloudSync: CloudKitSyncService
    @EnvironmentObject var supabaseSync: SupabaseSyncService
    @EnvironmentObject var settings:  AppSettings
    @EnvironmentObject var watchService: WatchConnectivityService
    @Environment(\.dismiss) var dismiss

    @State private var showLogoutConfirm = false
    @State private var showSettings = false

    private var session: UserSession? { signIn.currentSession }

    var body: some View {
        NavigationStack {
            ZStack {
                AppGradient.screenBackground
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: AppSpacing.large) {
                        accountHeroCard
                        settingsLauncherCard
                        signOutCard
                    }
                    .padding(AppSpacing.medium)
                }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColor.Accent.primary)
                }
            }
            .alert("Sign Out?", isPresented: $showLogoutConfirm) {
                Button("Sign Out", role: .destructive) {
                    signIn.signOut()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You'll be returned to the welcome screen. Your encrypted data remains safely stored on this device and in iCloud.")
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    SettingsView()
                        .environmentObject(signIn)
                        .environmentObject(biometricAuth)
                        .environmentObject(dataStore)
                        .environmentObject(healthService)
                        .environmentObject(cloudSync)
                        .environmentObject(supabaseSync)
                        .environmentObject(settings)
                        .environmentObject(watchService)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { showSettings = false }
                            }
                        }
                }
                .presentationDetents([.large])
            }
        }
    }

    // ─────────────────────────────────────────────────────
    // MARK: Sub-components
    // ─────────────────────────────────────────────────────

    private var accountHeroCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            HStack(spacing: AppSpacing.small) {
                avatarView
                VStack(alignment: .leading, spacing: AppSpacing.xxxSmall) {
                    Text(session?.displayName ?? "User")
                        .font(.title3.weight(.bold))
                    HStack(spacing: AppSpacing.xxSmall) {
                        providerBadge
                        Text(session?.provider.rawValue ?? "Signed In")
                            .font(AppText.caption)
                            .foregroundStyle(AppColor.Text.secondary)
                    }
                }
                Spacer()
            }

            dividerLine

            accountDetailRow(title: "Email", value: session?.email ?? "—", selectable: session?.email != nil)
            accountDetailRow(title: "Phone", value: session?.phone ?? "—")

            Text("Account details come from your active sign-in provider and stay tied to this device's encrypted data.")
                .font(AppText.caption)
                .foregroundStyle(AppColor.Text.secondary)
        }
        .padding(AppSpacing.large)
        .background(cardBackground)
    }

    private var settingsLauncherCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
            sectionTitle("Settings")

            HStack(spacing: AppSpacing.xxSmall) {
                accessPill(
                    icon: "lock.fill",
                    label: settings.requireBiometricUnlockOnReopen ? "Biometric Reopen On" : "Biometric Reopen Off",
                    tint: settings.requireBiometricUnlockOnReopen ? AppColor.Status.success : AppColor.Status.warning
                )

                if session?.provider == .passkey {
                    accessPill(icon: "key.fill", label: "Passkey Active", tint: AppColor.Accent.sleep)
                }

                accessPill(
                    icon: "applewatch",
                    label: watchService.status.label,
                    tint: watchService.status.dotColor
                )
            }

            Button {
                showSettings = true
            } label: {
                HStack(spacing: AppSpacing.xSmall) {
                    Image(systemName: "gearshape.fill")
                        .foregroundStyle(AppColor.Accent.primary)
                    VStack(alignment: .leading, spacing: AppSpacing.micro) {
                        Text("Open Full Settings")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppColor.Text.primary)
                        Text("Manage account security, HealthKit, goals, training preferences, and sync.")
                            .font(AppText.caption)
                            .foregroundStyle(AppColor.Text.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(AppText.captionStrong)
                        .foregroundStyle(AppColor.Text.secondary)
                }
                .padding(AppSpacing.xSmall)
                .background(AppColor.Surface.materialLight, in: RoundedRectangle(cornerRadius: AppRadius.medium))
            }
            .buttonStyle(.plain)
        }
        .padding(AppSpacing.large)
        .background(cardBackground)
    }

    private var signOutCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {
            sectionTitle("Session")
            Button(role: .destructive) {
                showLogoutConfirm = true
            } label: {
                HStack(spacing: AppSpacing.xSmall) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("Sign Out")
                        .fontWeight(.semibold)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.xSmall)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColor.Status.error)

            Text("Signing out returns you to the welcome screen. Encrypted logs remain on device and in iCloud.")
                .font(AppText.caption)
                .foregroundStyle(AppColor.Text.secondary)
        }
        .padding(AppSpacing.large)
        .background(cardBackground)
    }

    private var avatarView: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(colors: [AppColor.Status.success.opacity(0.8), AppColor.Brand.cool.opacity(0.6)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: 52, height: 52)

            Text(session?.initials ?? "—")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: AppRadius.large)
            .fill(AppColor.Surface.primary.opacity(0.96))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.large)
                    .stroke(AppColor.Border.strong, lineWidth: 1)
            )
    }

    private var dividerLine: some View {
        Rectangle()
            .fill(AppColor.Border.hairline)
            .frame(height: 1)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(AppText.captionStrong)
            .foregroundStyle(AppColor.Text.secondary)
            .textCase(.uppercase)
            .tracking(1)
    }

    private func accountDetailRow(title: String, value: String, selectable: Bool = false) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .font(AppText.captionStrong)
                .foregroundStyle(AppColor.Text.secondary)
                .frame(width: 52, alignment: .leading)
            Group {
                if selectable {
                    Text(value).textSelection(.enabled)
                } else {
                    Text(value)
                }
            }
            .font(.subheadline)
            .foregroundStyle(AppColor.Text.primary.opacity(0.82))
            Spacer(minLength: 0)
        }
    }

    private func accessPill(icon: String, label: String, tint: Color) -> some View {
        HStack(spacing: AppSpacing.xxSmall) {
            Image(systemName: icon)
                .font(AppText.captionStrong)
            Text(label)
                .font(AppText.captionStrong)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, AppSpacing.xxSmall)
        .padding(.vertical, AppSpacing.xxSmall)
        .background(tint.opacity(0.12), in: Capsule())
    }

    @ViewBuilder
    private var providerBadge: some View {
        let provider = session?.provider ?? .apple
        HStack(spacing: AppSpacing.micro) {
            Image(systemName: providerIcon(provider))
                .font(AppText.monoLabel)
            Text(provider.rawValue)
                .font(AppText.monoLabel)
        }
        .padding(.horizontal, AppSpacing.xxSmall).padding(.vertical, AppSpacing.micro)
        .background(providerColor(provider).opacity(0.12), in: Capsule())
        .foregroundStyle(providerColor(provider))
    }

    private func providerIcon(_ p: AuthProvider) -> String {
        switch p {
        case .apple:    "apple.logo"
        case .google:   "globe"
        case .facebook: "f.circle.fill"
        case .passkey:  "key.fill"
        case .email:    "envelope.fill"
        }
    }

    private func providerColor(_ p: AuthProvider) -> Color {
        switch p {
        case .apple:    AppColor.Text.primary
        case .google:   AppColor.Status.error
        case .facebook: AppColor.Brand.secondary
        case .passkey:  AppColor.Accent.sleep
        case .email:    AppColor.Brand.secondary
        }
    }
}
