# Meta-Analysis Full-System Audit — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Run a 4-layer risk-weighted parallel audit of the entire FitMe codebase (143 Swift files, 37 services, 13 AI files, 21 test files, 69 framework configs), producing a structured findings database, a narrative case study, and a system health scorecard — all measured under v7.0 protocols.

**Architecture:** Layer 1 dispatches 6 domain agents in parallel for surface sweep. Layer 2 deep-dives flagged areas + high-risk files. Layer 3 cross-references findings against 18 case studies, UX foundations, and the framework itself. Layer 4 runs external validation (Xcode build/test already confirmed: BUILD SUCCEEDED, 231/231 pass, 0 failures).

**Tech Stack:** JSON (findings database), Markdown (case study), Bash (external validation scripts), Python (JSON validation)

**Spec:** `docs/superpowers/specs/2026-04-16-meta-analysis-full-system-audit-design.md`

**Baseline (pre-audit):** Build passes, 231 tests pass, 0 failures. This is the external validation anchor.

---

## File Structure

```
.claude/shared/
├── audit-findings.json              (CREATE — structured findings database)

.claude/features/meta-analysis-audit/
├── state.json                       (CREATE — v7.0 case study measurement)
├── layer1-ui.json                   (CREATE — Layer 1 UI agent findings)
├── layer1-backend.json              (CREATE — Layer 1 Backend agent findings)
├── layer1-ai.json                   (CREATE — Layer 1 AI agent findings)
├── layer1-design-system.json        (CREATE — Layer 1 Design System agent findings)
├── layer1-tests.json                (CREATE — Layer 1 Test agent findings)
├── layer1-framework.json            (CREATE — Layer 1 Framework agent findings)
├── layer2-deep-findings.json        (CREATE — Layer 2 merged deep-dive findings)
└── layer3-cross-reference.json      (CREATE — Layer 3 cross-reference + meta analysis)

docs/case-studies/
└── meta-analysis-full-system-audit-v7.0-case-study.md  (CREATE — narrative case study)
```

---

### Task 1: Setup — Case Study State + Findings Database Scaffold

**Files:**
- Create: `.claude/features/meta-analysis-audit/state.json`
- Create: `.claude/shared/audit-findings.json`

- [ ] **Step 1: Create the feature directory**

Run: `mkdir -p .claude/features/meta-analysis-audit`

- [ ] **Step 2: Create case study state.json**

```json
{
  "feature": "meta-analysis-audit",
  "display_name": "Meta-Analysis Full-System Audit",
  "work_type": "chore",
  "framework_version": "7.0",
  "phase": "implementation",
  "status": "in_progress",
  "created": "2026-04-16T00:00:00Z",
  "branch": "main",
  "spec": "docs/superpowers/specs/2026-04-16-meta-analysis-full-system-audit-design.md",
  "plan": "docs/superpowers/plans/2026-04-16-meta-analysis-full-system-audit.md",
  "timing": {
    "time_source": "measured",
    "session_start": "2026-04-16T00:00:00Z",
    "session_end": null,
    "phases": {
      "research": {
        "started_at": "2026-04-16T00:00:00Z",
        "ended_at": "2026-04-16T00:30:00Z",
        "duration_minutes": 30,
        "paused_minutes": 0,
        "notes": "Brainstorm: 4 approaches → risk-weighted parallel sweep selected"
      },
      "tasks": {
        "started_at": "2026-04-16T00:30:00Z",
        "ended_at": "2026-04-16T01:00:00Z",
        "duration_minutes": 30,
        "paused_minutes": 0,
        "notes": "Spec + plan written, baseline validated (231 tests pass)"
      },
      "implementation": {
        "started_at": "2026-04-16T01:00:00Z",
        "ended_at": null,
        "duration_minutes": null,
        "paused_minutes": 0,
        "notes": "4-layer audit execution"
      },
      "documentation": {
        "started_at": null,
        "ended_at": null,
        "duration_minutes": null,
        "paused_minutes": 0
      }
    },
    "parallel_context": {
      "concurrent_features": 0,
      "stress_test": true
    }
  },
  "complexity": {
    "cu_version": 2,
    "view_count": 0,
    "new_types_count": 0,
    "design_iteration_rounds": 0,
    "is_first_of_kind": true,
    "architectural_novelty": true,
    "computed_cu": 1.7,
    "factors_applied": [
      "base: 1.0",
      "first_of_kind: +0.2",
      "cross_feature_scope: +0.3",
      "architectural_novelty: +0.2"
    ]
  },
  "tasks": {
    "total": 8,
    "completed": 0,
    "in_progress": 0
  },
  "external_validation": {
    "build": "SUCCEEDED",
    "tests_passed": 231,
    "tests_failed": 0,
    "tests_skipped": 1,
    "baseline_date": "2026-04-16"
  }
}
```

