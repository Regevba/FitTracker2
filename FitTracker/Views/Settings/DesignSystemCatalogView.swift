import SwiftUI

struct DesignSystemCatalogView: View {
    @Environment(\.dismiss) private var dismiss

    private let tokenGroups: [(title: String, swatches: [(name: String, color: Color)])] = [
        (
            "Brand + Accent",
            [
                ("Primary", AppColor.Brand.primary),
                ("Secondary", AppColor.Brand.secondary),
                ("Recovery", AppColor.Accent.recovery),
                ("Sleep", AppColor.Accent.sleep),
                ("Achievement", AppColor.Accent.achievement),
            ]
        ),
        (
            "Status",
            [
                ("Success", AppColor.Status.success),
                ("Warning", AppColor.Status.warning),
                ("Error", AppColor.Status.error),
            ]
        ),
        (
            "Surfaces",
            [
                ("Primary", AppColor.Surface.primary),
                ("Elevated", AppColor.Surface.elevated),
                ("Material", AppColor.Surface.materialLight),
                ("Inverse", AppColor.Surface.inverse),
            ]
        ),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                AppGradient.screenBackground
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: AppSpacing.large) {
                        heroCard
                        tokenSection
                        typographySection
                        buttonsSection
                        componentSection
                        platformSection
                    }
                    .padding(AppSpacing.large)
                }
            }
            .navigationTitle("Design System")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColor.Accent.primary)
                }
            }
        }
    }

    private var heroCard: some View {
        AppCard(tone: .elevated, contentPadding: AppSpacing.large) {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                Text("Apple-First System Foundation")
                    .font(AppText.pageTitle)
                    .foregroundStyle(AppColor.Text.primary)

                Text("This catalog is the coded source of truth for FitTracker foundations. Build iPhone first, validate regular-width Apple layouts next, then adapt the same semantic core to Android and Pixel patterns.")
                    .font(AppText.subheading)
                    .foregroundStyle(AppColor.Text.secondary)

                HStack(spacing: AppSpacing.small) {
                    StatusBadge(text: "iPhone First", color: AppColor.Accent.primary)
                    StatusBadge(text: "Semantic Tokens", color: AppColor.Accent.recovery)
                    StatusBadge(text: "Android Ready", color: AppColor.Brand.secondary)
                }
            }
        }
    }

    private var tokenSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Text("Color Roles")
                .font(AppText.sectionTitle)
                .foregroundStyle(AppColor.Text.primary)

            ForEach(tokenGroups, id: \.title) { group in
                AppCard {
                    VStack(alignment: .leading, spacing: AppSpacing.medium) {
                        Text(group.title)
                            .font(AppText.callout)
                            .foregroundStyle(AppColor.Text.primary)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: AppSpacing.medium)], spacing: AppSpacing.medium) {
                            ForEach(group.swatches, id: \.name) { swatch in
                                TokenSwatch(name: swatch.name, color: swatch.color)
                            }
                        }
                    }
                }
            }
        }
    }

    private var typographySection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                Text("Typography Roles")
                    .font(AppText.sectionTitle)
                    .foregroundStyle(AppColor.Text.primary)

                typographySample("Hero", font: AppText.hero, text: "Today")
                typographySample("Page Title", font: AppText.pageTitle, text: "Nutrition")
                typographySample("Section", font: AppText.sectionTitle, text: "Weekly Trends")
                typographySample("Body", font: AppText.body, text: "Fast scanning, Dynamic Type friendly copy.")
                typographySample("Caption", font: AppText.caption, text: "Supporting info, labels, and metadata.")
                typographySample("Monospaced Metric", font: AppText.monoMetric, text: "128 g")
            }
        }
    }

    private var buttonsSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                Text("Buttons + CTA")
                    .font(AppText.sectionTitle)
                    .foregroundStyle(AppColor.Text.primary)

                AppButton(title: "Primary Action", systemImage: "bolt.fill") {}
                AppButton(title: "Secondary Action", hierarchy: .secondary) {}
                AppButton(title: "Learn More", hierarchy: .tertiary, isFullWidth: false) {}
            }
        }
    }

    private var componentSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Text("Shared Components")
                .font(AppText.sectionTitle)
                .foregroundStyle(AppColor.Text.primary)

            AppCard {
                VStack(alignment: .leading, spacing: AppSpacing.medium) {
                    MetricCard(
                        icon: "scalemass.fill",
                        label: "Weight",
                        value: "67.3",
                        unit: "kg",
                        trendDelta: "↓ 0.5",
                        statusColor: AppColor.Status.success
                    )

                    ChartCard(
                        title: "Training Volume",
                        periodLabel: "Last 7 days",
                        trendDelta: 0.12,
                        positiveIsGood: true
                    ) {
                        RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                            .fill(AppGradient.brand.opacity(0.24))
                            .frame(height: 88)
                            .overlay(
                                Text("Chart shell")
                                    .font(AppText.captionStrong)
                                    .foregroundStyle(AppColor.Text.secondary)
                            )
                    }
                }
            }

            AppCard {
                VStack(alignment: .leading, spacing: AppSpacing.medium) {
                    AppMenuRow(
                        icon: "list.bullet.rectangle.fill",
                        title: "Settings and Menus",
                        subtitle: "Use list-detail rows with clear hierarchy and a single trailing action."
                    )

                    EmptyStateView(
                        icon: "sparkles",
                        title: "No recovery data yet",
                        subtitle: "Shared empty, loading, and error states should describe the next useful action."
                    )
                }
            }
        }
    }

    private var platformSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                Text("Platform Priorities")
                    .font(AppText.sectionTitle)
                    .foregroundStyle(AppColor.Text.primary)

                platformRow(title: "iPhone", detail: "Compact-first hierarchy, one-handed actions, visible next step.")
                platformRow(title: "iPad + Mac", detail: "Sidebar/detail, broader spacing, stronger secondary panels.")
                platformRow(title: "watchOS", detail: "Rules-first only for now: glanceability, short labels, high contrast.")
                platformRow(title: "Android / Pixel", detail: "Map the same semantic tokens to Material 3 roles and edge-to-edge patterns.")
            }
        }
    }

    private func typographySample(_ title: String, font: Font, text: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxxSmall) {
            Text(title)
                .font(AppText.captionStrong)
                .foregroundStyle(AppColor.Text.tertiary)
                .textCase(.uppercase)
            Text(text)
                .font(font)
                .foregroundStyle(AppColor.Text.primary)
        }
    }

    private func platformRow(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxxSmall) {
            Text(title)
                .font(AppText.callout)
                .foregroundStyle(AppColor.Text.primary)
            Text(detail)
                .font(AppText.caption)
                .foregroundStyle(AppColor.Text.secondary)
        }
    }
}

private struct TokenSwatch: View {
    let name: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                .fill(color)
                .frame(height: 54)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                        .stroke(AppColor.Border.hairline, lineWidth: 1)
                )

            Text(name)
                .font(AppText.captionStrong)
                .foregroundStyle(AppColor.Text.primary)
        }
    }
}

#if DEBUG
struct DesignSystemCatalogView_Previews: PreviewProvider {
    static var previews: some View {
        DesignSystemCatalogView()
    }
}
#endif
