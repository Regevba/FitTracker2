import SwiftUI

struct ImportSourcePickerView: View {
    @StateObject private var orchestrator = ImportOrchestrator()
    @State private var pasteText = ""
    @State private var showPasteField = false
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppGradient.screenBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: AppSpacing.medium) {
                        if showPasteField {
                            pasteFieldView
                        } else {
                            sourceOptions
                        }

                        statusView
                    }
                    .padding(.horizontal, AppSpacing.medium)
                    .padding(.vertical, AppSpacing.small)
                }
            }
            .navigationTitle("Import Training Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var sourceOptions: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.small) {
            sourceCard(icon: "doc.text", title: "Paste Text", subtitle: "AI chat, notes, email") {
                showPasteField = true
            }
            sourceCard(icon: "folder", title: "Choose File", subtitle: "CSV or JSON file") {
                // File picker — future implementation
            }
        }
    }

    private func sourceCard(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: AppSpacing.xSmall) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundStyle(AppColor.Accent.primary)
                    .frame(height: 44)
                Text(title)
                    .font(AppText.callout)
                    .foregroundStyle(AppColor.Text.primary)
                Text(subtitle)
                    .font(AppText.caption)
                    .foregroundStyle(AppColor.Text.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(AppSpacing.medium)
            .background(AppColor.Surface.primary, in: RoundedRectangle(cornerRadius: AppRadius.card))
        }
        .buttonStyle(.plain)
    }

    private var pasteFieldView: some View {
        VStack(spacing: AppSpacing.small) {
            TextEditor(text: $pasteText)
                .font(AppText.body)
                .frame(minHeight: 200)
                .padding(AppSpacing.xSmall)
                .background(AppColor.Surface.primary, in: RoundedRectangle(cornerRadius: AppRadius.medium))
                .overlay(
                    Group {
                        if pasteText.isEmpty {
                            Text("Paste your training plan here...")
                                .font(AppText.body)
                                .foregroundStyle(AppColor.Text.tertiary)
                                .padding(AppSpacing.small)
                        }
                    }, alignment: .topLeading
                )

            Button {
                Task { await orchestrator.importFromText(pasteText) }
            } label: {
                Text("Parse & Import")
                    .font(AppText.button)
                    .foregroundStyle(AppColor.Text.inversePrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: AppSize.ctaHeight)
                    .background(AppColor.Accent.primary, in: RoundedRectangle(cornerRadius: AppRadius.button))
            }
            .buttonStyle(.plain)
            .disabled(pasteText.isEmpty)
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch orchestrator.state {
        case .idle:
            EmptyView()
        case .parsing, .mapping:
            ProgressView("Processing...")
                .padding()
        case .preview(let plan):
            VStack(spacing: AppSpacing.small) {
                Text("Found \(plan.days.flatMap(\.exercises).count) exercises")
                    .font(AppText.callout)
                    .foregroundStyle(AppColor.Text.primary)
                Button {
                    orchestrator.confirmImport()
                    dismiss()
                } label: {
                    Text("Confirm & Import")
                        .font(AppText.button)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: AppSize.ctaHeight)
                        .background(AppColor.Status.success, in: RoundedRectangle(cornerRadius: AppRadius.button))
                }
                .buttonStyle(.plain)
            }
        case .success:
            Label("Plan imported!", systemImage: "checkmark.circle.fill")
                .font(AppText.callout)
                .foregroundStyle(AppColor.Status.success)
        case .error(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(AppText.caption)
                .foregroundStyle(AppColor.Status.error)
                .padding()
        }
    }
}
