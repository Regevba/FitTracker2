// FitTracker/Views/Shared/LiveInfoStrip.swift
// Static info strip that displays the highest-priority contextual slide.
// Callers pass pre-prioritised slides; only the first element is shown.
import SwiftUI

struct InfoSlide: Identifiable {
    let id = UUID()
    let text: String
    var icon: String?
    var color: Color?
}

struct LiveInfoStrip: View {

    let slides: [InfoSlide]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if let slide = slides.first {
                slideView(slide)
                    .accessibilityLabel(slide.text)
            } else {
                EmptyView()
            }
        }
    }

    private func slideView(_ slide: InfoSlide) -> some View {
        HStack(spacing: AppSpacing.xxSmall) {
            if let icon = slide.icon {
                Image(systemName: icon)
                    .font(AppText.callout)
                    .foregroundStyle(slide.color ?? AppColor.Text.primary)
            }
            Text(slide.text)
                .font(AppText.hero)
                .foregroundStyle(slide.color ?? AppColor.Text.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 34)
    }
}

#if DEBUG
struct LiveInfoStrip_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: AppSpacing.large) {
            // Multiple slides passed — only the first is displayed.
            LiveInfoStrip(slides: [
                InfoSlide(text: "Good evening, Regev 🌙"),
                InfoSlide(text: "78 — Ready to train", icon: "heart.fill", color: AppColor.Status.success),
                InfoSlide(text: "🔥 7-day streak", color: AppColor.Brand.primary),
            ])

            // Single slide.
            LiveInfoStrip(slides: [
                InfoSlide(text: "Welcome back!", icon: "hand.wave", color: AppColor.Brand.primary),
            ])

            // Empty slides — renders nothing.
            LiveInfoStrip(slides: [])
        }
        .padding()
        .background(AppGradient.screenBackground)
    }
}
#endif
