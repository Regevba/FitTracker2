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
                    VStack(alignment: .leading, spacing: 18) {
                        accountHeroCard
                        settingsLauncherCard
                        signOutCard
                    }
                    .padding(20)
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
                        .environmentObject(settings)
                        .environmentObject(watchService)
                }
                .presentationDetents([.large])
                .presentationCornerRadius(AppSheet.standardCornerRadius)
            }
        }
    }

    // ─────────────────────────────────────────────────────
    // MARK: Sub-components
    // ─────────────────────────────────────────────────────

    private var accountHeroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                avatarView
                VStack(alignment: .leading, spacing: 4) {
                    Text(session?.displayName ?? "User")
                        .font(AppText.titleStrong)
                        .foregroundStyle(AppColor.Text.primary)
                    HStack(spacing: 6) {
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
        .padding(18)
        .background(cardBackground)
    }

    private var settingsLauncherCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Settings")

            HStack(spacing: 10) {
                accessPill(
                    icon: "lock.fill",
                    label: settings.requireBiometricUnlockOnReopen ? "Biometric Reopen On" : "Biometric Reopen Off",
                    tint: settings.requireBiometricUnlockOnReopen ? .green : .orange
                )

                if session?.provider == .passkey {
                    accessPill(icon: "key.fill", label: "Passkey Active", tint: .purple)
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
                AppMenuRow(
                    icon: "gearshape.fill",
                    title: "Open Full Settings",
                    subtitle: "Manage account security, HealthKit, goals, training preferences, sync, and design system guidance.",
                    tint: AppColor.Accent.primary
                )
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(cardBackground)
    }

    private var signOutCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Session")
            AppButton(
                title: "Sign Out",
                systemImage: "rectangle.portrait.and.arrow.right",
                hierarchy: .destructive
            ) {
                showLogoutConfirm = true
            }
            .buttonStyle(.plain)

            Text("Signing out returns you to the welcome screen. Encrypted logs remain on device and in iCloud.")
                .font(AppText.caption)
                .foregroundStyle(AppColor.Text.secondary)
        }
        .padding(18)
        .background(cardBackground)
    }

    private var avatarView: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [AppColor.Accent.primary.opacity(0.88), AppColor.Accent.secondary.opacity(0.72)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 52, height: 52)

            Text(session?.initials ?? "—")
                .font(AppText.metricCompact)
                .foregroundStyle(AppColor.Text.inversePrimary)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 22)
            .fill(AppColor.Surface.elevated)
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(AppColor.Border.subtle, lineWidth: 1)
            )
    }

    private var dividerLine: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
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
            .font(AppText.subheading)
            .foregroundStyle(AppColor.Text.primary)
            Spacer(minLength: 0)
        }
    }

    private func accessPill(icon: String, label: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(AppText.captionStrong)
            Text(label)
                .font(AppText.captionStrong)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(tint.opacity(0.12), in: Capsule())
    }

    @ViewBuilder
    private var providerBadge: some View {
        let provider = session?.provider ?? .apple
        HStack(spacing: 3) {
            Image(systemName: providerIcon(provider))
                .font(AppText.monoLabel)
            Text(provider.rawValue)
                .font(AppText.monoLabel)
        }
        .padding(.horizontal, 6).padding(.vertical, 2)
        .background(providerColor(provider).opacity(0.12), in: Capsule())
        .foregroundStyle(providerColor(provider))
    }

    private func providerIcon(_ p: AuthProvider) -> String {
        switch p {
        case .apple:    "apple.logo"
        case .google:   "globe"
        case .facebook: "person.2.fill"
        case .passkey:  "key.fill"
        case .email:    "envelope.fill"
        }
    }

    private func providerColor(_ p: AuthProvider) -> Color {
        switch p {
        case .apple:    AppColor.Text.primary
        case .google:   AppColor.Accent.secondary
        case .facebook: AppColor.Accent.sleep
        case .passkey:  AppColor.Accent.sleep
        case .email:    AppColor.Accent.secondary
        }
    }
}
