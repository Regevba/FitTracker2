// Services/AppTheme.swift
// Shared color constants used across views.
// Use Color.appOrange1 etc. instead of local Color(red:green:blue:) literals.

import SwiftUI

enum AppBrand {
    static let name = "FitMe"
}

extension Color {
    static let appOrange1 = Color(red: 1.0,  green: 0.89, blue: 0.73)
    static let appOrange2 = Color(red: 1.0,  green: 0.78, blue: 0.54)
    static let appOrange3 = Color(red: 0.98, green: 0.56, blue: 0.25)
    static let appBlue1   = Color(red: 0.73, green: 0.89, blue: 1.0)
    static let appBlue2   = Color(red: 0.54, green: 0.78, blue: 1.0)
    static let appBlue3   = Color(red: 0.87, green: 0.95, blue: 1.0)
    static let appBlue4   = Color(red: 0.94, green: 0.98, blue: 1.0)
    static let appSurface = Color.white.opacity(0.72)
    static let appStroke  = Color.white.opacity(0.54)
    static let appTextPrimary = Color.black.opacity(0.84)
    static let appTextSecondary = Color.black.opacity(0.58)
    static let appTextTertiary = Color.black.opacity(0.42)
    static let appAccentPrimary = appOrange3
    static let appAccentSoft = appOrange1.opacity(0.34)

    // Status colour tokens
    enum status {
        static let success = Color(red: 0.204, green: 0.780, blue: 0.349)
        static let warning = Color(red: 1.0,   green: 0.584, blue: 0.0)
        static let error   = Color(red: 1.0,   green: 0.231, blue: 0.188)
    }

    // Accent colour tokens
    enum accent {
        static let cyan   = Color(red: 0.353, green: 0.784, blue: 0.980)
        static let purple = Color(red: 0.749, green: 0.353, blue: 0.949)
        static let gold   = Color(red: 1.0,   green: 0.839, blue: 0.039)
    }
}

// Type scale definition
enum AppType {
    static let display    = Font.system(size: 34, weight: .bold)
    static let headline   = Font.system(size: 20, weight: .semibold)
    static let body       = Font.system(size: 15, weight: .medium)
    static let subheading = Font.system(size: 13, weight: .regular)
    static let caption    = Font.system(size: 11, weight: .regular)
}

enum AppGradient {
    static let screenBackground = LinearGradient(
        colors: [.appBlue4, .appBlue3, .appBlue1, .appBlue2.opacity(0.9)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let authBackground = screenBackground

    static let brand = LinearGradient(
        colors: [.appOrange3, .appOrange2, .appOrange1],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
