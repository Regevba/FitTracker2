// FitTracker/Views/Shared/LiveInfoStrip.swift
// Reusable animated info strip that cycles through contextual slides.
// Used in the Home screen greeting area to rotate between greeting,
// readiness score, supplement streak, and other contextual info.
import SwiftUI
import Combine

struct InfoSlide: Identifiable {
    let id = UUID()
    let text: String
    var icon: String?       // SF Symbol name
    var color: Color?       // accent color for the text/icon
}

struct LiveInfoStrip: View {

    let slides: [InfoSlide]
    var cycleDuration: TimeInterval = 5.0

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
        .onTapGesture { pauseAndResume() }
        .onReceive(timer) { _ in
            guard !isPaused, slides.count > 1, !reduceMotion else { return }
            withAnimation {
                currentIndex = (currentIndex + 1) % slides.count
            }
        }
    }

    private var timer: Publishers.Autoconnect<Timer.TimerPublisher> {
        Timer.publish(every: cycleDuration, on: .main, in: .common).autoconnect()
    }

    private func slideView(_ slide: InfoSlide) -> some View {
        HStack(spacing: AppSpacing.xxSmall) {
            if let icon = slide.icon {
                Image(systemName: icon)
                    .font(AppText.callout)
                    .foregroundStyle(slide.color ?? AppColor.Text.primary)
            }
            Text(slide.text)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(slide.color ?? AppColor.Text.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 34)
    }

    private func pauseAndResume() {
        isPaused = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            isPaused = false
        }
    }
}

#if DEBUG
struct LiveInfoStrip_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: AppSpacing.large) {
            LiveInfoStrip(slides: [
                InfoSlide(text: "Good evening, Regev 🌙"),
                InfoSlide(text: "78 — Ready to train", icon: "heart.fill", color: AppColor.Status.success),
                InfoSlide(text: "🔥 7-day supplement streak", color: AppColor.Brand.primary),
            ])
        }
        .padding()
        .background(AppGradient.screenBackground)
    }
}
#endif
