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
    private let bgOrange1 = Color.appOrange1
    private let bgOrange2 = Color.appOrange2

    init(initialDay: DayType? = nil) {
        self.initialDay = initialDay
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [bgOrange1, bgOrange2],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    weekStrip
                    sessionPicker
                    sessionHeader
                    sessionCommandDeck
                    exerciseQueueStrip
                    exerciseSections
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
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
                    .padding(.trailing, 16)
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
            .presentationCornerRadius(24)
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
                        .foregroundStyle(isActive ? Color.primary : Color.secondary)

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
                            .foregroundStyle(isToday ? Color.black : Color.primary)
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
        .padding(.vertical, 8)
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

    private var sessionHeader: some View {
        let exercises = exercisesForSelectedDay
        let done = exercises.filter { log?.taskStatuses[$0.id] == .completed }.count
        let total = exercises.count
        let summaryText = total == 0 ? "Active rest - walk, yoga, recover" : "\(done) of \(total) complete · \(max(total - done, 0)) left"

        return HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(selectedDay.rawValue)
                    .font(.title3.bold())
                Text(summaryText)
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if total > 0 {
                completionRing(done: done, total: total)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.35), in: RoundedRectangle(cornerRadius: 14))
    }

    private var sessionCommandDeck: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Current Focus")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .tracking(1)
                    Text(focusedExercise?.name ?? "Recovery and movement")
                        .font(.headline)
                    Text(sessionFocusSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                restTimerCard
            }

            if let focusedExercise {
                HStack(spacing: 8) {
                    Label(focusedExercise.targetReps, systemImage: "repeat")
                    Label("Rest \(focusedExercise.restSeconds)s", systemImage: "timer")
                    Label("\(focusedExercise.targetSets) sets", systemImage: "number.square")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Button {
                    if let next = nextExercise {
                        focusedExerciseID = next.id
                        restPresetSeconds = next.restSeconds
                    }
                } label: {
                    Label("Jump To Next", systemImage: "arrow.down.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.accent.cyan, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                Button {
                    startRestTimer()
                } label: {
                    Label(restTimerEnd == nil ? "Start Rest" : "Restart Rest", systemImage: "timer")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.black.opacity(0.78))
                }
                .buttonStyle(.plain)

                Button {
                    showFocusMode = true
                } label: {
                    Label("Focus Mode", systemImage: "eye.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .disabled(focusedExercise == nil)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.48), in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.45), lineWidth: 1)
        )
    }

    private var restTimerCard: some View {
        VStack(alignment: .trailing, spacing: 6) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(restTimeString(at: context.date))
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundStyle(restTimeRemaining(at: context.date) > 0 ? Color.appOrange2 : Color.black.opacity(0.78))
            }
            Text(restTimerEnd == nil ? "rest preset" : "remaining")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Stepper(value: $restPresetSeconds, in: 30...180, step: 15) {
                Text("\(restPresetSeconds)s")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .labelsHidden()
            .frame(width: 90)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
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
                            .font(.system(size: 14, weight: .semibold))
                        Text(isDone ? "Done — tap to clear" : restTimeString(at: context.date))
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
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
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(width: 146, alignment: .leading)
                        .background(
                            isFocused ? Color.appBlue1.opacity(0.35) : Color.white.opacity(0.28),
                            in: RoundedRectangle(cornerRadius: 14)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(isFocused ? Color.blue : Color.white.opacity(0.3), lineWidth: isFocused ? 1.5 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
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
                .font(.system(size: 10, weight: .bold, design: .monospaced))
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
            ExGroup(title: "🏋️ Machines",      exercises: all.filter { $0.category == .machine }),
            ExGroup(title: "🏋️ Free Weights",   exercises: all.filter { $0.category == .freeWeight }),
            ExGroup(title: "🤸 Calisthenics",   exercises: all.filter { $0.category == .calisthenics }),
            ExGroup(title: "🧘 Core Circuit",   exercises: all.filter { $0.category == .core }),
            ExGroup(title: "❤️ Cardio",         exercises: all.filter { $0.category == .cardio }),
        ]
    }

    private func makeBlankLog() -> DailyLog {
        DailyLog(
            date: activeDate,
            phase: dataStore.userProfile.currentPhase,
            dayType: selectedDay,
            recoveryDay: dataStore.userProfile.recoveryDay(for: activeDate)
        )
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
                    .font(.system(size: 18, weight: .semibold))
                Text(dayType.rawValue)
                    .font(.caption2.weight(.semibold))
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(borderColor, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var foregroundColor: Color {
        if isSelected   { return Color.blue }
        if isSuggested  { return Color.appOrange2 }
        return Color.primary
    }

    private var backgroundColor: Color {
        if isSelected   { return Color.blue.opacity(0.2) }
        if isSuggested  { return Color.appOrange1.opacity(0.25) }
        return Color.secondary.opacity(0.08)
    }

    private var borderColor: Color {
        if isSelected   { return Color.blue }
        if isSuggested  { return Color.appOrange2 }
        return Color.secondary.opacity(0.2)
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
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .tracking(1)
                .padding(.leading, 2)

            ForEach(exercises) { ex in
                ExerciseRowView(
                    exercise: ex,
                    selectedDay: selectedDay,
                    isFocused: focusedExerciseID == ex.id,
                    onFocus: { onFocusExercise(ex) },
                    log: $log,
                    onStartRest: onStartRest
                )
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
            .padding(12)
            .contentShape(Rectangle())
            .onTapGesture { onFocus() }

            // Expanded log panel (only when completed or partial)
            if status == .completed || status == .partial {
                Divider().padding(.leading, 12)
                if exercise.category == .cardio {
                    cardioPanel
                } else {
                    liftPanel
                }
            }
        }
        .background(rowBG, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(isFocused ? Color.blue.opacity(0.8) : accentColor.opacity(0.25), lineWidth: isFocused ? 1.5 : 1))
        .animation(.easeInOut(duration: 0.25), value: status)
    }

    // ── Status stripe
    private var statusStripe: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(accentColor)
            .frame(width: 3)
            .padding(.vertical, 4)
    }

    // ── Exercise info block
    private var exerciseInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(exercise.name)
                    .font(.subheadline.weight(.semibold))
                    .strikethrough(status == .completed, color: Color.status.success)
                    .foregroundStyle(status == .completed ? .secondary : .primary)
                if isFocused {
                    Text("LIVE")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.blue.opacity(0.12), in: Capsule())
                        .foregroundStyle(Color.blue)
                }
            }

            Text(exercise.muscleGroups.map { $0.rawValue.capitalized }.joined(separator: " · "))
                .font(.caption2).foregroundStyle(.secondary)

            if exercise.category != .cardio {
                HStack(spacing: 6) {
                    Pill("\(exercise.targetSets) sets")
                    Pill(exercise.targetReps)
                    Pill("Rest \(exercise.restSeconds)s")
                }
            }
            Text("↳ \(exercise.coachingCue)")
                .font(.caption2.italic()).foregroundStyle(.tertiary)
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
        case .completed: Color.status.success.opacity(0.03)
        case .missed: Color.status.error.opacity(0.03)
        default: isFocused ? Color.white.opacity(0.72) : Color(.systemBackground).opacity(0.5)
        }
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
        VStack(spacing: 0) {
            // Panel header
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(isFocused ? "LIVE SET LOG" : "SET LOG")
                        .font(.caption2.monospaced()).foregroundStyle(isFocused ? Color.blue : Color.status.success).tracking(1)
                    Spacer()
                    if exerciseLog.totalVolume > 0 {
                        Text("Total: \(Int(exerciseLog.totalVolume)) kg")
                            .font(.caption2.monospaced()).foregroundStyle(Color.status.success.opacity(0.8))
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
                        .padding(.horizontal, 12)
                        .padding(.top, 2)
                }

                if let suggestion = overloadSuggestion {
                    Text(suggestion)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.accent.cyan)
                        .padding(.horizontal, 12)
                        .padding(.top, 2)
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
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background((isFocused ? Color.blue.opacity(0.06) : Color.status.success.opacity(0.05)))

            // Column headers
            HStack(spacing: 0) {
                Text("SET").frame(width: 32, alignment: .leading)
                Text("KG").frame(maxWidth: .infinity)
                Text("REPS").frame(width: 52)
                Text("RPE").frame(width: 44)
                Text("NOTE").frame(maxWidth: .infinity)
                Text("DONE").frame(width: 56)
            }
            .font(.system(size: 9, design: .monospaced))
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 12).padding(.vertical, 5)
            .background(Color.secondary.opacity(0.05))

            // Set rows
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
                if i < exerciseLog.sets.count - 1 { Divider().padding(.leading, 12) }
            }

            if exerciseLog.sets.isEmpty {
                Text("Tap 'Add Set' to log your first set")
                    .font(.caption).foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity).padding(14)
            }

            // Notes
            Divider()
            HStack(spacing: 8) {
                Image(systemName: "note.text").font(.caption).foregroundStyle(.secondary)
                TextField("Session notes, form, pain, PR…", text: $exerciseLog.notes)
                    .font(.caption)
            }
            .padding(10)
        }
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
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
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
        HStack(spacing: 0) {
            // Set number
            Text("\(setNum)")
                .font(.system(.caption, design: .monospaced, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .leading)

            // Weight
            if weightStr.isEmpty, let prev = previousSet, let prevWeight = prev.weightKg {
                Button {
                    weightStr = formattedWeight(prevWeight)
                } label: {
                    Text(formattedWeight(prevWeight))
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6).padding(.horizontal, 4)
                        .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 5))
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.secondary.opacity(0.1)))
                }
            } else {
                TextField("0", text: $weightStr)
                    .font(.system(.body, design: .monospaced))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6).padding(.horizontal, 4)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 5))
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.secondary.opacity(0.2)))
                    .onChange(of: weightStr) { _, v in setLog.weightKg = Double(v) }
            }

            // Reps
            if repsStr.isEmpty, let prev = previousSet, let prevReps = prev.repsCompleted {
                Button {
                    repsStr = String(prevReps)
                } label: {
                    Text(String(prevReps))
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .frame(width: 48)
                        .padding(.vertical, 6).padding(.horizontal, 4)
                        .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 5))
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.secondary.opacity(0.1)))
                }
            } else {
                TextField("—", text: $repsStr)
                    .font(.system(.body, design: .monospaced))
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .frame(width: 48)
                    .padding(.vertical, 6).padding(.horizontal, 4)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 5))
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.secondary.opacity(0.2)))
                    .onChange(of: repsStr) { _, v in setLog.repsCompleted = Int(v) }
            }

            // RPE — 5-segment tap bar
            RPETapBar(rpe: Binding(get: { setLog.rpe }, set: { setLog.rpe = $0 }))
                .frame(maxWidth: .infinity)

            // Note
            TextField("—", text: $noteStr)
                .font(.caption)
                .frame(maxWidth: .infinity)
                .onChange(of: noteStr) { _, v in setLog.notes = v }

            // Done / complete-set
            Button {
                onCompleteSet()
                withAnimation(.easeOut(duration: 0.1)) { flashGreen = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    withAnimation(.easeIn(duration: 0.25)) { flashGreen = false }
                }
            } label: {
                Image(systemName: setIsComplete ? "checkmark.circle.fill" : "timer")
                    .foregroundStyle(setIsComplete ? Color.status.success : Color.appOrange2)
                    .font(.caption)
            }
            .frame(width: 28)

            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary).font(.caption)
            }
            .frame(width: 28)
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(flashGreen ? Color.status.success.opacity(0.12) : (setIsComplete ? Color.status.success.opacity(0.03) : Color.clear))
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
        VStack(alignment: .leading, spacing: 0) {
            // Panel header
            HStack {
                Text(cardioType == .rowing ? "🚣 ROWING LOG" : "🚴 ELLIPTICAL LOG")
                    .font(.caption2.monospaced()).foregroundStyle(Color.status.success).tracking(1)
                Spacer()
                if let zone = cardioLog.wasInZone2(lower: dataStore.userPreferences.zone2LowerHR, upper: dataStore.userPreferences.zone2UpperHR) {
                    Text(zone ? "✓ Zone 2" : "↑ Above Zone 2")
                        .font(.caption2.monospaced())
                        .foregroundStyle(zone ? Color.status.success : Color.status.warning)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color.status.success.opacity(0.05))

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
            .padding(12)

            // Notes
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "note.text").foregroundStyle(.secondary).font(.caption)
                TextField("Feel, energy, breathing, HR stability…", text: $cardioLog.notes, axis: .vertical)
                    .font(.caption).lineLimit(2...4)
            }
            .padding(10)
            .background(Color.secondary.opacity(0.04))

            Divider()

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
                        .padding(.horizontal, 10).padding(.vertical, 5)
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
                        .padding(.horizontal, 10).padding(.vertical, 5)
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
                        .clipShape(RoundedRectangle(cornerRadius: 10))
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
                            .padding(8)
                        }
                        .onTapGesture { showImageExpanded = true }
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.secondary.opacity(0.07))
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
            .padding(12)
        }
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
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.secondary).textCase(.uppercase).tracking(0.5)
            TextField(placeholder, text: $value)
                .font(.system(.body, design: .monospaced))
                .keyboardType(.decimalPad)
                .padding(7)
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2)))
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
                        .padding(.vertical, 5)
                        .background(
                            isSelected
                                ? Color.appOrange2
                                : Color(.systemBackground),
                            in: RoundedRectangle(cornerRadius: 4)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(isSelected ? Color.appOrange2 : Color.secondary.opacity(0.2), lineWidth: 1)
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
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(color.opacity(0.25)))
        }
    }

    private var color: Color {
        switch status {
        case .completed: Color.status.success; case .partial: Color.status.warning; case .missed: Color.status.error; case .pending: .secondary
        }
    }
}

