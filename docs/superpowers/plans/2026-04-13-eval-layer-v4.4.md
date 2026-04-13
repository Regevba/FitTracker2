# Eval Layer + Framework v4.4 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement 20 deterministic eval cases across 3 test files that test AI output quality (not just code correctness), add ai_quality_metrics to case study monitoring, and advance the framework to v4.4 with Phase 5 (Eval) in the Skill Internal Lifecycle.

**Architecture:** 3 XCTest files in a new `FitTrackerTests/EvalTests/` directory. Each file tests a different quality surface: formula golden cases, AI copy heuristics, and hybrid tier behavior. Framework docs updated to v4.4. Case study monitoring schema extended with ai_quality_metrics.

**Tech Stack:** Swift/XCTest, JSON (shared layer), Markdown (docs)

**Case Study:** `eval-layer-v4.4-2026-04` (opened in case-study-monitoring.json)

---

## Task 1: Create ReadinessFormulaEvals (7 golden I/O tests)

**Files:**
- Create: `FitTrackerTests/EvalTests/ReadinessFormulaEvals.swift`

- [ ] **Step 1: Write the 7 eval tests**

The tests use the same `makeLogs()` and `makeMetrics()` helpers as `ReadinessEngineTests.swift`. Since they're in a different file, redefine the helpers locally (DRY across test files is less important than test file independence).

Each test creates a specific biometric profile, calls `ReadinessEngine.compute()`, and asserts the score falls within an expected range + the recommendation matches the expected tier.

Eval cases:
1. `testEval_healthyAthleteBaseline` — HRV 55, RHR 58, 8h sleep (17.5% deep, 22.5% REM), 10 days steady training, goalMode .maintain → score 75-85, rec .fullIntensity
2. `testEval_sleepDeprived` — HRV 50, RHR 65, 4h sleep no stages, 10 days logs → score 35-50, rec .lightOnly
3. `testEval_overreaching` — HRV 40, RHR 72 (+7 above 65 baseline), high-load training, 28 days → score 25-40, rec .lightOnly or .restDay
4. `testEval_fullRecoveryDay` — HRV 70, RHR 55, 9h sleep, no training 3 days → score 85-100, rec .pushHard
5. `testEval_fatLossGoalShift` — same healthy profile, compare .fatLoss vs .maintain → delta 3-8 pts
6. `testEval_layer0ColdStart` — only HRV 45, sleep 7h, zero logs → non-nil, score 40-70, confidence .low
7. `testEval_contradictorySignals` — HRV excellent (70) + sleep terrible (3.5h) → score 45-65, rec .moderate

- [ ] **Step 2: Add to Xcode test target (pbxproj)**

Add `ReadinessFormulaEvals.swift` to the FitTrackerTests Sources build phase in `project.pbxproj`. Follow the same pattern as `ReadinessEngineTests.swift` (PBXBuildFile, PBXFileReference, group, Sources).

- [ ] **Step 3: Build + run evals**

Run: `xcodebuild test -scheme FitTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' -derivedDataPath .build/DerivedData -only-testing:FitTrackerTests/ReadinessFormulaEvals`
Expected: 7/7 pass

- [ ] **Step 4: Commit**

```bash
git add FitTrackerTests/EvalTests/ReadinessFormulaEvals.swift FitTracker.xcodeproj/project.pbxproj
git commit -m "test(evals): 7 golden I/O formula evals for ReadinessEngine"
```

---

## Task 2: Create AIOutputQualityEvals (7 heuristic checks)

**Files:**
- Create: `FitTrackerTests/EvalTests/AIOutputQualityEvals.swift`

- [ ] **Step 1: Write the 7 eval tests**

1. `testEval_signalCoverage100Percent` — call `AIRecommendation.localFallback(for:snapshot:)` for all 4 segments with a populated snapshot. Collect all signal strings. For each, call the `humanReadableSignal()` mapping logic. Assert zero signals hit the default "New insight available" fallback.

2. `testEval_noRawKeysInUI` — for every mapped signal output, assert it contains zero underscore characters.

3. `testEval_copyLengthBounds` — for every mapped signal output, assert length >= 15 and <= 80.

4. `testEval_toneMatchesReadiness` — build a ReadinessResult with score 20 (low). Get recommendation copy from `HomeRecommendationProvider.recommendation(readinessResult:isRestDay:streakDays:)`. Assert copy contains at least one of ["rest", "recover", "lighter", "easy", "body needs"]. Repeat with score 90 (high), assert contains at least one of ["great", "push", "strong", "go", "shape"].

5. `testEval_confidenceBadgeText` — assert `ReadinessConfidence.low.rawValue == "low"`, `.medium.rawValue == "medium"`, `.high.rawValue == "high"`.

6. `testEval_recommendationCopyCompleteness` — for every `TrainingRecommendation` case, build a ReadinessResult with a score that maps to that recommendation, pass to `HomeRecommendationProvider.recommendation(readinessResult:isRestDay:false:streakDays:0)`. Assert title and subtitle are both non-empty.

