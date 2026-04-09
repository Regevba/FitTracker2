// FitTracker/Views/Training/v2/SessionCompletionSheet.swift
// Post-session summary sheet — celebrates completion (Celebration Not Guilt),
// shows key stats, and offers share/done actions.
import SwiftUI

struct SessionCompletionSheet: View {
    let log: DailyLog?
    let selectedDay: DayType
    let previousLog: DailyLog?
    let streak: Int
    let onShare: () -> Void
    let onDone: () -> Void

    @EnvironmentObject private var analytics: AnalyticsService

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.medium) {
                    headerSection
                    encouragementText
                    statsGrid
                    Divider()
                        .padding(.horizontal, AppSpacing.small)
                    actionButtons
                }
                .padding(.horizontal, AppSpacing.large)
                .padding(.bottom, AppSpacing.xLarge)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            fireCompletionAnalytics()
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.success)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: AppSpacing.xxSmall) {
            Image(systemName: "checkmark.seal.fill")
                .font(AppText.iconLarge)
                .foregroundStyle(AppColor.Status.success)
                .accessibilityHidden(true)

            Text("Session Complete!")
                .font(AppText.pageTitle)
                .foregroundStyle(AppColor.Text.primary)
                .accessibilityAddTraits(.isHeader)

            Text(selectedDay.rawValue)
                .font(AppText.subheading)
                .foregroundStyle(AppColor.Text.secondary)
        }
        .padding(.top, AppSpacing.xxSmall)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Session complete. \(selectedDay.rawValue)")
    }

    // MARK: - Encouragement (Celebration Not Guilt)

    private var encouragementText: some View {
        Text(completionMessage)
            .font(AppText.subheading)
            .foregroundStyle(AppColor.Text.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, AppSpacing.xxSmall)
            .accessibilityLabel(completionMessage)
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: AppSpacing.xSmall
        ) {
            statTile(
                icon: "clock.fill",
                label: "Duration",
                value: durationStr,
                color: AppColor.Accent.sleep
            )
            statTile(
                icon: "checkmark.circle.fill",
                label: "Exercises",
                value: exerciseCountStr,
                color: AppColor.Status.success
            )
            statTile(
                icon: "number",
                label: "Total Sets",
                value: totalSetsStr,
                color: AppColor.Accent.primary
            )
            statTile(
                icon: "scalemass.fill",
                label: "Volume",
                value: totalVolumeStr,
                color: AppColor.Accent.recovery
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Session statistics")
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Stat Tile

    @ViewBuilder
    private func statTile(
        icon: String,
        label: String,
        value: String,
        color: Color
    ) -> some View {
        VStack(spacing: AppSpacing.xxSmall) {
            HStack(spacing: AppSpacing.xxSmall) {
                Image(systemName: icon)
                    .font(AppText.captionStrong)
                    .foregroundStyle(color)
                    .accessibilityHidden(true)
                Text(label)
                    .font(AppText.caption)
                    .foregroundStyle(AppColor.Text.secondary)
            }
            Text(value)
                .font(AppText.titleStrong)
                .foregroundStyle(AppColor.Text.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.xSmall)
        .background(
            AppColor.Surface.secondary,
            in: RoundedRectangle(cornerRadius: AppRadius.small)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: AppSpacing.xSmall) {
            Button(action: onShare) {
                Label("Share", systemImage: "square.and.arrow.up")
                    .font(AppText.button)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.xSmall)
                    .background(
                        AppColor.Surface.secondary,
                        in: RoundedRectangle(cornerRadius: AppRadius.button)
                    )
                    .foregroundStyle(AppColor.Text.primary)
            }
            .buttonStyle(.plain)
            .frame(minHeight: 44)
            .accessibilityLabel("Share session summary")
            .accessibilityHint("Opens share sheet with your workout results")

            Button(action: onDone) {
                Text("Done")
                    .font(AppText.sectionTitle)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.xSmall)
                    .foregroundStyle(AppColor.Text.inversePrimary)
                    .background(
                        AppColor.Status.success,
                        in: RoundedRectangle(cornerRadius: AppRadius.button)
                    )
            }
            .buttonStyle(.plain)
            .frame(minHeight: 44)
            .accessibilityLabel("Dismiss session summary")
            .accessibilityHint("Closes the completion sheet and returns to training")
        }
    }

    // MARK: - Analytics

    private func fireCompletionAnalytics() {
        let durationSeconds: Int = {
            guard let start = log?.sessionStartTime else { return 0 }
            return max(0, Int(Date().timeIntervalSince(start)))
        }()
        analytics.logTrainingSessionCompleted(
            sessionDurationSeconds: durationSeconds,
            totalSets: totalSets,
            exerciseCount: exerciseCount
        )
    }

    // MARK: - Computed Helpers

    private var exerciseCount: Int {
        let total = TrainingProgramData.exercises(for: selectedDay).count
        let done = log?.taskStatuses.values.filter { $0 == .completed }.count ?? 0
        return min(done, total)
    }

    private var exerciseCountStr: String {
        let total = TrainingProgramData.exercises(for: selectedDay).count
        return "\(exerciseCount)/\(total)"
    }

    private var totalSets: Int {
        log?.exerciseLogs.values.reduce(0) { sum, exLog in
            sum + exLog.sets.filter { $0.weightKg != nil || $0.repsCompleted != nil }.count
        } ?? 0
    }

    private var totalSetsStr: String {
        totalSets > 0 ? "\(totalSets)" : "—"
    }

    private var totalVolume: Double {
        log?.exerciseLogs.values.map(\.totalVolume).reduce(0, +) ?? 0
    }

    private var totalVolumeStr: String {
        totalVolume > 0 ? "\(Int(totalVolume)) kg" : "—"
    }

    private var durationStr: String {
        guard let start = log?.sessionStartTime else { return "—" }
        let minutes = max(0, Int(Date().timeIntervalSince(start) / 60))
        if minutes >= 60 {
            let h = minutes / 60
            let m = minutes % 60
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
        return minutes > 0 ? "\(minutes) min" : "< 1 min"
    }

    private var firstPRExerciseName: String? {
        guard let exLogs = log?.exerciseLogs,
              let prevExLogs = previousLog?.exerciseLogs else { return nil }
        let bestEntry = exLogs
            .filter { exerciseID, current in
                guard let best = current.bestSet?.weightKg,
                      let prevBest = prevExLogs[exerciseID]?.bestSet?.weightKg
                else { return false }
                return best > prevBest
            }
            .max { a, b in
                let aGain = (a.value.bestSet?.weightKg ?? 0)
                    - (prevExLogs[a.key]?.bestSet?.weightKg ?? 0)
                let bGain = (b.value.bestSet?.weightKg ?? 0)
                    - (prevExLogs[b.key]?.bestSet?.weightKg ?? 0)
                return aGain < bGain
            }
        return bestEntry.map { exerciseID, _ in
            TrainingProgramData.allExercises
                .first { $0.id == exerciseID }?.name ?? exerciseID
        }
    }

    /// Encouraging, never guilt-inducing. Matches Celebration Not Guilt principle.
    private var completionMessage: String {
        if previousLog == nil {
            return "That's day one. The hardest one."
        }
        if let name = firstPRExerciseName {
            return "New record on \(name). You're stronger than last week."
        }
        if streak >= 7 {
            return "\(streak) days straight. Consistency beats intensity every time."
        }
        return "Good work. Come back stronger."
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Session Complete") {
    SessionCompletionSheet(
        log: nil,
        selectedDay: .upperPush,
        previousLog: nil,
        streak: 3,
        onShare: {},
        onDone: {}
    )
    .environmentObject(AnalyticsService.makeDefault())
}
#endif
