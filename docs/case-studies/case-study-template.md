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
| **Wall Time** | {total hours} |
| **Tests** | {count} ({analytics tests} + {eval tests}) |
| **Analytics Events** | {count} |
| **Cache Hit Rate** | {percentage} |
| **Eval Pass Rate** | {N/N} |
| **Headline** | "{Xh at vN vs Yh at vM = Z% improvement}" |

---

## 2. Experiment Design

### Independent Variable
- **Framework version** at time of execution (e.g., v4.4)

### Dependent Variables
| DV | Unit | How Measured |
|----|------|-------------|
| Wall time | hours | Phase timestamps from state.json transitions[] |
| Planning velocity | phases/hour | Phases 0-3 time ÷ phase count |
| Implementation velocity | files/hour | Files created+modified ÷ Phase 4 time |
| Task completion rate | tasks/hour | Tasks completed ÷ total time |
| Cache hit rate | % | Cache sources cited ÷ total research actions |
| Eval pass rate | % | Evals passing ÷ total evals defined |
| Defect escape rate | count | Bugs found post-implementation (code review) |
| Test density | tests/event | Analytics tests ÷ analytics events |

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

| Phase | Start | End | Duration | Notes |
|-------|-------|-----|----------|-------|
| 0. Research | | | | |
| 1. PRD | | | | |
| 2. Tasks | | | | |
| 3. UX/Design | | | | |
| 4. Implement | | | | |
| 5. Test | | | | |
| 6. Review | | | | |
| 7. Merge | | | | |
| 8. Docs | | | | |
| **Total** | | | | |

### Task Completion

| Task | Type | Skill | Effort | Status | Cache Hit? |
|------|------|-------|--------|--------|------------|
| T1 | | | | | |

### Cache Hits During Execution

| Cache Entry | Level | What It Provided | Time Saved (est.) |
|-------------|-------|-----------------|-------------------|
| | | | |

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

## 5. Cross-Version Comparison Table

| Feature | Version | Type | Wall Time | Tasks | Tests | Events | Files | Cache% |
|---------|---------|------|-----------|-------|-------|--------|-------|--------|
| Onboarding v2 | v2.0 | refactor | 6.5h | 22 | 5 | 5 | 20 | 0% |
| Home v2 | v3.0 | refactor | 36h* | 17 | 21 | 4 | 5 | 0% |
| Training v2 | v4.0 | refactor | 5h | 16 | 16 | 12 | 7 | 40% |
| Nutrition v2 | v4.1 | refactor | 2h | 14 | 7 | 5 | 5 | 55% |
| Stats v2 | v4.1 | refactor | 1.5h | 10 | 10 | 4 | 4 | 65% |
| Settings v2 | v4.1 | refactor | 1h | 6 | 8 | 3 | 3 | 70% |
| Readiness v2 | v4.2 | enhancement | 2.5h | 7 | 25 | 9 | 7 | 35% |
| AI Engine v2 | v4.2 | enhancement | 0.5h | 4 | 0 | 0 | 4 | 50% |
| AI Rec UI | v4.2 | feature | 0.7h | 6 | 16 | 6 | 7 | 40% |
| **{This Feature}** | **v{X.Y}** | **{type}** | **{time}** | **{tasks}** | **{tests}** | **{events}** | **{files}** | **{cache%}** |

*Home v2 was an outlier — first full refactor, invented the v2 convention.

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
