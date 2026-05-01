// SetNewPasswordView.swift — auth-polish-v2 A3
// Per ux-spec.md §5.3. Pushed at the RootView level after the recovery
// deep-link returns into the app (wired in A4 by observing
// signIn.pendingPasswordResetURL).

import SwiftUI

struct SetNewPasswordView: View {
    @EnvironmentObject private var signIn: SignInService
    @EnvironmentObject private var analytics: AnalyticsService

    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""

    /// Called after a successful password update. Parent transitions to Home
    /// (the user is already signed in via the recovery session).
    let onSuccess: () -> Void

    var body: some View {
        AuthScaffold {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                Text("Set new password")
                    .font(AppText.pageTitle)
                    .foregroundStyle(AppColor.Text.inversePrimary)
                    .accessibilityLabel("Set new password")
                    .accessibilityAddTraits(.isHeader)

                AuthFormCard {
                    VStack(alignment: .leading, spacing: AppSpacing.small) {
                        PasswordRulesSecureField(
                            placeholder: "New password",
                            text: $newPassword,
                            textContentType: .newPassword
                        )
                        .frame(height: 48)
                        .accessibilityLabel("New password")
                        .accessibilityHint("Enter your new password. Must be 6 to 14 characters with at least one uppercase letter, one number, and one special character")

                        PasswordRulesSecureField(
                            placeholder: "Confirm new password",
                            text: $confirmPassword,
                            textContentType: .newPassword
                        )
                        .frame(height: 48)
                        .accessibilityLabel("Confirm new password")
                        .accessibilityHint("Re-enter your new password to confirm it matches")

                        if showsMismatch {
                            Text("Passwords don't match")
                                .font(AppText.subheading)
                                .foregroundStyle(AppColor.Status.error)
                                .accessibilityLabel("Passwords don't match")
                        }
                    }
                }

                rulesView

                Button {
                    submit()
                } label: {
                    if signIn.isLoading {
                        ProgressView()
                            .tint(AppColor.Text.inversePrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.small)
                    } else {
                        Text("Update password")
                    }
                }
                .buttonStyle(AuthPrimaryButtonStyle())
                .disabled(!canSubmit || signIn.isLoading)
                .accessibilityLabel("Update password")
                .accessibilityHint("Sets your new password and signs you in")

                Spacer(minLength: AppSpacing.large)
            }
        }
    }

    private var rulesView: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {
            ruleRow(label: "6 to 14 characters", satisfied: lengthOk)
            ruleRow(label: "One uppercase letter", satisfied: hasUppercase)
            ruleRow(label: "One number", satisfied: hasNumber)
            ruleRow(label: "One special character", satisfied: hasSpecial)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Password requirements")
    }

    private func ruleRow(label: String, satisfied: Bool) -> some View {
        HStack(spacing: AppSpacing.xxSmall) {
            Image(systemName: satisfied ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(ruleColor(satisfied: satisfied))
            Text(label)
                .font(AppText.subheading)
                .foregroundStyle(ruleColor(satisfied: satisfied))
        }
        .accessibilityLabel(label)
        .accessibilityValue(satisfied ? "met" : "not met")
    }

    private func ruleColor(satisfied: Bool) -> Color {
        if satisfied { return AppColor.Status.success }
        return newPassword.isEmpty ? AppColor.Text.tertiary : AppColor.Status.error
    }

    private func submit() {
        guard canSubmit, !signIn.isLoading else { return }
        // Snapshot before SignInService clears it on success.
        let requestedAt = signIn.passwordResetRequestedAt
        Task {
            await signIn.setNewPassword(newPassword)
            if signIn.authErrorMessage == nil {
                if let requestedAt {
                    let elapsed = Int(Date().timeIntervalSince(requestedAt))
                    analytics.logAuthPasswordResetCompleted(
                        timeToCompleteSeconds: max(0, min(elapsed, 86_400))
                    )
                }
                onSuccess()
            }
        }
    }

    private var lengthOk: Bool { (6...14).contains(newPassword.count) }
    private var hasUppercase: Bool { newPassword.contains(where: { $0.isUppercase }) }
    private var hasNumber: Bool { newPassword.contains(where: { $0.isNumber }) }
    private var hasSpecial: Bool {
        let specials = "-!@#$%^&*()_=+[]{};:,.?/"
        return newPassword.contains(where: { specials.contains($0) })
    }
    private var rulesValid: Bool { lengthOk && hasUppercase && hasNumber && hasSpecial }
    private var passwordsMatch: Bool { !confirmPassword.isEmpty && newPassword == confirmPassword }
    private var showsMismatch: Bool { !confirmPassword.isEmpty && !passwordsMatch }
    private var canSubmit: Bool { rulesValid && passwordsMatch }
}
