import Foundation

struct PasswordValidationResult: Equatable {
    var issues: [String]
    var isValid: Bool { issues.isEmpty }
}

enum PasswordRuleEvaluator {
    static let allowedSpecialCharacters = "!@#$%^&*()-_=+[]{};:,.?/"

    static func validate(_ password: String) -> PasswordValidationResult {
        var issues: [String] = []

        if password.count < 6 || password.count > 14 {
            issues.append("Use 6 to 14 characters.")
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
            birthday: birthday,
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
        if email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors["email"] = "Enter your email address."
        } else if !Self.isValidEmail(email) {
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

    private static func isValidEmail(_ email: String) -> Bool {
        let pattern = #"^[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}$"#
        return email.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
}

enum VerificationCodeState: Equatable {
    case idle
    case invalid(String)
    case verifying
    case accepted
}
