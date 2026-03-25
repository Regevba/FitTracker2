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

    var body: some View {
        NavigationStack(path: $signIn.navigationPath) {
            AuthScaffold {
                AuthLandingView(
                    mode: $mode,
                    registrationForm: $registrationForm,
                    loginForm: $loginForm
                )
            }
            .navigationDestination(for: AuthRoute.self) { route in
                switch route {
                case .emailVerification:
                    AuthScaffold {
                        EmailVerificationView(
                            mode: $mode,
                            registrationForm: $registrationForm
                        )
                    }
                case let .passwordReset(prefillEmail):
                    AuthScaffold {
                        PasswordResetView(
                            mode: $mode,
                            initialEmail: prefillEmail
                        )
                    }
                }
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

    var emailSectionTitle: String {
        switch self {
        case .login:
            return "Use email instead"
        case .register:
            return "Create with email"
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

private struct AuthScaffold<Content: View>: View {
    @EnvironmentObject private var signIn: SignInService
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            AppGradient.authBackground
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
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
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity)
            }
        }
        .scrollDismissesKeyboardCompat()
    }
}

private struct AuthLandingView: View {
    @EnvironmentObject private var signIn: SignInService
    @EnvironmentObject private var biometricAuth: AuthManager

    @Binding var mode: AuthMode
    @Binding var registrationForm: EmailRegistrationFormState
    @Binding var loginForm: EmailLoginFormState

    @State private var registrationErrors: [String: String] = [:]
    @State private var loginError: String?
    @FocusState private var focusedField: AuthField?

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            AuthHeroSection(mode: mode)

            if showQuickReturn {
                QuickReturnSection(
                    canUseBiometrics: biometricAuth.isAvailable && signIn.hasStoredSession,
                    biometricLabel: biometricAuth.biometricName,
                    biometricIcon: biometricAuth.biometricIcon,
                    canUsePasskey: signIn.canShowPasskeyLogin,
                    biometricAction: quickUnlock,
                    passkeyAction: { signIn.signInWithPasskey() }
                )
            }

            AuthSurfaceCard {
                VStack(alignment: .leading, spacing: 18) {
                    Picker("Authentication mode", selection: $mode) {
                        ForEach(AuthMode.allCases) { currentMode in
                            Text(currentMode.rawValue).tag(currentMode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityHint("Switch between login and account creation.")

                    VStack(alignment: .leading, spacing: 6) {
                        Text(mode.title)
                            .font(AppType.headline.weight(.bold))
                            .foregroundStyle(Color.appTextPrimary)

                        Text(mode.subtitle)
                            .font(AppType.body)
                            .foregroundStyle(Color.appTextSecondary)
                    }

                    ApplePrimaryButton(mode: mode)

                    AuthDividerLabel(text: "or use email")

                    if mode == .login {
                        EmailLoginSection(
                            form: $loginForm,
                            localError: $loginError,
                            focusedField: $focusedField
                        )
                    } else {
                        EmailRegistrationSection(
                            form: $registrationForm,
                            errors: $registrationErrors,
                            focusedField: $focusedField
                        )
                    }
                }
            }

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
        (biometricAuth.isAvailable && signIn.hasStoredSession) || signIn.canShowPasskeyLogin
    }

    private func quickUnlock() {
        Task {
            let success = await biometricAuth.authenticateForQuickUnlock()
            if success {
                if signIn.hasStoredSession {
                    signIn.resumeStoredSession()
                } else {
                    signIn.clearFeedback()
                }
            }
        }
    }
}

private struct AuthHeroSection: View {
    let mode: AuthMode

    private let trustItems: [(icon: String, title: String)] = [
        ("lock.shield.fill", "Encrypted on device"),
        ("icloud.fill", "Apple ecosystem ready"),
        ("heart.text.square.fill", "Health data stays private"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                Text(AppBrand.name)
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(.clear)
                    .overlay(
                        AppGradient.brand.mask(
                            Text(AppBrand.name)
                                .font(.system(size: 38, weight: .bold, design: .rounded))
                        )
                    )

                Text(mode == .login ? "Your secure fitness command center." : "A calmer way to track training, recovery, and nutrition.")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.appTextPrimary)

                Text("Sign in quickly, keep your data encrypted, and get back to the workouts, meals, and recovery signals that matter today.")
                    .font(AppType.body)
                    .foregroundStyle(Color.appTextSecondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(trustItems, id: \.title) { item in
                        HStack(spacing: 8) {
                            Image(systemName: item.icon)
                                .font(.system(size: 13, weight: .semibold))
                            Text(item.title)
                                .font(AppType.subheading.weight(.semibold))
                        }
                        .foregroundStyle(Color.appTextPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.55), in: Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.appStroke, lineWidth: 1)
                        )
                    }
                }
            }
            .accessibilityElement(children: .contain)
        }
    }
}

