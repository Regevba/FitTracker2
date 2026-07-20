# iOS Snapshot Testing (FIT-152 / T4)

> **Visual-regression coverage for the v2 SwiftUI surfaces.** Baselines are
> recorded in the CI simulator, committed as PNGs, and verified **advisory-first**
> so a snapshot diff surfaces on the PR without blocking a merge.

Harness: `pointfreeco/swift-snapshot-testing` (SPM). Tests:
[`FitTrackerTests/SnapshotTests/`](../../FitTrackerTests/SnapshotTests/).

## Why baselines are recorded in CI, not locally

Snapshot reference PNGs are **simulator-specific**. The local dev sim (Xcode 26 /
iPhone 17 Pro / iOS 26) and the CI sim (iPhone 15/16 / iOS ~18) render text and
anti-aliasing differently, so a locally-recorded baseline fails in CI and vice
versa. The baselines are therefore recorded **in the CI environment** and
committed from there, and only ever verified in that same environment.

## The three modes (`SNAPSHOT_MODE`)

[`SnapshotTestSupport.swift`](../../FitTrackerTests/SnapshotTests/SnapshotTestSupport.swift)
gates every snapshot test on the `SNAPSHOT_MODE` env var:

| `SNAPSHOT_MODE` | Behavior | Where |
|---|---|---|
| _unset_ (default) | tests **skip** (`XCTSkip`) | the required `Build and Test` job — so it never reddens without baselines |
| `record` | writes/overwrites reference PNGs (and reports "failed" by design) | `ios-snapshot-record.yml` (dispatch-only) |
| `verify` | compares against committed PNGs at 0.98 precision | `ios-snapshot-verify.yml` (advisory) |

## Workflow: adding or refreshing baselines

1. **Record** — dispatch the recorder:
   ```bash
   gh workflow run ios-snapshot-record.yml --repo Regevba/FitTracker2
   ```
   It runs the snapshot tests with `SNAPSHOT_MODE=record` on a `macos-15` runner
   and uploads the generated `__Snapshots__` dirs as the `snapshot-baselines`
   artifact (~40 min).
2. **Commit** — download + place the PNGs, then commit:
   ```bash
   gh run download <run-id> --repo Regevba/FitTracker2 -n snapshot-baselines -D /tmp/snap
   rsync -a /tmp/snap/ FitTrackerTests/SnapshotTests/   # __Snapshots__/ lands next to the tests
   git add FitTrackerTests/SnapshotTests/__Snapshots__ && git commit
   ```
3. **Verify** — [`ios-snapshot-verify.yml`](../../.github/workflows/ios-snapshot-verify.yml)
   runs `SNAPSHOT_MODE=verify` on every PR that touches `FitTracker/**` or the
   snapshot tests, comparing against the committed baselines. It is **advisory**
   (not a required check), so a diff shows up + uploads a `snapshot-verify-diffs`
   artifact but does not block the merge.

## Why verify is advisory-first

Snapshot tests are a documented **high-flake surface** (CLAUDE.md "UI test
coverage strategy" — the parallel-clone simulator hang). Wiring verify as a
required check on day one would let cross-OS anti-aliasing noise or an
env-object construction hiccup block unrelated merges. So verify runs advisory
during a calibration window; it is promoted to a required status check only
after it demonstrates stability across a run of PRs — the same advisory→enforced
discipline the framework applies to every new gate.

## Coverage

**Baselined (as of 2026-07-20 — 11 canonical CI baselines):** the 4 shared
design-system components (`AppProgressRing`, `AppPickerChip`,
`AppSegmentedControl`, `AppMetricColumn`) + 4 v2 screens (Stats / Nutrition /
Training / Settings) + 3 auth views (SignIn / BiometricUnlock /
OnboardingWelcome). Every recorded PNG is **visually inspected before commit** —
a blank or crashed render is still a PNG, so "the recorder wrote a file" is not
proof the surface rendered (this caught the blank `WelcomeView` below).

**Pending recipe fixes (hard-skipped so no blank baseline is ever committed):**
- `testHomeScreenV2` — needs a stubbed `AIOrchestrator` (no factory: init takes
  engineClient + foundationModel + pcc + snapshot/goalMode closures).
- `testWelcomeAuthView` — renders **BLANK** in CI; `WelcomeView` needs a
  `NavigationStack` wrapper / animation-settle (SignInView renders correctly
  *because* it is NavigationStack-wrapped).

When a screen changes intentionally, re-record (step 1) and commit the new
baseline in the same PR.
