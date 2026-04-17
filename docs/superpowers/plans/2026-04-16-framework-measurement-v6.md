# Framework Measurement v6.0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade the PM framework's measurement infrastructure from narrative-estimated to instrumented-deterministic across 8 dimensions identified in the meta-analysis.

**Architecture:** Four layers (instrumentation → CI → normalization model → case study template) built vertically across 3 priority slices + 1 second pass. Zero Swift code — all JSON schemas, Markdown, Makefile targets, and one shell script.

**Tech Stack:** JSON Schema (draft-07), GNU Make, Python (tiktoken), Markdown

**Spec:** `docs/superpowers/specs/2026-04-16-framework-measurement-v6-design.md`

---

## File Structure

| File | Responsibility | Slice |
|------|---------------|-------|
| `.claude/skills/pm-workflow/state-schema.json` | Feature lifecycle schema — adding `timing`, `eval_results`, `complexity` | 1, 3, 2nd |
| `.claude/skills/pm-workflow/SKILL.md` | PM workflow protocols — adding 4 new protocols | 1, 2, 3 |
| `docs/case-studies/case-study-template.md` | Case study structure — new fields, tables, sections | 1, 2, 3, 2nd |
| `docs/case-studies/normalization-framework.md` | CU formula + trend data — appending v2 section | 2nd |
| `Makefile` | CI targets — adding `verify-framework`, `verify-evals`, `verify-timing` | 1, 2, 3 |
| `.claude/shared/cache-metrics.json` | Rolling cache aggregate across features (new file) | 2 |
| `.claude/shared/token-budget.json` | Token counts per framework layer (new file) | 2nd |
| `scripts/count-framework-tokens.sh` | Tokenizer script (new file) | 2nd |

---

## SLICE 1 — Phase Timing Instrumentation

### Task 1: Add `timing` object to state schema

**Files:**
- Modify: `.claude/skills/pm-workflow/state-schema.json:139-141` (before closing `}`)

- [ ] **Step 1: Read the current schema to confirm insertion point**

Open `.claude/skills/pm-workflow/state-schema.json`. The file ends at line 142-143 with:
```json
    }
  }
}
```
The `timing` property goes inside `"properties"` at the same level as `"feature"`, `"created"`, `"phases"`, etc. — that means inserting before the final closing of the `"properties"` object (line 140).

- [ ] **Step 2: Add the `timing` property to the schema**

Insert after the `"phases"` property block (after line 140, before the closing `}`):

```json
    ,
    "timing": {
      "type": "object",
      "description": "Precise timing instrumentation. Added in v6.0. Optional — old features default to estimated.",
      "properties": {
        "session_start": { "type": ["string", "null"], "format": "date-time" },
        "session_end": { "type": ["string", "null"], "format": "date-time" },
        "total_wall_time_minutes": { "type": ["number", "null"] },
        "time_source": {
          "type": "string",
          "enum": ["measured", "estimated"],
          "default": "estimated",
          "description": "Whether wall time comes from instrumented timestamps or narrative estimate"
        },
        "phases": {
          "type": "object",
          "description": "Per-phase start/end times. Keys are phase names (research, prd, tasks, etc.)",
          "additionalProperties": {
            "type": "object",
            "properties": {
              "started_at": { "type": "string", "format": "date-time" },
              "ended_at": { "type": ["string", "null"], "format": "date-time" },
              "duration_minutes": { "type": ["number", "null"] },
              "paused_minutes": {
                "type": ["number", "null"],
                "default": 0,
                "description": "Practitioner-reported pause time. On session resume, PM workflow asks how long the break was."
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
          "description": "Tracks concurrent features for serial vs parallel decomposition.",
          "properties": {
            "concurrent_features": { "type": "integer", "default": 1 },
            "concurrent_feature_slugs": { "type": "array", "items": { "type": "string" } },
            "is_stress_test": { "type": "boolean", "default": false }
          }
        }
      }
    }
```

- [ ] **Step 3: Validate the JSON is syntactically correct**

Run: `python3 -c "import json; json.load(open('.claude/skills/pm-workflow/state-schema.json'))"`

Expected: No output (success). If `json.decoder.JSONDecodeError`, check comma placement.

- [ ] **Step 4: Commit**

```bash
git add .claude/skills/pm-workflow/state-schema.json
git commit -m "feat(v6.0): add timing object to state schema — phase start/end, sessions, parallel context"
```

---

### Task 2: Add Phase Timing Protocol to SKILL.md

**Files:**
- Modify: `.claude/skills/pm-workflow/SKILL.md` (insert after Mirror Pattern section, ~line 150)

- [ ] **Step 1: Read SKILL.md to find the insertion point**

Look for the end of the "Mirror Pattern" section (around line 150: `- Files under 50 lines (overhead exceeds benefit)`). The new protocol goes after this line and before `## Result Forwarding Protocol`.

- [ ] **Step 2: Insert the Phase Timing Protocol**

Add between the Mirror Pattern section end and the Result Forwarding Protocol section:

```markdown
## Phase Timing Protocol (v6.0 — Measurement Instrumentation)

Every phase transition now records precise timestamps in `state.json → timing`. This replaces estimated wall times with measured durations.

### On Phase Start (after user approves transition)

1. Write `timing.phases[{phase}].started_at` = current ISO 8601 timestamp
2. If this is the **first phase** of the feature, also write `timing.session_start` = now
3. If resuming after a break, ask the user: "How long were you away?" and add the answer to the previous phase's `paused_minutes`

### On Phase End (before requesting next transition approval)

1. Write `timing.phases[{phase}].ended_at` = current ISO 8601 timestamp
2. Compute `timing.phases[{phase}].duration_minutes` = `(ended_at - started_at)` in minutes
3. Update `state.json → updated` timestamp

### On Feature Completion (current_phase → "complete")

1. Write `timing.session_end` = current ISO 8601 timestamp
2. Compute `timing.total_wall_time_minutes` = sum of all `timing.phases[*].duration_minutes`
3. Set `timing.time_source` = `"measured"`

### Multi-Session Features

If a feature spans multiple conversations/sessions:
1. On session start: append a new entry to `timing.sessions[]` with `started_at` = now and `phases_active` = [current phase]
2. On session end: write `ended_at` and compute `duration_minutes` for the current session entry
3. `timing.total_wall_time_minutes` = sum of all `timing.sessions[*].duration_minutes`

### Parallel Features

When multiple features are being worked on concurrently (stress tests, parallel dispatch):
1. Set `timing.parallel_context.concurrent_features` = count of active features
2. Set `timing.parallel_context.concurrent_feature_slugs` = list of other feature slugs
3. Set `timing.parallel_context.is_stress_test` = true if this is a deliberate parallel test
```

