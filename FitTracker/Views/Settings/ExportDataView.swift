// Views/Settings/ExportDataView.swift
// GDPR Article 20 — Data portability. Export all user data as JSON.

import SwiftUI

struct ExportDataView: View {
    @EnvironmentObject private var exportService: DataExportService
    @State private var showShareSheet = false

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

                SettingsSectionCard(title: "Export Format", eyebrow: "JSON") {
                    SettingsSupportingText("Your data will be exported as a JSON file containing all your training logs, nutrition data, biometrics, profile, and preferences.\n\nNo data is sent to any server during export — everything stays on your device.")
                }

                if exportService.isExporting {
                    ProgressView("Generating export...")
                        .padding()
                } else {
                    Button {
                        Task {
                            await exportService.generateExport()
                            if exportService.exportURL != nil {
                                showShareSheet = true
                            }
                        }
                    } label: {
                        Label("Export as JSON", systemImage: "square.and.arrow.up")
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
