// FitTracker/Views/AI/HRVTrendChart.swift
//
// C4 feature: trend-alerts-hrv.
//
// 7-day mini-chart for the "Your HRV Trend" section in AIIntelligenceSheet.
// Renders daily HRV reads as a Line + Point chart, with horizontal RuleMark
// overlays at `baseline` (dotted) and `floor` (solid). Per-day annotations
// color-code the points: green ≥ baseline, amber between floor and baseline,
// red ≤ floor.
//
// Reuses Swift Charts (system framework, available iOS 16+) + AppTheme
// tokens. No new visualization primitives — sits on top of existing chart
// infrastructure shipped with stats-v2 (PR #76).

import SwiftUI
import Charts

struct HRVTrendChart: View {
    /// 7-day HRV daily reads, ordered oldest → newest.
    /// Empty / nil entries indicate missing reads (rendered as gaps).
    let dailySamples: [Double?]

    /// User's personal baseline (30-day median).
    let baseline: Double

    /// Adaptive floor: max(baseline - 1σ, hardFloor).
    let floor: Double

    /// Reference dates for x-axis labelling. Length must match dailySamples.
    let referenceDates: [Date]

    private struct Sample: Identifiable {
        let id: Int
        let date: Date
        let value: Double?
    }

    private var samples: [Sample] {
        zip(referenceDates, dailySamples).enumerated().map { idx, pair in
            Sample(id: idx, date: pair.0, value: pair.1)
        }
    }

    var body: some View {
        Chart(samples) { sample in
            if let value = sample.value {
                LineMark(
                    x: .value("Day", sample.date, unit: .day),
                    y: .value("HRV", value)
                )
                .foregroundStyle(AppColor.Chart.hrv)
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Day", sample.date, unit: .day),
                    y: .value("HRV", value)
                )
                .foregroundStyle(color(for: value))
                .symbolSize(80)
            }
        }
        .chartYScale(domain: yDomain)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.day())
            }
        }
        .chartOverlay { _ in
            // Two horizontal reference lines drawn as overlays so they're
            // visible above the data line.
            EmptyView()
        }
        .chart(baselineRule: baseline, floorRule: floor)
        .frame(height: 160)
        .padding(.vertical, AppSpacing.xSmall)
        .accessibilityLabel("7-day HRV trend chart")
        .accessibilityValue("Baseline \(Int(baseline)). Floor \(Int(floor)). \(validSampleCount) of \(dailySamples.count) readings available.")
    }

    // MARK: - Derived

    private var validSampleCount: Int {
        dailySamples.compactMap { $0 }.count
    }

    private var yDomain: ClosedRange<Double> {
        let values = dailySamples.compactMap { $0 }
        let minSample = values.min() ?? floor
        let maxSample = values.max() ?? baseline
        let yMin = min(minSample, floor) - 5
        let yMax = max(maxSample, baseline) + 5
        return yMin ... yMax
    }

    private func color(for value: Double) -> Color {
        if value >= baseline { return AppColor.Status.success }
        if value >= floor    { return AppColor.Status.warning }
        return AppColor.Status.error
    }
}

// MARK: - Reference-line overlay modifier

private struct BaselineAndFloorOverlay: ViewModifier {
    let baseline: Double
    let floor: Double

    func body(content: Content) -> some View {
        content
            .chartOverlay { proxy in
                GeometryReader { geo in
                    let plot = geo[proxy.plotAreaFrame]
                    if let baselineY = proxy.position(forY: baseline),
                       let floorY = proxy.position(forY: floor) {
                        Path { path in
                            path.move(to: CGPoint(x: plot.minX, y: baselineY))
                            path.addLine(to: CGPoint(x: plot.maxX, y: baselineY))
                        }
                        .stroke(AppColor.Text.tertiary, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))

                        Path { path in
                            path.move(to: CGPoint(x: plot.minX, y: floorY))
                            path.addLine(to: CGPoint(x: plot.maxX, y: floorY))
                        }
                        .stroke(AppColor.Status.error.opacity(0.7), style: StrokeStyle(lineWidth: 1))
                    }
                }
            }
    }
}

private extension View {
    func chart(baselineRule baseline: Double, floorRule floor: Double) -> some View {
        modifier(BaselineAndFloorOverlay(baseline: baseline, floor: floor))
    }
}
