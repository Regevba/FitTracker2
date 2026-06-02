// Views/Settings/v2/Screens/CustomProgramPlaceholders.swift
// C6 training-program-customization (2026-06-02)
//
// TEMPORARY placeholder views for T7 (NewProgramSheet) and T10
// (CustomProgramEditorScreen). Keep the T6 commit (CustomProgramListScreen)
// buildable while T7 + T10 land in their own commits.
//
// THIS FILE IS DELETED by T7 + T10 commits — DO NOT add other content here.

import SwiftUI

struct NewProgramSheet: View {
    var onSave: (CustomProgram) -> Void

    var body: some View {
        Text("NewProgramSheet placeholder — replaced in T7 commit")
            .padding()
    }
}

struct CustomProgramEditorScreen: View {
    let program: CustomProgram
    var onSave: (CustomProgram) -> Void

    var body: some View {
        Text("CustomProgramEditorScreen placeholder — replaced in T10 commit")
            .padding()
    }
}
