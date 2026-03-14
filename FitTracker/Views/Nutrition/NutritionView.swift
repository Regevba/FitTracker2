// Views/Nutrition/NutritionView.swift
// Tab 3: Nutrition
//   At this stage: supplement tracking only
//   Morning stack + Evening stack, per-supplement check-off

import SwiftUI

struct NutritionView: View {

    @EnvironmentObject var dataStore: EncryptedDataStore
    @State private var log: DailyLog?
    @State private var supplementsExpanded = false
    @State private var editingMealEntry: MealEntry?

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
                macroBar
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
        .onAppear { loadLog() }
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

    // ─────────────────────────────────────────────────────
    // Sub-views
    // ─────────────────────────────────────────────────────

    private var dateHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Nutrition")
                    .font(.title2.bold())
                Text(formattedToday)
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            overallBadge
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
            Text("today")
                .font(.caption2).foregroundStyle(.secondary)
        }
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
        let nutrition = log?.nutritionLog ?? NutritionLog()
        let protein   = nutrition.totalProteinG ?? nutrition.meals.compactMap(\.proteinG).reduce(0, +)
        let carbs     = nutrition.totalCarbsG   ?? nutrition.meals.compactMap(\.carbsG).reduce(0, +)
        let fat       = nutrition.totalFatG     ?? nutrition.meals.compactMap(\.fatG).reduce(0, +)
        let phase     = dataStore.userProfile.currentPhase
        let isTraining = log?.dayType.isTrainingDay ?? false
        let targetCal = isTraining ? phase.trainingCalories : phase.restCalories
        let leanMass  = log?.biometrics.leanBodyMassKg
        let targetPro = leanMass.map { $0 * 2 } ?? 135.0

        return MacroTargetBar(
            protein: protein,
            carbs: carbs,
            fat: fat,
            targetCalories: targetCal,
            targetProteinG: targetPro
        )
    }

    private var mealSection: some View {
        let nutritionBinding = Binding<NutritionLog>(
            get: { log?.nutritionLog ?? NutritionLog() },
            set: { log?.nutritionLog = $0 }
        )
        return MealSectionView(nutritionLog: nutritionBinding) { mealNumber in
            let existing = log?.nutritionLog.meals.first(where: { $0.mealNumber == mealNumber })
            editingMealEntry = existing ?? MealEntry(mealNumber: max(mealNumber, 1))
        }
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

    private var formattedToday: String {
        Self.todayDateFormatter.string(from: Date())
    }

    // ─────────────────────────────────────────────────────
    // Helpers
    // ─────────────────────────────────────────────────────

    private func loadLog() {
        log = dataStore.todayLog() ?? DailyLog(
            date: Date(), phase: dataStore.userProfile.currentPhase,
            dayType: .restDay, recoveryDay: dataStore.userProfile.daysSinceStart
        )
    }

    private func saveLog() {
        if let l = log { dataStore.upsertLog(l) }
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
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}
