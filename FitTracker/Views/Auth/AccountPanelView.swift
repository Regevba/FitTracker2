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
                        .foregroundStyle(Color.appAccentPrimary)
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
                SettingsView()
                    .environmentObject(signIn)
                    .environmentObject(biometricAuth)
                    .environmentObject(dataStore)
                    .environmentObject(healthService)
                    .environmentObject(cloudSync)
                    .environmentObject(settings)
                    .environmentObject(watchService)
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
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            dividerLine

            accountDetailRow(title: "Email", value: session?.email ?? "—", selectable: session?.email != nil)
            accountDetailRow(title: "Phone", value: session?.phone ?? "—")

            Text("Account details come from your active sign-in provider and stay tied to this device's encrypted data.")
                .font(.caption)
                .foregroundStyle(.secondary)
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
                HStack(spacing: AppSpacing.xSmall) {
                    Image(systemName: "gearshape.fill")
                        .foregroundStyle(Color.appAccentPrimary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Open Full Settings")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("Manage account security, HealthKit, goals, training preferences, and sync.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(AppSpacing.xSmall)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: AppRadius.medium))
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
            .tint(.red)

            Text("Signing out returns you to the welcome screen. Encrypted logs remain on device and in iCloud.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(AppSpacing.large)
        .background(cardBackground)
    }

    private var avatarView: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(colors: [.green.opacity(0.8), .mint.opacity(0.6)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: 52, height: 52)

            Text(session?.initials ?? "—")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 22)
            .fill(Color.appSurface.opacity(0.96))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.appStroke, lineWidth: 1)
            )
    }

    private var dividerLine: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(height: 1)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(1)
    }

    private func accountDetailRow(title: String, value: String, selectable: Bool = false) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .leading)
            Group {
                if selectable {
                    Text(value).textSelection(.enabled)
                } else {
                    Text(value)
                }
            }
            .font(.subheadline)
            .foregroundStyle(.primary.opacity(0.82))
            Spacer(minLength: 0)
        }
    }

    private func accessPill(icon: String, label: String, tint: Color) -> some View {
        HStack(spacing: AppSpacing.xxSmall) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
            Text(label)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, AppSpacing.xxSmall)
        .padding(.vertical, AppSpacing.xxSmall)
        .background(tint.opacity(0.12), in: Capsule())
    }

    @ViewBuilder
    private var providerBadge: some View {
        let provider = session?.provider ?? .apple
        HStack(spacing: 3) {
            Image(systemName: providerIcon(provider))
                .font(.system(size: 9, weight: .semibold))
            Text(provider.rawValue)
                .font(.system(size: 9, weight: .semibold))
        }
        .padding(.horizontal, 6).padding(.vertical, 2)
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
        case .apple:    .primary
        case .google:   .red
        case .facebook: .blue
        case .passkey:  .purple
        case .email:    .appBlue2
        }
    }
}
