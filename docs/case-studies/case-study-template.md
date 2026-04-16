# Case Study Template — PM Framework Performance Analysis

> **Purpose:** Every feature executed through the PM workflow produces a case study. This template ensures consistent structure, metrics, and analysis so framework performance can be compared across versions.
>
> **Core question:** How did the framework version affect development speed and quality?
>
> **Usage:** Copy this template to `docs/case-studies/{feature}-v{version}-case-study.md` and fill in each section. Data sources: `state.json`, `case-study-monitoring.json`, `git log`, session timing.

---

## 1. Summary Card

| Field | Value |
|-------|-------|
| **Feature** | {name} |
| **Framework Version** | v{X.Y} |
| **Work Type** | Feature / Enhancement / Fix / Chore |
| **Complexity** | Files created: N, Files modified: N, Tasks: N |
| **Wall Time** | {total hours} ({measured/estimated}) |
| **Active Work Time** | {hours excluding pauses} |
| **Longest Phase** | {phase name}: {minutes} |
| **Tests** | {count} ({analytics tests} + {eval tests}) |
| **Analytics Events** | {count} |
| **Cache Hit Rate** | {percentage} (L1: {%}, L2: {%}, L3: {%}) — {measured/inferred} |
| **Eval Pass Rate** | {N/N} |
| **Headline** | "{Xh at vN vs Yh at vM = Z% improvement}" |

---

## 2. Experiment Design

### Independent Variable
- **Framework version** at time of execution (e.g., v4.4)

### Dependent Variables
| DV | Unit | How Measured |
|----|------|-------------|
| Wall time | hours | timing.total_wall_time_minutes from state.json ({measured/estimated}) |
| Planning velocity | phases/hour | Phases 0-3 time ÷ phase count |
| Implementation velocity | files/hour | Files created+modified ÷ Phase 4 time |
| Task completion rate | tasks/hour | Tasks completed ÷ total time |
| Cache hit rate | % | Cache sources cited ÷ total research actions |
| Eval pass rate | % | Evals passing ÷ total evals defined |
| Defect escape rate | count | Bugs found post-implementation (code review) |
| Test density | tests/event | Analytics tests ÷ analytics events |
| Serial improvement | multiplier | baseline_min_CU / this_feature_min_CU |
| Parallel speedup | multiplier | parallel_CU_per_hour / serial_CU_per_hour |

### Complexity Proxy
- Files created + modified (scope indicator)
- Work type (feature > enhancement > fix > chore)
- Has UI (yes/no — UI features are more complex)

### Controls
- Same PM workflow (same 10-phase lifecycle)
- Same developer (Regev + Claude Code)
- Same codebase (FitMe iOS app)
- Same design system (AppTheme tokens)

### Confounders (documented, not controlled)
- Feature complexity varies (documented via files/tasks count)
- Framework evolves between features (this IS the signal)
- Practitioner learning (partially captured by cache hit rate)
- Session continuity (single session vs. multi-session)

---

## 3. Raw Data

### Phase Timing

> Data source: `state.json → timing.phases`. Mark `(e)` for estimated, `(m)` for measured.

| Phase | Started | Ended | Duration (min) | Paused (min) | Active (min) | Source |
| ------- | --------- | ------- | ---------------- | -------------- | -------------- | -------- |
| 0. Research | | | | 0 | | (m/e) |
| 1. PRD | | | | 0 | | (m/e) |
| 2. Tasks | | | | 0 | | (m/e) |
| 3. UX/Design | | | | 0 | | (m/e) |
| 4. Implement | | | | 0 | | (m/e) |
| 5. Test | | | | 0 | | (m/e) |
| 6. Review | | | | 0 | | (m/e) |
| 7. Merge | | | | 0 | | (m/e) |
| 8. Docs | | | | 0 | | (m/e) |
| **Total** | | | **{sum}** | **{sum}** | **{sum}** | |

### Task Completion

| Task | Type | Skill | Effort | Status | Cache Hit? |
|------|------|-------|--------|--------|------------|
| T1 | | | | | |

### Cache Performance (v6.0)

> Data source: `.claude/features/{name}/cache-hits.json`. Mark `(m)` for measured, `(i)` for inferred.

| Level     | Hits | Misses | Hit Rate | Most Valuable Hit | Costliest Miss | Source |
|-----------|------|--------|----------|-------------------|----------------|--------|
| L1        |      |        |          |                   |                | (m/i)  |
| L2        |      |        |          |                   |                | (m/i)  |
| L3        |      |        |          |                   |                | (m/i)  |
| **Total** |      |        |          |                   |                |        |

### Cache Hit Detail Log

| Timestamp | Level | Skill | Key | Type          | Task Context |
|-----------|-------|-------|-----|---------------|--------------|
|           |       |       |     | exact/adapted |              |

### Cache Miss Detail Log

| Timestamp | Level | Skill | Expected Key | Reason                        | Task Context |
|-----------|-------|-------|--------------|-------------------------------|--------------|
|           |       |       |              | no_entry/stale/wrong_context  |              |

### Eval Results (v4.4+)

| Eval File | Tests | Pass | Fail | Notes |
|-----------|-------|------|------|-------|
| | | | | |

---

## 4. Analysis (3 Levels)

### Level 1 — Micro (Per-Skill Performance)

For each skill invoked during the feature:

| Skill | Invocations | Cache Hits | Time | Key Output |
|-------|------------|------------|------|------------|
| /pm-workflow | | | | |
| /dev | | | | |
| /qa | | | | |
| /analytics | | | | |
| /ux | | | | |
| /design | | | | |

