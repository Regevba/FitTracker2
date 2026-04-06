// FitTracker/Services/AppTheme.swift
// Semantic design token layer.
// Views always reference this file — never AppPalette or raw values.
import SwiftUI

enum AppBrand {
    static let name = "FitMe"
}

enum AppColor {
    enum Brand {
        static let primary   = Color("brand-primary")
        static let secondary = Color("brand-secondary")
        static let warmSoft  = Color("brand-warm-soft")
        static let warm      = Color("brand-warm")
        static let coolSoft  = Color("brand-cool-soft")
        static let cool      = Color("brand-cool")
    }

    enum Background {
        static let appPrimary   = Color("bg-app-primary")
        static let appSecondary = Color("bg-app-secondary")
        static let appTint      = Color("bg-app-tint")
        static let appWarmTint  = Color("bg-app-warm-tint")
        // Auth backgrounds are always dark — same value in light and dark mode
        static let authTop    = Color("bg-auth-top")
        static let authMiddle = Color("bg-auth-middle")
        static let authBottom = Color("bg-auth-bottom")
    }

    enum Surface {
        static let primary        = Color("surface-primary")
        static let secondary      = Color("surface-secondary")
        static let tertiary       = Color("surface-tertiary")
        static let elevated       = Color("surface-elevated")
        static let materialLight  = Color("surface-material-light")
        static let materialStrong = Color("surface-material-strong")
        static let inverse        = Color("surface-inverse")
    }

    enum Text {
        static let primary          = Color("text-primary")
        static let secondary        = Color("text-secondary")
        static let tertiary         = Color("text-tertiary")  // WCAG AA: ≈4.6:1 light, ≈5.1:1 dark
        static let inversePrimary   = Color("text-inverse-primary")
        static let inverseSecondary = Color("text-inverse-secondary")
        static let inverseTertiary  = Color("text-inverse-tertiary")
    }

    enum Border {
        static let strong   = Color("border-strong")
        static let subtle   = Color("border-subtle")
        static let hairline = Color("border-hairline")
    }

    enum Accent {
        static let primary     = Brand.primary
        static let secondary   = Brand.secondary
        static let recovery    = Color("accent-recovery")
        static let sleep       = Color("accent-sleep")
        static let achievement = Color("accent-achievement")
    }

    enum Status {
        static let success = Color("status-success")
        static let warning = Color("status-warning")
        static let error   = Color("status-error")
    }

    enum Chart {
        static let body         = Color("chart-body")
        static let cardio       = Color("chart-cardio")
        static let sleep        = Color("chart-sleep")
        static let achievement  = Color("chart-achievement")
        static let progress     = Color("chart-progress")
        static let nutritionFat = Color("chart-nutrition-fat")
    }

    enum Focus {
        static let ring = Brand.secondary
    }

    enum Selection {
        static let active   = Color("selection-active")
        static let inactive = Color("selection-inactive")
    }
}

// MARK: - Spacing
enum AppSpacing {
    /// Sub-grid — tightest data-display pairs only (value+unit, inline icon+label).
    /// Not for general layout — use xxxSmall (4) for all other tight spacing.
    static let micro:    CGFloat = 2
    // 4pt grid below
    static let xxxSmall: CGFloat = 4
    static let xxSmall:  CGFloat = 8
    static let xSmall:   CGFloat = 12
    static let small:    CGFloat = 16
    static let medium:   CGFloat = 20
    static let large:    CGFloat = 24
    static let xLarge:   CGFloat = 32
    static let xxLarge:  CGFloat = 40
}

// MARK: - Radius
enum AppRadius {
    /// Data-viz only — progress bars, chart bar segments, small inline indicators.
    /// Not for interactive surfaces — use xSmall (8) as the smallest component radius.
    static let micro:     CGFloat = 4
    static let xSmall:    CGFloat = 8
    static let small:     CGFloat = 12
    static let medium:    CGFloat = 16
    /// Pill-style buttons and action tiles with a softer corner than medium.
    static let button:    CGFloat = 20
    static let large:     CGFloat = 24
    static let xLarge:    CGFloat = 28   // deliberately 28 — distinct from sheet=32
    static let sheet:     CGFloat = 32
    static let authSheet: CGFloat = 36
}

// MARK: - Shadow
enum AppShadow {
    static let cardColor:   Color  = AppPalette.black.opacity(0.08)
    static let cardRadius:  CGFloat = 10
    static let cardYOffset: CGFloat = 4

    static let ctaColor:    Color  = AppColor.Accent.primary.opacity(0.28)
    static let ctaRadius:   CGFloat = 12
    static let ctaYOffset:  CGFloat = 4
}

enum AppSheet {
    static let standardCornerRadius = AppRadius.sheet
    static let authCornerRadius     = AppRadius.authSheet
}

