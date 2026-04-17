import SwiftUI
import AuthenticationServices
#if os(iOS)
import UIKit
#endif

struct AuthHubView: View {
    @EnvironmentObject private var signIn: SignInService
    @EnvironmentObject private var biometricAuth: AuthManager
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        NavigationStack(path: $signIn.navigationPath) {
            AuthScaffold {
                AuthEntryScreen()
            }
            .navigationDestination(for: AuthRoute.self) { route in
                switch route {
                case .registerMethods:
                    AuthScaffold {
                        AuthMethodSelectionView(mode: .register)
                    }
                case .loginMethods:
                    AuthScaffold {
                        AuthMethodSelectionView(mode: .login)
                    }
                case .emailRegistration:
                    AuthScaffold {
                        EmailRegistrationView()
                    }
                case .emailVerification:
                    AuthScaffold {
                        EmailVerificationView()
                    }
                case .emailLogin:
                    AuthScaffold {
                        EmailLoginView()
                    }
                }
            }
        }
    }
}

private struct AuthScaffold<Content: View>: View {
    @EnvironmentObject private var signIn: SignInService
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            AppGradient.authBackground
                .ignoresSafeArea()

            VStack(spacing: AppSpacing.xSmall) {
                if let error = signIn.authErrorMessage {
                    AuthBannerView(
                        icon: "exclamationmark.triangle.fill",
                        text: error,
                        tint: AppColor.Status.error
                    )
                } else if let status = signIn.statusMessage {
                    AuthBannerView(
                        icon: "checkmark.circle.fill",
                        text: status,
                        tint: AppColor.Status.success
                    )
                }

                content
            }
            .padding(.horizontal, AppSpacing.medium)
            .padding(.top, AppSpacing.large)
            .padding(.bottom, AppSpacing.xSmall)
        }
    }
}

private struct AuthEntryScreen: View {
    @EnvironmentObject private var signIn: SignInService
    @EnvironmentObject private var biometricAuth: AuthManager
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            Spacer(minLength: AppSpacing.xSmall)

            VStack(alignment: .leading, spacing: AppSpacing.small) {
                FitMeBrandIcon.medium

                Text(AppBrand.name)
                    .font(AppText.hero)
                    .foregroundStyle(AppColor.Text.primary)

                Text("Private health, training, and recovery tracking in one secure place.")
                    .font(AppText.body)
                    .foregroundStyle(AppColor.Text.secondary)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: AppSpacing.xxSmall)

