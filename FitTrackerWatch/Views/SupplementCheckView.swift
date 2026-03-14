// FitTrackerWatch/Views/SupplementCheckView.swift
// Watch: morning/evening supplement stack quick toggles
// Syncs state to phone via WCSession

import SwiftUI

struct SupplementCheckView: View {

    @EnvironmentObject var session: WatchSessionManager

    private var morningSupplements: [WatchSupplement] {
        session.supplements.filter { $0.timing == "morning" }
    }

    private var eveningSupplements: [WatchSupplement] {
        session.supplements.filter { $0.timing == "evening" }
    }

    private var morningDone: Int { morningSupplements.filter(\.isChecked).count }
    private var eveningDone: Int { eveningSupplements.filter(\.isChecked).count }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Progress summary
                HStack(spacing: 12) {
                    progressBadge(
                        label: "Morning",
                        done: morningDone,
                        total: morningSupplements.count,
                        color: .orange
                    )
                    progressBadge(
                        label: "Evening",
                        done: eveningDone,
                        total: eveningSupplements.count,
                        color: .indigo
                    )
                }

                if !morningSupplements.isEmpty {
                    supplementSection("MORNING", supplements: morningSupplements)
                }
                if !eveningSupplements.isEmpty {
                    supplementSection("EVENING", supplements: eveningSupplements)
                }

                if session.supplements.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "pills.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("Open FitTracker on\nyour iPhone to sync")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                }
            }
            .padding(8)
        }
        .navigationTitle("Supplements")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func progressBadge(label: String, done: Int, total: Int, color: Color) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 4)
                    .frame(width: 40, height: 40)
                Circle()
                    .trim(from: 0, to: total > 0 ? Double(done) / Double(total) : 0)
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(-90))
                Text("\(done)/\(total)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
            }
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(Color(.systemFill), in: RoundedRectangle(cornerRadius: 10))
    }

    private func supplementSection(_ title: String, supplements: [WatchSupplement]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary)
                .tracking(1)
                .padding(.leading, 2)

            ForEach(supplements) { supp in
                Button {
                    WKInterfaceDevice.current().play(supp.isChecked ? .click : .success)
                    session.toggleSupplement(supp.id)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: supp.isChecked
                              ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(supp.isChecked ? .green : .secondary)
                            .font(.system(size: 16))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(supp.name)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)
                                .strikethrough(supp.isChecked)
                            Text(supp.dose)
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 8).padding(.vertical, 6)
                    .background(
                        supp.isChecked
                            ? Color.green.opacity(0.1)
                            : Color(.systemFill),
                        in: RoundedRectangle(cornerRadius: 8)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
