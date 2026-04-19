// FitTracker/Views/Nutrition/Tabs/SmartTabView.swift
// Smart tab — camera/photo capture + bilingual nutrition label parsing.
// Extracted from MealEntrySheet.swift in Audit M-2b (UI-004 decomposition).

import SwiftUI
#if canImport(PhotosUI)
import PhotosUI
#endif

struct SmartTabView: View {
    @ObservedObject var vm: MealEntryViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {
                    Text("Smart Nutrition Capture")
                        .font(AppText.sectionTitle)
                    Text("Scan a nutrition label, paste English or Hebrew nutrition text, then scale it to the weight you actually ate.")
                        .font(AppText.caption)
                        .foregroundStyle(AppColor.Text.secondary)
                }

                #if canImport(UIKit)
                if let selectedImagePreview = vm.selectedImagePreview {
                    Image(uiImage: selectedImagePreview)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 150)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.medium)
                                .stroke(AppColor.Border.subtle, lineWidth: 1)
                        )
                }
                #endif

                HStack(spacing: AppSpacing.xxSmall) {
                    #if canImport(UIKit)
                    Button {
                        vm.showCameraCapture = true
                    } label: {
                        SmartActionLabel(title: "Take Label Photo", systemImage: "camera.fill", tint: AppColor.Accent.recovery)
                    }
                    .buttonStyle(.plain)
                    #endif

                    #if canImport(PhotosUI)
                    PhotosPicker(selection: $vm.selectedPhotoItem, matching: .images) {
                        SmartActionLabel(title: "Choose Photo", systemImage: "photo.fill", tint: AppColor.Brand.warm)
                    }
                    .buttonStyle(.plain)
                    #endif
                }

                VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {
                    Text("Nutrition Text")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColor.Text.secondary)
                    TextEditor(text: $vm.rawLabelText)
                        .frame(minHeight: 140)
                        .padding(AppSpacing.xxSmall)
                        .background(AppColor.Text.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: AppRadius.small))
                    Text("Hebrew and English keywords are parsed here. Photos use Apple Vision OCR first, then this parser scales the label to your consumed weight. If a Hebrew label photo doesn’t scan cleanly, paste the label text here and the parser still works.")
                        .font(.caption2)
                        .foregroundStyle(AppColor.Text.secondary)
                }

                HStack(spacing: AppSpacing.xSmall) {
                    MealEntryField(label: "Consumed weight (g)", placeholder: "e.g. 100", text: $vm.servingGrams, isNumeric: true)
                    MealEntryField(label: "Label reference (g)", placeholder: "100", text: $vm.referenceGrams, isNumeric: true)
                }

                if let smartStatus = vm.smartStatus {
                    Label(smartStatus, systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColor.Status.success)
                }

                if let smartError = vm.smartError {
                    Label(smartError, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColor.Status.error)
                }

                Button {
                    vm.parseSmartLabel()
                } label: {
                    Text("Parse and Apply")
                        .font(AppText.button)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.xSmall)
                        .background(AppColor.Accent.recovery, in: RoundedRectangle(cornerRadius: AppRadius.small))
                        // Audit UI-012: token instead of raw .white literal
                        .foregroundStyle(AppColor.Text.inversePrimary)
                }
                .buttonStyle(.plain)

                if let parsedLabel = vm.parsedLabel {
                    VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {
                        Text("Parsed Per \(Int(parsedLabel.referenceGrams))g")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppColor.Text.secondary)
                        HStack(spacing: AppSpacing.xSmall) {
                            ParsedMetricView(title: "kcal", value: parsedLabel.calories, tint: AppColor.Brand.warm)
                            ParsedMetricView(title: "Protein", value: parsedLabel.proteinG, tint: AppColor.Accent.recovery)
                            ParsedMetricView(title: "Carbs", value: parsedLabel.carbsG, tint: AppColor.Brand.warmSoft)
                            ParsedMetricView(title: "Fat", value: parsedLabel.fatG, tint: AppColor.Chart.nutritionFat)
                        }
                    }
                    .padding(AppSpacing.xSmall)
                    .background(AppColor.Surface.materialStrong, in: RoundedRectangle(cornerRadius: AppRadius.medium))
                }
            }
            .padding(.horizontal, AppSpacing.small)
            .padding(.top, AppSpacing.small)
            .padding(.bottom, AppSpacing.xLarge)
        }
    }
}
