import SwiftUI
import AuthenticationServices
#if os(macOS)
import AppKit
#endif

struct AuthHubView: View {
    @EnvironmentObject private var signIn: SignInService
    @State private var mode: AuthMode = .login
    @State private var registrationForm = EmailRegistrationFormState()
    @State private var loginForm = EmailLoginFormState()
    @State private var passwordResetPrefill: String = ""
    @State private var showPasswordReset = false

    var body: some View {
        NavigationStack(path: $signIn.navigationPath) {
            AuthScaffold(
                content: {
                AuthLandingView(
                    mode: $mode,
                    registrationForm: $registrationForm,
                    loginForm: $loginForm,
                    onForgotPassword: { prefill in
                        passwordResetPrefill = prefill
                        showPasswordReset = true
                    }
                )
                },
                bottomAccessory: {
                    AuthTrustSection()
                        .padding(.horizontal, 18)
                        .padding(.bottom, 10)
                }
            )
            .navigationDestination(for: AuthRoute.self) { route in
                switch route {
                case .emailVerification:
                    AuthScaffold(
                        content: {
                        EmailVerificationView(
                            mode: $mode,
                            registrationForm: $registrationForm
                        )
                        },
                        bottomAccessory: { EmptyView() }
                    )
                default:
                    EmptyView()
                }
            }
            .sheet(isPresented: $showPasswordReset) {
                NavigationStack {
                    AuthScaffold(
                        content: {
                        PasswordResetView(
                            mode: $mode,
                            initialEmail: passwordResetPrefill
                        )
                        },
                        bottomAccessory: { EmptyView() }
                    )
                    .navigationTitle("Reset Password")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showPasswordReset = false }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(AppSheet.standardCornerRadius)
            }
        }
    }
}

private enum AuthMode: String, CaseIterable, Identifiable {
    case login = "Log In"
    case register = "Create Account"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .login:
            return "Welcome back"
        case .register:
            return "Create your account"
        }
    }

    var subtitle: String {
        switch self {
        case .login:
            return "Private training, nutrition, and recovery data protected from the moment you enter."
        case .register:
            return "Set up a secure FitMe account with Apple or email in under a minute."
        }
    }

    var appleButtonTitle: String {
        switch self {
        case .login:
            return "Sign in with Apple"
        case .register:
            return "Continue with Apple"
        }
    }

}

private enum AuthField: Hashable {
    case loginEmail
    case loginPassword
    case registerFirstName
    case registerLastName
    case registerEmail
    case registerPassword
    case registerConfirmPassword
    case resetEmail
}

private struct AuthScaffold<Content: View, BottomAccessory: View>: View {
    @EnvironmentObject private var signIn: SignInService
    let content: Content
    let bottomAccessory: BottomAccessory

    init(
        @ViewBuilder content: () -> Content,
        @ViewBuilder bottomAccessory: () -> BottomAccessory
    ) {
        self.content = content()
        self.bottomAccessory = bottomAccessory()
    }

    var body: some View {
        ZStack {
            AppGradient.screenBackground
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    if let error = signIn.authErrorMessage {
                        AuthBannerView(
                            icon: "exclamationmark.triangle.fill",
                            text: error,
                            tint: .status.error
                        )
                    } else if let status = signIn.statusMessage {
                        AuthBannerView(
                            icon: "checkmark.circle.fill",
                            text: status,
                            tint: .status.success
                        )
                    }

                    content
                }
                .frame(maxWidth: 620)
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomAccessory
        }
        .scrollDismissesKeyboardCompat()
    }
}

private struct AuthLandingView: View {
    @EnvironmentObject private var signIn: SignInService

    @Binding var mode: AuthMode
    @Binding var registrationForm: EmailRegistrationFormState
    @Binding var loginForm: EmailLoginFormState
    var onForgotPassword: (String) -> Void = { _ in }

    @State private var registrationErrors: [String: String] = [:]
    @State private var loginError: String?
    @FocusState private var focusedField: AuthField?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            AuthHeroSection()

            if showQuickReturn {
                QuickReturnSection(
                    passkeyAction: { signIn.signInWithPasskey() }
                )
            }

