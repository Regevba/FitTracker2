# M-4 — XCUITest Infrastructure (TEST-025)

> **Audit finding**: TEST-025 — "No XCUITest files — zero UI integration test coverage"
> **Recommended fix**: "Add FitTrackerUITests: sign-in, onboarding, home readiness card, nutrition meal-log flow"
> **Type**: Multi-session feature — case study tracking ON from start (per the M-3/M-1/M-2 precedent)
> **Predecessor plan**: `docs/superpowers/plans/2026-04-19-m2-mealentrysheet-decomposition.md`
> **Date**: 2026-04-19

## Goal

Stand up a working XCUITest harness for FitTracker so the app's critical user journeys can be exercised end-to-end, and ship the audit-recommended happy-path coverage (sign-in, onboarding, home readiness, meal log). After M-4, the project has a green XCUITest target with at least 4 happy-path tests; the audit-recommended baseline is met. CI integration is **out of scope** — local-only for now (CI billing block continues; CI wiring becomes follow-up work once billing restored).

## Source structure (what exists today)

| What | State |
|---|---|
| `FitTrackerTests/` target (unit tests) | Exists, ~30+ test files, 9 known environmental failures (EncryptionService + KeychainHelper, pre-existing) |
| `FitTrackerUITests/` target | **Does not exist** |
| XCUITest files in repo | **Zero** |
| pbxproj target count | 2 (FitTracker app + FitTrackerTests unit-test bundle) |
| Existing test target pattern | `B50000010000000000000001 /* FitTrackerTests */` — productType `com.apple.product-type.bundle.unit-test`, dependency on FitTracker app target, `TEST_HOST = "$(BUILT_PRODUCTS_DIR)/FitTracker.app/FitTracker"`, `BUNDLE_LOADER = "$(TEST_HOST)"` |

Adding a UI-test target requires a similar but distinct PBXNativeTarget (productType `com.apple.product-type.bundle.ui-testing`) with a different set of build settings (`TEST_TARGET_NAME=FitTracker`, no `TEST_HOST`/`BUNDLE_LOADER` since UI tests inject via `XCUIApplication()`).

## Phases

### Phase M-4a — Target setup + smoke test (this sprint)

The hard, risky phase. Add a `FitTrackerUITests/` directory and a single bootstrap test (`AppLaunchUITests.swift`) that just launches the app and asserts the root view appears. This proves the harness works before investing in real test coverage.

**Pbxproj additions** (8 new entries across 6 sections):

| Section | New entries | IDs (proposed) |
|---|---|---|
| `PBXFileReference` | `FitTrackerUITests.xctest` (product) + `AppLaunchUITests.swift` (source) | `UI200000000000000000XT01` (xctest), `UI200000000000000000UT01` (.swift) |
| `PBXBuildFile` | `AppLaunchUITests.swift in Sources` | `UI100000000000000000UT01` |
| `PBXSourcesBuildPhase` | New Sources phase for UI test target | `UI300000000000000000UT01` |
| `PBXFrameworksBuildPhase` | New Frameworks phase for UI test target | `UI300000000000000000UT02` |
| `PBXResourcesBuildPhase` | New Resources phase for UI test target | `UI300000000000000000UT03` |
| `PBXGroup` | New `FitTrackerUITests` group children + add to top-level mainGroup | `UI400000000000000000UT01` |
| `PBXNativeTarget` | New `FitTrackerUITests` target (productType `com.apple.product-type.bundle.ui-testing`) | `UI500000000000000000UT01` |
| `PBXTargetDependency` + `PBXContainerItemProxy` | UI tests depend on FitTracker app target | `UI600000000000000000UT01`, `UI700000000000000000UT01` |
| `XCBuildConfiguration` | Debug + Release configs with `TEST_TARGET_NAME = FitTracker`, `PRODUCT_BUNDLE_IDENTIFIER = com.fittracker.regev.uitests` | `UI800000000000000000UT01` (Debug), `UI800000000000000000UT02` (Release) |
| `XCConfigurationList` | Build configuration list pointing at the 2 configs | `UI900000000000000000UT01` |
| Update `PBXProject.targets` | Add `UI500000000000000000UT01` to existing array | edit existing |
| Update `PBXProject.attributes.TargetAttributes` | Add `TestTargetID = A50000010000000000000001` for UI test target | edit existing |
| Update `Products` group | Add `FitTrackerUITests.xctest` reference | edit existing |
| Update top-level mainGroup | Add `FitTrackerUITests` group | edit existing |

**New file**: `FitTrackerUITests/AppLaunchUITests.swift`

