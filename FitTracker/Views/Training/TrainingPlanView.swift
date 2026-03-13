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
    @State private var log: DailyLog?
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
                    dayPicker
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
    }

    // ─────────────────────────────────────────────────────
    // Day picker
    // ─────────────────────────────────────────────────────

    private var dayPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DayType.allCases, id: \.self) { day in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { selectedDay = day }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: day.icon).font(.caption2)
                            Text(day.rawValue).font(.caption.weight(.semibold))
                        }
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(selectedDay == day ? Color.blue : Color.white.opacity(0.35), in: Capsule())
                        .foregroundStyle(selectedDay == day ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
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
    let exercise: ExerciseDefinition
    let selectedDay: DayType
    @Binding var log: DailyLog?

    private var status: TaskStatus { log?.taskStatuses[exercise.id] ?? .pending }

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
                .strikethrough(status == .completed, color: .green)
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
        case .completed: .green; case .partial: .orange; case .missed: .red; case .pending: .secondary
        }
    }

    private var rowBG: Color {
        switch status {
        case .completed: .green.opacity(0.03); case .missed: .red.opacity(0.03); default: Color(.systemBackground).opacity(0.5)
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
    @Binding var exerciseLog: ExerciseLog

    var body: some View {
        VStack(spacing: 0) {
            // Panel header
            HStack {
                Text("📋 SET LOG")
                    .font(.caption2.monospaced()).foregroundStyle(.green).tracking(1)
                Spacer()
                if exerciseLog.totalVolume > 0 {
                    Text("Total: \(Int(exerciseLog.totalVolume)) kg")
                        .font(.caption2.monospaced()).foregroundStyle(.green.opacity(0.8))
                }
                Button {
                    exerciseLog.sets.append(SetLog(
                        setNumber: exerciseLog.sets.count + 1,
                        weightKg: exerciseLog.sets.last?.weightKg
                    ))
                } label: {
                    Label("Add Set", systemImage: "plus.circle.fill")
                        .font(.caption.weight(.semibold)).foregroundStyle(.green)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(.green.opacity(0.05))

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
    let onDelete: () -> Void

    @State private var weightStr = ""
    @State private var repsStr   = ""
    @State private var noteStr   = ""
    @State private var rpe: Double?

    var body: some View {
        HStack(spacing: 0) {
            // Set number
            Text("\(setNum)")
                .font(.system(.caption, design: .monospaced, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .leading)

            // Weight
            TextField("0", text: $weightStr)
                .font(.system(.body, design: .monospaced))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6).padding(.horizontal, 4)
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 5))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.secondary.opacity(0.2)))
                .onChange(of: weightStr) { _, v in setLog.weightKg = Double(v) }

            // Reps
            TextField("—", text: $repsStr)
                .font(.system(.body, design: .monospaced))
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .frame(width: 48)
                .padding(.vertical, 6).padding(.horizontal, 4)
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 5))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.secondary.opacity(0.2)))
                .onChange(of: repsStr) { _, v in setLog.repsCompleted = Int(v) }

            // RPE
            RPEBadge(rpe: Binding(get: { setLog.rpe }, set: { setLog.rpe = $0 }))
                .frame(width: 40)

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
                    .font(.caption2.monospaced()).foregroundStyle(.green).tracking(1)
                Spacer()
                if let zone = cardioLog.wasInZone2 {
                    Text(zone ? "✓ Zone 2" : "↑ Above Zone 2")
                        .font(.caption2.monospaced())
                        .foregroundStyle(zone ? .green : .orange)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(.green.opacity(0.05))

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
                        .background(.green.opacity(0.1), in: Capsule())
                        .foregroundStyle(.green)
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

struct RPEBadge: View {
    @Binding var rpe: Double?
    @State private var show = false

    var body: some View {
        Button { show.toggle() } label: {
            Text(rpe.map { String(format: "%.0f", $0) } ?? "—")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(rpe != nil ? .primary : .tertiary)
                .frame(width: 34).padding(.vertical, 4)
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 5))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.secondary.opacity(0.2)))
        }
        .popover(isPresented: $show) {
            VStack(spacing: 2) {
                Text("RPE").font(.caption.bold()).padding(.top, 8)
                ForEach([6.0, 7.0, 7.5, 8.0, 8.5, 9.0, 10.0], id: \.self) { v in
                    Button("\(v == floor(v) ? String(Int(v)) : String(v))  ·  \(rpeLabel(v))") { rpe = v; show = false }
                        .font(.caption).padding(.vertical, 3)
                }
            }
            .padding()
            .presentationCompactAdaptation(.popover)
        }
    }

    private func rpeLabel(_ v: Double) -> String {
        switch v {
        case 6:   "Easy"
        case 7:   "Moderate"
        case 7.5: "Somewhat Hard"
        case 8:   "Hard"
        case 8.5: "Very Hard"
        case 9:   "Near Max"
        default:  "Absolute Max"
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
        case .completed: .green; case .partial: .orange; case .missed: .red; case .pending: .secondary
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
