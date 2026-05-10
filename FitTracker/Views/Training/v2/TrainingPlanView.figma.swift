// Figma Code Connect template — Training tab with active-plan badge
//
// Maps Figma node 973:5 in FitTracker-Design-System-Library
// (page 916:2 "Import Training Plan") to TrainingPlanView's
// surface displaying the "Following: My Strength Plan" active-
// plan badge added when an imported plan is the active source.
// Original frame 922:2 was converted to component 973:5 on
// 2026-05-10 because Code Connect publish requires the target
// node to be a COMPONENT or COMPONENT_SET.
//
// File: 0Ai7s3fCFqR5JXDW8JvgmD

#if canImport(Figma)
import Figma
import SwiftUI

struct TrainingPlanView_ActivePlanBadgeConnect: FigmaConnect {
    let component = TrainingPlanView.self
    let figmaNodeUrl: String =
        "https://www.figma.com/design/0Ai7s3fCFqR5JXDW8JvgmD/FitTracker-Design-System-Library?node-id=973-5"

    var body: some View {
        TrainingPlanView()
    }
}
#endif
