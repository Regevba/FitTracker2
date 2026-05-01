// AuthSharedComponents.swift — extracted from AuthHubView.swift on 2026-04-28 per
// auth-polish-v2 T0 (Phase 4 prereq for 5 new screens). Per UX spec §3 Component Catalogue.
import SwiftUI
#if os(iOS)
import UIKit
#endif

// MARK: - AuthScaffold

struct AuthScaffold<Content: View>: View {
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

// MARK: - AuthFormCard

struct AuthFormCard<Content: View>: View {
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

// MARK: - AuthBannerView

struct AuthBannerView: View {
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

// MARK: - PasswordRulesTooltip

struct PasswordRulesTooltip: View {
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

// MARK: - AuthPrimaryButtonStyle

struct AuthPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppText.button)
            .foregroundStyle(AppColor.Text.inversePrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.small)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.button)
                    .fill(AppColor.Surface.inverse.opacity(configuration.isPressed ? 0.74 : 0.82))
            )
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
    }
}

// MARK: - PasswordRulesSecureField

#if os(iOS)
struct PasswordRulesSecureField: UIViewRepresentable {
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
#else
struct PasswordRulesSecureField: View {
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
#endif