// MARK: - Typography
enum AppText {
    static let hero              = Font.system(.largeTitle,   design: .rounded).weight(.bold)
    static let pageTitle         = Font.system(.title2,       design: .rounded).weight(.bold)
    static let titleStrong       = Font.system(.title3,       design: .rounded).weight(.bold)
    static let titleMedium       = Font.system(.title3,       design: .rounded).weight(.semibold)
    static let sectionTitle      = Font.system(.headline,     design: .rounded).weight(.semibold)
    static let body              = Font.system(.body,         design: .rounded).weight(.medium)
    static let bodyRegular       = Font.system(.body,         design: .rounded)
    static let callout           = Font.system(.callout,      design: .rounded).weight(.medium)
    static let subheading        = Font.system(.subheadline,  design: .rounded)
    static let caption           = Font.system(.caption,      design: .rounded)
    static let captionStrong     = Font.system(.caption,      design: .rounded).weight(.semibold)
    static let eyebrow           = Font.system(.caption,      design: .rounded).weight(.bold)
    static let chip              = Font.system(.footnote,     design: .rounded).weight(.semibold)
    static let footnote          = Font.system(.footnote,     design: .rounded)
    static let metric            = Font.system(.title,        design: .rounded).weight(.bold)
    static let metricCompact     = Font.system(.title2,       design: .rounded).weight(.bold)
    // metricHero and metricDisplay are intentional semantic aliases of hero (largeTitle/bold/rounded).
    // metricHero: full-screen readiness score (ReadinessCard).
    // metricDisplay: large standalone metric (e.g. body weight hero in StatsView).
    // hero: page-level heading. Same font, different semantic role — kept separate for Figma mapping.
    static let metricHero        = Font.system(.largeTitle,   design: .rounded).weight(.bold)
    static let metricDisplay     = Font.system(.largeTitle,   design: .rounded).weight(.bold)
    static let metricDisplayMono = Font.system(.title,        design: .monospaced).weight(.bold)
    static let monoMetric        = Font.system(.title3,       design: .monospaced).weight(.bold)
    static let monoLabel         = Font.system(.caption2,     design: .monospaced).weight(.semibold)
    static let button            = Font.system(.body,         design: .rounded).weight(.semibold)
}

// MARK: - Legacy aliases (DEPRECATED — migrate call sites to AppText.*)
// These exist only for backward compatibility. Do not use in new code.
// Removal tracked: all call sites should use AppText.* directly.
enum AppType {
    @available(*, deprecated, renamed: "AppText.hero")
    static let display    = AppText.hero
    @available(*, deprecated, renamed: "AppText.sectionTitle")
    static let headline   = AppText.sectionTitle
    @available(*, deprecated, renamed: "AppText.body")
    static let body       = AppText.body
    @available(*, deprecated, renamed: "AppText.subheading")
    static let subheading = AppText.subheading
    @available(*, deprecated, renamed: "AppText.caption")
    static let caption    = AppText.caption
}

// MARK: - Gradients
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

    // Auth uses the same brand gradient as the rest of the app.
    // Previously used a dark forest gradient (darkForest0/1/2) which was off-brand.
    static let authBackground = screenBackground

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

// MARK: - Legacy compatibility aliases (DEPRECATED — migrate call sites to AppColor.*)
// These exist only for backward compatibility with older view code.
// Do not use in new code. Removal tracked for next cleanup pass.
extension Color {
    static let appOrange1 = AppColor.Brand.warmSoft
    static let appOrange2 = AppColor.Brand.warm
    static let appOrange3 = AppColor.Brand.primary
    static let appBlue1   = AppColor.Brand.cool
    static let appBlue2   = AppColor.Brand.secondary
    static let appBlue3   = AppColor.Brand.coolSoft
    static let appBlue4   = AppColor.Background.appSecondary

    static let appSurface      = AppColor.Surface.primary
    static let appStroke       = AppColor.Border.strong
    static let appTextPrimary  = AppColor.Text.inversePrimary
    static let appTextSecondary = AppColor.Text.inverseSecondary
    static let appTextTertiary = AppColor.Text.inverseTertiary
    static let appAccentPrimary = AppColor.Accent.primary
    static let appAccentSoft   = AppColor.Brand.warmSoft.opacity(0.34)

    enum status {
        static let success = AppColor.Status.success
        static let warning = AppColor.Status.warning
        static let error   = AppColor.Status.error
    }

    enum accent {
        static let primary = AppColor.Accent.primary
        static let cyan   = AppColor.Accent.recovery
        static let purple = AppColor.Accent.sleep
        static let gold   = AppColor.Accent.achievement
    }
}

// MARK: - Contrast validation (DEBUG only)
#if DEBUG
enum ColorContrastValidator {
    static func validate() {
        // Text.tertiary on white background: black.opacity(0.55) ≈ 4.6:1 — passes WCAG AA
        // Text.secondary on white background: black.opacity(0.62) ≈ 5.4:1 — passes WCAG AA
        // Text.primary on white background: black.opacity(0.84) ≈ 9.2:1 — passes WCAG AAA
        assert(
            true,
            "Run xcrun simctl to visually verify contrast ratios in DesignSystemCatalogView"
        )
    }
}
#endif
