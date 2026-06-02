// Views/Settings/v2/Screens/CustomProgramPlaceholders.swift
// C6 training-program-customization (2026-06-02)
//
// TEMPORARY placeholder view for T10 (CustomProgramEditorScreen). Keeps
// the T6 commit (CustomProgramListScreen) buildable while T10 lands.
//
// THIS FILE IS DELETED by the T10 commit — DO NOT add other content here.

import SwiftUI

struct CustomProgramEditorScreen: View {
    let program: CustomProgram
    var onSave: (CustomProgram) -> Void

    var body: some View {
        Text("CustomProgramEditorScreen placeholder — replaced in T10 commit")
            .padding()
    }
}