            VStack(alignment: .leading, spacing: 16) {
                AuthModeSwitcher(mode: $mode)

                ApplePrimaryButton(mode: mode)

                AuthDividerLabel(text: "or use email")

                if mode == .login {
                    EmailLoginSection(
                        form: $loginForm,
                        localError: $loginError,
                        focusedField: $focusedField,
                        onForgotPassword: onForgotPassword
                    )
                } else {
                    EmailRegistrationSection(
                        form: $registrationForm,
                        errors: $registrationErrors,
                        focusedField: $focusedField
                    )
                }
            }
            .padding(.top, showQuickReturn ? 8 : 18)
            .padding(.horizontal, 14)

            AuthFootnote(mode: mode)
        }
        .onChange(of: mode) { _, _ in
            signIn.clearFeedback()
            loginError = nil
            registrationErrors = [:]
            focusedField = nil
        }
        .onChange(of: loginForm.email) { _, _ in
            if loginError != nil {
                loginError = nil
            }
        }
        .onChange(of: loginForm.password) { _, _ in
            if loginError != nil {
                loginError = nil
            }
        }
        .onChange(of: registrationForm) { _, _ in
            if !registrationErrors.isEmpty {
                registrationErrors = [:]
            }
        }
    }

    private var showQuickReturn: Bool {
        signIn.canShowPasskeyLogin
    }
}

private struct AuthHeroSection: View {
    var body: some View {
        Text(AppBrand.name)
            .font(AppText.hero)
            .foregroundStyle(.clear)
            .overlay(
                AppGradient.brand.mask(
                    Text(AppBrand.name)
                        .font(AppText.hero)
                )
            )
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
    }
}

