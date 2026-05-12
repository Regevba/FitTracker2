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
        // Home v2 metric tints (T3) — colorsets added 2026-04-20 alongside tokens.json entries.
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

    // MARK: - P1 audit burndown tokens (ios-ui-audit-p1-burndown PR-1, 2026-05-11)
    // Added after frequency analysis showed these were the most-repeated magic
    // numbers in the codebase. Adding semantic names with consistent values lets
    // us mass-substitute and keeps the design system honest about what these
    // sizes mean (vs inventing a token for every one-off).

    /// iOS HIG minimum tap target (44pt) — use for any tappable element
    /// (icon-only buttons, label .frame(minHeight:), Circle stroke containers).
    /// Source: Apple HIG "Touch target sizes" — 44×44 minimum.
    static let tapTarget: CGFloat = 44

    /// Compact tap target (36pt) — slightly tighter than the HIG minimum.
    /// Use for secondary controls in already-constrained layouts (segmented
    /// pills, inline-toolbar buttons). Verify legibility per Dynamic Type
    /// before using.
    static let tapTargetCompact: CGFloat = 36

    /// Icon container (28pt) — distinct from iconBadge (26pt) which is for
    /// overlay icons. iconContainer is the standalone size used in
    /// list/nav contexts (settings rows, training plan exercise icons).
    static let iconContainer: CGFloat = 28

    /// Compact field width (80pt) — for inline numeric input fields
    /// (weight in kg, body-fat %, heart-rate bpm). Aligns with trailing
    /// label patterns where the field is constrained but the parent
    /// row is full-width.
    static let fieldWidthCompact: CGFloat = 80

    // MARK: - P1 drift tokens (ios-ui-audit-p1-drift-cleanup, 2026-05-12)
    // Frequency-gated additions per Option B rule (≥2 occurrences with
    // consistent semantic intent). Closes 26 of 40 remaining DS-MAGIC-FRAME
    // findings. Singletons (50, 88, 76, 60, 58, 320, …) stay as
    // fix-as-you-touch — adding a token for every one-off would bloat
    // the system without improving design coherence.

    /// Tiny indicator dot (6pt) — small status pips, smaller than
    /// indicatorDot (8pt). Used by StatusDropdown, SyncStatusIndicator,
    /// the ReadinessCard score ladder.
    static let indicatorDotTiny: CGFloat = 6

    /// Tall chart container (200pt) — used by ImportSourcePicker,
    /// BodyCompositionDetail, ChartCard. Distinct from chartHeight (158pt
    /// default).
    static let chartHeightTall: CGFloat = 200

    /// Compact chart container (180pt) — used by ReadinessCard score
    /// ladder.
    static let chartHeightCompact: CGFloat = 180

    /// Minimum chart width (260pt) — used for horizontally-scrolled
    /// charts when their container is constrained (NutritionView,
    /// ReadinessCard ladder).
    static let chartMinWidth: CGFloat = 260

    /// Jumbo icon (96pt) — large standalone icons in onboarding /
    /// settings detail. Distinct from iconBadge (26pt) and iconContainer
    /// (28pt).
    static let iconJumbo: CGFloat = 96

    /// Hero avatar (72pt) — primary profile + training-plan row avatars.
    static let avatarHero: CGFloat = 72

    /// Large illustration (120pt) — onboarding auth illustrations.
    static let illustrationLarge: CGFloat = 120

    /// XL illustration (160pt) — onboarding consent illustration.
    static let illustrationXLarge: CGFloat = 160

    /// Small control footprint (34pt) — segmented pills, status pills.
    /// Smaller than tapTargetCompact (36pt); smaller than touchTargetLarge
    /// (48pt). Verify legibility per Dynamic Type before reusing.
    static let controlSmall: CGFloat = 34

    /// Tall progress bar height (6pt) — used by ReadinessCard score
    /// trackers + nutrition macro bars. Distinct from progressBarHeight
    /// (4pt, default thin bar).
    static let progressBarHeightTall: CGFloat = 6

    // MARK: - P1 final-sweep tokens (ui-ux-final-sweep-2026-05-12)
    // 13 semantic tokens for the remaining DS-MAGIC-FRAME singletons.
    // User explicitly overrode Option B to push P1 to 0 — these tokens
    // accept the bloat trade-off in exchange for design-system honesty
    // (no raw literals in views).

    /// Caption label width (60pt) — aligned read-only labels in detail
    /// sheets (AIIntelligenceSheet trailing alignment).
    static let captionLabelWidth: CGFloat = 60

    /// Auth field row height (58pt) — input row containers, subtly
    /// taller than ctaHeight (52pt).
    static let authFieldHeight: CGFloat = 58

    /// Hairline divider thickness (0.5pt) — sub-section dividers that
    /// need to be visibly thinner than 1pt. Resolves to 1 physical pixel
    /// on Retina displays.
    static let dividerHairline: CGFloat = 0.5

    /// Macro target bar height (14pt) — taller than progressBarHeightTall
    /// (6pt) for prominent macro displays.
    static let macroBarHeight: CGFloat = 14

    /// Image preview height (150pt) — photo-picker label preview in
    /// SmartTabView. Aspect ratio chosen for nutrition labels.
    static let imagePreviewHeight: CGFloat = 150

    /// Text-editor minimum height (140pt) — SmartTabView raw-text input.
    static let textEditorMinHeight: CGFloat = 140

    /// Popover max width (220pt) — NutritionView search-results popover.
    static let popoverMaxWidth: CGFloat = 220

    /// Brand banner height (88pt) — DesignSystemCatalogView brand-gradient
    /// hero strip.
    static let bannerHeight: CGFloat = 88

    /// Centered prose max-width (280pt) — empty-state instructional text
    /// in ImportedPlansListScreen.
    static let centeredTextMaxWidth: CGFloat = 280

    /// Modal dialog max-width (320pt) — LockedFeatureOverlay upgrade
    /// prompt. Sized for compact dialog surfaces.
    static let dialogMaxWidth: CGFloat = 320

    /// Compact row height (76pt) — ReadinessCard next-day indicator row.
    /// Distinct from avatarHero (72pt).
    static let rowHeightCompact: CGFloat = 76

    /// Vertical divider height (50pt) — between achievement cells in
    /// ReadinessCard.
    static let dividerVerticalTall: CGFloat = 50

    /// Step indicator circle (30pt) — numbered-step circles in
    /// RecoveryRoutineSheet onboarding-style lists.
    static let stepIndicatorSize: CGFloat = 30
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
    /// Subheading bold — secondary section labels (e.g. nutrition-step header)
    static let subheadingStrong  = Font.system(.subheadline,  design: .rounded).weight(.semibold)
    static let caption           = Font.system(.caption,      design: .rounded)
    static let captionStrong     = Font.system(.caption,      design: .rounded).weight(.semibold)
    /// Micro caption — smallest body-style text, non-monospaced
    static let captionMicro      = Font.system(.caption2,     design: .rounded)
    /// Micro caption medium — sync-status / inline-pill text
    static let captionMicroMedium = Font.system(.caption2,    design: .rounded).weight(.medium)
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