private struct QuickReturnSection: View {
    let canUseBiometrics: Bool
    let biometricLabel: String
    let biometricIcon: String
    let canUsePasskey: Bool
    let biometricAction: () -> Void
    let passkeyAction: () -> Void

    var body: some View {
        AuthSurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Quick return")
                    .font(AppType.headline.weight(.semibold))
                    .foregroundStyle(Color.appTextPrimary)

                Text("For returning users only. Standard login options are still available below.")
                    .font(AppType.subheading)
                    .foregroundStyle(Color.appTextSecondary)

                if canUseBiometrics {
                    Button(action: biometricAction) {
                        AuthQuickReturnRow(
                            icon: biometricIcon,
                            title: "Use \(biometricLabel)",
                            subtitle: "Reopen the last secure session on this device"
                        )
                    }
                    .buttonStyle(AuthCardButtonStyle(baseFill: Color.white.opacity(0.6)))
                    .accessibilityHint("Authenticate with biometrics and reopen your saved session.")
                }

                if canUsePasskey {
                    Button(action: passkeyAction) {
                        AuthQuickReturnRow(
                            icon: "key.fill",
                            title: "Use Passkey",
                            subtitle: "Sign in with a saved passkey or security key"
                        )
                    }
                    .buttonStyle(AuthCardButtonStyle(baseFill: Color.white.opacity(0.6)))
                    .accessibilityHint("Sign in with a saved passkey.")
                }
            }
        }
    }
}

private struct ApplePrimaryButton: View {
    @EnvironmentObject private var signIn: SignInService
    let mode: AuthMode

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SignInWithAppleButton(
                mode == .register ? .continue : .signIn,
                onRequest: signIn.prepareAppleSignInRequest,
                onCompletion: signIn.handleAppleSignInResult
            )
            .signInWithAppleButtonStyle(.black)
            .frame(height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .accessibilityLabel(mode.appleButtonTitle)
            .accessibilityHint("Uses your Apple Account for a secure \(mode == .login ? "login" : "account setup").")

            Text(mode == .login ? "Fastest way back into your encrypted data." : "Fastest way to create a secure account with less typing.")
                .font(AppType.subheading)
                .foregroundStyle(Color.appTextSecondary)
        }
    }
}

private struct EmailLoginSection: View {
    @EnvironmentObject private var signIn: SignInService
    @Binding var form: EmailLoginFormState
    @Binding var localError: String?
    let focusedField: FocusState<AuthField?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Use email instead")
                .font(AppType.body.weight(.semibold))
                .foregroundStyle(Color.appTextPrimary)

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
                    signIn.showPasswordReset(prefillEmail: form.normalizedEmail)
                }
                .buttonStyle(.plain)
                .font(AppType.subheading.weight(.semibold))
                .foregroundStyle(Color.accent.cyan)
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
        VStack(alignment: .leading, spacing: 14) {
            Text("Create with email")
                .font(AppType.body.weight(.semibold))
                .foregroundStyle(Color.appTextPrimary)

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
                    .font(AppType.subheading)
                    .foregroundStyle(Color.appTextSecondary)

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
                    .foregroundStyle(Color.appTextSecondary)
                + Text(expiresAt, style: .timer)
                    .foregroundStyle(Color.appTextPrimary)
                + Text(". AutoFill and paste are supported.")
                    .foregroundStyle(Color.appTextSecondary)
            )
            .font(AppType.subheading)
        }
        else {
            Text("AutoFill and paste are supported.")
                .font(AppType.subheading)
                .foregroundStyle(Color.appTextSecondary)
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
                signIn.resetToEntry(keepingStatus: true)
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
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(Color.appTextPrimary)

            Text(subtitle)
                .font(AppType.body)
                .foregroundStyle(Color.appTextSecondary)
        }
    }
}