```swift
import XCTest

final class AppLaunchUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAppLaunches() throws {
        let app = XCUIApplication()
        app.launch()

        // Wait for the launch sequence to settle. Detection target is
        // intentionally permissive: any one of the post-launch root surfaces.
        let predicate = NSPredicate(format: "exists == true")
        let homeTab = app.tabBars.buttons["Home"]
        let signInButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Sign In'"))
        let onboardingNext = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Continue' OR label CONTAINS[c] 'Next'"))

        let appearedExpectation = XCTNSPredicateExpectation(predicate: predicate, object: homeTab)
        let signInExpectation = XCTNSPredicateExpectation(predicate: predicate, object: signInButton.element)
        let onboardingExpectation = XCTNSPredicateExpectation(predicate: predicate, object: onboardingNext.element)

        let result = XCTWaiter.wait(for: [appearedExpectation, signInExpectation, onboardingExpectation], timeout: 10.0)
        XCTAssertNotEqual(result, .timedOut, "App did not reach a known root surface within 10s")
    }
}
```

**Risk**: HIGH. project.pbxproj surgery for a new PBXNativeTarget is the largest single edit M-series has done. Mitigations:
1. Build verify locally before commit
2. Run the UI test locally to confirm the harness works
3. If pbxproj corrupts, `git restore FitTracker.xcodeproj/project.pbxproj` reverts cleanly
4. Single PR — easy to revert

**Out of M-4a**:
- Real user-flow tests (those are M-4b/c)
- CI integration (out of scope for entire M-4)
- Test fixtures, mock services, or launch arguments for deterministic UI state

### Phase M-4b — First happy-path test: home readiness card

Add `HomeUITests.swift` that:
- Launches the app
- Bypasses sign-in/onboarding by detecting them and either passing through (if a test fixture user is configured) or skipping with a documented reason
- Asserts the home tab loads
- Asserts the readiness card appears with expected accessibility identifiers

Risk: low once M-4a's harness works. Real risk is the app's existing accessibility identifiers — many UI elements may not have `accessibilityIdentifier` set, requiring view source touches to make them queryable. This is captured as a known cost.

### Phase M-4c — Remaining happy-path tests

Add per-flow files:
- `SignInUITests.swift` — sign-in screen renders + tappable provider buttons
- `OnboardingUITests.swift` — first-launch onboarding flow reaches completion
- `MealLogUITests.swift` — open Meal Entry sheet, switch tabs, type meal name + macros, tap Log

Each is one XCTestCase + 1-3 test methods. Will probably surface accessibility identifier gaps that need adding to the production views — those edits stay minimal and labeled `// Audit M-4c: accessibility identifier for XCUITest`.

Risk: low-medium. The risk is production-code creep if accessibility additions snowball. Boundary: only add identifiers, no behavioural/visual changes.

### Phase M-4d — Case study + monitoring entry

Same pattern as M-1d/M-2d: case study, monitoring entry, TEST-025 closure in audit-findings.json, memory update. Concurrent tracking.

## Out of scope for entire M-4

