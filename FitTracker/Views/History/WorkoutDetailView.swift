// Views/History/WorkoutDetailView.swift
// Drill-down detail for a single past workout session

import SwiftUI

struct WorkoutDetailView: View {

    let log: DailyLog
    @EnvironmentObject var settings: AppSettings

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .full
        f.timeStyle = .none
        return f
    }()

    private var totalVolume: Double {
        log.exerciseLogs.values.map { $0.totalVolume }.reduce(0, +)
    }

    private var sortedExerciseLogs: [ExerciseLog] {
        log.exerciseLogs.values.sorted { $0.exerciseName < $1.exerciseName }
    }

    var body: some View {
        ZStack {
            Color.appOrange1.opacity(0.3).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Header summary card
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(log.dayType.rawValue)
                                    .font(.title2.bold())
                                Text(Self.dateFormatter.string(from: log.date))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.15))
                                    .frame(width: 52, height: 52)
                                Image(systemName: log.dayType.icon)
                                    .font(.title2)
                                    .foregroundStyle(.blue)
                            }
                        }

                        Divider()

                        HStack(spacing: 0) {
                            detailStat(value: "\(log.exerciseLogs.count)", label: "Exercises")
                            Divider().frame(height: 36)
                            let sets = log.exerciseLogs.values.map { $0.sets.count }.reduce(0, +)
                            detailStat(value: "\(sets)", label: "Sets")
                            Divider().frame(height: 36)
                            detailStat(value: settings.unitSystem.displayWeight(totalVolume), label: "Volume")
                            Divider().frame(height: 36)
                            detailStat(value: "\(Int(log.completionPct))%", label: "Completion")
                        }
                    }
                    .padding(16)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))

                    // Biometrics on training day
                    if log.biometrics.weightKg != nil || log.biometrics.effectiveHRV != nil {
                        sectionCard(title: "BIOMETRICS") {
                            VStack(spacing: 8) {
                                if let w = log.biometrics.weightKg {
                                    biometricRow("Weight", value: settings.unitSystem.displayWeight(w))
                                }
                                if let bf = log.biometrics.bodyFatPercent {
                                    biometricRow("Body Fat", value: String(format: "%.1f%%", bf))
                                }
                                if let hrv = log.biometrics.effectiveHRV {
                                    biometricRow("HRV", value: String(format: "%.0f ms", hrv))
                                }
                                if let rhr = log.biometrics.effectiveRestingHR {
                                    biometricRow("Resting HR", value: String(format: "%.0f bpm", rhr))
                                }
                                if let sleep = log.biometrics.effectiveSleep {
                                    biometricRow("Sleep", value: String(format: "%.1f h", sleep))
                                }
                            }
                        }
                    }

                    // Exercise logs
                    if !sortedExerciseLogs.isEmpty {
                        sectionCard(title: "EXERCISES") {
                            VStack(spacing: 16) {
                                ForEach(sortedExerciseLogs) { exLog in
                                    exerciseCard(exLog)
                                }
                            }
                        }
                    }

                    // Cardio logs
                    if !log.cardioLogs.isEmpty {
                        sectionCard(title: "CARDIO") {
                            VStack(spacing: 12) {
                                ForEach(Array(log.cardioLogs.values)) { cardio in
                                    cardioCard(cardio)
                                }
                            }
                        }
                    }

                    // Supplement log
                    let suppl = log.supplementLog
                    if suppl.morningStatus != .pending || suppl.eveningStatus != .pending {
                        sectionCard(title: "SUPPLEMENTS") {
                            VStack(spacing: 6) {
                                supplementRow("Morning Stack", status: suppl.morningStatus)
                                supplementRow("Evening Stack", status: suppl.eveningStatus)
                            }
                        }
                    }

                    // Notes
                    if !log.notes.isEmpty {
                        sectionCard(title: "NOTES") {
                            Text(log.notes)
                                .font(.body)
                                .foregroundStyle(.primary)
                        }
                    }

                    // Mood/energy
                    if log.mood != nil || log.energyLevel != nil {
                        sectionCard(title: "WELLNESS") {
                            HStack(spacing: 20) {
                                if let mood = log.mood {
                                    wellnessBadge(label: "Mood", value: "\(mood)/5")
                                }
                                if let energy = log.energyLevel {
                                    wellnessBadge(label: "Energy", value: "\(energy)/10")
                                }
                                if let craving = log.cravingLevel {
                                    wellnessBadge(label: "Cravings", value: "\(craving)/10")
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle(log.dayType.rawValue)
        .navigationBarTitleDisplayMode(.inline)
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Sub-views
    // ─────────────────────────────────────────────────────

    private func sectionCard<Content: View>(title: String,
                                             @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(.secondary)
                .tracking(1.5)
            content()
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func detailStat(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(.subheadline, design: .monospaced, weight: .bold))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func biometricRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.subheadline.weight(.semibold))
        }
    }

    private func exerciseCard(_ exLog: ExerciseLog) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(exLog.exerciseName)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(settings.unitSystem.displayWeight(exLog.totalVolume))
                    .font(.caption.monospaced())
                    .foregroundStyle(.orange)
            }

            if !exLog.sets.isEmpty {
                VStack(spacing: 4) {
                    HStack {
                        Text("Set").font(.caption2).foregroundStyle(.secondary).frame(width: 28)
                        Text("Weight").font(.caption2).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                        Text("Reps").font(.caption2).foregroundStyle(.secondary).frame(width: 36)
                        Text("RPE").font(.caption2).foregroundStyle(.secondary).frame(width: 36)
                    }
                    ForEach(exLog.sets) { set in
                        HStack {
                            Text("\(set.setNumber)")
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .frame(width: 28)
                            Text(set.weightKg.map { settings.unitSystem.displayWeight($0) } ?? "BW")
                                .font(.caption.monospaced())
                                .frame(maxWidth: .infinity)
                            Text(set.repsCompleted.map { "\($0)" } ?? "—")
                                .font(.caption.monospaced())
                                .frame(width: 36)
                            Text(set.rpe.map { String(format: "%.0f", $0) } ?? "—")
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .frame(width: 36)
                        }
                    }
                }
            }

            if !exLog.notes.isEmpty {
                Text(exLog.notes)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .italic()
            }
        }
        .padding(12)
        .background(Color(.systemFill), in: RoundedRectangle(cornerRadius: 10))
    }

    private func cardioCard(_ cardio: CardioLog) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(cardio.cardioType.rawValue)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if let zone2 = cardio.wasInZone2 {
                    Label(zone2 ? "Zone 2" : "Above Zone 2",
                          systemImage: zone2 ? "checkmark.circle.fill" : "exclamationmark.circle")
                        .font(.caption2)
                        .foregroundStyle(zone2 ? .green : .orange)
                }
            }
            HStack(spacing: 16) {
                if let dur = cardio.durationMinutes {
                    cardioStat(value: String(format: "%.0f min", dur), label: "Duration")
                }
                if let avg = cardio.avgHeartRate {
                    cardioStat(value: String(format: "%.0f bpm", avg), label: "Avg HR")
                }
                if let cal = cardio.caloriesBurned {
                    cardioStat(value: String(format: "%.0f kcal", cal), label: "Calories")
                }
            }
        }
        .padding(12)
        .background(Color(.systemFill), in: RoundedRectangle(cornerRadius: 10))
    }

    private func cardioStat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.caption.weight(.semibold).monospaced())
            Text(label).font(.system(size: 9)).foregroundStyle(.secondary)
        }
    }

    private func supplementRow(_ label: String, status: TaskStatus) -> some View {
        HStack {
            Text(label).font(.subheadline)
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: status == .completed ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(status == .completed ? .green : .secondary)
                Text(status.rawValue.capitalized)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(status == .completed ? .green : .secondary)
            }
        }
    }

    private func wellnessBadge(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .bold))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(Color(.systemFill), in: RoundedRectangle(cornerRadius: 10))
    }
}
