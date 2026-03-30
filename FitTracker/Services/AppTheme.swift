// Services/AppTheme.swift
// Canonical design system foundation for FitTracker.
// New UI code should prefer AppColor / AppText / AppSpacing / AppRadius.
// Legacy Color.app* and AppType aliases remain available during migration.

import SwiftUI

enum AppBrand {
    static let name = "FitMe"
}

enum AppColor {
    enum Brand {
        static let primary = Color(red: 0.98, green: 0.56, blue: 0.25)
        static let secondary = Color(red: 0.54, green: 0.78, blue: 1.0)
        static let warmSoft = Color(red: 1.0, green: 0.89, blue: 0.73)
        static let warm = Color(red: 1.0, green: 0.78, blue: 0.54)
        static let coolSoft = Color(red: 0.87, green: 0.95, blue: 1.0)
        static let cool = Color(red: 0.73, green: 0.89, blue: 1.0)
    }

    enum Background {
        static let appPrimary = Brand.coolSoft
        static let appSecondary = Color(red: 0.94, green: 0.98, blue: 1.0)
        static let appTint = Brand.cool
        static let appWarmTint = Brand.warmSoft

        static let authTop = Color(red: 0.04, green: 0.08, blue: 0.06)
        static let authMiddle = Color(red: 0.06, green: 0.14, blue: 0.10)
        static let authBottom = Color(red: 0.02, green: 0.06, blue: 0.04)
    }

    enum Surface {
        static let primary = Color.white.opacity(0.72)
        static let secondary = Color.white.opacity(0.58)
        static let tertiary = Color.white.opacity(0.38)
        static let elevated = Color.white.opacity(0.92)
        static let materialLight = Color.white.opacity(0.22)
        static let materialStrong = Color.white.opacity(0.34)
        static let inverse = Color.black.opacity(0.82)
    }

    enum Text {
        static let primary = Color.black.opacity(0.84)
        static let secondary = Color.black.opacity(0.62)
        static let tertiary = Color.black.opacity(0.42)
        static let inversePrimary = Color.white.opacity(0.94)
        static let inverseSecondary = Color.white.opacity(0.76)
        static let inverseTertiary = Color.white.opacity(0.54)
    }

    enum Border {
        static let strong = Color.white.opacity(0.54)
        static let subtle = Color.white.opacity(0.30)
        static let hairline = Color.black.opacity(0.08)
    }

    enum Accent {
        static let primary = Brand.primary
        static let secondary = Brand.secondary
        static let recovery = Color(red: 0.353, green: 0.784, blue: 0.980)
        static let sleep = Color(red: 0.749, green: 0.353, blue: 0.949)
        static let achievement = Color(red: 1.0, green: 0.839, blue: 0.039)
    }

    enum Status {
        static let success = Color(red: 0.204, green: 0.780, blue: 0.349)
        static let warning = Color(red: 1.0, green: 0.584, blue: 0.0)
        static let error = Color(red: 1.0, green: 0.231, blue: 0.188)
    }

    enum Chart {
        static let body = Brand.warm
        static let cardio = Accent.recovery
        static let sleep = Accent.sleep
        static let achievement = Accent.achievement
        static let progress = Brand.secondary
        static let nutritionFat = Color(red: 0.60, green: 0.35, blue: 0.15)
    }

    enum Focus {
        static let ring = Brand.secondary
    }

    enum Selection {
        static let active = Color.white.opacity(0.84)
        static let inactive = Color.white.opacity(0.42)
    }
}

enum AppSpacing {
    static let xxxSmall: CGFloat = 4
    static let xxSmall: CGFloat = 6
    static let xSmall: CGFloat = 8
    static let small: CGFloat = 10
    static let medium: CGFloat = 14
    static let large: CGFloat = 18
    static let xLarge: CGFloat = 22
    static let xxLarge: CGFloat = 28
}

enum AppRadius {
    static let small: CGFloat = 10
    static let medium: CGFloat = 14
    static let large: CGFloat = 16
    static let xLarge: CGFloat = 22
    static let sheet: CGFloat = 24
    static let authSheet: CGFloat = 28
}

enum AppShadow {
    static let cardColor = Color.black.opacity(0.08)
    static let cardRadius: CGFloat = 10
    static let cardYOffset: CGFloat = 4