            VStack(spacing: AppSpacing.xSmall) {
                Button("Register") {
                    signIn.openRegisterFlow()
                }
                .buttonStyle(AuthPrimaryButtonStyle())

                Button("Log In") {
                    signIn.openLoginFlow()
                }
                .buttonStyle(AuthSecondaryButtonStyle())

                VStack(spacing: AppSpacing.xxSmall) {
                    if showBiometricQuickAction {
                        Button {
                            Task {
                                let success = await biometricAuth.authenticateForQuickUnlock()
                                if success {
                                    signIn.resumeStoredSession()
                                }
                            }
                        } label: {
                            AuthQuickActionLabel(
                                icon: biometricAuth.biometricIcon,
                                title: biometricAuth.biometricLabel,
                                subtitle: "Open your existing FitTracker session"
                            )
                        }
                        .buttonStyle(AuthTertiaryButtonStyle())
                    }

                    if signIn.canShowPasskeyLogin {
                        Button {
                            signIn.signInWithPasskey()
                        } label: {
                            AuthQuickActionLabel(
                                icon: "key.fill",
                                title: "Use Passkey",
                                subtitle: "Sign in with a saved passkey or hardware key"
                            )
                        }
                        .buttonStyle(AuthTertiaryButtonStyle())
                    }
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var showBiometricQuickAction: Bool {
        signIn.hasStoredSession && settings.requireBiometricUnlockOnReopen && biometricAuth.isAvailable
    }
}

private enum AuthMethodMode {
    case register
    case login

    var title: String {
        switch self {
        case .register: "Create your account"
        case .login: "Log in to FitTracker"
        }
    }

    var subtitle: String {
        switch self {
        case .register: "Choose how you want to get started."
        case .login: "Pick a sign-in method and continue."
        }
    }
}

private struct AuthMethodSelectionView: View {
    @EnvironmentObject private var signIn: SignInService
    let mode: AuthMethodMode

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                AuthScreenHeader(title: mode.title, subtitle: mode.subtitle)

                VStack(spacing: AppSpacing.xSmall) {
                    if signIn.isEmailAuthAvailable {
                        Button {
                            switch mode {
                            case .register: signIn.showEmailRegistration()
                            case .login: signIn.showEmailLogin()
                            }
                        } label: {
                            AuthProviderRow(
                                icon: "envelope.fill",
                                title: mode == .register ? "Continue with Email" : "Log in with Email",
                                subtitle: mode == .register ? "Register with your email address" : "Use your email and password",
                                tint: AppColor.Brand.secondary
                            )
                        }
                        .buttonStyle(AuthCardButtonStyle())
                    }

                    if signIn.isGoogleAuthAvailable {
                        Button {
                            signIn.signInWithGoogle()
                        } label: {
                            GoogleProviderRow(
                                title: mode == .register ? "Continue with Google" : "Log in with Google",
                                subtitle: "Use your Google account"
                            )
                        }
                        .buttonStyle(AuthCardButtonStyle(baseFill: .white, useDarkStroke: true))
                    }

                    Button {
                        signIn.signInWithApple()
                    } label: {
                        AppleProviderRow(
                            title: mode == .register ? "Continue with Apple" : "Log in with Apple",
                            subtitle: "Use your Apple Account"
                        )
                    }
                    .buttonStyle(AuthCardButtonStyle(baseFill: AppColor.Surface.inverse, foreground: .white))

                    if mode == .login && signIn.canShowPasskeyLogin {
                        Button {
                            signIn.signInWithPasskey()
                        } label: {
                            AuthProviderRow(
                                icon: "key.fill",
                                title: "Use Passkey",
                                subtitle: "Sign in with a saved passkey",
                                tint: AppColor.Accent.sleep
                            )
                        }
                        .buttonStyle(AuthCardButtonStyle())
                    }
                }

                if !signIn.isEmailAuthAvailable || !signIn.isGoogleAuthAvailable {
                    VStack(alignment: .leading, spacing: AppSpacing.micro) {
                        if !signIn.isEmailAuthAvailable {
                            Text("Email sign-in appears after Supabase auth is configured for this build.")
                        }
                        if !signIn.isGoogleAuthAvailable {
                            Text("Google sign-in stays hidden until the Google SDK and URL scheme are fully activated.")
                        }
                    }
                    .font(AppText.subheading)
                    .foregroundStyle(AppColor.Text.tertiary)
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct EmailRegistrationView: View {
    @EnvironmentObject private var signIn: SignInService
    @State private var form = EmailRegistrationFormState()
    @State private var errors: [String: String] = [:]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                AuthScreenHeader(
                    title: "Register with Email",
                    subtitle: "Create your account, then verify your email with a 5-digit code."
                )

                AuthFormCard {
                    AuthTextField(title: "First name", text: $form.firstName, contentType: .givenName)
                    if let error = errors["firstName"] { AuthInlineError(text: error) }

                    AuthTextField(title: "Last name", text: $form.lastName, contentType: .familyName)
                    if let error = errors["lastName"] { AuthInlineError(text: error) }

                    DatePicker("Birthday", selection: $form.birthday, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .font(AppText.body)
                        .padding(.top, 2)

                    AuthTextField(title: "Email", text: $form.email, keyboardType: .emailAddress, contentType: .emailAddress, textInputAutocapitalization: .never)
                    if let error = errors["email"] { AuthInlineError(text: error) }

                    PasswordRulesSecureField(placeholder: "Password", text: $form.password, textContentType: .newPassword)
                    PasswordRulesTooltip()
                    if let error = errors["password"] { AuthInlineError(text: error) }

                    PasswordRulesSecureField(placeholder: "Confirm password", text: $form.confirmPassword, textContentType: .newPassword)
                    if let error = errors["confirmPassword"] { AuthInlineError(text: error) }
                }

                Button(signIn.isLoading ? "Registering..." : "Register") {
                    errors = form.validationErrors()
                    guard errors.isEmpty else { return }
                    Task {
                        await signIn.startEmailRegistration(form.normalizedDraft())
                    }
                }
                .buttonStyle(AuthPrimaryButtonStyle())
                .disabled(signIn.isLoading)
            }
        }
    }
}

private struct EmailVerificationView: View {
    @EnvironmentObject private var signIn: SignInService
    @State private var code = ""
    @State private var codeState: VerificationCodeState = .idle

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            AuthScreenHeader(
                title: "Verify your email",
                subtitle: "A confirmation email with a verification code was sent to \(signIn.pendingEmailRegistration?.email ?? "your address")."
            )

            AuthFormCard {
                OTPCodeEntryField(code: $code, digitCount: 5)
                Text("Enter the 5-digit code. AutoFill and paste are supported.")
                    .font(AppText.subheading)
                    .foregroundStyle(AppColor.Text.tertiary)

                if case let .invalid(message) = codeState {
                    AuthInlineError(text: message)
                }
            }

            Button(signIn.isLoading ? "Verifying..." : "Done") {
                let trimmedCode = code.filter(\.isNumber)
                guard trimmedCode.count == 5 else {
                    codeState = .invalid("Enter the 5-digit code.")
                    return
                }

                codeState = .verifying
                Task {
                    await signIn.verifyEmailRegistrationCode(trimmedCode)
                    if signIn.authErrorMessage == nil {
                        codeState = .accepted
                    } else {
                        codeState = .invalid(signIn.authErrorMessage ?? "The code is invalid.")
                    }
                }
            }
            .buttonStyle(AuthPrimaryButtonStyle())
            .disabled(signIn.isLoading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct EmailLoginView: View {
    @EnvironmentObject private var signIn: SignInService
    @State private var email = ""
    @State private var password = ""
    @State private var localError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            AuthScreenHeader(
                title: "Log in with Email",
                subtitle: "Use your registered email address and password."
            )

            AuthFormCard {
                AuthTextField(title: "Email", text: $email, keyboardType: .emailAddress, contentType: .username, textInputAutocapitalization: .never)
                PasswordRulesSecureField(placeholder: "Password", text: $password, textContentType: .password)

                if let localError {
                    AuthInlineError(text: localError)
                }
            }

            Button(signIn.isLoading ? "Logging in..." : "Log In") {
                guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    localError = "Enter your email address."
                    return
                }
                guard !password.isEmpty else {
                    localError = "Enter your password."
                    return
                }

                localError = nil
                Task {
                    await signIn.signInWithEmail(
                        email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                        password: password
                    )
                }
            }
            .buttonStyle(AuthPrimaryButtonStyle())
            .disabled(signIn.isLoading)

            Button(signIn.isLoading ? "Sending reset link..." : "Forgot password?") {
                let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedEmail.isEmpty else {
                    localError = "Enter your email address to reset your password."
                    return
                }

                localError = nil
                Task {
                    await signIn.requestPasswordReset(email: trimmedEmail)
                }
            }
            .buttonStyle(AuthSecondaryButtonStyle())
            .disabled(signIn.isLoading)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct AuthScreenHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {
            Text(title)
                .font(AppText.hero)
                .foregroundStyle(AppColor.Text.primary)

            Text(subtitle)
                .font(AppText.body)
                .foregroundStyle(AppColor.Text.tertiary)
        }
        .padding(.top, AppSpacing.xxSmall)
    }
}

private struct AuthFormCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
            content
        }
        .padding(AppSpacing.large)
        .background(AppColor.Surface.primary, in: RoundedRectangle(cornerRadius: AppRadius.sheet))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.sheet)
                .stroke(AppColor.Border.strong, lineWidth: 1)
        )
    }
}

