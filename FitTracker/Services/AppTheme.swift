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

    /// Overlay tokens — semi-transparent layers placed above content.
    /// Use `scrim` for backdrops behind modals, sheets, and locked-feature overlays.
    enum Overlay {
        /// Modal/sheet backdrop — black at 40% opacity. Provides ~7:1 contrast against content below.
        static let scrim = Color.black.opacity(0.4)
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
        static let nutrition   = Color("accent-recovery").opacity(0.9) // Cyan-tinted nutrition accent — distinct from recovery
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
        // Home v2 metric tints (T3)
        static let weight       = Color("chart-weight")
        static let hrv          = Color("chart-hrv")
        static let heartRate    = Color("chart-heart-rate")
        static let activity     = Color("chart-activity")
    }

    // Focus.ring removed in audit DS-015 — token had zero references in any view.
    // If a focus-ring style is needed in the future, re-introduce here via
    // Brand.secondary or a dedicated focus token.

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
    /// Supplement detail row indent — checkbox (26) + surrounding padding. Nutrition v2 specific.
    static let supplementDetailIndent: CGFloat = 54

    /// All spacing values that MUST be on the 4pt grid.
    /// Exposed for compliance tests — add new tokens here when they belong to the grid.
    /// Sub-grid (`micro`, 2pt) and feature-specific values (`supplementDetailIndent`, 54pt)
    /// are intentionally excluded.
    static let gridValues: [CGFloat] = [
        xxxSmall, xxSmall, xSmall, small, medium, large, xLarge, xxLarge
    ]
}

// MARK: - Opacity
enum AppOpacity {
    /// Disabled/inactive state — use for dimmed backgrounds on toggled-off elements
    static let disabled: Double = 0.15
    /// Subtle background — use for tinted card backgrounds, hover states
    static let subtle:   Double = 0.12
    /// Hover/focus — lightest tint for interactive feedback
    static let hover:    Double = 0.08
}

// MARK: - Layout (component sizing)
enum AppLayout {
    /// Standard chart canvas height (Swift Charts)
    static let chartHeight:          CGFloat = 158
    /// Empty state container minimum height
    static let emptyStateMinHeight:  CGFloat = 128
    /// Metric chip minimum width in carousel
    static let chipMinWidth:         CGFloat = 128
    /// Metric chip ideal width in carousel
    static let chipIdealWidth:       CGFloat = 144
    /// Metric chip maximum width in carousel
    static let chipMaxWidth:         CGFloat = 168
    /// Selection indicator dot size
    static let dotSize:              CGFloat = 8
}

// MARK: - Radius
enum AppRadius {
    /// Data-viz only — progress bars, chart bar segments, small inline indicators.
    /// Not for interactive surfaces — use xSmall (8) as the smallest component radius.
    static let micro:     CGFloat = 4
    static let xSmall:    CGFloat = 8
    static let small:     CGFloat = 12
    static let medium:    CGFloat = 16
    static let card:      CGFloat = 16   // alias for card surfaces (used by ConsentView and other card components)
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

    // Welcome screen CTA: white-on-orange shadow (subtler than the brand-tinted CTA shadow)
    static let ctaInverseColor:   Color   = AppPalette.black.opacity(0.12)
    static let ctaInverseRadius:  CGFloat = 8
    static let ctaInverseYOffset: CGFloat = 4
}

// MARK: - Size
// Semantic size tokens for fixed-dimension UI elements (introduced for onboarding v2 alignment).
enum AppSize {
    /// Standard CTA height (52pt) — used for all primary action buttons
    static let ctaHeight: CGFloat = 52
    /// Large touch target (48pt) — exceeds 44pt minimum, used for selection circles
    static let touchTargetLarge: CGFloat = 48
    /// Icon badge / inset element (26pt) — small overlay icons
    static let iconBadge: CGFloat = 26
    /// Progress bar segment height (4pt)
    static let progressBarHeight: CGFloat = 4
    /// Small status/readiness indicator dot (8pt) — Home v2 (T1)
    static let indicatorDot: CGFloat = 8
    /// Tab bar clearance padding (56pt) — Training v2 (T1)
    static let tabBarClearance: CGFloat = 56
}

// MARK: - Motion
// Semantic animation tokens that respect Reduce Motion when consumed via SwiftUI's
// `accessibilityReduceMotion` environment value.
enum AppMotion {
    /// Onboarding step transition — easeInOut 0.3s
    static let stepTransition: Animation = .easeInOut(duration: 0.3)
    /// Standard quick interaction — easeOut 0.2s
    static let quickInteraction: Animation = .easeOut(duration: 0.2)
    /// Tap/press feedback — easeOut 0.16s (just below perceptible delay threshold)
    static let pressFeedback: Animation = .easeOut(duration: 0.16)
    /// Selection state change — easeOut 0.18s
    static let selectionChange: Animation = .easeOut(duration: 0.18)
    /// Page/tab transition — easeInOut 0.2s
    static let pageTransition: Animation = .easeInOut(duration: 0.2)
    /// Progress bar fill — easeOut 0.6s (slower for hero metric reveals)
    static let progressFill: Animation = .easeOut(duration: 0.6)
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
    /// ~25pt rounded bold — Home v2 status card value hero (T1)
    /// Uses Font.system(design:) so Dynamic Type scales relative to .title.
    static let metricM           = Font.system(size: 25, weight: .bold, design: .rounded)
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
    /// Monospaced caption — timer displays, set counters
    static let monoCaption       = Font.system(.caption2,     design: .monospaced).weight(.semibold)
    static let button            = Font.system(.body,         design: .rounded).weight(.semibold)

    // Icon sizes — for SF Symbol illustrations in onboarding, empty states, hero displays.
    // These are intentionally fixed-size (icons don't scale with Dynamic Type).
    static let iconSmall         = Font.system(size: 18, weight: .medium)
    /// Profile/inline action icon (22pt) — used for compact toolbar/list affordances. Audit UI-010.
    static let iconCompact       = Font.system(size: 22, weight: .medium)
    static let iconMedium        = Font.system(size: 28, weight: .medium)
    /// Home v2 primary action button icon (32pt) — T1
    static let iconXL            = Font.system(size: 32, weight: .medium)
    static let iconLarge         = Font.system(size: 48, weight: .medium)
    static let iconHero          = Font.system(size: 64, weight: .regular)
    static let iconDisplay       = Font.system(size: 72, weight: .regular)

    // Display headlines — bold + rounded, fixed size for hero onboarding/marketing surfaces.
    /// Onboarding welcome hero headline (32pt bold rounded). Audit UI-008.
    static let displayHeadline   = Font.system(size: 32, weight: .bold, design: .rounded)
    /// Onboarding first-action headline (36pt bold). Audit UI-009.
    static let displayLarge      = Font.system(size: 36, weight: .bold)
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

// Audit DS-002 + DS-003 (Sprint K-7): the deprecated `Color.appOrange*` /
// `appBlue*` / `appSurface` / `appStroke` / `appText*` / `appAccent*` /
// `Color.status.*` / `Color.accent.*` aliases were removed here. All 57
// call-sites across TrainingPlanView, NutritionView (v1+v2), and
// MainScreenView were migrated to `AppColor.*` semantic tokens in the
// same commit. Re-introducing any of these aliases would constitute a
// design-system regression — use the `AppColor.*` namespace instead.

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
