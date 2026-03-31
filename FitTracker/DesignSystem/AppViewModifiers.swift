// FitTracker/DesignSystem/AppViewModifiers.swift
// Shared ViewModifiers for the FitTracker design system.
// Apply these to reduce repetition at call sites.
import SwiftUI

// MARK: - .appEyebrowStyle()
// Consolidates the 4+ repeating pattern: .captionStrong + .uppercase + .tracking(1.6)
// Used for section labels, category eyebrows, "MEALS", "TRAINING", etc.
private struct AppEyebrowModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(AppText.eyebrow)
            .textCase(.uppercase)
            .tracking(1.6)
            .foregroundStyle(AppColor.Text.tertiary)
    }
}

extension View {
    func appEyebrowStyle() -> some View {
        modifier(AppEyebrowModifier())
    }
}

// MARK: - .appTextRole(_ role:)
// Applies both font AND foreground color in one call, following IBM Carbon pattern.
enum AppTextRole {
    case primary
    case secondary
    case tertiary
    case inversePrimary
    case inverseSecondary
    case accent
    case success
    case warning
    case error

    var font: Font {
        switch self {
        case .primary:        return AppText.body
        case .secondary:      return AppText.bodyRegular
        case .tertiary:       return AppText.caption
        case .inversePrimary: return AppText.body
        case .inverseSecondary: return AppText.bodyRegular
        case .accent:         return AppText.callout
        case .success, .warning, .error: return AppText.captionStrong
        }
    }

    var color: Color {
        switch self {
        case .primary:          return AppColor.Text.primary
        case .secondary:        return AppColor.Text.secondary
        case .tertiary:         return AppColor.Text.tertiary
        case .inversePrimary:   return AppColor.Text.inversePrimary
        case .inverseSecondary: return AppColor.Text.inverseSecondary
        case .accent:           return AppColor.Accent.primary
        case .success:          return AppColor.Status.success
        case .warning:          return AppColor.Status.warning
        case .error:            return AppColor.Status.error
        }
    }
}

private struct AppTextRoleModifier: ViewModifier {
    let role: AppTextRole

    func body(content: Content) -> some View {
        content
            .font(role.font)
            .foregroundStyle(role.color)
    }
}

extension View {
    func appTextRole(_ role: AppTextRole) -> some View {
        modifier(AppTextRoleModifier(role: role))
    }
}

// MARK: - .appReducedMotion(_:value:)
// Wraps reduce motion check: applies animation only if reduce motion is off.
private struct AppReducedMotionModifier<V: Equatable>: ViewModifier {
    let animation: Animation
    let value: V

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? .none : animation, value: value)
    }
}

extension View {
    func appReducedMotion<V: Equatable>(_ animation: Animation, value: V) -> some View {
        modifier(AppReducedMotionModifier(animation: animation, value: value))
    }
}

// MARK: - .appCardStyle()
// Standard card container: surface background + corner radius + shadow
private struct AppCardStyleModifier: ViewModifier {
    let density: AppCardDensity

    func body(content: Content) -> some View {
        content
            .padding(density.padding)
            .background(AppColor.Surface.primary, in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
            .shadow(color: AppShadow.cardColor, radius: AppShadow.cardRadius, y: AppShadow.cardYOffset)
    }
}

enum AppCardDensity {
    case compact, `default`, spacious

    var padding: CGFloat {
        switch self {
        case .compact:  return AppSpacing.xSmall  // 12
        case .default:  return AppSpacing.small    // 16
        case .spacious: return AppSpacing.medium   // 20
        }
    }
}

extension View {
    func appCardStyle(density: AppCardDensity = .default) -> some View {
        modifier(AppCardStyleModifier(density: density))
    }
}

// MARK: - .appSectionBackground()
// Blended background for screen sections (ultraThinMaterial equivalent in token system)
private struct AppSectionBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                    .stroke(AppColor.Border.subtle, lineWidth: 1)
            )
    }
}

extension View {
    func appSectionBackground() -> some View {
        modifier(AppSectionBackgroundModifier())
    }
}
