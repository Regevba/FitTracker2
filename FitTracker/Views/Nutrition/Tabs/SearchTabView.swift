// FitTracker/Views/Nutrition/Tabs/SearchTabView.swift
// Search tab — Open Food Facts text search + iOS barcode scan.
// Extracted from MealEntrySheet.swift in Audit M-2b (UI-004 decomposition).

import SwiftUI

struct SearchTabView: View {
    @ObservedObject var vm: MealEntryViewModel
    @ObservedObject var foodSearch: FoodSearchService
    let onTextSearch: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: AppSpacing.xxSmall) {
                HStack(spacing: AppSpacing.xxSmall) {
                    AppInputShell {
                        TextField("Search food…", text: $vm.searchQuery)
                            .font(AppText.body)
                            .foregroundStyle(AppColor.Text.primary)
                            .submitLabel(.search)
                            .onSubmit { onTextSearch() }
                    }

                    AppButton(
                        title: "",
                        systemImage: foodSearch.isSearching ? "clock" : "magnifyingglass",
                        hierarchy: .primary,
                        isFullWidth: false
                    ) {
                        onTextSearch()
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
}
