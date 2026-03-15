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
    @Environment(\.dismiss) var dismiss

    @State private var showLogoutConfirm = false
    @State private var showSettings = false

    private var session: UserSession? { signIn.currentSession }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    accountHeroCard
                    accessCard
                    settingsCard
                    signOutCard
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(.green)
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
                }
                    .presentationDetents([.large])
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
                        .font(.title3.weight(.bold))
                    HStack(spacing: 6) {
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
        .padding(18)
        .background(cardBackground)
    }

    private var accessCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Access")

            HStack(spacing: 10) {
                accessPill(
                    icon: "lock.fill",
                    label: settings.requireBiometricUnlockOnReopen ? "Biometric Reopen On" : "Biometric Reopen Off",
                    tint: settings.requireBiometricUnlockOnReopen ? .green : .orange
                )

                if session?.provider == .passkey {
                    accessPill(icon: "key.fill", label: "Passkey Active", tint: .purple)
                }
            }

            Button {
                showSettings = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "faceid")
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Security and Access Settings")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("Manage reopen lock, passkeys, sync, and device protection.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(cardBackground)
    }

    private var settingsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("App")

            HStack(spacing: 12) {
                settingsMiniTile(title: settings.unitSystem.rawValue, subtitle: "Units", icon: "ruler", tint: .blue)
                settingsMiniTile(title: settings.appearance.rawValue, subtitle: "Appearance", icon: "paintpalette.fill", tint: .indigo)
            }

            Button {
                showSettings = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "gearshape.fill")
                        .foregroundStyle(.blue)
                    Text("Open Full Settings")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(cardBackground)
    }

    private var signOutCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Session")
            Button(role: .destructive) {
                showLogoutConfirm = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("Sign Out")
                        .fontWeight(.semibold)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)

            Text("Signing out returns you to the welcome screen. Encrypted logs remain on device and in iCloud.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(18)
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
            .fill(Color(.secondarySystemGroupedBackground))
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
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
            Text(label)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(tint.opacity(0.12), in: Capsule())
    }

    private func settingsMiniTile(title: String, subtitle: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
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
        case .facebook: "person.2.fill"
        case .passkey:  "key.fill"
        }
    }

    private func providerColor(_ p: AuthProvider) -> Color {
        switch p {
        case .apple:    .primary
        case .google:   Color(red: 0.26, green: 0.52, blue: 0.96)
        case .facebook: Color(red: 0.23, green: 0.35, blue: 0.60)
        case .passkey:  .purple
        }
    }
}
