// FitTracker/Views/Shared/AppDesignSystemComponents.swift
// Composite design system components: cards, buttons, menu rows, selection tiles, input shells.
// These are higher-level patterns that compose atomic components and tokens into reusable surfaces.
//
// Split rationale:
//   DesignSystem/AppComponents:  Atomic/molecule components (picker, filter, ring, stat row)
//   This file:                   Composite components (card, button, menu row, selection tile, input shell)
//
// Both files reference AppTheme.* only — never AppPalette or raw values.
import SwiftUI

enum AppButtonHierarchy: String, CaseIterable, Identifiable {
    case primary
    case secondary
    case tertiary
    case destructive

    var id: String { rawValue }
}

enum AppCardTone {
    case standard
    case elevated
    case quiet
    case inverse
}

struct AppCard<Content: View>: View {
    let tone: AppCardTone
    let contentPadding: CGFloat
    @ViewBuilder let content: () -> Content

    init(
        tone: AppCardTone = .standard,
        contentPadding: CGFloat = AppSpacing.medium,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.tone = tone
        self.contentPadding = contentPadding
        self.content = content
    }

    var body: some View {
        content()
            .padding(contentPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background, in: RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .shadow(color: shadowColor, radius: AppShadow.cardRadius, y: AppShadow.cardYOffset)
    }

    private var background: Color {
        switch tone {
        case .standard:
            return AppColor.Surface.materialLight
        case .elevated:
            return AppColor.Surface.elevated
        case .quiet:
            return AppColor.Surface.primary
        case .inverse:
            return AppColor.Surface.inverse
        }
    }

    private var borderColor: Color {
        switch tone {
        case .inverse:
            return AppColor.Surface.materialLight
        case .elevated:
            return AppColor.Border.subtle
        case .standard, .quiet:
            return AppColor.Border.strong.opacity(0.35)
        }
    }

    private var shadowColor: Color {
        tone == .quiet ? .clear : AppShadow.cardColor
    }
}

struct AppButton: View {
    let title: String
    var systemImage: String? = nil
    var hierarchy: AppButtonHierarchy = .primary
    var isFullWidth: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.xSmall) {
                if let systemImage {
                    Image(systemName: systemImage)
                }

                Text(title)
                    .lineLimit(1)

                if hierarchy == .primary && isFullWidth {
                    Spacer(minLength: 0)
                }
            }
            .font(AppText.button)
            .padding(.horizontal, AppSpacing.small)
            .padding(.vertical, AppSpacing.xSmall)
            .frame(maxWidth: isFullWidth ? .infinity : nil, alignment: .center)
        }
        .buttonStyle(AppHierarchyButtonStyle(hierarchy: hierarchy))
    }
}

private struct AppHierarchyButtonStyle: ButtonStyle {
    let hierarchy: AppButtonHierarchy

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foregroundColor.opacity(configuration.isPressed ? 0.88 : 1))
            .background(
                RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                    .fill(backgroundColor.opacity(configuration.isPressed ? 0.88 : 1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                    .stroke(borderColor, lineWidth: hierarchy == .tertiary ? 0 : 1)
            )
            .shadow(
                color: hierarchy == .primary ? AppShadow.ctaColor.opacity(configuration.isPressed ? 0.45 : 1) : .clear,
                radius: hierarchy == .primary ? AppShadow.ctaRadius : 0,
                y: hierarchy == .primary ? AppShadow.ctaYOffset : 0
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }

    private var backgroundColor: Color {
        switch hierarchy {
        case .primary:
            return AppColor.Accent.primary
        case .secondary:
            return AppColor.Surface.elevated
        case .tertiary:
            return .clear
        case .destructive:
            return AppColor.Status.error
        }
    }

    private var foregroundColor: Color {
        switch hierarchy {
        case .primary, .destructive:
            return AppColor.Text.primary
        case .secondary:
            return AppColor.Text.primary
        case .tertiary:
            return AppColor.Accent.primary
        }
    }

    private var borderColor: Color {
        switch hierarchy {
        case .primary:
            return AppColor.Accent.primary.opacity(0.22)
        case .secondary:
            return AppColor.Border.subtle
        case .tertiary:
            return .clear
        case .destructive:
            return AppColor.Status.error.opacity(0.18)
        }
    }
}

struct AppMenuRow: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    var tint: Color = AppColor.Accent.primary
    var trailingSystemImage: String = "chevron.right"

    var body: some View {
        HStack(spacing: AppSpacing.medium) {
            Image(systemName: icon)
                .font(AppText.callout)
                .foregroundStyle(tint)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: AppSpacing.xxxSmall) {
                Text(title)
                    .font(AppText.callout)
                    .foregroundStyle(AppColor.Text.primary)

                if let subtitle {
                    Text(subtitle)
                        .font(AppText.caption)
                        .foregroundStyle(AppColor.Text.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()

            Image(systemName: trailingSystemImage)
                .font(AppText.captionStrong)
                .foregroundStyle(AppColor.Text.tertiary)
        }
        .padding(.horizontal, AppSpacing.medium)
        .padding(.vertical, AppSpacing.medium)
        .background(AppColor.Surface.elevated, in: RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                .stroke(AppColor.Border.subtle, lineWidth: 1)
        )
    }
}

struct AppSelectionTile<Content: View>: View {
    let isSelected: Bool
    var tint: Color = AppColor.Accent.primary
    var cornerRadius: CGFloat = AppRadius.medium
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity)
            .padding(.horizontal, AppSpacing.small)
            .padding(.vertical, AppSpacing.medium)
            .background(background, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .shadow(color: isSelected ? tint.opacity(0.14) : .clear, radius: 10, y: 4)
            .animation(.easeOut(duration: 0.18), value: isSelected)
    }

    private var background: Color {
        isSelected ? tint.opacity(0.16) : AppColor.Surface.elevated
    }

    private var borderColor: Color {
        isSelected ? tint.opacity(0.40) : AppColor.Border.subtle
    }
}

struct AppFieldLabel: View {
    let title: String
    var helper: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(AppText.captionStrong)
                .textCase(.uppercase)
                .tracking(1)
                .foregroundStyle(AppColor.Text.secondary)

            if let helper {
                Text(helper)
                    .font(AppText.caption)
                    .foregroundStyle(AppColor.Text.tertiary)
            }
        }
    }
}

