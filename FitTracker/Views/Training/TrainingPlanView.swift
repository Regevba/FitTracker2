// Views/Training/TrainingPlanView.swift
// Tab 2: Training Plan
//   - Today's session breakdown by section
//   - Per-exercise: set × reps × weight logging
//   - Elliptical + Rowing: full cardio log + photo capture of machine summary screen

import SwiftUI
import PhotosUI

// ─────────────────────────────────────────────────────────
// MARK: – Training Plan Root View
// ─────────────────────────────────────────────────────────

struct TrainingPlanView: View {

    @EnvironmentObject var dataStore:    EncryptedDataStore
    @EnvironmentObject var programStore: TrainingProgramStore

    private let initialDay: DayType?
    @State private var selectedDay: DayType = .restDay
    @State private var activeDate: Date = Date()
    @State private var log: DailyLog?
    @State private var showCompletionSheet = false
    @State private var showNotesEditor     = false
    @State private var showFocusMode       = false
    @State private var focusedExerciseID: String?
    @State private var restTimerEnd: Date?
    @State private var restPresetSeconds = 90
    @State private var didHapticAt10 = false
    @State private var didHapticAt0 = false
    init(initialDay: DayType? = nil) {
        self.initialDay = initialDay
    }

    var body: some View {
        ZStack {
            AppGradient.screenBackground
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    weekStrip
                    sessionPicker
                    sessionOverviewBlock
                    exerciseQueueStrip
                    exerciseSections
                }
                .padding(.horizontal, AppSpacing.small)
                .padding(.bottom, AppSpacing.xxLarge)
            }