private struct AuthTrustSection: View {
    private let trustItems: [(icon: String, title: String)] = [
        ("lock.shield.fill", "Encrypted on device"),
        ("icloud.fill", "Apple ecosystem ready"),
    ]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(trustItems, id: \.title) { item in
                trustBadge(item)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private func trustBadge(_ item: (icon: String, title: String)) -> some View {
        HStack(spacing: 7) {
            Image(systemName: item.icon)
                .font(AppText.caption)
            Text(item.title)
                .font(AppText.captionStrong)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .foregroundStyle(AppColor.Text.primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .frame(maxWidth: 222)
        .frame(maxWidth: .infinity)
        .background(AppColor.Surface.elevated, in: Capsule())
        .overlay(
            Capsule()
                .stroke(AppColor.Border.hairline, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 5, y: 2)
    }
}

private struct AuthModeSwitcher: View {
    @Binding var mode: AuthMode

    var body: some View {
        HStack(spacing: 10) {
            ForEach(AuthMode.allCases) { currentMode in
                Button {
                    mode = currentMode
                } label: {
                    Text(currentMode.rawValue)
                        .font(AppType.subheading.weight(.semibold))
                        .foregroundStyle(
                            mode == currentMode
                                ? AppColor.Text.primary
                                : AppColor.Text.secondary
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(
                            Capsule(style: .continuous)
                                .fill(mode == currentMode ? AppColor.Surface.elevated.opacity(0.9) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityHint("Switch between login and account creation.")
            }
        }
        .padding(3)
        .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                .stroke(Color.white.opacity(0.20), lineWidth: 1)
        )
    }
}

private struct QuickReturnSection: View {
    let passkeyAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Saved sign-in")
                .font(AppText.captionStrong)
                .foregroundStyle(AppColor.Text.secondary)

            Button(action: passkeyAction) {
                AuthQuickReturnRow(
                    icon: "key.fill",
                    title: "Use Passkey",
                    subtitle: "Sign in with your saved passkey or security key"
                )
            }
            .buttonStyle(AuthCardButtonStyle(baseFill: AppColor.Surface.elevated.opacity(0.84)))
            .accessibilityHint("Sign in with a saved passkey.")
        }
        .padding(.horizontal, 14)
    }
}

private struct ApplePrimaryButton: View {
    @EnvironmentObject private var signIn: SignInService
    let mode: AuthMode

    var body: some View {
        Button(action: { signIn.signInWithApple() }) {
            HStack {
                Image(systemName: "apple.logo")
                    .font(AppText.body)
                Text(mode.appleButtonTitle)
                    .font(AppText.button)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color.black, in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mode.appleButtonTitle)
        .accessibilityHint("Uses your Apple Account for a secure \(mode == .login ? "login" : "account setup").")
    }
}

private struct EmailLoginSection: View {
    @EnvironmentObject private var signIn: SignInService
    @Binding var form: EmailLoginFormState
    @Binding var localError: String?
    let focusedField: FocusState<AuthField?>.Binding
    var onForgotPassword: (String) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AuthTextInput(
                title: "Email",
                text: $form.email,
                keyboard: .emailAddress,
                contentType: .username,
                textInputAutocapitalization: .never,
                submitLabel: .next,
                focusedField: focusedField,
                equals: .loginEmail,
                onSubmitAction: { focusedField.wrappedValue = .loginPassword }
            )

            AuthSecureInput(
                title: "Password",
                text: $form.password,
                contentType: .password,
                submitLabel: .go,
                focusedField: focusedField,
                equals: .loginPassword,
                onSubmitAction: submit
            )

            HStack {
                Spacer()
                Button("Forgot password?") {
                    onForgotPassword(form.normalizedEmail)
                }
                .buttonStyle(.plain)
                .font(AppType.caption.weight(.semibold))
                .foregroundStyle(AppColor.Accent.secondary)
                .accessibilityHint("Open password reset.")
            }

            if let localError {
                AuthInlineError(text: localError)
            }

            Button(signIn.isLoading ? "Logging in..." : "Log In", action: submit)
                .buttonStyle(AuthPrimaryButtonStyle())
                .disabled(signIn.isLoading)
                .accessibilityHint("Log in using your email and password.")
        }
    }

    private func submit() {
        if let error = form.validationError() {
            localError = error
            return
        }

        localError = nil
        signIn.clearFeedback()
        Task {
            await signIn.signInWithEmail(email: form.normalizedEmail, password: form.password)
        }
    }
}

private struct EmailRegistrationSection: View {
    @EnvironmentObject private var signIn: SignInService
    @Binding var form: EmailRegistrationFormState
    @Binding var errors: [String: String]
    let focusedField: FocusState<AuthField?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    AuthTextInput(
                        title: "First name",
                        text: $form.firstName,
                        contentType: .givenName,
                        submitLabel: .next,
                        focusedField: focusedField,
                        equals: .registerFirstName,
                        onSubmitAction: { focusedField.wrappedValue = .registerLastName }
                    )

                    if let error = errors["firstName"] {
                        AuthInlineError(text: error)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    AuthTextInput(
                        title: "Last name",
                        text: $form.lastName,
                        contentType: .familyName,
                        submitLabel: .next,
                        focusedField: focusedField,
                        equals: .registerLastName,
                        onSubmitAction: { focusedField.wrappedValue = .registerEmail }
                    )

                    if let error = errors["lastName"] {
                        AuthInlineError(text: error)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                AuthTextInput(
                    title: "Email",
                    text: $form.email,
                    keyboard: .emailAddress,
                    contentType: .emailAddress,
                    textInputAutocapitalization: .never,
                    submitLabel: .next,
                    focusedField: focusedField,
                    equals: .registerEmail,
                    onSubmitAction: { focusedField.wrappedValue = .registerPassword }
                )

                if let error = errors["email"] {
                    AuthInlineError(text: error)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                AuthSecureInput(
                    title: "Password",
                    text: $form.password,
                    contentType: .newPassword,
                    submitLabel: .next,
                    focusedField: focusedField,
                    equals: .registerPassword,
                    onSubmitAction: { focusedField.wrappedValue = .registerConfirmPassword }
                )

                Text(PasswordRuleEvaluator.guidanceText)
                    .font(AppType.caption)
                    .foregroundStyle(AppColor.Text.secondary)

                if let error = errors["password"] {
                    AuthInlineError(text: error)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                AuthSecureInput(
                    title: "Confirm password",
                    text: $form.confirmPassword,
                    contentType: .newPassword,
                    submitLabel: .go,
                    focusedField: focusedField,
                    equals: .registerConfirmPassword,
                    onSubmitAction: submit
                )

                if let error = errors["confirmPassword"] {
                    AuthInlineError(text: error)
                }
            }

            Button(signIn.isLoading ? "Creating account..." : "Create Account", action: submit)
                .buttonStyle(AuthPrimaryButtonStyle())
                .disabled(signIn.isLoading)
                .accessibilityHint("Create an account with email and continue to verification.")
        }
    }

    private func submit() {
        let currentErrors = form.validationErrors()
        errors = currentErrors

        guard currentErrors.isEmpty else { return }

        signIn.clearFeedback()
        Task {
            await signIn.startEmailRegistration(form.normalizedDraft())
        }
    }
}

private struct EmailVerificationView: View {
    @EnvironmentObject private var signIn: SignInService
    @Binding var mode: AuthMode
    @Binding var registrationForm: EmailRegistrationFormState
    @State private var code = ""
    @State private var localError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            AuthFlowHeader(
                title: "Verify your email",
                subtitle: "Enter the code sent to \(signIn.pendingEmailRegistration?.email ?? registrationForm.email)."
            )

            AuthSurfaceCard {
                VStack(alignment: .leading, spacing: 14) {
                    OTPCodeEntryField(code: $code, digitCount: 5)
                        .accessibilityLabel("Verification code")
                        .accessibilityHint("Enter the 5 digit code from your email.")

                    expiryNote

                    if let localError {
                        AuthInlineError(text: localError)
                    }
                }
            }

            HStack(spacing: 12) {
                Button("Change email") {
                    localError = nil
                    signIn.resetToEntry()
                    mode = .register
                }
                .buttonStyle(AuthSecondaryButtonStyle())
                .accessibilityHint("Go back and edit your email address.")

                Button(signIn.isLoading ? "Sending..." : "Resend code") {
                    localError = nil
                    Task {
                        await signIn.resendEmailRegistrationCode()
                        if let message = signIn.authErrorMessage {
                            localError = message
                        }
                    }
                }
                .buttonStyle(AuthSecondaryButtonStyle())
                .disabled(signIn.isLoading)
                .accessibilityHint("Send a fresh verification code.")
            }

            Button(signIn.isLoading ? "Verifying..." : "Verify Email") {
                let trimmedCode = code.filter(\.isNumber)
                guard trimmedCode.count == 5 else {
                    localError = "Enter the 5-digit code."
                    return
                }

                localError = nil
                Task {
                    await signIn.verifyEmailRegistrationCode(trimmedCode)
                    if let message = signIn.authErrorMessage {
                        localError = message
                    }
                }
            }
            .buttonStyle(AuthPrimaryButtonStyle())
            .disabled(signIn.isLoading)
            .accessibilityHint("Complete account verification.")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var expiryNote: some View {
        if let expiresAt = signIn.pendingEmailChallenge?.expiresAt {
            (
                Text("Code expires in ")
                    .foregroundStyle(AppColor.Text.secondary)
                + Text(expiresAt, style: .timer)
                    .foregroundStyle(AppColor.Text.primary)
                + Text(". AutoFill and paste are supported.")
                    .foregroundStyle(AppColor.Text.secondary)
            )
            .font(AppType.subheading)
        }
        else {
            Text("AutoFill and paste are supported.")
                .font(AppType.subheading)
                .foregroundStyle(AppColor.Text.secondary)
        }
    }
}

private struct PasswordResetView: View {
    @EnvironmentObject private var signIn: SignInService
    @Binding var mode: AuthMode
    let initialEmail: String

    @State private var email = ""
    @State private var localError: String?
    @FocusState private var focusedField: AuthField?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            AuthFlowHeader(
                title: "Reset your password",
                subtitle: "We’ll send a reset link if the email belongs to an existing account."
            )

            AuthSurfaceCard {
                VStack(alignment: .leading, spacing: 14) {
                    AuthTextInput(
                        title: "Email",
                        text: $email,
                        keyboard: .emailAddress,
                        contentType: .emailAddress,
                        textInputAutocapitalization: .never,
                        submitLabel: .go,
                        focusedField: $focusedField,
                        equals: .resetEmail,
                        onSubmitAction: sendReset
                    )

                    if let localError {
                        AuthInlineError(text: localError)
                    }
                }
            }

            HStack(spacing: 12) {
                Button("Back to login") {
                    localError = nil
                    mode = .login
                    signIn.resetToEntry()
                }
                .buttonStyle(AuthSecondaryButtonStyle())

                Button(signIn.isLoading ? "Sending..." : "Send Reset Link", action: sendReset)
                    .buttonStyle(AuthPrimaryButtonStyle())
                    .disabled(signIn.isLoading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            if email.isEmpty {
                email = initialEmail
            }
            focusedField = .resetEmail
        }
    }

    private func sendReset() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmedEmail.isEmpty else {
            localError = "Enter your email address."
            return
        }
        guard AuthInputValidator.isValidEmail(trimmedEmail) else {
            localError = "Enter a valid email address."
            return
        }

        localError = nil
        Task {
            await signIn.requestPasswordReset(email: trimmedEmail)
            if let message = signIn.authErrorMessage {
                localError = message
            } else {
                mode = .login
                signIn.resetToEntry()
            }
        }
    }
}

private struct AuthFlowHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(AppText.pageTitle)
                .foregroundStyle(AppColor.Text.primary)

            Text(subtitle)
                .font(AppType.body)
                .foregroundStyle(AppColor.Text.secondary)
        }
    }
}

private struct AuthSurfaceCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        AppCard(tone: .elevated, contentPadding: 18) {
            content
        }
    }
}