- [ ] **Step 3: Create empty audit-findings.json scaffold**

```json
{
  "version": "1.0",
  "audit_date": "2026-04-16",
  "framework_version": "7.0",
  "methodology": "risk-weighted-parallel-sweep",
  "self_referential": true,
  "baseline": {
    "build": "SUCCEEDED",
    "tests_passed": 231,
    "tests_failed": 0,
    "swift_files": 143,
    "test_files": 21,
    "service_files": 37,
    "ai_files": 13,
    "framework_files": 69
  },
  "summary": {
    "total_findings": 0,
    "by_severity": { "critical": 0, "high": 0, "medium": 0, "low": 0, "info": 0 },
    "by_domain": { "ui": 0, "backend": 0, "ai": 0, "design_system": 0, "tests": 0, "framework": 0 },
    "by_validation": { "external-automated": 0, "external-manual": 0, "external-git": 0, "cross-referenced": 0, "framework-only": 0 },
    "by_layer": { "surface": 0, "deep": 0, "cross-reference": 0 }
  },
  "findings": [],
  "ux_compliance_matrix": {},
  "case_study_patterns": {
    "recurring": [],
    "regressions": [],
    "predicted": [],
    "new_categories": []
  },
  "framework_self_audit": {
    "config_consistency": null,
    "cache_staleness": null,
    "token_budget_accurate": null,
    "skill_routing_valid": null,
    "hadf_integrity": null,
    "bias_risk_findings": []
  }
}
```

- [ ] **Step 4: Validate and commit**

Run:
```bash
python3 -c "import json; json.load(open('.claude/features/meta-analysis-audit/state.json')); print('state: VALID')"
python3 -c "import json; json.load(open('.claude/shared/audit-findings.json')); print('findings: VALID')"
```

```bash
git add -f .claude/features/meta-analysis-audit/state.json .claude/shared/audit-findings.json
git commit -m "feat(audit): scaffold case study state + findings database"
```

---

### Task 2: Layer 1 — Surface Sweep (6 Domain Agents in Parallel)

This task dispatches 6 agents in parallel. Each agent scans its domain and produces a JSON findings file.

**Files:**
- Create: `.claude/features/meta-analysis-audit/layer1-ui.json`
- Create: `.claude/features/meta-analysis-audit/layer1-backend.json`
- Create: `.claude/features/meta-analysis-audit/layer1-ai.json`
- Create: `.claude/features/meta-analysis-audit/layer1-design-system.json`
- Create: `.claude/features/meta-analysis-audit/layer1-tests.json`
- Create: `.claude/features/meta-analysis-audit/layer1-framework.json`

**IMPORTANT:** All 6 agents run in parallel (dispatch in a single message with 6 Agent tool calls). Each agent writes its own output file — no conflicts.

- [ ] **Step 1: Dispatch Agent 1 — UI Audit**

Prompt the agent with:
- Scope: all .swift files under `FitTracker/Views/`
- Scan for: files >500 lines (decomposition candidates), hardcoded colors/fonts/spacing (token violations), missing accessibility labels, dead views, v1 files still in build target, state management in views
- Read each file, categorize findings by severity
- Output: write findings as JSON array to `.claude/features/meta-analysis-audit/layer1-ui.json`
- Each finding follows the schema: `{id, domain: "ui", severity, category, file, line, title, description, evidence, recommended_fix, effort, validation: "framework-only"}`

- [ ] **Step 2: Dispatch Agent 2 — Backend & Sync Audit**

Prompt the agent with:
- Scope: SupabaseSyncService.swift, CloudKitSyncService.swift, EncryptionService.swift, SignInService.swift, AuthManager.swift, GoogleAuthProvider.swift, EmailAuthProvider.swift, SupabaseAppleAuthProvider.swift, AuthValidation.swift, SupabaseClient.swift, DataSyncManager.swift (if exists)
- Scan for: error handling gaps, race conditions, credential storage issues, missing Keychain usage, offline handling, sync conflict resolution, RLS concerns
- Output: `.claude/features/meta-analysis-audit/layer1-backend.json`

- [ ] **Step 3: Dispatch Agent 3 — AI Engine Audit**

