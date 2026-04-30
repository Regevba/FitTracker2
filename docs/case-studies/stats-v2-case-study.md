---
slug: stats-v2-case-study
title: stats-v2 — Resume, Reconcile, and Ship Despite a Three-Layer Bug Stack
date: 2026-04-30
framework_version: v7.7
work_type: feature
work_subtype: v2_refactor
status: shipped
case_study_type: shipped
tier_tags_required: true
case_study: docs/case-studies/stats-v2-case-study.md
case_study_showcase: fitme-story/content/04-case-studies/<TODO-slot>-stats-v2.mdx
predecessor_case_studies:
  - docs/case-studies/six-features-roundup-case-study.md
related_prs:
  - 76    # original v2 alignment pass (2026-04-10)
  - 144   # v7.7 Validity Closure (precondition for resume)
  - 160   # broken quarantine (root-cause surfaced here)
  - 164   # this feature's completion PR
  - 165   # cascading quarantine fix
  - 166   # cascading backlog task
related_features:
  - data-integrity-framework-v7-5  # reconciliation enforcement
  - mechanical-enforcement-v7-6    # write-time gates that DIDN'T catch this drift
  - framework-v7-7-validity-closure # resume signal
success_metrics:
  - name: stats_voiceover_coverage
    baseline: 0.27
    target: 0.90
    review_at: 2026-05-14
    tier: T1
  - name: motion_token_compliance
    baseline: 0.0
    target: 1.0
    tier: T1
kill_criteria: a11y coverage drops below 70% after merge
dispatch_pattern: serial (per F6-F9 concurrent-dispatch hygiene block)
---

# Case Study: stats-v2 — Resume, Reconcile, and Ship Despite a Three-Layer Bug Stack

> **Status:** Shipped 2026-04-30 via PR #164 (squash merge `9b05ebf`).
> **Framework version:** v7.7 (Validity Closure).
> **Predecessor case study:** the original six-features roundup (`docs/case-studies/six-features-roundup-case-study.md`) treated stats-v2 as one of six paused features. This dedicated case study replaces that entry once the feature actually shipped, because the resume turned into a substantive multi-defect story worth its own writeup.

---

## 1. Summary card

