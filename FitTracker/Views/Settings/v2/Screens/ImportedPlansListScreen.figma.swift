// Figma Code Connect template — Imported Plans List screen
//
// Maps two screen variants in the FitTracker-Design-System-Library:
//   - 973:2 — populated (active plan selected) [converted from frame 919:2 → component 2026-05-10]
//   - 973:3 — empty state                       [converted from frame 920:2 → component 2026-05-10]
//
// Source-of-truth Figma file: 0Ai7s3fCFqR5JXDW8JvgmD (page 916:2 "Import Training Plan")
// Note: original frames 919:2 + 920:2 were converted to components
// 2026-05-10 because Code Connect publish requires the target node to
// be a COMPONENT or COMPONENT_SET, not a FRAME.
//
// Note: this file is parsed by the figma CLI's Swift parser. It is NOT
// part of the Xcode build target — operator excludes from compilation
// or relies on the figma CLI's `--exclude` glob.

#if canImport(Figma)
import Figma
import SwiftUI

struct ImportedPlansListScreen_PopulatedConnect: FigmaConnect {
    let component = ImportedPlansListScreen.self
    let figmaNodeUrl: String =
        "https://www.figma.com/design/0Ai7s3fCFqR5JXDW8JvgmD/FitTracker-Design-System-Library?node-id=973-2"

    var body: some View {
        ImportedPlansListScreen()
    }
}

struct ImportedPlansListScreen_EmptyConnect: FigmaConnect {
    let component = ImportedPlansListScreen.self
    let figmaNodeUrl: String =
        "https://www.figma.com/design/0Ai7s3fCFqR5JXDW8JvgmD/FitTracker-Design-System-Library?node-id=973-3"

    var body: some View {
        ImportedPlansListScreen()
    }
}
#endif
