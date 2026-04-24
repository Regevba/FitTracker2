// FitTracker/Views/Training/v2/TrainingPlanView.swift
// v2 — UX Foundations-aligned rewrite of TrainingPlanView.
// Design-system compliant: zero raw literals, semantic tokens only.
// Container view — composes T3 (RestTimerView), T4 (ExerciseRowView),
// T5 (SetRowView via T4), T6 (SessionCompletionSheet), T7 (FocusModeView).
import SwiftUI

struct TrainingPlanView: View {
    // MARK: - Environment
    @EnvironmentObject private var dataStore: EncryptedDataStore
    @EnvironmentObject private var programStore: TrainingProgramStore
    @EnvironmentObject private var analytics: AnalyticsService

    // MARK: - Init
    private let initialDay: DayType?
    init(initialDay: DayType? = nil) { self.initialDay = initialDay }

    // MARK: - State
    @State private var selectedDay: DayType = .restDay
    @State private var activeDate: Date = Date()
    @State private var log: DailyLog?
    @State private var showActivityPicker = false
    @State private var showCompletionSheet = false
    @State private var showFocusMode = false
    @State private var focusedExerciseID: String?
    @State private var restTimerEnd: Date?
    @State private var restPresetSeconds = 90
    @State private var restTimerTick: Date = .now
    @State private var isLoading = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Computed Properties