private struct AuthBannerView: View {
    let icon: String
    let text: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(tint)

            Text(text)
                .font(AppType.subheading)
                .foregroundStyle(AppColor.Text.primary)

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(AppColor.Surface.elevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct AuthQuickReturnRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(AppText.callout)
                .foregroundStyle(AppColor.Accent.recovery)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(AppText.callout)
                    .foregroundStyle(AppColor.Text.primary)
                Text(subtitle)
                    .font(AppType.caption)
                    .foregroundStyle(AppColor.Text.secondary)
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(AppText.captionStrong)
                .foregroundStyle(AppColor.Text.tertiary)
        }
    }
}

private struct AuthDividerLabel: View {
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(AppColor.Border.strong)
                .frame(height: 1)

            Text(text.uppercased())
                .font(AppText.eyebrow)
                .foregroundStyle(AppColor.Text.tertiary)

            Rectangle()
                .fill(AppColor.Border.strong)
                .frame(height: 1)
        }
    }
}

private struct AuthTextInput: View {
    let title: String
    @Binding var text: String
    var keyboard: UIKeyboardTypeCompat = .default
    var contentType: AuthTextContentType?
    var textInputAutocapitalization: TextInputAutocapitalization = .words
    var submitLabel: SubmitLabel = .next
    var focusedField: FocusState<AuthField?>.Binding? = nil
    var equals: AuthField? = nil
    var onSubmitAction: (() -> Void)? = nil

