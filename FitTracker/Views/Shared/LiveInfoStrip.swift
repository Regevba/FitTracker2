// FitTracker/Views/Shared/LiveInfoStrip.swift
// Reusable animated info strip that cycles through contextual slides.
import SwiftUI

struct InfoSlide: Identifiable {
    let id = UUID()
    let text: String
    var icon: String?
    var color: Color?
}

struct LiveInfoStrip: View {

    let slides: [InfoSlide]
    var cycleDuration: UInt64 = 5

    @State private var currentIndex = 0
    @State private var isPaused = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if slides.isEmpty {
                EmptyView()
            } else if reduceMotion || slides.count == 1 {
                slideView(slides[0])
            } else {
                slideView(slides[currentIndex])
                    .id(currentIndex)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: AppDuration.standard), value: currentIndex)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isPaused = true
            Task {
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                isPaused = false
            }
        }
        .task {
            guard slides.count > 1, !reduceMotion else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: cycleDuration * 1_000_000_000)
                guard !isPaused else { continue }
                withAnimation {
                    currentIndex = (currentIndex + 1) % slides.count
                }
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
            LiveInfoStrip(slides: [
                InfoSlide(text: "Good evening, Regev 🌙"),
                InfoSlide(text: "78 — Ready to train", icon: "heart.fill", color: AppColor.Status.success),
                InfoSlide(text: "🔥 7-day streak", color: AppColor.Brand.primary),
            ])
        }
        .padding()
        .background(AppGradient.screenBackground)
    }
}
#endif
