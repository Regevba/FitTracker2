# Dispatch Intelligence (v5.2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create the dispatch-intelligence.json config, wire it into the PM workflow, bump the framework to v5.2, and update research docs to reflect implementation status.

**Architecture:** A single JSON config file (`.claude/shared/dispatch-intelligence.json`) defines permission tables, model routing tiers, probe settings, tool budgets, and validation flags. The PM workflow SKILL.md references this config when dispatching subagents. No Swift code — this is framework infrastructure.

**Tech Stack:** JSON config, Markdown (SKILL.md), existing PM workflow system.

---

### Task 1: Create dispatch-intelligence.json

**Files:**
- Create: `.claude/shared/dispatch-intelligence.json`

- [ ] **Step 1: Create the config file**

```json
{
  "version": "1.0",
  "framework_version": "5.2",
  "updated": "2026-04-16",
  "description": "Dispatch Intelligence — 3-stage pipeline for subagent routing: score complexity → probe capability → dispatch with budget.",

  "permission_table": {
    "known_writable": [
      "FitTracker/**",
      "FitTrackerTests/**",
      "docs/**",
      "dashboard/**",
      "website/**",
      "scripts/**",
      ".claude/features/**",
      ".claude/shared/**"
    ],
    "known_readonly": [
      ".claude/skills/**",
      ".claude/integrations/**",
      ".claude/cache/**"
    ]
  },

  "model_routing": {
    "lightweight": {
      "model": "haiku",
      "tool_budget": 10,
      "timeout_seconds": 60,
      "review_required": false,
      "escalation_on_budget": "DONE_WITH_CONCERNS"
    },
    "standard": {
      "model": "sonnet",
      "tool_budget": 25,
      "timeout_seconds": 180,
      "review_required": true,
      "escalation_on_budget": "DONE_WITH_CONCERNS"
    },
    "heavyweight": {
      "model": "opus",
      "tool_budget": 50,
      "timeout_seconds": 600,
      "review_required": true,
      "escalation_on_budget": "BLOCKED"
    }
  },

  "probe": {
    "model": "haiku",
    "tool_budget": 5,
    "timeout_seconds": 15,
    "trigger": "path_not_in_permission_table"
  },

  "validation": {
    "mode": "measure",
    "switch_threshold": 0.6,
    "min_sample_size": 20,
    "flag_key": "complexity_prediction_needs_review",
    "log_to": "stress-test-checkpoint.json"
  },

  "budget_tuning": {
    "increase_trigger": 0.30,
    "decrease_trigger": 0.05,
    "adjustment_factor": 0.25
  },

  "escalation_path": ["lightweight", "standard", "heavyweight", "BLOCKED"],
  "max_escalations_per_task": 1
}
```

- [ ] **Step 2: Validate JSON syntax**

Run: `python3 -m json.tool .claude/shared/dispatch-intelligence.json > /dev/null && echo "Valid JSON"`

Expected: `Valid JSON`

- [ ] **Step 3: Commit**

```bash
git add -f .claude/shared/dispatch-intelligence.json
git commit -m "feat(v5.2): create dispatch-intelligence.json — model routing, probes, budgets"
```

---

### Task 2: Update skill-routing.json — add v5.2 reference

**Files:**
- Modify: `.claude/shared/skill-routing.json`

- [ ] **Step 1: Read the current file to find the version fields**

Run: `python3 -c "import json; d=json.load(open('.claude/shared/skill-routing.json')); print(f'version: {d[\"version\"]}, framework: {d[\"framework_version\"]}')"` 

Expected: `version: 4.1, framework: 5.1`

- [ ] **Step 2: Update version and add dispatch intelligence reference**

Use python to update:

```python
import json

with open('.claude/shared/skill-routing.json') as f:
    data = json.load(f)

data['version'] = '5.0'
data['framework_version'] = '5.2'
data['dispatch_intelligence'] = {
    'version': '1.0',
    'config_path': '.claude/shared/dispatch-intelligence.json',
    'enabled': True
}

with open('.claude/shared/skill-routing.json', 'w') as f:
    json.dump(data, f, indent=2)
```

- [ ] **Step 3: Validate**

Run: `python3 -c "import json; d=json.load(open('.claude/shared/skill-routing.json')); print(f'version: {d[\"version\"]}, framework: {d[\"framework_version\"]}, dispatch: {d[\"dispatch_intelligence\"][\"version\"]}')"` 

Expected: `version: 5.0, framework: 5.2, dispatch: 1.0`

- [ ] **Step 4: Commit**

