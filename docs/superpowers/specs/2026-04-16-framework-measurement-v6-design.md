# Framework Measurement v6.0 — Design Spec

> **Date:** 2026-04-16
> **Branch:** `feature/framework-measurement-v6`
> **Work Type:** Feature (full 9-phase PM lifecycle)
> **Framework Version:** v5.2 → v6.0
> **Triggered By:** Meta-analysis of all FitMe PM case studies (`docs/case-studies/meta-analysis-2026-04-16.md`)

---

## 1. Problem Statement

The FitMe PM framework has 16 case studies spanning v2.0 → v5.2, forming a rare longitudinal dataset of framework-driven development. A cross-case meta-analysis identified 8 measurement gaps that limit the precision and reliability of these case studies:

1. Wall times are estimated (±15-30 min), not instrumented
2. Cache hit rates are inferred from narratives, not counted
3. Token overhead uses `wc` word counts as proxy (~10-15% error)
4. Some AI-touching features shipped without eval coverage
5. Monitoring stays out of sync with CI (manual updates)
6. Complexity factors are subjective (binary flags, flat weights)
7. Serial and parallel improvement gains are conflated
8. All comparisons anchor to a single v2.0 baseline

These gaps don't invalidate the trend (15.2 → 2.1 min/CU is real), but they cap how far the numbers can be used for prediction, attribution, or external benchmarking.

## 2. Research Questions

### Experiment 1: Measurement Precision (Meta-Experiment)

**Question:** Does upgrading the framework's measurement infrastructure (v5.2 → v6.0) produce more precise, reliable, and actionable case study data?

**Independent Variable:**
- Framework measurement version: v5.2 (estimated, narrative-based) vs v6.0 (instrumented, deterministic)

**Dependent Variables:**

| DV | Unit | v5.2 State | v6.0 Target |
|---|---|---|---|
| Wall-time error band | ±minutes | ±15-30 min (commit-derived) | ±0 (instrumented start/end) |
| Cache hit measurement type | measured vs inferred | Narrative ("5/13 tasks") | Deterministic L1/L2/L3 counters |
| Token overhead accuracy | % error vs actual | `wc` proxy (~10-15% error) | tiktoken counts (~5% error) |
| Eval coverage completeness | behaviors covered / identified | Spotty, manual | Gated, auto-synced |
| Monitoring freshness | auto vs manual | Manual (stale risk) | Phase-transition auto-sync |
| CU reproducibility | subjective vs objective | Binary flags | Objective signals (view count, type count) |

**Controls:** Same codebase, practitioner, PM lifecycle. Measurement changes observe the process without altering it.

**Hypothesis:** v6.0 instrumentation reduces the error band on all 6 DVs, making case study claims auditable rather than narrative.

### Experiment 2: Framework Velocity (Ongoing)

**Question:** Does the PM framework continue to improve development velocity as it evolves?

**Independent Variable:**
- PM framework version at time of feature execution (v2.0 through v6.0)

**Dependent Variables:**

| DV | Unit | v5.2 Measurement | v6.0 Measurement |
|---|---|---|---|
| Velocity (primary) | min/CU | Estimated time ÷ binary CU | Measured time ÷ continuous CU |
| Planning velocity | phases/hour | Estimated from transitions | Measured phase durations |
| Implementation velocity | files/hour | Estimated Phase 4 time | Measured Phase 4 duration |
| Cache hit rate | % | Narrative inference | Deterministic counters |
| Eval pass rate | % | Manual count | Auto-synced from test runs |
| Defect escape rate | count | Manual tally | Manual tally (inherently subjective) |
| Test density | tests/task | Manual count | Verified against state.json |
| Serial improvement | multiplier | Not separated | Explicit: baseline / serial velocity |
| Parallel speedup | multiplier | Not separated | Explicit: parallel / serial throughput |

**Controls:** Same practitioner, codebase, design system, PM lifecycle. CU normalization controls for feature complexity.

**Confounders (documented, not controlled):**
- Practitioner learning (partially captured by cache hit rate)
- Feature complexity variance (controlled by CU normalization)
- Framework evolution between features (this IS the signal)
- Session continuity (now measurable via `timing.sessions[]`)