- **CI integration** — running XCUITests in GitHub Actions. The user's CI billing block makes this moot until billing is restored. Captured as follow-up.
- **Snapshot testing** — different audit finding (TEST-026, already closed via PR #105).
- **Test fixtures or mocked services** — tests run against the real app launch state. Determinism limits acknowledged in case study.
- **Coverage gates** — no minimum-coverage enforcement; audit just asks for the 4 named flows to exist.

## Success criteria

- After Phase M-4a: `xcodebuild test -scheme FitTracker` discovers the new UI test target; `AppLaunchUITests.testAppLaunches` passes locally.
- After Phase M-4b: home readiness card test passes (with at most 2-3 accessibility identifier additions to production views).
- After Phase M-4c: 3 additional UI test files exist, each with at least 1 passing happy-path test.
- After Phase M-4d: case study + monitoring entry shipped, TEST-025 closed, audit total: 183/185 (98.9%).

## Estimated effort

| Phase | Effort | Risk |
|---|---|---|
| M-4a (this PR — risky) | 60-90 min | HIGH (pbxproj surgery for new target) |
| M-4b | 30-60 min | low |
| M-4c | 60-90 min | low-medium |
| M-4d | 30 min | low |
| **Total** | **~3-4 hours** | |

## Rollback plan

Each phase ships as its own PR. M-4a rollback = revert PR; pbxproj returns to its 2-target state. If M-4a's test target builds but discovery fails (Xcode quirk), the test files stay but the target gets disabled in scheme. Worst case: M-4 stays at "infrastructure attempted" without coverage; documented as a deferred follow-up.

## Methodology notes

This is the first M-series phase that **adds a build target** rather than restructuring source files. The risk profile differs from M-1/M-2:
- M-1/M-2 risk = source compilation + visibility + behaviour preservation (mostly low)
- M-4 risk = pbxproj target wiring (high) + Xcode test discovery quirks (medium) + production accessibility identifier additions (creep risk)

If M-4a goes smoothly, M-4b/c/d are straightforward. If M-4a hits an unrecoverable pbxproj issue, the documented fallback is to ship the test source files in a `FitTrackerUITests/` directory (not in the build) + a follow-up plan that asks the user to add the target via Xcode UI. Lossy but recoverable.

The pattern of **bootstrap test first, real coverage later** mirrors how production XCUITest setups work in practice — "make the harness compile" is its own deliverable, distinct from "make tests pass for X feature".

---

## Addendum — M-4a attempt 1 (2026-04-20, aborted + rolled back)

**Status**: M-4a was attempted on branch `feature/m4a-xcuitest-target-setup` (now deleted). Rolled back per the "if anything fails, stop and rollback" instruction the user gave at the start of execution. Main is unaffected.

### What worked

The pbxproj surgery completed without corruption. 12 edits across 11 sections produced a working configuration:

| Section | New entries | IDs used |
|---|---|---|
| `PBXBuildFile` | `AppLaunchUITests.swift in Sources` | `UI100000000000000000UT01` |
| `PBXContainerItemProxy` | dependency proxy → FitTracker app target | `UI600000000000000000UT01` |
| `PBXFileReference` | `FitTrackerUITests.xctest` (product) + `AppLaunchUITests.swift` (source) | `UI200000000000000000XT01`, `UI200000000000000000UT01` |
| `PBXGroup` | new `FitTrackerUITests` group + added to mainGroup + Products | `UI400000000000000000UT01` |
| `PBXFrameworksBuildPhase` | empty Frameworks phase for UI target | `UI300000000000000000UT02` |
| `PBXNativeTarget` | `FitTrackerUITests` target (productType `com.apple.product-type.bundle.ui-testing`) | `UI500000000000000000UT01` |
| `PBXProject` | added to `targets` + `TargetAttributes` (with `TestTargetID = A50000010000000000000001`) | edits to existing |
| `PBXResourcesBuildPhase` | empty Resources phase | `UI300000000000000000UT03` |
| `PBXSourcesBuildPhase` | Sources phase containing the bootstrap test | `UI300000000000000000UT01` |
| `PBXTargetDependency` | UI target depends on FitTracker app | `UI700000000000000000UT01` |
| `XCBuildConfiguration` | Debug + Release configs (`TEST_TARGET_NAME = FitTracker`, `PRODUCT_BUNDLE_IDENTIFIER = com.fittracker.regev.uitests`, no `TEST_HOST`/`BUNDLE_LOADER`) | `UI800000000000000000UT01`, `UI800000000000000000UT02` |
| `XCConfigurationList` | configuration list pointing at the 2 configs | `UI900000000000000000UT01` |

**Plus 2 scheme edits** in `FitTracker.xcscheme`:

- New `<BuildActionEntry>` for the UI test target
- New `<TestableReference>` in `<Testables>`

Both `xcodebuild build` and `xcodebuild build-for-testing` succeeded. The output bundle `FitTrackerUITests-Runner.app/PlugIns/FitTrackerUITests.xctest/FitTrackerUITests` was produced. The harness IS working.

### What broke

The bootstrap test `AppLaunchUITests.testAppLaunches()` ran end-to-end (~20s, app launched, test executed) but the assertion failed.

**Root cause**: the test code used:

```swift
let result = XCTWaiter.wait(for: [homeExpectation, signInExpectation, onboardingExpectation], timeout: 10.0)
XCTAssertNotEqual(result, .timedOut, ...)
```

This is wrong. `XCTWaiter.wait(for:timeout:)` requires **ALL** expectations to fulfill, not ANY. Since the app only ever lands on one root surface at a time (home OR sign-in OR onboarding), at most one of the three expectations can ever fulfill within the timeout. The other two always time out. Result: always `.timedOut`, always fails.

**This is a test logic bug, not an infrastructure bug.**

### Lesson for the next M-4a attempt

Use a simpler post-launch assertion that doesn't require predicate matching against unknown launch state:

```swift
func testAppLaunches() throws {
    let app = XCUIApplication()
    app.launch()

    // Just confirm the app reached foreground state. Predicate-on-content
    // assertions belong in M-4b/c where we own the launch fixture state.
    let foregrounded = app.wait(for: .runningForeground, timeout: 10.0)
    XCTAssertTrue(foregrounded, "App did not reach .runningForeground within 10s")
}
```

This decouples "is the harness working?" from "does the app's first screen match an expected layout?" — the latter is M-4b/c's job.

### Recovery

- Branch `feature/m4a-xcuitest-target-setup` deleted
- All pbxproj + scheme edits reverted via `git restore`
- `FitTrackerUITests/` directory removed (was untracked)
- Main builds green, no residue from the attempt

### What this means for M-4 (status: FROZEN)

- M-4 stays at "planned" state. PR #131 (this plan) remains the canonical reference + execution map.
- The pbxproj recipe (12 edits + 2 scheme edits) above is now known-good. Next M-4a attempt copies it.
- The `XCTWaiter` gotcha is captured here so the next attempt doesn't trip on it.
- Audit total stays at **182/185 (98.4%)** until M-4 retries.
- Status frozen pending user direction.
