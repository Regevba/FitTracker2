// FitTracker/DesignSystem/FitMeLogoLoader.swift
// Branded loading/status indicator using the Figma-exported FitMe icon.
// Supports 4 animation modes × 3 sizes. Respects reduce-motion accessibility.
// Uses Image("FitMeAppIcon") — the same PDF asset as FitMeBrandIcon.
import SwiftUI

struct FitMeLogoLoader: View {

    enum Mode { case breathe, rotate, pulse, shimmer }
    enum Size: CGFloat {
        case small  = 24
        case medium = 44
        case large  = 72
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
            Image("FitMeAppIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size.rawValue, height: size.rawValue)
                .scaleEffect(scaleValue)
                .rotationEffect(.degrees(rotationValue))
                .opacity(opacityValue)

            if let message {
                Text(message)
                    .font(AppText.caption)
                    .foregroundStyle(AppColor.Text.secondary)
            }
        }
        .accessibilityLabel("FitMe")
        .onAppear { startAnimation() }
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
        VStack(spacing: AppSpacing.large) {
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