private struct AuthBannerView: View {
    let icon: String
    let text: String
    let tint: Color

    var body: some View {
        HStack(spacing: AppSpacing.xxSmall) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            Text(text)
                .font(AppText.subheading)
                .foregroundStyle(AppColor.Text.secondary)
            Spacer()
        }
        .padding(.horizontal, AppSpacing.xSmall)
        .padding(.vertical, AppSpacing.xSmall)
        .background(AppColor.Surface.primary, in: RoundedRectangle(cornerRadius: AppRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct AuthProviderRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let tint: Color

    var body: some View {
        HStack(spacing: AppSpacing.xSmall) {
            Image(systemName: icon)
                .font(AppText.sectionTitle)
                .foregroundStyle(tint)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: AppSpacing.micro) {
                Text(title)
                    .font(AppText.button)
                Text(subtitle)
                    .font(AppText.subheading)
                    .foregroundStyle(AppColor.Text.secondary)
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColor.Text.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct GoogleProviderRow: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: AppSpacing.xSmall) {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 26, height: 26)
                Text("G")
                    .font(AppText.callout)
                    .foregroundStyle(AppColor.Brand.secondary)
            }

            VStack(alignment: .leading, spacing: AppSpacing.micro) {
                Text(title)
                    .font(AppText.button)
                    .foregroundStyle(AppColor.Text.primary)
                Text(subtitle)
                    .font(AppText.subheading)
                    .foregroundStyle(AppColor.Text.tertiary)
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColor.Text.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AppleProviderRow: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: AppSpacing.xSmall) {
            OfficialAppleButtonIcon()
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: AppSpacing.micro) {
                Text(title)
                    .font(AppText.button)
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(AppText.subheading)
                    .foregroundStyle(AppColor.Text.inverseSecondary)
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColor.Text.inverseSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct OfficialAppleButtonIcon: UIViewRepresentable {
    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(type: .signIn, style: .white)
        button.isUserInteractionEnabled = false
        button.cornerRadius = 8
        return button
    }

    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {}
}

private struct AuthTextField: View {
    let title: String
    @Binding var text: String
    #if os(iOS)
    var keyboardType: UIKeyboardType = .default
    var contentType: UITextContentType?
    #else
    var contentType: NSTextContentType?
    #endif
    var textInputAutocapitalization: TextInputAutocapitalization = .words

    var body: some View {
        #if os(iOS)
        TextField(title, text: $text)
            .keyboardType(keyboardType)
            .textContentType(contentType)
            .textInputAutocapitalization(textInputAutocapitalization)
            .autocorrectionDisabled()
            .font(AppText.body)
            .padding(.horizontal, AppSpacing.xSmall)
            .padding(.vertical, AppSpacing.xSmall)
            .background(AppColor.Surface.primary, in: RoundedRectangle(cornerRadius: AppRadius.medium))
        #else
        TextField(title, text: $text)
            .font(AppText.body)
            .padding(.horizontal, AppSpacing.xSmall)
            .padding(.vertical, AppSpacing.xSmall)
            .background(AppColor.Surface.primary, in: RoundedRectangle(cornerRadius: AppRadius.medium))
        #endif
    }
}

private struct PasswordRulesTooltip: View {
    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.xxSmall) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(AppColor.Accent.recovery)
                .padding(.top, 1)
            Text("Use 6 to 14 characters with at least 1 capital letter, 1 number, and 1 special character.")
                .font(AppText.subheading)
                .foregroundStyle(AppColor.Text.tertiary)
        }
    }
}