            // Floating rest timer — bottom-right corner, safe-area aware
            GeometryReader { geo in
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        floatingRestTimer
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    .padding(.bottom, geo.safeAreaInsets.bottom + 56)
                    .padding(.trailing, AppSpacing.small)
                }
            }
            .allowsHitTesting(restTimerEnd != nil)
            .animation(.spring(response: 0.35), value: restTimerEnd != nil)
        }
        .navigationTitle("Training Plan")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            activeDate = Calendar.current.startOfDay(for: Date())
            loadLog(for: activeDate, preferredDay: initialDay ?? programStore.todayDayType)
        }
        .onDisappear {
            // Persist on disappear; the scene .background handler in FitTrackerApp
            // ensures this reaches disk even if the app is about to be suspended.
            saveLog()
        }
        .onChange(of: taskStatusSignature) { _, _ in
            guard let log else { return }
            let exercises = TrainingProgramData.exercises(for: selectedDay)
            syncFocusedExercise()
            guard !exercises.isEmpty else { return }
            let allDone = exercises.allSatisfy { log.taskStatuses[$0.id] == .completed }
            if allDone && !showCompletionSheet {
                showCompletionSheet = true
            }
        }
        .onChange(of: selectedDay) { _, _ in
            syncFocusedExercise()
            restPresetSeconds = focusedExercise?.restSeconds ?? 90
        }
        .sheet(isPresented: $showCompletionSheet) {
            SessionCompletionSheet(
                log: log,
                selectedDay: selectedDay,
                previousLog: previousSameDayLog,
                streak: dataStore.supplementStreak,
                onDone: { showCompletionSheet = false },
                onLogNotes: { showCompletionSheet = false; showNotesEditor = true }
            )
            .presentationDetents([.medium, .large])
            .presentationCornerRadius(AppSheet.standardCornerRadius)
        }
        .sheet(isPresented: $showNotesEditor) {
            NotesEditorSheet(notes: Binding(
                get: { log?.notes ?? "" },
                set: { log?.notes = $0; saveLog() }
            ), onDone: { showNotesEditor = false })
            .presentationDetents([.medium])
            .presentationCornerRadius(20)
        }
        .fullScreenCover(isPresented: $showFocusMode) {
            if let exercise = focusedExercise {
                FocusModeView(
                    exercise: exercise,
                    exerciseLog: Binding(
                        get: { log?.exerciseLogs[exercise.id] ?? ExerciseLog(exerciseID: exercise.id, exerciseName: exercise.name) },
                        set: {
                            log?.exerciseLogs[exercise.id] = $0
                        }
                    ),
                    onExit: { showFocusMode = false }
                )
            }
        }
    }

    // ─────────────────────────────────────────────────────
    // Week strip (Mon–Sun)
    // ─────────────────────────────────────────────────────

    private var weekStrip: some View {
        let calendar = Calendar.current
        // Build Mon–Sun for the week containing today
        let today = Date()
        let weekday = calendar.component(.weekday, from: today) // 1=Sun … 7=Sat
        // Days offset so Monday is first
        let daysFromMonday = (weekday + 5) % 7   // Mon=0, Tue=1 … Sun=6
        let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: calendar.startOfDay(for: today)) ?? calendar.startOfDay(for: today)
        let weekDays = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }

        return HStack(spacing: 0) {
            ForEach(weekDays, id: \.self) { day in
                let wday    = calendar.component(.weekday, from: day)
                let isToday = calendar.isDateInToday(day)
                let isActive = calendar.isDate(day, inSameDayAs: activeDate)
                let isRest  = TrainingProgramStore.restWeekdays.contains(wday)
                let hasLog  = dataStore.dailyLogs.first {
                    calendar.isDate($0.date, inSameDayAs: day)
                }.map { $0.completionPct > 0 } ?? false

                VStack(spacing: 4) {
                    Text(day.formatted(.dateTime.weekday(.abbreviated)))
                        .font(AppType.caption)
                        .foregroundStyle(isActive ? AppColor.Text.primary : AppColor.Text.secondary)

                    ZStack {
                        if isToday {
                            Circle()
                                .fill(Color.appOrange1)
                                .frame(width: 28, height: 28)
                        } else if isActive {
                            Circle()
                                .fill(Color.white.opacity(0.25))
                                .frame(width: 28, height: 28)
                        }
                        Text("\(calendar.component(.day, from: day))")
                            .font(isToday ? AppType.body : AppType.subheading)
                            .fontWeight(isToday ? .bold : .regular)
                            .foregroundStyle(isToday ? Color.black : AppColor.Text.primary)
                    }

                    // Completion dot
                    Circle()
                        .fill(hasLog ? Color.status.success : Color.clear)
                        .frame(width: 5, height: 5)
                }
                .opacity(isRest && !hasLog ? 0.4 : 1.0)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    saveLog()
                    activeDate = day
                    let suggested = TrainingProgramStore.dayType(forWeekday: wday)
                    withAnimation(.easeInOut(duration: 0.2)) {
                        loadLog(for: day, preferredDay: suggested)
                    }
                }
            }
        }
        .padding(.vertical, AppSpacing.xxSmall)
    }

    // ─────────────────────────────────────────────────────
    // Session summary header
    // ─────────────────────────────────────────────────────

    private var exercisesForSelectedDay: [ExerciseDefinition] {
        TrainingProgramData.exercises(for: selectedDay)
    }

    private var focusedExercise: ExerciseDefinition? {
        if let focusedExerciseID,
           let selected = exercisesForSelectedDay.first(where: { $0.id == focusedExerciseID }) {
            return selected
        }
        return nextExercise
    }

    private var nextExercise: ExerciseDefinition? {
        exercisesForSelectedDay.first { (log?.taskStatuses[$0.id] ?? .pending) != .completed }
    }

    private var taskStatusSignature: [String] {
        exercisesForSelectedDay.map { exercise in
            "\(exercise.id):\(log?.taskStatuses[exercise.id]?.rawValue ?? TaskStatus.pending.rawValue)"
        }
    }

    private var sessionOverviewBlock: some View {
        let exercises = exercisesForSelectedDay
        let done = exercises.filter { log?.taskStatuses[$0.id] == .completed }.count
        let total = exercises.count
        let summaryText = total == 0 ? "Active rest - walk, yoga, recover" : "\(done) of \(total) complete · \(max(total - done, 0)) left"

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedDay.rawValue)
                        .font(.title3.bold())
                    Text(summaryText)
                        .font(.caption)
                        .foregroundStyle(AppColor.Text.secondary)
                }

                Spacer()

                HStack(spacing: 14) {
                    if total > 0 {
                        completionRing(done: done, total: total)
                    }
                    restTimerCard
                }
            }

            Divider()
                .overlay(AppColor.Border.subtle)

            VStack(alignment: .leading, spacing: 8) {
                Text("Current Focus")
                    .font(.caption2.monospaced())
                    .foregroundStyle(AppColor.Text.secondary)
                    .tracking(1)

                Text(focusedExercise?.name ?? "Recovery and movement")
                    .font(.headline)

                Text(sessionFocusSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let focusedExercise {
                    HStack(spacing: 8) {
                        sessionMetaPill(label: focusedExercise.targetReps, systemImage: "repeat")
                        sessionMetaPill(label: "Rest \(focusedExercise.restSeconds)s", systemImage: "timer")
                        sessionMetaPill(label: "\(focusedExercise.targetSets) sets", systemImage: "number.square")
                    }
                } else {
                    HStack(spacing: 8) {
                        sessionMetaPill(label: "Walk or yoga", systemImage: "figure.walk")
                        sessionMetaPill(label: "Recovery notes", systemImage: "note.text")
                    }
                }
            }

            HStack(spacing: 10) {
                trainingActionButton(
                    title: "Jump To Next",
                    systemImage: "arrow.down.circle.fill",
                    fill: Color.accent.cyan,
                    foreground: .white
                ) {
                    if let next = nextExercise {
                        focusedExerciseID = next.id
                        restPresetSeconds = next.restSeconds
                    }
                }

                trainingActionButton(
                    title: restTimerEnd == nil ? "Start Rest" : "Restart Rest",
                    systemImage: "timer",
                    fill: Color.white.opacity(0.45),
                    foreground: AppColor.Text.primary
                ) {
                    startRestTimer()
                }

                trainingActionButton(
                    title: "Focus Mode",
                    systemImage: "eye.fill",
                    fill: Color.black.opacity(0.65),
                    foreground: .white
                ) {
                    showFocusMode = true
                }
                .disabled(focusedExercise == nil)
            }

            Divider()
                .overlay(AppColor.Border.subtle)
        }
        .padding(.vertical, 2)
    }

    private var restTimerCard: some View {
        VStack(alignment: .trailing, spacing: 6) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(restTimeString(at: context.date))
                    .font(AppText.monoMetric)
                    .foregroundStyle(restTimeRemaining(at: context.date) > 0 ? Color.appOrange2 : Color.black.opacity(0.78))
            }
            Text(restTimerEnd == nil ? "rest preset" : "remaining")
                .font(.caption2)
                .foregroundStyle(AppColor.Text.secondary)
            Stepper(value: $restPresetSeconds, in: 30...180, step: 15) {
                Text("\(restPresetSeconds)s")
                    .font(.caption)
                    .foregroundStyle(AppColor.Text.secondary)
            }
            .labelsHidden()
            .frame(width: 90)
        }
        .padding(.horizontal, AppSpacing.xxSmall)
        .padding(.vertical, AppSpacing.xxSmall)
        .background(Color.white.opacity(0.18), in: RoundedRectangle(cornerRadius: AppRadius.small))
    }

    @ViewBuilder
    private var floatingRestTimer: some View {
        if restTimerEnd != nil {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let remaining = restTimeRemaining(at: context.date)
                let isDone = remaining == 0

                Button {
                    restTimerEnd = nil
                    didHapticAt10 = false
                    didHapticAt0 = false
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: isDone ? "checkmark.circle.fill" : "timer")
                            .font(AppText.captionStrong)
                        Text(isDone ? "Done — tap to clear" : restTimeString(at: context.date))
                            .font(AppText.monoMetric)
                    }
                    .padding(.horizontal, AppSpacing.small)
                    .padding(.vertical, AppSpacing.xxSmall)
                    .background(
                        isDone ? Color.status.success : Color.black.opacity(0.75),
                        in: Capsule()
                    )
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
                .onChange(of: remaining) { _, newRemaining in
                    if newRemaining == 10 && !didHapticAt10 {
                        let g = UIImpactFeedbackGenerator(style: .light)
                        g.prepare()
                        g.impactOccurred()
                        didHapticAt10 = true
                    } else if newRemaining == 0 && !didHapticAt0 {
                        let g = UINotificationFeedbackGenerator()
                        g.prepare()
                        g.notificationOccurred(.success)
                        didHapticAt0 = true
                    }
                }
            }
        }
    }

    private var exerciseQueueStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(exercisesForSelectedDay) { exercise in
                    let isFocused = exercise.id == focusedExercise?.id
                    let status = log?.taskStatuses[exercise.id] ?? .pending
                    Button {
                        focusedExerciseID = exercise.id
                        restPresetSeconds = exercise.restSeconds
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(queueColor(for: status))
                                    .frame(width: 7, height: 7)
                                Text(exercise.name)
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                            }
                            Text(status.rawValue.capitalized)
                                .font(.caption2)
                                .foregroundStyle(AppColor.Text.secondary)
                        }
                        .padding(.horizontal, AppSpacing.xSmall)
                        .padding(.vertical, AppSpacing.xxSmall)
                        .frame(width: 146, alignment: .leading)
                        .background(
                            isFocused ? Color.appBlue1.opacity(0.18) : Color.white.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: AppRadius.small)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.small)
                                .stroke(isFocused ? Color.blue.opacity(0.85) : Color.white.opacity(0.16), lineWidth: isFocused ? 1.2 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func sessionMetaPill(label: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
            Text(label)
                .font(.caption.weight(.medium))
                .lineLimit(1)
        }
        .foregroundStyle(AppColor.Text.primary)
        .padding(.horizontal, AppSpacing.xxSmall)
        .padding(.vertical, AppSpacing.xxSmall)
        .background(Color.white.opacity(0.28), in: Capsule())
    }

    private func trainingActionButton(
        title: String,
        systemImage: String,
        fill: Color,
        foreground: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.xSmall)
                .background(fill, in: RoundedRectangle(cornerRadius: AppRadius.small))
                .foregroundStyle(foreground)
        }
        .buttonStyle(.plain)
    }

    private func completionRing(done: Int, total: Int) -> some View {
        let progress = total > 0 ? Double(done) / Double(total) : 0
        let percent = Int(progress * 100)
        return ZStack {
            Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 5).frame(width: 44, height: 44)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.blue, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .frame(width: 44, height: 44)
                .rotationEffect(.degrees(-90))
            Text("\(percent)%")
                .font(AppText.monoLabel)
                .foregroundStyle(Color.blue)
        }
    }

    // ─────────────────────────────────────────────────────
    // Sections: Machines / Free Weights / Calisthenics / Core / Cardio
    // ─────────────────────────────────────────────────────

    private var exerciseSections: some View {
        let exercises = exercisesForSelectedDay
        let grouped = groupedExercises(exercises)

        return ForEach(grouped, id: \.title) { group in
            if !group.exercises.isEmpty {
                ExerciseSectionBlock(
                    title: group.title,
                    exercises: group.exercises,
                    selectedDay: selectedDay,
                    focusedExerciseID: $focusedExerciseID,
                    log: $log,
                    onFocusExercise: { exercise in
                        focusedExerciseID = exercise.id
                        restPresetSeconds = exercise.restSeconds
                    },
                    onStartRest: startRestTimer
                )
            }
        }
    }

    private struct ExGroup { let title: String; let exercises: [ExerciseDefinition] }

    private func groupedExercises(_ all: [ExerciseDefinition]) -> [ExGroup] {
        [
            ExGroup(title: "Machines",      exercises: all.filter { $0.category == .machine }),
            ExGroup(title: "Free Weights",  exercises: all.filter { $0.category == .freeWeight }),
            ExGroup(title: "Calisthenics",  exercises: all.filter { $0.category == .calisthenics }),
            ExGroup(title: "Core Circuit",  exercises: all.filter { $0.category == .core }),
            ExGroup(title: "Cardio",        exercises: all.filter { $0.category == .cardio }),
        ]
    }

    private func makeBlankLog() -> DailyLog {
        .scheduled(for: activeDate, profile: dataStore.userProfile, dayType: selectedDay)
    }

    // ─────────────────────────────────────────────────────
    // Suggested day derived from activeDate's weekday
    // ─────────────────────────────────────────────────────

    private var suggestedDay: DayType {
        let wd = Calendar.current.component(.weekday, from: activeDate)
        return TrainingProgramStore.dayType(forWeekday: wd)
    }

    // ─────────────────────────────────────────────────────
    // Previous same-day log (for completion sheet comparison)
    // ─────────────────────────────────────────────────────

    private var previousSameDayLog: DailyLog? {
        dataStore.dailyLogs
            .filter {
                $0.dayType == selectedDay &&
                !Calendar.current.isDate($0.date, inSameDayAs: log?.date ?? Date())
            }
            .sorted { $0.date > $1.date }
            .first
    }

    private func saveLog() {
        guard var current = log else { return }
        current.date = activeDate
        current.dayType = selectedDay
        current.recoveryDay = dataStore.userProfile.recoveryDay(for: activeDate)
        log = current
        dataStore.upsertLog(current)
    }

    private func loadLog(for date: Date, preferredDay: DayType) {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        activeDate = normalizedDate
        if let existing = dataStore.log(for: normalizedDate) {
            log = existing
            selectedDay = existing.dayType
        } else {
            selectedDay = preferredDay
            log = makeBlankLog()
        }
        syncFocusedExercise()
        restPresetSeconds = focusedExercise?.restSeconds ?? 90
    }

    private func syncFocusedExercise() {
        let exerciseIDs = Set(exercisesForSelectedDay.map(\.id))
        if let focusedExerciseID, exerciseIDs.contains(focusedExerciseID) {
            return
        }
        focusedExerciseID = nextExercise?.id ?? exercisesForSelectedDay.first?.id
    }

    private func startRestTimer() {
        restTimerEnd = Date().addingTimeInterval(TimeInterval(restPresetSeconds))
        didHapticAt10 = false
        didHapticAt0 = false
    }

    private func restTimeRemaining(at date: Date) -> Int {
        guard let restTimerEnd else { return 0 }
        return max(0, Int(restTimerEnd.timeIntervalSince(date)))
    }

    private func restTimeString(at date: Date) -> String {
        let remaining = restTimeRemaining(at: date)
        if remaining == 0 {
            return restTimerEnd == nil ? "--:--" : "Done"
        }
        return String(format: "%02d:%02d", remaining / 60, remaining % 60)
    }

    private var sessionFocusSubtitle: String {
        guard let focusedExercise else {
            return "Use today for walking, mobility, and recovery notes."
        }
        let status = log?.taskStatuses[focusedExercise.id] ?? .pending
        switch status {
        case .completed:
            return "Completed. Review the next queue item or move to session notes."
        case .partial:
            return "In progress. Finish the work sets or log what changed."
        case .missed:
            return "Marked missed. Either swap the movement or move on."
        case .pending:
            return "Your next working block. Use the previous-performance hints below."
        }
    }

    private func queueColor(for status: TaskStatus) -> Color {
        switch status {
        case .completed: Color.status.success
        case .partial: Color.status.warning
        case .missed: Color.status.error
        case .pending: Color.secondary
        }
    }

    // ─────────────────────────────────────────────────────
    // Session type picker (3×2 grid)
    // ─────────────────────────────────────────────────────

    private var sessionPicker: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
            spacing: 10
        ) {
            ForEach(DayType.allCases, id: \.self) { dt in
                SessionTypeButton(
                    dayType: dt,
                    isSelected: dt == selectedDay,
                    isSuggested: dt == suggestedDay
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedDay = dt
                        log?.dayType = dt
                    }
                }
            }
        }
    }

}

