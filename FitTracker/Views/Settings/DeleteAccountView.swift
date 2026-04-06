// Views/Settings/DeleteAccountView.swift
// GDPR Article 17 — Account deletion with 30-day grace period.
// Two states: default (request deletion) and grace period active (cancel/countdown).

import SwiftUI
import LocalAuthentication

struct DeleteAccountView: View {
    @EnvironmentObject private var deletionService: AccountDeletionService
    @EnvironmentObject private var analytics: AnalyticsService
    @State private var confirmToggle = false
    @State private var showAuthError = false
    @State private var authErrorMessage = ""

    var body: some View {
        SettingsDetailScaffold(
            title: "Delete Account",
            subtitle: deletionService.isDeletionPending
                ? "Your account is scheduled for deletion."
                : "Permanently delete your account and all data."
        ) {
            if deletionService.isDeletionPending {
                gracePeriodView
            } else {
                defaultView
            }
        }
        .navigationTitle("Delete Account")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Authentication Failed", isPresented: $showAuthError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(authErrorMessage)
        }
        .task {
            deletionService.checkGracePeriod()
        }
        .analyticsScreen(AnalyticsScreen.deleteAccount)
    }

    // MARK: - Default State (request deletion)

    private var defaultView: some View {
        VStack(spacing: AppSpacing.medium) {
            SettingsSectionCard(title: "Warning", eyebrow: "Permanent") {
                SettingsSupportingText("Deleting your account will permanently remove all data from all devices and cloud storage:\n\n• All training logs and PRs\n• All nutrition and meal data\n• All biometric records\n• Your profile and settings\n• All synced cloud data\n• Cardio session photos\n\nThis action cannot be undone after the grace period expires.")
            }

            SettingsSectionCard(title: "Grace Period", eyebrow: "30 Days") {
                SettingsSupportingText("After confirming, your account will be scheduled for deletion in 30 days. You can cancel anytime during this period and your data will be fully restored.")
            }

            SettingsSectionCard(title: "Confirm", eyebrow: "Required") {
                Toggle(isOn: $confirmToggle) {
                    VStack(alignment: .leading, spacing: AppSpacing.micro) {
                        Text("I understand")
                            .font(AppText.body)
                            .foregroundStyle(AppColor.Text.primary)
                        Text("All my data will be permanently deleted after 30 days.")
                            .font(AppText.caption)
                            .foregroundStyle(AppColor.Text.tertiary)
                    }
                }
                .tint(AppColor.Status.error)
            }

            Button(role: .destructive) {
                Task { await authenticateAndDelete() }
            } label: {
                Text("Delete My Account")
                    .font(AppText.button)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.small)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColor.Status.error)
            .disabled(!confirmToggle)
            .padding(.horizontal, AppSpacing.small)

            Text("Requires Face ID to confirm.")
                .font(AppText.caption)
                .foregroundStyle(AppColor.Text.tertiary)
        }
    }

    // MARK: - Grace Period Active

    private var gracePeriodView: some View {
        VStack(spacing: AppSpacing.medium) {
            SettingsSectionCard(title: "Deletion Scheduled", eyebrow: "Pending") {
                VStack(alignment: .leading, spacing: AppSpacing.small) {
                    Text("Your account will be permanently deleted on:")
                        .font(AppText.bodyRegular)
                        .foregroundStyle(AppColor.Text.secondary)

                    if let dateStr = deletionService.deletionDateFormatted {
                        Text(dateStr)
                            .font(AppText.titleStrong)
                            .foregroundStyle(AppColor.Text.primary)
                    }

                    if let days = deletionService.daysRemaining {
                        Text("\(days) days remaining")
                            .font(AppText.body)
                            .foregroundStyle(AppColor.Status.warning)
                    }

                    SettingsSupportingText("All data will be removed from all devices and cloud storage.")
                }
            }

            Button {
                deletionService.cancelDeletion()
            } label: {
                Text("Cancel Deletion")
                    .font(AppText.button)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.small)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColor.Brand.primary)
            .padding(.horizontal, AppSpacing.small)

            Text("Changed your mind? Cancelling will fully restore your account and all data.")
                .font(AppText.caption)
                .foregroundStyle(AppColor.Text.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.medium)
        }
    }

    // MARK: - Authentication

    private func authenticateAndDelete() async {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            // Fallback: no biometrics available — proceed with confirmation only
            await deletionService.requestDeletion(authMethod: "confirmation")
            return
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Confirm account deletion"
            )
            if success {
                await deletionService.requestDeletion(authMethod: "biometric")
            }
        } catch {
            authErrorMessage = error.localizedDescription
            showAuthError = true
        }
    }
}