Prompt the agent with:
- Scope: all .swift files under `FitTracker/AI/`
- Scan for: three-tier pipeline graceful degradation, adapter data validation, confidence gating consistency (0.4 threshold), privacy leaks past categorical bands, RecommendationMemory growth, Foundation model iOS 26+ gate
- Output: `.claude/features/meta-analysis-audit/layer1-ai.json`

- [ ] **Step 4: Dispatch Agent 4 — Design System Audit**

Prompt the agent with:
- Scope: `FitTracker/DesignSystem/*.swift`, `FitTracker/Services/AppTheme.swift`, `design-tokens/tokens.json`, PLUS scan all View files for token violations
- Scan for: raw hex colors, hardcoded font sizes, magic spacing numbers, unused tokens, missing dark mode support, component reuse vs rebuild, Dynamic Type support
- Output: `.claude/features/meta-analysis-audit/layer1-design-system.json`

- [ ] **Step 5: Dispatch Agent 5 — Test Audit**

Prompt the agent with:
- Scope: all .swift files under `FitTrackerTests/`
- Scan for: coverage gaps (which of the 37 services have no test?), test quality (behavior vs implementation testing), eval coverage, edge case gaps, flaky test indicators, missing test categories
- Cross-reference: list of all services in FitTracker/Services/ vs test files
- Output: `.claude/features/meta-analysis-audit/layer1-tests.json`

- [ ] **Step 6: Dispatch Agent 6 — Framework Audit**

Prompt the agent with:
- Scope: `.claude/shared/` (all JSON), `.claude/skills/*/SKILL.md`, `.claude/cache/` (sample 5 entries)
- Scan for: config version consistency, stale cache entries, skill routing accuracy, token budget accuracy (compare to last measured), HADF integrity (validate hardware_context against spec), dead configs, case-study-monitoring currency
- Tag each finding with `bias_risk: "low|medium|high"`
- Output: `.claude/features/meta-analysis-audit/layer1-framework.json`

- [ ] **Step 7: Wait for all 6 agents to complete**

All agents write their own files. Verify all 6 exist:

```bash
ls -la .claude/features/meta-analysis-audit/layer1-*.json
```

Expected: 6 files.

- [ ] **Step 8: Validate all Layer 1 outputs and commit**

```bash
python3 -c "
import json, glob
files = glob.glob('.claude/features/meta-analysis-audit/layer1-*.json')
total = 0
for f in sorted(files):
    data = json.load(open(f))
    count = len(data) if isinstance(data, list) else len(data.get('findings', []))
    total += count
    print(f'  {f}: {count} findings')
print(f'  TOTAL: {total} findings across {len(files)} domains')
"
```

```bash
git add -f .claude/features/meta-analysis-audit/layer1-*.json
git commit -m "feat(audit): Layer 1 surface sweep — 6 domain agents complete"
```

---

### Task 3: Layer 1 Merge — Consolidate Surface Findings

**Files:**
- Modify: `.claude/shared/audit-findings.json`

- [ ] **Step 1: Merge all Layer 1 findings into audit-findings.json**

Read all 6 `layer1-*.json` files. Merge all findings into the `findings` array in `audit-findings.json`. Update the `summary` counters (by_severity, by_domain, by_layer).

- [ ] **Step 2: Identify Layer 2 targets**

From the merged findings, extract:
1. All files with `critical` or `high` severity findings
2. All files appearing in 3+ findings (cluster indicator)
3. All findings with `category: "security"`
4. Add the 7 CLAUDE.md high-risk files (regardless of Layer 1 results):
   - `FitTracker/Models/DomainModels.swift`
   - `FitTracker/Services/EncryptionService.swift`
   - `FitTracker/Services/SupabaseSyncService.swift`
   - `FitTracker/Services/CloudKitSyncService.swift`
   - `FitTracker/Services/SignInService.swift`
   - `FitTracker/Services/AuthManager.swift`
   - `FitTracker/AI/AIOrchestrator.swift`

Print the deep-dive target list.

- [ ] **Step 3: Commit**

```bash
git add -f .claude/shared/audit-findings.json
git commit -m "feat(audit): Layer 1 merge — surface findings consolidated, Layer 2 targets identified"
```

---

### Task 4: Layer 2 — Risk-Weighted Deep Dive

**Files:**
- Create: `.claude/features/meta-analysis-audit/layer2-deep-findings.json`
- Modify: `.claude/shared/audit-findings.json`

- [ ] **Step 1: Dispatch deep-dive agents for high-risk files**

