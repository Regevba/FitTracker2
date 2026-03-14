// Views/History/WorkoutHistoryView.swift
// Tab 5: History — browse all past training sessions
// Filterable by day type and searchable by exercise name

import SwiftUI

struct WorkoutHistoryView: View {

    @EnvironmentObject var dataStore: EncryptedDataStore
    @EnvironmentObject var settings:  AppSettings

    @State private var searchText     = ""
    @State private var filterDayType: DayType? = nil

    private var filteredLogs: [DailyLog] {
        var logs = dataStore.dailyLogs
            .filter { $0.dayType.isTrainingDay || !$0.exerciseLogs.isEmpty }
            .sorted { $0.date > $1.date }

        if let dt = filterDayType {
            logs = logs.filter { $0.dayType == dt }
        }
        if !searchText.isEmpty {
            logs = logs.filter { log in
                log.exerciseLogs.values.contains { $0.exerciseName.localizedCaseInsensitiveContains(searchText) }
            }
        }
        return logs
    }

    private var trainingDayTypes: [DayType] {
        DayType.allCases.filter { $0.isTrainingDay }
    }

    var body: some View {
        ZStack {
            Color.appOrange1.opacity(0.4).ignoresSafeArea()

            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search by exercise...", text: $searchText)
                        .submitLabel(.search)
                }
                .padding(10)
                .background(Color(.systemFill), in: RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 16)
                .padding(.top, 8)

                // Day type filter pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        filterPill(label: "All", icon: "list.bullet", selected: filterDayType == nil) {
                            filterDayType = nil
                        }
                        ForEach(trainingDayTypes, id: \.self) { dt in
                            filterPill(label: dt.rawValue, icon: dt.icon,
                                       selected: filterDayType == dt) {
                                filterDayType = filterDayType == dt ? nil : dt
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }

                if filteredLogs.isEmpty {
                    Spacer()
                    VStack(spacing: 14) {
                        Image(systemName: "clock.badge.questionmark")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text(dataStore.dailyLogs.isEmpty
                             ? "No workouts logged yet.\nStart training to see your history here."
                             : "No sessions match your filter.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(40)
                    Spacer()
                } else {
                    List {
                        ForEach(filteredLogs) { log in
                            NavigationLink(destination:
                                WorkoutDetailView(log: log)
                                    .environmentObject(settings)
                            ) {
                                WorkoutHistoryRow(log: log)
                                    .environmentObject(settings)
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func filterPill(label: String, icon: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.caption2)
                Text(label).font(.caption.weight(.semibold))
            }
            .foregroundStyle(selected ? .white : .secondary)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(selected ? Color.blue.opacity(0.85) : Color(.systemFill),
                        in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – Row
// ─────────────────────────────────────────────────────────

struct WorkoutHistoryRow: View {

    let log: DailyLog
    @EnvironmentObject var settings: AppSettings

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    private var totalVolume: Double {
        log.exerciseLogs.values.map { $0.totalVolume }.reduce(0, +)
    }

    private var exercisesCompleted: Int {
        log.taskStatuses.values.filter { $0 == .completed }.count
    }

    var body: some View {
        HStack(spacing: 14) {
            // Day type icon circle
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: log.dayType.icon)
                    .font(.body)
                    .foregroundStyle(.blue)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(Self.dateFormatter.string(from: log.date))
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(log.dayType.rawValue)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color(.systemFill), in: Capsule())
                }

                HStack(spacing: 12) {
                    Label("\(exercisesCompleted) exercises",
                          systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)

                    if totalVolume > 0 {
                        Label(settings.unitSystem.displayWeight(totalVolume),
                              systemImage: "scalemass.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    if !log.cardioLogs.isEmpty {
                        Label("\(log.cardioLogs.count) cardio",
                              systemImage: "heart.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .padding(.vertical, 3)
    }
}
