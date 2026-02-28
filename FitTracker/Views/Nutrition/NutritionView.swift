// Views/Nutrition/NutritionView.swift
// Tab 3: Nutrition
//   At this stage: supplement tracking only
//   Morning stack + Evening stack, per-supplement check-off

import SwiftUI

struct NutritionView: View {

    @EnvironmentObject var dataStore: EncryptedDataStore
    @State private var log: DailyLog?

    private var morning: [SupplementDefinition] { TrainingProgramData.morningSupplements }
    private var evening: [SupplementDefinition] { TrainingProgramData.eveningSupplements }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                dateHeader
                adherenceRow
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
                        // Auto-mark all morning supplements as taken
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
                    accentColor: .purple
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

                disclaimerNote
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 40)
        }
        .navigationTitle("Nutrition")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadLog() }
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
                Text("Supplements")
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
                .foregroundStyle(.green)
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
                        .fill(LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * frac, height: 6)
                        .animation(.spring(response: 0.6), value: frac)
                }
            }
            .frame(height: 6)
        }
        .padding(14)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
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

    private var formattedToday: String {
        let f = DateFormatter(); f.dateStyle = .long; f.timeStyle = .none
        return f.string(from: Date())
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
