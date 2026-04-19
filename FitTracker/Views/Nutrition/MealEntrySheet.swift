// Views/Nutrition/MealEntrySheet.swift
// Sheet presented when the user taps a meal slot.
// Four tabs: Smart capture, Manual entry, Template picker, Food search (text + barcode).
// State + business logic live in MealEntryViewModel (Audit M-2c).

import SwiftUI
#if canImport(PhotosUI)
import PhotosUI
#endif
#if canImport(UIKit)
import UIKit
#endif

// ─────────────────────────────────────────────────────────
// MARK: – Tab enum
// ─────────────────────────────────────────────────────────

enum MealEntryTab: String, CaseIterable {
    case smart    = "Smart"
    case manual   = "Manual"
    case template = "Template"
    case search   = "Search"
}

// ─────────────────────────────────────────────────────────
// MARK: – Main Sheet
// ─────────────────────────────────────────────────────────

struct MealEntrySheet: View {
    @EnvironmentObject var dataStore: EncryptedDataStore
    @Binding var entry: MealEntry
    let onSave: (MealEntry) -> Void
    @Environment(\.dismiss) var dismiss

    @StateObject private var vm = MealEntryViewModel()
    @StateObject private var foodSearch = FoodSearchService()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Meal entry method", selection: $vm.activeTab) {
                    ForEach(MealEntryTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, AppSpacing.small)
                .padding(.vertical, AppSpacing.xxSmall)
                .accessibilityLabel("Meal entry method")
                .accessibilityHint("Choose how to enter your meal: smart capture, manual, template, or search")

                Divider()

