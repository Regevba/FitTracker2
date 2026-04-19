// FitTracker/Views/Nutrition/Tabs/TemplateTabView.swift
// Template tab — pick a saved meal template to populate the manual form.
// Extracted from MealEntrySheet.swift in Audit M-2b (UI-004 decomposition).

import SwiftUI

struct TemplateTabView: View {
    @ObservedObject var vm: MealEntryViewModel
    @EnvironmentObject var dataStore: EncryptedDataStore
    let onDelete: (IndexSet) -> Void

    var body: some View {
        Group {
            if dataStore.mealTemplates.isEmpty {
                EmptyStateView(
                    icon: "doc.text",
                    title: "No Templates Yet",
                    subtitle: "Save a meal from the Manual tab to reuse it here."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(dataStore.mealTemplates) { template in
                        Button {
                            vm.fillFromTemplate(template)
                        } label: {
                            VStack(alignment: .leading, spacing: AppSpacing.xxxSmall) {
                                Text(template.name)
                                    .font(AppText.body)
                                    .foregroundStyle(AppColor.Text.primary)
                                HStack(spacing: AppSpacing.xxSmall) {
                                    if let cal = template.calories {
                                        Text("\(Int(cal)) kcal")
                                            .font(AppText.caption)
                                            .foregroundStyle(AppColor.Accent.achievement)
                                    }
                                    if let pro = template.proteinG {
                                        Text("\(Int(pro))g protein")
                                            .font(AppText.caption)
                                            .foregroundStyle(AppColor.Accent.recovery)
                                    }
                                }
                            }
                            .padding(.vertical, AppSpacing.xxxSmall)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in onDelete(offsets) }
                }
                .listStyle(.plain)
            }
        }
    }
}