private struct AuthSurfaceCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(18)
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.appStroke, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 14, y: 8)
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
                .foregroundStyle(Color.appTextPrimary)

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.accent.cyan)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(AppType.body.weight(.semibold))
                    .foregroundStyle(Color.appTextPrimary)
                Text(subtitle)
                    .font(AppType.subheading)
                    .foregroundStyle(Color.appTextSecondary)
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.appTextTertiary)
        }
    }
}

private struct AuthDividerLabel: View {
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color.white.opacity(0.5))
                .frame(height: 1)

            Text(text.uppercased())
                .font(AppType.caption.weight(.semibold))
                .foregroundStyle(Color.appTextTertiary)

            Rectangle()
                .fill(Color.white.opacity(0.5))
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
        .font(AppType.body)
        .authKeyboardType(keyboard)
        .authTextContentType(contentType)
        .submitLabel(submitLabel)
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.74), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.35), lineWidth: 1)
        )
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
        HStack(spacing: 10) {
            Group {
                if isRevealed {
                    secureInputField(revealed: true)
                } else {
                    secureInputField(revealed: false)
                }
            }

            Button(isRevealed ? "Hide" : "Show") {
                isRevealed.toggle()
            }
            .buttonStyle(.plain)
            .font(AppType.subheading.weight(.semibold))
            .foregroundStyle(Color.accent.cyan)
            .accessibilityLabel(isRevealed ? "Hide password" : "Show password")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.74), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.35), lineWidth: 1)
        )
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
        .font(AppType.body)
        .authTextContentType(contentType)
        .submitLabel(submitLabel)
    }
}

private struct AuthInlineError: View {
    let text: String

    var body: some View {
        Text(text)
            .font(AppType.subheading)
            .foregroundStyle(Color.status.error)
            .accessibilityLabel("Error: \(text)")
    }
}

private struct AuthFootnote: View {
    let mode: AuthMode

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(mode == .login ? "New here? Switch to Create Account above if you’re setting up FitMe for the first time." : "Already have an account? Switch to Log In above to use your existing Apple, email, or passkey sign-in.")
                .font(AppType.subheading)
                .foregroundStyle(Color.appTextSecondary)

            Text("Passkeys can be added later in Settings after your first successful sign-in.")
                .font(AppType.caption)
                .foregroundStyle(Color.appTextTertiary)
        }
        .padding(.horizontal, 4)
    }
}

private struct AuthPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppType.body.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: configuration.isPressed
                                ? [Color.appOrange3.opacity(0.92), Color.appOrange2.opacity(0.92)]
                                : [Color.appOrange3, Color.appOrange2],
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
            .font(AppType.body.weight(.semibold))
            .foregroundStyle(Color.appTextPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.62 : 0.72))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.appStroke, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
    }
}

private struct AuthCardButtonStyle: ButtonStyle {
    var baseFill: Color = Color.appSurface

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(baseFill.opacity(configuration.isPressed ? 0.9 : 1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.appStroke, lineWidth: 1)
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

                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.74))
                        .frame(height: 58)
                        .overlay(
                            Text(digit)
                                .font(.system(size: 24, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.appTextPrimary)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(index == min(code.count, digitCount - 1) && code.count < digitCount ? Color.appBlue2 : Color.clear, lineWidth: 1.5)
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
        .font(AppType.body)
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.74), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.35), lineWidth: 1)
        )
    }
}
#endif
