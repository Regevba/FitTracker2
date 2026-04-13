import SwiftUI

struct ProfileBodyCompCard: View {
    let currentWeight: Double?
    let currentBF: Double?
    let currentLeanMass: Double?
    let targetWeightMin: Double
    let targetWeightMax: Double
    let targetBFMin: Double
    let targetBFMax: Double
    let startBF: Double
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                // Header
                Text("Body Composition")
                    .font(AppText.subheading)
                    .foregroundStyle(AppColor.Text.primary)

                // Current metrics row
                HStack(spacing: AppSpacing.large) {
                    metricColumn(
                        value: currentWeight.map { String(format: "%.1f", $0) } ?? "–",
                        unit: "kg",
                        label: "Weight"
                    )
                    metricColumn(
                        value: currentBF.map { String(format: "%.1f", $0) } ?? "–",
                        unit: "%",
                        label: "Body Fat"
                    )
                    metricColumn(
                        value: currentLeanMass.map { String(format: "%.1f", $0) } ?? "–",
                        unit: "kg",
                        label: "Lean Mass"
                    )
                }

                // Target row
                Text("Target: \(Int(targetWeightMin))–\(Int(targetWeightMax)) kg · \(Int(targetBFMin))–\(Int(targetBFMax))% BF")
                    .font(AppText.caption)
                    .foregroundStyle(AppColor.Text.secondary)

                // Progress bar
                if let currentBF, startBF > 0 {
                    let targetMidpoint = (targetBFMin + targetBFMax) / 2
                    let totalRange = startBF - targetMidpoint
                    let progress = totalRange > 0 ? min(1, max(0, (startBF - currentBF) / totalRange)) : 0

                    VStack(alignment: .leading, spacing: AppSpacing.xxxSmall) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: AppRadius.button)
                                    .fill(AppColor.Surface.secondary)
                                    .frame(height: 8)
                                RoundedRectangle(cornerRadius: AppRadius.button)
                                    .fill(AppColor.Brand.primary)
                                    .frame(width: geo.size.width * progress, height: 8)
                            }
                        }
                        .frame(height: 8)

                        Text("\(Int(progress * 100))% to goal")
                            .font(AppText.caption)
                            .foregroundStyle(AppColor.Text.tertiary)
                    }
                } else {
                    Text("Log your first weigh-in to track progress")
                        .font(AppText.caption)
                        .foregroundStyle(AppColor.Text.tertiary)
                }
            }
            .padding(AppSpacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.Surface.primary, in: RoundedRectangle(cornerRadius: AppRadius.card))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Body composition. \(currentWeight.map { String(format: "%.1f kilograms", $0) } ?? "No data"). Tap to view stats.")
    }

    private func metricColumn(value: String, unit: String, label: String) -> some View {
        VStack(spacing: AppSpacing.xxxSmall) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(AppText.monoCaption)
                    .foregroundStyle(AppColor.Text.primary)
                Text(unit)
                    .font(AppText.caption)
                    .foregroundStyle(AppColor.Text.tertiary)
            }
            Text(label)
                .font(AppText.caption)
                .foregroundStyle(AppColor.Text.secondary)
        }
    }
}