// ─────────────────────────────────────────────────────────
// MARK: – Session Type Button
// ─────────────────────────────────────────────────────────

fileprivate struct SessionTypeButton: View {
    let dayType:    DayType
    let isSelected: Bool
    let isSuggested: Bool
    let action:     () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: dayType.icon)
                    .font(AppText.sectionTitle)
                Text(dayType.rawValue)
                    .font(.caption2.weight(.semibold))
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.xxSmall)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: AppRadius.small))
        }
        .buttonStyle(.plain)
    }

    private var foregroundColor: Color {
        if isSelected   { return AppColor.Text.primary }
        if isSuggested  { return AppColor.Brand.primary }
        return AppColor.Text.primary
    }

    private var backgroundColor: Color {
        if isSelected   { return AppColor.Accent.secondary.opacity(0.28) }
        if isSuggested  { return Color.appOrange1.opacity(0.24) }
        return Color.white.opacity(0.12)
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – Exercise Section Block
// ─────────────────────────────────────────────────────────

struct ExerciseSectionBlock: View {
    let title:     String
    let exercises: [ExerciseDefinition]
    let selectedDay: DayType
    @Binding var focusedExerciseID: String?
    @Binding var log: DailyLog?
    let onFocusExercise: (ExerciseDefinition) -> Void
    let onStartRest: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Rectangle()
                    .fill(Color.white.opacity(0.36))
                    .frame(width: 22, height: 1)
                Text(title)
                    .font(.caption.monospaced())
                    .foregroundStyle(AppColor.Text.secondary)
                    .tracking(1.2)
                Rectangle()
                    .fill(Color.white.opacity(0.18))
                    .frame(height: 1)
            }
            .padding(.top, 4)

            VStack(spacing: 0) {
                ForEach(Array(exercises.enumerated()), id: \.element.id) { index, ex in
                    ExerciseRowView(
                        exercise: ex,
                        selectedDay: selectedDay,
                        isFocused: focusedExerciseID == ex.id,
                        showsDivider: index < exercises.count - 1,
                        onFocus: { onFocusExercise(ex) },
                        log: $log,
                        onStartRest: onStartRest
                    )
                }
            }
        }
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – Single Exercise Row
// ─────────────────────────────────────────────────────────

struct ExerciseRowView: View {
    @EnvironmentObject var dataStore: EncryptedDataStore
    let exercise: ExerciseDefinition
    let selectedDay: DayType
    let isFocused: Bool
    let showsDivider: Bool
    let onFocus: () -> Void
    @Binding var log: DailyLog?
    let onStartRest: () -> Void

    private var status: TaskStatus { log?.taskStatuses[exercise.id] ?? .pending }

