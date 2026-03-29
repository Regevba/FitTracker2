import Foundation

struct PasswordValidationResult: Equatable {
    var issues: [String]
    var isValid: Bool { issues.isEmpty }
}

enum PasswordRuleEvaluator {
    static let minimumLength = 8
    static let guidanceText = "Use 8 or more characters with a mix of letters, numbers, and symbols."
    static let allowedSpecialCharacters = "!@#$%^&*()-_=+[]{};:,.?/"

    static func validate(_ password: String) -> PasswordValidationResult {
        var issues: [String] = []

        if password.count < minimumLength {
            issues.append("Use at least \(minimumLength) characters.")
        }
        if password.range(of: "[A-Z]", options: .regularExpression) == nil {
            issues.append("Include at least 1 capital letter.")
        }
        if password.range(of: "[0-9]", options: .regularExpression) == nil {
            issues.append("Include at least 1 number.")
        }
        if password.rangeOfCharacter(from: CharacterSet(charactersIn: allowedSpecialCharacters)) == nil {
            issues.append("Include at least 1 special character.")
        }

        return PasswordValidationResult(issues: issues)
    }
}

enum AuthInputValidator {
    static func isValidEmail(_ email: String) -> Bool {
        let pattern = #"^[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}$"#
        return email.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
}

struct EmailRegistrationFormState: Equatable, Sendable {
    var firstName = ""
    var lastName = ""
    var birthday = Date()
    var email = ""
    var password = ""
    var confirmPassword = ""

    func normalizedDraft() -> PendingEmailRegistration {
        PendingEmailRegistration(
            firstName: firstName.trimmingCharacters(in: .whitespacesAndNewlines),
            lastName: lastName.trimmingCharacters(in: .whitespacesAndNewlines),
            email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            password: password
        )
    }

    func validationErrors() -> [String: String] {
        var errors: [String: String] = [:]

        if firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors["firstName"] = "Enter your first name."
        }
        if lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors["lastName"] = "Enter your last name."
        }
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalizedEmail.isEmpty {
            errors["email"] = "Enter your email address."
        } else if !AuthInputValidator.isValidEmail(normalizedEmail) {
            errors["email"] = "Enter a valid email address."
        }

        let passwordResult = PasswordRuleEvaluator.validate(password)
        if !passwordResult.isValid {
            errors["password"] = passwordResult.issues.first
        }
        if confirmPassword.isEmpty {
            errors["confirmPassword"] = "Confirm your password."
        } else if confirmPassword != password {
            errors["confirmPassword"] = "Passwords must match."
        }

        return errors
    }

    var isValid: Bool { validationErrors().isEmpty }
}

struct EmailLoginFormState: Equatable, Sendable {
    var email = ""
    var password = ""

    var normalizedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    func validationError() -> String? {
        if normalizedEmail.isEmpty {
            return "Enter your email address."
        }
        if !AuthInputValidator.isValidEmail(normalizedEmail) {
            return "Enter a valid email address."
        }
        if password.isEmpty {
            return "Enter your password."
        }
        return nil
    }
}

enum VerificationCodeState: Equatable {
    case idle
    case invalid(String)
    case verifying
    case accepted
}