### Level 2 — Meso (Cross-Skill Interaction)

| Dimension | This Feature | Comparison |
|-----------|-------------|------------|
| Handoff mechanism | | |
| Parallel execution | | |
| Data sharing | | |
| Error detection | | |

### Level 3 — Macro (Framework Performance)

| Metric | This Feature (vX.Y) | Best Prior (vA.B) | Worst Prior (vC.D) | Delta |
|--------|---------------------|-------------------|--------------------| ------|
| Wall time | | | | |
| Files/hour | | | | |
| Tasks/hour | | | | |
| Tests created | | | | |
| Cache hit rate | | | | |
| Defect escapes | | | | |

---

## 5. Normalized Velocity (mandatory)

> See `docs/case-studies/normalization-framework.md` for the full methodology.
> CU = Tasks × Work_Type_Weight × (1 + sum(Complexity_Factors))

### This Feature

| Metric | Value |
|---|---|
| Tasks | {N} |
| Work type weight | {0.3-1.0} |
| Complexity factors | {list: UI +0.3, Auth +0.5, Runtime +0.4, New Model +0.2, Cross-Feat +0.2, Design Iter +0.15/round} |
| **Complexity Units (CU)** | **{CU}** |
| Wall time (min) | {min} |
| **min/CU** | **{velocity}** |
| Rank (of N features) | {rank} / {N} |
| vs Baseline (v2.0 = 15.2 min/CU) | {+/-}% |

### Cross-Version Comparison (Normalized)

| Feature | Version | Type | Wall Time | CU | min/CU | vs Baseline |
|---|---|---|---|---|---|---|
| Onboarding v2 | v2.0 | refactor | 6.5h | 25.7 | 15.2 | Baseline |
| Home v2 | v3.0 | refactor | 36h* | 23.0 | 93.9* | Outlier |
| Training v2 | v4.0 | refactor | 5h | 18.7 | 16.0 | -5% |
| Nutrition v2 | v4.1 | refactor | 2h | 16.4 | 7.3 | +52% |
| Stats v2 | v4.1 | refactor | 1.5h | 11.7 | 7.7 | +49% |
| Settings v2 | v4.1 | refactor | 1h | 7.0 | 8.6 | +43% |
| Readiness v2 | v4.2 | enhancement | 2.5h | 8.4 | 17.9 | -18% |
| AI Engine v2 | v4.2 | enhancement | 0.5h | 3.8 | 7.9 | +48% |
| AI Rec UI | v4.2 | feature | 0.7h | 7.8 | 5.4 | +64% |
| Profile | v4.4 | feature | 2h | 16.9 | 7.1 | +53% |
| AI Engine Arch | v5.1 | enhancement | 1.5h | 17.7 | 5.1 | +66% |
| Onboarding Auth | v5.1 | feature | 1.7h | 47.7 | 2.1 | +86% |
| **{This Feature}** | **v{X.Y}** | **{type}** | **{time}** | **{CU}** | **{min/CU}** | **{delta}** |

*Home v2 excluded from trend — outlier that invented the v2 convention.

### Effect Size (Hedges' g)

| Comparison | Metric | Hedges' g | Interpretation |
|-----------|--------|-----------|----------------|
| v2.0 → vX.Y | Wall time | | small/medium/large |
| v4.0 → vX.Y | Files/hour | | |
| v4.1 → vX.Y | Cache hit rate | | |

---

## 6. Success & Failure Cases

### What Worked

| # | Success | Evidence |
|---|---------|----------|
| 1 | | |

### What Broke Down

| # | Failure | Evidence | Impact |
|---|---------|----------|--------|
| 1 | | | |

---

## 7. Framework Improvement Signals

### Cache Entries to Promote
- {pattern} — should move from L1 → L2 because {reason}

### Anti-Patterns Discovered
- {pattern} — {what went wrong} — source: {this feature}

### Eval Failures That Revealed Quality Gaps
- {eval name} — {what it caught} — fixed? yes/no

### Recommended Framework Changes for Next Version
- {change} — {rationale}

---

## 8. Methodology Notes

### Statistical Methods Used
- **Design:** Within-subjects repeated measures (each feature = one measurement of the same framework)
- **Effect size:** Hedges' g with small-sample correction (N < 20)
- **Trend detection:** Mann-Kendall test for monotonic improvement
- **Curve fitting:** Power law regression T = a * N^(-b) where b = improvement rate
- **Confidence intervals:** Bootstrap (BCa) with 10,000 resamples (when N > 6)

### Data Sources
- `state.json` — phase timestamps, task completion, metrics
- `case-study-monitoring.json` — process metrics, quality metrics, ai_quality_metrics
- `git log` — commit counts, file changes, PR data
- Session observations — wall time, decisions, blockers

### Limitations
- Single practitioner (Regev + Claude Code) — results may not generalize
- Framework evolves between measurements — cannot isolate framework effect from learning
- Feature complexity varies — normalized but not perfectly controlled
- Small sample size — effect sizes are estimates, not definitive

### References
- Runeson & Host (2009) — Guidelines for Case Study Research in Software Engineering
- Power Law of Practice — T = a * N^(-b) for learning/improvement curves
- Hedges' g — Small-sample corrected effect size (bias factor J)
- Mann-Kendall — Non-parametric monotonic trend test
- Prior case study: `docs/case-studies/pm-workflow-evolution-v1-to-v4.md`
