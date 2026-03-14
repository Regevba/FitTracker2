// FitTrackerWatch/Views/ActiveWorkoutView.swift
// Watch: today's exercise list with set logging via Digital Crown

import SwiftUI

struct ActiveWorkoutView: View {

    @EnvironmentObject var session: WatchSessionManager
    @State private var selectedExercise: WatchExercise? = nil
    @State private var showSetLog = false

    private var elapsedFormatted: String {
        let total = Int(session.sessionElapsed)
        let h = total / 3600; let m = (total % 3600) / 60; let s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Session timer
                if session.isSessionActive {
                    HStack(spacing: 6) {
                        Circle().fill(Color.green).frame(width: 6, height: 6)
                        Text(elapsedFormatted)
                            .font(.system(.caption2, design: .monospaced, weight: .bold))
                            .foregroundStyle(.green)
                        Spacer()
                        Button("End") { session.endSession() }
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.red)
                            .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 6).padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                } else {
                    Button {
                        session.startSession()
                    } label: {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Start Session")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.blue, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 6).padding(.vertical, 4)
                }

                if session.exercises.isEmpty {
                    VStack(spacing: 10) {
                        Spacer()
                        Image(systemName: "iphone.and.arrow.forward")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("Open FitTracker\non your iPhone")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(session.exercises) { ex in
                            Button {
                                selectedExercise = ex
                                showSetLog = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: ex.isCompleted
                                          ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(ex.isCompleted ? .green : .secondary)
                                        .font(.caption)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(ex.name)
                                            .font(.system(size: 13, weight: .medium))
                                            .lineLimit(1)
                                            .strikethrough(ex.isCompleted)
                                        Text("\(ex.sets)×\(ex.reps)")
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(
                                ex.isCompleted
                                    ? Color.green.opacity(0.08)
                                    : Color.clear
                            )
                        }
                    }
                    .listStyle(.carousel)
                }
            }
            .navigationTitle("Workout")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showSetLog) {
                if let ex = selectedExercise {
                    SetLogView(exercise: ex)
                        .environmentObject(session)
                }
            }
        }
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – Set Log View
// ─────────────────────────────────────────────────────────

struct SetLogView: View {

    let exercise: WatchExercise
    @EnvironmentObject var session: WatchSessionManager
    @Environment(\.dismiss) var dismiss

    @State private var setNumber: Int = 1
    @State private var weightKg: Double = 20
    @State private var reps: Int = 10

    private var completedSetsForExercise: Int {
        session.completedSets.filter { $0.exerciseID == exercise.id }.count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text(exercise.name)
                    .font(.system(size: 13, weight: .bold))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                Text("Set \(completedSetsForExercise + 1) of \(exercise.sets)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                // Weight (Digital Crown compatible)
                VStack(spacing: 4) {
                    Text("Weight")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    HStack {
                        Button { weightKg = max(0, weightKg - 2.5) } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title3).foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                        Text(String(format: "%.1f kg", weightKg))
                            .font(.system(.headline, design: .monospaced))
                            .frame(minWidth: 70)
                        Button { weightKg += 2.5 } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3).foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                    .focusable()
                    .digitalCrownRotation($weightKg, from: 0, through: 300, by: 2.5,
                                          sensitivity: .medium, isContinuous: false,
                                          isHapticFeedbackEnabled: true)
                }
                .padding(8)
                .background(Color(.systemFill), in: RoundedRectangle(cornerRadius: 8))

                // Reps
                VStack(spacing: 4) {
                    Text("Reps")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    HStack {
                        Button { reps = max(1, reps - 1) } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title3).foregroundStyle(.orange)
                        }
                        .buttonStyle(.plain)
                        Text("\(reps)")
                            .font(.system(.headline, design: .monospaced))
                            .frame(minWidth: 40)
                        Button { reps += 1 } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3).foregroundStyle(.orange)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .background(Color(.systemFill), in: RoundedRectangle(cornerRadius: 8))

                Button {
                    let next = completedSetsForExercise + 1
                    session.logSet(exerciseID: exercise.id, setNumber: next,
                                   weightKg: weightKg, reps: reps)
                    WKInterfaceDevice.current().play(.success)
                    if next >= exercise.sets { dismiss() }
                    else { setNumber = next + 1 }
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Log Set")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.green, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                Button("Cancel") { dismiss() }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .buttonStyle(.plain)
            }
            .padding(8)
        }
        .onAppear {
            setNumber = completedSetsForExercise + 1
        }
    }
}
