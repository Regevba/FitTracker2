// FitTracker/Views/AI/DismissReasonPicker.swift
// C5 ai-user-feedback-loop (2026-06-01)
//
// A confirmationDialog-based picker exposing 5 enum dismiss reasons + a free-text
// "Other" sheet (80-char cap). Surfaces ONLY in AIIntelligenceSheet's
// AIFeedbackView (sheet-only per PRD OQ-2 — home-card tap latency stays at 1 tap).
//
// Usage:
//   .modifier(DismissReasonPicker(isPresented: $show, onPick: { reason in ... }))
//
// On free-text "Other" pick, the reason value is "other:<verbatim user text>"
// to make the on-device introspection screen (Settings → AI Feedback) useful
// without leaking the free text to GA4 (PRD §"GDPR / Privacy").

import SwiftUI

enum DismissReasonKind: String, CaseIterable, Sendable {
    case notRelevant = "not_relevant"
    case alreadyAware = "already_aware"
    case disagree = "disagree"
    case repetitive = "repetitive"
    case other = "other"

    var displayCopy: String {
        switch self {
        case .notRelevant:  "Not relevant to me"
        case .alreadyAware: "Already aware of this"
        case .disagree:     "I disagree"
        case .repetitive:   "Too repetitive"
        case .other:        "Other (tell us more)"
        }
    }
}

struct DismissReasonPicker: ViewModifier {

    /// Maximum length of the "other" free-text reason. PRD §"GDPR / Privacy".
    static let freeTextMaxLength = 80

    @Binding var isPresented: Bool
    let onPick: (String) -> Void

    @State private var showOtherSheet = false
    @State private var otherText: String = ""

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                "Tell us why",
                isPresented: $isPresented,
                titleVisibility: .visible
            ) {
                ForEach(DismissReasonKind.allCases.filter { $0 != .other }, id: \.rawValue) { kind in
                    Button(kind.displayCopy) {
                        onPick(kind.rawValue)
                    }
                }
                Button(DismissReasonKind.other.displayCopy) {
                    showOtherSheet = true
                }
                Button("Cancel", role: .cancel) { }
            }
            .sheet(isPresented: $showOtherSheet) {
                otherSheet
            }
    }

    private var otherSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(
                        "Tell us more (optional, on-device only)",
                        text: $otherText,
                        axis: .vertical
                    )
                    .lineLimit(3, reservesSpace: true)
                    .onChange(of: otherText) { _, newValue in
                        if newValue.count > Self.freeTextMaxLength {
                            otherText = String(newValue.prefix(Self.freeTextMaxLength))
                        }
                    }
                } footer: {
                    Text("\(otherText.count)/\(Self.freeTextMaxLength) characters. Stored on this device only — never sent to our servers.")
                        .font(AppText.caption)
                        .foregroundStyle(AppColor.Text.secondary)
                }
            }
            .navigationTitle("Other reason")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") {
                        showOtherSheet = false
                        onPick(DismissReasonKind.other.rawValue)
                        otherText = ""
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        showOtherSheet = false
                        let payload = otherText.isEmpty
                            ? DismissReasonKind.other.rawValue
                            : "other:\(otherText)"
                        onPick(payload)
                        otherText = ""
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
