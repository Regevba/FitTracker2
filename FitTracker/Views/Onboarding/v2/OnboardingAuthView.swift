// FitTracker/Views/Onboarding/v2/OnboardingAuthView.swift
// Onboarding Step 5 — Account creation embedded in onboarding flow.
// Offers Email, Google, Apple sign-in. "Already have an account? Log In" shortcut.
// Uses onboarding visual style (not AuthHubView dark style).

import SwiftUI
import AuthenticationServices

struct OnboardingAuthView: View {
    let onAuthenticated: () -> Void
    let onLogin: () -> Void

    @EnvironmentObject private var signIn: SignInService
    @EnvironmentObject private var analytics: AnalyticsService
    @State private var showEmailForm = false
    @State private var showLoginForm = false

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.large) {
                Spacer().frame(height: AppSpacing.xLarge)

                // Hero icon
                ZStack {
                    Circle()
                        .fill(AppColor.Brand.coolSoft.opacity(0.5))
                        .frame(width: 120, height: 120)

                    Image(systemName: "person.badge.plus")
                        .font(AppText.iconHero)
                        .foregroundStyle(AppColor.Brand.secondary)
                }

                // Title + subtitle
                VStack(spacing: AppSpacing.xSmall) {
                    Text("Save your progress")
                        .font(AppText.titleStrong)
                        .foregroundStyle(AppColor.Text.primary)
                        .multilineTextAlignment(.center)

                    Text("Create an account to keep your data safe and synced across devices.")
                        .font(AppText.bodyRegular)
                        .foregroundStyle(AppColor.Text.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.small)
                }

                // Error banner
                if let error = signIn.authErrorMessage {
                    HStack(spacing: AppSpacing.xxSmall) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(AppColor.Status.error)
                        Text(error)
                            .font(AppText.subheading)
                            .foregroundStyle(AppColor.Text.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, AppSpacing.xSmall)
                    .padding(.vertical, AppSpacing.xSmall)
                    .background(AppColor.Surface.primary, in: RoundedRectangle(cornerRadius: AppRadius.medium))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.medium)
                            .stroke(AppColor.Status.error.opacity(0.18), lineWidth: 1)
                    )
                    .padding(.horizontal, AppSpacing.small)
                }

                if showEmailForm {
                    emailRegistrationForm
                } else if showLoginForm {
                    emailLoginForm
                } else {
                    providerButtons
                }

                // Login link
                if !showLoginForm && !showEmailForm {
                    Button {
                        showLoginForm = true
                        showEmailForm = false
                    } label: {
                        HStack(spacing: AppSpacing.xxxSmall) {
                            Text("Already have an account?")
                                .foregroundStyle(AppColor.Text.secondary)
                            Text("Log In")
                                .foregroundStyle(AppColor.Brand.primary)
                                .fontWeight(.semibold)
                        }
                        .font(AppText.body)
                    }
                    .buttonStyle(.plain)
                }

                Spacer().frame(height: AppSpacing.xLarge)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Color.clear)
        .onChange(of: signIn.activeSession) { _, session in
            guard session != nil else { return }
            if showLoginForm {
                onLogin()
            } else {
                onAuthenticated()
            }
        }
        .onAppear {
            analytics.logScreenView(AnalyticsScreen.onboardingAuth, screenClass: "OnboardingAuthView")
            analytics.logOnboardingStepViewed(stepIndex: 5, stepName: "auth")
        }
    }

    // MARK: - Provider Buttons

    private var providerButtons: some View {
        VStack(spacing: AppSpacing.xSmall) {
            // Email
            Button {
                showEmailForm = true
                analytics.logOnboardingAuthMethodSelected(method: "email")
            } label: {
                HStack(spacing: AppSpacing.xSmall) {
                    Image(systemName: "envelope.fill")
                        .font(AppText.sectionTitle)
                        .foregroundStyle(.blue)
                        .frame(width: 26)
                    VStack(alignment: .leading, spacing: AppSpacing.micro) {
                        Text("Continue with Email")
                            .font(AppText.button)
                            .foregroundStyle(AppColor.Text.primary)
                        Text("Register with your email address")
                            .font(AppText.subheading)
                            .foregroundStyle(AppColor.Text.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColor.Text.secondary)
                }
                .padding(.horizontal, AppSpacing.small)
                .padding(.vertical, AppSpacing.small)
                .background(AppColor.Surface.elevated, in: RoundedRectangle(cornerRadius: AppRadius.medium))
                .overlay(RoundedRectangle(cornerRadius: AppRadius.medium).stroke(AppColor.Border.subtle, lineWidth: 1))
            }
            .buttonStyle(.plain)

            // Google
            if signIn.isGoogleAuthAvailable {
                Button {
                    analytics.logOnboardingAuthMethodSelected(method: "google")
                    signIn.signInWithGoogle()
                } label: {
                    HStack(spacing: AppSpacing.xSmall) {
                        ZStack {
                            Circle().fill(Color.white).frame(width: 26, height: 26)
                            Text("G").font(AppText.callout).foregroundStyle(AppColor.Brand.secondary)
                        }
                        VStack(alignment: .leading, spacing: AppSpacing.micro) {
                            Text("Continue with Google")
                                .font(AppText.button)
                                .foregroundStyle(AppColor.Text.primary)
                            Text("Use your Google account")
                                .font(AppText.subheading)
                                .foregroundStyle(AppColor.Text.tertiary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppColor.Text.secondary)
                    }
                    .padding(.horizontal, AppSpacing.small)
                    .padding(.vertical, AppSpacing.small)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: AppRadius.medium))
                    .overlay(RoundedRectangle(cornerRadius: AppRadius.medium).stroke(AppColor.Border.hairline, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            // Apple
            Button {
                analytics.logOnboardingAuthMethodSelected(method: "apple")
                signIn.signInWithApple()
            } label: {
                HStack(spacing: AppSpacing.xSmall) {
                    Image(systemName: "apple.logo")
                        .font(AppText.sectionTitle)
                        .foregroundStyle(.white)
                        .frame(width: 26)
                    VStack(alignment: .leading, spacing: AppSpacing.micro) {
                        Text("Continue with Apple")
                            .font(AppText.button)
                            .foregroundStyle(.white)
                        Text("Use your Apple Account")
                            .font(AppText.subheading)
                            .foregroundStyle(AppColor.Text.inverseSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColor.Text.inverseSecondary)
                }
                .padding(.horizontal, AppSpacing.small)
                .padding(.vertical, AppSpacing.small)
                .background(AppColor.Surface.inverse, in: RoundedRectangle(cornerRadius: AppRadius.medium))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppSpacing.small)
    }

    // MARK: - Email Registration Form (inline)

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var formErrors: [String: String] = [:]

    private var emailRegistrationForm: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
            Button {
                showEmailForm = false
            } label: {
                HStack(spacing: AppSpacing.xxSmall) {
                    Image(systemName: "chevron.left")
                    Text("Back to sign-in options")
                }
                .font(AppText.subheading)
                .foregroundStyle(AppColor.Text.secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                TextField("First name", text: $firstName)
                    .textContentType(.givenName)
                if let err = formErrors["firstName"] { Text(err).font(AppText.subheading).foregroundStyle(AppColor.Status.error) }

                TextField("Last name", text: $lastName)
                    .textContentType(.familyName)
                if let err = formErrors["lastName"] { Text(err).font(AppText.subheading).foregroundStyle(AppColor.Status.error) }

                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if let err = formErrors["email"] { Text(err).font(AppText.subheading).foregroundStyle(AppColor.Status.error) }

                SecureField("Password", text: $password)
                    .textContentType(.newPassword)
                if let err = formErrors["password"] { Text(err).font(AppText.subheading).foregroundStyle(AppColor.Status.error) }

                SecureField("Confirm password", text: $confirmPassword)
                    .textContentType(.newPassword)
                if let err = formErrors["confirmPassword"] { Text(err).font(AppText.subheading).foregroundStyle(AppColor.Status.error) }
            }
            .font(AppText.body)
            .padding(AppSpacing.large)
            .background(AppColor.Surface.elevated, in: RoundedRectangle(cornerRadius: AppRadius.sheet))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.sheet).stroke(AppColor.Border.subtle, lineWidth: 1))

            Button(signIn.isLoading ? "Registering..." : "Register") {
                formErrors = validateForm()
                guard formErrors.isEmpty else { return }
                Task {
                    await signIn.startEmailRegistration(
                        PendingEmailRegistration(
                            firstName: firstName.trimmingCharacters(in: .whitespaces),
                            lastName: lastName.trimmingCharacters(in: .whitespaces),
                            birthday: Date(),
                            email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                            password: password
                        )
                    )
                }
            }
            .font(AppText.button)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.small)
            .background(AppColor.Surface.inverse.opacity(0.82), in: RoundedRectangle(cornerRadius: AppRadius.button))
            .buttonStyle(.plain)
            .disabled(signIn.isLoading)
        }
        .padding(.horizontal, AppSpacing.small)
    }

    // MARK: - Email Login Form (inline)

    @State private var loginEmail = ""
    @State private var loginPassword = ""

    private var emailLoginForm: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
            Button {
                showLoginForm = false
            } label: {
                HStack(spacing: AppSpacing.xxSmall) {
                    Image(systemName: "chevron.left")
                    Text("Back to sign-in options")
                }
                .font(AppText.subheading)
                .foregroundStyle(AppColor.Text.secondary)
            }
            .buttonStyle(.plain)

            Text("Log in to FitMe")
                .font(AppText.hero)
                .foregroundStyle(AppColor.Text.primary)

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                TextField("Email", text: $loginEmail)
                    .textContentType(.username)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                SecureField("Password", text: $loginPassword)
                    .textContentType(.password)
            }
            .font(AppText.body)
            .padding(AppSpacing.large)
            .background(AppColor.Surface.elevated, in: RoundedRectangle(cornerRadius: AppRadius.sheet))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.sheet).stroke(AppColor.Border.subtle, lineWidth: 1))

            Button(signIn.isLoading ? "Logging in..." : "Log In") {
                guard !loginEmail.isEmpty, !loginPassword.isEmpty else { return }
                Task {
                    await signIn.signInWithEmail(
                        email: loginEmail.trimmingCharacters(in: .whitespacesAndNewlines),
                        password: loginPassword
                    )
                }
            }
            .font(AppText.button)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.small)
            .background(AppColor.Surface.inverse.opacity(0.82), in: RoundedRectangle(cornerRadius: AppRadius.button))
            .buttonStyle(.plain)
            .disabled(signIn.isLoading)
        }
        .padding(.horizontal, AppSpacing.small)
    }

    // MARK: - Validation

    private func validateForm() -> [String: String] {
        var errors: [String: String] = [:]
        if firstName.trimmingCharacters(in: .whitespaces).isEmpty { errors["firstName"] = "First name is required" }
        if lastName.trimmingCharacters(in: .whitespaces).isEmpty { errors["lastName"] = "Last name is required" }
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedEmail.isEmpty || !trimmedEmail.contains("@") { errors["email"] = "Enter a valid email" }
        if password.count < 6 { errors["password"] = "Password must be at least 6 characters" }
        if password != confirmPassword { errors["confirmPassword"] = "Passwords don't match" }
        return errors
    }
}
