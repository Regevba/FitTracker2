# Stats v2 — V2 Refactor Checklist (filled)

> Walk-through of `docs/design-system/v2-refactor-checklist.md` for the
> stats-v2 feature, completed 2026-04-30 during the post-v7.7 resume.
>
> Legend: ✅ verified · 🟡 partial / deferred · N/A skipped (with reason) ·
> ⚠️ not manually verified in this pass (school-project context)

---

## Section A — Audit & spec (Phase 3)

- ✅ **A1.** `v2-audit-report.md` exists at `.claude/features/stats-v2/`. 9 findings: 2 P0 (F1 motion, F2 chart a11y), 3 P1 (F3-F5 frame tokenization), 4 P2 (F6-F9). Each has a fix proposed.
- 🟡 **A2.** No standalone `ux-research.md` at `.claude/features/stats-v2/`. Pre-PM-workflow feature; principle application captured in the audit report instead.
- 🟡 **A3.** No standalone `ux-spec.md`. Predates the strict ux-spec gate. PRD (`prd.md`) + audit report (`v2-audit-report.md`) cover screens, components, tokens, a11y, motion, state coverage equivalent.
- ✅ **A4.** Token / component / motion / a11y checks recorded in `v2-audit-report.md` Compliance Scorecard. Fails enumerated in F1-F9 with specific fixes.
- ✅ **A5.** `state.json.work_subtype = "v2_refactor"`, `state.json.v2_file_path = "FitTracker/Views/Stats/v2/StatsView.swift"`, `state.json.v2_rule_compliant = true`.

---

## Section B — File convention (Phase 4)

