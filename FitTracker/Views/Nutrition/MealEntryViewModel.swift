// FitTracker/Views/Nutrition/MealEntryViewModel.swift
// State + business logic for MealEntrySheet. Holds the 16 mutable
// fields the sheet exposes to its 4 tabs and owns the bilingual label
// parser + Vision OCR + photo import flows.
// Extracted from MealEntrySheet.swift in Audit M-2c (UI-004 decomposition).

import SwiftUI
import Vision
#if canImport(PhotosUI)
import PhotosUI
#endif
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class MealEntryViewModel: ObservableObject {
    // ── Tab selection ─────────────────────────────────────
    @Published var activeTab: MealEntryTab = .smart

    // ── Manual tab fields ─────────────────────────────────
    @Published var name: String = ""
    @Published var calories: String = ""
    @Published var proteinG: String = ""
    @Published var carbsG: String = ""
    @Published var fatG: String = ""
    @Published var servingGrams: String = ""
    @Published var referenceGrams: String = "100"
    @Published var sourceDetails: String = ""

    // ── Smart label parsing ───────────────────────────────
    @Published var rawLabelText: String = ""
    @Published var parsedLabel: ParsedNutritionLabel?
    @Published var smartStatus: String?
    @Published var smartError: String?

    // ── Template save confirmation ────────────────────────
    @Published var savedTemplate: Bool = false

    // ── Search tab ────────────────────────────────────────
    @Published var searchQuery: String = ""

    // ── Barcode + camera state ────────────────────────────
    @Published var showScanner: Bool = false
    #if canImport(UIKit)
    @Published var showCameraCapture: Bool = false
    @Published var selectedImagePreview: UIImage?
    #endif
    #if canImport(PhotosUI)
    @Published var selectedPhotoItem: PhotosPickerItem?
    #endif

    // The view injects this in onAppear so the VM can record the entry's
    // input source without holding a Binding<MealEntry>. Default no-op.
    var onSourceChange: (MealEntrySource) -> Void = { _ in }

    // ─────────────────────────────────────────────────────
    // MARK: – Helpers
    // ─────────────────────────────────────────────────────

    // formatMealValue is a free helper in Tabs/MealEntrySharedComponents.swift —
    // both the VM and the parsed-metric tile call the same function.

    func loadFromEntry(_ entry: MealEntry) {
        name     = entry.name
        calories = entry.calories.map { String($0) } ?? ""
        proteinG = entry.proteinG.map  { String($0) } ?? ""
        carbsG   = entry.carbsG.map    { String($0) } ?? ""
        fatG     = entry.fatG.map      { String($0) } ?? ""
        servingGrams = entry.servingGrams.map { formatMealValue($0) } ?? ""
        referenceGrams = entry.labelReferenceGrams.map { formatMealValue($0) } ?? "100"
        sourceDetails = entry.sourceDetails
        rawLabelText = entry.source == .photoLabel ? entry.sourceDetails : ""
    }

    func writeBack(into entry: inout MealEntry) {
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
    }

    func confirmTemplateSaved() {
        savedTemplate = true
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run { self.savedTemplate = false }
        }
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Template + product fill
    // ─────────────────────────────────────────────────────

    func fillFromTemplate(_ template: MealTemplate) {
        name     = template.name
        calories = template.calories.map { formatMealValue($0) } ?? ""
        proteinG = template.proteinG.map  { formatMealValue($0) } ?? ""
        carbsG   = template.carbsG.map    { formatMealValue($0) } ?? ""
        fatG     = template.fatG.map      { formatMealValue($0) } ?? ""
        sourceDetails = "Saved template"
        activeTab = .manual
        onSourceChange(.template)
    }

    func fillFromProduct(_ product: FoodProduct) {
        name     = product.name.isEmpty ? searchQuery : product.name
        calories = product.caloriesPer100g.map { formatMealValue($0) } ?? ""
        proteinG = product.proteinPer100g.map   { formatMealValue($0) } ?? ""
        carbsG   = product.carbsPer100g.map     { formatMealValue($0) } ?? ""
        fatG     = product.fatPer100g.map       { formatMealValue($0) } ?? ""
        referenceGrams = formatMealValue(product.referenceGrams)
        servingGrams = servingGrams.isEmpty ? formatMealValue(product.referenceGrams) : servingGrams
        sourceDetails = product.sourceDescription
        activeTab = .manual
        onSourceChange(product.source)
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Smart label parsing
    // ─────────────────────────────────────────────────────

    func parseSmartLabel() {
        smartError = nil
        smartStatus = nil

        guard let parsed = NutritionLabelParser.parse(rawLabelText, fallbackReferenceGrams: Double(referenceGrams) ?? 100) else {
            smartError = "I couldn’t parse the label yet. Try a clearer photo or paste the nutrition lines."
            return
        }

        parsedLabel = parsed
        referenceGrams = formatMealValue(parsed.referenceGrams)
        applyParsedLabel(parsed)
        sourceDetails = rawLabelText
        smartStatus = parsed.detectedLanguageHint == .hebrew
            ? "Hebrew nutrition text parsed successfully."
            : "Nutrition label applied successfully."
        activeTab = .manual
        onSourceChange(.photoLabel)
    }

    private func applyParsedLabel(_ parsed: ParsedNutritionLabel) {
        let consumedGrams = Double(servingGrams) ?? parsed.referenceGrams
        servingGrams = formatMealValue(consumedGrams)
        let scale = max(consumedGrams, 1) / max(parsed.referenceGrams, 1)

        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            name = parsed.nameHint ?? name
        }

        calories = parsed.calories.map { formatMealValue($0 * scale) } ?? calories
        proteinG = parsed.proteinG.map { formatMealValue($0 * scale) } ?? proteinG
        carbsG = parsed.carbsG.map { formatMealValue($0 * scale) } ?? carbsG
        fatG = parsed.fatG.map { formatMealValue($0 * scale) } ?? fatG
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Vision OCR + photo import (iOS only)
    // ─────────────────────────────────────────────────────

    #if canImport(UIKit)
    func processNutritionImage(_ image: UIImage) {
        selectedImagePreview = image
        smartError = nil
        smartStatus = "Reading nutrition label…"

        guard let cgImage = image.cgImage else {
            smartStatus = nil
            smartError = "That image could not be processed."
            return
        }

        let request = VNRecognizeTextRequest { [weak self] request, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let error {
                    self.smartStatus = nil
                    self.smartError = "Photo scan failed: \(error.localizedDescription)"
                    return
                }

                let lines = (request.results as? [VNRecognizedTextObservation])?
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n") ?? ""

                self.rawLabelText = lines
                self.parseSmartLabel()
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

        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
            } catch {
                await MainActor.run {
                    self?.smartStatus = nil
                    self?.smartError = "Photo scan failed: \(error.localizedDescription)"
                }
            }
        }
    }

    #if canImport(PhotosUI)
    func loadSelectedPhoto(_ item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                smartError = "That photo could not be opened."
                return
            }
            processNutritionImage(image)
        } catch {
            smartError = "Photo import failed: \(error.localizedDescription)"
        }
    }
    #endif
    #endif
}
