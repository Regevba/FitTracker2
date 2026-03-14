// Views/Body/BodyMeasurementsView.swift
// Track body measurements: waist, chest, arms, hips with trend chart
// Accessible from Stats tab (Body segment) and Home screen quick action

import SwiftUI
import Charts
import PhotosUI

struct BodyMeasurementsView: View {

    @EnvironmentObject var dataStore: EncryptedDataStore
    @EnvironmentObject var settings:  AppSettings
    @Environment(\.dismiss) var dismiss

    @State private var showAddSheet = false
    @State private var selectedMetric: MeasurementMetric = .waist

    enum MeasurementMetric: String, CaseIterable {
        case waist = "Waist"
        case chest = "Chest"
        case leftArm = "L. Arm"
        case rightArm = "R. Arm"
        case hips  = "Hips"
        case neck  = "Neck"

        func value(from m: BodyMeasurement) -> Double? {
            switch self {
            case .waist:    m.waistCm
            case .chest:    m.chestCm
            case .leftArm:  m.leftArmCm
            case .rightArm: m.rightArmCm
            case .hips:     m.hipsCm
            case .neck:     m.neckCm
            }
        }
    }

    private var chartData: [(date: Date, value: Double)] {
        dataStore.bodyMeasurements
            .compactMap { m -> (Date, Double)? in
                guard let v = selectedMetric.value(from: m) else { return nil }
                return (m.date, v)
            }
            .sorted { $0.0 < $1.0 }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appOrange1.opacity(0.35).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {

                        // Metric picker
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(MeasurementMetric.allCases, id: \.self) { m in
                                    Button(m.rawValue) { selectedMetric = m }
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(selectedMetric == m ? .white : .secondary)
                                        .padding(.horizontal, 14).padding(.vertical, 7)
                                        .background(selectedMetric == m
                                                    ? Color.blue.opacity(0.8)
                                                    : Color(.systemFill),
                                                    in: Capsule())
                                        .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        }

                        // Trend chart
                        VStack(alignment: .leading, spacing: 12) {
                            Text("\(selectedMetric.rawValue.uppercased()) TREND")
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .foregroundStyle(.secondary)
                                .tracking(1.5)

                            if chartData.isEmpty {
                                VStack(spacing: 8) {
                                    Image(systemName: "ruler")
                                        .font(.title)
                                        .foregroundStyle(.secondary)
                                    Text("No \(selectedMetric.rawValue.lowercased()) measurements yet.\nTap + to add your first entry.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity, minHeight: 120)
                            } else {
                                Chart(chartData, id: \.date) { item in
                                    LineMark(
                                        x: .value("Date", item.date),
                                        y: .value("cm", item.value)
                                    )
                                    .foregroundStyle(.blue)
                                    .interpolationMethod(.catmullRom)
                                    AreaMark(
                                        x: .value("Date", item.date),
                                        y: .value("cm", item.value)
                                    )
                                    .foregroundStyle(.blue.opacity(0.1))
                                    .interpolationMethod(.catmullRom)
                                    PointMark(
                                        x: .value("Date", item.date),
                                        y: .value("cm", item.value)
                                    )
                                    .foregroundStyle(.blue)
                                    .symbolSize(40)
                                }
                                .chartYAxisLabel(settings.unitSystem == .metric ? "cm" : "in")
                                .frame(height: 180)
                            }
                        }
                        .padding(16)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 16)

                        // Measurement history list
                        if !dataStore.bodyMeasurements.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("MEASUREMENT LOG")
                                    .font(.system(size: 11, weight: .black, design: .rounded))
                                    .foregroundStyle(.secondary)
                                    .tracking(1.5)

                                ForEach(dataStore.bodyMeasurements) { m in
                                    MeasurementRow(measurement: m)
                                        .environmentObject(settings)
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                dataStore.deleteMeasurement(m)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                            .padding(16)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Body Measurements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { showAddSheet = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddMeasurementView()
                    .environmentObject(dataStore)
                    .environmentObject(settings)
                    .presentationDetents([.large])
                    .presentationCornerRadius(24)
            }
        }
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – Measurement Row
// ─────────────────────────────────────────────────────────

struct MeasurementRow: View {

    let measurement: BodyMeasurement
    @EnvironmentObject var settings: AppSettings

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none; return f
    }()

    private func display(_ cm: Double?) -> String? {
        guard let v = cm else { return nil }
        if settings.unitSystem == .metric { return String(format: "%.1f cm", v) }
        return String(format: "%.1f in", v / 2.54)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Self.dateFormatter.string(from: measurement.date))
                .font(.subheadline.weight(.semibold))

            FlowRow {
                if let v = display(measurement.waistCm)    { measureChip("Waist", v) }
                if let v = display(measurement.chestCm)    { measureChip("Chest", v) }
                if let v = display(measurement.leftArmCm)  { measureChip("L. Arm", v) }
                if let v = display(measurement.rightArmCm) { measureChip("R. Arm", v) }
                if let v = display(measurement.hipsCm)     { measureChip("Hips", v) }
                if let v = display(measurement.neckCm)     { measureChip("Neck", v) }
            }

            if !measurement.notes.isEmpty {
                Text(measurement.notes)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .italic()
            }
        }
        .padding(.vertical, 4)
    }

    private func measureChip(_ label: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text(label).font(.system(size: 10)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 11, weight: .semibold, design: .monospaced))
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Color(.systemFill), in: Capsule())
    }
}