| Field | Value | Tier |
|---|---|---|
| Feature | stats-v2 | — |
| Framework version at completion | v7.7 | T1 |
| Work type | Feature (v2 refactor) | T1 |
| Wall time (resume → ship) | ~2.5 hours | T1 |
| Tasks: planned / completed / partial | 10 / 9 / 1 (T9 build-clean + CI-flake-accepted) | T1 |
| Files: created / modified / deleted | 5 / 4 / 0 | T1 |
| Commits on `feature/stats-v2` | 5 | T1 |
| Cascading PRs opened | 3 (#164, #165, #166) | T1 |
| Defects discovered during resume | 3 (ledger drift, view-wiring gap, broken CI quarantine) | T1 |
| Analytics events newly wired | 4 (`stats_period_changed`, `stats_metric_selected`, `stats_chart_interaction`, `stats_empty_state_shown`) | T1 |
| Accessibility annotations on `v2/StatsView.swift` | 9 → 18 (audit target ≥ 14) | T1 |
| Lines on `v2/StatsView.swift` after T2 type extraction | 899 → 673 (-25%) | T1 |
| CI: green checks / total | 9 / 10 (Build-and-Test red on unrelated infra flake) | T1 |
| Headline | "Service-layer tests can pass while view-wiring is a no-op. Audits can pass while ledgers drift. CI can stay green while quarantines silently fail." | T3 |

---

## 2. Why this case study exists

The original stats-v2 v2 alignment pass shipped **2026-04-10** via PR #76. The state.json was incorrectly marked `current_phase: complete` that day. On 2026-04-20 a manual integrity audit found the inconsistency (10/10 tasks pending vs. complete status) and downgraded it to `tasks`. On 2026-04-27 the feature was paused under the v7.7 Validity Closure full-priority freeze. On 2026-04-30 v7.7 shipped (PR #144) and stats-v2 was the first paused feature picked up.

What was supposed to be a small "complete the remaining tasks" job turned into a three-layer reveal — each layer hidden by the layer above looking green:

1. **Layer 1: state.json drifted from reality both ways.** The 2026-04-20 audit had over-corrected. T3 (build v2 file), T4 (pbxproj swap), T7 (analytics tests), T10 (mark v1 historical) had ALL actually shipped on 2026-04-10 in PR #76 — but never logged in state.json. The audit caught the false-positive `complete` and downgraded to `tasks`, missing that 4 tasks were genuinely done.
2. **Layer 2: tests passing didn't mean the feature worked.** T7 (StatsAnalyticsTests.swift, 93 lines) passed for 20 days — but the 4 stats analytics events it tested were never called from the view. The constants existed in `AnalyticsProvider.swift`, the methods existed in `AnalyticsService.swift`, the tests exercised the service directly. Zero `analytics.log…()` calls in `v2/StatsView.swift`. The primary metric `stats_voiceover_coverage` was being measured against zero traffic.
3. **Layer 3: the CI quarantine that "made it green" was lying.** PR #160 (2026-04-29) had quarantined a flaky UI test using `XCTSkipIf(ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] != nil, …)`. Stats-v2's PR run failed Build-and-Test, the rerun failed too — on a different test. The quarantine had never actually fired on hosted CI; it just looked like it had because the parallel-clone sim hang had picked a different victim each post-merge run.

Each layer was load-bearing trust for the layer above. Each layer was wrong.

---

## 3. Phase ledger

### 3.1 Pre-resume state (frozen 2026-04-27 14:00 UTC)

| `state.json` field | Value at pause | Reality on 2026-04-30 |
|---|---|---|
| `current_phase` | `tasks` | should have been `implementation` |
| `phases.implementation.status` | `in_progress` (residue) | should have been `in_progress` with commits |
| `phases.implementation.commits` | `[]` | should have included `e93d6e8` (PR #76) |
| `tasks[T1].status` | `pending` | already on main pre-feature (`AppTheme.swift:139-152`) |
| `tasks[T3,T4,T7,T10].status` | `pending` × 4 | actually done 2026-04-10 |
| `tasks[T2,T5,T6,T8,T9].status` | `pending` × 5 | genuinely pending |

### 3.2 Resume work (2026-04-30 16:00–18:30 UTC)

| Step | Output | Commit | Tier |
|---|---|---|---|
| Lift v7.7 freeze on stats-v2 + mark T1 done | state.json reconciliation, `paused.lifted_at` recorded with corrigendum after discovering v7.7 had already shipped | `71bac5a` | T1 |
| Reconcile state.json with PR #76 reality | T3/T4/T7/T10 → completed with commit citation, T5/T6 → partial, current_phase → `implementation`, transitions[] appended | `fca1ece` | T1 |
| T5 wire 4 analytics events + T6 a11y additions | `@EnvironmentObject AnalyticsService` added; 4 `analytics.logStats…()` calls wired; `category` property added to `StatsFocusMetric`; 9 → 18 a11y annotations | `027abf0` | T1 |
| T2 extract 3 nested types to `Models/Stats/` | New files `StatsPeriod.swift` (47 lines), `StatsFocusMetric.swift` (210 lines), `MetricSeriesPoint.swift` (8 lines); pbxproj wired with 5 surgical edits; `v2/StatsView.swift` 899 → 673 lines | `47f8bd5` | T1 |
| T8 v2-refactor-checklist filed + T2/T5/T6 marked completed in tasks ledger | `docs/case-studies/v2-refactor-checklist.md` walked: 46 verified + 11 N/A + 10 partial + 6 manual-deferred = 57/73 applicable verified-or-N/A | `6659dc8` | T1 |
| T9 closed with infra-flake-accepted caveat | state.json T9 → completed with explicit `partial_status: build_clean_infra_flake_accepted` | `d88d067` | T1 |

---

## 4. The three layers in detail

### 4.1 Layer 1 — Ledger drift the v7.6 mechanical gates couldn't catch

The v7.5/v7.6 Data Integrity Framework has 7 write-time gates and 13 cycle-time check codes. Specifically:

- `SCHEMA_DRIFT` — caught the legacy `phase` key on commit; doesn't catch field-value drift (T2)
- `PHASE_LIE` (cycle-time) — flags a state.json marked `complete` but with pending tasks. Caught the original 2026-04-10 false-positive on 2026-04-20.
- `PHASE_TRANSITION_NO_LOG` / `PHASE_TRANSITION_NO_TIMING` — gate forward transitions. Doesn't catch retroactive drift between state and reality.

What was missing: a check for "task marked pending in state.json BUT a commit on the feature branch / main implements the task". That signal would have flagged stats-v2's T3/T4/T7/T10 as drifted at the time of the 2026-04-20 audit. The audit author caught the OTHER direction (claimed complete, isn't) but missed this direction (claimed pending, actually done).

**Why this matters:** mechanical enforcement so far has hardened the **forward** path (don't claim work that hasn't shipped). Reverse-path enforcement (don't have unrecorded work shipped silently) is an open gap. Filed for follow-up under v7.7's "known mechanical limits" descendant.

### 4.2 Layer 2 — Service-layer tests that passed while the view did nothing

`StatsAnalyticsTests.swift` (93 lines, exists since 2026-04-10) tests the analytics service directly:

```swift
func testStatsPeriodChangedEvent() {
    analyticsService.logStatsPeriodChanged(period: "monthly")
    XCTAssertEqual(mockAdapter.capturedEvents.count, 1)
    let event = mockAdapter.capturedEvents[0]
    XCTAssertEqual(event.name, AnalyticsEvent.statsPeriodChanged)
    XCTAssertEqual(event.parameters?[AnalyticsParam.period] as? String, "monthly")
}
```

This is a perfectly correct test — it verifies that *if* `logStatsPeriodChanged` is called with `"monthly"`, the right event fires with the right parameter. It does NOT verify that the view ever calls `logStatsPeriodChanged`.

The view (`v2/StatsView.swift` from PR #76) had zero `analytics.log…()` invocations. So in production, the four `stats_*` events never fired. The PRD's primary metric `stats_voiceover_coverage` was being collected against zero traffic — the dashboard had been showing 0.27 baseline since shipping 20 days earlier, indistinguishable from "feature works perfectly and users just don't have HRV data."

**The fix in commit `027abf0`:**
- `@EnvironmentObject private var analytics: AnalyticsService` added to `StatsView`
- `.onChange(of: period)` — emits `stats_period_changed`
- Metric chip Button — emits `stats_metric_selected`
- Chart drag-gesture `.onEnded` — emits `stats_chart_interaction`
- `EmptyStateView.onAppear` — emits `stats_empty_state_shown`

**Lesson for the framework:** the `/analytics validate` skill should mark a screen-prefixed event as "wired" only if both (a) the constant + service method exist AND (b) at least one call site exists in the view layer. The current convention checks (a) only.

### 4.3 Layer 3 — The CI quarantine that wasn't quarantining anything

PR #160 had quarantined `HomeReadinessUITests.testHomeTabRendersInAuthenticatedReviewMode` (a UI test that consistently hung at ~236s on hosted CI) using:

```swift
try XCTSkipIf(
    ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] != nil,
    "Quarantined on hosted GitHub Actions"
)
```

The bug: **environment variables set on the GitHub Actions runner do NOT propagate to the iOS Simulator's XCTRunner process.** `xcodebuild test` boots a sim, the test bundle runs as XCTRunner inside that sim, and that process has its own (empty for this var) environment. PR #160 looked green only by luck — the parallel-clone sim hang affects a *random subset* of tests each run, and the smart-reminders post-merge run happened to dodge HomeReadinessUITests.

Stats-v2 PR #164 surfaced the bug clearly with two consecutive failed Build-and-Test runs hitting **different** tests:

| Run | Failed test | Time | Outcome |
|---|---|---|---|
| First | `OnboardingUITests.testOnboardingFirstStepRendersIfNotComplete` | 74.4 s | Failed |
| Rerun | `HomeReadinessUITests.testHomeTabRendersInAuthenticatedReviewMode` | 194.8 s | Failed (the very test PR #160 thought it had quarantined) |

If the env-var check had worked, run 2's HomeReadiness failure would have been impossible.

**The fix in PR #165 (`chore/ci-quarantine-fix`):**

```swift
try XCTSkipIf(
    NSUserName() == "runner",
    "Quarantined on hosted GitHub Actions runner"
)
```

`NSUserName()` returns the host user identity which XCTRunner DOES inherit on hosted GitHub Actions macOS runners — and that user is always literally `"runner"`. Locally it returns the dev's username, so tests run normally.

PR #165 also extends the quarantine to `OnboardingUITests` since it has the same hang signature.

**The underlying environmental cause** (parallel-clone sim hang where one of the parallel iPhone 16 Pro clones lands in an unhealthy state where `XCUIElementQuery` calls hang for 74-236s instead of returning their expected result) is **still unresolved**. PR #166 files it as a backlog task under "High Priority (Architecture & Framework)" with concrete investigation steps and an acceptance criterion (5 consecutive green runs without quarantines, OR a documented permanent-quarantine + parallelism-reduction decision).

---

## 5. Honest accounting on T9

T9 ("CI verification") was the dependency that should have closed the feature. It was closed with an explicit caveat in state.json:

```json
{
  "id": "T9",
  "status": "completed",
  "partial_status": "build_clean_infra_flake_accepted",
  "completed_at": "2026-04-30T18:30:00Z",
  "partial_note": "Local xcodebuild build clean … CI verification on PR #164: 9 of 10 checks green … Build-and-Test failed twice on UNRELATED UI test infra flake … User accepted stats-v2 merge despite Build-and-Test red because: (a) all stats-v2 code verified clean (compile + non-flaky tests pass), (b) failure is unrelated UI test infra, (c) quarantine fix is in flight, (d) parallel-clone hang root cause is filed as separate backlog task. T9 marked completed with caveat for ledger honesty."
}
```

PR #164 was admin-merged with Build-and-Test red. The repo's branch protection has no required status checks (per `project_ci_ui_test_investigation_2026_04_29.md` — `required_status_checks: null`), so the merge was permitted. The `partial_status` field is the framework's mechanism for "shipped, but with this asterisk" — it preserves the truth in the ledger rather than papering over an unclean ship.

**This is a deliberate trade-off documented in this case study so future readers can audit it:** we accepted a known infra-flake on a verified-clean feature in order to (a) unblock 5 paused features, (b) prove the CI bug exists by surfacing it through a real PR, (c) document the proper fix in PR #165 — and we filed the root-cause investigation as PR #166. The alternative (block stats-v2 until CI is fully fixed) would have rolled the broken-quarantine cost onto every other PR until then.

---

## 6. What worked

| # | Success | Evidence | Tier |
|---|---|---|---|
| 1 | The 2026-04-30 reconciliation audit caught the drift the 2026-04-20 audit missed | T3/T4/T7/T10 retroactively logged with commit `e93d6e8` citation in fca1ece | T1 |
| 2 | The audit-first-then-code sequencing ("option A" the user picked) saved compounding work on top of a drifted ledger | Reconciliation commit `fca1ece` landed before any code changes | T1 |
| 3 | Worktree isolation kept the auth-polish-v2 dirty state contained while stats-v2 ran in `.worktrees/stats-v2/` | Both branches developed in parallel without cross-contamination of untracked files (HADF, Sentry, .env.local) | T1 |
| 4 | T5 wiring shipped a bug fix, not just a marker check | 0 → 4 `analytics.log…()` calls in the view; primary metric `stats_voiceover_coverage` will start collecting non-zero traffic post-merge | T2 (production verification at +14d) |
| 5 | The CI failure cascade became three properly-scoped PRs (one per concern) instead of one bundled monolith | #164 ships the feature, #165 fixes CI infra, #166 files root-cause task | T1 |

## 7. What broke down

| # | Failure | Evidence | Impact | Tier |
|---|---|---|---|---|
| 1 | v7.6 mechanical gates didn't catch reverse-path drift (claimed-pending-but-actually-shipped) | T3/T4/T7/T10 sat unrecorded for 20 days through 4 cycle-time check runs | Filed as v7.7 follow-up "known mechanical limits" gap | T1 |
| 2 | T7 service-layer tests passed for 20 days while the view-wiring gap shipped to production | `StatsAnalyticsTests.swift` exercises service directly, not view→service integration | Filed as `/analytics validate` enhancement (require call-site presence, not just constant + method) | T1 |
| 3 | PR #160's `GITHUB_ACTIONS` env-var quarantine never fired on CI; appeared green by luck | Stats-v2 rerun failed on the very test PR #160 thought it had quarantined | Fixed in PR #165 with `NSUserName() == "runner"`. Permanent caveat written into both test files: "DO NOT use ProcessInfo env-var detection in iOS UI tests." | T1 |
| 4 | A self-inflicted near-miss: backlog commit briefly landed on local `main` because `gh pr merge --delete-branch` left the worktree on main | Caught before push (branch protection would have blocked); commit moved to `chore/backlog-ci-parallel-clone-task`, local main reset to `origin/main` | Lesson: after squash-merge with `--delete-branch`, explicitly `git checkout` to a known branch before next commit | T1 |

---

## 8. Framework improvement signals

### 8.1 Cache entries to promote
- "iOS UI test env-var detection silently fails on hosted CI" — promote from this case study's L1 (incident-local) to L2 (cross-feature CI infra). Future agents writing test quarantines should match against this pattern and prefer `NSUserName()` / build-config flags / launch arguments.

### 8.2 Anti-patterns discovered
- **Service-layer-only test coverage on a wired-from-view event.** Pattern: tests exist for `Service.logFooEvent(...)`, view never calls it, dashboard collects zeros, no signal ever reaches engineering that the wiring is missing. Source: this feature's T5 gap.
- **Audit downgrade without forward verification.** Pattern: an integrity audit catches `phase=complete` but `tasks=pending`, downgrades to `tasks` — without checking whether some of the tasks ARE actually shipped. Result: under-correction. Source: 2026-04-20 audit on this feature.

### 8.3 Recommended framework changes for next version
- **Reverse-path ledger gate:** add a cycle-time check `TASK_PENDING_BUT_SHIPPED` that grep's main + the feature branch for files matching `task.title` or `task.acceptance_criteria` keywords and flags pending tasks where the matching code already exists. False-positive prone but cheap to triage; would have caught this case 20 days earlier.
- **`/analytics validate` enhancement:** require call-site presence in the view layer, not just constant + method definition. Match against `Analytics{Event,Service}.{constantName,methodName}` references in `FitTracker/Views/`.
- **Test runner env-var documentation:** add a one-paragraph note to the testing playbook (or `docs/process/`) saying "iOS UI tests run inside XCTRunner on the simulator; host environment variables do NOT propagate. Use `NSUserName()`, launch arguments, or build-config flags for CI detection." Prevent future re-occurrence of the broken quarantine pattern.

---

## 9. Methodology notes

### 9.1 Tier convention used
- **T1 (Instrumented):** anything pulled directly from `state.json`, `git log`, or CI run JSON.
- **T2 (Declared):** the primary success metric `stats_voiceover_coverage` baseline 0.27 / target 0.90 — declared in PRD; T1 readout pending +14d post-merge.
- **T3 (Narrative):** the "headline" framing in section 1 and the framework-improvement-signals section are interpretive synthesis.

### 9.2 Data sources
- `state.json` — task ledger, phase timing, transitions, commits
- `.claude/logs/stats-v2.log.json` — 1 phase_transition event recorded contemporaneously
- `git log feature/stats-v2 ^main` — 5 commits with full messages
- `gh pr view 164` — merge metadata (squash `9b05ebf` at 2026-04-30T18:31:48Z)
- `gh run view 25179756754 --log-failed` — Build-and-Test failure detail (the OnboardingUITests + HomeReadinessUITests timeouts)

### 9.3 Limitations
- Single practitioner (Regev + Claude Code, one session)
- Production verification of `stats_voiceover_coverage` is owed at +14d (`2026-05-14`); this case study cannot yet claim "metric moved"
- Manual QA (color contrast, AX5 Dynamic Type, Reduce Motion, VoiceOver simulator pass) deferred — school-project context
- The "20 days of zero traffic" claim assumes the existing GA4 funnel was actually receiving the events; if the consent gate had been blocking globally, the same zero would result. Forward T1 verification needed.

---

## 10. Cross-references

- Six-features roundup case study (predecessor, now superseded for stats-v2): [`docs/case-studies/six-features-roundup-case-study.md`](./six-features-roundup-case-study.md)
- v7.7 Validity Closure (precondition): [`docs/case-studies/framework-v7-7-validity-closure-case-study.md`](./framework-v7-7-validity-closure-case-study.md)
- v7.6 Mechanical Enforcement (gates that both helped and missed this case): [`docs/case-studies/mechanical-enforcement-v7-6-case-study.md`](./mechanical-enforcement-v7-6-case-study.md)
- Memory: `project_stats_v2.md` (current status), `project_ci_ui_test_investigation_2026_04_29.md` (CI infra context)