7. `testEval_warningTextQuality` — collect all possible warning strings from ReadinessEngine (hydration, visceral, HRV, RHR warnings). Assert each is >20 characters and contains actionable language.

- [ ] **Step 2: Add to Xcode test target**

- [ ] **Step 3: Build + run**

Expected: 7/7 pass

- [ ] **Step 4: Commit**

```bash
git add FitTrackerTests/EvalTests/AIOutputQualityEvals.swift FitTracker.xcodeproj/project.pbxproj
git commit -m "test(evals): 7 AI output quality heuristic evals"
```

---

## Task 3: Create AITierBehaviorEvals (6 hybrid system tests)

**Files:**
- Create: `FitTrackerTests/EvalTests/AITierBehaviorEvals.swift`

- [ ] **Step 1: Write the 6 eval tests**

1. `testEval_localFallbackAlwaysWorks` — for each segment in `AISegment.allCases`, call `AIRecommendation.localFallback(for:snapshot:)` with a minimal `LocalUserSnapshot()`. Assert result is non-nil.

2. `testEval_confidenceGateBoundary` — create a mock AIOrchestrator scenario. With confidence 0.39, the base recommendation should be used (not adapted). With 0.41, the adapted should be used. This tests the `personalisationThreshold` constant.

3. `testEval_allSegmentsProduceSignals` — for each segment, localFallback produces a signals array with >=1 entry.

4. `testEval_emptySnapshotGraceful` — `LocalUserSnapshot()` with all nil fields. Call localFallback for all 4 segments. Assert no crash, all produce results.

5. `testEval_readinessFeedsSnapshot` — build a ReadinessResult, pass to `AISnapshotBuilder.build(from:readiness:)`. Assert `snapshot.readinessScore` is non-nil and matches the result's overallScore.

6. `testEval_staleSnapshotWarning` — verify the empty snapshot closure in FitTrackerApp produces a DEBUG warning. This may need to capture stdout or check a flag — if not testable, verify the comment exists and the fallback returns a valid empty snapshot.

- [ ] **Step 2: Add to Xcode test target**

- [ ] **Step 3: Build + run**

Expected: 6/6 pass

- [ ] **Step 4: Commit**

```bash
git add FitTrackerTests/EvalTests/AITierBehaviorEvals.swift FitTracker.xcodeproj/project.pbxproj
git commit -m "test(evals): 6 AI tier behavior evals for hybrid system"
```

---

## Task 4: Update Framework to v4.4

**Files:**
- Modify: `docs/skills/evolution.md`
- Modify: `docs/skills/README.md`
- Modify: `.claude/cache/_index.json`
- Modify: `.claude/shared/framework-manifest.json`
- Modify: `.claude/shared/framework-health.json`

- [ ] **Step 1: Add v4.4 section to evolution.md**

Append after the v4.3 section: §21 covering the 6-phase lifecycle, eval-driven development pattern, ai_quality_metrics, and how evals feed back into the learning cache.

- [ ] **Step 2: Update README.md**

Add v4.4 evolution bullet. Add rule 12: "Every feature defines eval cases during Phase 2 (Tasks). Evals run during Phase 5 (Test) and results feed case-study monitoring." Update shared file count if changed.

- [ ] **Step 3: Update framework-manifest.json**

Change `framework_version` from `"4.3"` to `"4.4"`. Add `"eval_driven_development"` to capabilities list.

- [ ] **Step 4: Update _index.json lifecycle**

Add Phase 5 (Eval) after the existing Phase 4 (Learn) entry.

- [ ] **Step 5: Update framework-health.json version reference**

- [ ] **Step 6: Commit**

```bash
git add docs/skills/evolution.md docs/skills/README.md .claude/cache/_index.json .claude/shared/framework-manifest.json .claude/shared/framework-health.json
git commit -m "docs: framework v4.4 — eval-driven development with Phase 5 (Eval)"
```

---

## Task 5: Final Verification + Case Study Snapshot

- [ ] **Step 1: Run full test suite**

```bash
xcodebuild test -scheme FitTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' -derivedDataPath .build/DerivedData
```
Expected: all tests pass including 20 new evals

- [ ] **Step 2: Update case study snapshot**

Update `eval-layer-v4.4-2026-04` in `case-study-monitoring.json` with:
- `eval_pass_rate`: 100 (or actual)
- `eval_total`: 20
- `tests_passing`: total count
- `build_verified`: true
- New snapshot: "implementation complete"

- [ ] **Step 3: Push to main**

```bash
git push
```

---

## Summary

| Task | Files | Tests | Commit |
|------|-------|-------|--------|
| 1 | ReadinessFormulaEvals.swift + pbxproj | 7 golden I/O | `7 golden I/O formula evals` |
| 2 | AIOutputQualityEvals.swift + pbxproj | 7 heuristic | `7 AI output quality evals` |
| 3 | AITierBehaviorEvals.swift + pbxproj | 6 tier behavior | `6 AI tier behavior evals` |
| 4 | evolution.md + README.md + manifest + health + cache | 0 | `framework v4.4` |
| 5 | case-study-monitoring.json | 0 | push |

**Total: 5 tasks, 20 eval cases, framework v4.4.**