// Simple horizontal wrapping layout
struct FlowRow<Content: View>: View {
    @ViewBuilder let content: () -> Content
    var body: some View {
        // Using HStack with wrapping via TupleView is complex; use a simple HStack with scroll
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) { content() }
        }
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – Add Measurement Sheet
// ─────────────────────────────────────────────────────────

struct AddMeasurementView: View {

    @EnvironmentObject var dataStore: EncryptedDataStore
    @EnvironmentObject var settings:  AppSettings
    @Environment(\.dismiss) var dismiss

    @State private var waist    = ""
    @State private var chest    = ""
    @State private var leftArm  = ""
    @State private var rightArm = ""
    @State private var hips     = ""
    @State private var neck     = ""
    @State private var thigh    = ""
    @State private var notes    = ""
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var photoData: Data? = nil

    private var unit: String { settings.unitSystem == .metric ? "cm" : "in" }

    private func fromDisplay(_ s: String) -> Double? {
        guard let v = Double(s) else { return nil }
        return settings.unitSystem == .metric ? v : v * 2.54
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("MEASUREMENTS (\(unit))") {
                    measureField("Waist",      text: $waist)
                    measureField("Chest",      text: $chest)
                    measureField("Left Arm",   text: $leftArm)
                    measureField("Right Arm",  text: $rightArm)
                    measureField("Hips",       text: $hips)
                    measureField("Neck",       text: $neck)
                    measureField("Thigh",      text: $thigh)
                }

                Section("PROGRESS PHOTO (optional)") {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        HStack {
                            if photoData != nil {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                Text("Photo selected")
                            } else {
                                Image(systemName: "camera.fill").foregroundStyle(.secondary)
                                Text("Add progress photo")
                            }
                        }
                    }
                }

                Section("NOTES") {
                    TextField("Optional notes...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Add Measurements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save(); dismiss() }
                        .disabled(!hasAnyValue)
                }
            }
            .onChange(of: selectedPhoto) { _, item in
                Task {
                    photoData = try? await item?.loadTransferable(type: Data.self)
                }
            }
        }
    }

    private var hasAnyValue: Bool {
        [waist, chest, leftArm, rightArm, hips, neck, thigh].contains { !$0.isEmpty }
    }

    private func measureField(_ label: String, text: Binding<String>) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            TextField(unit, text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
        }
    }

    private func save() {
        let m = BodyMeasurement(
            date:         Date(),
            waistCm:      fromDisplay(waist),
            chestCm:      fromDisplay(chest),
            leftArmCm:    fromDisplay(leftArm),
            rightArmCm:   fromDisplay(rightArm),
            hipsCm:       fromDisplay(hips),
            neckCm:       fromDisplay(neck),
            thighCm:      fromDisplay(thigh),
            progressPhotoData: photoData,
            notes:        notes
        )
        dataStore.upsertMeasurement(m)
    }
}
