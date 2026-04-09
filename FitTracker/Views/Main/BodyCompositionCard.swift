// FitTracker/Views/Main/BodyCompositionCard.swift
// Composite card: weight + body-fat metrics, overall progress bar,
// optional protein strip, and AI recommendation — tappable surface.
import SwiftUI

struct BodyCompositionCard: View {

    // MARK: - Inputs

    let currentWeight: Double?
    let currentBF: Double?
    let weightTarget: (min: Double, max: Double)?
    let bfTarget: (min: Double, max: Double)?
    let overallProgress: Double
    let proteinConsumed: Double?
    let proteinTarget: Double?
    let recommendation: HomeRecommendation
    let onTap: () -> Void
    let onLogTap: () -> Void

    // MARK: - State

    @State private var isPressed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Computed

    private var hasData: Bool {
        currentWeight != nil || currentBF != nil
    }

    // MARK: - Body

    var body: some View {
        Group {
            if hasData {
                filledCard
                    .onTapGesture { onTap() }
                    .onLongPressGesture(
                        minimumDuration: .infinity,
                        pressing: { pressing in
                            withAnimation(reduceMotion ? .none : AppSpring.snappy) {
                                isPressed = pressing
                            }
                        },
                        perform: {}
                    )
            } else {
                emptyCard
            }
        }
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .motionSafe(AppSpring.snappy, value: isPressed)
    }

    // MARK: - Filled card

    private var filledCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
            // 1 — Eyebrow + chevron
            eyebrowRow

            // 2 — Weight + Body Fat columns
            metricsRow

            // 3 — Progress bar
            progressBar

            // 4 — Protein strip (P1, conditional)
            if let consumed = proteinConsumed, let target = proteinTarget {
                proteinStrip(consumed: consumed, target: target)
            }

            // 5 — Recommendation
            Text(recommendation.title)
                .font(AppText.callout)
                .foregroundStyle(recommendation.accentColor)
                .lineLimit(2)
                .accessibilityLabel("Recommendation: \(recommendation.title)")
        }
        .padding(AppSpacing.small)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                .fill(AppColor.Surface.elevated)
        )
        .shadow(color: AppShadow.cardColor, radius: AppShadow.cardRadius, y: AppShadow.cardYOffset)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Body composition card")
        .accessibilityHint("Double-tap for details")
    }

    // MARK: - Empty card

    private var emptyCard: some View {
        VStack(spacing: AppSpacing.xSmall) {
            eyebrowRow

            Spacer()

            Button(action: onLogTap) {
                Text("Log your first metrics")
                    .font(AppText.button)
                    .foregroundStyle(AppColor.Accent.primary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Log your first metrics")
            .accessibilityHint("Opens the metrics logging screen")

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.small)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                .fill(AppColor.Surface.elevated)
        )
        .shadow(color: AppShadow.cardColor, radius: AppShadow.cardRadius, y: AppShadow.cardYOffset)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Body composition card, empty")
    }

    // MARK: - Subviews

    private var eyebrowRow: some View {
        HStack {
            Text("BODY COMPOSITION")
                .font(AppText.eyebrow)
                .foregroundStyle(AppColor.Text.tertiary)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Image(systemName: AppIcon.forward)
                .font(AppText.caption)
                .foregroundStyle(AppColor.Text.tertiary)
                .accessibilityHidden(true)
        }
    }

    private var metricsRow: some View {
        HStack(alignment: .top, spacing: AppSpacing.small) {
            // Weight column
            valueColumn(
                value: currentWeight.map { String(format: "%.1f", $0) },
                unit: "kg",
                target: weightTarget.map { "Target: \(String(format: "%.0f", $0.min))–\(String(format: "%.0f", $0.max))" }
            )

            // Body fat column
            valueColumn(
                value: currentBF.map { String(format: "%.1f", $0) },
                unit: "%",
                target: bfTarget.map { "Target: \(String(format: "%.0f", $0.min))–\(String(format: "%.0f", $0.max))%" }
            )
        }
    }

    private func valueColumn(value: String?, unit: String, target: String?) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxxSmall) {
            if let value {
                HStack(alignment: .lastTextBaseline, spacing: AppSpacing.micro) {
                    Text(value)
                        .font(AppText.metricM)
                        .monospacedDigit()
                        .foregroundStyle(AppColor.Text.primary)
                    Text(unit)
                        .font(AppText.footnote.weight(.medium))
                        .foregroundStyle(AppColor.Text.tertiary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityValue("\(value) \(unit)")
            } else {
                Text("—")
                    .font(AppText.metricM)
                    .foregroundStyle(AppColor.Text.tertiary)
            }

            if let target {
                Text(target)
                    .font(AppText.caption)
                    .foregroundStyle(AppColor.Text.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var progressBar: some View {
        HStack(spacing: AppSpacing.xxSmall) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: AppRadius.micro, style: .continuous)
                        .fill(AppColor.Surface.tertiary)

                    // Fill
                    RoundedRectangle(cornerRadius: AppRadius.micro, style: .continuous)
                        .fill(AppColor.Accent.primary)
                        .frame(width: geo.size.width * min(max(overallProgress, 0), 1))
                }
            }
            .frame(height: AppSize.progressBarHeight)

            Text("\(Int(overallProgress * 100))%")
                .font(AppText.caption)
                .monospacedDigit()
                .foregroundStyle(AppColor.Text.secondary)
                .accessibilityLabel("Overall progress \(Int(overallProgress * 100)) percent")
        }
    }

    private func proteinStrip(consumed: Double, target: Double) -> some View {
        Text("\u{1F969} \(Int(consumed))g / \(Int(target))g protein")
            .font(AppText.caption)
            .foregroundStyle(AppColor.Text.secondary)
            .accessibilityLabel("Protein: \(Int(consumed)) of \(Int(target)) grams")
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Filled") {
    BodyCompositionCard(
        currentWeight: 82.5,
        currentBF: 18.2,
        weightTarget: (min: 78, max: 82),
        bfTarget: (min: 14, max: 16),
        overallProgress: 0.64,
        proteinConsumed: 120,
        proteinTarget: 180,
        recommendation: HomeRecommendation(
            tone: .encouraging,
            title: "Looking good — steady effort today",
            subtitle: "",
            accentColor: AppColor.Accent.primary
        ),
        onTap: {},
        onLogTap: {}
    )
    .padding(AppSpacing.small)
    .background(AppGradient.screenBackground)
}

#Preview("No Protein") {
    BodyCompositionCard(
        currentWeight: 82.5,
        currentBF: nil,
        weightTarget: (min: 78, max: 82),
        bfTarget: nil,
        overallProgress: 0.35,
        proteinConsumed: nil,
        proteinTarget: nil,
        recommendation: HomeRecommendation(
            tone: .cautious,
            title: "Take it easy today",
            subtitle: "",
            accentColor: AppColor.Status.warning
        ),
        onTap: {},
        onLogTap: {}
    )
    .padding(AppSpacing.small)
    .background(AppGradient.screenBackground)
}

#Preview("Empty State") {
    BodyCompositionCard(
        currentWeight: nil,
        currentBF: nil,
        weightTarget: nil,
        bfTarget: nil,
        overallProgress: 0,
        proteinConsumed: nil,
        proteinTarget: nil,
        recommendation: HomeRecommendation(
            tone: .encouraging,
            title: "Ready to start?",
            subtitle: "",
            accentColor: AppColor.Accent.primary
        ),
        onTap: {},
        onLogTap: {}
    )
    .padding(AppSpacing.small)
    .background(AppGradient.screenBackground)
}
#endif
