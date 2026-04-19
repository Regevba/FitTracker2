// FitTracker/Views/Settings/v2/Screens/AccountSecuritySettingsScreen.swift
// Settings v2 — Account & Security detail screen.
// Extracted from SettingsView.swift in Audit M-1a (UI-002 decomposition).

import SwiftUI
import LocalAuthentication

struct AccountSecuritySettingsScreen: View {
    @EnvironmentObject private var signIn: SignInService
    @EnvironmentObject private var dataStore: EncryptedDataStore
    @EnvironmentObject private var cloudSync: CloudKitSyncService
    @EnvironmentObject private var supabaseSync: SupabaseSyncService
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var biometricAuth: AuthManager
    @EnvironmentObject private var analytics: AnalyticsService

    var body: some View {
        SettingsDetailScaffold(
            title: SettingsCategory.accountSecurity.title,
            subtitle: "Manage how your account opens, how credentials are stored, and which protections are active on this device."
        ) {
            SettingsSectionCard(title: "Account Identity", eyebrow: "Account") {
                SettingsValueRow(title: "Sign-In Method", value: signIn.currentSession?.provider.rawValue ?? "Unavailable")
                SettingsValueRow(title: "Name", value: signIn.currentSession?.displayName ?? "—")
                SettingsValueRow(title: "Email", value: signIn.currentSession?.email ?? "—")
                SettingsValueRow(title: "Phone", value: signIn.currentSession?.phone ?? "—")
            }

            SettingsSectionCard(title: "Access on Reopen", eyebrow: "Security") {
                Toggle(isOn: $settings.requireBiometricUnlockOnReopen) {
                    VStack(alignment: .leading, spacing: AppSpacing.xxxSmall) {
                        Text("Require \(biometricUnlockLabel) on Reopen")
                            .font(AppText.button)
                            .foregroundStyle(AppColor.Text.primary)
                        Text("When off, \(AppBrand.name) stays unlocked while the app remains in memory.")
                            .font(AppText.subheading)
                            .foregroundStyle(AppColor.Text.secondary)
                    }
                }
                .tint(AppColor.Accent.primary)
                .disabled(!biometricsAvailable)

                if !biometricsAvailable {
                    SettingsSupportingText("Biometric unlock is unavailable on this device. Set up Face ID or Touch ID to protect reopen access.")
                }

                Button {
                    signIn.addPasskeyForCurrentUser()
                } label: {
                    SettingsActionLabel(
                        title: signIn.currentSession?.provider == .passkey ? "Create Another Passkey" : "Add Passkey",
                        subtitle: signIn.isPasskeyConfigured ? "Register a passkey for quick passwordless sign in." : "Passkey setup requires a valid relying party configuration.",
                        icon: "key.fill",
                        tint: AppColor.Accent.sleep,
                        trailing: signIn.isLoading ? .progress : .chevron
                    )
                }
                .buttonStyle(.plain)
                .disabled(signIn.isLoading || !signIn.isPasskeyConfigured)
            }

            SettingsSectionCard(title: "Protection Summary", eyebrow: "Security") {
                SettingsValueRow(title: "Encryption", value: "AES-256-GCM + ChaCha20-Poly1305")
                SettingsValueRow(title: "Key Storage", value: "Keychain with biometric protection")
                SettingsValueRow(title: "Cloud Storage", value: "Encrypted locally before upload")
                SettingsValueRow(title: "Data Protection", value: "NSFileProtectionCompleteUnlessOpen")
            }

            SettingsSectionCard(title: "Account", eyebrow: "GDPR") {
                NavigationLink {
                    DeleteAccountView()
                        .environmentObject(AccountDeletionService(
                            dataStore: dataStore,
                            cloudSync: cloudSync,
                            supabaseSync: supabaseSync,
                            signIn: signIn,
                            analytics: analytics
                        ))
                        .environmentObject(analytics)
                } label: {
                    SettingsActionLabel(
                        title: "Delete Account",
                        subtitle: "Schedule permanent deletion of your account and all data.",
                        icon: "trash.fill",
                        tint: AppColor.Status.error
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle(SettingsCategory.accountSecurity.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var biometricsAvailable: Bool {
        let ctx = LAContext()
        var error: NSError?
        return ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    private var biometricUnlockLabel: String {
        let ctx = LAContext()
        var error: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return biometricAuth.biometricName
        }
        switch ctx.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        default: return "Biometric Unlock"
        }
    }
}