For each Layer 2 target file, dispatch an agent that:
- Reads the full file
- Receives the Layer 1 findings for that file as context
- Performs a thorough code review focused on: root causes, security implications, architectural issues, hidden bugs
- Produces findings with `layer: 2` and `root_cause_of` linking to Layer 1 finding IDs where applicable
- Includes `code_snippet` and `fix_snippet` for each finding
- Tags `confidence` (0-1) on each finding

Dispatch high-risk files in parallel batches (3-4 at a time to avoid overwhelming context):
- Batch A: EncryptionService, SignInService, AuthManager
- Batch B: SupabaseSyncService, CloudKitSyncService, DomainModels
- Batch C: AIOrchestrator + any Layer 1-flagged files

- [ ] **Step 2: Merge deep findings**

Collect all deep-dive outputs into `layer2-deep-findings.json`. Merge into `audit-findings.json`.

- [ ] **Step 3: Update summary counters and commit**

```bash
git add -f .claude/features/meta-analysis-audit/layer2-deep-findings.json .claude/shared/audit-findings.json
git commit -m "feat(audit): Layer 2 deep dive — high-risk files reviewed, root causes identified"
```

---

### Task 5: Layer 3 — Cross-Reference & Meta-Analysis

**Files:**
- Create: `.claude/features/meta-analysis-audit/layer3-cross-reference.json`
- Modify: `.claude/shared/audit-findings.json`

- [ ] **Step 1: Pass A — Case Study Pattern Matching**

Read all 18 case studies in `docs/case-studies/`. For each finding in the database, check:
- Does this issue type appear in any prior case study? → tag `case_study_pattern: "recurring"`, add `related_case_study`
- Was this issue fixed before but reappeared? → tag `"regression"`
- Did a case study's "open questions" predict this? → tag `"predicted"`
- Is this a completely new finding type? → tag `"new_category"`

Populate `case_study_patterns` in audit-findings.json.

- [ ] **Step 2: Pass B — UX Foundations & Design System Validation**

Read `docs/design-system/ux-foundations.md` (13 principles). For each UI finding:
- Which UX principle does it violate?
- For each principle with zero findings, flag as suspicious

Produce the `ux_compliance_matrix`: 13 principles x major screens (Home, Training, Nutrition, Stats, Settings, Onboarding), scored green/yellow/red.

- [ ] **Step 3: Pass C — Framework Self-Audit**

Validate the framework infrastructure:
- Config consistency: do dispatch-intelligence.json, cache-metrics.json, token-budget.json agree on framework version?
- Run `bash scripts/count-framework-tokens.sh` and compare to stored token-budget.json
- Check skill-routing.json vs SKILL.md files
- Validate HADF chip-profiles.json, hardware-signature-table.json, hardware_context section
- Tag each framework finding with `bias_risk`

Populate `framework_self_audit` in audit-findings.json.

- [ ] **Step 4: Write self-referential bias section**

Based on all findings, compute:
- Validation distribution (what % of findings are framework-only vs externally validated)
- Bias risk distribution (what % of findings have high bias risk)
- Honest assessment of what the audit likely missed

Store in `layer3-cross-reference.json`.

- [ ] **Step 5: Commit**

```bash
git add -f .claude/features/meta-analysis-audit/layer3-cross-reference.json .claude/shared/audit-findings.json
git commit -m "feat(audit): Layer 3 — case study patterns, UX compliance matrix, framework self-audit, bias assessment"
```

---

### Task 6: Layer 4 — External Validation

**Files:**
- Modify: `.claude/shared/audit-findings.json`

- [ ] **Step 1: Run automated external checks**

```bash
# Build (already confirmed — record result)
echo "BUILD: SUCCEEDED (pre-validated)"

# Tests (already confirmed — record result)
echo "TESTS: 231 passed, 0 failed, 1 skipped (pre-validated)"

# Design system drift
make tokens-check 2>&1 || echo "tokens-check not configured"

# Token budget accuracy
bash scripts/count-framework-tokens.sh
```

Compare script output to stored `token-budget.json`. If they match, tag token-related findings `validation: "external-automated"`.

- [ ] **Step 2: Git cross-check timing claims**

For each case study that claims a wall time, verify against git log:

```bash
# Example: check v6.0 case study timing
git log --format="%ai" --reverse docs/superpowers/specs/2026-04-16-framework-measurement-v6-design.md | head -1
git log --format="%ai" docs/superpowers/specs/2026-04-16-framework-measurement-v6-design.md | head -1
```

Tag verified timing claims `validation: "external-git"`.

- [ ] **Step 3: Update validation tags on all findings**

Walk through all findings in audit-findings.json:
- Structural findings (file size, dead code, missing tests) → `validation: "external-automated"` (objectively measurable)
- Findings corroborated by case study patterns → `validation: "cross-referenced"`
- Findings about code behavior/logic → `validation: "framework-only"` (unless manually tested)