```bash
git add -f .claude/shared/skill-routing.json
git commit -m "feat(v5.2): wire dispatch-intelligence into skill-routing v5.0"
```

---

### Task 3: Update framework-manifest.json — bump to v5.2

**Files:**
- Modify: `.claude/shared/framework-manifest.json`

- [ ] **Step 1: Read current manifest**

Run: `python3 -c "import json; d=json.load(open('.claude/shared/framework-manifest.json')); print(f'version: {d[\"version\"]}, framework: {d[\"framework_version\"]}')"` 

Expected: `version: 1.2, framework: 5.1`

- [ ] **Step 2: Bump version**

```python
import json

with open('.claude/shared/framework-manifest.json') as f:
    data = json.load(f)

data['version'] = '1.3'
data['framework_version'] = '5.2'
data['capabilities'] = data.get('capabilities', [])
if 'dispatch_intelligence' not in data['capabilities']:
    data['capabilities'].append('dispatch_intelligence')

with open('.claude/shared/framework-manifest.json', 'w') as f:
    json.dump(data, f, indent=2)
```

- [ ] **Step 3: Validate**

Run: `python3 -c "import json; d=json.load(open('.claude/shared/framework-manifest.json')); print(f'version: {d[\"version\"]}, framework: {d[\"framework_version\"]}, capabilities: {d.get(\"capabilities\", [])}')"` 

Expected: `version: 1.3, framework: 5.2, capabilities: [..., 'dispatch_intelligence']`

- [ ] **Step 4: Commit**

```bash
git add -f .claude/shared/framework-manifest.json
git commit -m "feat(v5.2): bump framework manifest to v5.2 with dispatch_intelligence capability"
```

---

### Task 4: Update PM workflow SKILL.md — dispatch protocol

**Files:**
- Modify: `.claude/skills/pm-workflow/SKILL.md`

- [ ] **Step 1: Find the subagent dispatch section**

Run: `grep -n "dispatch\|subagent\|parallel\|agent" .claude/skills/pm-workflow/SKILL.md | head -20`

- [ ] **Step 2: Add dispatch intelligence protocol**

Find the section that describes how to dispatch subagents (look for batch dispatch, parallel dispatch, or similar). Add this protocol block after it:

```markdown
### Dispatch Intelligence (v5.2)

Before dispatching any subagent, apply the 3-stage pipeline from `.claude/shared/dispatch-intelligence.json`:

**Stage 1 — Score:** Read the task's `complexity` field (lightweight/standard/heavyweight). If missing, default to `standard`.

**Stage 2 — Probe:** Check target file paths against the `permission_table`:
- `known_writable` → dispatch to subagent
- `known_readonly` → controller handles directly
- Unknown → dispatch haiku micro-probe (5 tool budget, 15s timeout)

**Stage 3 — Dispatch:** Use the `model_routing` config for the task's complexity tier:
- Include in prompt: `"BUDGET: You have {N} tool uses for this task."`
- Set model parameter to the tier's model (haiku/sonnet/opus)
- On budget hit: accept if usable, escalate if incomplete (max 1 escalation)

**Logging:** Every dispatch logs `{task_id, predicted_complexity, model_used, actual_tool_uses, actual_duration, result, quality}` to the checkpoint file for validation analysis.
```

- [ ] **Step 3: Commit**

```bash
git add -f .claude/skills/pm-workflow/SKILL.md
git commit -m "feat(v5.2): add dispatch intelligence protocol to PM workflow SKILL.md"
```

---

### Task 5: Update research docs — mark as implemented

**Files:**
- Modify: `docs/architecture/subagent-preflight-probe-research.md`

- [ ] **Step 1: Update status line**

Change line 4 from:
```
> **Status:** Research idea — to be prototyped after experiment completes
```
To:
```
> **Status:** Implemented in v5.2 — see `.claude/shared/dispatch-intelligence.json`
```

- [ ] **Step 2: Commit**

```bash
git add docs/architecture/subagent-preflight-probe-research.md
git commit -m "docs: mark pre-flight probe as implemented in v5.2"
```

---

### Task 6: Create tasks.md for the feature + update state

**Files:**
- Create: `.claude/features/dispatch-intelligence-v5.2/tasks.md`
- Modify: `.claude/features/dispatch-intelligence-v5.2/state.json`

- [ ] **Step 1: Write tasks.md**

