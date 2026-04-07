// FitTracker/DesignSystem/FitMeBrandIcon.swift
// FitMe app icon — 4 intertwined circles with gradient "FitMe" text.
// Figma ref: "App Icon — 1024×1024 Master" (node 635:2)
// Colors: Pink #F5B8E8, Yellow #FFBD12, Blue #85D6FF, Teal #33E0C2
// Use this for onboarding, auth, about screens, and anywhere the brand icon appears.

import SwiftUI

struct FitMeBrandIcon: View {
    var size: CGFloat = 100

    // Figma icon colors
    private let pink = Color(red: 0.96, green: 0.72, blue: 0.91)   // #F5B8E8
    private let yellow = Color(red: 1.0, green: 0.74, blue: 0.07)  // #FFBD12
    private let blue = Color(red: 0.52, green: 0.84, blue: 1.0)    // #85D6FF
    private let teal = Color(red: 0.2, green: 0.88, blue: 0.76)    // #33E0C2

    private var strokeWidth: CGFloat { size * 0.035 }
    private var circleSize: CGFloat { size * 0.96 }
    private var offset: CGFloat { size * 0.012 }

    var body: some View {
        ZStack {
            // 4 slightly offset circles — creates the intertwined organic feel
            Circle()
                .strokeBorder(pink, lineWidth: strokeWidth)
                .frame(width: circleSize, height: circleSize)
                .offset(x: -offset, y: -offset)

            Circle()
                .strokeBorder(yellow, lineWidth: strokeWidth)
                .frame(width: circleSize, height: circleSize)
                .offset(x: offset, y: -offset)

            Circle()
                .strokeBorder(blue, lineWidth: strokeWidth)
                .frame(width: circleSize, height: circleSize)
                .offset(x: -offset, y: offset)

            Circle()
                .strokeBorder(teal, lineWidth: strokeWidth)
                .frame(width: circleSize, height: circleSize)
                .offset(x: offset, y: offset)

            // Gradient "FitMe" text
            Text("FitMe")
                .font(.system(size: size * 0.2, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.55, blue: 0.0),   // Orange
                            Color(red: 1.0, green: 0.74, blue: 0.07),  // Yellow
                            Color(red: 0.2, green: 0.88, blue: 0.76),  // Teal
                            Color(red: 0.52, green: 0.84, blue: 1.0),  // Blue
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
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
    }
}
#endif