**Hypothesis:** Velocity continues to improve, and v6.0 instrumentation enables attributing improvement to specific causes (cache maturity, eval-driven development, parallel execution).

### How The Two Experiments Interact

Experiment 1 produces better instruments. Experiment 2 uses those instruments to measure itself. The v6.0 feature is both the first subject and the instrument builder — its own case study evaluates measurement DVs (data quality before/after) while also reporting velocity DVs normally (CU, min/CU, historical table entry).

---

## 3. Architecture

Four layers, built vertically across 3 priority slices + 1 second pass:

```
┌─────────────────────────────────────────────────────────┐
│                    CASE STUDY TEMPLATE                   │
│  measured_wall_time, cache_breakdown, eval_coverage,     │
│  rolling_baseline, serial_vs_parallel, token_overhead    │
├─────────────────────────────────────────────────────────┤
│                   NORMALIZATION MODEL                    │
│  CU v2: continuous factors, rolling baseline,            │
│  serial/parallel decomposition, cu_version field         │
├─────────────────────────────────────────────────────────┤
│                      CI / MAKEFILE                       │
│  verify-framework, verify-evals, verify-timing,          │
│  auto-monitoring-sync                                    │
├─────────────────────────────────────────────────────────┤
│                  INSTRUMENTATION LAYER                   │
│  state.json timing{}, cache-hits.json,                   │
│  eval_results{}, token-budget.json                       │
├─────────────────────────────────────────────────────────┤
│                   PM WORKFLOW (SKILL.md)                  │
│  Phase timing protocol, cache tracking protocol,         │
│  eval coverage gate, monitoring sync protocol            │
└─────────────────────────────────────────────────────────┘
```

**Scope:** Zero Swift code. All changes are JSON schemas, Markdown templates, Makefile targets, PM workflow protocols, and one shell script.

**Backward compatibility:** Existing state.json files are not migrated. All new fields are optional with defaults. Old features remain valid. CU v1 values are preserved as historical record.

---

## 4. Slice 1 — Phase Timing Instrumentation

**Closes:** Meta-analysis gap #1 (wall-time precision)

### 4.1 State Schema: `timing` Object

Add to `state-schema.json` as a new top-level optional property:

```json
"timing": {
  "type": "object",
  "description": "Precise timing instrumentation. Added in v6.0.",
  "properties": {
    "session_start": { "type": ["string", "null"], "format": "date-time" },
    "session_end": { "type": ["string", "null"], "format": "date-time" },
    "total_wall_time_minutes": { "type": ["number", "null"] },
    "time_source": {
      "type": "string",
      "enum": ["measured", "estimated"],
      "default": "estimated"
    },
    "phases": {
      "type": "object",
      "additionalProperties": {
        "type": "object",
        "properties": {
          "started_at": { "type": "string", "format": "date-time" },
          "ended_at": { "type": ["string", "null"], "format": "date-time" },
          "duration_minutes": { "type": ["number", "null"] },
          "paused_minutes": {
            "type": ["number", "null"], "default": 0,
            "description": "Reported by practitioner on session resume. When user says 'I'm back' or resumes work after a break, the PM workflow asks 'How long were you away?' and records the answer. If no break reported, stays 0."
          }
        }
      }
    },
    "sessions": {
      "type": "array",
      "description": "For multi-session features. Each entry = one work session.",
      "items": {
        "type": "object",
        "properties": {
          "started_at": { "type": "string", "format": "date-time" },
          "ended_at": { "type": ["string", "null"], "format": "date-time" },
          "duration_minutes": { "type": ["number", "null"] },
          "phases_active": { "type": "array", "items": { "type": "string" } }
        }
      }
    },
    "parallel_context": {
      "type": "object",
      "properties": {
        "concurrent_features": { "type": "integer", "default": 1 },
        "concurrent_feature_slugs": { "type": "array", "items": { "type": "string" } },
        "is_stress_test": { "type": "boolean", "default": false }
      }
    }
  }
}
```

### 4.2 PM Workflow Protocol

