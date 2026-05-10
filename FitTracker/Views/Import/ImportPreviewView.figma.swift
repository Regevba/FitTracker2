// Figma Code Connect template — Day-Assignment Editor (preview mode)
//
// Maps Figma node 921:2 in FitTracker-Design-System-Library
// (page 916:2 "Import Training Plan") to ImportPreviewView's
// `.preview` mode.
//
// File: 0Ai7s3fCFqR5JXDW8JvgmD

#if canImport(Figma)
import Figma
import SwiftUI

struct ImportPreviewView_DayAssignmentConnect: FigmaConnect {
    let component = ImportPreviewView.self
    let figmaNodeUrl: String =
        "https://www.figma.com/design/0Ai7s3fCFqR5JXDW8JvgmD/FitTracker-Design-System-Library?node-id=921-2"

    var body: some View {
        // Illustrative example — operator may substitute a real
        // ImportedPlan + ImportOrchestrator at publish time.
        ImportPreviewView(
            plan: ImportedPlan.figmaPreviewSample,
            onConfirm: {},
            onCancel: {}
        )
    }
}
#endif