Update `summary.by_validation` counters.

- [ ] **Step 4: Produce System Health Scorecard**

Compute per-domain health score (0-100) based on findings:
- Start at 100
- Each critical: -15
- Each high: -8
- Each medium: -3
- Each low: -1
- Floor at 0

Add `health_scorecard` to audit-findings.json:

```json
{
  "health_scorecard": {
    "ui": 0,
    "backend": 0,
    "ai": 0,
    "design_system": 0,
    "tests": 0,
    "framework": 0,
    "overall": 0
  }
}
```

- [ ] **Step 5: Commit**

```bash
git add -f .claude/shared/audit-findings.json
git commit -m "feat(audit): Layer 4 — external validation, git cross-check, health scorecard"
```

---

### Task 7: Case Study — Narrative Write-Up

**Files:**
- Create: `docs/case-studies/meta-analysis-full-system-audit-v7.0-case-study.md`

- [ ] **Step 1: Write the case study**

Pull all data from `audit-findings.json` and produce the narrative with these sections:

1. **Summary Card** — table with: feature name, framework version, work type (chore), wall time, total findings, severity distribution, validation distribution, health scorecard, CU
2. **Methodology** — 4-layer architecture description, self-referential bias acknowledgment
3. **Experiment Design** — IV: audit methodology. DVs: findings count, external validation rate, cross-reference hit rate, framework self-audit accuracy, time efficiency
4. **Layer 1 Results** — per-domain findings summary with counts and highlights
5. **Layer 2 Results** — high-risk file analysis, root cause chains
6. **Layer 3 Results** — case study patterns (recurring/regression/predicted/new), UX compliance matrix, framework self-audit with bias tags
7. **Layer 4 Results** — external validation results, validation distribution chart, git cross-check
8. **Top 10 Findings** — most impactful, fully contextualized
9. **System Health Scorecard** — per-domain scores, bottlenecks, successes
10. **Self-Referential Bias Report** — what we can/can't detect, validation distribution, honest assessment
11. **Recommendations** — prioritized action list with effort estimates
12. **Lessons Learned** — methodology wins, methodology gaps, improvements for next audit

- [ ] **Step 2: Commit**

```bash
git add docs/case-studies/meta-analysis-full-system-audit-v7.0-case-study.md
git commit -m "docs(audit): full-system audit case study — methodology, findings, health scorecard, bias report"
```

---

### Task 8: Finalize — Update State, Sync, Summary

**Files:**
- Modify: `.claude/features/meta-analysis-audit/state.json`
- Modify: `docs/case-studies/README.md`

- [ ] **Step 1: Update case study state**

Set `implementation.ended_at` and `documentation.ended_at` with actual timestamps. Calculate total `duration_minutes`. Set `status: "complete"`.

- [ ] **Step 2: Update case-studies/README.md**

Add the new case study to the table:

```
| `meta-analysis-full-system-audit-v7.0-case-study.md` | Full-System Meta-Analysis Audit (v7.0) | First self-referential full-system audit — 4-layer risk-weighted sweep, N findings across 6 domains, external validation, framework self-audit with bias acknowledgment |
```

- [ ] **Step 3: Final validation**

```bash
python3 -c "
import json
data = json.load(open('.claude/shared/audit-findings.json'))
print(f'Total findings: {data[\"summary\"][\"total_findings\"]}')
print(f'By severity: {data[\"summary\"][\"by_severity\"]}')
print(f'By validation: {data[\"summary\"][\"by_validation\"]}')
print(f'Health scorecard: {data.get(\"health_scorecard\", \"NOT SET\")}')
ext_count = data['summary']['by_validation'].get('external-automated', 0) + data['summary']['by_validation'].get('external-manual', 0) + data['summary']['by_validation'].get('external-git', 0)
total = data['summary']['total_findings']
ext_rate = ext_count / total * 100 if total > 0 else 0
print(f'External validation rate: {ext_rate:.1f}%')
print(f'Target: >40%. Kill: <20%.')
"
```

- [ ] **Step 4: Commit and sync**

```bash
git add -f .claude/features/meta-analysis-audit/state.json docs/case-studies/README.md
git commit -m "feat(audit): finalize — state complete, README updated, validation rate computed"
git push origin main
```

- [ ] **Step 5: Print final summary**

Report to user:
- Total findings count and severity distribution
- Health scorecard (per-domain)
- External validation rate
- Top 3 most critical findings
- Recommended immediate actions
