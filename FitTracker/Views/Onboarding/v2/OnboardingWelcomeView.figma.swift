// Figma Code Connect template — Onboarding v2 Welcome screen
//
// Maps Figma node 974:2 in FitTracker-Design-System-Library
// (page 25:6 "Onboarding" → "I3.2 Onboarding v2 (PRD-Aligned)"
// section 688:2 → "Screen 1 — Welcome", originally frame 688:6 —
// converted to component 974:2 on 2026-05-10 because Code Connect
// publish requires the target node to be a COMPONENT or
// COMPONENT_SET. The original section 688:2 was the wrong target
// (Code Connect can't map to a SECTION; it needs to be a single
// COMPONENT representing the Welcome screen).
//
// File: 0Ai7s3fCFqR5JXDW8JvgmD

#if canImport(Figma)
import Figma
import SwiftUI

struct OnboardingWelcomeView_V2Connect: FigmaConnect {
    let component = OnboardingWelcomeView.self
    let figmaNodeUrl: String =
        "https://www.figma.com/design/0Ai7s3fCFqR5JXDW8JvgmD/FitTracker-Design-System-Library?node-id=974-2"

    var body: some View {
        OnboardingWelcomeView()
    }
}
#endif