- [ ] **Step 3: Verify the file is well-formed Markdown**

Skim the inserted section. Confirm no broken heading hierarchy (## level matches other protocol sections). Confirm no orphaned code blocks.

- [ ] **Step 4: Commit**

```bash
git add .claude/skills/pm-workflow/SKILL.md
git commit -m "feat(v6.0): add phase timing protocol to PM workflow — measured start/end/pause/sessions"
```

---

### Task 3: Update case study template with timing fields

**Files:**
- Modify: `docs/case-studies/case-study-template.md:11-25` (Summary Card)
- Modify: `docs/case-studies/case-study-template.md:34-43` (Dependent Variables)
- Modify: `docs/case-studies/case-study-template.md:66-79` (Phase Timing table)

- [ ] **Step 1: Update the Summary Card (Section 1)**

Replace lines 19-20:
```markdown
| **Wall Time** | {total hours} |
```
with:
```markdown
| **Wall Time** | {total hours} ({measured/estimated}) |
| **Active Work Time** | {hours excluding pauses} |
| **Longest Phase** | {phase name}: {minutes} |
```

- [ ] **Step 2: Update the Dependent Variables table (Section 2)**

Replace line 36:
```markdown
| Wall time | hours | Phase timestamps from state.json transitions[] |
```
with:
```markdown
| Wall time | hours | timing.total_wall_time_minutes from state.json ({measured/estimated}) |
```

Add after the existing DV rows (after line 43):
```markdown
| Serial improvement | multiplier | baseline_min_CU / this_feature_min_CU |
| Parallel speedup | multiplier | parallel_CU_per_hour / serial_CU_per_hour |
```

- [ ] **Step 3: Enhance the Phase Timing raw data table (Section 3)**

Replace lines 66-79:
```markdown
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
```
with:
```markdown
### Phase Timing

> Data source: `state.json → timing.phases`. Mark `(e)` for estimated, `(m)` for measured.

| Phase | Started | Ended | Duration (min) | Paused (min) | Active (min) | Source |
|-------|---------|-------|----------------|--------------|--------------|--------|
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
```

- [ ] **Step 4: Commit**

```bash
git add docs/case-studies/case-study-template.md
git commit -m "feat(v6.0): update case study template — measured timing, active work, phase breakdown"
```

---

### Task 4: Add `verify-timing` target to Makefile

**Files:**
- Modify: `Makefile:5` (.PHONY line)
- Modify: `Makefile:37` (verify-local target)
- Add new target after line 46

- [ ] **Step 1: Add verify-timing to .PHONY**

Update line 5 from:
```makefile
.PHONY: tokens tokens-check install verify-local verify-web verify-ai verify-ios app-icon app-store-check
```
to:
```makefile
.PHONY: tokens tokens-check install verify-local verify-web verify-ai verify-ios verify-timing verify-framework verify-evals app-icon app-store-check
```

(Adding all three new targets now to avoid editing this line 3 times.)

- [ ] **Step 2: Add the verify-timing target**

Insert after the `verify-ios` target (after line 69, before the app-icon section):

```makefile
# ── Framework Measurement v6.0 Verification ──────
# Soft gates: warn but don't block. These become hard gates after validation.

verify-timing:
	@echo "=== Timing Instrumentation Check ==="
	@for dir in .claude/features/*/; do \
		state="$$dir/state.json"; \
		if [ -f "$$state" ]; then \
			phase=$$(python3 -c "import json; print(json.load(open('$$state')).get('current_phase',''))" 2>/dev/null); \
			if [ "$$phase" = "complete" ]; then \
				has_timing=$$(python3 -c "import json; d=json.load(open('$$state')); print('yes' if d.get('timing',{}).get('time_source')=='measured' else 'no')" 2>/dev/null); \
				feature=$$(basename "$$dir"); \
				if [ "$$has_timing" = "no" ]; then \
					echo "  ⚠  $$feature: complete but timing.time_source != measured (estimated)"; \
				else \
					echo "  ✓  $$feature: timing instrumented"; \
				fi; \
			fi; \
		fi; \
	done
	@echo "Done."
```

- [ ] **Step 3: Verify Makefile syntax**

Run: `make -n verify-timing`

Expected: Prints the echo commands without errors. If `*** missing separator`, check that indentation uses tabs (not spaces).

- [ ] **Step 4: Commit**

```bash
git add Makefile
git commit -m "feat(v6.0): add verify-timing, verify-framework, verify-evals to Makefile .PHONY"
```

---

## SLICE 2 — Cache Hit Tracking

### Task 5: Create `cache-metrics.json` shared aggregate

**Files:**
- Create: `.claude/shared/cache-metrics.json`

- [ ] **Step 1: Create the file**

```json
{
  "version": "1.0",
  "updated": "2026-04-16T00:00:00Z",
  "description": "Rolling cache hit rate aggregate across features. Updated on feature completion. Added in v6.0.",
  "by_framework_version": {
    "v5.2": {
      "features_measured": 0,
      "avg_hit_rate": 0.0,
      "L1_avg": 0.0,
      "L2_avg": 0.0,
      "L3_avg": 0.0,
      "top_entries_by_hits": [],
      "top_misses_by_cost": []
    },
    "v6.0": {
      "features_measured": 0,
      "avg_hit_rate": 0.0,
      "L1_avg": 0.0,
      "L2_avg": 0.0,
      "L3_avg": 0.0,
      "top_entries_by_hits": [],
      "top_misses_by_cost": []
    }
  },
  "promotion_candidates": [],
  "cache_health_trend": [],
  "rolling_baselines": {
    "last_5_features": {
      "avg_min_cu": 0.0,
      "features": []
    },
    "by_work_type": {
      "feature": { "last_3_avg": 0.0, "features": [] },
      "enhancement": { "last_3_avg": 0.0, "features": [] },
      "refactor": { "last_3_avg": 0.0, "features": [] },
      "fix": { "last_3_avg": 0.0, "features": [] },
      "chore": { "last_3_avg": 0.0, "features": [] }
    }
  }
}
```

- [ ] **Step 2: Validate JSON**

Run: `python3 -c "import json; json.load(open('.claude/shared/cache-metrics.json'))"`

Expected: No output (success).

- [ ] **Step 3: Commit**

```bash
git add .claude/shared/cache-metrics.json
git commit -m "feat(v6.0): create cache-metrics.json — rolling hit rate aggregate + rolling baselines"
```

---

### Task 6: Add Cache Tracking Protocol to SKILL.md

**Files:**
- Modify: `.claude/skills/pm-workflow/SKILL.md` (insert after Phase Timing Protocol)

- [ ] **Step 1: Find insertion point**

The Phase Timing Protocol (added in Task 2) ends with the "Parallel Features" subsection. Insert the new protocol immediately after it, before `## Result Forwarding Protocol`.

- [ ] **Step 2: Insert the Cache Tracking Protocol**

```markdown
## Cache Tracking Protocol (v6.0 — Deterministic Hit Logging)

Replace probabilistic cache health checks with deterministic per-event logging. Every cache access is recorded in `.claude/features/{feature}/cache-hits.json`.

### On Skill Load (reading from .claude/cache/{skill}/)

1. Check if a cache entry exists for the current task type and context
2. **HIT**: Append to `cache-hits.json → sessions[current].hits[]`:
   ```json
   {
     "timestamp": "{ISO 8601}",
     "cache_level": "L1|L2|L3",
     "skill": "{skill-name}",
     "cache_key": "{skill}:{task_type}:{context}",
     "hit_type": "exact|adapted",
     "task_context": "{task description from tasks list}"
   }
   ```
3. **MISS**: Append to `cache-hits.json → sessions[current].misses[]`:
   ```json
   {
     "timestamp": "{ISO 8601}",
     "cache_level": "L1|L2|L3",
     "skill": "{skill-name}",
     "expected_key": "{key that was looked up}",
     "miss_reason": "no_entry|stale|wrong_context",
     "task_context": "{task description}"
   }
   ```
4. **STALE** (SHA256 of source file doesn't match `invalidated_by` hash): Log as miss with `miss_reason: "stale"`

### Hit Type Taxonomy

- `exact`: Cache entry used directly without modification
- `adapted`: Cache entry used as a starting point but modified for current context
- `stale`: Entry existed but was outdated — counted as a miss

### On Phase Completion

1. Compute session summary: count L1/L2/L3 hits and misses
2. Write `total_hit_rate = total_hits / (total_hits + total_misses)` to session summary

### On Feature Completion

1. Finalize `aggregate` section in `cache-hits.json` (totals across all sessions)
2. Identify `most_valuable_hit` (entry that saved the most rework) and `costliest_miss` (pattern that had to be built from scratch)
3. Update `.claude/shared/cache-metrics.json`:
   - Increment `by_framework_version[current].features_measured`
   - Recompute `avg_hit_rate` and `L1_avg/L2_avg/L3_avg`
   - Add to `cache_health_trend[]` with date and hit rate
4. Check promotion candidates: any L1 entry hit by 2+ different skills → add to `promotion_candidates[]`

### Velocity Annotation

When writing the case study, annotate velocity claims based on cache hit rate:
- `hit_rate >= 0.6`: velocity is framework-attributable (no annotation needed)
- `hit_rate 0.3–0.6`: annotate as "partial cache" — velocity partially reflects practitioner skill
- `hit_rate < 0.3`: annotate as "cold cache" — velocity may significantly reflect practitioner skill over framework

This annotation does NOT change the CU calculation. It adds interpretive context to min/CU comparisons.
```

- [ ] **Step 3: Commit**

```bash
git add .claude/skills/pm-workflow/SKILL.md
git commit -m "feat(v6.0): add cache tracking protocol — deterministic L1/L2/L3 hit logging + velocity annotation"
```

---

### Task 7: Update case study template with cache fields

**Files:**
- Modify: `docs/case-studies/case-study-template.md` (Summary Card + new table)

- [ ] **Step 1: Update the Summary Card**

Find the existing line:
```markdown
| **Cache Hit Rate** | {percentage} |
```
Replace with:
```markdown
| **Cache Hit Rate** | {percentage} (L1: {%}, L2: {%}, L3: {%}) — {measured/inferred} |
```

- [ ] **Step 2: Update the Cache Hits raw data table (Section 3)**

Find the existing table:
```markdown
### Cache Hits During Execution

| Cache Entry | Level | What It Provided | Time Saved (est.) |
|-------------|-------|-----------------|-------------------|
| | | | |
```
Replace with:
```markdown
### Cache Performance (v6.0)

> Data source: `.claude/features/{name}/cache-hits.json`. Mark `(m)` for measured, `(i)` for inferred.

| Level | Hits | Misses | Hit Rate | Most Valuable Hit | Costliest Miss | Source |
|-------|------|--------|----------|-------------------|----------------|--------|
| L1    |      |        |          |                   |                | (m/i)  |
| L2    |      |        |          |                   |                | (m/i)  |
| L3    |      |        |          |                   |                | (m/i)  |
| **Total** | | |      |                   |                |        |

### Cache Hit Detail Log

| Timestamp | Level | Skill | Key | Type | Task Context |
|-----------|-------|-------|-----|------|-------------|
| | | | | exact/adapted | |

### Cache Miss Detail Log

| Timestamp | Level | Skill | Expected Key | Reason | Task Context |
|-----------|-------|-------|-------------|--------|-------------|
| | | | | no_entry/stale/wrong_context | |
```

- [ ] **Step 3: Commit**

```bash
git add docs/case-studies/case-study-template.md
git commit -m "feat(v6.0): update case study template — L1/L2/L3 cache breakdown, hit/miss detail logs"
```

---

### Task 8: Add `verify-framework` target to Makefile

**Files:**
- Modify: `Makefile` (add after verify-timing target)

- [ ] **Step 1: Add the target**

Insert after `verify-timing`:

```makefile
verify-framework:
	@echo "=== Framework Integrity Check ==="
	@echo "Cache metrics:"
	@test -f .claude/shared/cache-metrics.json && echo "  ✓ cache-metrics.json exists" || echo "  ⚠ cache-metrics.json MISSING"
	@python3 -c "import json; json.load(open('.claude/shared/cache-metrics.json'))" 2>/dev/null && echo "  ✓ cache-metrics.json valid JSON" || echo "  ⚠ cache-metrics.json invalid JSON"
	@echo "Per-feature cache tracking:"
	@for dir in .claude/features/*/; do \
		state="$$dir/state.json"; \
		cache="$$dir/cache-hits.json"; \
		if [ -f "$$state" ]; then \
			phase=$$(python3 -c "import json; print(json.load(open('$$state')).get('current_phase',''))" 2>/dev/null); \
			feature=$$(basename "$$dir"); \
			if [ "$$phase" = "complete" ]; then \
				if [ -f "$$cache" ]; then \
					echo "  ✓  $$feature: cache-hits.json present"; \
				else \
					echo "  ⚠  $$feature: complete but no cache-hits.json"; \
				fi; \
			fi; \
		fi; \
	done
	@echo "Cache index consistency:"
	@test -f .claude/cache/_index.json && echo "  ✓ _index.json exists" || echo "  ⚠ _index.json MISSING"
	@echo "Token budget:"
	@test -f .claude/shared/token-budget.json && echo "  ✓ token-budget.json exists" || echo "  ⚠ token-budget.json not yet generated (run scripts/count-framework-tokens.sh)"
	@echo "Done."
```

- [ ] **Step 2: Verify syntax**

Run: `make -n verify-framework`

Expected: Prints echo commands without errors.

- [ ] **Step 3: Commit**

```bash
git add Makefile
git commit -m "feat(v6.0): add verify-framework target — cache metrics, per-feature tracking, index consistency"
```

---

## SLICE 3 — Eval & Test Gates + Auto-Monitoring

### Task 9: Add `eval_results` and `min_eval_coverage_met` to state schema

**Files:**
- Modify: `.claude/skills/pm-workflow/state-schema.json` (inside `phases.testing.properties`)

- [ ] **Step 1: Find the testing phase properties**

In `state-schema.json`, locate the `"testing"` object (around line 86-95). It currently has: `status`, `ci_passed`, `tests_added`, `instrumentation_verified`, `analytics_tests_added`, `analytics_verification_passed`.

- [ ] **Step 2: Add eval_results and min_eval_coverage_met**

After `analytics_verification_passed` (line 94), add:

```json
            ,
            "eval_results": {
              "type": "object",
              "description": "Eval coverage for AI-touching features. Added in v6.0. Non-AI features: defaults (0/0), gate auto-passes.",
              "properties": {
                "total_evals": { "type": "integer", "default": 0 },
                "passing": { "type": "integer", "default": 0 },
                "failing": { "type": "integer", "default": 0 },
                "eval_pass_rate": { "type": ["number", "null"] },
                "categories": {
                  "type": "object",
                  "description": "Eval counts by category. Keys: golden_io, quality_heuristic, tier_behavior, edge_case, etc.",
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
                  "items": { "type": "string" },
                  "description": "AI behaviors identified in PRD that have no eval coverage yet"
                }
              }
            },
            "min_eval_coverage_met": {
              "type": "boolean",
              "default": false,
              "description": "Gate: true when every AI behavior has >= 1 eval. Non-AI features: auto-true."
            }
```

- [ ] **Step 3: Validate JSON**

Run: `python3 -c "import json; json.load(open('.claude/skills/pm-workflow/state-schema.json'))"`

Expected: No output (success).

- [ ] **Step 4: Commit**

```bash
git add .claude/skills/pm-workflow/state-schema.json
git commit -m "feat(v6.0): add eval_results + min_eval_coverage_met to testing phase schema"
```

---

### Task 10: Add Eval Coverage Gate Protocol to SKILL.md

**Files:**
- Modify: `.claude/skills/pm-workflow/SKILL.md` (insert after Cache Tracking Protocol)

- [ ] **Step 1: Insert the Eval Coverage Gate Protocol**

Add after the Cache Tracking Protocol (added in Task 6), before `## Result Forwarding Protocol`:

```markdown
## Eval Coverage Gate Protocol (v6.0 — AI Quality Assurance)

Ensures AI-touching features have verifiable eval coverage before shipping. Non-AI features auto-pass.

### During PRD Phase (AI-touching features only)

1. Identify all **AI behaviors** in the PRD:
   - Recommendations (nutrition, training, recovery)
   - Scoring (readiness, confidence, tier assignment)
   - Classification (cohort, goal-awareness, intensity selection)
   - Any output that depends on AI/ML logic
2. For each behavior, define minimum eval coverage:
   - **Golden I/O evals**: >= 3 per behavior (known-good input → expected output)
   - **Quality heuristic evals**: >= 2 per behavior (output meets quality bar)
   - **Tier/edge case evals**: >= 1 per behavior (boundary conditions)
3. Write the coverage plan to the PRD under `### Test & Eval Requirements`
4. Store the full behavior list in `state.json → phases.testing.eval_results.uncovered_behaviors`

### During Testing Phase

1. Run evals: `cd ai-engine && pytest evals/ -v`
2. Parse results and write to `state.json → phases.testing.eval_results`:
   - `total_evals`, `passing`, `failing`, `eval_pass_rate`
   - `categories` breakdown (golden_io, quality_heuristic, tier_behavior, etc.)
   - Update `uncovered_behaviors` — remove behaviors that now have evals
3. **Gate check**: `min_eval_coverage_met` = every behavior in the original list has >= 1 passing eval
4. If **gate fails**: BLOCK transition to Review phase
   - Display: "Eval gate failed: {N} behaviors still uncovered: {list}"
   - User can override with justification → record in `transitions[].note`: "Eval gate overridden: {reason}"
5. If **gate passes**: Set `min_eval_coverage_met = true`, proceed normally

### Non-AI Features

- `eval_results` stays at defaults (total_evals: 0, passing: 0)
- `min_eval_coverage_met` auto-set to `true`
- Gate does not block

### How to Detect AI-Touching Features

A feature touches AI if ANY of these are true:
- PRD references AIOrchestrator, ReadinessEngine, NutritionRecommender, TrainingRecommender, or CohortIntelligence
- `state.json → has_ui` is true AND the feature modifies views that display AI-generated content
- The task list includes changes to `ai-engine/` directory
- The PRD has a "### AI Behaviors" or "### Recommendation Logic" section
```

- [ ] **Step 2: Commit**

```bash
git add .claude/skills/pm-workflow/SKILL.md
git commit -m "feat(v6.0): add eval coverage gate protocol — blocks review phase if AI behaviors uncovered"
```

---

### Task 11: Add Monitoring Sync Protocol to SKILL.md

**Files:**
- Modify: `.claude/skills/pm-workflow/SKILL.md` (insert after Eval Coverage Gate)

- [ ] **Step 1: Insert the Monitoring Sync Protocol**

Add after the Eval Coverage Gate Protocol (added in Task 10):

```markdown
## Monitoring Sync Protocol (v6.0 — Auto-Update Case Study Monitoring)

Phase transitions automatically update `case-study-monitoring.json`. This replaces manual monitoring updates with structured, event-driven writes.

### Phase Transition Triggers

| Transition | Fields Updated in case-study-monitoring.json |
|-----------|----------------------------------------------|
| research → prd | `process_metrics.research_complete = true` |
| prd → tasks | `process_metrics.prd_approved = true` |
| tasks → implement | `process_metrics.tasks_defined = state.phases.tasks.count` |
| implement → testing | `process_metrics.repo_files_added` and `repo_files_updated` from `git diff --stat` |
| testing → review | `process_metrics.tests_passing`, `build_verified`, `ai_quality_metrics.eval_pass_rate`, `eval_total`, `eval_failed[]` |
| review → merge | `quality_metrics.critical_findings`, `high_findings`, `medium_findings` from review |
| merge → docs | `process_metrics.merged = true`, `pr_number` from state.json |
| docs → complete | Add snapshot with label `"feature-complete-auto-{ISO 8601}"`, write `timing.total_wall_time_minutes` |

### Snapshot Protocol

Every auto-sync also adds a snapshot entry:
```json
{
  "timestamp": "{ISO 8601}",
  "label": "auto-sync-{from_phase}-to-{to_phase}",
  "metrics": { /* current metrics at time of transition */ }
}
```

### Fallback

If `case-study-monitoring.json` does not have an entry for the current feature:
1. Create one with the feature slug as `case_id`
2. Set `status: "in_progress"`, `framework_version`, `work_type` from state.json
3. Then proceed with the sync

### Manual Override

The auto-sync writes structured fields only. Narrative notes, decisions, and custom metrics are still added manually. Auto-synced snapshots are labeled with `auto-sync-` prefix to distinguish them from manually written ones.
```

- [ ] **Step 2: Commit**

```bash
git add .claude/skills/pm-workflow/SKILL.md
git commit -m "feat(v6.0): add monitoring sync protocol — auto-update case-study-monitoring.json on phase transitions"
```

---

### Task 12: Update case study template with eval fields

**Files:**
- Modify: `docs/case-studies/case-study-template.md` (Summary Card + eval table)

- [ ] **Step 1: Update Summary Card**

After the Cache Hit Rate line (updated in Task 7), find:
```markdown
| **Eval Pass Rate** | {N/N} |
```
Replace with:
```markdown
| **Eval Pass Rate** | {N/N} ({N} behaviors, {M} evals) — {N uncovered} |
| **Monitoring Sync** | auto / manual |
```

- [ ] **Step 2: Enhance the Eval Results table (Section 3)**

Find the existing table:
```markdown
### Eval Results (v4.4+)

| Eval File | Tests | Pass | Fail | Notes |
|-----------|-------|------|------|-------|
| | | | | |
```
Replace with:
```markdown
### Eval Results (v6.0)

> Data source: `state.json → phases.testing.eval_results`

#### Coverage by AI Behavior

| Behavior | Golden I/O | Quality Heuristic | Tier/Edge | Total | Pass Rate | Covered? |
|----------|-----------|-------------------|-----------|-------|-----------|----------|
| | | | | | | ✓/✗ |

#### Eval Detail

| Eval File | Category | Tests | Pass | Fail | Notes |
|-----------|----------|-------|------|------|-------|
| | golden_io/quality_heuristic/tier_behavior | | | | |

#### Gate Status

- `min_eval_coverage_met`: {true/false}
- Uncovered behaviors: {list or "none"}
- Override: {yes — reason / no}
```

- [ ] **Step 3: Commit**

```bash
git add docs/case-studies/case-study-template.md
git commit -m "feat(v6.0): update case study template — eval coverage per behavior, gate status, monitoring sync"
```

---

### Task 13: Add `verify-evals` target to Makefile

**Files:**
- Modify: `Makefile` (add after verify-framework, update verify-local)

- [ ] **Step 1: Add the target**

Insert after `verify-framework`:

```makefile
verify-evals:
	@echo "=== AI Eval Suite ==="
	@if [ -d "ai-engine/evals" ]; then \
		cd ai-engine && . $(AI_VENV)/bin/activate && pytest evals/ -v --tb=short; \
	else \
		echo "  ⚠ ai-engine/evals/ directory not found — skipping"; \
	fi
```

- [ ] **Step 2: Update verify-local to include all new targets**

Replace line 37:
```makefile
verify-local: tokens-check verify-web verify-ai verify-ios
```
with:
```makefile
verify-local: tokens-check verify-web verify-ai verify-evals verify-ios verify-timing verify-framework
```

- [ ] **Step 3: Verify syntax**

Run: `make -n verify-local`

Expected: Shows all targets in dependency order without errors.

- [ ] **Step 4: Commit**

```bash
git add Makefile
git commit -m "feat(v6.0): add verify-evals target, update verify-local to include all v6.0 gates"
```

---

## SECOND PASS — Token Counting, CU v2, Baselines

### Task 14: Create token counting script

**Files:**
- Create: `scripts/count-framework-tokens.sh`
- Create: `.claude/shared/token-budget.json`

- [ ] **Step 1: Verify tiktoken is available**

Run: `python3 -c "import tiktoken; print(tiktoken.encoding_for_model('gpt-4').name)"`

If ModuleNotFoundError: `pip3 install tiktoken`

Expected: `cl100k_base`

- [ ] **Step 2: Create the script**

Write to `scripts/count-framework-tokens.sh`:

```bash
#!/usr/bin/env bash
# count-framework-tokens.sh — Counts tokens across framework layers
# Output: .claude/shared/token-budget.json
# Requires: python3 with tiktoken installed
# Usage: bash scripts/count-framework-tokens.sh

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT="$PROJECT_ROOT/.claude/shared/token-budget.json"

python3 << 'PYEOF'
import json
import os
import glob
from datetime import datetime, timezone

try:
    import tiktoken
    enc = tiktoken.encoding_for_model("gpt-4")
except ImportError:
    print("ERROR: tiktoken not installed. Run: pip3 install tiktoken")
    exit(1)

project_root = os.environ.get("PROJECT_ROOT", os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

def count_tokens_in_files(pattern):
    """Count tokens across all files matching a glob pattern."""
    files = glob.glob(pattern, recursive=True)
    total = 0
    count = 0
    for f in files:
        if os.path.isfile(f):
            try:
                with open(f, "r", encoding="utf-8", errors="ignore") as fh:
                    total += len(enc.encode(fh.read()))
                count += 1
            except Exception:
                pass
    return count, total

layers = {}

# Layer 1: Skills
files, tokens = count_tokens_in_files(os.path.join(project_root, ".claude/skills/*/SKILL.md"))
layers["skills"] = {"files": files, "tokens": tokens}

# Layer 2: Cache
files, tokens = count_tokens_in_files(os.path.join(project_root, ".claude/cache/**/*.json"))
layers["cache"] = {"files": files, "tokens": tokens}

# Layer 3: Shared config
files, tokens = count_tokens_in_files(os.path.join(project_root, ".claude/shared/*.json"))
layers["shared"] = {"files": files, "tokens": tokens}

# Layer 4: Adapters
files, tokens = count_tokens_in_files(os.path.join(project_root, ".claude/integrations/**/*"))
layers["adapters"] = {"files": files, "tokens": tokens}

total_tokens = sum(l["tokens"] for l in layers.values())
for key in layers:
    layers[key]["pct_of_total"] = round(layers[key]["tokens"] / total_tokens, 4) if total_tokens > 0 else 0.0

output = {
    "measured_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "model": "claude-opus-4-6",
    "tokenizer": "tiktoken-cl100k_base",
    "layers": layers,
    "total_tokens": total_tokens,
    "context_budget_pct": round(total_tokens / 1_000_000, 6)
}

output_path = os.path.join(project_root, ".claude/shared/token-budget.json")
with open(output_path, "w") as f:
    json.dump(output, f, indent=2)

print(f"Token budget written to {output_path}")
print(f"  Skills:   {layers['skills']['tokens']:>8,} tokens ({layers['skills']['files']} files)")
print(f"  Cache:    {layers['cache']['tokens']:>8,} tokens ({layers['cache']['files']} files)")
print(f"  Shared:   {layers['shared']['tokens']:>8,} tokens ({layers['shared']['files']} files)")
print(f"  Adapters: {layers['adapters']['tokens']:>8,} tokens ({layers['adapters']['files']} files)")
print(f"  TOTAL:    {total_tokens:>8,} tokens ({round(total_tokens/1000, 1)}K, {output['context_budget_pct']*100:.2f}% of 1M context)")
PYEOF
```

- [ ] **Step 3: Make executable and run**

Run:
```bash
chmod +x scripts/count-framework-tokens.sh
PROJECT_ROOT=/Volumes/DevSSD/FitTracker2 bash scripts/count-framework-tokens.sh
```

Expected: Output showing token counts per layer and a new `.claude/shared/token-budget.json` file.

- [ ] **Step 4: Verify the output**

Run: `python3 -c "import json; d=json.load(open('.claude/shared/token-budget.json')); print(json.dumps(d, indent=2))"`

Expected: Valid JSON with non-zero token counts for at least the skills and shared layers.

- [ ] **Step 5: Commit**

```bash
git add scripts/count-framework-tokens.sh .claude/shared/token-budget.json
git commit -m "feat(v6.0): add token counting script + initial token-budget.json — tiktoken cl100k_base"
```

---

### Task 15: Add `complexity` object to state schema (CU v2)

**Files:**
- Modify: `.claude/skills/pm-workflow/state-schema.json` (add after `timing` property)

- [ ] **Step 1: Add the complexity property**

Insert after the `timing` property (added in Task 1), at the same level inside `"properties"`:

```json
    ,
    "complexity": {
      "type": "object",
      "description": "Objective complexity signals for CU v2 calculation. Added in v6.0. Optional — old features use CU v1.",
      "properties": {
        "cu_version": { "type": "integer", "default": 2, "description": "1 = binary factors (v5.2 and earlier), 2 = continuous factors (v6.0+)" },
        "view_count": { "type": "integer", "default": 0, "description": "Number of distinct views/screens created or modified. Maps to UI factor: 1=+0.15, 2-3=+0.30, 4+=+0.45" },
        "new_types_count": { "type": "integer", "default": 0, "description": "New Swift structs/enums/classes/protocols. Maps to model factor: 1-2=+0.1, 3-5=+0.2, 6+=+0.3" },
        "design_iteration_details": {
          "type": "array",
          "description": "Each design iteration round with its scope tier and computed weight.",
          "items": {
            "type": "object",
            "properties": {
              "round": { "type": "integer" },
              "scope": { "type": "string", "enum": ["text_only", "layout", "interaction", "full_redesign"], "description": "text_only=+0.10, layout=+0.15, interaction=+0.20, full_redesign=+0.25" },
              "weight": { "type": "number" }
            }
          }
        },
        "is_first_of_kind": { "type": "boolean", "default": false, "description": "True if no cache entry exists for this pattern type. Adds +0.2 architectural novelty factor." },
        "computed_cu": { "type": ["number", "null"], "description": "Final CU value after applying all factors" },
        "factors_applied": {
          "type": "array",
          "items": { "type": "string" },
          "description": "Human-readable list of factors, e.g. ['ui:0.30 (3 views)', 'new_model:0.20 (4 types)', 'first_of_kind:0.20']"
        }
      }
    }
```

- [ ] **Step 2: Validate JSON**

Run: `python3 -c "import json; json.load(open('.claude/skills/pm-workflow/state-schema.json'))"`

Expected: No output (success).

- [ ] **Step 3: Commit**

```bash
git add .claude/skills/pm-workflow/state-schema.json
git commit -m "feat(v6.0): add complexity object to state schema — CU v2 continuous factors"
```

---

### Task 16: Append v2 section to normalization framework

**Files:**
- Modify: `docs/case-studies/normalization-framework.md` (append after Section 6)

- [ ] **Step 1: Read the end of the file to find insertion point**

The file currently ends at Section 6 "How to Apply in Future Case Studies" with a template code block.

- [ ] **Step 2: Append the v2 section**

Add at the end of the file:

```markdown

---

## 7. v2 Normalization (Framework v6.0+)

> Added 2026-04-16. v1 methodology (Sections 1-6) is preserved unchanged. v2 refines the inputs, not the formula.

### CU Formula (unchanged)

```
CU = Tasks × Work_Type_Weight × (1 + sum(Weighted_Factors))
```

### Changes from v1 — Complexity Factors

| Factor | v1 (binary/flat) | v2 (continuous) | Signal Source |
|--------|-----------------|-----------------|---------------|
| Has UI | +0.3 | +0.15 (1 view) / +0.30 (2-3) / +0.45 (4+) | `state.json → complexity.view_count` |
| Design Iterations | +0.15 per round | +0.10 (text) / +0.15 (layout) / +0.20 (interaction) / +0.25 (full redesign) per round | `state.json → complexity.design_iteration_details` |
| New Model/Service | +0.2 | +0.1 (1-2 types) / +0.2 (3-5) / +0.3 (6+) | `state.json → complexity.new_types_count` |
| Auth/External | +0.5 | +0.5 (unchanged) | Same binary flag |
| Runtime Testing | +0.4 | +0.4 (unchanged) | Same binary flag |
| Cross-Feature | +0.2 | +0.2 (unchanged) | Same binary flag |
| **Architectural Novelty** | Not tracked | **+0.2** | `state.json → complexity.is_first_of_kind` (no cache entry for this pattern) |

### New Reporting Requirements

1. **time_source flag**: Every velocity figure must note `(measured)` or `(estimated)`
2. **cu_version field**: `state.json → complexity.cu_version` (1 or 2)
3. **Velocity annotation**: Cache hit rate context (see Cache Tracking Protocol)
4. **Three baselines**:

| Comparison | Formula |
|-----------|---------|
| vs Historical Baseline | `15.2 / this_min_cu` (Onboarding v2, always reported) |
| vs Rolling Baseline | `mean(last 5 features min/CU) / this_min_cu` |
| vs Same-Type Baseline | `mean(last 3 same work_type min/CU) / this_min_cu` |

5. **Serial vs Parallel Decomposition** (for multi-feature sessions):

| Metric | Formula |
|--------|---------|
| Serial velocity | This feature's min/CU (CU / active minutes on this feature alone) |
| Serial improvement | `15.2 / serial_velocity` |
| Parallel speedup | `parallel_CU_per_hour / serial_CU_per_hour` |
| Combined improvement | `serial_improvement × parallel_speedup` |

Single-feature runs: `parallel_speedup = 1.0x`, `combined = serial`.

### Backward Compatibility

- v1 CU values are **preserved unchanged**. No retroactive recomputation.
- `cu_version` field distinguishes v1 (binary) from v2 (continuous) calculations.
- Cross-version comparisons must note which formula was used.
- Features without `complexity` object in state.json default to v1 calculation.
```

- [ ] **Step 3: Commit**

```bash
git add docs/case-studies/normalization-framework.md
git commit -m "feat(v6.0): append v2 normalization section — continuous CU factors, rolling baselines, serial/parallel decomposition"
```

---

### Task 17: Add velocity decomposition + baselines to case study template

**Files:**
- Modify: `docs/case-studies/case-study-template.md` (Section 5 — Normalized Velocity)

- [ ] **Step 1: Find the "This Feature" table in Section 5**

Locate the table starting with:
```markdown
### This Feature

| Metric | Value |
|---|---|
| Tasks | {N} |
```

- [ ] **Step 2: Add cu_version and time_source to the table**

After the existing row `| **min/CU** | **{velocity}** |`, add:
```markdown
| CU version | v1 (binary) / v2 (continuous) |
| Time source | measured / estimated |
| Cache hit rate | {%} — {framework-attributable / partial cache / cold cache} |
```

- [ ] **Step 3: Add Velocity Decomposition section after the Cross-Version Comparison table**

After the `*Home v2 excluded from trend` note, add:

```markdown
### Velocity Decomposition (v6.0)

| Metric | Value | How Computed |
|--------|-------|-------------|
| Serial velocity (min/CU) | | This feature's min/CU |
| Serial improvement vs baseline | | 15.2 / serial_velocity |
| Parallel features in session | | Count of concurrent features (1 = serial only) |
| Parallel throughput (CU/hour) | | Total CU across all features / wall time hours |
| Parallel speedup factor | | parallel_throughput / serial_throughput (1.0x if serial) |
| Combined improvement | | serial_improvement × parallel_speedup |

### Baseline Comparisons (v6.0)

| Comparison | Baseline Value | This Feature | Improvement |
|-----------|---------------|-------------|------------|
| vs Historical (Onboarding v2) | 15.2 min/CU | {min/CU} | {+/-}% |
| vs Rolling (last 5 features) | {X} min/CU | {min/CU} | {+/-}% |
| vs Same-Type (last 3 {type}) | {X} min/CU | {min/CU} | {+/-}% |
```

- [ ] **Step 4: Add token overhead to Summary Card**

Find the Summary Card and add after the Monitoring Sync line:
```markdown
| **Framework Token Overhead** | {N}K tokens ({X}% of context) |
| **CU Version** | v1 / v2 |
```

- [ ] **Step 5: Commit**

```bash
git add docs/case-studies/case-study-template.md
git commit -m "feat(v6.0): add velocity decomposition, 3 baselines, token overhead, CU version to template"
```

---

### Task 18: Wire token counting into verify-framework

**Files:**
- Modify: `Makefile` (add token counting to verify-framework)

- [ ] **Step 1: Update verify-framework target**

Add to the end of the `verify-framework` target (before the final `@echo "Done."`):

```makefile
	@echo "Token budget (run if stale):"
	@if [ -f .claude/shared/token-budget.json ]; then \
		age=$$(python3 -c "import json,datetime as dt; t=json.load(open('.claude/shared/token-budget.json'))['measured_at']; d=dt.datetime.now(dt.timezone.utc)-dt.datetime.fromisoformat(t.replace('Z','+00:00')); print(d.days)"); \
		if [ "$$age" -gt 7 ]; then \
			echo "  ⚠ token-budget.json is $$age days old — run: bash scripts/count-framework-tokens.sh"; \
		else \
			tokens=$$(python3 -c "import json; print(json.load(open('.claude/shared/token-budget.json'))['total_tokens'])"); \
			echo "  ✓ token-budget.json current ($$tokens tokens)"; \
		fi; \
	else \
		echo "  ⚠ token-budget.json not found — run: bash scripts/count-framework-tokens.sh"; \
	fi
```

- [ ] **Step 2: Commit**

```bash
git add Makefile
git commit -m "feat(v6.0): wire token budget staleness check into verify-framework"
```

---

### Task 19: Open the v6.0 case study + feature state

**Files:**
- Create: `.claude/features/framework-measurement-v6/state.json`
- Create: `.claude/features/framework-measurement-v6/cache-hits.json`

- [ ] **Step 1: Create the feature directory**

Run: `mkdir -p .claude/features/framework-measurement-v6`

- [ ] **Step 2: Create state.json with timing instrumentation active**

Write `.claude/features/framework-measurement-v6/state.json`:

```json
{
  "feature": "framework-measurement-v6",
  "created": "2026-04-16T14:00:00Z",
  "updated": "2026-04-16T14:00:00Z",
  "branch": "feature/framework-measurement-v6",
  "current_phase": "implement",
  "work_type": "feature",
  "has_ui": false,
  "requires_analytics": false,
  "github_issue_number": null,
  "phases": {
    "research": {
      "status": "approved",
      "approved_at": "2026-04-16T14:00:00Z",
      "sources": ["docs/case-studies/meta-analysis-2026-04-16.md"]
    },
    "prd": {
      "status": "approved",
      "approved_at": "2026-04-16T14:15:00Z",
      "analytics_spec_complete": false
    },
    "tasks": {
      "status": "approved",
      "count": 19
    },
    "ux_or_integration": {
      "status": "skipped",
      "type": "integration",
      "compliance_passed": null,
      "compliance_violations": [],
      "compliance_decision": null,
      "design_system_changes": []
    },
    "implementation": {
      "status": "in_progress",
      "commits": []
    },
    "testing": {
      "status": "pending",
      "ci_passed": false,
      "tests_added": 0,
      "instrumentation_verified": false,
      "analytics_tests_added": 0,
      "analytics_verification_passed": false,
      "eval_results": {
        "total_evals": 0,
        "passing": 0,
        "failing": 0,
        "eval_pass_rate": null,
        "categories": {},
        "uncovered_behaviors": []
      },
      "min_eval_coverage_met": true
    },
    "review": {
      "status": "pending",
      "risks": [],
      "ci_main": false,
      "ci_feature": false
    },
    "merge": {
      "status": "pending",
      "pr_number": null,
      "analytics_regression_passed": null
    },
    "documentation": {
      "status": "pending"
    },
    "metrics": {
      "primary": {
        "name": "measurement_precision_dvs_deterministic",
        "baseline": 2,
        "target": 8,
        "current": null
      },
      "secondary": [
        { "name": "case_study_writing_time", "baseline": null, "target": "no increase" },
        { "name": "framework_token_overhead_pct", "baseline": null, "target": 0.05 },
        { "name": "cu_v2_interrater_agreement", "baseline": null, "target": 0.90 }
      ],
      "guardrails": [
        { "name": "pm_workflow_latency", "threshold": "no added latency" },
        { "name": "existing_case_study_validity", "threshold": "v1 data unchanged" },
        { "name": "ci_pass_rate", "threshold": "soft gates only" }
      ],
      "instrumentation_ready": false,
      "first_review_date": null,
      "kill_criteria": "If < 5/9 DVs become deterministic after full implementation, instrumentation overhead exceeds value"
    }
  },
  "transitions": [
    {
      "from": null,
      "to": "research",
      "timestamp": "2026-04-16T14:00:00Z",
      "approved_by": "user",
      "note": "Meta-analysis identified 8 measurement gaps. Full feature lifecycle approved."
    },
    {
      "from": "research",
      "to": "prd",
      "timestamp": "2026-04-16T14:00:00Z",
      "approved_by": "user",
      "note": "Research = meta-analysis document. PRD = design spec."
    },
    {
      "from": "prd",
      "to": "tasks",
      "timestamp": "2026-04-16T14:15:00Z",
      "approved_by": "user",
      "note": "Spec approved. Approach C (vertical slices) selected."
    },
    {
      "from": "tasks",
      "to": "implementation",
      "timestamp": "2026-04-16T14:30:00Z",
      "approved_by": "user",
      "note": "19 tasks across 3 slices + second pass. Implementation plan written."
    }
  ],
  "timing": {
    "session_start": "2026-04-16T14:00:00Z",
    "session_end": null,
    "total_wall_time_minutes": null,
    "time_source": "measured",
    "phases": {
      "research": {
        "started_at": "2026-04-16T14:00:00Z",
        "ended_at": "2026-04-16T14:00:00Z",
        "duration_minutes": 0,
        "paused_minutes": 0
      },
      "prd": {
        "started_at": "2026-04-16T14:00:00Z",
        "ended_at": "2026-04-16T14:15:00Z",
        "duration_minutes": 15,
        "paused_minutes": 0
      },
      "tasks": {
        "started_at": "2026-04-16T14:15:00Z",
        "ended_at": "2026-04-16T14:30:00Z",
        "duration_minutes": 15,
        "paused_minutes": 0
      },
      "implementation": {
        "started_at": "2026-04-16T14:30:00Z",
        "ended_at": null,
        "duration_minutes": null,
        "paused_minutes": 0
      }
    },
    "sessions": [],
    "parallel_context": {
      "concurrent_features": 1,
      "concurrent_feature_slugs": [],
      "is_stress_test": false
    }
  },
  "complexity": {
    "cu_version": 2,
    "view_count": 0,
    "new_types_count": 0,
    "design_iteration_details": [],
    "is_first_of_kind": true,
    "computed_cu": null,
    "factors_applied": []
  }
}
```

- [ ] **Step 3: Create initial cache-hits.json**

Write `.claude/features/framework-measurement-v6/cache-hits.json`:

```json
{
  "feature": "framework-measurement-v6",
  "framework_version": "6.0",
  "sessions": [
    {
      "session_id": "2026-04-16T14:00:00Z",
      "hits": [],
      "misses": [],
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

- [ ] **Step 4: Validate both files**

Run:
```bash
python3 -c "import json; json.load(open('.claude/features/framework-measurement-v6/state.json'))"
python3 -c "import json; json.load(open('.claude/features/framework-measurement-v6/cache-hits.json'))"
```

Expected: No output (success) for both.

- [ ] **Step 5: Commit**

```bash
git add .claude/features/framework-measurement-v6/
git commit -m "feat(v6.0): open case study — state.json with timing + complexity, cache-hits.json initialized"
```

---

## VERIFICATION

### Task 20: Run all verification targets

- [ ] **Step 1: Run verify-timing**

Run: `make verify-timing`

Expected: Lists completed features and their timing status. The new `framework-measurement-v6` feature won't show (it's in `implement`, not `complete`).

- [ ] **Step 2: Run verify-framework**

Run: `make verify-framework`

Expected: Shows cache-metrics.json exists, token-budget.json exists (if Task 14 ran), completed features checked for cache-hits.json.

- [ ] **Step 3: Run verify-evals**

Run: `make verify-evals`

Expected: Either runs evals from `ai-engine/evals/` or prints skip message if directory doesn't exist.

- [ ] **Step 4: Validate the schema is internally consistent**

Run:
```bash
python3 -c "
import json
schema = json.load(open('.claude/skills/pm-workflow/state-schema.json'))
props = schema['properties']
assert 'timing' in props, 'timing missing'
assert 'complexity' in props, 'complexity missing'
testing = props['phases']['properties']['testing']['properties']
assert 'eval_results' in testing, 'eval_results missing'
assert 'min_eval_coverage_met' in testing, 'min_eval_coverage_met missing'
print('Schema validation PASSED — all v6.0 additions present')
"
```

Expected: `Schema validation PASSED — all v6.0 additions present`

- [ ] **Step 5: Verify the feature state.json validates against the schema structure**

Run:
```bash
python3 -c "
import json
state = json.load(open('.claude/features/framework-measurement-v6/state.json'))
assert state['timing']['time_source'] == 'measured'
assert state['complexity']['cu_version'] == 2
assert state['complexity']['is_first_of_kind'] == True
assert state['phases']['testing']['eval_results']['total_evals'] == 0
assert state['phases']['testing']['min_eval_coverage_met'] == True
print('State validation PASSED — v6.0 fields populated correctly')
"
```

Expected: `State validation PASSED — v6.0 fields populated correctly`

- [ ] **Step 6: Final commit with verification results**

```bash
git add -A
git commit -m "feat(v6.0): verification pass — all schema additions, Makefile targets, template updates validated"
```