- ✅ **B1.** `FitTracker/Views/Stats/v2/` exists, contains only `StatsView.swift`.
- ✅ **B2.** v2 file declares `struct StatsView: View` (same name as v1's `StatsView_V1_Historical`-renamed type — pre-rename it was `StatsView`).
- ✅ **B3.** v2 file imports only `SwiftUI` and `Charts`. All visuals come from `AppColor`, `AppText`, `AppSpacing`, `AppLayout`, `AppRadius`, `AppMotion` tokens defined in `FitTracker/Services/AppTheme.swift`. No new ad-hoc components introduced inline.
- ✅ **B4.** No raw literals — all values resolve to tokens (`AppLayout.chartHeight`, `AppLayout.dotSize`, `AppLayout.chipMinWidth`, etc.). `make tokens-check` passes.
- ✅ **B5.** v1 file `FitTracker/Views/Stats/StatsView.swift` has historical header (lines 1-5) + types renamed `*_V1_Historical`. Shipped 2026-04-10 via PR #76.
- ✅ **B6.** project.pbxproj wired correctly:
  - PBXGroup for `v2/` (SV4*) and `Models/Stats/` (SS4*)
  - PBXFileReference for v2 StatsView (SV2*) + 3 model files (SP2*/SF2*/MP2*)
  - PBXBuildFile for v2 StatsView (SV1*) + 3 model files (SP1*/SF1*/MP1*)
  - All 4 PBXBuildFiles in the Sources build phase
  - v1 PBXBuildFile removed from Sources (PBXFileReference kept for navigator/git history)
- ✅ **B7.** `git diff main..HEAD -- FitTracker.xcodeproj/project.pbxproj` shows only the 5 surgical edits for T2's Models/Stats group + 3 file refs. No UUID reshuffles.

---

## Section C — Token compliance

- ✅ **C1.** Colors: only `AppColor.*` (Brand, Status, Surface, Text, Border, Accent). No raw colors.
- ✅ **C2.** Typography: only `AppText.*`. No `.font(.system(...))`.
- ✅ **C3.** Spacing: only `AppSpacing.*`. No raw padding numbers.
- ✅ **C4.** Radii: only `AppRadius.*`.
- N/A **C5.** No shadows used in v2/StatsView.swift.
- ✅ **C6.** No new tokens added in this feature (AppLayout was already shipped on main pre-feature). `feature-memory.md` entry is the audit report.

---

## Section D — Component reuse

- ✅ **D1.** `ChartCard`, `EmptyStateView`, `AppSelectionTile` — all from `FitTracker/DesignSystem/`.
- N/A **D2.** No new components proposed.
- ✅ **D3.** No copy-paste from v1 (rebuilt bottom-up from tokens per UX Foundations alignment).
- ✅ **D4.** v1 file no longer compiles (removed from Sources phase). v1 still parses for git review (verified in PR #76).

---

## Section E — UX principles

- ✅ **E1. Fitts's Law** — period picker buttons full-width; metric chips ≥128pt. Tap targets ≥44pt.
- ✅ **E2. Hick's Law** — Period picker has 5 options (within 5–7); selectedMetricSection shows 1 chart at a time.
- ✅ **E3. Jakob's Law** — Standard navigation, drag gesture for chart inspection (matches Health app).
- ✅ **E4. Progressive Disclosure** — Permanent body charts up top; "Track More" carousel below with details one tap away.
- ✅ **E5. Recognition over Recall** — Selected metric is highlighted via `AppSelectionTile` tint; latest value visible without tapping.
- ✅ **E6. Consistency** — Reuses `ChartCard` / `EmptyStateView`.
- ✅ **E7. Feedback** — `withAnimation(AppMotion.quickInteraction)` on chip tap; chart drag updates `chartSelection` immediately.
- N/A **E8. Error Prevention** — read-only stats screen; no destructive actions.
- ✅ **E9. Readiness-First** — Readiness is the default `selectedMetric` (`@State private var selectedMetric: StatsFocusMetric = .readiness`).
- N/A **E10. Zero-Friction Logging** — read-only screen; logging happens elsewhere.
- ✅ **E11. Privacy by Default** — Analytics events emit metric NAMES only (e.g. `"weight"`, `"hrv"`), never raw health values.
- N/A **E12. Progressive Profiling** — N/A for stats screen.
- ✅ **E13. Celebration Not Guilt** — empty states use neutral copy ("No weight data") + actionable CTA ("Log body metrics or sync a smart scale").

---

## Section F — State coverage

- ✅ **F1.** Default — chart with data points.
- 🟡 **F2.** Loading — no explicit loading state in v2; chart renders on `dataStore` synchronous call. Acceptable for the stats screen since data is local. Could add a skeleton on cold load — deferred follow-up.
- ✅ **F3.** Empty — `EmptyStateView` with metric icon + title + subtitle + CTA per `metric.emptyStateTitle/Subtitle`.
- N/A **F4.** Error — no error state in stats v2 since reads are local + offline-tolerant. The dataStore returns empty arrays, which falls into the empty branch.
- N/A **F5.** Success — read-only screen.

---

## Section G — Accessibility

- ✅ **G1.** Period picker buttons, metric chips, chart container all labeled. Decorative dots (`.frame(width: AppLayout.dotSize)`) are visual only — combined into the chip's accessibility element via `.accessibilityElement(children: .combine)` upstream (the chip itself).
- ✅ **G2.** `accessibilityHint("Tap to view chart for \(metric.title)")` on metric chips.
- ✅ **G3.** Chart container has `.accessibilityValue("X data points, latest value Y")`.
- 🟡 **G4.** Custom rotor for the chart's data points — deferred. The chart is announced as a single element with summary; per-point exploration would need `AXChartDescriptorRepresentable` (audit recommendation, F2 fix-alternative). Pragmatic accessibilityValue accepted.
- ✅ **G5.** Period picker buttons full-width within container; metric chips ≥128pt.
- ✅ **G6.** `AppSpacing.xSmall` (12pt) between picker buttons; `AppSpacing.xxSmall` (8pt) between chips.
- ✅ **G7.** All `AppText.*` Dynamic Type tokens used. Chip text has `.lineLimit(1).minimumScaleFactor(0.8)` for AX5 compatibility.
- ⚠️ **G8.** Color contrast not re-validated this pass — relies on `AppColor.Text.*` being pre-validated by `ColorContrastValidator` in DEBUG builds.
- ✅ **G9.** Selected metric is paired with tint AND `AppSelectionTile`'s isSelected visual + `.accessibilityAddTraits(.isSelected)`. Color is not the sole indicator.
- ✅ **(extra)** 18 a11y annotations total in v2/StatsView.swift (audit baseline 9, target 14+).

---

## Section H — Motion

- ✅ **H1.** Single animation: `withAnimation(AppMotion.quickInteraction)` on metric chip tap (state change). No decorative animations.
- ✅ **H2.** `AppMotion.quickInteraction` is a token (not a raw `.easeInOut(duration:)`).
- N/A **H3.** No springs used.
- ⚠️ **H4.** Reduce Motion: `AppMotion.quickInteraction` token honors Reduce Motion at the token layer (per AppMotion definition); not manually re-tested at AX-level this pass.
- N/A **H5.** No haptics in stats screen (read-only).
- N/A **H6.** No animation-only feedback paths.

---

## Section I — Analytics

- ✅ **I1.** All 4 events wired in v2/StatsView.swift (this commit, T5):
  - `stats_period_changed` on `.onChange(of: period)`
  - `stats_metric_selected` on metric chip tap
  - `stats_chart_interaction` on chart drag-gesture .onEnded
  - `stats_empty_state_shown` on EmptyStateView .onAppear
- ✅ **I2.** Event names follow GA4 rules: snake_case, ≤40 chars, no reserved prefixes. `stats_*` prefix is per the project Analytics Naming Convention (CLAUDE.md).
- ✅ **I3.** No PII in parameters: `period` (rawValue like "M"/"W"), `metricName` (rawValue like "weight"), `category` (`body`/`recovery`/`training`/`activity`/`nutrition`), `interactionType` (`"drag"`). No raw health values.
- 🟡 **I4.** No `.analyticsScreen()` modifier on the v2 root yet — deferred. Screen view tracking is global via `app_open` / `screen_view` elsewhere.
- ✅ **I5.** Consent gating verified by `StatsAnalyticsTests.swift` (93 lines) at the service layer. Service does not emit when consent is denied.

---

## Section J — Build & test

- ✅ **J1.** `xcodebuild build` — clean (verified after T5/T6 commit `027abf0` and T2 commit `47f8bd5`).
- 🟡 **J2.** `xcodebuild test` — targeted `StatsAnalyticsTests` running locally on iPhone 17 Pro Max simulator. Full XCTest suite NOT run in this pass (HomeReadinessUITests has known sim-hang issue per memory `project_ci_ui_test_investigation_2026_04_29`). Real CI verify on PR push.
- ✅ **J3.** `make tokens-check` clean.
- ⚠️ **J4-J7.** Manual testing (every state on simulator, AX5 Dynamic Type, Reduce Motion, VoiceOver) — NOT performed in this pass. School-project context; left for a later QA cycle.
- ✅ **J8.** v1 file (`FitTracker/Views/Stats/StatsView.swift`) still parses (no syntax errors). Types renamed `*_V1_Historical` so no clash with v2.

---

## Section K — Documentation

- 🟡 **K1.** PRD reflects original v2 plan; not updated post-resume with the discovered partial-shipment + reconciliation. Out-of-scope for this pass; included implicitly via state.json transitions[] reconciliation entry.
- 🟡 **K2.** `feature-memory.md` not updated — no new tokens/components added (AppLayout already on main pre-feature).
- 🟡 **K3.** `backlog.md` Done table — to be updated when feature reaches `documentation` phase.
- 🟡 **K4.** `CHANGELOG.md` — to be updated at merge time.
- ✅ **K5.** `state.json.transitions[]` reflects: research → prd → tasks → ux → (false-positive complete on 2026-04-10) → audit-downgrade to tasks (2026-04-20) → reconciliation to implementation (2026-04-30). All transitions logged with `approved_by` + `note`.

---

## Summary

| Section | Verified | Partial | N/A | Manual-deferred |
|---|---|---|---|---|
| A. Audit & spec | 3 | 2 | 0 | 0 |
| B. File convention | 7 | 0 | 0 | 0 |
| C. Token compliance | 5 | 0 | 1 | 0 |
| D. Component reuse | 3 | 0 | 1 | 0 |
| E. UX principles | 9 | 0 | 4 | 0 |
| F. State coverage | 2 | 1 | 2 | 0 |
| G. Accessibility | 8 | 1 | 0 | 1 |
| H. Motion | 2 | 0 | 3 | 1 |
| I. Analytics | 4 | 1 | 0 | 0 |
| J. Build & test | 2 | 1 | 0 | 4 |
| K. Documentation | 1 | 4 | 0 | 0 |
| **Total** | **46** | **10** | **11** | **6** |

Boxes verified or N/A: 57 of 73 applicable.
Boxes partial: 10 (mostly K — documentation is the next phase).
Boxes deferred to manual QA: 6 (G8 contrast, H4 Reduce Motion, J4-J7 manual sim testing).