    var body: some View {
        AppInputShell {
            Group {
                if let focusedField, let equals {
                    TextField(title, text: $text)
                        .focused(focusedField, equals: equals)
                        .onSubmit { onSubmitAction?() }
                } else {
                    TextField(title, text: $text)
                        .onSubmit { onSubmitAction?() }
                }
            }
            .authTextInputAutocapitalization(textInputAutocapitalization)
            .authAutocorrectionDisabled()
            .font(AppText.body)
            .foregroundStyle(AppColor.Text.primary)
            .authKeyboardType(keyboard)
            .authTextContentType(contentType)
            .submitLabel(submitLabel)
        }
        .accessibilityLabel(title)
    }
}

private struct AuthSecureInput: View {
    let title: String
    @Binding var text: String
    var contentType: AuthTextContentType?
    var submitLabel: SubmitLabel = .next
    var focusedField: FocusState<AuthField?>.Binding? = nil
    var equals: AuthField? = nil
    var onSubmitAction: (() -> Void)? = nil
    @State private var isRevealed = false

    var body: some View {
        AppInputShell {
            Group {
                if isRevealed {
                    secureInputField(revealed: true)
                } else {
                    secureInputField(revealed: false)
                }
            }

            Button {
                withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                    isRevealed.toggle()
                }
            } label: {
                Image(systemName: isRevealed ? "eye.slash.fill" : "eye.fill")
                    .font(AppText.callout)
                    .foregroundStyle(AppColor.Accent.secondary)
                    .frame(width: 30, height: 30)
                    .background(AppColor.Surface.primary, in: Circle())
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.bounce, value: isRevealed)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isRevealed ? "Hide password" : "Show password")
        }
        .accessibilityLabel(title)
    }

    @ViewBuilder
    private func secureInputField(revealed: Bool) -> some View {
        Group {
            if revealed {
                if let focusedField, let equals {
                    TextField(title, text: $text)
                        .focused(focusedField, equals: equals)
                        .onSubmit { onSubmitAction?() }
                } else {
                    TextField(title, text: $text)
                        .onSubmit { onSubmitAction?() }
                }
            } else {
                if let focusedField, let equals {
                    SecureField(title, text: $text)
                        .focused(focusedField, equals: equals)
                        .onSubmit { onSubmitAction?() }
                } else {
                    SecureField(title, text: $text)
                        .onSubmit { onSubmitAction?() }
                }
            }
        }
        .authTextInputAutocapitalization(.never)
        .authAutocorrectionDisabled()
        .font(AppText.body)
        .foregroundStyle(AppColor.Text.primary)
        .authTextContentType(contentType)
        .submitLabel(submitLabel)
    }
}

