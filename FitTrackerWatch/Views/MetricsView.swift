// FitTrackerWatch/Views/MetricsView.swift
// Watch: live HR, HRV, calories, steps, Zone 2 indicator

import SwiftUI

struct MetricsView: View {

    @EnvironmentObject var session: WatchSessionManager

    private var hrColor: Color {
        guard let hr = session.currentHR else { return .secondary }
        switch hr {
        case ..<100: return .green
        case 100..<124: return .orange
        default: return .red
        }
    }

    private var isInZone2: Bool {
        guard let hr = session.currentHR else { return false }
        return hr >= 106 && hr <= 124
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Heart rate — large prominent display
                VStack(spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(hrColor)
                            .font(.system(size: 14))
                        Text("HEART RATE")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .tracking(1)
                    }
                    HStack(alignment: .lastTextBaseline, spacing: 3) {
                        Text(session.currentHR.map { String(format: "%.0f", $0) } ?? "—")
                            .font(.system(size: 52, weight: .bold, design: .monospaced))
                            .foregroundStyle(hrColor)
                        Text("bpm")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }

                    // Zone 2 indicator
                    if session.currentHR != nil {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(isInZone2 ? Color.green : Color.secondary.opacity(0.4))
                                .frame(width: 6, height: 6)
                            Text(isInZone2 ? "Zone 2 ✓" : "Outside Zone 2")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(isInZone2 ? .green : .secondary)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(
                            (isInZone2 ? Color.green : Color.secondary).opacity(0.1),
                            in: Capsule()
                        )
                    }
                }
                .padding()
                .background(Color(.systemFill), in: RoundedRectangle(cornerRadius: 12))

                // Grid of metrics
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    metricCard(
                        icon: "waveform.path.ecg",
                        value: session.currentHRV.map { String(format: "%.0f", $0) } ?? "—",
                        unit: "ms",
                        label: "HRV",
                        color: .purple
                    )
                    metricCard(
                        icon: "flame.fill",
                        value: session.calories.map { String(format: "%.0f", $0) } ?? "—",
                        unit: "kcal",
                        label: "Calories",
                        color: .orange
                    )
                    metricCard(
                        icon: "figure.walk",
                        value: session.steps.map { "\($0)" } ?? "—",
                        unit: "steps",
                        label: "Steps",
                        color: .blue
                    )
                    metricCard(
                        icon: "clock.fill",
                        value: formatElapsed(session.sessionElapsed),
                        unit: "",
                        label: "Session",
                        color: .green
                    )
                }

                // Zone 2 target reminder
                VStack(spacing: 4) {
                    Text("ZONE 2 TARGET")
                        .font(.system(size: 9, weight: .black))
                        .tracking(1)
                        .foregroundStyle(.secondary)
                    Text("106 – 124 bpm")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(.orange)
                }
                .padding(8)
                .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            }
            .padding(8)
        }
        .navigationTitle("Metrics")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func metricCard(icon: String, value: String, unit: String,
                             label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(Color(.systemFill), in: RoundedRectangle(cornerRadius: 10))
    }

    private func formatElapsed(_ t: TimeInterval) -> String {
        let total = Int(t)
        let m = total / 60; let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}
