// ForgotPasswordCooldownView.swift — auth-polish-v2 A3
// Per ux-spec.md §5.2. Second view in the forgot-password sheet flow.
// Pushed onto the sheet's NavigationStack after the user submits the email.

import SwiftUI

struct ForgotPasswordCooldownView: View {
    @EnvironmentObject private var signIn: SignInService

    let email: String

    /// Called when the user taps "Use a different email" — parent pops back
    /// to ForgotPasswordRequestView with the field cleared.
    let onUseDifferentEmail: () -> Void

    var body: some View {
        AuthScaffold {
            VStack(spacing: AppSpacing.medium) {
                Image(systemName: "checkmark.circle.fill")
                    .font(AppText.iconMedium)
                    .foregroundStyle(AppColor.Status.success)
                    .accessibilityHidden(true)

                Text("Check your inbox")
                    .font(AppText.titleMedium)
                    .foregroundStyle(AppColor.Text.inversePrimary)
                    .accessibilityLabel("Check your inbox")
                    .accessibilityAddTraits(.isHeader)

                (Text("We sent a link to ") + Text(email).bold())
                    .font(AppText.body)
                    .foregroundStyle(AppColor.Text.inverseSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("We sent a link to \(email)")

                VStack(spacing: AppSpacing.small) {
                    Button {
                        Task {
                            await signIn.requestPasswordReset(email: email)
                        }
                    } label: {
                        if signIn.isLoading {
                            ProgressView()
                                .tint(AppColor.Text.inversePrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, AppSpacing.small)
                        } else if cooldownActive {
                            Text("Resend email (in \(remainingSeconds)s)")
                        } else {
                            Text("Resend email")
                        }
                    }
                    .buttonStyle(AuthPrimaryButtonStyle())
                    .disabled(cooldownActive || signIn.isLoading)
                    .opacity(cooldownActive ? 0.6 : 1.0)
                    .frame(minHeight: 44)
                    .accessibilityLabel(
                        cooldownActive
                            ? "Resend reset email, available in \(remainingSeconds) seconds"
                            : "Resend reset email"
                    )
                    .accessibilityHint("Sends a new password reset link")

                    Button {
                        onUseDifferentEmail()
                    } label: {
                        Text("Use a different email")
                            .font(AppText.subheading)
                            .foregroundStyle(AppColor.Text.inverseSecondary)
                            .underline()
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                    .accessibilityLabel("Use a different email address")
                    .accessibilityHint("Returns to email entry with a blank field")
                }

                Spacer(minLength: AppSpacing.large)
            }
            .padding(.top, AppSpacing.large)
        }
    }

    private var remainingSeconds: Int {
        Int(signIn.passwordResetCooldownRemaining.rounded(.up))
    }

    private var cooldownActive: Bool {
        signIn.passwordResetCooldownRemaining > 0
    }
}