private struct AuthInlineError: View {
    let text: String

    var body: some View {
        Text(text)
            .font(AppText.subheading)
            .foregroundStyle(AppColor.Status.error)
            .accessibilityLabel("Error: \(text)")
    }
}

private struct AuthFootnote: View {
    let mode: AuthMode

    var body: some View {
        Text(
            mode == .login
                ? "New here? Switch to Create Account above to set up FitMe. Passkeys can be added later in Settings after your first successful sign-in."
                : "Already have an account? Switch to Log In above to use your existing Apple, email, or passkey sign-in."
        )
        .font(AppText.caption)
        .foregroundStyle(AppColor.Text.secondary)
        .multilineTextAlignment(.center)
        .lineSpacing(1)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
    }
}

private struct AuthPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppText.button)
            .foregroundStyle(AppColor.Text.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: configuration.isPressed
                                ? [AppColor.Accent.primary.opacity(0.92), AppColor.Brand.warm.opacity(0.92)]
                                : [AppColor.Accent.primary, AppColor.Brand.warm],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
    }
}

private struct AuthSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppText.button)
            .foregroundStyle(AppColor.Text.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppColor.Surface.elevated.opacity(configuration.isPressed ? 0.76 : 1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppColor.Border.strong, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
    }
}

private struct AuthCardButtonStyle: ButtonStyle {
    var baseFill: Color = AppColor.Surface.elevated

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                    .fill(baseFill.opacity(configuration.isPressed ? 0.9 : 1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                    .stroke(Color.white.opacity(0.24), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
    }
}

#if os(iOS)
private typealias UIKeyboardTypeCompat = UIKeyboardType
private typealias AuthTextContentType = UITextContentType
#else
private enum UIKeyboardTypeCompat {
    case `default`
    case emailAddress
}
private typealias AuthTextContentType = NSTextContentType
#endif

private extension View {
    @ViewBuilder
    func authKeyboardType(_ type: UIKeyboardTypeCompat) -> some View {
        #if os(iOS)
        keyboardType(type)
        #else
        self
        #endif
    }

    @ViewBuilder
    func authTextContentType(_ type: AuthTextContentType?) -> some View {
        #if os(iOS)
        textContentType(type)
        #elseif os(macOS)
        if let type {
            textContentType(type)
        } else {
            self
        }
        #endif
    }

    @ViewBuilder
    func authTextInputAutocapitalization(_ value: TextInputAutocapitalization) -> some View {
        #if os(iOS)
        textInputAutocapitalization(value)
        #else
        self
        #endif
    }

    @ViewBuilder
    func authAutocorrectionDisabled() -> some View {
        #if os(iOS)
        autocorrectionDisabled()
        #else
        self
        #endif
    }

    @ViewBuilder
    func scrollDismissesKeyboardCompat() -> some View {
        #if os(iOS)
        scrollDismissesKeyboard(.interactively)
        #else
        self
        #endif
    }
}

#if os(iOS)
private struct OTPCodeEntryField: View {
    @Binding var code: String
    let digitCount: Int
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            TextField("", text: Binding(
                get: { code },
                set: { newValue in
                    code = String(newValue.filter(\.isNumber).prefix(digitCount))
                }
            ))
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
            .focused($isFocused)
            .opacity(0.01)

            HStack(spacing: 10) {
                ForEach(0..<digitCount, id: \.self) { index in
                    let digit = Array(code).dropFirst(index).first.map(String.init) ?? ""

                    RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                        .fill(AppColor.Surface.elevated)
                        .frame(height: 58)
                        .overlay(
                            Text(digit)
                                .font(AppText.metricCompact)
                                .foregroundStyle(AppColor.Text.primary)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                                .stroke(index == min(code.count, digitCount - 1) && code.count < digitCount ? AppColor.Accent.secondary : Color.clear, lineWidth: 1.5)
                        )
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                isFocused = true
            }
        }
        .onAppear {
            isFocused = true
        }
    }
}
#else
private struct OTPCodeEntryField: View {
    @Binding var code: String
    let digitCount: Int

    var body: some View {
        TextField("12345", text: Binding(
            get: { code },
            set: { newValue in
                code = String(newValue.filter(\.isNumber).prefix(digitCount))
            }
        ))
        .font(AppText.body)
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(AppColor.Surface.elevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppColor.Border.subtle, lineWidth: 1)
        )
    }
}
#endif
