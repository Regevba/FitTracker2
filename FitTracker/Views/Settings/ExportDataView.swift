// Views/Settings/ExportDataView.swift
// GDPR Article 20 — Data portability.
// JSON = full data (all training logs, nutrition, biometrics, profile, preferences).
// CSV  = daily logs flat (spreadsheet-friendly companion).

import SwiftUI

struct ExportDataView: View {
    @EnvironmentObject private var exportService: DataExportService
    @State private var showShareSheet = false
    @State private var selectedFormat: DataExportFormat = .json

    private var formatEyebrow: String {
        selectedFormat == .json ? "JSON" : "CSV"
    }

    private var formatDescription: String {
        switch selectedFormat {
        case .json:
            return "Your data will be exported as a JSON file containing all your training logs, nutrition data, biometrics, profile, and preferences.\n\nNo data is sent to any server during export — everything stays on your device."
        case .csv:
            return "Your data will be exported as a CSV file containing one row per day (date, phase, biometrics, nutrition totals, training summary). Best for spreadsheets and data analysis.\n\nNo data is sent to any server during export — everything stays on your device."
        }
    }

    private var exportButtonTitle: String {
        selectedFormat == .json ? "Export as JSON" : "Export as CSV"
    }

    var body: some View {
        SettingsDetailScaffold(
            title: "Export My Data",
            subtitle: "Download all your data in a portable format."
        ) {
            VStack(spacing: AppSpacing.medium) {
                SettingsSectionCard(title: "Your Data Summary", eyebrow: "Records") {
                    ForEach(exportService.recordCounts, id: \.label) { item in
                        SettingsValueRow(title: item.label, value: "\(item.count)")
                    }
                }

                SettingsSectionCard(title: "Export Format", eyebrow: formatEyebrow) {
                    Picker("Format", selection: $selectedFormat) {
                        Text("JSON").tag(DataExportFormat.json)
                        Text("CSV").tag(DataExportFormat.csv)
                    }
                    .pickerStyle(.segmented)
                    .padding(.bottom, AppSpacing.xSmall)
                    .accessibilityLabel("Export format")

                    SettingsSupportingText(formatDescription)
                }

                if exportService.isExporting {
                    ProgressView("Generating export...")
                        .padding()
                } else {
                    Button {
                        Task {
                            await exportService.generateExport(format: selectedFormat)
                            if exportService.exportURL != nil {
                                showShareSheet = true
                            }
                        }
                    } label: {
                        Label(exportButtonTitle, systemImage: "square.and.arrow.up")
                            .font(AppText.button)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.small)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppColor.Brand.primary)
                    .padding(.horizontal, AppSpacing.small)
                }

                if let error = exportService.exportError {
                    Text("Export failed: \(error)")
                        .font(AppText.caption)
                        .foregroundStyle(AppColor.Status.error)
                }
            }
        }
        .navigationTitle("Export My Data")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShareSheet) {
            if let url = exportService.exportURL {
                ShareSheet(items: [url])
            }
        }
        .analyticsScreen(AnalyticsScreen.exportData)
    }
}

// MARK: - Share Sheet (UIKit bridge)

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
