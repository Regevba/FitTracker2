// Views/Nutrition/NutritionView.swift
// Tab 3: Nutrition
//   At this stage: supplement tracking only
//   Morning stack + Evening stack, per-supplement check-off

import SwiftUI

struct NutritionView: View {

    @EnvironmentObject var dataStore: EncryptedDataStore
    @State private var activeDate: Date = Date()
    @State private var log: DailyLog?
    @State private var supplementsExpanded = false
    @State private var editingMealEntry: MealEntry?
    @State private var showSupplementInfo = false

    private var morning: [SupplementDefinition] { TrainingProgramData.morningSupplements }
    private var evening: [SupplementDefinition] { TrainingProgramData.eveningSupplements }

    private let bgOrange1 = Color.appOrange1
    private let bgOrange2 = Color.appOrange2

    var body: some View {
        ZStack {
            LinearGradient(colors: [bgOrange1, bgOrange2],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                dateHeader
                nutritionCommandDeck
                macroBar
                quickLogSection
                hydrationCard
                adherenceRow
                mealSection
                supplementRow

                disclaimerNote
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 40)
        }
        } // ZStack
        .navigationTitle("Nutrition")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .onAppear {
            activeDate = Calendar.current.startOfDay(for: Date())
            loadLog(for: activeDate)
        }
        .onDisappear { saveLog() }
        .sheet(item: $editingMealEntry) { entry in
            let entryBinding = Binding<MealEntry>(
                get: { log?.nutritionLog.meals.first(where: { $0.mealNumber == entry.mealNumber }) ?? entry },
                set: { newEntry in
                    if let i = log?.nutritionLog.meals.firstIndex(where: { $0.mealNumber == entry.mealNumber }) {
                        log?.nutritionLog.meals[i] = newEntry
                    } else {
                        log?.nutritionLog.meals.append(newEntry)
                    }
                }
            )
            MealEntrySheet(entry: entryBinding) { saved in
                if let i = log?.nutritionLog.meals.firstIndex(where: { $0.mealNumber == saved.mealNumber }) {
                    log?.nutritionLog.meals[i] = saved
                } else {
                    log?.nutritionLog.meals.append(saved)
                }
                saveLog()
                editingMealEntry = nil
            }
            .environmentObject(dataStore)
            .presentationDetents([.large])
            .presentationCornerRadius(24)
        }
    }

    // ─────────────────────────────────────────────────────
    // Derived state
    // ─────────────────────────────────────────────────────

    private var morningStatus: TaskStatus { log?.supplementLog.morningStatus ?? .pending }
    private var eveningStatus: TaskStatus { log?.supplementLog.eveningStatus ?? .pending }

    private var individualStatus: [String: Bool] {
        log?.supplementLog.individualOverrides ?? [:]
    }

    private var nutritionLog: NutritionLog {
        log?.nutritionLog ?? NutritionLog()
    }

    private var currentPhase: ProgramPhase {
        dataStore.userProfile.currentPhase
    }

    private var isTrainingDay: Bool {
        (log?.dayType ?? suggestedDay(for: activeDate)).isTrainingDay
    }

    private var targetCalories: Double {
        isTrainingDay ? Double(currentPhase.trainingCalories) : Double(currentPhase.restCalories)
    }

    private var targetProteinG: Double {
        if let leanMass = log?.biometrics.leanBodyMassKg {
            return leanMass * 2
        }
        return 135
    }

    private var consumedCalories: Double {
        nutritionLog.resolvedCalories ?? 0
    }

    private var consumedProteinG: Double {
        nutritionLog.resolvedProteinG ?? 0
    }

    private var remainingCalories: Double {
        max(targetCalories - consumedCalories, 0)
    }

    private var remainingProteinG: Double {
        max(targetProteinG - consumedProteinG, 0)
    }

    private var nextMealNumber: Int {
        max((nutritionLog.meals.map(\.mealNumber).max() ?? 0) + 1, 1)
    }

    private var completionText: String {
        let completedMeals = nutritionLog.meals.filter { $0.status == .completed }.count
        let templateCount = dataStore.mealTemplates.count
        if completedMeals == 0 {
            return templateCount > 0 ? "Use your saved meals to log faster." : "Log your first meal to start building momentum."
        }
        if remainingProteinG > 25 {
            return "Protein is the main gap right now. A quick repeat meal can close it fast."
        }
        if remainingCalories > 400 {
            return "You still have room in the plan. Finish the day with one more full meal."
        }
        return "Nutrition is on track. Keep hydration and supplements tight."
    }

    private var recentMeals: [MealEntry] {
        var seen = Set<String>()
        return dataStore.dailyLogs
            .sorted { $0.date > $1.date }
            .filter { !Calendar.current.isDate($0.date, inSameDayAs: activeDate) }
            .flatMap { $0.nutritionLog.meals }
            .filter { $0.status == .completed && !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
            .filter { meal in
                let key = meal.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                return seen.insert(key).inserted
            }
            .prefix(6)
            .map { $0 }
    }

    // ─────────────────────────────────────────────────────
    // Sub-views
    // ─────────────────────────────────────────────────────

    private var dateHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Nutrition")
                        .font(.title2.bold())
                    Text(formattedActiveDate)
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                overallBadge
            }

            HStack(spacing: 10) {
                Button {
                    shiftDay(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.primary)
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.7), in: Circle())
                }
                .buttonStyle(.plain)

                Button {
                    activeDate = Calendar.current.startOfDay(for: Date())
                    loadLog(for: activeDate)
                } label: {
                    Text(isViewingToday ? "Today" : "Jump to Today")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isViewingToday ? .secondary : .primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Color.white.opacity(0.58), in: Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    shiftDay(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.primary)
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.7), in: Circle())
                }
                .buttonStyle(.plain)

                Spacer()

                Text(log?.dayType.rawValue ?? suggestedDay(for: activeDate).rawValue)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.5), in: Capsule())
            }
        }
        .padding(.top, 6)
    }

    private var overallBadge: some View {
        let total  = morning.count + evening.count
        let taken  = individualStatus.filter { $0.value }.count
        let pct    = total > 0 ? Int(Double(taken) / Double(total) * 100) : 0
        return VStack(spacing: 2) {
            Text("\(pct)%")
                .font(.system(.title3, design: .monospaced, weight: .bold))
                .foregroundStyle(Color.status.success)
            Text("supps")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var nutritionCommandDeck: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Nutrition Focus")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .tracking(1)
                    Text(remainingProteinG > 25 ? "Close the protein gap" : "Stay consistent through the day")
                        .font(.headline)
                    Text(completionText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Text("\(Int(remainingCalories))")
                        .font(.system(.title3, design: .monospaced, weight: .bold))
                        .foregroundStyle(Color.appOrange2)
                    Text("kcal left")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                quickActionButton(
                    title: nutritionLog.meals.isEmpty ? "Log First Meal" : "Add Meal",
                    icon: "plus.circle.fill",
                    tint: Color.accent.cyan
                ) {
                    editingMealEntry = MealEntry(mealNumber: nextMealNumber)
                }

                quickActionButton(
                    title: recentMeals.isEmpty ? "Quick Protein" : "Repeat Last",
                    icon: recentMeals.isEmpty ? "bolt.heart.fill" : "clock.arrow.circlepath",
                    tint: Color.status.success
                ) {
                    if let recent = recentMeals.first {
                        openPrefilledMeal(recent)
                    } else {
                        editingMealEntry = MealEntry(
                            mealNumber: nextMealNumber,
                            name: "Protein Shake",
                            calories: 180,
                            proteinG: 30,
                            carbsG: 8,
                            fatG: 3
                        )
                    }
                }
            }

            HStack(spacing: 20) {
                nutritionMetric(title: "Protein left", value: "\(Int(remainingProteinG))g", color: Color.accent.cyan)
                nutritionMetric(title: "Meals logged", value: "\(nutritionLog.meals.filter { $0.status == .completed }.count)", color: Color.appOrange2)
                nutritionMetric(title: "Water", value: "\(Int((nutritionLog.waterML ?? 0) / 250)) cups", color: Color.appBlue2)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.5), in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.45), lineWidth: 1)
        )
    }

    private var adherenceRow: some View {
        let all   = morning + evening
        let taken = individualStatus.filter { $0.value }.count
        let total = all.count
        let frac  = total > 0 ? Double(taken) / Double(total) : 0.0

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("DAILY PROGRESS")
                    .font(.caption2.monospaced()).foregroundStyle(.secondary).tracking(1)
                Spacer()
                Text("\(taken)/\(total) taken")
                    .font(.caption2.monospaced()).foregroundStyle(.secondary)
                Button { showSupplementInfo.toggle() } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("About supplement adherence")
                .popover(isPresented: $showSupplementInfo) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Supplement Adherence")
                            .font(.headline)
                        Text("Tracks whether you took all pills in your morning and evening stacks today. The 🔥 streak counts consecutive days with 100% adherence across both stacks.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .frame(minWidth: 260)
                    .presentationCompactAdaptation(.popover)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.15)).frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(LinearGradient(colors: [Color.status.success, Color.status.success], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * frac, height: 6)
                        .animation(.spring(response: 0.6), value: frac)
                }
            }
            .frame(height: 6)
        }
        .padding(14)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
    }

    private var macroBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Macro Targets")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .tracking(1)
                Spacer()
                Text("\(Int(consumedCalories)) / \(Int(targetCalories)) kcal")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            MacroTargetBar(
                protein: nutritionLog.resolvedProteinG ?? 0,
                carbs: nutritionLog.resolvedCarbsG ?? 0,
                fat: nutritionLog.resolvedFatG ?? 0,
                targetCalories: Int(targetCalories),
                targetProteinG: targetProteinG
            )
        }
    }

    private var mealSection: some View {
        let nutritionBinding = Binding<NutritionLog>(
            get: { nutritionLog },
            set: { log?.nutritionLog = $0 }
        )
        return MealSectionView(nutritionLog: nutritionBinding, suggestedMealNumber: nextMealNumber, mealSlotNames: dataStore.userProfile.mealSlotNames) { mealNumber in
            let existing = log?.nutritionLog.meals.first(where: { $0.mealNumber == mealNumber })
            editingMealEntry = existing ?? MealEntry(mealNumber: max(mealNumber, nextMealNumber))
        }
    }

    private var quickLogSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !dataStore.mealTemplates.isEmpty {
                quickMealLane(
                    title: "Favorites",
                    subtitle: "Saved templates for repeat meals",
                    meals: dataStore.mealTemplates.prefix(6).map {
                        MealEntry(
                            mealNumber: nextMealNumber,
                            name: $0.name,
                            calories: $0.calories,
                            proteinG: $0.proteinG,
                            carbsG: $0.carbsG,
                            fatG: $0.fatG
                        )
                    }
                )
            }

            if !recentMeals.isEmpty {
                quickMealLane(
                    title: "Remembered Meals",
                    subtitle: "Recently logged meals you can reuse",
                    meals: recentMeals
                )
            }
        }
    }

    private var hydrationCard: some View {
        let waterML = nutritionLog.waterML ?? 0
        let waterTarget = isTrainingDay ? 3500.0 : 2800.0
        let waterProgress = min(max(waterML / waterTarget, 0), 1)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hydration")
                        .font(.headline)
                    Text(isTrainingDay ? "Training days need a little more water." : "Keep the baseline high even on rest days.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(Int(waterML)) ml")
                    .font(.system(.title3, design: .monospaced, weight: .bold))
                    .foregroundStyle(Color.appBlue2)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(colors: [Color.appBlue1, Color.appBlue2], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * waterProgress, height: 8)
                }
            }
            .frame(height: 8)

            HStack(spacing: 10) {
                ForEach([250.0, 500.0, 1000.0], id: \.self) { amount in
                    Button {
                        log?.nutritionLog.waterML = waterML + amount
                        saveLog()
                    } label: {
                        Text("+\(Int(amount)) ml")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.appBlue2)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.appBlue1.opacity(0.2), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Button {
                    let current = log?.nutritionLog.alluloseTaken ?? false
                    log?.nutritionLog.alluloseTaken = !current
                    saveLog()
                } label: {
                    Label(log?.nutritionLog.alluloseTaken == true ? "Allulose done" : "Allulose", systemImage: log?.nutritionLog.alluloseTaken == true ? "checkmark.circle.fill" : "circle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(log?.nutritionLog.alluloseTaken == true ? Color.status.success : .secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.55), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
    }

    // ─────────────────────────────────────────────────────
    // Compact supplement row (collapsed) / full cards (expanded)
    // ─────────────────────────────────────────────────────

    private var supplementRow: some View {
        Group {
            if supplementsExpanded {
                // ── Expanded: show full stack cards with a collapse button ──
                VStack(spacing: 12) {
                    HStack {
                        Spacer()
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                supplementsExpanded = false
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text("Hide")
                                    .font(.caption.weight(.semibold))
                                Image(systemName: "chevron.up")
                                    .font(.caption.weight(.semibold))
                            }
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.secondary.opacity(0.1), in: Capsule())
                        }
                    }

                    SupplementStackCard(
                        stackTitle: "🌅  Morning Stack",
                        stackSubtitle: "Take with breakfast",
                        supplements: morning,
                        stackStatus: morningStatus,
                        individualStatus: individualStatus,
                        accentColor: Color(red: 1.0, green: 0.75, blue: 0.0)
                    ) { newStatus in
                        log?.supplementLog.morningStatus = newStatus
                        if newStatus == .completed {
                            log?.supplementLog.morningTime = Date()
                            for s in morning { log?.supplementLog.individualOverrides[s.id] = true }
                        }
                        saveLog()
                    } onToggle: { suppID, taken in
                        log?.supplementLog.individualOverrides[suppID] = taken
                        recomputeStackStatus(isEvening: false)
                        saveLog()
                    }

                    SupplementStackCard(
                        stackTitle: "🌙  Evening Stack",
                        stackSubtitle: "30 min before bed",
                        supplements: evening,
                        stackStatus: eveningStatus,
                        individualStatus: individualStatus,
                        accentColor: Color.accent.purple
                    ) { newStatus in
                        log?.supplementLog.eveningStatus = newStatus
                        if newStatus == .completed {
                            log?.supplementLog.eveningTime = Date()
                            for s in evening { log?.supplementLog.individualOverrides[s.id] = true }
                        }
                        saveLog()
                    } onToggle: { suppID, taken in
                        log?.supplementLog.individualOverrides[suppID] = taken
                        recomputeStackStatus(isEvening: true)
                        saveLog()
                    }
                }
            } else {
                // ── Collapsed: single compact row ──
                HStack(spacing: 12) {

                    // Pills icon
                    Image(systemName: "pills.fill")
                        .font(.title3)
                        .foregroundStyle(Color(red: 1.0, green: 0.75, blue: 0.0))

                    // Morning + Evening pill status buttons
                    HStack(spacing: 8) {
                        // Morning pill
                        Button {
                            HapticFeedback.impact()
                            let newStatus: TaskStatus = morningStatus == .completed ? .pending : .completed
                            log?.supplementLog.morningStatus = newStatus
                            if newStatus == .completed {
                                log?.supplementLog.morningTime = Date()
                                for s in morning { log?.supplementLog.individualOverrides[s.id] = true }
                            } else {
                                for s in morning { log?.supplementLog.individualOverrides[s.id] = false }
                            }
                            recomputeStackStatus(isEvening: false)
                            saveLog()
                        } label: {
                            HStack(spacing: 4) {
                                Text("Morning")
                                    .font(.caption.weight(.semibold))
                                if morningStatus == .completed {
                                    Image(systemName: "checkmark")
                                        .font(.caption2.weight(.bold))
                                }
                            }
                            .foregroundStyle(morningStatus == .completed ? Color.status.success : .secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                morningStatus == .completed
                                    ? Color.status.success.opacity(0.15)
                                    : Color.secondary.opacity(0.08)
                            )
                            .overlay(
                                Capsule()
                                    .stroke(
                                        morningStatus == .completed
                                            ? Color.status.success
                                            : Color.secondary.opacity(0.3),
                                        lineWidth: 1
                                    )
                            )
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        // Evening pill
                        Button {
                            HapticFeedback.impact()
                            let newStatus: TaskStatus = eveningStatus == .completed ? .pending : .completed
                            log?.supplementLog.eveningStatus = newStatus
                            if newStatus == .completed {
                                log?.supplementLog.eveningTime = Date()
                                for s in evening { log?.supplementLog.individualOverrides[s.id] = true }
                            } else {
                                for s in evening { log?.supplementLog.individualOverrides[s.id] = false }
                            }
                            recomputeStackStatus(isEvening: true)
                            saveLog()
                        } label: {
                            HStack(spacing: 4) {
                                Text("Evening")
                                    .font(.caption.weight(.semibold))
                                if eveningStatus == .completed {
                                    Image(systemName: "checkmark")
                                        .font(.caption2.weight(.bold))
                                }
                            }
                            .foregroundStyle(eveningStatus == .completed ? Color.status.success : .secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                eveningStatus == .completed
                                    ? Color.status.success.opacity(0.15)
                                    : Color.secondary.opacity(0.08)
                            )
                            .overlay(
                                Capsule()
                                    .stroke(
                                        eveningStatus == .completed
                                            ? Color.status.success
                                            : Color.secondary.opacity(0.3),
                                        lineWidth: 1
                                    )
                            )
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    // Streak badge
                    Text("🔥 \(dataStore.supplementStreak)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.12), in: Capsule())

                    // Expand chevron
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            supplementsExpanded = true
                        }
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: supplementsExpanded)
    }

    private var disclaimerNote: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle").foregroundStyle(.secondary).font(.caption)
            Text("Supplement timing matters. Take morning stack with food. Evening stack 30 min before bed — especially glycine + magnesium for deep sleep. Always separate creatine from NAC by 2+ hours.")
                .font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
    }

    private static let todayDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .none
        return f
    }()

    private var formattedActiveDate: String {
        if Calendar.current.isDateInToday(activeDate) {
            return "Today"
        }
        return Self.todayDateFormatter.string(from: activeDate)
    }

    // ─────────────────────────────────────────────────────
    // Helpers
    // ─────────────────────────────────────────────────────

    private var isViewingToday: Bool {
        Calendar.current.isDateInToday(activeDate)
    }

    private func saveLog() {
        guard var current = log else { return }
        current.date = activeDate
        current.dayType = log?.dayType ?? suggestedDay(for: activeDate)
        current.recoveryDay = dataStore.userProfile.recoveryDay(for: activeDate)
        log = current
        dataStore.upsertLog(current)
    }

    private func loadLog(for date: Date) {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        activeDate = normalizedDate
        log = dataStore.log(for: normalizedDate) ?? DailyLog(
            date: normalizedDate,
            phase: dataStore.userProfile.currentPhase,
            dayType: suggestedDay(for: normalizedDate),
            recoveryDay: dataStore.userProfile.recoveryDay(for: normalizedDate)
        )
    }

    private func shiftDay(by days: Int) {
        guard let nextDate = Calendar.current.date(byAdding: .day, value: days, to: activeDate) else { return }
        saveLog()
        loadLog(for: nextDate)
    }

    private func suggestedDay(for date: Date) -> DayType {
        TrainingProgramStore.dayType(forWeekday: Calendar.current.component(.weekday, from: date))
    }

    private func recomputeStackStatus(isEvening: Bool) {
        let group = isEvening ? evening : morning
        let taken = group.filter { log?.supplementLog.individualOverrides[$0.id] == true }.count
        let status: TaskStatus = taken == 0 ? .pending
                               : taken == group.count ? .completed
                               : .partial
        if isEvening { log?.supplementLog.eveningStatus = status }
        else          { log?.supplementLog.morningStatus = status }
    }

    private func openPrefilledMeal(_ meal: MealEntry) {
        editingMealEntry = MealEntry(
            mealNumber: nextMealNumber,
            name: meal.name,
            calories: meal.calories,
            proteinG: meal.proteinG,
            carbsG: meal.carbsG,
            fatG: meal.fatG
        )
    }

    private func quickActionButton(title: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(tint)
        }
        .buttonStyle(.plain)
    }

    private func nutritionMetric(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
        }
    }

    private func quickMealLane(title: String, subtitle: String, meals: [MealEntry]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(meals) { meal in
                        Button {
                            openPrefilledMeal(meal)
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(meal.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(2)
                                HStack(spacing: 8) {
                                    if let calories = meal.calories {
                                        Text("\(Int(calories)) kcal")
                                            .font(.caption)
                                            .foregroundStyle(Color.appOrange2)
                                    }
                                    if let protein = meal.proteinG {
                                        Text("\(Int(protein))g protein")
                                            .font(.caption)
                                            .foregroundStyle(Color.accent.cyan)
                                    }
                                }
                                Text("Tap to prefill")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 180, alignment: .leading)
                            .padding(14)
                            .background(Color.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – Supplement Stack Card
// ─────────────────────────────────────────────────────────

struct SupplementStackCard: View {

    let stackTitle:      String
    let stackSubtitle:   String
    let supplements:     [SupplementDefinition]
    let stackStatus:     TaskStatus
    let individualStatus: [String: Bool]
    let accentColor:     Color
    let onStackStatus:   (TaskStatus) -> Void
    let onToggle:        (String, Bool) -> Void

    @State private var expanded = true

    var body: some View {
        VStack(spacing: 0) {

            // ── Stack header ─────────────────────────────
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(stackTitle)
                        .font(.headline)
                    Text(stackSubtitle)
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                // Mark all button
                StatusDropdown(status: stackStatus, onSelect: onStackStatus)
                // Expand/collapse
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
                } label: {
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .background(accentColor.opacity(0.07))

            // ── Status indicator bar ─────────────────────
            GeometryReader { geo in
                let taken = supplements.filter { individualStatus[$0.id] == true }.count
                let frac  = supplements.count > 0 ? Double(taken) / Double(supplements.count) : 0
                RoundedRectangle(cornerRadius: 0)
                    .fill(accentColor.opacity(0.15)).frame(height: 3)
                RoundedRectangle(cornerRadius: 0)
                    .fill(accentColor)
                    .frame(width: geo.size.width * frac, height: 3)
                    .animation(.spring(response: 0.5), value: frac)
            }
            .frame(height: 3)

            // ── Supplement rows ──────────────────────────
            if expanded {
                ForEach(supplements) { supp in
                    SupplementItemRow(
                        supplement: supp,
                        isTaken: individualStatus[supp.id] ?? false,
                        accentColor: accentColor
                    ) { taken in
                        onToggle(supp.id, taken)
                    }
                    if supp.id != supplements.last?.id { Divider().padding(.leading, 54) }
                }
            }
        }
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(stackStatus == .completed ? accentColor.opacity(0.4) : Color.clear, lineWidth: 1)
        )
        .clipped()
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – Single supplement row
// ─────────────────────────────────────────────────────────

struct SupplementItemRow: View {

    let supplement:  SupplementDefinition
    let isTaken:     Bool
    let accentColor: Color
    let onToggle:    (Bool) -> Void

    @State private var expanded = false

    var body: some View {
        VStack(spacing: 0) {
            Button {
                HapticFeedback.impact()
                onToggle(!isTaken)
            } label: {
                HStack(spacing: 12) {
                    // Checkbox
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isTaken ? accentColor : Color.secondary.opacity(0.35), lineWidth: 1.5)
                            .frame(width: 26, height: 26)
                        if isTaken {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(accentColor)
                        }
                    }

                    // Supplement info
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(supplement.name)
                                .font(.subheadline.weight(.semibold))
                                .strikethrough(isTaken, color: accentColor)
                                .foregroundStyle(isTaken ? .secondary : .primary)
                            Text(supplement.dose)
                                .font(.caption.monospaced())
                                .foregroundStyle(accentColor)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(accentColor.opacity(0.1), in: Capsule())
                        }
                        Text(supplement.timing.rawValue)
                            .font(.caption2).foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Info expand toggle
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expandable benefit / notes
            if expanded {
                VStack(alignment: .leading, spacing: 6) {
                    Text(supplement.benefit)
                        .font(.caption).foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        Image(systemName: "clock").font(.caption2).foregroundStyle(.tertiary)
                        Text(supplement.notes).font(.caption2).foregroundStyle(.tertiary)
                    }
                }
                .padding(.horizontal, 54).padding(.bottom, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(accentColor.opacity(0.03))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – Haptic helper (iOS only)
// ─────────────────────────────────────────────────────────

enum HapticFeedback {
    static func impact() {
        #if os(iOS)
        let g = UIImpactFeedbackGenerator(style: .medium)
        g.prepare()
        g.impactOccurred()
        #endif
    }
}
