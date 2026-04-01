// FitTracker/Views/Shared/LiveInfoStrip.swift
// Reusable animated info strip that cycles through contextual slides.
// Used in the Home screen greeting area to rotate between greeting,
// readiness score, supplement streak, and other contextual info.
//
// Features:
// - Auto-cycles through slides with configurable timing (default 5s)
// - Cross-fade animation between slides
// - Pauses on user tap (resumes after 10s)
// - Respects reduce-motion accessibility (shows first slide only)
// - Supports manual swipe via TabView paging
import SwiftUI

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
    @State private var timer: Timer?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if slides.isEmpty {
                EmptyView()
            } else if reduceMotion || slides.count == 1 {
                // Static: show first slide only
                slideView(slides[0])
            } else {
                // Animated cycling
                slideView(slides[currentIndex])
                    .id(currentIndex) // force view identity change for transition
                    .transition(.opacity)
                    .animation(.easeInOut(duration: AppDuration.standard), value: currentIndex)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { pauseAndResume() }
        .onAppear { startTimer() }
        .onDisappear { stopTimer() }
    }

    // MARK: - Slide view

    private func slideView(_ slide: InfoSlide) -> some View {
        HStack(spacing: AppSpacing.xxSmall) {
            if let icon = slide.icon {
                Image(systemName: icon)
                    .font(AppText.callout)
                    .foregroundStyle(slide.color ?? AppColor.Text.primary)
            }
            Text(slide.text)
                .font(.system(size: 26, weight: .bold, design: .rounded)) // responsive — matches greeting size
                .foregroundStyle(slide.color ?? AppColor.Text.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 34) // stable height prevents layout shift
    }

    // MARK: - Timer

    private func startTimer() {
        guard slides.count > 1, !reduceMotion else { return }
        timer = Timer.scheduledTimer(withTimeInterval: cycleDuration, repeats: true) { _ in
            guard !isPaused else { return }
            withAnimation {
                currentIndex = (currentIndex + 1) % slides.count
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func pauseAndResume() {
        isPaused = true
        // Resume after 10 seconds of no interaction
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            isPaused = false
        }
    }
}

// MARK: - Preview

#if DEBUG
struct LiveInfoStrip_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: AppSpacing.large) {
            LiveInfoStrip(slides: [
                InfoSlide(text: "Good evening, Regev 🌙"),
                InfoSlide(text: "78 — Ready to train", icon: "heart.fill", color: AppColor.Status.success),
                InfoSlide(text: "🔥 7-day supplement streak", color: AppColor.Brand.primary),
            ])

            LiveInfoStrip(slides: [
                InfoSlide(text: "Single slide only"),
            ])
        }
        .padding()
        .background(AppGradient.screenBackground)
    }
}
#endif
