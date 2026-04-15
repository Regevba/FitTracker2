// FitTracker/DesignSystem/FitMeBrandIcon.swift
// FitMe app icon — 4 intertwined circles with gradient "FitMe" text.
// Uses the app's blue gradient palette for visual consistency.
// Updated 2026-04-15: switched from rainbow to blue gradient per brand direction.

import SwiftUI

struct FitMeBrandIcon: View {
    var size: CGFloat = 100

    // Blue gradient palette — matches AppGradient.screenBackground
    private let blue1 = Color(red: 0.875, green: 0.953, blue: 1.0)    // brand-cool-soft #DFF3FF
    private let blue2 = Color(red: 0.729, green: 0.890, blue: 1.0)    // brand-cool #BAE3FF
    private let blue3 = Color(red: 0.541, green: 0.780, blue: 1.0)    // brand-secondary #8AC7FF
    private let blue4 = Color(red: 0.400, green: 0.680, blue: 0.950)  // deeper blue accent

    private var strokeWidth: CGFloat { size * 0.06 }
    private var circleSize: CGFloat { size * 0.82 }
    private var circleOffset: CGFloat { size * 0.06 }

    var body: some View {
        ZStack {
            // 4 offset circles — intertwined petal pattern
            Circle()
                .strokeBorder(blue1, lineWidth: strokeWidth)
                .frame(width: circleSize, height: circleSize)
                .offset(x: -circleOffset, y: -circleOffset)

            Circle()
                .strokeBorder(blue2, lineWidth: strokeWidth)
                .frame(width: circleSize, height: circleSize)
                .offset(x: circleOffset, y: -circleOffset)

            Circle()
                .strokeBorder(blue3, lineWidth: strokeWidth)
                .frame(width: circleSize, height: circleSize)
                .offset(x: -circleOffset, y: circleOffset)

            Circle()
                .strokeBorder(blue4, lineWidth: strokeWidth)
                .frame(width: circleSize, height: circleSize)
                .offset(x: circleOffset, y: circleOffset)

            // Gradient "FitMe" text — blue gradient
            Text("FitMe")
                .font(.system(size: size * 0.2, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [blue3, blue4],
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
        .background(AppGradient.brand)
    }
}
#endif
