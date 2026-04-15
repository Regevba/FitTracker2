// FitTracker/DesignSystem/FitMeBrandIcon.swift
// FitMe app icon — 4 overlapping circles in a flower/petal pattern.
// Figma ref: "App Icon — 1024×1024 Master" (node 635:2)
// Circles: Blue (top-left), Teal (top-right, largest), Pink/Lavender (bottom-left), Orange (bottom-right)
// Each circle has different size and position — NOT identical circles with tiny offsets.
//
// NOTE: For pixel-perfect accuracy, export the Figma icon as PDF and add to Assets.xcassets.
// This SwiftUI approximation matches the Figma layout structurally.

import SwiftUI

struct FitMeBrandIcon: View {
    var size: CGFloat = 100

    // Figma colors from the master icon
    private let circleBlue = Color(red: 0.52, green: 0.73, blue: 1.0)        // top-left circle
    private let circleTeal = Color(red: 0.40, green: 0.85, blue: 0.78)       // top-right (largest)
    private let circlePink = Color(red: 0.82, green: 0.68, blue: 0.88)       // bottom-left
    private let circleOrange = Color(red: 0.95, green: 0.72, blue: 0.30)     // bottom-right

    // Text gradient — matches Figma: green-gold-orange
    private let textGreen = Color(red: 0.40, green: 0.78, blue: 0.55)
    private let textGold = Color(red: 0.95, green: 0.75, blue: 0.20)
    private let textBlue = Color(red: 0.52, green: 0.73, blue: 1.0)

    private var strokeWidth: CGFloat { size * 0.04 }

    var body: some View {
        ZStack {
            // Circle 1: Blue — top-left, medium size
            Circle()
                .strokeBorder(circleBlue, lineWidth: strokeWidth)
                .frame(width: size * 0.72, height: size * 0.72)
                .offset(x: -size * 0.08, y: -size * 0.10)

            // Circle 2: Teal — top-right, largest, dominant
            Circle()
                .strokeBorder(circleTeal, lineWidth: strokeWidth)
                .frame(width: size * 0.90, height: size * 0.90)
                .offset(x: size * 0.06, y: -size * 0.02)

            // Circle 3: Pink/Lavender — bottom-left, medium
            Circle()
                .strokeBorder(circlePink, lineWidth: strokeWidth)
                .frame(width: size * 0.78, height: size * 0.78)
                .offset(x: -size * 0.12, y: size * 0.08)

            // Circle 4: Orange — bottom-right, smaller
            Circle()
                .strokeBorder(circleOrange, lineWidth: strokeWidth)
                .frame(width: size * 0.65, height: size * 0.65)
                .offset(x: size * 0.14, y: size * 0.14)

            // "FitMe" text with gradient
            Text("FitMe")
                .font(.system(size: size * 0.18, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [textGreen, textGold, textBlue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .offset(x: size * 0.02, y: size * 0.02)
        }
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
        VStack(spacing: AppSpacing.large) {
            FitMeBrandIcon.small
            FitMeBrandIcon.medium
            FitMeBrandIcon.large
            FitMeBrandIcon.hero
        }
        .padding()
        .background(AppGradient.brand)
    }
}
#endif