                Group {
                    switch vm.activeTab {
                    case .smart:    smartTab
                    case .manual:   manualTab
                    case .template: templateTab
                    case .search:   searchTab
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Log Meal \(entry.mealNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                vm.onSourceChange = { newSource in entry.source = newSource }
                vm.loadFromEntry(entry)
            }
        }
        #if os(iOS)
        .sheet(isPresented: $vm.showScanner) {
            BarcodeScannerSheet { barcode in
                vm.showScanner = false
                fetchProduct(barcode: barcode)
            }
        }
        .sheet(isPresented: $vm.showCameraCapture) {
            NutritionCameraSheet { image in
                vm.showCameraCapture = false
                vm.processNutritionImage(image)
            }
        }
        #if canImport(PhotosUI)
        .onChange(of: vm.selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task { await vm.loadSelectedPhoto(newItem) }
        }
        #endif
        #endif
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Smart Tab
    // ─────────────────────────────────────────────────────

    private var smartTab: some View {
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
                        smartActionLabel("Take Label Photo", systemImage: "camera.fill", tint: AppColor.Accent.recovery)
                    }
                    .buttonStyle(.plain)
                    #endif

                    #if canImport(PhotosUI)
                    PhotosPicker(selection: $vm.selectedPhotoItem, matching: .images) {
                        smartActionLabel("Choose Photo", systemImage: "photo.fill", tint: AppColor.Brand.warm)
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
                    manualField(label: "Consumed weight (g)", placeholder: "e.g. 100", text: $vm.servingGrams, isNumeric: true)
                    manualField(label: "Label reference (g)", placeholder: "100", text: $vm.referenceGrams, isNumeric: true)
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
                            parsedMetric("kcal", parsedLabel.calories, tint: AppColor.Brand.warm)
                            parsedMetric("Protein", parsedLabel.proteinG, tint: AppColor.Accent.recovery)
                            parsedMetric("Carbs", parsedLabel.carbsG, tint: AppColor.Brand.warmSoft)
                            parsedMetric("Fat", parsedLabel.fatG, tint: AppColor.Chart.nutritionFat)
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

    // ─────────────────────────────────────────────────────
    // MARK: – Manual Tab
    // ─────────────────────────────────────────────────────

    private var manualTab: some View {
        ScrollView {
            VStack(spacing: AppSpacing.small) {
                Group {
                    manualField(label: "Meal name",       placeholder: "e.g. Chicken & Rice", text: $vm.name)
                    manualField(label: "Calories (kcal)", placeholder: "e.g. 500",            text: $vm.calories, isNumeric: true)
                    manualField(label: "Protein (g)",     placeholder: "e.g. 40",             text: $vm.proteinG, isNumeric: true)
                    manualField(label: "Carbs (g)",       placeholder: "e.g. 60",             text: $vm.carbsG,   isNumeric: true)
                    manualField(label: "Fat (g)",         placeholder: "e.g. 15",             text: $vm.fatG,     isNumeric: true)
                }
                .padding(.horizontal, AppSpacing.small)

                VStack(spacing: AppSpacing.xSmall) {
                    Button {
                        saveAsTemplate()
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
                        logMeal()
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

    @ViewBuilder
    private func manualField(label: String, placeholder: String, text: Binding<String>, isNumeric: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {
            AppFieldLabel(title: label)
            AppInputShell {
                TextField(placeholder, text: text)
                    .font(AppText.body)
                    .foregroundStyle(AppColor.Text.primary)
                    #if canImport(UIKit)
                    .keyboardType(isNumeric ? .decimalPad : .default)
                    #endif
            }
        }
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Template Tab
    // ─────────────────────────────────────────────────────

    private var templateTab: some View {
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
                    .onDelete { offsets in deleteTemplates(at: offsets) }
                }
                .listStyle(.plain)
            }
        }
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Search Tab
    // ─────────────────────────────────────────────────────

    private var searchTab: some View {
        VStack(spacing: 0) {
            VStack(spacing: AppSpacing.xxSmall) {
                HStack(spacing: AppSpacing.xxSmall) {
                    AppInputShell {
                        TextField("Search food…", text: $vm.searchQuery)
                            .font(AppText.body)
                            .foregroundStyle(AppColor.Text.primary)
                            .submitLabel(.search)
                            .onSubmit { runTextSearch() }
                    }

                    AppButton(
                        title: "",
                        systemImage: foodSearch.isSearching ? "clock" : "magnifyingglass",
                        hierarchy: .primary,
                        isFullWidth: false
                    ) {
                        runTextSearch()
                    }
                    .disabled(vm.searchQuery.trimmingCharacters(in: .whitespaces).isEmpty || foodSearch.isSearching)
                }

                #if os(iOS)
                AppQuietButton(
                    title: "Scan Barcode",
                    systemImage: "barcode.viewfinder",
                    tint: AppColor.Accent.sleep
                ) {
                    vm.showScanner = true
                }
                #endif

                if let error = foodSearch.searchError {
                    HStack(spacing: AppSpacing.xxSmall) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(AppColor.Status.error)
                        Text(error)
                            .font(AppText.caption)
                            .foregroundStyle(AppColor.Status.error)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, AppSpacing.small)
            .padding(.top, AppSpacing.xSmall)
            .padding(.bottom, AppSpacing.xxSmall)

            Divider()

            if foodSearch.searchResults.isEmpty && !foodSearch.isSearching {
                Spacer()
                EmptyStateView(
                    icon: "magnifyingglass",
                    title: "Search for food",
                    subtitle: "Type a food name above or scan a barcode to find nutrition data."
                )
                Spacer()
            } else if foodSearch.isSearching {
                Spacer()
                ProgressView("Searching…")
                    .font(AppText.subheading)
                Spacer()
            } else {
                List(foodSearch.searchResults) { product in
                    Button {
                        vm.fillFromProduct(product)
                    } label: {
                        VStack(alignment: .leading, spacing: AppSpacing.xxxSmall) {
                            Text(product.name.isEmpty ? "Unknown product" : product.name)
                                .font(AppText.body)
                                .foregroundStyle(AppColor.Text.primary)
                            HStack(spacing: AppSpacing.xxSmall) {
                                if let cal = product.caloriesPer100g {
                                    Text("\(Int(cal)) kcal/100g")
                                        .font(AppText.caption)
                                        .foregroundStyle(AppColor.Accent.achievement)
                                }
                                if let pro = product.proteinPer100g {
                                    Text("\(Int(pro))g prot")
                                        .font(AppText.caption)
                                        .foregroundColor(AppColor.Accent.recovery)
                                }
                            }
                            Text(product.sourceDescription)
                                .font(.caption2)
                                .foregroundStyle(AppColor.Text.secondary)
                        }
                        .padding(.vertical, AppSpacing.xxxSmall)
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }
        }
    }

    // ─────────────────────────────────────────────────────
    // MARK: – View helpers
    // ─────────────────────────────────────────────────────

    private func smartActionLabel(_ title: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: AppSpacing.xxSmall) {
            Image(systemName: systemImage)
            Text(title)
        }
        .font(.caption.weight(.semibold))
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xSmall)
        .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: AppRadius.small))
        .foregroundStyle(tint)
    }

    private func parsedMetric(_ title: String, _ value: Double?, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.micro) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(AppColor.Text.secondary)
            Text(value.map { vm.formatNum($0) } ?? "—")
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Bridge actions (entry / dataStore / dismiss)
    // ─────────────────────────────────────────────────────

    private func saveAsTemplate() {
        let template = MealTemplate(
            name:     vm.name,
            calories: Double(vm.calories),
            proteinG: Double(vm.proteinG),
            carbsG:   Double(vm.carbsG),
            fatG:     Double(vm.fatG)
        )
        dataStore.mealTemplates.append(template)
        Task { await dataStore.persistToDisk() }
        vm.confirmTemplateSaved()
    }

    private func logMeal() {
        vm.writeBack(into: &entry)
        onSave(entry)
        dismiss()
    }

    private func deleteTemplates(at offsets: IndexSet) {
        dataStore.mealTemplates.remove(atOffsets: offsets)
        Task { await dataStore.persistToDisk() }
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Networking — thin shims over FoodSearchService
    // Audit UI-017: actual implementation lives in
    // Services/FoodSearchService.swift. The view only triggers + observes.
    // ─────────────────────────────────────────────────────

    private func runTextSearch() {
        Task { await foodSearch.search(query: vm.searchQuery) }
    }

    private func fetchProduct(barcode: String) {
        vm.activeTab = .search
        Task {
            if let product = await foodSearch.fetchProduct(barcode: barcode) {
                vm.fillFromProduct(product)
            }
        }
    }
}