    private var previousSessionLog: ExerciseLog? {
        dataStore.dailyLogs
            .filter {
                $0.dayType == selectedDay &&
                !Calendar.current.isDate($0.date, inSameDayAs: log?.date ?? Date()) &&
                $0.exerciseLogs[exercise.id] != nil
            }
            .sorted { $0.date > $1.date }
            .first?
            .exerciseLogs[exercise.id]
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header row
            HStack(alignment: .top, spacing: 10) {
                statusStripe
                exerciseInfo
                Spacer()
                StatusDropdown(status: status) { newStatus in
                    ensureLogMetadata()
                    log?.taskStatuses[exercise.id] = newStatus
                    if newStatus == .completed { initLogIfNeeded() }
                }
            }
            .padding(.horizontal, AppSpacing.xxxSmall)
            .padding(.vertical, AppSpacing.xSmall)
            .contentShape(Rectangle())
            .onTapGesture { onFocus() }

            // Expanded log panel (only when completed or partial)
            if status == .completed || status == .partial {
                Divider()
                    .overlay(Color.white.opacity(0.24))
                    .padding(.leading, 14)
                if exercise.category == .cardio {
                    cardioPanel
                } else {
                    liftPanel
                }
            }

            if showsDivider {
                Divider()
                    .overlay(Color.white.opacity(0.2))
                    .padding(.leading, 14)
            }
        }
        .padding(.horizontal, AppSpacing.xxSmall)
        .background(
            Group {
                if isFocused || status == .completed || status == .partial {
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                        .fill(rowBG)
                } else {
                    Color.clear
                }
            }
        )
        .animation(.easeInOut(duration: 0.25), value: status)
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }

    // ── Status stripe
    private var statusStripe: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(accentColor)
            .frame(width: 4)
            .padding(.vertical, 4)
    }

    // ── Exercise info block
    private var exerciseInfo: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Text(exercise.name)
                    .font(.subheadline.weight(.semibold))
                    .strikethrough(status == .completed, color: Color.status.success)
                    .foregroundStyle(status == .completed ? AppColor.Text.secondary : AppColor.Text.primary)
                if isFocused {
                    Text("LIVE")
                        .font(AppText.monoLabel)
                        .padding(.horizontal, AppSpacing.xxxSmall)
                        .padding(.vertical, 3)
                        .background(AppColor.Accent.secondary.opacity(0.18), in: Capsule())
                        .foregroundStyle(AppColor.Accent.secondary)
                }
            }

            Text(exercise.muscleGroups.map { $0.rawValue.capitalized }.joined(separator: " · "))
                .font(.caption2).foregroundStyle(AppColor.Text.secondary)

            if exercise.category != .cardio {
                HStack(spacing: 8) {
                    exerciseMetaPill("\(exercise.targetSets) sets")
                    exerciseMetaPill(exercise.targetReps)
                    exerciseMetaPill("Rest \(exercise.restSeconds)s")
                }
            }
            Text("↳ \(exercise.coachingCue)")
                .font(.caption2.italic()).foregroundStyle(AppColor.Text.tertiary)
                .lineLimit(2)
        }
    }

    // ── Lift log panel (sets × reps × weight)
    private var liftPanel: some View {
        LiftLogPanel(
            exercise: exercise,
            isFocused: isFocused,
            previousSessionLog: previousSessionLog,
            exerciseLog: Binding(
                get: { log?.exerciseLogs[exercise.id] ?? ExerciseLog(exerciseID: exercise.id, exerciseName: exercise.name) },
                set: {
                    ensureLogMetadata()
                    log?.exerciseLogs[exercise.id] = $0
                }
            ),
            onStartRest: onStartRest,
            onSetCompleted: {
                if log?.sessionStartTime == nil {
                    log?.sessionStartTime = Date()
                }
            }
        )
    }

    // ── Cardio log panel (elliptical / rowing) with photo upload
    private var cardioPanel: some View {
        CardioLogPanel(
            cardioType: exercise.equipment == .rowingMachine ? .rowing : .elliptical,
            cardioLog: Binding(
                get: { log?.cardioLogs[exercise.id] ?? CardioLog(cardioType: exercise.equipment == .rowingMachine ? .rowing : .elliptical) },
                set: {
                    ensureLogMetadata()
                    log?.cardioLogs[exercise.id] = $0
                }
            )
        )
    }

    private var accentColor: Color {
        switch status {
        case .completed: Color.status.success; case .partial: Color.status.warning; case .missed: Color.status.error; case .pending: .secondary
        }
    }

    private var rowBG: Color {
        switch status {
        case .completed: Color.status.success.opacity(0.08)
        case .partial: Color.status.warning.opacity(0.06)
        case .missed: Color.status.error.opacity(0.06)
        default: isFocused ? Color.white.opacity(0.24) : Color.clear
        }
    }

    private func exerciseMetaPill(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .foregroundStyle(AppColor.Text.primary)
            .padding(.horizontal, AppSpacing.xxSmall)
            .padding(.vertical, AppSpacing.xxxSmall)
            .background(Color.white.opacity(0.18), in: Capsule())
    }

    private func initLogIfNeeded() {
        ensureLogMetadata()
        if exercise.category == .cardio && log?.cardioLogs[exercise.id] == nil {
            log?.cardioLogs[exercise.id] = CardioLog(
                cardioType: exercise.equipment == .rowingMachine ? .rowing : .elliptical
            )
        } else if log?.exerciseLogs[exercise.id] == nil {
            log?.exerciseLogs[exercise.id] = ExerciseLog(
                exerciseID: exercise.id, exerciseName: exercise.name
            )
        }
    }

    private func ensureLogMetadata() {
        log?.dayType = selectedDay
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – Lift Log Panel (sets × reps × weight × RPE)
// ─────────────────────────────────────────────────────────

struct LiftLogPanel: View {
    let exercise: ExerciseDefinition
    let isFocused: Bool
    let previousSessionLog: ExerciseLog?
    @Binding var exerciseLog: ExerciseLog
    let onStartRest: () -> Void
    var onSetCompleted: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(isFocused ? "LIVE SET LOG" : "SET LOG")
                        .font(.caption2.monospaced())
                        .foregroundStyle(isFocused ? Color.blue : Color.status.success)
                        .tracking(1)
                    Spacer()
                    if exerciseLog.totalVolume > 0 {
                        Text("Total: \(Int(exerciseLog.totalVolume)) kg")
                            .font(.caption2.monospaced())
                            .foregroundStyle(Color.status.success.opacity(0.82))
                    }
                }

                if let prev = previousSessionLog {
                    HStack(spacing: 10) {
                        previousPerformanceTile(
                            title: "Last Best",
                            value: prev.bestSet.map { "\((Int(($0.weightKg ?? 0).rounded()))) kg x \($0.repsCompleted ?? 0)" } ?? "—"
                        )
                        previousPerformanceTile(
                            title: "Last Volume",
                            value: prev.totalVolume > 0 ? "\(Int(prev.totalVolume)) kg" : "—"
                        )
                    }
                }

                // Estimated 1RM from current session best set
                if let best = exerciseLog.bestSet,
                   let weight = best.weightKg,
                   let reps = best.repsCompleted,
                   let orm = estimated1RM(weightKg: weight, reps: reps) {
                    Text("Est. 1RM ~\(Int(orm.rounded())) kg")
                        .font(.caption)
                        .foregroundStyle(Color.accent.cyan)
                        .padding(.horizontal, AppSpacing.xSmall)
                        .padding(.top, 2)
                }

                if let suggestion = overloadSuggestion {
                    Text(suggestion)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.accent.cyan)
                }

                HStack(spacing: 10) {
                    if let prev = previousSessionLog, exerciseLog.sets.isEmpty {
                        Button {
                            exerciseLog.sets = prev.sets.enumerated().map { (i, s) in
                                SetLog(
                                    setNumber: i + 1,
                                    weightKg: s.weightKg,
                                    repsCompleted: s.repsCompleted
                                )
                            }
                        } label: {
                            Label("Copy Last", systemImage: "bolt.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.accent.cyan)
                        }
                    }
                    Button {
                        exerciseLog.sets.append(SetLog(
                            setNumber: exerciseLog.sets.count + 1,
                            weightKg: exerciseLog.sets.last?.weightKg
                        ))
                    } label: {
                        Label("Add Set", systemImage: "plus.circle.fill")
                            .font(.caption.weight(.semibold)).foregroundStyle(Color.status.success)
                    }
                    Spacer()
                    Button {
                        onStartRest()
                    } label: {
                        Label("Start Rest", systemImage: "timer")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.appOrange2)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.xSmall)
            .padding(.top, AppSpacing.xxSmall)

            if exerciseLog.sets.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "plus.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("Tap 'Add Set' to log your first set")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.medium)
            } else {
                VStack(spacing: 10) {
                    ForEach(exerciseLog.sets.indices, id: \.self) { i in
                        SetRowView(
                            setLog: $exerciseLog.sets[i],
                            setNum: i + 1,
                            previousSet: previousSessionLog?.sets.indices.contains(i) == true ? previousSessionLog?.sets[i] : nil,
                            onCompleteSet: {
                                exerciseLog.sets[i].timestamp = Date()
                                onSetCompleted?()
                                onStartRest()
                                let hap = UIImpactFeedbackGenerator(style: .medium); hap.prepare(); hap.impactOccurred()
                            },
                            onDelete: {
                                exerciseLog.sets.remove(at: i)
                                for j in exerciseLog.sets.indices { exerciseLog.sets[j].setNumber = j + 1 }
                            }
                        )
                    }
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "note.text")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Session notes, form, pain, PR…", text: $exerciseLog.notes)
                    .font(.caption)
            }
            .padding(AppSpacing.xxSmall)
            .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: AppRadius.small))
        }
        .padding(AppSpacing.xSmall)
        .background(Color.white.opacity(isFocused ? 0.18 : 0.12), in: RoundedRectangle(cornerRadius: AppRadius.medium))
    }

    private var overloadSuggestion: String? {
        guard let prev = previousSessionLog else { return nil }
        // Exclude warmup sets from both the target check and best-weight calculation
        let workingSets = prev.sets.filter { !$0.isWarmup }
        guard !workingSets.isEmpty else { return nil }
        // Parse minimum reps from targetReps string (e.g., "8-12" → 8, "10" → 10)
        let minTargetReps = exercise.targetReps
            .components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap { Int($0) }
            .first ?? 0
        guard minTargetReps > 0 else { return nil }
        // Check all working sets hit target reps
        let allHitTarget = workingSets.allSatisfy { ($0.repsCompleted ?? 0) >= minTargetReps }
        guard allHitTarget else { return nil }
        // Suggest +2.5 kg from previous best working weight
        guard let bestWeight = workingSets.compactMap(\.weightKg).max() else { return nil }
        let suggested = bestWeight + 2.5
        let fmt = suggested.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(suggested)) : String(format: "%.1f", suggested)
        return "→ Try \(fmt) kg today (+2.5)"
    }

    private func previousPerformanceTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, AppSpacing.xxSmall)
        .padding(.vertical, AppSpacing.xxSmall)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.18), in: RoundedRectangle(cornerRadius: AppRadius.xSmall))
    }
}

