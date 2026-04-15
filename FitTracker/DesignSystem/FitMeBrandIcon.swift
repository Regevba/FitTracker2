// FitTracker/DesignSystem/FitMeBrandIcon.swift
// FitMe app icon — rendered from Figma-exported PDF asset.
// Figma ref: "App Icon — 1024×1024 Master" (node 635:2)
// Asset: FitMeAppIcon (Assets.xcassets/Images/FitMeAppIcon.imageset/FitmeIcon.pdf)
//
// Supports two rendering modes:
//   .original — full-color Figma icon (default)
//   .template — shape only, colored by foregroundStyle (used on Welcome screen)

import SwiftUI

struct FitMeBrandIcon: View {
    var size: CGFloat = 100
    var renderingMode: Image.TemplateRenderingMode = .original

    var body: some View {
        Image("FitMeAppIcon")
            .renderingMode(renderingMode)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .accessibilityLabel("FitMe logo")
    }
}

// MARK: - Convenience sizes

extension FitMeBrandIcon {
    static var small: FitMeBrandIcon { FitMeBrandIcon(size: 44) }
    static var medium: FitMeBrandIcon { FitMeBrandIcon(size: 72) }
    static var large: FitMeBrandIcon { FitMeBrandIcon(size: 120) }
    static var hero: FitMeBrandIcon { FitMeBrandIcon(size: 180) }
}

#if DEBUG
struct FitMeBrandIcon_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            FitMeBrandIcon.small
            FitMeBrandIcon.medium
            FitMeBrandIcon.large
            FitMeBrandIcon(size: 180, renderingMode: .template)
                .foregroundStyle(AppGradient.brand)
        }
        .padding()
        .background(AppGradient.screenBackground)
    }
}
#endif
