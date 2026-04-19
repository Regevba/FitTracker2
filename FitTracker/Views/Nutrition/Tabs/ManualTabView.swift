// FitTracker/Views/Nutrition/Tabs/ManualTabView.swift
// Manual tab — direct entry of meal name + macros, plus Save Template / Log actions.
// Extracted from MealEntrySheet.swift in Audit M-2b (UI-004 decomposition).

import SwiftUI

struct ManualTabView: View {
    @ObservedObject var vm: MealEntryViewModel
    let onSaveAsTemplate: () -> Void
    let onLog: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.small) {
                Group {
                    MealEntryField(label: "Meal name",       placeholder: "e.g. Chicken & Rice", text: $vm.name)
                    MealEntryField(label: "Calories (kcal)", placeholder: "e.g. 500",            text: $vm.calories, isNumeric: true)
                    MealEntryField(label: "Protein (g)",     placeholder: "e.g. 40",             text: $vm.proteinG, isNumeric: true)
                    MealEntryField(label: "Carbs (g)",       placeholder: "e.g. 60",             text: $vm.carbsG,   isNumeric: true)
                    MealEntryField(label: "Fat (g)",         placeholder: "e.g. 15",             text: $vm.fatG,     isNumeric: true)
                }
                .padding(.horizontal, AppSpacing.small)

                VStack(spacing: AppSpacing.xSmall) {
                    Button {
                        onSaveAsTemplate()
                    } label: {
                        HStack {
                            if vm.savedTemplate {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(AppColor.Status.success)
                                Text("Saved!")
                                    .foregroundStyle(AppColor.Status.success)
                            } else {
                                Image(systemName: "square.and.arrow.down")
                                Text("Save as Template")
                            }
                        }
                        .font(AppText.body)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.xSmall)
                        .background(AppColor.Surface.elevated, in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                                .stroke(AppColor.Border.subtle, lineWidth: 1)
                        )
                    }
                    .disabled(vm.name.isEmpty)

                    AppButton(
                        title: "Log",
                        hierarchy: .primary
                    ) {
                        onLog()
                    }
                    .disabled(vm.name.isEmpty)
                }
                .padding(.horizontal, AppSpacing.small)
                .padding(.top, AppSpacing.xxSmall)
            }
            .padding(.top, AppSpacing.small)
            .padding(.bottom, AppSpacing.xLarge)
        }
    }
}