struct SetRowView: View {
    @Binding var setLog: SetLog
    let setNum:  Int
    let previousSet: SetLog?
    let onCompleteSet: () -> Void
    let onDelete: () -> Void

    @State private var weightStr  = ""
    @State private var repsStr    = ""
    @State private var noteStr    = ""
    @State private var flashGreen = false

    private var setIsComplete: Bool {
        setLog.weightKg != nil && setLog.repsCompleted != nil
    }

    private func formattedWeight(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Text("Set \(setNum)")
                    .font(.system(.caption, design: .monospaced, weight: .bold))
                    .foregroundStyle(.secondary)

                if let previousSet {
                    Text(previousHint(for: previousSet))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    onCompleteSet()
                    withAnimation(.easeOut(duration: 0.1)) { flashGreen = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        withAnimation(.easeIn(duration: 0.25)) { flashGreen = false }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: setIsComplete ? "checkmark.circle.fill" : "timer")
                        Text(setIsComplete ? "Done" : "Log")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(setIsComplete ? Color.status.success : Color.appOrange2)
                    .padding(.horizontal, AppSpacing.xxSmall)
                    .padding(.vertical, AppSpacing.xxxSmall)
                    .background((setIsComplete ? Color.status.success : Color.appOrange2).opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)

                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }

            HStack(spacing: 10) {
                entryField(
                    title: "KG",
                    text: $weightStr,
                    placeholder: "0",
                    previousValue: previousSet?.weightKg.map(formattedWeight),
                    onUsePrevious: {
                        if let prevWeight = previousSet?.weightKg {
                            weightStr = formattedWeight(prevWeight)
                            setLog.weightKg = prevWeight
                        }
                    }
                )

                entryField(
                    title: "REPS",
                    text: $repsStr,
                    placeholder: "0",
                    previousValue: previousSet?.repsCompleted.map(String.init),
                    fixedWidth: 86,
                    keyboardType: .numberPad,
                    onUsePrevious: {
                        if let prevReps = previousSet?.repsCompleted {
                            repsStr = String(prevReps)
                            setLog.repsCompleted = prevReps
                        }
                    }
                )
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("RPE")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                RPETapBar(rpe: Binding(get: { setLog.rpe }, set: { setLog.rpe = $0 }))
            }

            HStack(spacing: 8) {
                Image(systemName: "note.text")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Add note or cue", text: $noteStr)
                    .font(.caption)
                    .onChange(of: noteStr) { _, v in setLog.notes = v }
            }
            .padding(.horizontal, AppSpacing.xxSmall)
            .padding(.vertical, AppSpacing.xxSmall)
            .background(Color.white.opacity(0.16), in: RoundedRectangle(cornerRadius: AppRadius.xSmall))
        }
        .padding(AppSpacing.xSmall)
        .background(flashGreen ? Color.status.success.opacity(0.16) : (setIsComplete ? Color.status.success.opacity(0.08) : Color.white.opacity(0.08)), in: RoundedRectangle(cornerRadius: AppRadius.small))
        .onAppear {
            weightStr = setLog.weightKg.map(formattedWeight) ?? ""
            repsStr   = setLog.repsCompleted.map { String($0) } ?? ""
            noteStr   = setLog.notes
        }
        // Re-sync local strings if the binding is updated externally (e.g. CloudKit merge).
        .onChange(of: setLog) { _, newLog in
            weightStr = newLog.weightKg.map(formattedWeight) ?? ""
            repsStr   = newLog.repsCompleted.map { String($0) } ?? ""
            noteStr   = newLog.notes
        }
    }

    private func previousHint(for set: SetLog) -> String {
        let weight = set.weightKg.map(formattedWeight) ?? "—"
        let reps = set.repsCompleted.map(String.init) ?? "—"
        return "Last \(weight) × \(reps)"
    }

    @ViewBuilder
    private func entryField(
        title: String,
        text: Binding<String>,
        placeholder: String,
        previousValue: String?,
        fixedWidth: CGFloat? = nil,
        keyboardType: UIKeyboardType = .decimalPad,
        onUsePrevious: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                if let previousValue, text.wrappedValue.isEmpty {
                    Button("Last \(previousValue)") {
                        onUsePrevious()
                    }
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color.accent.cyan)
                }
            }

            TextField(placeholder, text: text)
                .font(.system(.body, design: .monospaced))
                .keyboardType(keyboardType)
                .multilineTextAlignment(.center)
                .padding(.vertical, AppSpacing.xxSmall)
                .padding(.horizontal, AppSpacing.xxSmall)
                .background(Color.white.opacity(0.2), in: RoundedRectangle(cornerRadius: AppRadius.xSmall))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.xSmall)
                        .stroke(Color.white.opacity(0.12))
                )
        }
        .frame(width: fixedWidth)
        .frame(maxWidth: fixedWidth == nil ? .infinity : nil)
        .onChange(of: text.wrappedValue) { _, v in
            if title == "KG" {
                setLog.weightKg = Double(v)
            } else {
                setLog.repsCompleted = Int(v)
            }
        }
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – Cardio Log Panel (Elliptical + Rowing + Photo)
// ─────────────────────────────────────────────────────────

