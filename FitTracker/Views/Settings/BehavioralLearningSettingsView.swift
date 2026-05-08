// FitTracker/Views/Settings/BehavioralLearningSettingsView.swift
//
// PR 1 of smart-reminders-behavioral-learning (per
// docs/superpowers/specs/2026-05-01-smart-reminders-behavioral-learning-design.md):
// a single global "Smart timing" toggle row.
//
// Defaults OFF — PR 1 ships zero user-visible behaviour change. The
// resolver that consumes the priors + posterior (SmartTimingResolver,
// PR 2) is not yet on the schedule path; this toggle has no consumer yet.
//
// PR 2 will flip the default to ON for new installs and wire the toggle
// to the SmartTimingResolver. PR 3 will append per-type "Why this time?"
// rows below this section.
//
// Self-contained: takes AppSettings via @EnvironmentObject. Embed via
//   BehavioralLearningSettingsView()
// from any host Settings screen.

import SwiftUI

struct BehavioralLearningSettingsView: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        SettingsSectionCard(title: "Smart Timing", eyebrow: "Reminders") {
            Toggle(isOn: $settings.smartTimingEnabled) {
                VStack(alignment: .leading, spacing: AppSpacing.xxxSmall) {
                    Text("Smart timing")
                        .font(AppText.button)
                        .foregroundStyle(AppColor.Text.primary)
                    Text("Learns when you're most responsive and shifts reminder times to match. Off keeps the app's static defaults.")
                        .font(AppText.subheading)
                        .foregroundStyle(AppColor.Text.secondary)
                }
            }
            .tint(AppColor.Accent.primary)

            SettingsSupportingText("Personalisation applies to Nutrition Gap, Training Day, and Rest Day reminders. The other reminder types use static fire times.")
        }
    }
}
