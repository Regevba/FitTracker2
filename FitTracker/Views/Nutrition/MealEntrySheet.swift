// Views/Nutrition/MealEntrySheet.swift
// Sheet presented when the user taps a meal slot.
// Four tabs (each its own View struct under Tabs/): Smart, Manual, Template, Search.
// State + business logic in MealEntryViewModel (M-2c). This file is the
// coordinator: tab switch + sheets + bridge actions to dataStore / onSave / dismiss.

import SwiftUI

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
                    case .smart:
                        SmartTabView(vm: vm)
                    case .manual:
                        ManualTabView(vm: vm, onSaveAsTemplate: saveAsTemplate, onLog: logMeal)
                    case .template:
                        TemplateTabView(vm: vm, onDelete: deleteTemplates)
                    case .search:
                        SearchTabView(vm: vm, foodSearch: foodSearch, onTextSearch: runTextSearch)
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
    // MARK: – Bridge actions (entry / dataStore / dismiss / foodSearch)
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

    // Audit UI-017: actual implementation lives in
    // Services/FoodSearchService.swift. The view only triggers + observes.

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