struct CardioLogPanel: View {
    @EnvironmentObject var dataStore: EncryptedDataStore
    let cardioType: CardioType
    @Binding var cardioLog: CardioLog

    @State private var showPhotoPicker   = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var capturedImage:    Image?
    @State private var showCamera        = false
    @State private var showImageExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(cardioType == .rowing ? "ROWING LOG" : "ELLIPTICAL LOG")
                    .font(.caption2.monospaced())
                    .foregroundStyle(Color.status.success)
                    .tracking(1)
                Spacer()
                if let zone = cardioLog.wasInZone2(lower: dataStore.userPreferences.zone2LowerHR, upper: dataStore.userPreferences.zone2UpperHR) {
                    Text(zone ? "✓ Zone 2" : "↑ Above Zone 2")
                        .font(.caption2.monospaced())
                        .foregroundStyle(zone ? Color.status.success : Color.status.warning)
                }
            }

            // Metric grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                CardioField("Duration (min)", value: durationBinding)
                CardioField("Avg HR (bpm)",   value: avgHRBinding)
                CardioField("Max HR (bpm)",   value: maxHRBinding)
                CardioField("Calories",       value: calsBinding)

                if cardioType == .rowing {
                    CardioField("Pace /500m", value: paceBinding, placeholder: "2:30")
                    CardioField("SPM",        value: spmBinding,  placeholder: "24")
                } else {
                    CardioField("Resistance", value: resistBinding, placeholder: "8")
                    CardioField("Distance km", value: distBinding, placeholder: "0.0")
                }
            }

            // Notes
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "note.text")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                TextField("Feel, energy, breathing, HR stability…", text: $cardioLog.notes, axis: .vertical)
                    .font(.caption)
                    .lineLimit(2...4)
            }
            .padding(AppSpacing.xxSmall)
            .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: AppRadius.small))

            // ── Photo Section ──────────────────────────────
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Session Summary Photo", systemImage: "camera.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    // Camera button (iOS only)
                    #if os(iOS)
                    Button {
                        showCamera = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "camera")
                            Text("Take Photo")
                        }
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, AppSpacing.xxSmall).padding(.vertical, AppSpacing.xxxSmall)
                        .background(Color.status.success.opacity(0.1), in: Capsule())
                        .foregroundStyle(Color.status.success)
                    }
                    #endif

                    // Photo library picker
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        HStack(spacing: 4) {
                            Image(systemName: "photo")
                            Text("Library")
                        }
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, AppSpacing.xxSmall).padding(.vertical, AppSpacing.xxxSmall)
                        .background(Color.secondary.opacity(0.1), in: Capsule())
                        .foregroundStyle(.secondary)
                    }
                }

                // Caption text
                Text("Photograph the machine's summary screen to capture all session data.")
                    .font(.caption2).foregroundStyle(.tertiary)

                // Preview
                if let img = capturedImage {
                    img.resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 180)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xSmall))
                        .overlay(alignment: .topTrailing) {
                            Button {
                                capturedImage = nil
                                cardioLog.summaryImageData = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.white)
                                    .background(Color.black.opacity(0.4), in: Circle())
                            }
                            .padding(AppSpacing.xxSmall)
                        }
                        .onTapGesture { showImageExpanded = true }
                } else {
                    RoundedRectangle(cornerRadius: AppRadius.xSmall)
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 80)
                        .overlay {
                            VStack(spacing: 6) {
                                Image(systemName: "camera.viewfinder")
                                    .font(.title2).foregroundStyle(.secondary)
                                Text("No photo yet — tap camera to capture")
                                    .font(.caption2).foregroundStyle(.tertiary)
                            }
                        }
                }
            }
            .padding(AppSpacing.xSmall)
            .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: AppRadius.small))
        }
        .padding(AppSpacing.xSmall)
        .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: AppRadius.medium))
        // Handle photo selection from library
        .onChange(of: selectedPhotoItem) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self) {
                    #if os(iOS)
                    if let ui = UIImage(data: data),
                       let compressed = ui.jpegData(compressionQuality: 0.75) {
                        capturedImage = Image(uiImage: ui)
                        cardioLog.summaryImageData = compressed
                    }
                    #endif
                }
            }
        }
        // Camera sheet (iOS only)
        #if os(iOS)
        .sheet(isPresented: $showCamera) {
            CameraView { imageData in
                if let data = imageData,
                   let ui = UIImage(data: data),
                   let compressed = ui.jpegData(compressionQuality: 0.75) {
                    capturedImage = Image(uiImage: ui)
                    cardioLog.summaryImageData = compressed
                }
                showCamera = false
            }
        }
        #endif
        // Full-screen image preview
        .fullScreenCover(isPresented: $showImageExpanded) {
            ZStack {
                Color.black.ignoresSafeArea()
                if let img = capturedImage {
                    img.resizable().aspectRatio(contentMode: .fit)
                }
                Button {
                    showImageExpanded = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.largeTitle).foregroundStyle(.white)
                }
                .padding(40)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
        }
        .onAppear {
            #if os(iOS)
            if let data = cardioLog.summaryImageData,
               let ui = UIImage(data: data) {
                capturedImage = Image(uiImage: ui)
            }
            #endif
        }
    }

    // ── Bindings for cardio fields ────────────────────────

    private var durationBinding: Binding<String> {
        .init(get: { cardioLog.durationMinutes.map { String($0) } ?? "" },
              set: { cardioLog.durationMinutes = Double($0) })
    }
    private var avgHRBinding: Binding<String> {
        .init(get: { cardioLog.avgHeartRate.map { String(Int($0)) } ?? "" },
              set: { cardioLog.avgHeartRate = Double($0) })
    }
    private var maxHRBinding: Binding<String> {
        .init(get: { cardioLog.maxHeartRate.map { String(Int($0)) } ?? "" },
              set: { cardioLog.maxHeartRate = Double($0) })
    }
    private var calsBinding: Binding<String> {
        .init(get: { cardioLog.caloriesBurned.map { String(Int($0)) } ?? "" },
              set: { cardioLog.caloriesBurned = Double($0) })
    }
    private var paceBinding: Binding<String> {
        .init(get: { cardioLog.pacePer500m ?? "" },
              set: { cardioLog.pacePer500m = $0.isEmpty ? nil : $0 })
    }
    private var spmBinding: Binding<String> {
        .init(get: { cardioLog.strokesPerMinute.map { String($0) } ?? "" },
              set: { cardioLog.strokesPerMinute = Int($0) })
    }
    private var resistBinding: Binding<String> {
        .init(get: { cardioLog.resistance.map { String($0) } ?? "" },
              set: { cardioLog.resistance = Int($0) })
    }
    private var distBinding: Binding<String> {
        .init(get: { cardioLog.distanceKm.map { String($0) } ?? "" },
              set: { cardioLog.distanceKm = Double($0) })
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – Camera wrapper (iOS only)
// ─────────────────────────────────────────────────────────

#if os(iOS)
import UIKit

struct CameraView: UIViewControllerRepresentable {
    let onCapture: (Data?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (Data?) -> Void
        init(onCapture: @escaping (Data?) -> Void) { self.onCapture = onCapture }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            picker.dismiss(animated: true)
            if let img = info[.originalImage] as? UIImage {
                onCapture(img.jpegData(compressionQuality: 0.8))
            } else {
                onCapture(nil)
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
            onCapture(nil)
        }
    }
}
#endif

// ─────────────────────────────────────────────────────────
// MARK: – Shared small components
// ─────────────────────────────────────────────────────────

struct CardioField: View {
    let label:       String
    @Binding var value: String
    var placeholder: String = "0"

    init(_ label: String, value: Binding<String>, placeholder: String = "0") {
        self.label       = label
        self._value      = value
        self.placeholder = placeholder
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            TextField(placeholder, text: $value)
                .font(.system(.body, design: .monospaced))
                .keyboardType(.decimalPad)
                .padding(AppSpacing.xxSmall)
                .background(Color.white.opacity(0.18), in: RoundedRectangle(cornerRadius: AppRadius.xSmall))
                .overlay(RoundedRectangle(cornerRadius: AppRadius.xSmall).stroke(Color.white.opacity(0.12)))
        }
    }
}