struct AppInputShell<Content: View>: View {
    var tint: Color = AppColor.Accent.secondary
    var isFocused: Bool = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: AppSpacing.small) {
            content()
        }
        .padding(.horizontal, AppSpacing.medium)
        .padding(.vertical, AppSpacing.medium)
        .background(AppColor.Surface.elevated, in: RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                .stroke(isFocused ? tint.opacity(0.65) : AppColor.Border.subtle, lineWidth: isFocused ? 1.5 : 1)
        )
        .shadow(color: isFocused ? tint.opacity(0.10) : .clear, radius: 10, y: 4)
    }
}

struct AppQuietButton: View {
    let title: String
    var systemImage: String? = nil
    var tint: Color = AppColor.Text.primary
    var isFullWidth: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.xSmall) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                if isFullWidth {
                    Spacer(minLength: 0)
                }
            }
            .font(AppText.button)
            .foregroundStyle(tint)
            .padding(.horizontal, AppSpacing.large)
            .padding(.vertical, AppSpacing.medium)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .background(AppColor.Surface.elevated, in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                    .stroke(AppColor.Border.subtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG
struct AppDesignSystemComponents_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: AppSpacing.large) {
                AppCard {
                    VStack(alignment: .leading, spacing: AppSpacing.small) {
                        Text("Card Surface")
                            .font(AppText.sectionTitle)
                        Text("Shared card treatments now come from the design system instead of one-off rounded rectangles.")
                            .font(AppText.subheading)
                            .foregroundStyle(AppColor.Text.secondary)
                    }
                }

                AppButton(title: "Primary Action", systemImage: "sparkles") {}
                AppButton(title: "Secondary Action", hierarchy: .secondary) {}
                AppButton(title: "Tertiary Action", hierarchy: .tertiary, isFullWidth: false) {}
                AppSelectionTile(isSelected: true) {
                    VStack(spacing: AppSpacing.xxxSmall) {
                        Text("Selected Tile")
                            .font(AppText.callout)
                        Text("Shared choice styles for pickers and mode switches.")
                            .font(AppText.caption)
                        .foregroundStyle(AppColor.Text.secondary)
                    }
                }
                AppFieldLabel(title: "Protein", helper: "Per serving")
                AppInputShell {
                    Text("Input shell")
                        .font(AppText.body)
                    Spacer()
                    Image(systemName: "eye.fill")
                        .font(AppText.callout)
                        .foregroundStyle(AppColor.Accent.secondary)
                }
                AppQuietButton(title: "Secondary Utility", systemImage: "square.and.arrow.down") {}
                AppMenuRow(
                    icon: "paintpalette.fill",
                    title: "Design System Catalog",
                    subtitle: "Preview tokens, typography, buttons, and shared components."
                )
            }
            .padding()
        }
        .background(AppGradient.screenBackground)
    }
}
#endif
