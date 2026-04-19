// Views/Nutrition/MealEntrySheet.swift
// Sheet presented when the user taps a meal slot.
// Three tabs: Manual entry, Template picker, Food search (text + barcode).

import SwiftUI
import AVFoundation
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
    @State private var searchQuery: String = ""
    @State private var searchResults: [FoodProduct] = []
    @State private var isSearching: Bool = false
    @State private var searchError: String? = nil

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
                        systemImage: isSearching ? "clock" : "magnifyingglass",
                        hierarchy: .primary,
                        isFullWidth: false
                    ) {
                        runTextSearch()
                    }
                    .disabled(searchQuery.trimmingCharacters(in: .whitespaces).isEmpty || isSearching)
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

                if let error = searchError {
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
            if searchResults.isEmpty && !isSearching {
                Spacer()
                EmptyStateView(
                    icon: "magnifyingglass",
                    title: "Search for food",
                    subtitle: "Type a food name above or scan a barcode to find nutrition data."
                )
                Spacer()
            } else if isSearching {
                Spacer()
                ProgressView("Searching…")
                    .font(AppText.subheading)
                Spacer()
            } else {
                List(searchResults) { product in
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

    private func matchingLocalFoods(for query: String) -> [FoodProduct] {
        let normalized = query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        return FoodProduct.referenceFoods.filter { product in
            product.searchAliases.contains {
                $0.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).contains(normalized)
            }
        }
    }

    private func deduplicatedProducts(_ products: [FoodProduct]) -> [FoodProduct] {
        var seen = Set<String>()
        return products.filter { product in
            seen.insert(product.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()).inserted
        }
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Networking
    // ─────────────────────────────────────────────────────

    private func runTextSearch() {
        let query = searchQuery.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        searchError = nil
        isSearching = true
        searchResults = matchingLocalFoods(for: query)

        Task {
            defer { isSearching = false }
            guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let url = URL(string: "https://world.openfoodfacts.org/cgi/search.pl?search_terms=\(encoded)&search_simple=1&action=process&json=1&page_size=10")
            else {
                searchError = "Invalid search query."
                return
            }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let decoded = try JSONDecoder().decode(OFFSearchResponse.self, from: data)
                let remoteResults = decoded.products.compactMap { FoodProduct(from: $0) }
                searchResults = deduplicatedProducts(searchResults + remoteResults)
                if searchResults.isEmpty {
                    searchError = "No results found."
                }
            } catch {
                if searchResults.isEmpty {
                    searchError = "Search failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func fetchProduct(barcode: String) {
        searchError = nil
        isSearching = true
        activeTab = .search

        Task {
            defer { isSearching = false }
            guard let url = URL(string: "https://world.openfoodfacts.org/api/v0/product/\(barcode).json") else {
                searchError = "Invalid barcode."
                return
            }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let decoded = try JSONDecoder().decode(OFFProductResponse.self, from: data)
                if let raw = decoded.product, let product = FoodProduct(from: raw) {
                    fillFromProduct(product)
                } else {
                    searchError = "Product not found for barcode \(barcode)."
                }
            } catch {
                searchError = "Barcode lookup failed: \(error.localizedDescription)"
            }
        }
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – OpenFoodFacts response models
// ─────────────────────────────────────────────────────────

private struct OFFSearchResponse: Decodable {
    var products: [OFFProduct]
}

private struct OFFProductResponse: Decodable {
    var product: OFFProduct?
}

private struct OFFProduct: Decodable {
    var product_name: String?

    struct Nutriments: Decodable {
        var energyKcal100g: Double?
        var proteins100g:   Double?
        var carbohydrates100g: Double?
        var fat100g:        Double?

        enum CodingKeys: String, CodingKey {
            case energyKcal100g    = "energy-kcal_100g"
            case proteins100g      = "proteins_100g"
            case carbohydrates100g = "carbohydrates_100g"
            case fat100g           = "fat_100g"
        }
    }
    var nutriments: Nutriments?
}

// ─────────────────────────────────────────────────────────
// MARK: – Parsed food product (view model)
// ─────────────────────────────────────────────────────────

private struct FoodProduct: Identifiable {
    let id = UUID()
    var name:             String
    var caloriesPer100g:  Double?
    var proteinPer100g:   Double?
    var carbsPer100g:     Double?
    var fatPer100g:       Double?
    var referenceGrams:   Double = 100
    var source:           MealEntrySource = .search
    var sourceDescription: String = "Open Food Facts"
    var searchAliases:    [String] = []

    init?(from raw: OFFProduct) {
        name             = raw.product_name ?? ""
        caloriesPer100g  = raw.nutriments?.energyKcal100g.flatMap    { $0 > 0 ? $0 : nil }
        proteinPer100g   = raw.nutriments?.proteins100g.flatMap       { $0 > 0 ? $0 : nil }
        carbsPer100g     = raw.nutriments?.carbohydrates100g.flatMap  { $0 > 0 ? $0 : nil }
        fatPer100g       = raw.nutriments?.fat100g.flatMap            { $0 > 0 ? $0 : nil }
        source = .barcode
        sourceDescription = "Open Food Facts barcode or text search"
        searchAliases = [name]
        return  // always succeed — caller filters empty names in UI
    }

    init(
        name: String,
        caloriesPer100g: Double?,
        proteinPer100g: Double?,
        carbsPer100g: Double?,
        fatPer100g: Double?,
        aliases: [String]
    ) {
        self.name = name
        self.caloriesPer100g = caloriesPer100g
        self.proteinPer100g = proteinPer100g
        self.carbsPer100g = carbsPer100g
        self.fatPer100g = fatPer100g
        self.referenceGrams = 100
        self.source = .search
        self.sourceDescription = "Built-in reference food"
        self.searchAliases = aliases
    }

    static let referenceFoods: [FoodProduct] = [
        .init(name: "White Rice / אורז לבן", caloriesPer100g: 130, proteinPer100g: 2.4, carbsPer100g: 28.2, fatPer100g: 0.3, aliases: ["white rice", "rice", "אורז", "אורז לבן"]),
        .init(name: "Chicken Breast / חזה עוף", caloriesPer100g: 165, proteinPer100g: 31.0, carbsPer100g: 0, fatPer100g: 3.6, aliases: ["chicken breast", "chicken", "חזה עוף", "עוף"]),
        .init(name: "Greek Yogurt / יוגורט יווני", caloriesPer100g: 97, proteinPer100g: 9.0, carbsPer100g: 3.9, fatPer100g: 5.0, aliases: ["greek yogurt", "יוגורט יווני", "יוגורט"]),
        .init(name: "Oats / שיבולת שועל", caloriesPer100g: 389, proteinPer100g: 16.9, carbsPer100g: 66.3, fatPer100g: 6.9, aliases: ["oats", "oatmeal", "שיבולת שועל", "קוואקר"]),
        .init(name: "Egg / ביצה", caloriesPer100g: 143, proteinPer100g: 12.6, carbsPer100g: 0.7, fatPer100g: 9.5, aliases: ["egg", "eggs", "ביצה", "ביצים"])
    ]
}

private enum ParsedNutritionLanguageHint {
    case english
    case hebrew
    case mixed
}

private struct ParsedNutritionLabel {
    var referenceGrams: Double
    var calories: Double?
    var proteinG: Double?
    var carbsG: Double?
    var fatG: Double?
    var nameHint: String?
    var detectedLanguageHint: ParsedNutritionLanguageHint
}

private enum NutritionLabelParser {
    static func parse(_ rawText: String, fallbackReferenceGrams: Double) -> ParsedNutritionLabel? {
        let normalized = rawText
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: ",", with: ".")
            .lowercased()

        let lines = normalized
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else { return nil }

        let referenceGrams = detectReferenceGrams(in: lines) ?? fallbackReferenceGrams
        let calories = extractCalories(in: lines)
        let protein = extractValue(in: lines, keywords: ["protein", "proteins", "חלבון", "חלבונים"])
        let carbs = extractValue(in: lines, keywords: ["carbs", "carbohydrate", "carbohydrates", "פחמימה", "פחמימות"])
        let fat = extractValue(in: lines, keywords: ["fat", "total fat", "שומן", "שומנים"])

        guard calories != nil || protein != nil || carbs != nil || fat != nil else { return nil }

        let languageHint: ParsedNutritionLanguageHint
        if normalized.contains(where: { $0.unicodeScalars.contains(where: { $0.value >= 0x0590 && $0.value <= 0x05FF }) }) {
            languageHint = normalized.contains("protein") || normalized.contains("fat") ? .mixed : .hebrew
        } else {
            languageHint = .english
        }

        return ParsedNutritionLabel(
            referenceGrams: referenceGrams,
            calories: calories,
            proteinG: protein,
            carbsG: carbs,
            fatG: fat,
            nameHint: lines.first(where: { !$0.contains("calories") && !$0.contains("חלבון") && !$0.contains("פחמ") && !$0.contains("שומן") }),
            detectedLanguageHint: languageHint
        )
    }

    private static func detectReferenceGrams(in lines: [String]) -> Double? {
        if lines.contains(where: { $0.contains("100g") || $0.contains("100 g") || $0.contains("100גרם") || $0.contains("100 גרם") || $0.contains("ל-100") }) {
            return 100
        }

        let referenceKeywords = ["serving", "serving size", "מנה", "כמות למנה", "portion"]
        for line in lines where referenceKeywords.contains(where: { line.contains($0) }) {
            if let grams = extractGrams(from: line) {
                return grams
            }
        }
        return nil
    }

    private static func extractCalories(in lines: [String]) -> Double? {
        for line in lines where ["calories", "energy", "kcal", "קלוריות", "אנרגיה"].contains(where: { line.contains($0) }) {
            let values = extractNumbers(from: line)
            if line.contains("kcal"), let kcal = values.last(where: { $0 < 1200 }) {
                return kcal
            }
            if let single = values.first {
                return single
            }
        }
        return nil
    }

    private static func extractValue(in lines: [String], keywords: [String]) -> Double? {
        for line in lines where keywords.contains(where: { line.contains($0) }) {
            if let value = extractNumbers(from: line).first {
                return value
            }
        }
        return nil
    }

    private static func extractGrams(from line: String) -> Double? {
        let pattern = #"(\d+(?:\.\d+)?)\s*(?:g|gr|gram|grams|גרם)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, options: [], range: nsRange),
              let range = Range(match.range(at: 1), in: line) else { return nil }
        return Double(String(line[range]))
    }

    private static func extractNumbers(from line: String) -> [Double] {
        let pattern = #"\d+(?:\.\d+)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }
        let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
        return regex.matches(in: line, options: [], range: nsRange).compactMap { match in
            guard let range = Range(match.range(at: 0), in: line) else { return nil }
            return Double(String(line[range]))
        }
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – Barcode Scanner (iOS only)
// ─────────────────────────────────────────────────────────

#if os(iOS)
struct NutritionCameraSheet: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onCapture: (UIImage) -> Void

        init(onCapture: @escaping (UIImage) -> Void) {
            self.onCapture = onCapture
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                onCapture(image)
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

struct BarcodeScannerSheet: View {
    let onScan: (String) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            BarcodeScannerView(onScan: { barcode in
                onScan(barcode)
            })
            .ignoresSafeArea()
            .navigationTitle("Scan Barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct BarcodeScannerView: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    func makeUIViewController(context: Context) -> BarcodeScannerVC {
        let vc = BarcodeScannerVC()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: BarcodeScannerVC, context: Context) {}

    // ── Coordinator ──────────────────────────────────────

    final class Coordinator: NSObject, BarcodeScannerVCDelegate {
        let onScan: (String) -> Void
        private var didScan = false

        init(onScan: @escaping (String) -> Void) { self.onScan = onScan }

        func barcodeScannerVC(_ vc: BarcodeScannerVC, didScanBarcode barcode: String) {
            guard !didScan else { return }
            didScan = true
            DispatchQueue.main.async { self.onScan(barcode) }
        }
    }
}

// ── Protocol ─────────────────────────────────────────────

protocol BarcodeScannerVCDelegate: AnyObject {
    func barcodeScannerVC(_ vc: BarcodeScannerVC, didScanBarcode barcode: String)
}

// ── UIViewController wrapping AVCaptureSession ────────────

final class BarcodeScannerVC: UIViewController {
    weak var delegate: BarcodeScannerVCDelegate?

    private let session        = AVCaptureSession()
    private var previewLayer:    AVCaptureVideoPreviewLayer?
    private let metadataQueue  = DispatchQueue(label: "com.fittracker.barcode")

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        metadataQueue.async {
            if !self.session.isRunning { self.session.startRunning() }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        metadataQueue.async {
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    private func setupSession() {
        guard AVCaptureDevice.authorizationStatus(for: .video) != .denied else {
            showPermissionDenied()
            return
        }

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        guard let device = AVCaptureDevice.default(for: .video),
              let input  = try? AVCaptureDeviceInput(device: device) else { return }

        if session.canAddInput(input) { session.addInput(input) }

        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: metadataQueue)
            let supported: [AVMetadataObject.ObjectType] = [.ean8, .ean13, .upce, .code128, .qr]
            output.metadataObjectTypes = supported.filter { output.availableMetadataObjectTypes.contains($0) }
        }

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.insertSublayer(preview, at: 0)
        previewLayer = preview

        // Scanning guide overlay
        let guide = UIView()
        guide.layer.borderColor = UIColor.white.withAlphaComponent(0.8).cgColor
        guide.layer.borderWidth = 2
        guide.layer.cornerRadius = 8
        guide.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(guide)
        NSLayoutConstraint.activate([
            guide.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            guide.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            guide.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.7),
            guide.heightAnchor.constraint(equalToConstant: 120)
        ])
    }

    private func showPermissionDenied() {
        DispatchQueue.main.async {
            let label = UILabel()
            label.text = "Camera access is required to scan barcodes.\nPlease enable it in Settings."
            label.textColor = .white
            label.numberOfLines = 0
            label.textAlignment = .center
            label.translatesAutoresizingMaskIntoConstraints = false
            self.view.addSubview(label)
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: self.view.centerYAnchor),
                label.widthAnchor.constraint(equalTo: self.view.widthAnchor, constant: -40)
            ])
        }
    }
}

extension BarcodeScannerVC: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = obj.stringValue else { return }
        session.stopRunning()
        delegate?.barcodeScannerVC(self, didScanBarcode: value)
    }
}
#endif