struct RPETapBar: View {
    @Binding var rpe: Double?

    private let segments: [Int] = [6, 7, 8, 9, 10]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(segments, id: \.self) { v in
                let isSelected = rpe.map { Int($0) } == v
                Button {
                    rpe = isSelected ? nil : Double(v)
                } label: {
                    Text("\(v)")
                        .font(.system(size: 10, weight: isSelected ? .bold : .regular, design: .monospaced))
                        .foregroundStyle(isSelected ? Color.black : Color.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.xxSmall)
                        .background(
                            isSelected
                                ? Color.appOrange2
                                : Color.white.opacity(0.14),
                            in: RoundedRectangle(cornerRadius: 4)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(isSelected ? Color.appOrange2 : Color.white.opacity(0.12), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct StatusDropdown: View {
    let status:   TaskStatus
    let onSelect: (TaskStatus) -> Void

    var body: some View {
        Menu {
            Button { onSelect(.completed) } label: { Label("Completed", systemImage: "checkmark.circle.fill") }
            Button { onSelect(.partial)   } label: { Label("Partial",   systemImage: "circle.lefthalf.filled") }
            Button { onSelect(.missed)    } label: { Label("Missed",    systemImage: "xmark.circle.fill") }
            Divider()
            Button { onSelect(.pending)   } label: { Label("Reset",     systemImage: "arrow.counterclockwise") }
        } label: {
            HStack(spacing: 4) {
                Circle().fill(color).frame(width: 6, height: 6)
                Text(status.rawValue.capitalized).font(.caption.weight(.medium))
                Image(systemName: "chevron.down").font(.system(size: 8, weight: .semibold))
            }
            .foregroundStyle(color)
            .padding(.horizontal, AppSpacing.xxSmall).padding(.vertical, AppSpacing.xxxSmall)
            .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 7))
        }
    }

    private var color: Color {
        switch status {
        case .completed: Color.status.success; case .partial: Color.status.warning; case .missed: Color.status.error; case .pending: .secondary
        }
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – Session Completion Sheet
// ─────────────────────────────────────────────────────────

struct SessionCompletionSheet: View {
    let log: DailyLog?
    let selectedDay: DayType
    let previousLog: DailyLog?
    let streak: Int
    let onDone: () -> Void
    let onLogNotes: () -> Void

    @EnvironmentObject var dataStore: EncryptedDataStore

    @State private var milestoneTitle: String? = nil
    @State private var milestoneMessage: String? = nil
    @State private var hasShownMilestone = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.status.success)
                        Text("Session Complete!")
                            .font(.title2.bold())
                        Text(selectedDay.rawValue)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, AppSpacing.xxSmall)

                    // Warm completion micro-copy
                    Text(completionMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.xxSmall)

                    // Stats grid: 4 metric tiles
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        // Total Volume
                        statTile(
                            icon: "scalemass.fill",
                            label: "Volume",
                            value: totalVolumeStr,
                            delta: volumeDeltaStr,
                            color: Color.accent.cyan
                        )
                        // Exercises done
                        statTile(
                            icon: "checkmark.circle.fill",
                            label: "Exercises",
                            value: exerciseSummaryStr,
                            delta: nil,
                            color: Color.status.success
                        )
                        // Session duration
                        statTile(
                            icon: "clock.fill",
                            label: "Duration",
                            value: durationStr,
                            delta: nil,
                            color: Color.accent.purple
                        )
                        // PRs this session (from exerciseLogs bestSet vs previous)
                        statTile(
                            icon: "trophy.fill",
                            label: "PRs",
                            value: prCountStr,
                            delta: nil,
                            color: Color.accent.gold
                        )
                    }

                    Divider()

                    // Buttons
                    VStack(spacing: 12) {
                        Button(action: onLogNotes) {
                            Label("Log Notes", systemImage: "note.text")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, AppSpacing.xSmall)
                                .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: AppRadius.small))
                        }
                        .buttonStyle(.plain)

                        Button(action: onDone) {
                            Text("Done")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, AppSpacing.xSmall)
                                .foregroundStyle(.black)
                                .background(
                                    LinearGradient(colors: [Color.status.success, Color.status.success.opacity(0.8)],
                                                   startPoint: .leading, endPoint: .trailing),
                                    in: RoundedRectangle(cornerRadius: AppRadius.small)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, AppSpacing.large)
                .padding(.bottom, AppSpacing.xLarge)
                .onAppear {
                    guard !hasShownMilestone else { return }
                    hasShownMilestone = true
                    let totalCompleted = dataStore.dailyLogs.filter {
                        $0.taskStatuses.values.contains(.completed)
                    }.count
                    if totalCompleted == 1 {
                        milestoneTitle = "First Workout Complete!"
                        milestoneMessage = "That's day one. The hardest one. Every session from here builds on this."
                    } else if let name = firstPRExerciseName {
                        milestoneTitle = "New Personal Record!"
                        milestoneMessage = "New record on \(name). You're stronger than last week."
                        let g = UIImpactFeedbackGenerator(style: .medium)
                        g.prepare()
                        g.impactOccurred()
                    }
                    let ng = UINotificationFeedbackGenerator()
                    ng.prepare()
                    ng.notificationOccurred(.success)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .fullScreenCover(isPresented: Binding(get: { milestoneTitle != nil }, set: { if !$0 { milestoneTitle = nil; milestoneMessage = nil } })) {
            if let title = milestoneTitle, let message = milestoneMessage {
                MilestoneModal(title: title, message: message) {
                    milestoneTitle = nil
                    milestoneMessage = nil
                }
            }
        }
    }

    // ── Helpers ────────────────────────────────────────────

    private var totalVolume: Double {
        log?.exerciseLogs.values.map(\.totalVolume).reduce(0, +) ?? 0
    }

    private var previousVolume: Double {
        previousLog?.exerciseLogs.values.map(\.totalVolume).reduce(0, +) ?? 0
    }

    private var totalVolumeStr: String {
        totalVolume > 0 ? "\(Int(totalVolume)) kg" : "—"
    }

    private var volumeDeltaStr: String? {
        guard totalVolume > 0, previousVolume > 0 else { return nil }
        let delta = totalVolume - previousVolume
        return delta >= 0 ? "+\(Int(delta)) kg" : "\(Int(delta)) kg"
    }