private struct AuthInlineError: View {
    let text: String

    var body: some View {
        Text(text)
            .font(AppText.subheading)
            .foregroundStyle(ColorAppColor.Status.error)
    }
}

private struct AuthQuickActionLabel: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: AppSpacing.xSmall) {
            Image(systemName: icon)
                .font(AppText.sectionTitle)
                .foregroundStyle(AppColor.Text.secondary)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: AppSpacing.micro) {
                Text(title)
                    .font(AppText.button)
                    .foregroundStyle(AppColor.Text.secondary)
                Text(subtitle)
                    .font(AppText.subheading)
                    .foregroundStyle(AppColor.Text.tertiary)
            }

            Spacer()
        }
    }
}

private struct AuthPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppText.button)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.small)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.button)
                    .fill(AppColor.Surface.inverse.opacity(configuration.isPressed ? 0.74 : 0.82))
            )
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
    }
}

private struct AuthSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppText.button)
            .foregroundStyle(AppColor.Text.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.small)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.button)
                    .fill(AppColor.Surface.primary.opacity(configuration.isPressed ? 0.72 : 0.62))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.button)
                    .stroke(AppColor.Border.strong, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
    }
}

private struct AuthTertiaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, AppSpacing.xSmall)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .fill(AppColor.Surface.secondary.opacity(configuration.isPressed ? 0.72 : 0.58))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .stroke(AppColor.Border.strong, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
    }
}