struct Pill: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.system(size: 9, design: .monospaced))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
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
                    .padding(.top, 8)

                    // Warm completion micro-copy
                    Text(completionMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)

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
                                .padding(.vertical, 14)
                                .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)

                        Button(action: onDone) {
                            Text("Done")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .foregroundStyle(.black)
                                .background(
                                    LinearGradient(colors: [Color.status.success, Color.status.success.opacity(0.8)],
                                                   startPoint: .leading, endPoint: .trailing),
                                    in: RoundedRectangle(cornerRadius: 14)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
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
        .padding(14)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
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

            VStack(spacing: 32) {
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
                .padding(.horizontal, 24)
                .padding(.top, 16)

                Spacer()

                // Exercise name
                Text(exercise.name)
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

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
                .padding(.horizontal, 32)

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
                        .padding(.vertical, 20)
                        .background(Color.status.success, in: RoundedRectangle(cornerRadius: 20))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 32)
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
        TextField(placeholder, text: text)
            .font(.system(size: 42, weight: .bold, design: .monospaced))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .keyboardType(.decimalPad)
            .padding(16)
            .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
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
                    .padding(.horizontal, 24)

                Button("Continue") {
                    autoDismissTimer?.invalidate()
                    onDismiss()
                }
                .font(.headline)
                .padding(.horizontal, 40)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 20))
                .foregroundStyle(.white)
            }
            .padding(32)
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
