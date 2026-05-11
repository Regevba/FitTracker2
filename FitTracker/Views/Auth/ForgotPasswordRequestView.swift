// ForgotPasswordRequestView.swift — auth-polish-v2 A3
// Per ux-spec.md §5.1. First view in the forgot-password sheet flow.
// Presented as a sheet from EmailLoginView (wired in A4).

import SwiftUI

struct ForgotPasswordRequestView: View {
    @EnvironmentObject private var signIn: SignInService
    @EnvironmentObject private var analytics: AnalyticsService
    @Environment(\.dismiss) private var dismiss

    @State private var email: String

    /// Called after a successful reset request. Parent navigates to
    /// ForgotPasswordCooldownView with the email.
    let onSent: (String) -> Void

    init(initialEmail: String = "", onSent: @escaping (String) -> Void) {
        self._email = State(initialValue: initialEmail)
        self.onSent = onSent
    }

    var body: some View {
        AuthScaffold {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                Text("Forgot password?")
                    .font(AppText.pageTitle)
                    .foregroundStyle(AppColor.Text.inversePrimary)
                    .accessibilityLabel("Forgot password")
                    .accessibilityAddTraits(.isHeader)

                Text("Enter your email and we'll send a reset link.")
                    .font(AppText.body)
                    .foregroundStyle(AppColor.Text.inverseSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                AuthFormCard {
                    TextField("your@email.com", text: $email)
                        .font(AppText.body)
                        .foregroundStyle(AppColor.Text.primary)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .submitLabel(.send)
                        .onSubmit { submit() }
                        .accessibilityLabel("Email address")
                        .accessibilityHint("Enter the email associated with your FitMe account")
                }

                Button {
                    submit()
                } label: {
                    if signIn.isLoading {
                        ProgressView()
                            .tint(AppColor.Text.inversePrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.small)
                            .accessibilityLabel("Sending reset link, please wait")
                    } else {
                        Text("Send reset link")
                    }
                }
                .buttonStyle(AuthPrimaryButtonStyle())
                .disabled(!isEmailValid || signIn.isLoading)
                .accessibilityLabel(
                    isEmailValid
                        ? "Send reset link"
                        : "Send reset link, enter an email to continue"
                )
                .accessibilityHint("Sends a password reset link to your email address")

                Spacer(minLength: AppSpacing.large)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: AppSpacing.xxSmall) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(AppText.subheading)
                    .foregroundStyle(AppColor.Text.inversePrimary)
                }
                .frame(minHeight: AppSize.tapTarget)
                .contentShape(Rectangle())
                .accessibilityLabel("Back")
                .accessibilityHint("Returns to sign-in")
            }
        }
    }

    private func submit() {
        guard isEmailValid, !signIn.isLoading else { return }
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            await signIn.requestPasswordReset(email: trimmed)
            if signIn.authErrorMessage == nil {
                analytics.logAuthPasswordResetRequested(emailProvided: !trimmed.isEmpty)
                onSent(trimmed)
            }
        }
    }

    private var isEmailValid: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return trimmed.contains("@") && trimmed.contains(".")
    }
}
