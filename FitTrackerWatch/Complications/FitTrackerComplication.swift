// FitTrackerWatch/Complications/FitTrackerComplication.swift
// WidgetKit complications for Apple Watch face
// AccessoryCircular: today's session completion ring
// AccessoryRectangular: day type + exercise count

import WidgetKit
import SwiftUI

// ─────────────────────────────────────────────────────────
// MARK: – Timeline Entry
// ─────────────────────────────────────────────────────────

struct FitTrackerEntry: TimelineEntry {
    let date:          Date
    let dayType:       String
    let exerciseCount: Int
    let completionPct: Double   // 0.0 – 1.0
}

// ─────────────────────────────────────────────────────────
// MARK: – Timeline Provider
// ─────────────────────────────────────────────────────────

struct FitTrackerProvider: TimelineProvider {

    typealias Entry = FitTrackerEntry

    func placeholder(in context: Context) -> FitTrackerEntry {
        FitTrackerEntry(date: Date(), dayType: "Upper Push",
                        exerciseCount: 10, completionPct: 0.4)
    }

    func getSnapshot(in context: Context,
                     completion: @escaping (FitTrackerEntry) -> Void) {
        completion(FitTrackerEntry(date: Date(), dayType: todayDayType,
                                   exerciseCount: 10, completionPct: 0))
    }

    func getTimeline(in context: Context,
                     completion: @escaping (Timeline<FitTrackerEntry>) -> Void) {
        let entry = FitTrackerEntry(date: Date(), dayType: todayDayType,
                                    exerciseCount: 10, completionPct: 0)
        // Refresh every hour
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private var todayDayType: String {
        let wd = Calendar.current.component(.weekday, from: Date())
        switch wd {
        case 2: return "Upper Push"
        case 3: return "Lower Body"
        case 5: return "Upper Pull"
        case 6: return "Full Body"
        case 7: return "Cardio"
        default: return "Rest Day"
        }
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – Complication Views
// ─────────────────────────────────────────────────────────

struct FitTrackerComplicationEntryView: View {

    var entry: FitTrackerEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            circularView
        case .accessoryRectangular:
            rectangularView
        case .accessoryInline:
            Text(entry.dayType).font(.system(.caption2, weight: .semibold))
        default:
            circularView
        }
    }

    // Completion ring
    private var circularView: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.3), lineWidth: 4)
            Circle()
                .trim(from: 0, to: entry.completionPct)
                .stroke(Color.green, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 1) {
                Text("\(Int(entry.completionPct * 100))%")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
            }
        }
    }

    // Day type + exercise count
    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.green)
                Text("FitTracker")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.green)
            }
            Text(entry.dayType)
                .font(.system(size: 13, weight: .bold))
                .lineLimit(1)
            HStack(spacing: 4) {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                Text("\(entry.exerciseCount) exercises")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(entry.completionPct * 100))%")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.green)
            }
        }
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – Widget Configuration
// ─────────────────────────────────────────────────────────

@main
struct FitTrackerComplicationWidget: Widget {

    let kind = "FitTrackerComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FitTrackerProvider()) { entry in
            FitTrackerComplicationEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("FitTracker")
        .description("Today's workout progress and day type")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