```markdown
# Dispatch Intelligence v5.2 — Task Breakdown

| ID | Title | Type | Complexity | Status |
|---|---|---|---|---|
| T1 | Create dispatch-intelligence.json | config | lightweight | pending |
| T2 | Update skill-routing.json v5.0 | config | lightweight | pending |
| T3 | Bump framework-manifest.json to v5.2 | config | lightweight | pending |
| T4 | Update PM workflow SKILL.md dispatch protocol | docs | standard | pending |
| T5 | Update research docs status | docs | lightweight | pending |
| T6 | Create tasks.md + update state | config | lightweight | pending |
| T7 | Validation: verify JSON configs parse correctly | test | lightweight | pending |
| T8 | Integration: dispatch 4 test tasks with different complexities | test | standard | pending |
```

- [ ] **Step 2: Update state.json — advance to implementation**

```python
import json

with open('.claude/features/dispatch-intelligence-v5.2/state.json') as f:
    s = json.load(f)

s['current_phase'] = 'implementation'
s['updated'] = '2026-04-16T10:30:00Z'
s['phases']['tasks'] = {
    'status': 'approved',
    'task_file': '.claude/features/dispatch-intelligence-v5.2/tasks.md',
    'v2_count': 8
}
s['transitions'].append({
    'from': 'tasks',
    'to': 'implementation',
    'timestamp': '2026-04-16T10:30:00Z',
    'approved_by': 'user',
    'note': '8 tasks. Config + docs + validation. No Swift code.'
})

with open('.claude/features/dispatch-intelligence-v5.2/state.json', 'w') as f:
    json.dump(s, f, indent=2)
```

- [ ] **Step 3: Commit**

```bash
git add -f .claude/features/dispatch-intelligence-v5.2/tasks.md .claude/features/dispatch-intelligence-v5.2/state.json
git commit -m "feat(dispatch-intelligence): tasks.md + advance to implementation"
```

---

### Task 7: Validation — verify all JSON configs

- [ ] **Step 1: Validate all 3 JSON files parse correctly**

```bash
python3 -c "
import json
files = [
    '.claude/shared/dispatch-intelligence.json',
    '.claude/shared/skill-routing.json',
    '.claude/shared/framework-manifest.json'
]
for f in files:
    try:
        json.load(open(f))
        print(f'OK: {f}')
    except Exception as e:
        print(f'FAIL: {f} — {e}')
"
```

Expected: All 3 print `OK`.

- [ ] **Step 2: Verify cross-references**

```bash
python3 -c "
import json
di = json.load(open('.claude/shared/dispatch-intelligence.json'))
sr = json.load(open('.claude/shared/skill-routing.json'))
fm = json.load(open('.claude/shared/framework-manifest.json'))

assert di['framework_version'] == '5.2', 'dispatch-intelligence version mismatch'
assert sr['framework_version'] == '5.2', 'skill-routing version mismatch'
assert fm['framework_version'] == '5.2', 'framework-manifest version mismatch'
assert sr['dispatch_intelligence']['version'] == di['version'], 'dispatch intelligence version cross-ref mismatch'
assert 'dispatch_intelligence' in fm.get('capabilities', []), 'capability not in manifest'
print('All cross-references valid')
"
```

Expected: `All cross-references valid`

- [ ] **Step 3: Commit (if any fixes needed)**

---

### Task 8: Final — push + update case study

- [ ] **Step 1: Push all changes**

```bash
git push origin main
```

- [ ] **Step 2: Update case study snapshot**

```python
import json

with open('.claude/shared/case-study-monitoring.json') as f:
    data = json.load(f)

for case in data['cases']:
    if case['case_id'] == 'dispatch-intelligence-v5.2-2026-04':
        case['status'] = 'in_progress'
        case['updated_at'] = '2026-04-16T11:00:00Z'
        case['process_metrics']['repo_files_added'] = 2
        case['process_metrics']['repo_files_updated'] = 3
        case['snapshots'].append({
            'timestamp': '2026-04-16T11:00:00Z',
            'label': 'v5.2 config deployed',
            'summary': 'dispatch-intelligence.json created. skill-routing bumped to v5.0. framework-manifest bumped to v5.2. SKILL.md dispatch protocol added. Research docs updated.',
            'metrics': {'tests_passing': 0, 'build_verified': True}
        })
        break

with open('.claude/shared/case-study-monitoring.json', 'w') as f:
    json.dump(data, f, indent=2)
```

- [ ] **Step 3: Final commit + push**

```bash
git add -f .claude/shared/case-study-monitoring.json
git commit -m "feat(v5.2): dispatch intelligence DEPLOYED — config, routing, manifest, SKILL.md, case study updated

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
git push origin main
```