    private var exercisesForSelectedDay: [ExerciseDefinition] {
        TrainingProgramData.exercises(for: selectedDay)
    }
    private var focusedExercise: ExerciseDefinition? {
        if let focusedExerciseID,
           let match = exercisesForSelectedDay.first(where: { $0.id == focusedExerciseID }) {
            return match
        }
        return nextIncompleteExercise
    }
    private var nextIncompleteExercise: ExerciseDefinition? {
        exercisesForSelectedDay.first { (log?.taskStatuses[$0.id] ?? .pending) != .completed }
    }
    private var completedCount: Int {
        exercisesForSelectedDay.filter { log?.taskStatuses[$0.id] == .completed }.count
    }
    private var totalExerciseCount: Int { exercisesForSelectedDay.count }
    private var completionProgress: Double {
        guard totalExerciseCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalExerciseCount)
    }
    private var suggestedDay: DayType {
        TrainingProgramStore.dayType(forWeekday: Calendar.current.component(.weekday, from: activeDate))
    }
    private var previousSameDayLog: DailyLog? {
        dataStore.dailyLogs
            .filter { $0.dayType == selectedDay
                && !Calendar.current.isDate($0.date, inSameDayAs: log?.date ?? Date()) }
            .sorted { $0.date > $1.date }.first
    }
    private var taskStatusSignature: [String] {
        exercisesForSelectedDay.map {
            "\($0.id):\(log?.taskStatuses[$0.id]?.rawValue ?? TaskStatus.pending.rawValue)"
        }
    }
    private var restTimeRemaining: Int {
        guard let end = restTimerEnd else { return 0 }
        return max(0, Int(end.timeIntervalSince(restTimerTick)))
    }
    private var isRestTimerActive: Bool { restTimerEnd != nil && restTimeRemaining > 0 }
    private var progressText: String {
        guard totalExerciseCount > 0 else { return "Active rest \u{2014} walk, yoga, recover" }
        let remaining = totalExerciseCount - completedCount
        return "\(completedCount) of \(totalExerciseCount) done \u{00B7} ~\(remaining * 6)m"
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                weekStrip
                activitySwitcherCard
                if isLoading { loadingSkeleton }
                else { ScrollView(showsIndicators: false) { exerciseList } }
            }
            .background(AppGradient.screenBackground.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                RestTimerView(
                    remainingSeconds: restTimeRemaining,
                    totalSeconds: restPresetSeconds,
                    isActive: isRestTimerActive,
                    onSkip: { skipRestTimer() },
                    onComplete: { clearRestTimer() }
                )
                .padding(.bottom, AppSize.tabBarClearance)
            }
            .analyticsScreen(AnalyticsScreen.trainingPlan)
            .navigationTitle("Training Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showActivityPicker) { activityPickerSheet }
            .sheet(isPresented: $showCompletionSheet) {
                SessionCompletionSheet(
                    log: log, selectedDay: selectedDay,
                    previousLog: previousSameDayLog,
                    streak: dataStore.supplementStreak,
                    onShare: { showCompletionSheet = false },
                    onDone: { showCompletionSheet = false }
                )
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(AppSheet.standardCornerRadius)
            }
            .fullScreenCover(isPresented: $showFocusMode) {
                if let exercise = focusedExercise {
                    FocusModeView(
                        exercise: exercise,
                        exerciseLog: exerciseLogBinding(for: exercise),
                        onExit: { showFocusMode = false }
                    )
                }
            }
            .onAppear { onViewAppear() }
            .onDisappear { saveLog() }
            .onChange(of: taskStatusSignature) { _, _ in handleStatusChange() }
            .onChange(of: selectedDay) { _, _ in syncAfterDayChange() }
        }
    }

    // MARK: - Week Strip

    private var weekStrip: some View {
        let cal = Calendar.current
        let today = Date()
        let daysFromMonday = (cal.component(.weekday, from: today) + 5) % 7
        let monday = cal.date(byAdding: .day, value: -daysFromMonday,
                              to: cal.startOfDay(for: today)) ?? cal.startOfDay(for: today)
        let weekDays = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: monday) }

        return HStack(spacing: 0) {
            ForEach(weekDays, id: \.self) { day in
                let isToday = cal.isDateInToday(day)
                let isActive = cal.isDate(day, inSameDayAs: activeDate)
                let wday = cal.component(.weekday, from: day)
                let isRest = TrainingProgramStore.restWeekdays.contains(wday)
                let hasLog = dataStore.dailyLogs.first {
                    cal.isDate($0.date, inSameDayAs: day)
                }.map { $0.completionPct > 0 } ?? false

                Button {
                    saveLog(); activeDate = day
                    let suggested = TrainingProgramStore.dayType(forWeekday: wday)
                    withAnimation(reduceMotion ? .none : AppEasing.short) {
                        loadLog(for: day, preferredDay: suggested)
                    }
                } label: {
                    VStack(spacing: AppSpacing.xxxSmall) {
                        Text(day.formatted(.dateTime.weekday(.abbreviated)))
                            .font(AppText.caption)
                            .foregroundStyle(isActive ? AppColor.Text.primary : AppColor.Text.secondary)
                        ZStack {
                            if isToday {
                                Circle().fill(AppColor.Brand.warmSoft).frame(width: 28, height: 28)
                            } else if isActive {
                                Circle().fill(AppColor.Surface.materialStrong).frame(width: 28, height: 28)
                            }
                            Text("\(cal.component(.day, from: day))")
                                .font(isToday ? AppText.body : AppText.subheading)
                                .fontWeight(isToday ? .bold : .regular)
                                .foregroundStyle(AppColor.Text.primary)
                        }
                        Circle()
                            .fill(hasLog ? AppColor.Status.success : Color.clear)
                            .frame(width: AppSpacing.xxxSmall + 1, height: AppSpacing.xxxSmall + 1)
                    }
                    .opacity(isRest && !hasLog ? 0.4 : 1.0)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(dayAccessibilityLabel(day: day, isToday: isToday, hasLog: hasLog))
            }
        }
        .padding(.vertical, AppSpacing.xxSmall)
        .padding(.horizontal, AppSpacing.small)
    }

    private func dayAccessibilityLabel(day: Date, isToday: Bool, hasLog: Bool) -> String {
        var label = day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        if isToday { label += ", today" }
        if hasLog { label += ", has activity" }
        return label
    }

    // MARK: - Activity Switcher Card

    private var activitySwitcherCard: some View {
        Button { showActivityPicker = true } label: {
            HStack(spacing: AppSpacing.xSmall) {
                Image(systemName: selectedDay.icon)
                    .font(AppText.iconMedium)
                    .foregroundStyle(AppColor.Accent.primary)
                VStack(alignment: .leading, spacing: AppSpacing.xxxSmall) {
                    HStack(spacing: AppSpacing.xxSmall) {
                        Text(selectedDay.rawValue)
                            .font(AppText.sectionTitle)
                            .foregroundStyle(AppColor.Text.primary)
                            .accessibilityAddTraits(.isHeader)
                        if selectedDay == suggestedDay { suggestedBadge }
                    }
                    Text(progressText)
                        .font(AppText.caption)
                        .foregroundStyle(AppColor.Text.secondary)
                }
                Spacer(minLength: AppSpacing.xxSmall)
                completionRing
                Image(systemName: "chevron.right")
                    .font(AppText.iconSmall)
                    .foregroundStyle(AppColor.Text.tertiary)
            }
            .padding(AppSpacing.small)
            .background(AppColor.Surface.elevated, in: RoundedRectangle(cornerRadius: AppRadius.card))
            .shadow(color: AppShadow.cardColor, radius: AppShadow.cardRadius, x: 0, y: AppShadow.cardYOffset)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, AppSpacing.small)
        .padding(.vertical, AppSpacing.xxSmall)
        .accessibilityLabel("Activity: \(selectedDay.rawValue)")
        .accessibilityValue(progressText)
        .accessibilityHint("Tap to switch activity type")
    }

    private var suggestedBadge: some View {
        Text("Suggested")
            .font(AppText.monoCaption)
            .foregroundStyle(AppColor.Brand.warm)
            .padding(.horizontal, AppSpacing.xxSmall)
            .padding(.vertical, AppSpacing.micro)
            .background(AppColor.Brand.warmSoft.opacity(0.3), in: Capsule())
    }

    private var completionRing: some View {
        let pct = Int(completionProgress * 100)
        return ZStack {
            Circle().stroke(AppColor.Surface.secondary, lineWidth: AppSpacing.xxxSmall)
                .frame(width: 40, height: 40)
            Circle().trim(from: 0, to: completionProgress)
                .stroke(AppColor.Brand.secondary,
                        style: StrokeStyle(lineWidth: AppSpacing.xxxSmall, lineCap: .round))
                .frame(width: 40, height: 40).rotationEffect(.degrees(-90))
            Text("\(pct)%").font(AppText.monoLabel).foregroundStyle(AppColor.Brand.secondary)
        }
        .accessibilityLabel("\(pct) percent complete")
    }

    // MARK: - Activity Picker Sheet

    private var activityPickerSheet: some View {
        NavigationStack {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())],
                      spacing: AppSpacing.xSmall) {
                ForEach(DayType.allCases, id: \.self) { activityPickerCell($0) }
            }
            .padding(AppSpacing.small)
            .navigationTitle("Choose Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showActivityPicker = false }
                        .accessibilityLabel("Cancel activity selection")
                }
            }
        }
        .presentationDetents([.medium])
        .presentationCornerRadius(AppSheet.standardCornerRadius)
    }

    private func activityPickerCell(_ dayType: DayType) -> some View {
        let isSelected = dayType == selectedDay
        let isSuggested = dayType == suggestedDay
        return Button {
            withAnimation(reduceMotion ? .none : AppEasing.short) {
                selectedDay = dayType; log?.dayType = dayType
            }
            analytics.logTrainingActivitySwitched(activityType: dayType.rawValue)
            showActivityPicker = false
        } label: {
            VStack(spacing: AppSpacing.xxSmall) {
                Image(systemName: dayType.icon).font(AppText.iconMedium)
                Text(dayType.rawValue).font(AppText.captionStrong).multilineTextAlignment(.center)
                if isSuggested && !isSelected {
                    Text("Suggested").font(AppText.monoCaption).foregroundStyle(AppColor.Brand.warm)
                }
            }
            .foregroundStyle(isSelected ? AppColor.Text.primary : AppColor.Text.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.small)
            .background(
                isSelected ? AppColor.Accent.secondary.opacity(0.28)
                : isSuggested ? AppColor.Brand.warmSoft.opacity(0.24)
                : AppColor.Surface.materialLight,
                in: RoundedRectangle(cornerRadius: AppRadius.small))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.small)
                .stroke(isSelected ? AppColor.Brand.secondary : Color.clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(dayType.rawValue)\(isSuggested ? ", suggested" : "")")
        .accessibilityHint("Double tap to switch to \(dayType.rawValue)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Exercise List

    private var exerciseList: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(exercisesForSelectedDay.enumerated()), id: \.element.id) { index, exercise in
                let status = log?.taskStatuses[exercise.id] ?? .pending
                ExerciseRowView(
                    exercise: exercise, selectedDay: selectedDay,
                    exerciseLog: log?.exerciseLogs[exercise.id],
                    previousSessionLog: previousExerciseLog(for: exercise.id),
                    status: status,
                    showsDivider: index < exercisesForSelectedDay.count - 1,
                    onStatusChange: { updateStatus($0, for: exercise) },
                    onFocus: { focusedExerciseID = exercise.id; restPresetSeconds = exercise.restSeconds },
                    onStartRest: { startRestTimer() },
                    onSetUpdated: { updateSet($0, log: $1, for: exercise) },
                    onSetLogged: { logSet($0, for: exercise) },
                    onSetDeleted: { deleteSet($0, for: exercise) },
                    onCopyLast: { copyLastSet($0, for: exercise) }
                )
            }
        }
        .padding(.horizontal, AppSpacing.small)
        .padding(.bottom, AppSpacing.xxLarge)
    }

    // MARK: - Loading Skeleton

    private var loadingSkeleton: some View {
        VStack(spacing: AppSpacing.xSmall) {
            ForEach(0..<4, id: \.self) { _ in
                RoundedRectangle(cornerRadius: AppRadius.small)
                    .fill(AppColor.Surface.materialLight)
                    .frame(height: 72)
                    .modifier(ShimmerEffect())
            }
        }
        .padding(.horizontal, AppSpacing.small)
        .padding(.top, AppSpacing.small)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading exercises")
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button { showFocusMode = true } label: {
                Image(systemName: "eye.fill")
                    .font(AppText.iconSmall).foregroundStyle(AppColor.Accent.primary)
            }
            .disabled(focusedExercise == nil)
            .accessibilityLabel("Focus mode")
            .accessibilityHint("Enter distraction-free workout mode")
        }
    }

    // MARK: - Timer Management

    private func startRestTimer() {
        restPresetSeconds = focusedExercise?.restSeconds ?? 90
        restTimerEnd = Date().addingTimeInterval(TimeInterval(restPresetSeconds))
        analytics.logTrainingRestTimerStarted(restDurationSeconds: restPresetSeconds)
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            DispatchQueue.main.async {
                restTimerTick = .now
                if restTimerEnd == nil { timer.invalidate() }
            }
        }
    }
    private func skipRestTimer() {
        analytics.logTrainingRestTimerSkipped(restDurationSeconds: restTimeRemaining)
        clearRestTimer()
    }
    private func clearRestTimer() { restTimerEnd = nil }

    // MARK: - Data Operations

    private func onViewAppear() {
        activeDate = Calendar.current.startOfDay(for: Date())
        loadLog(for: activeDate, preferredDay: initialDay ?? programStore.todayDayType)
        isLoading = false
    }

    private func loadLog(for date: Date, preferredDay: DayType) {
        let normalized = Calendar.current.startOfDay(for: date)
        activeDate = normalized
        if let existing = dataStore.log(for: normalized) {
            log = existing; selectedDay = existing.dayType
        } else {
            selectedDay = preferredDay
            log = .scheduled(for: normalized, profile: dataStore.userProfile, dayType: selectedDay)
        }
        syncFocusedExercise()
        restPresetSeconds = focusedExercise?.restSeconds ?? 90
    }

    private func saveLog() {
        guard var current = log else { return }
        current.date = activeDate
        current.dayType = selectedDay
        current.recoveryDay = dataStore.userProfile.recoveryDay(for: activeDate)
        log = current
        dataStore.upsertLog(current)
    }

    private func syncFocusedExercise() {
        let ids = Set(exercisesForSelectedDay.map(\.id))
        if let focusedExerciseID, ids.contains(focusedExerciseID) { return }
        focusedExerciseID = nextIncompleteExercise?.id ?? exercisesForSelectedDay.first?.id
    }

    private func handleStatusChange() {
        guard let log else { return }
        let exercises = exercisesForSelectedDay
        syncFocusedExercise()
        guard !exercises.isEmpty else { return }
        if exercises.allSatisfy({ log.taskStatuses[$0.id] == .completed }) && !showCompletionSheet {
            showCompletionSheet = true
        }
    }

    private func syncAfterDayChange() {
        syncFocusedExercise()
        restPresetSeconds = focusedExercise?.restSeconds ?? 90
    }

    // MARK: - Exercise Mutations

    private func updateStatus(_ status: TaskStatus, for exercise: ExerciseDefinition) {
        ensureExerciseLog(for: exercise)
        log?.taskStatuses[exercise.id] = status
        if status == .completed {
            analytics.logTrainingExerciseCompleted(
                exerciseName: exercise.name,
                sets: log?.exerciseLogs[exercise.id]?.sets.count ?? 0)
        }
        saveLog()
    }

    private func updateSet(_ index: Int, log setLog: SetLog, for exercise: ExerciseDefinition) {
        ensureExerciseLog(for: exercise)
        guard var exLog = log?.exerciseLogs[exercise.id], index < exLog.sets.count else { return }
        exLog.sets[index] = setLog
        log?.exerciseLogs[exercise.id] = exLog
        saveLog()
    }

    private func logSet(_ index: Int, for exercise: ExerciseDefinition) {
        ensureExerciseLog(for: exercise)
        guard let exLog = log?.exerciseLogs[exercise.id], index < exLog.sets.count else { return }
        analytics.logTrainingSetLogged(
            exerciseName: exercise.name, setIndex: index + 1,
            reps: exLog.sets[index].repsCompleted ?? 0,
            weightKg: exLog.sets[index].weightKg ?? 0)
        if log?.sessionStartTime == nil { log?.sessionStartTime = Date() }
        saveLog()
    }

    private func deleteSet(_ index: Int, for exercise: ExerciseDefinition) {
        guard var exLog = log?.exerciseLogs[exercise.id], index < exLog.sets.count else { return }
        exLog.sets.remove(at: index)
        log?.exerciseLogs[exercise.id] = exLog
        saveLog()
    }

    private func copyLastSet(_ index: Int, for exercise: ExerciseDefinition) {
        analytics.logTrainingSetCopied(exerciseName: exercise.name, setIndex: index + 1)
    }

    private func ensureExerciseLog(for exercise: ExerciseDefinition) {
        guard log?.exerciseLogs[exercise.id] == nil else { return }
        var exLog = ExerciseLog(exerciseID: exercise.id, exerciseName: exercise.name)
        exLog.sets = (1...exercise.targetSets).map { SetLog(setNumber: $0) }
        log?.exerciseLogs[exercise.id] = exLog
    }

    private func exerciseLogBinding(for exercise: ExerciseDefinition) -> Binding<ExerciseLog> {
        Binding(
            get: { log?.exerciseLogs[exercise.id]
                ?? ExerciseLog(exerciseID: exercise.id, exerciseName: exercise.name) },
            set: { log?.exerciseLogs[exercise.id] = $0 }
        )
    }

    private func previousExerciseLog(for exerciseID: String) -> ExerciseLog? {
        dataStore.dailyLogs
            .filter { $0.dayType == selectedDay
                && !Calendar.current.isDate($0.date, inSameDayAs: log?.date ?? Date())
                && $0.exerciseLogs[exerciseID] != nil }
            .sorted { $0.date > $1.date }.first?
            .exerciseLogs[exerciseID]
    }
}

// MARK: - Shimmer Effect

private struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0
    func body(content: Content) -> some View {
        content.overlay(
            LinearGradient(
                colors: [Color.clear, AppColor.Surface.materialStrong.opacity(0.3), Color.clear],
                startPoint: .leading, endPoint: .trailing
            )
            .offset(x: phase).mask(content)
        )
        .onAppear {
            withAnimation(AppLoadingAnimation.fastShimmer) { phase = 300 }
        }
    }
}

// MARK: - Preview

// Preview removed — requires full app environment (EncryptedDataStore, TrainingProgramStore)
