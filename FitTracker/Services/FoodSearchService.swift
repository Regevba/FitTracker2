// Services/FoodSearchService.swift
// Audit UI-017: extracted from MealEntrySheet so the view doesn't own
// network/parse async logic. The view binds to `searchResults` /
// `isSearching` / `searchError` for display; the form text input
// (`searchQuery`) stays in the view because it's pure UI state.
//
// Owns the OpenFoodFacts (OFF) network calls + decoding + local-foods
// fallback. Pure-data Sendable inputs/outputs make this testable in
// isolation with URLProtocol mocks (when test infra is added).

import Foundation
import SwiftUI

@MainActor
final class FoodSearchService: ObservableObject {

    // ── Published state observed by the view ─────────────────
    @Published private(set) var searchResults: [FoodProduct] = []
    @Published private(set) var isSearching: Bool = false
    @Published var searchError: String?

    // ── Public API ───────────────────────────────────────────

    /// Run a text search: local-foods first (synchronous), then OFF for
    /// remote results. Updates published state for the view.
    func search(query rawQuery: String) async {
        let query = rawQuery.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        searchError = nil
        isSearching = true
        defer { isSearching = false }

        // Local matches first (instant feedback).
        searchResults = Self.matchingLocalFoods(for: query)

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
            searchResults = Self.deduplicatedProducts(searchResults + remoteResults)
            if searchResults.isEmpty {
                searchError = "No results found."
            }
        } catch {
            if searchResults.isEmpty {
                searchError = "Search failed: \(error.localizedDescription)"
            }
        }
    }

    /// Look up a single product by barcode. Returns the product on hit so
    /// the caller can `fillFromProduct(...)`; updates `searchError` on miss.
    func fetchProduct(barcode: String) async -> FoodProduct? {
        searchError = nil
        isSearching = true
        defer { isSearching = false }

        guard let url = URL(string: "https://world.openfoodfacts.org/api/v0/product/\(barcode).json") else {
            searchError = "Invalid barcode."
            return nil
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(OFFProductResponse.self, from: data)
            if let raw = decoded.product, let product = FoodProduct(from: raw) {
                return product
            }
            searchError = "Product not found for barcode \(barcode)."
            return nil
        } catch {
            searchError = "Barcode lookup failed: \(error.localizedDescription)"
            return nil
        }
    }

    /// Clear any prior results + errors. Called when the user switches tabs
    /// or closes the search affordance.
    func reset() {
        searchResults = []
        searchError = nil
        isSearching = false
    }

    // ── Pure helpers ─────────────────────────────────────────

    static func matchingLocalFoods(for query: String) -> [FoodProduct] {
        let normalized = query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        return FoodProduct.referenceFoods.filter { product in
            product.searchAliases.contains {
                $0.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).contains(normalized)
            }
        }
    }

    static func deduplicatedProducts(_ products: [FoodProduct]) -> [FoodProduct] {
        var seen = Set<String>()
        return products.filter { product in
            seen.insert(product.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()).inserted
        }
    }
}

// Note: OFF response models (OFFSearchResponse, OFFProductResponse,
// OFFProduct, OFFProduct.Nutriments) and FoodProduct live in
// MealEntrySheet.swift as module-internal types — no duplication here.