    static let ctaColor = AppColor.Accent.primary.opacity(0.28)
    static let ctaRadius: CGFloat = 12
    static let ctaYOffset: CGFloat = 4
}

enum AppSheet {
    static let standardCornerRadius = AppRadius.sheet
    static let authCornerRadius = AppRadius.authSheet
}

enum AppText {
    static let hero = Font.system(.largeTitle, design: .rounded).weight(.bold)
    static let pageTitle = Font.system(.title2, design: .rounded).weight(.bold)
    static let titleStrong = Font.system(.title3, design: .rounded).weight(.bold)
    static let titleMedium = Font.system(.title3, design: .rounded).weight(.semibold)
    static let sectionTitle = Font.system(.headline, design: .rounded).weight(.semibold)
    static let body = Font.system(.body, design: .rounded).weight(.medium)
    static let bodyRegular = Font.system(.body, design: .rounded)
    static let callout = Font.system(.callout, design: .rounded).weight(.medium)
    static let subheading = Font.system(.subheadline, design: .rounded)
    static let caption = Font.system(.caption, design: .rounded)
    static let captionStrong = Font.system(.caption, design: .rounded).weight(.semibold)
    static let eyebrow = Font.system(.caption, design: .rounded).weight(.bold)
    static let chip = Font.system(.footnote, design: .rounded).weight(.semibold)
    static let footnote = Font.system(.footnote, design: .rounded)
    static let metric = Font.system(.title, design: .rounded).weight(.bold)
    static let metricCompact = Font.system(.title2, design: .rounded).weight(.bold)
    static let metricHero = Font.system(.largeTitle, design: .rounded).weight(.bold)
    static let metricDisplay = Font.system(size: 48, design: .rounded).weight(.bold)
    static let metricDisplayMono = Font.system(size: 42, design: .monospaced).weight(.bold)
    static let monoMetric = Font.system(.title3, design: .monospaced).weight(.bold)
    static let monoLabel = Font.system(.caption2, design: .monospaced).weight(.semibold)
    static let button = Font.system(.body, design: .rounded).weight(.semibold)
}

// Legacy compatibility aliases while the rest of the app migrates.
enum AppType {
    static let display = AppText.hero
    static let headline = AppText.sectionTitle
    static let body = AppText.body
    static let subheading = AppText.subheading
    static let caption = AppText.caption
}

enum AppGradient {
    static let screenBackground = LinearGradient(
        colors: [
            AppColor.Background.appSecondary,
            AppColor.Background.appPrimary,
            AppColor.Brand.cool,
            AppColor.Brand.secondary.opacity(0.9),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let authBackground = LinearGradient(
        colors: [
            AppColor.Background.authTop,
            AppColor.Background.authMiddle,
            AppColor.Background.authBottom,
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let brand = LinearGradient(
        colors: [
            AppColor.Brand.primary,
            AppColor.Brand.warm,
            AppColor.Brand.warmSoft,
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let darkAccent = LinearGradient(
        colors: [
            AppColor.Accent.recovery.opacity(0.42),
            AppColor.Accent.sleep.opacity(0.34),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

extension Color {
    // Legacy brand aliases
    static let appOrange1 = AppColor.Brand.warmSoft
    static let appOrange2 = AppColor.Brand.warm
    static let appOrange3 = AppColor.Brand.primary
    static let appBlue1 = AppColor.Brand.cool
    static let appBlue2 = AppColor.Brand.secondary
    static let appBlue3 = AppColor.Brand.coolSoft
    static let appBlue4 = AppColor.Background.appSecondary

    static let appSurface = AppColor.Surface.primary
    static let appStroke = AppColor.Border.strong
    static let appTextPrimary = AppColor.Text.inversePrimary
    static let appTextSecondary = AppColor.Text.inverseSecondary
    static let appTextTertiary = AppColor.Text.inverseTertiary
    static let appAccentPrimary = AppColor.Accent.primary
    static let appAccentSoft = AppColor.Brand.warmSoft.opacity(0.34)

    enum status {
        static let success = AppColor.Status.success
        static let warning = AppColor.Status.warning
        static let error = AppColor.Status.error
    }

    enum accent {
        static let cyan = AppColor.Accent.recovery
        static let purple = AppColor.Accent.sleep
        static let gold = AppColor.Accent.achievement
    }
}
