// swift-tools-version:5.9
//
// SPM-isolated wrapper for the Figma Code Connect Swift toolchain.
//
// Why a subdirectory: the FT2 repo root has FitTracker.xcodeproj.
// Putting Package.swift at root would tempt SPM to scan the whole
// FT2 source tree (including iOS-app-specific sources that depend
// on Xcode-only modules) and fail to compile.
//
// This subdirectory hosts ONLY the @figma/code-connect dependency,
// so `swift run --package-path .figma-cc-tools figma-swift connect
// publish ...` resolves cleanly without touching app sources.
//
// Used by:
//   - Local operator: `swift run --package-path .figma-cc-tools
//                     figma-swift connect publish --token "$FIGMA_ACCESS_TOKEN"`
//   - CI: .github/workflows/figma-code-connect-publish.yml
//
// Companion config: ../Figma.toml (file_key + include glob for
// FitTracker/**/*.figma.swift).
//
// Companion docs: ../docs/design-system/ios-code-connect-workflow.md

import PackageDescription

let package = Package(
    name: "FigmaCodeConnectTools",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/figma/code-connect", from: "1.0.0"),
    ],
    targets: [
        // Empty placeholder target — SPM requires at least one,
        // but we never build it. The figma-swift binary comes
        // from the dependency above.
        .target(name: "FigmaCodeConnectTools", path: "Sources"),
    ]
)
