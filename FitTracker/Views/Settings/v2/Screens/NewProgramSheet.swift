// Views/Settings/v2/Screens/NewProgramSheet.swift
// C6 training-program-customization (2026-06-02) — Surface 2.
//
// Modal sub-sheet over CustomProgramListScreen. User picks a template tile,
// optionally renames, and taps Save → calls onSave with a fresh
// CustomProgram materialized via TrainingProgramData.template(_:).
//
// Analytics: training_custom_program_template_selected fires on tile tap.
// training_custom_program_saved fires from the parent (list screen) when
// the program is persisted, not here.

import SwiftUI

struct NewProgramSheet: View {
    var onSave: (CustomProgram) -> Void

    @EnvironmentObject private var analytics: AnalyticsService
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTemplate: TemplateID = .ppl6Day
    @State private var programName: String = TemplateID.ppl6Day.defaultProgramName

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.large) {
                    SettingsSectionCard(title: "Pick a Template", eyebrow: "Start From") {
                        VStack(spacing: AppSpacing.small) {
                            ForEach(TemplateID.allCases, id: \.rawValue) { template in
                                templateTile(template)
                            }
                        }
                    }

                    SettingsSectionCard(title: "Name Your Program", eyebrow: "Personalize") {
                        TextField("Program name", text: $programName)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled(true)
                            .accessibilityLabel("Program name")
                    }
                }
                .padding(AppSpacing.medium)
            }
            .background(AppGradient.screenBackground.ignoresSafeArea())
            .navigationTitle("New Program")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { handleSave() }
                        .disabled(trimmedName.isEmpty)
                }
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func templateTile(_ template: TemplateID) -> some View {
        let isSelected = selectedTemplate == template
        Button {
            select(template)
        } label: {
            HStack(spacing: AppSpacing.small) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? AppColor.Accent.primary : AppColor.Text.tertiary)
                VStack(alignment: .leading, spacing: AppSpacing.micro) {
                    Text(template.displayName)
                        .font(AppText.body)
                        .foregroundStyle(AppColor.Text.primary)
                    Text(template.summary)
                        .font(AppText.caption)
                        .foregroundStyle(AppColor.Text.secondary)
                }
                Spacer()
            }
            .padding(.vertical, AppSpacing.xSmall)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(template.displayName), \(template.summary)\(isSelected ? ", selected" : "")")
    }

    // MARK: - Helpers

    private var trimmedName: String {
        programName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func select(_ template: TemplateID) {
        selectedTemplate = template
        // Only reset the name if the user hasn't customized it (matches the
        // previous template's default).
        let previousDefaults = TemplateID.allCases.map(\.defaultProgramName)
        if previousDefaults.contains(programName) {
            programName = template.defaultProgramName
        }
        analytics.logTrainingCustomProgramTemplateSelected(templateId: template.rawValue)
    }

    private func handleSave() {
        var program = TrainingProgramData.template(selectedTemplate)
        program.name = trimmedName
        program.updatedAt = Date()
        onSave(program)
        dismiss()
    }
}
