// FitTracker/DesignSystem/FitMeLogoLoader.swift
// Branded loading indicator using the FitMe intertwined-circles logo.
// Supports 4 animation modes × 3 sizes. Respects reduce-motion accessibility.
import SwiftUI

struct FitMeLogoLoader: View {

    enum Mode { case breathe, rotate, pulse, shimmer }
    enum Size: CGFloat {
        case small  = 24
        case medium = 44
        case large  = 72

        var strokeWidth: CGFloat {
            switch self {
            case .small:  return 2
            case .medium: return 3
            case .large:  return 4
            }
        }

        var showText: Bool { self == .large }
    }

    let mode: Mode
    var size: Size = .medium
    var message: String?

    @State private var isAnimating = false
    @State private var rotationAngle: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Body

    var body: some View {
        VStack(spacing: size == .large ? AppSpacing.xSmall : AppSpacing.xxxSmall) {
            ZStack {
                // Outer ring (pink/magenta)
                Circle()
                    .stroke(
                        Color(red: 0.90, green: 0.00, blue: 0.49), // #E6007E magenta
                        lineWidth: size.strokeWidth
                    )
                    .frame(width: size.rawValue, height: size.rawValue)

                // Inner ring with organic wave (brand orange gradient)
                innerRing
                    .frame(width: size.rawValue * 0.82, height: size.rawValue * 0.82)

                // Center text (large size only)
                if size.showText {
                    VStack(spacing: 0) {
                        Text("FIT")
                            .font(.system(size: size.rawValue * 0.18, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 0.90, green: 0.00, blue: 0.49))
                        Text("ME")
                            .font(.system(size: size.rawValue * 0.18, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColor.Brand.primary)
                    }
                }
            }
            .scaleEffect(scaleValue)
            .rotationEffect(.degrees(rotationValue))
            .opacity(opacityValue)

            if let message {
                Text(message)
                    .font(AppText.caption)
                    .foregroundStyle(AppColor.Text.secondary)
            }
        }
        .onAppear { startAnimation() }
    }

    // MARK: - Inner ring (orange gradient with organic wave shape)

    private var innerRing: some View {
        ZStack {
            // Base circle
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [AppColor.Brand.primary, AppColor.Brand.warm],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: size.strokeWidth
                )

            // Organic wave overlay (simplified S-curve using an offset ellipse)
            Ellipse()
                .stroke(
                    LinearGradient(
                        colors: [AppColor.Brand.primary.opacity(0.6), AppColor.Brand.warm.opacity(0.3)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: size.strokeWidth * 0.8
                )
                .scaleEffect(x: 0.7, y: 1.1)
                .rotationEffect(.degrees(25))
        }
    }

    // MARK: - Animation values

    private var scaleValue: CGFloat {
        switch mode {
        case .breathe: return isAnimating ? 1.08 : 0.92
        case .pulse:   return isAnimating ? 1.15 : 1.0
        case .rotate, .shimmer: return 1.0
        }
    }

    private var rotationValue: Double {
        mode == .rotate ? rotationAngle : 0
    }

    private var opacityValue: Double {
        mode == .shimmer ? (isAnimating ? 1.0 : 0.4) : 1.0
    }

    // MARK: - Start animation

    private func startAnimation() {
        guard !reduceMotion else {
            // Reduce-motion fallback: subtle static opacity
            isAnimating = true
            return
        }

        switch mode {
        case .breathe:
            withAnimation(AppLoadingAnimation.breathe) {
                isAnimating = true
            }
        case .rotate:
            withAnimation(AppLoadingAnimation.rotate) {
                rotationAngle = 360
            }
        case .pulse:
            withAnimation(AppLoadingAnimation.confirmPulse) {
                isAnimating = true
            }
            // Reset after pulse completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                isAnimating = false
            }
        case .shimmer:
            withAnimation(AppLoadingAnimation.shimmer) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct FitMeLogoLoader_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: AppSpacing.xLarge) {
            HStack(spacing: AppSpacing.large) {
                FitMeLogoLoader(mode: .breathe, size: .small)
                FitMeLogoLoader(mode: .rotate, size: .small)
                FitMeLogoLoader(mode: .shimmer, size: .small)
            }

            HStack(spacing: AppSpacing.large) {
                FitMeLogoLoader(mode: .breathe, size: .medium, message: "Loading...")
                FitMeLogoLoader(mode: .rotate, size: .medium, message: "Syncing...")
            }

            FitMeLogoLoader(mode: .breathe, size: .large, message: "Calculating readiness...")
        }
        .padding()
        .background(AppGradient.screenBackground)
    }
}
#endif
