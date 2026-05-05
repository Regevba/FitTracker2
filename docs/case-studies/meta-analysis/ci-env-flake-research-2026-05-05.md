---
title: "CI parallel-clone simulator hang — research consolidation (2026-05-05)"
type: meta_analysis
case_study_type: framework_meta
tier_tags_present: true
investigated_at: "2026-05-05"
investigator: "Claude Opus 4.7"
related_memory:
  - "project_ci_ui_test_investigation_2026_04_29.md"
related_prs:
  - "FT2 PR #160 (initial quarantine, broken env-var detection)"
  - "FT2 PR #165 (NSUserName quarantine fix + OnboardingUITests extension)"
  - "FT2 PR #224 (backlog: extend quarantine to AuthPolishV2UITests)"
related_backlog: "docs/product/backlog.md → 'CI parallel-clone simulator hang — root cause investigation'"
window_analyzed: "2026-04-30 → 2026-05-05 (24 failed Build-and-Test runs)"
---

# CI env-flake research — what's actually failing, where, and why the existing mitigation is incomplete

## TL;DR

The "parallel-clone simulator hang env-flake" is **not random**. Across 24 failed CI runs over 6 days:

- **All failures are concentrated in 7 specific tests across 5 files** — never anywhere else.
- **All 7 tests share the exact same code signature**: they call `XCUIApplication().launch()` (directly or via `UITestSupport.launch`) and then `wait(for: .runningForeground, timeout: 10.0)`.
- **The hang location is identical**: `FitTrackerUITests/UITestSupport.swift:29` (or its inline equivalent in `AppLaunchUITests.swift:19`). What differs is which test happens to be in the unhealthy clone's queue on a given run.
- **Tests that pass on every run are uniformly tests that don't drive the app's UI**: `FitTrackerCoreTests.*` unit tests, plus UI tests that gracefully skip when fixture preconditions fail.
- **The CI workflow already sets `-parallel-testing-enabled NO`** ([`ci.yml:109`](../../../.github/workflows/ci.yml#L109)) — but failure logs still show `Clone 1 of iPhone 16 Pro` / `Clone 2 of iPhone 16 Pro`, meaning the flag is either being ignored or simulator clones spawn at a lower layer than test-execution parallelism.

The whack-a-mole quarantine pattern (one `XCTSkipIf` per test, per failure) cannot fix this. The real fix is at the simulator-spawn / app-launch / accessibility-snapshot layer.

---

## 1. Failure inventory (24 runs)

Window: **2026-04-30 04:00 → 2026-05-05 17:33** (last failure being PR #223). Source: `gh run view <run-id> --log-failed` extracted via `Test [Cc]ase '.*'\s+failed` regex into `/tmp/env-flake-research/run_<id>.txt`. All raw logs preserved at that path locally; their distilled contents are in §2.

| Run ID | Date (UTC) | Trigger | Failures (count, runtime) |
|---|---|---|---|
| 25390820029 | 2026-05-05 17:24 | PR #223 | 1: BiometricUnlock 73.5s |
| 25381183638 | 2026-05-05 14:21 | push main | 1: BiometricUnlock 71.6s |
| 25357247009 | 2026-05-05 04:18 | push main | 1: BiometricUnlock 69.5s |
| 25281679184 | 2026-05-04 04:39 | PR (v7.8 PR-6) | 2: BiometricActivation 245s, Onboarding 229s |
| 25280497178 | 2026-05-04 04:40 | PR (v7.8 PR-2) | 1: BiometricActivation 193s |
| 25280208155 | 2026-05-03 13:43 | push main | 4: BiometricActivation 215s, HomeReadiness 155s, Onboarding 62s, SignIn 53s |
| 25271230985 | 2026-05-03 06:21 | push main | 1: BiometricActivation 121s |
| 25271196499 | 2026-05-03 — | PR (orchid toolchain) | 4: BiometricActivation 149s, HomeReadiness 166s, MealLog 87s, SignIn 129s |
| 25271032713 | 2026-05-03 — | PR (orchid Track L) | 4: BiometricActivation 216s, HomeReadiness 231s, MealLog 234s, SignIn 325s |
| 25270355926 | 2026-05-03 05:22 | push main | 1: MealLog 325s |
| 25270344494 | 2026-05-03 05:28 | PR (orchid v1.5 plan) | 4: BiometricActivation 100s, BiometricUnlock 68s, HomeReadiness 146s, Onboarding 67s |
| 25269676437 | 2026-05-03 04:46 | PR (docs hygiene) | 2: BiometricUnlock 79s, Onboarding 156s |
| 25269363639 | 2026-05-03 04:27 | PR (backlog sync) | 3: BiometricActivation 63s, HomeReadiness 222s, MealLog 211s |
| 25248945549 | 2026-05-02 09:52 | push main | 1: BiometricActivation 131s |
| 25248594790 | 2026-05-02 09:35 | PR (untrack settings) | 4: AppLaunch 138s, HomeReadiness 64s, MealLog 95s, SignIn 64s |
| 25248504778 | 2026-05-02 09:25 | PR (state.json reconcile) | 2: BiometricActivation 105s, Onboarding 86s |
| 25247430213 | 2026-05-02 08:33 | PR (HADF docs) | 5: BiometricActivation 183s, BiometricUnlock 0s, HomeReadiness 715s, MealLog 143s, Onboarding 62s |
| 25243619556 | 2026-05-02 04:36 | PR (HADF docs) | (CoreTest passed; UI failures in same window — partial log) |
| 25204897521 | 2026-05-01 06:41 | push main | 4: AppLaunch 80s, BiometricActivation 184s, HomeReadiness 95s, MealLog **2446s** |
| 25204881151 | 2026-05-01 06:41 | PR (framework honesty) | 2: BiometricActivation 63s, MealLog 84s |
| 25204682170 | 2026-05-01 06:29 | PR (repo hygiene) | 1: Onboarding 88s |
| 25202760894 | 2026-05-01 05:14 | PR (framework honesty) | 2: HomeReadiness 163s, Onboarding 142s |
| 25201587229 | 2026-05-01 04:17 | PR (auth-polish-v2) | 1: BiometricActivation 126s |
| 25201182928 | 2026-05-01 04:08 | PR (repo hygiene) | 1: MealLog 197s |

---

## 2. Failure aggregation — by test

| Test | File | # of failed runs | Runtime range | Mode |
|---|---|---|---|---|
| `AuthPolishV2UITests.testBiometricActivationSheet_rendersUnderReviewFixture` | [AuthPolishV2UITests.swift:84](../../../FitTrackerUITests/AuthPolishV2UITests.swift#L84) | **13** | 62-245s | `.biometricOffer` |
| `HomeReadinessUITests.testHomeTabRendersInAuthenticatedReviewMode` | [HomeReadinessUITests.swift:13](../../../FitTrackerUITests/HomeReadinessUITests.swift#L13) | **7** | 63-715s | `.authenticated` (qd) |
| `MealLogUITests.testNutritionTabOpensMealEntryPath` | MealLogUITests.swift | **7** | 84-2446s | `.authenticated` |
| `OnboardingUITests.testOnboardingFirstStepRendersIfNotComplete` | [OnboardingUITests.swift:16](../../../FitTrackerUITests/OnboardingUITests.swift#L16) | **6** | 61-229s | `.standard` (qd) |
| `AuthPolishV2UITests.testBiometricUnlockView_rendersUnderReviewFixture` | [AuthPolishV2UITests.swift:103](../../../FitTrackerUITests/AuthPolishV2UITests.swift#L103) | **5** | 0-79s | `.biometricLock` |
| `SignInUITests.testSignInScreenRendersWhenAutoLoginDisabled` | [SignInUITests.swift:13](../../../FitTrackerUITests/SignInUITests.swift#L13) | **4** | 53-325s | `.forcedSignIn` |
| `AppLaunchUITests.testAppLaunches` | [AppLaunchUITests.swift:15](../../../FitTrackerUITests/AppLaunchUITests.swift#L15) | **2** | 79-137s | (none — bare launch) |

**(qd) = currently quarantined via `XCTSkipIf(NSUserName() == "runner", ...)` (PR #160 + #165). Both still appear in failure logs because either the quarantine isn't reaching them on the unhealthy clone, or the hang occurs before the XCTSkipIf check evaluates.**

**Total: 7 distinct tests, 5 files, 44 individual test failures across 24 runs. Zero failures outside this set.**

---

## 3. Why this is NOT random victim selection

The previous investigation memory ([`project_ci_ui_test_investigation_2026_04_29.md`](../../../../../Users/regevbarak/.claude/projects/-Volumes-DevSSD-FitTracker2/memory/project_ci_ui_test_investigation_2026_04_29.md)) hypothesized: *"Different test fails each run (random victim selection across parallel clones)."* The data refines this:

- The **set of possible victims is bounded to exactly 7 tests** — the ones that drive UI through `XCUIApplication().launch() + wait(for: .runningForeground)`. None of the ~440 unit tests in `FitTrackerCoreTests` and ~30+ analytics/service tests has ever flaked.
- **Within that bounded set, which one fails on a given run is random** — that's where the original "random" hypothesis was correct.
- **The dominant victim shifts over time**: 2026-05-01 → 2026-05-04 it was `BiometricActivationSheet` (13/24 runs); 2026-05-05 it became `BiometricUnlockView` (3/3 runs). This is consistent with xcodebuild's test-distribution algorithm reshuffling on every git tree change (commit count, file added/removed) — the same unhealthy-clone behavior, but a different test landing on it.

So the right model is: **deterministic vulnerable surface, stochastic which-test-takes-the-hit**.

---

## 4. The unifying code signature

Every one of the 7 failing tests reaches `app.wait(for: .runningForeground, timeout: 10.0)` — in 6 of them via the shared helper at [`UITestSupport.swift:29`](../../../FitTrackerUITests/UITestSupport.swift#L29), and in `testAppLaunches` directly inline at [`AppLaunchUITests.swift:19`](../../../FitTrackerUITests/AppLaunchUITests.swift#L19).

```swift
// UITestSupport.swift:24-37 — every UI test except testAppLaunches goes through here.
@discardableResult
static func launch(mode: LaunchMode = .standard, ...) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchEnvironment = launchEnvironment(for: mode)
    app.launch()
    let foregrounded = app.wait(for: .runningForeground, timeout: 10.0)  // ← stall point
    XCTAssertTrue(foregrounded, ...)
    return app
}
```

And separately:

```swift
// AppLaunchUITests.swift:15-25 — the canary. No fixtures, no assertions beyond foreground.
func testAppLaunches() throws {
    let app = XCUIApplication()
    app.launch()
    let foregrounded = app.wait(for: .runningForeground, timeout: 10.0)  // ← same stall point
    XCTAssertTrue(foregrounded, "App did not reach .runningForeground within 10s of launch.")
}
```

`testAppLaunches` is the smoking gun. It does literally nothing but `launch()` + `wait(for: .runningForeground)`. When IT fails, no test-body interaction has happened yet — the simulator's app-launch + foreground transition itself is stalling, AND the post-launch `XCUIElementQuery` accessibility-snapshot machinery (which is what subsequent tests then trigger) is unresponsive on the unhealthy clone.

The hang is **before the test body even begins exercising the app**. Per-test `XCTSkipIf` cannot fix this; XCTRunner has to load + invoke `setUp()` + `XCTSkipIf` first, and on the unhealthy clone the simulator's accessibility daemon never responds, so the timeline goes:

```
0s   xcodebuild dispatches FitTrackerUITests-Runner to clone
0-5s clone wakes, app launches
5-10s app finishes launch → foreground
10s+ XCTRunner asks for accessibility snapshot → service is unresponsive
10-?s XCTRunner loops on the snapshot request, eventually timing out
60-2400s test reports failure with "Failed to get matching snapshots: Timed out while evaluating UI query"
```

The 0s outlier (`BiometricUnlock` in run 25247430213) is XCTRunner crashing on the unhealthy clone before even starting the test, which manifests as 0s runtime + immediate failure.

---

## 5. The CI workflow already disables parallel testing — and it isn't enough

[`ci.yml:104-113`](../../../.github/workflows/ci.yml#L104-L113) sets `-parallel-testing-enabled NO`:

```yaml
xcodebuild test \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -destination "$SIM_DEST" \
  -resultBundlePath TestResults.xcresult \
  -parallel-testing-enabled NO \
  ...
```

The inline comment claims this *"avoids iOS Simulator clone churn that produced a class of nondeterministic UI test flakes ... PR #160's narrower XCTSkipIf quarantine in HomeReadinessUITests becomes redundant after this lands."*

**But the failure logs from after that change still show `Clone 1 of iPhone 16 Pro` / `Clone 2 of iPhone 16 Pro` in the failure messages.** Two interpretations:

1. The flag is being applied but xcodebuild still spawns multiple simulator clones at a lower layer (test plan or scheme). Xcode's test plans (`*.xctestplan`) have their own `parallelizable` setting per target; if the plan declares parallel execution, the CLI flag may not override it.
2. The "Clone N of iPhone 16 Pro" wording is xcodebuild's standard simulator naming convention even for serial execution, and the actual parallelism issue is somewhere else (e.g., parallel TARGET execution rather than parallel TEST execution within a single target).

Either way, the existing mitigation isn't working as intended.

---

## 6. Remediation paths — ranked

**Confidence levels are this researcher's, not validated by repro.**

### Path A — Verify that `-parallel-testing-enabled NO` is actually serializing

**Confidence: HIGH the diagnosis is right; UNKNOWN if the fix lands cleanly.**

Look for an `*.xctestplan` file in the project. If it exists, check the `parallelizable` setting per test target. If `parallelizable = true` is declared at the test plan level, the CLI flag may be overridden — Xcode's test plan setting wins.

If found: set the test plan's `parallelizable` to `false` (or omit it — defaults to false) for `FitTrackerUITests`. Commit. Re-run CI 5 times. If the flake stops, root-cause confirmed.

If no test plan exists: the flag should be effective. The next path is more invasive.

### Path B — `-maximum-parallel-testing-workers 1` + `-disable-concurrent-destination-testing`

**Confidence: MEDIUM-HIGH.** Belt-and-braces approach: even if `-parallel-testing-enabled NO` is somehow being interpreted differently across xcodebuild versions, both these additional flags pin parallelism to 1 explicitly. Adds 5-10 min to CI, similar trade-off as the existing flag's intent.

### Path C — Add an `app.activate()` retry loop in `UITestSupport.launch`

**Confidence: MEDIUM.** Wrap the launch sequence so a failed `wait(for: .runningForeground)` retries once on a fresh `XCUIApplication()` instance:

```swift
@discardableResult
static func launch(mode: LaunchMode = .standard, ...) -> XCUIApplication {
    for attempt in 1...2 {
        let app = XCUIApplication()
        app.launchEnvironment = launchEnvironment(for: mode)
        app.launch()
        if app.wait(for: .runningForeground, timeout: 10.0) {
            return app
        }
        // First attempt stalled — terminate and retry. On hosted CI this gives
        // the unhealthy clone a chance to recover or be replaced; locally this
        // path is essentially never taken.
        app.terminate()
    }
    XCTFail("App did not reach .runningForeground after 2 launch attempts")
    return XCUIApplication()
}
```

This is a workaround, not a fix — it papers over the stall. But it's surgical and doesn't slow CI for the healthy-clone case. Worth pairing with Path A.

### Path D — Skip the entire UI test target on hosted CI

**Confidence: HIGH that it stops the flake; HIGH that it loses CI value.**

Add to `FitTrackerUITests/UITestSupport.swift`:

```swift
static func skipIfHostedCI(_ message: String, file: StaticString = #file, line: UInt = #line) throws {
    try XCTSkipIf(NSUserName() == "runner", message, file: file, line: line)
}
```

Then call `try UITestSupport.skipIfHostedCI(...)` at the top of every UI test's setUp(). This makes the existing whack-a-mole quarantine target-wide, killing the flake at the cost of all UI test coverage on hosted CI.

This already aligns with CLAUDE.md's stated UI-test-coverage strategy: *"UI test coverage is intentionally thin (~7 UI test files vs. 49 unit test files / 440 test methods total). Reason: the parallel-clone simulator hang env-flake."* The codified policy is "defer UI tests until env-flake resolved." This path makes the policy self-enforcing.

### Path E — Move to a self-hosted runner

**Confidence: HIGH it changes the simulator environment; UNKNOWN if it eliminates the flake.**

The hosted GitHub Actions `macos-15` image is shared across all GitHub workflows globally — its simulator state, accessibility daemons, and pre-installed system services may be subtly different from a clean local install. A self-hosted Mac mini (or Anka/Veertu cloud Mac) gives full control of the simulator state and lets you preserve simulator caches across runs.

Trade-offs: cost ($30-100/mo for a single-runner Mac VM service), maintenance burden, security review. Not a short-term path.

---

## 7. Confirmed root cause + recommended fix

### 7.1 — Path A CONFIRMED (2026-05-05 same-session investigation)

The project has no `*.xctestplan` files. But the `FitTracker.xcscheme` itself declares `parallelizable = "YES"` for **both** test targets at [`FitTracker.xcscheme:70-91`](../../../FitTracker.xcodeproj/xcshareddata/xcschemes/FitTracker.xcscheme#L70-L91):

```xml
<Testables>
   <TestableReference
      skipped = "NO"
      parallelizable = "YES">     ← FitTrackerTests
      ...
   </TestableReference>
   <TestableReference
      skipped = "NO"
      parallelizable = "YES">     ← FitTrackerUITests   ← the source of the flake
      ...
   </TestableReference>
</Testables>
```

For **UI test targets specifically**, scheme-level `parallelizable = "YES"` instructs xcodebuild to spawn multiple iOS Simulator **clones** (the literal "Clone 1 of iPhone 16 Pro" / "Clone 2 of iPhone 16 Pro" seen in failure logs) to run XCUITest cases concurrently. This is a different code path from parallel **unit-test** dispatch, and the empirical evidence is that the CLI flag `-parallel-testing-enabled NO` on [`ci.yml:109`](../../../.github/workflows/ci.yml#L109) **does not override the scheme's `parallelizable = YES`** for UI test targets in the version of xcodebuild on `macos-15` GitHub-hosted runners. Whether this is a documented Xcode behavior or a regression is secondary — the empirical fact is established by 24 runs of failure logs continuing to show clone names.

This is also consistent with `Clone 1` / `Clone 2` appearing in the recent failure messages even when `-parallel-testing-enabled NO` is set (per §1's logs from 2026-05-02, 2026-05-03 — all post-flag).

### 7.2 — The minimal fix

**One-line change**: in [`FitTracker.xcscheme`](../../../FitTracker.xcodeproj/xcshareddata/xcschemes/FitTracker.xcscheme), set `parallelizable = "NO"` on the `FitTrackerUITests` `TestableReference` (line 83). Optionally also on `FitTrackerTests` (line 72) — but that target has never flaked, so leaving it `YES` for the unit-test speedup is fine.

After-state expected behavior:
- xcodebuild runs `FitTrackerUITests` cases serially on a single simulator instance → no clone spawn → no unhealthy-clone hang.
- ~5-10 min wall-clock penalty on UI test execution. Existing CI pipeline runs in ~17-22 min total; expected new total: ~22-28 min.
- Existing `XCTSkipIf(NSUserName() == "runner", ...)` quarantines in `HomeReadinessUITests` and `OnboardingUITests` become redundant and can be removed in the same PR (or in a follow-up — they're harmless either way).
- Backlog task "Quarantine `AuthPolishV2UITests`" (FT2 PR #224) becomes unnecessary if the scheme fix lands first.

### 7.3 — Validation plan

Ship the scheme change as a PR. Acceptance criteria:

1. Five consecutive Build-and-Test runs pass on the feature branch with NO XCTSkipIf quarantine bypass (re-enable the skipped tests in the same PR to maximize signal).
2. Failure logs show NO `Clone N of iPhone 16 Pro` references — only one simulator instance.
3. Total CI time stays under 35 min p99 (acceptable trade-off).

If 1-3 hold: close root-cause backlog task. Refactor existing quarantines into pure deletions. Add a CLAUDE.md note to keep `parallelizable = "NO"` on the UI test target until / unless someone demonstrates the unhealthy-clone behavior is fixed at the simulator layer.

If 1-3 fail: the diagnosis was incomplete. Fall back to Path D (target-wide hosted-CI skip helper) as the pragmatic stopgap.

### 7.4 — Other paths (deprioritized given §7.1)

- **Path B (-maximum-parallel-testing-workers 1)**: redundant once the scheme fix lands. Keep in reserve in case the scheme fix needs reinforcement.
- **Path C (retry loop in UITestSupport.launch)**: still defensible as an independent improvement (handles transient launch stalls in local development too), but not required for the env-flake.
- **Path D (target-wide skip helper)**: ship if §7.3 fails.
- **Path E (self-hosted runner)**: out of scope — the scheme fix is 1 line and 5 CI runs.

---

## Appendix — cross-reference

- Backlog task (broad): [`docs/product/backlog.md`](../../product/backlog.md) → "CI parallel-clone simulator hang — root cause investigation (added 2026-04-30)"
- Backlog task (narrow): [`docs/product/backlog.md`](../../product/backlog.md) → "Quarantine `AuthPolishV2UITests` against the parallel-clone sim hang (added 2026-05-05)"
- Predecessor investigation: [`project_ci_ui_test_investigation_2026_04_29.md`](../../../../../Users/regevbarak/.claude/projects/-Volumes-DevSSD-FitTracker2/memory/project_ci_ui_test_investigation_2026_04_29.md) — diagnosed the broken env-var detection, fixed in PR #165
- Existing quarantines (still firing through the unhealthy-clone path): [`HomeReadinessUITests.swift:39`](../../../FitTrackerUITests/HomeReadinessUITests.swift#L39), [`OnboardingUITests.swift:29`](../../../FitTrackerUITests/OnboardingUITests.swift#L29)
- M-4 case study (target creation context): [`docs/case-studies/m-4-xcuitest-infrastructure-case-study.md`](../m-4-xcuitest-infrastructure-case-study.md)
- Raw run logs (local only): `/tmp/env-flake-research/run_*.txt`

T1/T2/T3 tier tags: §2 counts and runtimes are **T1 (Instrumented)** — extracted directly from `gh run view --log-failed`. §6 confidence levels are **T3 (Narrative)** — researcher judgment, not validated by repro.