private struct AuthCardButtonStyle: ButtonStyle {
    var baseFill: Color = AppColor.Surface.primary
    var foreground: Color = .black
    var useDarkStroke = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, AppSpacing.small)
            .padding(.vertical, AppSpacing.small)
            .foregroundStyle(foreground)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .fill(baseFill.opacity(configuration.isPressed ? 0.88 : 1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .stroke(useDarkStroke ? AppColor.Border.hairline : AppColor.Border.strong, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
    }
}

#if os(iOS)
private struct PasswordRulesSecureField: UIViewRepresentable {
    let placeholder: String
    @Binding var text: String
    let textContentType: UITextContentType

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField(frame: .zero)
        field.isSecureTextEntry = true
        field.placeholder = placeholder
        field.textContentType = textContentType
        field.passwordRules = UITextInputPasswordRules(
            descriptor: "allowed: ascii-printable; required: upper; required: digit; required: [-!@#$%^&*()_=+[]{};:,.?/]; minlength: 6; maxlength: 14;"
        )
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        field.borderStyle = .none
        field.backgroundColor = UIColor(AppColor.Surface.primary)
        field.layer.cornerRadius = 16
        field.setContentHuggingPriority(.defaultHigh, for: .vertical)
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)

        let padding = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
        field.leftView = padding
        field.leftViewMode = .always
        field.rightView = padding
        field.rightViewMode = .always
        return field
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String

        init(text: Binding<String>) {
            self._text = text
        }

        @objc func textChanged(_ textField: UITextField) {
            text = textField.text ?? ""
        }
    }
}

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

            HStack(spacing: AppSpacing.xxSmall) {
                ForEach(0..<digitCount, id: \.self) { index in
                    let digit = Array(code).dropFirst(index).first.map(String.init) ?? ""

                    RoundedRectangle(cornerRadius: AppRadius.small)
                        .fill(AppColor.Surface.primary)
                        .frame(height: 58)
                        .overlay(
                            Text(digit)
                                .font(AppText.titleMedium)
                                .foregroundStyle(AppColor.Text.primary)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.small)
                                .stroke(index == code.count ? ColorAppColor.Brand.secondary : Color.clear, lineWidth: 1.5)
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
private struct PasswordRulesSecureField: View {
    let placeholder: String
    @Binding var text: String
    let textContentType: NSTextContentType?

    var body: some View {
        SecureField(placeholder, text: $text)
            .font(AppText.body)
            .padding(.horizontal, AppSpacing.xSmall)
            .padding(.vertical, AppSpacing.xSmall)
            .background(AppColor.Surface.primary, in: RoundedRectangle(cornerRadius: AppRadius.medium))
    }
}

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
        .padding(.horizontal, AppSpacing.xSmall)
        .padding(.vertical, AppSpacing.xSmall)
        .background(AppColor.Surface.primary, in: RoundedRectangle(cornerRadius: AppRadius.medium))
    }
}
#endif
