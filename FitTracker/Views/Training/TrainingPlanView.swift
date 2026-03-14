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
    private let bgOrange1 = Color.appOrange1
    private let bgOrange2 = Color.appOrange2
    private let appBlue   = Color.blue

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
                    exerciseSections
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Training Plan")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            selectedDay = initialDay ?? programStore.todayDayType
            log = dataStore.todayLog() ?? makeBlankLog()
        }
        .onDisappear {
            // Persist on disappear; the scene .background handler in FitTrackerApp
            // ensures this reaches disk even if the app is about to be suspended.
            if let current = log {
                dataStore.upsertLog(current)
            }
        }
        .onChange(of: log) { _, newLog in
            guard let log = newLog else { return }
            let exercises = TrainingProgramData.exercises(for: selectedDay)
            guard !exercises.isEmpty else { return }
            let allDone = exercises.allSatisfy { log.taskStatuses[$0.id] == .completed }
            if allDone && !showCompletionSheet {
                showCompletionSheet = true
            }
        }
        .sheet(isPresented: $showCompletionSheet) {
            SessionCompletionSheet(
                log: log,
                selectedDay: selectedDay,
                previousLog: previousSameDayLog,
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
        let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: calendar.startOfDay(for: today))!
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
                    activeDate = day
                    // Derive suggested day type from weekday
                    let suggested = TrainingProgramStore.dayType(forWeekday: wday)
                    withAnimation(.easeInOut(duration: 0.2)) { selectedDay = suggested }
                }
            }
        }
        .padding(.vertical, 8)
        .onAppear { activeDate = today }
    }

    // ─────────────────────────────────────────────────────
    // Session summary header
    // ─────────────────────────────────────────────────────

    private var sessionHeader: some View {
        let exercises = TrainingProgramData.exercises(for: selectedDay)
        let done = exercises.filter { log?.taskStatuses[$0.id] == .completed }.count
        let total = exercises.count
        let summaryText = total == 0 ? "Active rest - walk, yoga, recover" : "\(total) exercises - \(done) done"

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
        let exercises = TrainingProgramData.exercises(for: selectedDay)
        let grouped = groupedExercises(exercises)

        return ForEach(grouped, id: \.title) { group in
            if !group.exercises.isEmpty {
                ExerciseSectionBlock(
                    title: group.title,
                    exercises: group.exercises,
                    selectedDay: selectedDay,
                    log: $log
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
        DailyLog(date: Date(), phase: dataStore.userProfile.currentPhase,
                 dayType: selectedDay, recoveryDay: dataStore.userProfile.daysSinceStart)
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
        if let l = log { dataStore.upsertLog(l) }
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
    @Binding var log: DailyLog?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .tracking(1)
                .padding(.leading, 2)

            ForEach(exercises) { ex in
                ExerciseRowView(exercise: ex, selectedDay: selectedDay, log: $log)
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
    @Binding var log: DailyLog?

    private var status: TaskStatus { log?.taskStatuses[exercise.id] ?? .pending }

    private var previousSessionLog: ExerciseLog? {
        dataStore.dailyLogs
            .filter {
                $0.dayType == selectedDay &&
                !Calendar.current.isDateInToday($0.date) &&
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
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(accentColor.opacity(0.25), lineWidth: 1))
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
            Text(exercise.name)
                .font(.subheadline.weight(.semibold))
                .strikethrough(status == .completed, color: Color.status.success)
                .foregroundStyle(status == .completed ? .secondary : .primary)

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
            previousSessionLog: previousSessionLog,
            exerciseLog: Binding(
                get: { log?.exerciseLogs[exercise.id] ?? ExerciseLog(exerciseID: exercise.id, exerciseName: exercise.name) },
                set: {
                    ensureLogMetadata()
                    log?.exerciseLogs[exercise.id] = $0
                }
            )
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
        case .completed: Color.status.success.opacity(0.03); case .missed: Color.status.error.opacity(0.03); default: Color(.systemBackground).opacity(0.5)
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
    let previousSessionLog: ExerciseLog?
    @Binding var exerciseLog: ExerciseLog

    var body: some View {
        VStack(spacing: 0) {
            // Panel header
            HStack {
                Text("📋 SET LOG")
                    .font(.caption2.monospaced()).foregroundStyle(Color.status.success).tracking(1)
                Spacer()
                if exerciseLog.totalVolume > 0 {
                    Text("Total: \(Int(exerciseLog.totalVolume)) kg")
                        .font(.caption2.monospaced()).foregroundStyle(Color.status.success.opacity(0.8))
                }
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
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color.status.success.opacity(0.05))

            // Column headers
            HStack(spacing: 0) {
                Text("SET").frame(width: 32, alignment: .leading)
                Text("KG").frame(maxWidth: .infinity)
                Text("REPS").frame(width: 52)
                Text("RPE").frame(width: 44)
                Text("NOTE").frame(maxWidth: .infinity)
                Spacer().frame(width: 28)
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
}

struct SetRowView: View {
    @Binding var setLog: SetLog
    let setNum:  Int
    let previousSet: SetLog?
    let onDelete: () -> Void

    @State private var weightStr = ""
    @State private var repsStr   = ""
    @State private var noteStr   = ""

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
                    weightStr = String(format: "%.1f", prevWeight)
                } label: {
                    Text(String(format: "%.1f", prevWeight))
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

            // Delete
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary).font(.caption)
            }
            .frame(width: 28)
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .onAppear {
            weightStr = setLog.weightKg.map { String($0) } ?? ""
            repsStr   = setLog.repsCompleted.map { String($0) } ?? ""
            noteStr   = setLog.notes
        }
        // Re-sync local strings if the binding is updated externally (e.g. CloudKit merge).
        .onChange(of: setLog) { _, newLog in
            weightStr = newLog.weightKg.map { String($0) } ?? ""
            repsStr   = newLog.repsCompleted.map { String($0) } ?? ""
            noteStr   = newLog.notes
        }
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – Cardio Log Panel (Elliptical + Rowing + Photo)
// ─────────────────────────────────────────────────────────

struct CardioLogPanel: View {
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
                if let zone = cardioLog.wasInZone2 {
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
    let onDone: () -> Void
    let onLogNotes: () -> Void

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
            }
            .navigationBarTitleDisplayMode(.inline)
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

    private var durationStr: String {
        guard let exLogs = log?.exerciseLogs.values, !exLogs.isEmpty else { return "—" }
        let allTimestamps = exLogs.flatMap { $0.sets }.map(\.timestamp)
        guard let first = allTimestamps.min(), let last = allTimestamps.max() else { return "—" }
        let minutes = Int(last.timeIntervalSince(first) / 60)
        return minutes > 0 ? "\(minutes) min" : "< 1 min"
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