    private var exerciseSummaryStr: String {
        let total = TrainingProgramData.exercises(for: selectedDay).count
        let done  = log?.taskStatuses.values.filter { $0 == .completed }.count ?? 0
        return "\(done)/\(total)"
    }

    private func formatSessionDuration(since start: Date) -> String {
        let minutes = max(0, Int(Date().timeIntervalSince(start) / 60))
        if minutes >= 60 {
            let h = minutes / 60
            let m = minutes % 60
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
        return minutes > 0 ? "\(minutes) min" : "< 1 min"
    }

    private var durationStr: String {
        guard let start = log?.sessionStartTime else { return "—" }
        return formatSessionDuration(since: start)
    }

    private var prCountStr: String {
        guard let exLogs = log?.exerciseLogs, let prevExLogs = previousLog?.exerciseLogs else {
            return "—"
        }
        let count = exLogs.filter { (exerciseID, current) in
            guard let best = current.bestSet?.weightKg,
                  let prevBest = prevExLogs[exerciseID]?.bestSet?.weightKg else { return false }
            return best > prevBest
        }.count
        return count > 0 ? "\(count)" : "0"
    }

    private var firstPRExerciseName: String? {
        guard let exLogs = log?.exerciseLogs, let prevExLogs = previousLog?.exerciseLogs else { return nil }
        // Sort by biggest weight improvement for a deterministic, most-impressive PR
        let bestEntry = exLogs
            .filter { (exerciseID, current) in
                guard let best = current.bestSet?.weightKg,
                      let prevBest = prevExLogs[exerciseID]?.bestSet?.weightKg else { return false }
                return best > prevBest
            }
            .max { a, b in
                let aGain = (a.value.bestSet?.weightKg ?? 0) - (prevExLogs[a.key]?.bestSet?.weightKg ?? 0)
                let bGain = (b.value.bestSet?.weightKg ?? 0) - (prevExLogs[b.key]?.bestSet?.weightKg ?? 0)
                return aGain < bGain
            }
        return bestEntry.map { exerciseID, _ in
            TrainingProgramData.allExercises.first { $0.id == exerciseID }?.name ?? exerciseID
        }
    }

    private var completionMessage: String {
        if previousLog == nil {
            return "That's day one. The hardest one."
        }
        if let firstPRExercise = firstPRExerciseName {
            return "New record on \(firstPRExercise). You're stronger than last week."
        }
        if streak >= 7 {
            return "\(streak) days straight. Consistency beats intensity every time."
        }
        return "Good work. Come back stronger."
    }

    @ViewBuilder
    private func statTile(icon: String, label: String, value: String, delta: String?, color: Color) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(color)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.title3.bold())
            if let delta {
                Text(delta)
                    .font(.caption2)
                    .foregroundStyle(delta.hasPrefix("+") ? Color.status.success : Color.status.error)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.xSmall)
        .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: AppRadius.small))
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – Notes Editor Sheet
// ─────────────────────────────────────────────────────────

struct NotesEditorSheet: View {
    @Binding var notes: String
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            TextEditor(text: $notes)
                .font(.body)
                .padding()
                .navigationTitle("Session Notes")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done", action: onDone)
                    }
                }
        }
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – Focus Mode (distraction-free)
// ─────────────────────────────────────────────────────────

struct FocusModeView: View {
    let exercise: ExerciseDefinition
    @Binding var exerciseLog: ExerciseLog
    let onExit: () -> Void

    @State private var weightStr = ""
    @State private var repsStr   = ""

    private var nextIncompleteSetIndex: Int? {
        exerciseLog.sets.indices.first {
            exerciseLog.sets[$0].weightKg == nil || exerciseLog.sets[$0].repsCompleted == nil
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 28) {
                // Exit button
                HStack {
                    Spacer()
                    Button(action: onExit) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, AppSpacing.large)
                .padding(.top, AppSpacing.small)

                Spacer()

                // Exercise name
                VStack(spacing: 8) {
                    Text("Focus Mode")
                        .font(.caption.monospaced())
                        .tracking(1.2)
                        .foregroundStyle(Color.white.opacity(0.48))
                    Text(exercise.name)
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, AppSpacing.large)

                // Set info
                if let idx = nextIncompleteSetIndex {
                    VStack(spacing: 8) {
                        Text("Set \(idx + 1)")
                            .font(.system(size: 18, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.55))
                        Text(exercise.targetReps)
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                } else {
                    Text("All sets done ✓")
                        .font(.title2.bold())
                        .foregroundStyle(Color.status.success)
                }

                // Weight + Reps fields
                HStack(spacing: 16) {
                    focusField(placeholder: "kg", text: $weightStr)
                    Text("×")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.5))
                    focusField(placeholder: "reps", text: $repsStr)
                }
                .padding(.horizontal, AppSpacing.xLarge)

                Text("Tap Done after each set to keep momentum and stay off the main sheet.")
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.46))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xLarge)

                // Done button
                Button {
                    guard let idx = nextIncompleteSetIndex else { onExit(); return }
                    exerciseLog.sets[idx].weightKg      = Double(weightStr.replacingOccurrences(of: ",", with: "."))
                    exerciseLog.sets[idx].repsCompleted = Int(repsStr)
                    exerciseLog.sets[idx].timestamp     = Date()
                    let hap = UIImpactFeedbackGenerator(style: .medium); hap.prepare(); hap.impactOccurred()
                    repsStr = ""
                    // Prefill weight for the next incomplete set from the one just completed
                    if let kg = exerciseLog.sets[idx].weightKg {
                        weightStr = kg.truncatingRemainder(dividingBy: 1) == 0
                            ? String(Int(kg)) : String(kg)
                    } else {
                        weightStr = ""
                    }
                } label: {
                    Text(nextIncompleteSetIndex != nil ? "Done" : "Finish")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.medium)
                        .background(Color.status.success, in: RoundedRectangle(cornerRadius: AppRadius.large))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, AppSpacing.xLarge)
                .disabled(nextIncompleteSetIndex == nil)

                Spacer()
            }
        }
        .persistentSystemOverlays(.hidden)
        .onAppear {
            // Prefill weight from last set that has a weight logged
            if let kg = exerciseLog.sets.last(where: { $0.weightKg != nil })?.weightKg {
                weightStr = kg.truncatingRemainder(dividingBy: 1) == 0
                    ? String(Int(kg)) : String(kg)
            }
        }
    }

    private func focusField(placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(placeholder.uppercased())
                .font(.caption2.monospaced())
                .foregroundStyle(Color.white.opacity(0.42))
            TextField(placeholder, text: text)
                .font(.system(size: 42, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .keyboardType(.decimalPad)
                .padding(AppSpacing.small)
                .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: AppRadius.medium))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - MilestoneModal

struct MilestoneModal: View {
    let title: String
    let message: String
    let onDismiss: () -> Void

    @State private var autoDismissTimer: Timer? = nil

    var body: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()

            VStack(spacing: 20) {
                Text("🎉")
                    .font(.system(size: 72))

                Text(title)
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.large)

                Button("Continue") {
                    autoDismissTimer?.invalidate()
                    onDismiss()
                }
                .font(.headline)
                .padding(.horizontal, AppSpacing.xxLarge)
                .padding(.vertical, AppSpacing.xSmall)
                .background(Color.white.opacity(0.2), in: RoundedRectangle(cornerRadius: AppRadius.large))
                .foregroundStyle(.white)
            }
            .padding(AppSpacing.xLarge)
        }
        .onAppear {
            autoDismissTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
                onDismiss()
            }
        }
        .onDisappear {
            autoDismissTimer?.invalidate()
        }
    }
}
