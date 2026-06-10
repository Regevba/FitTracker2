# T4 — Swift Snapshot Testing (Phase A scaffold + spec)

> **Status:** Phase A (execution-ready, **2 operator gates open**). 2026-06-10.
> **Spec source:** [test-coverage master plan §4 T4](../../master-plan/test-coverage-master-plan-2026-05-13.md) (RICE 28.8).
> **Why a spec, not a PR:** T4 cannot ship unilaterally — it adds a new external
> dependency (an operator decision) and commits **baseline reference images** that
> bless the *current* UI as canonical (risk #310 in the test-coverage plan
> explicitly requires operator review of every initial baseline). This doc makes
> T4 execution-ready and surfaces exactly the two go/no-go points.

## What T4 delivers

Single-shot deterministic UI regression coverage for the View layer (~130 files,
currently untested except via thin XCUITest). A snapshot test renders a view to an
image and diffs it against a committed reference; a pixel-diff fails the PR. Unlike
XCUITest it has **no simulator-clone hang** (the documented M-4 / parallel-clone
flake) — it renders once, deterministically.

## The two operator gates

### Gate 1 — adopt the SPM dependency
`pointfreeco/swift-snapshot-testing` (the de-facto standard; the test-coverage
external study picked it over Muter/others). Adding it:
- adds one `XCRemoteSwiftPackageReference` to `FitTracker.xcodeproj` (alongside the
  existing firebase / GoogleSignIn / supabase packages) + a `SnapshotTesting`
  product dependency on the **FitTrackerTests** target only (not the app target);
- adds ~one package to `Package.resolved`;
- increases test-target build time modestly (SPM resolution + image rendering).

**Decision needed:** approve adding this test-only dependency.

### Gate 2 — bless the baselines (risk #310)
The first run of each snapshot test **records** a reference image. Those references
become the canonical "correct" UI. If the current UI has a latent visual bug, the
baseline enshrines it. So per risk #310, **every initial baseline must be reviewed
by the operator** (ideally paired with `/ux pre-merge-review`) before it's
committed. This is a ~30-45 min visual-inspection session at the simulator.

**Decision needed:** schedule the baseline-review session; until then no baselines
are committed and the gate stays inert (tests `XCTSkip`).

## Target surface (10 screens)

Per the spec: the 6 v2 screens + 4 auth views — the highest-drift, most-load-bearing
surfaces.

| # | Screen | Source |
|---|---|---|
| 1 | Home v2 | `FitTracker/Views/Main/v2/MainScreenView.swift` |
| 2 | Stats v2 | `FitTracker/Views/Stats/v2/` |
| 3 | Settings v2 | `FitTracker/Views/Settings/v2/` |
| 4 | Nutrition v2 | `FitTracker/Views/Nutrition/v2/` |
| 5 | Training v2 | `FitTracker/Views/Training/v2/` |
| 6 | Readiness v2 | `FitTracker/Views/.../ReadinessCard` (or the readiness surface) |
| 7-10 | 4 auth views | Onboarding v2 auth flow (`FitTracker/Views/Onboarding/v2/`) |

Each gets snapshots at: light + dark mode × a representative Dynamic Type size
(default + AX3) — so the same harness also exercises the L353 Dynamic Type concern
visually.

## Harness shape (ready to drop in once Gate 1 clears)

```swift
// FitTrackerTests/Snapshots/V2ScreenSnapshotTests.swift
import XCTest
import SnapshotTesting
@testable import FitTracker

@MainActor
final class V2ScreenSnapshotTests: XCTestCase {
    // Flip to true ONLY in a reviewed baseline-recording session (Gate 2), never on main.
    private let recording = false

    func testHomeV2_lightAndDark() throws {
        try XCTSkipUnless(baselinesBlessed, "T4 baselines pending operator review — see spec Gate 2")
        let view = MainScreenView(/* seeded with a deterministic preview fixture */)
        assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone13)), record: recording)
        assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone13), traits: .init(userInterfaceStyle: .dark)), record: recording)
    }
    // … one method per screen × {light, dark} × {default, AX3}
}
```

Key discipline:
- **Deterministic fixtures only.** Every screen is seeded from a fixed preview
  fixture (no live HealthKit / network / clock) so the render is reproducible.
- **`record = false` on main, always.** Recording happens only in the reviewed
  Gate-2 session; the committed baselines are the contract.
- **`XCTSkipUnless(baselinesBlessed)`** keeps CI green until Gate 2 completes, so
  the dependency + harness can land first without a red gate.

## CI wiring (after Gate 2)

Add the snapshot tests to the existing `Build and Test` job (no new workflow). They
run serially with the rest of FitTrackerTests — no parallel-clone exposure. A
failing diff uploads the (reference, actual, diff) triplet as a CI artifact for
review, the standard swift-snapshot-testing flow.

## Sequence

1. **Gate 1 ✅** → I add the SPM dependency + the harness file (skipped) + this
   runbook. One PR, CI green (tests skip).
2. **Gate 2 ✅** → operator baseline-review session: flip `recording`, render the
   10 screens, visually inspect each in the diff viewer, commit the blessed
   baselines, flip `baselinesBlessed = true`. The gate goes live.
3. Thereafter every PR touching those screens gets a pixel-diff gate.

## Phase E / framework compliance
- No framework gates added; this is application-layer test infra (Theme H).
- The dependency lives on the test target only — zero app-binary impact.
- Mirrors the T3/T5/T10 discipline: deterministic, device-free where possible,
  honest about what's gated.