```
PHASE TIMING PROTOCOL (v6.0)

On phase start (after user approves transition):
  1. Write timing.phases[phase].started_at = ISO 8601 now
  2. If first phase: also write timing.session_start = now

On phase end (before requesting next transition):
  1. Write timing.phases[phase].ended_at = ISO 8601 now
  2. Compute timing.phases[phase].duration_minutes = ended_at - started_at
  3. If user reports pause: add to timing.phases[phase].paused_minutes

On feature completion:
  1. Write timing.session_end = now
  2. Compute timing.total_wall_time_minutes = sum of all phase durations
  3. Set timing.time_source = "measured"

Multi-session features:
  Append to timing.sessions[] per work session. Total = sum of sessions.
```

### 4.3 Template Changes

Summary Card additions:
```
| **Wall Time** | {hours} ({measured/estimated}) |
| **Active Work Time** | {hours excluding pauses} |
| **Longest Phase** | {phase}: {minutes} |
```

New raw data table:
```
### Phase Timing
| Phase | Started | Ended | Duration (min) | Paused (min) | Active (min) |
```

### 4.4 CI: `verify-timing`

Soft gate (warn, don't block):
- For completed features: warn if `timing.time_source != "measured"`
- Warn if any phase has `started_at` but no `ended_at`

---

## 5. Slice 2 — Cache Hit Tracking

**Closes:** Meta-analysis gap #2 (cache correlation with velocity)

### 5.1 Per-Feature `cache-hits.json`

New file at `.claude/features/{name}/cache-hits.json`:

```json
{
  "feature": "{slug}",
  "framework_version": "6.0",
  "sessions": [
    {
      "session_id": "{ISO 8601}",
      "hits": [
        {
          "timestamp": "{ISO 8601}",
          "cache_level": "L1|L2|L3",
          "skill": "{skill-name}",
          "cache_key": "{skill}:{task_type}:{context}",
          "hit_type": "exact|adapted|stale",
          "task_context": "{task description}"
        }
      ],
      "misses": [
        {
          "timestamp": "{ISO 8601}",
          "cache_level": "L1|L2|L3",
          "skill": "{skill-name}",
          "expected_key": "{key}",
          "miss_reason": "no_entry|stale|wrong_context",
          "task_context": "{task description}"
        }
      ],
      "summary": {
        "L1_hits": 0, "L1_misses": 0,
        "L2_hits": 0, "L2_misses": 0,
        "L3_hits": 0, "L3_misses": 0,
        "total_hit_rate": 0.0
      }
    }
  ],
  "aggregate": {
    "total_hits": 0,
    "total_misses": 0,
    "hit_rate": 0.0,
    "L1_hit_rate": 0.0,
    "L2_hit_rate": 0.0,
    "L3_hit_rate": 0.0,
    "most_valuable_hit": null,
    "costliest_miss": null
  }
}
```

### 5.2 Shared `cache-metrics.json`

Rolling aggregate at `.claude/shared/cache-metrics.json`:

```json
{
  "version": "1.0",
  "updated": "{ISO 8601}",
  "by_framework_version": {
    "v6.0": {
      "features_measured": 0,
      "avg_hit_rate": 0.0,
      "L1_avg": 0.0, "L2_avg": 0.0, "L3_avg": 0.0,
      "top_entries_by_hits": [],
      "top_misses_by_cost": []
    }
  },
  "promotion_candidates": [],
  "cache_health_trend": [],
  "rolling_baseline_hit_rate": null
}
```

### 5.3 PM Workflow Protocol

```
CACHE TRACKING PROTOCOL (v6.0)

On skill load (reading from .claude/cache/{skill}/):
  1. Check if cache entry exists for current task type
  2. HIT: log to cache-hits.json (level, key, hit_type)
  3. MISS: log with expected_key and miss_reason
  4. STALE (SHA256 mismatch): log as miss, reason "stale"

On phase completion:
  1. Compute session summary (L1/L2/L3 hits and misses)

On feature completion:
  1. Finalize aggregate
  2. Update cache-metrics.json under current fw version
  3. Flag promotion candidates (L1 hit by 2+ skills → L2)
```

### 5.4 Velocity Annotation

```
Adjusted context for velocity comparison:
  hit_rate >= 0.6: velocity is framework-attributable (no annotation)
  hit_rate 0.3-0.6: "partial cache" annotation
  hit_rate < 0.3: "cold cache" annotation — velocity may reflect practitioner skill
```

Does not change CU. Adds interpretive context to velocity claims.

### 5.5 Template Changes

Summary Card: `| **Cache Hit Rate** | {%} (L1: {%}, L2: {%}, L3: {%}) — {measured/inferred} |`

New table:
```
### Cache Performance
| Level | Hits | Misses | Rate | Most Valuable Hit | Costliest Miss |
```

### 5.6 CI: `verify-framework`

- Validate `cache-metrics.json` exists and is valid JSON
- For completed features: check `cache-hits.json` exists
- Cross-reference `_index.json` hit counts with `cache-hits.json` totals
- Check for stale entries (SHA256 mismatch)
- Report promotion candidates

---

## 6. Slice 3 — Eval & Test Gates + Auto-Monitoring

**Closes:** Meta-analysis gaps #4 (AI test coverage) and #5 (monitoring sync)

### 6.1 State Schema: `eval_results`

Add to `testing` phase in `state-schema.json`:

```json
"eval_results": {
  "type": "object",
  "properties": {
    "total_evals": { "type": "integer", "default": 0 },
    "passing": { "type": "integer", "default": 0 },
    "failing": { "type": "integer", "default": 0 },
    "eval_pass_rate": { "type": ["number", "null"] },
    "categories": {
      "type": "object",
      "additionalProperties": {
        "type": "object",
        "properties": {
          "total": { "type": "integer" },
          "passing": { "type": "integer" }
        }
      }
    },
    "uncovered_behaviors": {
      "type": "array",
      "items": { "type": "string" }
    }
  }
},
"min_eval_coverage_met": {
  "type": "boolean",
  "default": false
}
```

### 6.2 Eval Coverage Gate (PM Workflow)

```
EVAL COVERAGE GATE (v6.0)

PRD phase (AI-touching features only):
  1. Identify all AI behaviors in PRD
  2. Define minimum coverage per behavior:
     - Golden I/O: >= 3 evals per behavior
     - Quality heuristic: >= 2 per behavior
     - Tier/edge case: >= 1 per behavior
  3. Write to PRD "### Test & Eval Requirements" section
  4. Store behavior list in state.json testing.eval_results.uncovered_behaviors

Testing phase:
  1. Run evals
  2. Write results to state.json testing.eval_results
  3. Gate: min_eval_coverage_met = every behavior has >= 1 eval
  4. If not met: BLOCK transition to Review (user can override with note)

Non-AI features:
  Gate auto-passes. eval_results stays at defaults.
```

### 6.3 Full Monitoring Sync Protocol

Phase transitions auto-update `case-study-monitoring.json`:

```
MONITORING SYNC PROTOCOL (v6.0)

research → prd:       research_complete = true
prd → tasks:          prd_approved = true
tasks → implement:    tasks_defined = phase.tasks.count
implement → testing:  repo_files_added/updated from git diff --stat
testing → review:     tests_passing, build_verified, eval results
review → merge:       critical/high/medium findings count
merge → docs:         merged = true, pr_number
docs → complete:      Final snapshot "feature-complete-auto"
                      Write timing.total_wall_time_minutes
```

### 6.4 CI: `verify-evals`

```makefile
verify-evals:
	cd ai-engine && $(AI_VENV)/bin/python -m pytest evals/ -v --tb=short

verify-local: tokens-check verify-web verify-ai verify-evals verify-ios
```

### 6.5 Template Changes

Summary Card:
```
| **Eval Coverage** | {N} behaviors, {M} evals ({rate}%) — {N uncovered} |
| **Monitoring Sync** | auto / manual |
```

New table:
```
### Eval Coverage (per AI behavior)
| Behavior | Golden I/O | Quality Heuristic | Tier/Edge | Total | Pass Rate |
```

---

## 7. Second Pass — Remaining Gaps

### 7.1 Token Counting (Gap #3)

**New file:** `scripts/count-framework-tokens.sh`

Uses Python tiktoken (cl100k_base) to count tokens across 4 layers:
- Skills (`.claude/skills/*/SKILL.md`)
- Cache (`.claude/cache/*/*.json`)
- Shared (`.claude/shared/*.json`)
- Adapters (`.claude/integrations/*/*`)

**Output:** `.claude/shared/token-budget.json`
```json
{
  "measured_at": "{ISO 8601}",
  "model": "claude-opus-4-6",
  "tokenizer": "tiktoken-cl100k_base",
  "layers": {
    "skills": { "files": 0, "tokens": 0, "pct_of_total": 0.0 },
    "cache": { "files": 0, "tokens": 0, "pct_of_total": 0.0 },
    "shared": { "files": 0, "tokens": 0, "pct_of_total": 0.0 },
    "adapters": { "files": 0, "tokens": 0, "pct_of_total": 0.0 }
  },
  "total_tokens": 0,
  "context_budget_pct": 0.0
}
```

Integrated into `make verify-framework`.

Template addition: `| **Framework Token Overhead** | {N}K tokens ({X}% of context) |`

### 7.2 CU Formula v2 (Gap #6)

Replace binary complexity factors with continuous signals:

| Factor | v1 | v2 | Signal Source |
|--------|----|----|---------------|
| Has UI | +0.3 binary | +0.15/+0.30/+0.45 | View count: 1/2-3/4+ |
| Design Iterations | +0.15 flat/round | +0.10 to +0.25/round | Scope tier: text/layout/interaction/full |
| New Model/Service | +0.2 binary | +0.1/+0.2/+0.3 | New types: 1-2/3-5/6+ |
| Architectural Novelty | Not tracked | +0.2 | First-of-kind (no cache entry) |

**State schema addition — `complexity` object:**

```json
"complexity": {
  "type": "object",
  "properties": {
    "cu_version": { "type": "integer", "default": 2 },
    "view_count": { "type": "integer", "default": 0 },
    "new_types_count": { "type": "integer", "default": 0 },
    "design_iteration_details": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "round": { "type": "integer" },
          "scope": { "type": "string", "enum": ["text_only", "layout", "interaction", "full_redesign"] },
          "weight": { "type": "number" }
        }
      }
    },
    "is_first_of_kind": { "type": "boolean", "default": false },
    "computed_cu": { "type": ["number", "null"] },
    "factors_applied": {
      "type": "array",
      "items": { "type": "string" }
    }
  }
}
```

**Backward compatibility:** v1 CU values preserved. `cu_version` field distinguishes formulas. No retroactive recomputation.

### 7.3 Serial vs Parallel Decomposition (Gap #7)

New template section:
```
### Velocity Decomposition
| Metric | Value | How Computed |
|--------|-------|-------------|
| Serial velocity (min/CU) | | This feature's min/CU if run alone |
| Serial improvement vs baseline | | baseline / serial_velocity |
| Parallel features in session | | Count of concurrent features |
| Parallel throughput (CU/hour) | | Total CU / wall hours |
| Parallel speedup factor | | parallel_throughput / serial_throughput |
| Combined improvement | | serial_improvement × parallel_speedup |
```

Single-feature runs: parallel = 1, speedup = 1.0x. Combined = serial only.

Parallel context tracked via `timing.parallel_context` in state.json (defined in Slice 1).

### 7.4 Rolling Baseline (Gap #8)

Every case study reports 3 baselines:

```
### Baseline Comparisons
| Comparison | Value |
|-----------|-------|
| vs Historical (Onboarding v2, 15.2 min/CU) | {+/-}% |
| vs Rolling (last 5 features, {X} min/CU) | {+/-}% |
| vs Same-Type (last 3 {work_type}, {X} min/CU) | {+/-}% |
```

Rolling baselines stored in `cache-metrics.json` (extends the schema defined in Section 5.2):
```json
"rolling_baselines": {
  "last_5_features": { "avg_min_cu": 0.0, "features": [] },
  "by_work_type": {
    "feature": { "last_3_avg": 0.0, "features": [] },
    "enhancement": { "last_3_avg": 0.0, "features": [] },
    "refactor": { "last_3_avg": 0.0, "features": [] }
  }
}
```

### 7.5 Normalization Framework v2 Section

Appended to `normalization-framework.md` (v1 section preserved):

```markdown
## v2 Normalization (Framework v6.0+)

### Changes from v1
- CU factors: continuous (view count, type count, scope tiers)
- New factor: Architectural novelty (+0.2 for first-of-kind)
- Velocity annotation: cache hit rate context
- time_source flag: measured vs estimated
- Parallel decomposition: serial × parallel (explicit)
- Three baselines: historical, rolling, same-type
- cu_version field distinguishes formula versions

### Backward Compatibility
- v1 values preserved. No retroactive recomputation.
- Cross-version comparisons note formula version.
```

---

## 8. Files Changed Summary

| File | Change Type | Slice |
|------|------------|-------|
| `.claude/skills/pm-workflow/state-schema.json` | Edit (add timing, eval_results, complexity) | 1, 2, 3, 2nd |
| `.claude/skills/pm-workflow/SKILL.md` | Edit (add 4 protocols) | 1, 2, 3 |
| `docs/case-studies/case-study-template.md` | Edit (new fields, tables, sections) | 1, 2, 3, 2nd |
| `docs/case-studies/normalization-framework.md` | Edit (append v2 section) | 2nd |
| `Makefile` | Edit (add verify-framework, verify-evals, verify-timing) | 1, 2, 3 |
| `.claude/shared/cache-metrics.json` | New file | 2 |
| `.claude/shared/token-budget.json` | New file | 2nd |
| `scripts/count-framework-tokens.sh` | New file | 2nd |
| `.claude/features/{name}/cache-hits.json` | New file pattern | 2 |

---

## 9. Success Metrics

### Primary Metric
- **Measurement precision improvement**: % of DVs that move from "estimated/inferred" to "measured/deterministic"
- Baseline: 2/9 DVs are currently deterministic (defect count, test density)
- Target: 8/9 DVs deterministic after v6.0 (defect escape rate remains inherently manual)
- Kill criteria: If < 5/9 DVs become deterministic after full implementation, the instrumentation overhead exceeds its value

### Secondary Metrics
- Case study writing time: should not increase (monitoring auto-sync saves manual effort)
- Framework token overhead: stays below 5% of context window (75K tokens for 1M context)
- CU v2 inter-rater reliability: two independent computations of the same feature's CU should agree within 10%

### Guardrails (must not degrade)
- PM workflow execution speed: no added latency from instrumentation
- Existing case study validity: v1 data unchanged
- CI pass rate: new targets are soft gates (warn, don't block) until validated

---

## 10. Task Breakdown (Preview)

Detailed tasks will be defined in the Tasks phase. High-level estimate:

| Slice | Tasks (est.) | Type |
|-------|-------------|------|
| Slice 1 — Phase Timing | 4 | Schema, protocol, template, CI |
| Slice 2 — Cache Tracking | 5 | Schema, new files, protocol, template, CI |
| Slice 3 — Eval Gates + Monitoring | 5 | Schema, gate protocol, sync protocol, template, CI |
| Second Pass — Token/CU/Baseline | 6 | Script, schema, normalization doc, template, decomposition, baselines |
| Case Study (self-referential) | 2 | Open case study, write final case study |
| **Total** | **~22** | |

---

## 11. Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Instrumentation overhead slows PM workflow | Low | Medium | All logging is append-only JSON writes; no blocking operations |
| CU v2 produces incomparable values to v1 | Medium | High | `cu_version` field; v1 preserved; no retroactive changes |
| Token counter tokenizer mismatch | Low | Low | tiktoken cl100k_base is within ~5% of Claude's tokenizer for English |
| Eval gate blocks legitimate features | Medium | Medium | User override with justification; non-AI features auto-pass |
| Monitoring sync adds noise to case-study-monitoring.json | Low | Low | Auto-sync uses structured fields, not freeform; snapshots labeled "auto-sync" |
