// Views/Nutrition/MealEntrySheet.swift
// Sheet presented when the user taps a meal slot.
// Three tabs: Manual entry, Template picker, Food search (text + barcode).

import SwiftUI
import Vision
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

    @State private var activeTab: MealEntryTab = .smart

    // Manual tab fields
    @State private var name:     String = ""
    @State private var calories: String = ""
    @State private var proteinG: String = ""
    @State private var carbsG:   String = ""
    @State private var fatG:     String = ""
    @State private var servingGrams: String = ""
    @State private var referenceGrams: String = "100"
    @State private var sourceDetails: String = ""

    // Smart label parsing
    @State private var rawLabelText: String = ""
    @State private var parsedLabel: ParsedNutritionLabel?
    @State private var smartStatus: String?
    @State private var smartError: String?

    // Template save confirmation
    @State private var savedTemplate = false

    // Search tab
    // Audit UI-017: search state + async network logic moved to
    // FoodSearchService (in Services/). Only the user-input text binding
    // (searchQuery) stays in the view — that's pure UI state.
    @State private var searchQuery: String = ""
    @StateObject private var foodSearch = FoodSearchService()

    // Barcode scanner
    @State private var showScanner: Bool = false
    #if canImport(UIKit)
    @State private var showCameraCapture = false
    @State private var selectedImagePreview: UIImage?
    #endif
    #if canImport(PhotosUI)
    @State private var selectedPhotoItem: PhotosPickerItem?
    #endif

    // ── Initialise fields from the binding on appear ──────
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab picker
                Picker("Meal entry method", selection: $activeTab) {
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

                // Tab content
                Group {
                    switch activeTab {
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
                name     = entry.name
                calories = entry.calories.map { String($0) } ?? ""
                proteinG = entry.proteinG.map  { String($0) } ?? ""
                carbsG   = entry.carbsG.map    { String($0) } ?? ""
                fatG     = entry.fatG.map      { String($0) } ?? ""
                servingGrams = entry.servingGrams.map { formatNum($0) } ?? ""
                referenceGrams = entry.labelReferenceGrams.map { formatNum($0) } ?? "100"
                sourceDetails = entry.sourceDetails
                rawLabelText = entry.source == .photoLabel ? entry.sourceDetails : ""
            }
        }
        #if os(iOS)
        .sheet(isPresented: $showScanner) {
            BarcodeScannerSheet { barcode in
                showScanner = false
                fetchProduct(barcode: barcode)
            }
        }
        .sheet(isPresented: $showCameraCapture) {
            NutritionCameraSheet { image in
                showCameraCapture = false
                processNutritionImage(image)
            }
        }
        #if canImport(PhotosUI)
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task { await loadSelectedPhoto(newItem) }
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
                if let selectedImagePreview {
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
                        showCameraCapture = true
                    } label: {
                        smartActionLabel("Take Label Photo", systemImage: "camera.fill", tint: AppColor.Accent.recovery)
                    }
                    .buttonStyle(.plain)
                    #endif

                    #if canImport(PhotosUI)
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        smartActionLabel("Choose Photo", systemImage: "photo.fill", tint: AppColor.Brand.warm)
                    }
                    .buttonStyle(.plain)
                    #endif
                }

                VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {
                    Text("Nutrition Text")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColor.Text.secondary)
                    TextEditor(text: $rawLabelText)
                        .frame(minHeight: 140)
                        .padding(AppSpacing.xxSmall)
                        .background(AppColor.Text.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: AppRadius.small))
                    Text("Hebrew and English keywords are parsed here. Photos use Apple Vision OCR first, then this parser scales the label to your consumed weight. If a Hebrew label photo doesn’t scan cleanly, paste the label text here and the parser still works.")
                        .font(.caption2)
                        .foregroundStyle(AppColor.Text.secondary)
                }

                HStack(spacing: AppSpacing.xSmall) {
                    manualField(label: "Consumed weight (g)", placeholder: "e.g. 100", text: $servingGrams, isNumeric: true)
                    manualField(label: "Label reference (g)", placeholder: "100", text: $referenceGrams, isNumeric: true)
                }

                if let smartStatus {
                    Label(smartStatus, systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColor.Status.success)
                }

                if let smartError {
                    Label(smartError, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColor.Status.error)
                }

                Button {
                    parseSmartLabel()
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

                if let parsedLabel {
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
                    manualField(label: "Meal name",       placeholder: "e.g. Chicken & Rice", text: $name)
                    manualField(label: "Calories (kcal)", placeholder: "e.g. 500",            text: $calories, isNumeric: true)
                    manualField(label: "Protein (g)",     placeholder: "e.g. 40",             text: $proteinG, isNumeric: true)
                    manualField(label: "Carbs (g)",       placeholder: "e.g. 60",             text: $carbsG,   isNumeric: true)
                    manualField(label: "Fat (g)",         placeholder: "e.g. 15",             text: $fatG,     isNumeric: true)
                }
                .padding(.horizontal, AppSpacing.small)

                // Buttons
                VStack(spacing: AppSpacing.xSmall) {
                    // Save as Template
                    Button {
                        saveAsTemplate()
                    } label: {
                        HStack {
                            if savedTemplate {
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
                    .disabled(name.isEmpty)

                    AppButton(
                        title: "Log",
                        hierarchy: .primary
                    ) {
                        logMeal()
                    }
                    .disabled(name.isEmpty)
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
                            fillFromTemplate(template)
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
            // Search bar
            VStack(spacing: AppSpacing.xxSmall) {
                HStack(spacing: AppSpacing.xxSmall) {
                    AppInputShell {
                        TextField("Search food…", text: $searchQuery)
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
                    .disabled(searchQuery.trimmingCharacters(in: .whitespaces).isEmpty || foodSearch.isSearching)
                }

                #if os(iOS)
                AppQuietButton(
                    title: "Scan Barcode",
                    systemImage: "barcode.viewfinder",
                    tint: AppColor.Accent.sleep
                ) {
                    showScanner = true
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

            // Results
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
                        fillFromProduct(product)
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
    // MARK: – Actions
    // ─────────────────────────────────────────────────────

    private func saveAsTemplate() {
        let template = MealTemplate(
            name:     name,
            calories: Double(calories),
            proteinG: Double(proteinG),
            carbsG:   Double(carbsG),
            fatG:     Double(fatG)
        )
        dataStore.mealTemplates.append(template)
        Task { await dataStore.persistToDisk() }

        savedTemplate = true
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run { savedTemplate = false }
        }
    }

    private func logMeal() {
        entry.name     = name
        entry.calories = Double(calories)
        entry.proteinG = Double(proteinG)
        entry.carbsG   = Double(carbsG)
        entry.fatG     = Double(fatG)
        entry.servingGrams = Double(servingGrams)
        entry.labelReferenceGrams = Double(referenceGrams)
        entry.sourceDetails = sourceDetails
        entry.eatenAt  = Date()
        entry.status   = .completed
        onSave(entry)
        dismiss()
    }

    private func fillFromTemplate(_ template: MealTemplate) {
        name     = template.name
        calories = template.calories.map { formatNum($0) } ?? ""
        proteinG = template.proteinG.map  { formatNum($0) } ?? ""
        carbsG   = template.carbsG.map    { formatNum($0) } ?? ""
        fatG     = template.fatG.map      { formatNum($0) } ?? ""
        entry.source = .template
        sourceDetails = "Saved template"
        activeTab = .manual
    }

    private func fillFromProduct(_ product: FoodProduct) {
        name     = product.name.isEmpty ? searchQuery : product.name
        calories = product.caloriesPer100g.map { formatNum($0) } ?? ""
        proteinG = product.proteinPer100g.map   { formatNum($0) } ?? ""
        carbsG   = product.carbsPer100g.map     { formatNum($0) } ?? ""
        fatG     = product.fatPer100g.map       { formatNum($0) } ?? ""
        referenceGrams = formatNum(product.referenceGrams)
        servingGrams = servingGrams.isEmpty ? formatNum(product.referenceGrams) : servingGrams
        entry.source = product.source
        sourceDetails = product.sourceDescription
        activeTab = .manual
    }

    private func deleteTemplates(at offsets: IndexSet) {
        dataStore.mealTemplates.remove(atOffsets: offsets)
        Task { await dataStore.persistToDisk() }
    }

    private func formatNum(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
    }

    private func parseSmartLabel() {
        smartError = nil
        smartStatus = nil

        guard let parsed = NutritionLabelParser.parse(rawLabelText, fallbackReferenceGrams: Double(referenceGrams) ?? 100) else {
            smartError = "I couldn’t parse the label yet. Try a clearer photo or paste the nutrition lines."
            return
        }

        parsedLabel = parsed
        referenceGrams = formatNum(parsed.referenceGrams)
        applyParsedLabel(parsed)
        entry.source = .photoLabel
        sourceDetails = rawLabelText
        smartStatus = parsed.detectedLanguageHint == .hebrew
            ? "Hebrew nutrition text parsed successfully."
            : "Nutrition label applied successfully."
        activeTab = .manual
    }

    private func applyParsedLabel(_ parsed: ParsedNutritionLabel) {
        let consumedGrams = Double(servingGrams) ?? parsed.referenceGrams
        servingGrams = formatNum(consumedGrams)
        let scale = max(consumedGrams, 1) / max(parsed.referenceGrams, 1)

        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            name = parsed.nameHint ?? name
        }

        calories = parsed.calories.map { formatNum($0 * scale) } ?? calories
        proteinG = parsed.proteinG.map { formatNum($0 * scale) } ?? proteinG
        carbsG = parsed.carbsG.map { formatNum($0 * scale) } ?? carbsG
        fatG = parsed.fatG.map { formatNum($0 * scale) } ?? fatG
    }

    #if canImport(UIKit)
    private func processNutritionImage(_ image: UIImage) {
        selectedImagePreview = image
        smartError = nil
        smartStatus = "Reading nutrition label…"

        guard let cgImage = image.cgImage else {
            smartStatus = nil
            smartError = "That image could not be processed."
            return
        }

        let request = VNRecognizeTextRequest { request, error in
            DispatchQueue.main.async {
                if let error {
                    smartStatus = nil
                    smartError = "Photo scan failed: \(error.localizedDescription)"
                    return
                }

                let lines = (request.results as? [VNRecognizedTextObservation])?
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n") ?? ""

                rawLabelText = lines
                parseSmartLabel()
            }
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        if #available(iOS 16.0, macOS 13.0, *) {
            request.automaticallyDetectsLanguage = true
        }
        if let languages = try? request.supportedRecognitionLanguages() {
            let preferred = ["en-US", "he-IL", "ar-SA"]
            request.recognitionLanguages = preferred.filter { languages.contains($0) }
        }

        Task.detached(priority: .userInitiated) {
            do {
                try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
            } catch {
                await MainActor.run {
                    smartStatus = nil
                    smartError = "Photo scan failed: \(error.localizedDescription)"
                }
            }
        }
    }

    #if canImport(PhotosUI)
    private func loadSelectedPhoto(_ item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                await MainActor.run { smartError = "That photo could not be opened." }
                return
            }
            await MainActor.run { processNutritionImage(image) }
        } catch {
            await MainActor.run { smartError = "Photo import failed: \(error.localizedDescription)" }
        }
    }
    #endif
    #endif

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
            Text(value.map { formatNum($0) } ?? "—")
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Networking — thin shims over FoodSearchService
    // Audit UI-017: actual implementation lives in
    // Services/FoodSearchService.swift. The view only triggers + observes.
    // ─────────────────────────────────────────────────────

    private func runTextSearch() {
        Task { await foodSearch.search(query: searchQuery) }
    }

    private func fetchProduct(barcode: String) {
        activeTab = .search
        Task {
            if let product = await foodSearch.fetchProduct(barcode: barcode) {
                fillFromProduct(product)
            }
        }
    }
}
