// FitTracker/Services/Auth/FTAuthError.swift
import Foundation

/// Authentication errors thrown by FitTracker auth providers.
enum FTAuthError: LocalizedError {
    case missingCredential
    case noRootViewController
    case unknown

    var errorDescription: String? {
        switch self {
        case .missingCredential:    return "Authentication credential is missing or invalid."
        case .noRootViewController: return "Could not find a root view controller to present sign-in."
        case .unknown:              return "An unknown authentication error occurred."
        }
    }
}
