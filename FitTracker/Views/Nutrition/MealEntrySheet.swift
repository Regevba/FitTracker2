// Views/Nutrition/MealEntrySheet.swift
// Sheet presented when the user taps a meal slot.
// Three tabs: Manual entry, Template picker, Food search (text + barcode).

import SwiftUI
import AVFoundation
#if canImport(UIKit)
import UIKit
#endif

// ─────────────────────────────────────────────────────────
// MARK: – Tab enum
// ─────────────────────────────────────────────────────────

enum MealEntryTab: String, CaseIterable {
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

    @State private var activeTab: MealEntryTab = .manual

    // Manual tab fields
    @State private var name:     String = ""
    @State private var calories: String = ""
    @State private var proteinG: String = ""
    @State private var carbsG:   String = ""
    @State private var fatG:     String = ""

    // Template save confirmation
    @State private var savedTemplate = false

    // Search tab
    @State private var searchQuery: String = ""
    @State private var searchResults: [FoodProduct] = []
    @State private var isSearching: Bool = false
    @State private var searchError: String? = nil

    // Barcode scanner
    @State private var showScanner: Bool = false

    // ── Initialise fields from the binding on appear ──────
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab picker
                Picker("Tab", selection: $activeTab) {
                    ForEach(MealEntryTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Divider()

                // Tab content
                Group {
                    switch activeTab {
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
            }
        }
        #if os(iOS)
        .sheet(isPresented: $showScanner) {
            BarcodeScannerSheet { barcode in
                showScanner = false
                fetchProduct(barcode: barcode)
            }
        }
        #endif
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Manual Tab
    // ─────────────────────────────────────────────────────

    private var manualTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                Group {
                    manualField(label: "Meal name",       placeholder: "e.g. Chicken & Rice", text: $name)
                    manualField(label: "Calories (kcal)", placeholder: "e.g. 500",            text: $calories, isNumeric: true)
                    manualField(label: "Protein (g)",     placeholder: "e.g. 40",             text: $proteinG, isNumeric: true)
                    manualField(label: "Carbs (g)",       placeholder: "e.g. 60",             text: $carbsG,   isNumeric: true)
                    manualField(label: "Fat (g)",         placeholder: "e.g. 15",             text: $fatG,     isNumeric: true)
                }
                .padding(.horizontal, 16)

                // Buttons
                VStack(spacing: 12) {
                    // Save as Template
                    Button {
                        saveAsTemplate()
                    } label: {
                        HStack {
                            if savedTemplate {
                                Image(systemName: "checkmark")
                                    .foregroundColor(Color.status.success)
                                Text("Saved!")
                                    .foregroundColor(Color.status.success)
                            } else {
                                Image(systemName: "square.and.arrow.down")
                                Text("Save as Template")
                            }
                        }
                        .font(AppType.body)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(name.isEmpty)

                    // Log button
                    Button {
                        logMeal()
                    } label: {
                        Text("Log")
                            .font(AppType.body)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(name.isEmpty ? Color.secondary.opacity(0.2) : Color.accent.cyan, in: RoundedRectangle(cornerRadius: 12))
                            .foregroundColor(name.isEmpty ? .secondary : .white)
                    }
                    .disabled(name.isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
    }

    @ViewBuilder
    private func manualField(label: String, placeholder: String, text: Binding<String>, isNumeric: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(AppType.caption)
                .foregroundColor(.secondary)
            TextField(placeholder, text: text)
                .font(AppType.body)
                #if canImport(UIKit)
                .keyboardType(isNumeric ? .decimalPad : .default)
                #endif
                .padding(10)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
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
                            VStack(alignment: .leading, spacing: 4) {
                                Text(template.name)
                                    .font(AppType.body)
                                    .foregroundColor(.primary)
                                HStack(spacing: 8) {
                                    if let cal = template.calories {
                                        Text("\(Int(cal)) kcal")
                                            .font(AppType.caption)
                                            .foregroundColor(Color.accent.gold)
                                    }
                                    if let pro = template.proteinG {
                                        Text("\(Int(pro))g protein")
                                            .font(AppType.caption)
                                            .foregroundColor(Color.accent.cyan)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
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
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    TextField("Search food…", text: $searchQuery)
                        .font(AppType.body)
                        .padding(10)
                        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                        .submitLabel(.search)
                        .onSubmit { runTextSearch() }

                    Button {
                        runTextSearch()
                    } label: {
                        Image(systemName: isSearching ? "clock" : "magnifyingglass")
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.accent.cyan, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(searchQuery.trimmingCharacters(in: .whitespaces).isEmpty || isSearching)
                }

                #if os(iOS)
                Button {
                    showScanner = true
                } label: {
                    HStack {
                        Image(systemName: "barcode.viewfinder")
                        Text("Scan Barcode")
                    }
                    .font(AppType.body)
                    .foregroundColor(Color.accent.purple)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.accent.purple.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                }
                #endif

                if let error = searchError {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(Color.status.error)
                        Text(error)
                            .font(AppType.caption)
                            .foregroundColor(Color.status.error)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

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
                    .font(AppType.subheading)
                Spacer()
            } else {
                List(searchResults) { product in
                    Button {
                        fillFromProduct(product)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(product.name.isEmpty ? "Unknown product" : product.name)
                                .font(AppType.body)
                                .foregroundColor(.primary)
                            HStack(spacing: 8) {
                                if let cal = product.caloriesPer100g {
                                    Text("\(Int(cal)) kcal/100g")
                                        .font(AppType.caption)
                                        .foregroundColor(Color.accent.gold)
                                }
                                if let pro = product.proteinPer100g {
                                    Text("\(Int(pro))g prot")
                                        .font(AppType.caption)
                                        .foregroundColor(Color.accent.cyan)
                                }
                            }
                        }
                        .padding(.vertical, 4)
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
        activeTab = .manual
    }

    private func fillFromProduct(_ product: FoodProduct) {
        name     = product.name.isEmpty ? searchQuery : product.name
        calories = product.caloriesPer100g.map { formatNum($0) } ?? ""
        proteinG = product.proteinPer100g.map   { formatNum($0) } ?? ""
        carbsG   = product.carbsPer100g.map     { formatNum($0) } ?? ""
        fatG     = product.fatPer100g.map       { formatNum($0) } ?? ""
        activeTab = .manual
    }

    private func deleteTemplates(at offsets: IndexSet) {
        dataStore.mealTemplates.remove(atOffsets: offsets)
        Task { await dataStore.persistToDisk() }
    }

    private func formatNum(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Networking
    // ─────────────────────────────────────────────────────

    private func runTextSearch() {
        let query = searchQuery.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        searchError = nil
        isSearching = true
        searchResults = []

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
                searchResults = decoded.products.compactMap { FoodProduct(from: $0) }
                if searchResults.isEmpty {
                    searchError = "No results found."
                }
            } catch {
                searchError = "Search failed: \(error.localizedDescription)"
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

    init?(from raw: OFFProduct) {
        name             = raw.product_name ?? ""
        caloriesPer100g  = raw.nutriments?.energyKcal100g.flatMap    { $0 > 0 ? $0 : nil }
        proteinPer100g   = raw.nutriments?.proteins100g.flatMap       { $0 > 0 ? $0 : nil }
        carbsPer100g     = raw.nutriments?.carbohydrates100g.flatMap  { $0 > 0 ? $0 : nil }
        fatPer100g       = raw.nutriments?.fat100g.flatMap            { $0 > 0 ? $0 : nil }
        return  // always succeed — caller filters empty names in UI
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – Barcode Scanner (iOS only)
// ─────────────────────────────────────────────────────────

#if os(iOS)
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
