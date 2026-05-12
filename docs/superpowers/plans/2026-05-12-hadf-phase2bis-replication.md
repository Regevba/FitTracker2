# HADF Phase 2-bis Replication Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the hardened harness + scaffolding that lets HADF Phase 2-bis run 3 sequential sub-experiments (11 endpoints / 8 providers / ~5,600 valid records / ~$5 cost / ~15 days) with 4 mandatory architectural fixes from the Phase 2 retro, producing 3 per-sub-exp verdicts + 1 cross-sub-exp synthesis.

**Architecture:** Per-sub-exp dedicated git worktrees on sibling SSD paths · launchctl plist drives 5 fires/day @ UTC 02:00/08:00/14:00/18:00/22:00 · single Python wrapper `scripts/hadf-phase2bis-collect.sh` enforces preflight + writes raw .jsonl + emits heartbeat + cost ledgers · pre-registration JSONs hash-locked + sibling `.lock` file + git tag · per-sub-exp closure ceremony (verdict → case study → snapshot → off-SSD backup) · cross-sub-exp synthesis case study after Sub-exp 3 → state.json `current_phase=complete` (FEATURE_CLOSURE_COMPLETENESS gate).

**Tech Stack:** Python 3.11 (existing FT2 venv pattern) · launchd (macOS scheduling) · Git + Mechanism E `union-dedup-by-key` merge driver · provider SDKs: `openai`, `anthropic`, `google-generativeai`, `mistralai`, `xai-sdk`, `boto3` (Bedrock), `ollama-python`, `requests` (Vercel AI Gateway HTTP) · `scikit-learn` (silhouette + KS-test) · `numpy` for stats.

**Spec:** [`docs/superpowers/specs/2026-05-11-hadf-phase2bis-replication-design.md`](../specs/2026-05-11-hadf-phase2bis-replication-design.md) (merged via FT2 PR #306, 2026-05-12).
**Linear:** [FIT-71](https://linear.app/fitme-project/issue/FIT-71)
**Predecessor:** [HADF Phase 2 case study](../../case-studies/hadf-phase2-cloud-fingerprinting-case-study.md)
**Calendar gate:** Sub-exp 1 collection earliest **2026-05-23** (T+12d v7.8.3 soak). Block A scaffolding fills 2026-05-13 → 22 soak window.

---

## File Structure

| Path | Responsibility | Block |
|---|---|---|
| `.claude/features/hadf-phase2bis-replication/state.json` | Feature state (canonical per-sub-exp progress) | A0 |
| `.claude/features/hadf-phase2bis-replication/research.md` | Research notes synthesis (link to spec) | A0 |
| `.claude/features/hadf-phase2bis-replication/prd.md` | Product requirements (link to spec) | A0 |
| `.claude/features/hadf-phase2bis-replication/tasks.md` | Per-sub-exp task blocks | A0 |
| `.claude/features/hadf-phase2bis-replication/go-no-go-ceremony.md` | 6-point safety checklist runbook | A11 |
| `.claude/shared/hadf/provider-rates.json` | Frozen $/M token rates per provider | A1 |
| `.claude/shared/hadf/preregistration-phase2bis-subexp{1,2,3}.json` | Pre-registration (hash-locked) | A6 |
| `.claude/shared/hadf/preregistration-phase2bis-subexp{1,2,3}.json.lock` | sha256 lock sibling | A6 (runtime) |
| `.claude/shared/hadf/phase2bis-fire-heartbeat.jsonl` | Heartbeat ledger (T2-A) | A3 |
| `.claude/shared/hadf/phase2bis-cost-log.jsonl` | Per-fire cost log (T2-C) | A4 |
| `.claude/shared/hadf/phase2bis-raw-<subexp>-<run>.jsonl` | Raw per-call records (Fix #4) | A2 (runtime) |
| `.claude/shared/hadf/phase2bis-deploy-verification/subexp{N}-deliberate-break.log` | Preflight test artifact | A2 |
| `scripts/hadf-phase2bis-collect.sh` | Wrapper invoked by launchd | A2 |
| `scripts/hadf-phase2bis-collect.py` | Python collection driver (called by sh wrapper) | A2 |
| `scripts/hadf-cost-estimate.py` | Compute estimated cost from rates + tokens | A1 |
| `scripts/hadf-phase2bis-heartbeat-audit.py` | Reconcile plist vs ledger | A3 |
| `scripts/hadf-cost-cron.py` | Daily cumulative cost check + bootout | A4 |
| `scripts/hadf-phase2bis-smoke-fire.sh` | Pre-flight 1-call/endpoint shake-out | A5 |
| `scripts/hadf-phase2bis-lock-prereg.sh` | sha256 + .lock + git tag | A6 |
| `scripts/hadf-phase2bis-anchor-drift-check.py` | KS-test on anchor endpoint distributions (Sub-exp 3) | A8 |
| `scripts/hadf-phase2bis-verdict.py` | Silhouette + cluster count + threshold check → verdict | A9 |
| `~/Library/LaunchAgents/com.fitme.hadf-phase2bis-subexp{1,2,3}.plist` | launchd schedule per sub-exp | A10 |
| `.gitattributes` | Add raw .jsonl + heartbeat + cost log to merge driver | A2 |
| `.githooks/pre-commit` | Add prereg-lock check | A6 |
| `docs/case-studies/hadf-phase2bis-subexp{1,2,3}-case-study.md` | Per-sub-exp case studies | B13/B14/B15 |
| `docs/case-studies/hadf-phase2bis-cross-sub-exp-synthesis-case-study.md` | Final synthesis | C16 |
| `fitme-story/content/04-case-studies/30-hadf-phase2bis-cross-sub-exp-synthesis.mdx` | Public showcase | C17 |

---

## Worktree Convention

Per spec §8, dedicated per-sub-exp worktrees at sibling SSD paths. Created at the start of each sub-exp launch (Phase B13/B14/B15). All Block A scaffolding work happens on a single feature branch in the canonical worktree (`/Volumes/DevSSD/FitTracker2`), since it's pre-launch infrastructure.

| Sub-exp | Worktree path | Branch |
|---|---|---|
| Block A scaffolding | `/Volumes/DevSSD/FitTracker2` (current) | `feat/hadf-phase2bis-impl` |
| Sub-exp 1 collection | `/Volumes/DevSSD/FitTracker2-hadf-phase2bis-subexp1` | `feat/hadf-phase2bis-subexp1` |
| Sub-exp 2 collection | `/Volumes/DevSSD/FitTracker2-hadf-phase2bis-subexp2` | `feat/hadf-phase2bis-subexp2` |
| Sub-exp 3 collection | `/Volumes/DevSSD/FitTracker2-hadf-phase2bis-subexp3` | `feat/hadf-phase2bis-subexp3` |
| Cross-sub-exp synthesis | `/Volumes/DevSSD/FitTracker2-hadf-phase2bis-synthesis` | `feat/hadf-phase2bis-synthesis` |

---

# BLOCK A — Soak Window Scaffolding (2026-05-13 → 22)

All tasks in this block are subagent-driven (per task: implementer → spec reviewer → code quality reviewer). Mechanical setup → Haiku; integration/judgment → Sonnet; architecture decisions → Opus.

## Task A0: Stub creation + research/prd/tasks placeholders

**Files:**
- Create: `.claude/features/hadf-phase2bis-replication/state.json`
- Create: `.claude/features/hadf-phase2bis-replication/research.md`
- Create: `.claude/features/hadf-phase2bis-replication/prd.md`
- Create: `.claude/features/hadf-phase2bis-replication/tasks.md`

- [ ] **Step 1: Create feature branch**

```bash
git checkout main
git pull --ff-only origin main
git checkout -b feat/hadf-phase2bis-impl
```

Expected: `Switched to a new branch 'feat/hadf-phase2bis-impl'`

- [ ] **Step 2: Create state.json with v7.8.3 schema compliance**

```bash
mkdir -p .claude/features/hadf-phase2bis-replication
cat > .claude/features/hadf-phase2bis-replication/state.json <<'EOF'
{
  "name": "hadf-phase2bis-replication",
  "state_owner": "ft2",
  "framework_version": "v7.8.3",
  "work_type": "Feature",
  "current_phase": "research",
  "isolation_opt_out": false,
  "created_at": "2026-05-12T00:00:00Z",
  "timing": {
    "phases": {
      "research": {
        "started_at": "2026-05-12T00:00:00Z"
      }
    }
  },
  "primary_metric": "silhouette score at k=5 across all 11 endpoints (replicates Phase 2 baseline)",
  "success_metrics": [
    "Sub-exp 1: silhouette ≥ 0.5 with cluster count ≥ 3 across 9 cloud endpoints",
    "Sub-exp 2: Ollama distribution KS-distinguishable from cloud endpoints (p < 0.01)",
    "Sub-exp 3: Bedrock haiku-4-5 fingerprint distinguishable from Anthropic-direct haiku-4-5 (signature delta > Sub-exp 1 within-provider variance)"
  ],
  "kill_criteria": [
    "n_valid < 600 per sub-exp (yield too low for silhouette computation)",
    "All endpoints simultaneously rate-limited > 2 fires consecutively",
    "ANY endpoint changes streaming protocol or model id mid-collection",
    "Wrapper preflight fails 3+ times consecutively"
  ],
  "kill_criteria_resolution": null,
  "dispatch_pattern": "subagent-driven (Block A) + operator-driven (Block B/C)",
  "case_study": "docs/case-studies/hadf-phase2bis-cross-sub-exp-synthesis-case-study.md",
  "case_study_showcase": "fitme-story/content/04-case-studies/30-hadf-phase2bis-cross-sub-exp-synthesis.mdx",
  "spec": "docs/superpowers/specs/2026-05-11-hadf-phase2bis-replication-design.md",
  "plan": "docs/superpowers/plans/2026-05-12-hadf-phase2bis-replication.md",
  "predecessor_case_study": "docs/case-studies/hadf-phase2-cloud-fingerprinting-case-study.md",
  "linear": "FIT-71",
  "related_prs": [],
  "tasks": [],
  "phases": {
    "research": {"status": "in_progress"},
    "prd": {"status": "pending"},
    "tasks_phase": {"status": "pending"},
    "implement": {"status": "pending"},
    "test": {"status": "pending"},
    "review": {"status": "pending"},
    "merge": {"status": "pending"},
    "docs": {"status": "pending"},
    "learn": {"status": "pending"}
  }
}
EOF
```

- [ ] **Step 3: Create research.md placeholder pointing to spec**

```bash
cat > .claude/features/hadf-phase2bis-replication/research.md <<'EOF'
# HADF Phase 2-bis — Research Notes

This Feature's research synthesis lives in the merged design spec:

→ [`docs/superpowers/specs/2026-05-11-hadf-phase2bis-replication-design.md`](../../../docs/superpowers/specs/2026-05-11-hadf-phase2bis-replication-design.md)

## Predecessor research (input to this Feature)

- HADF Phase 2 case study: `docs/case-studies/hadf-phase2-cloud-fingerprinting-case-study.md`
- Phase 2 incident catalog: `memory/project_hadf_phase2_in_progress.md` (agent memory, off-repo)
- 3-fix follow-up tracks (Track 5): `memory/project_post_hadf_phase2_followup_tracks.md`
- Brainstorm Q1/Q2/Q3 resolution: `memory/project_phase2bis_brainstorm_paused_2026_05_11.md`
- Backup discovery (raw .jsonl preservation gap): `memory/project_hadf_preservation_backup_2026_05_08.md`

## Decisions locked by brainstorm (carried into spec)

- D (Scope) = full Tier 1 + Tier 2 matrix (11 endpoints, 8 providers)
- P1 (Phasing) = 3 sequential sub-experiments, each pre-registered + own verdict
- H1 (Carry-forward) = Ollama no-anchor; Bedrock anchored
- T1 (Per-call defaults) = Phase 2 defaults + 600s Ollama timeout override
- Q1=S1: Cross-repo Phase C (v7.8.3) ships first → MET 2026-05-11
- Q2=V2-only: Mechanism C writer-path enforced (V3/V4/V5 deferred)
- Q3=OUT: Track 6 HADF gate activation stays separate

See spec §1-§11 for full detail.
EOF
```

- [ ] **Step 4: Create prd.md pointing to spec**

```bash
cat > .claude/features/hadf-phase2bis-replication/prd.md <<'EOF'
# HADF Phase 2-bis — PRD

This Feature uses the merged design spec as its PRD source-of-truth:

→ [`docs/superpowers/specs/2026-05-11-hadf-phase2bis-replication-design.md`](../../../docs/superpowers/specs/2026-05-11-hadf-phase2bis-replication-design.md)

## Implementation plan

→ [`docs/superpowers/plans/2026-05-12-hadf-phase2bis-replication.md`](../../../docs/superpowers/plans/2026-05-12-hadf-phase2bis-replication.md)

## Success metrics

See state.json `success_metrics[]`.

## Kill criteria

See state.json `kill_criteria[]`. `kill_criteria_resolution` populated at each sub-exp closure ceremony per spec §10.

## Cross-sub-exp synthesis

After Sub-exp 3 closes, the cross-sub-exp synthesis case study at `docs/case-studies/hadf-phase2bis-cross-sub-exp-synthesis-case-study.md` becomes this Feature's `case_study` link.
EOF
```

- [ ] **Step 5: Create tasks.md per-sub-exp task blocks**

```bash
cat > .claude/features/hadf-phase2bis-replication/tasks.md <<'EOF'
# HADF Phase 2-bis — Tasks

## Block A — Soak window scaffolding (2026-05-13 → 22)

See plan A0–A12.

## Block B — Sub-experiment campaigns

### Sub-exp 1 (2026-05-23 → ~2026-05-26)

- [ ] B13.1 Operator runs go/no-go ceremony for Sub-exp 1
- [ ] B13.2 Lock prereg-subexp1.json
- [ ] B13.3 launchctl bootstrap subexp1 plist
- [ ] B13.4 Wait 3 days for collection (5 fires/day × 3 days)
- [ ] B13.5 Run verdict script
- [ ] B13.6 Write Sub-exp 1 case study
- [ ] B13.7 make snapshot-phase
- [ ] B13.8 Commit + PR + merge

### Sub-exp 2 (gated on Sub-exp 1 PASS, ~2026-05-27 → 30)

- [ ] B14.1–B14.8 same as B13 with subexp2 substitutions

### Sub-exp 3 (gated on Sub-exp 2 PASS, ~2026-05-31 → ~06-03)

- [ ] B15.1–B15.8 same as B13 with subexp3 substitutions
- [ ] B15.9 Run anchor-drift check vs Sub-exp 1 anchors (T2-E)

## Block C — Synthesis + closure (~2026-06-04 → 07)

- [ ] C16 Cross-sub-exp synthesis case study
- [ ] C17 fitme-story showcase MDX (slot 30)
- [ ] C18 state.json closure (current_phase=complete; passes FEATURE_CLOSURE_COMPLETENESS)
- [ ] C19 Final make snapshot-phase
- [ ] C20 Linear FIT-71 → Done
EOF
```

- [ ] **Step 6: Append Tier 2.2 log entry for phase=research start**

```bash
python3 scripts/append-feature-log.py \
  --feature hadf-phase2bis-replication \
  --event phase_started \
  --phase research \
  --message "HADF Phase 2-bis Feature stub created; Block A scaffolding starts"
```

Expected: writes new line to `.claude/logs/hadf-phase2bis-replication.log.json`

- [ ] **Step 7: Verify state.json + research/prd/tasks pass schema-check**

Run: `python3 scripts/check-state-schema.py .claude/features/hadf-phase2bis-replication/state.json`
Expected: exit 0; all v7.8.3 gates pass (STATE_OWNER_MISSING, STATE_OWNER_INVALID, STATE_OWNER_LOCATION_MISMATCH all green)

- [ ] **Step 8: Commit**

```bash
git add .claude/features/hadf-phase2bis-replication/ .claude/logs/hadf-phase2bis-replication.log.json
git commit -m "$(cat <<'MSG'
feat(hadf-phase2bis-replication): Feature stub + research/prd/tasks placeholders

Creates the v7.8.3-compliant state.json (state_owner=ft2, framework_version=v7.8.3, current_phase=research) plus research.md/prd.md/tasks.md placeholders pointing to the canonical spec at docs/superpowers/specs/2026-05-11-hadf-phase2bis-replication-design.md (merged via PR #306).

Linear: FIT-71

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
MSG
)"
```

---

## Task A1: Provider rate table + cost estimation script

**Files:**
- Create: `.claude/shared/hadf/provider-rates.json`
- Create: `scripts/hadf-cost-estimate.py`
- Create: `tests/framework/test_hadf_cost_estimate.py`

- [ ] **Step 1: Write the failing test**

```python
# tests/framework/test_hadf_cost_estimate.py
import json
import subprocess
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]

def test_cost_estimate_openai_gpt4o_mini():
    """50 calls × 200 output tokens × OpenAI gpt-4o-mini rate ($0.60/M output) = $0.006"""
    result = subprocess.run(
        ["python3", str(REPO_ROOT / "scripts/hadf-cost-estimate.py"),
         "--provider", "openai",
         "--endpoint", "gpt-4o-mini",
         "--calls", "50",
         "--avg-output-tokens", "200"],
        capture_output=True, text=True
    )
    assert result.returncode == 0, result.stderr
    cost = float(result.stdout.strip())
    assert 0.005 < cost < 0.008, f"expected ~$0.006, got ${cost}"

def test_cost_estimate_anthropic_haiku_4_5():
    """50 calls × 200 output tokens × Anthropic haiku rate"""
    result = subprocess.run(
        ["python3", str(REPO_ROOT / "scripts/hadf-cost-estimate.py"),
         "--provider", "anthropic",
         "--endpoint", "claude-haiku-4-5",
         "--calls", "50",
         "--avg-output-tokens", "200"],
        capture_output=True, text=True
    )
    assert result.returncode == 0, result.stderr
    cost = float(result.stdout.strip())
    assert cost > 0, "cost should be positive"

def test_cost_estimate_unknown_provider_fails():
    result = subprocess.run(
        ["python3", str(REPO_ROOT / "scripts/hadf-cost-estimate.py"),
         "--provider", "nonexistent",
         "--endpoint", "fake",
         "--calls", "50",
         "--avg-output-tokens", "200"],
        capture_output=True, text=True
    )
    assert result.returncode != 0
    assert "unknown provider" in result.stderr.lower()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `.venv/bin/python3 -m pytest tests/framework/test_hadf_cost_estimate.py -v`
Expected: FAIL with file-not-found on scripts/hadf-cost-estimate.py

- [ ] **Step 3: Create provider-rates.json (frozen at 2026-05-12 from public pricing)**

```bash
mkdir -p .claude/shared/hadf
cat > .claude/shared/hadf/provider-rates.json <<'EOF'
{
  "frozen_at": "2026-05-12",
  "currency": "USD",
  "unit": "per_million_tokens",
  "rates": {
    "openai": {
      "gpt-4o-mini": {"input": 0.15, "output": 0.60},
      "gpt-4o":      {"input": 2.50, "output": 10.00}
    },
    "anthropic": {
      "claude-haiku-4-5":  {"input": 1.00, "output": 5.00},
      "claude-sonnet-4-6": {"input": 3.00, "output": 15.00}
    },
    "google": {
      "gemini-2-flash": {"input": 0.30, "output": 2.50},
      "gemini-2-pro":   {"input": 1.25, "output": 10.00}
    },
    "vercel-ai-gateway": {
      "gpt-4o-mini": {"input": 0.15, "output": 0.60}
    },
    "mistral": {
      "mistral-large-latest": {"input": 2.00, "output": 6.00}
    },
    "xai": {
      "grok-4-1": {"input": 3.00, "output": 15.00}
    },
    "ollama": {
      "llama3.2:3b": {"input": 0.0, "output": 0.0}
    },
    "aws-bedrock": {
      "anthropic.claude-haiku-4-5": {"input": 1.00, "output": 5.00}
    }
  }
}
EOF
```

- [ ] **Step 4: Implement cost estimator**

```python
# scripts/hadf-cost-estimate.py
"""HADF Phase 2-bis cost estimator. Reads provider-rates.json + per-call params -> $ estimate.

Usage:
    python3 scripts/hadf-cost-estimate.py \
      --provider openai --endpoint gpt-4o-mini \
      --calls 50 --avg-output-tokens 200 [--avg-input-tokens 100]
"""
import argparse
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
RATES_PATH = REPO_ROOT / ".claude/shared/hadf/provider-rates.json"

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--provider", required=True)
    p.add_argument("--endpoint", required=True)
    p.add_argument("--calls", type=int, required=True)
    p.add_argument("--avg-output-tokens", type=int, required=True)
    p.add_argument("--avg-input-tokens", type=int, default=100)
    args = p.parse_args()

    rates = json.loads(RATES_PATH.read_text())["rates"]
    if args.provider not in rates:
        print(f"unknown provider: {args.provider}", file=sys.stderr)
        sys.exit(2)
    if args.endpoint not in rates[args.provider]:
        print(f"unknown endpoint for {args.provider}: {args.endpoint}", file=sys.stderr)
        sys.exit(2)

    rate = rates[args.provider][args.endpoint]
    total_input_tokens = args.calls * args.avg_input_tokens
    total_output_tokens = args.calls * args.avg_output_tokens
    cost = (total_input_tokens / 1_000_000) * rate["input"] + \
           (total_output_tokens / 1_000_000) * rate["output"]
    print(f"{cost:.6f}")

if __name__ == "__main__":
    main()
```

- [ ] **Step 5: Run test to verify it passes**

Run: `.venv/bin/python3 -m pytest tests/framework/test_hadf_cost_estimate.py -v`
Expected: 3 PASSED

- [ ] **Step 6: Commit**

```bash
git add .claude/shared/hadf/provider-rates.json scripts/hadf-cost-estimate.py tests/framework/test_hadf_cost_estimate.py
git commit -m "feat(hadf-phase2bis): provider rate table + cost estimator (3 tests pass)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task A2: Wrapper script with 4 architectural fixes

**Files:**
- Create: `scripts/hadf-phase2bis-collect.sh`
- Create: `scripts/hadf-phase2bis-collect.py`
- Modify: `.gitattributes` (add raw + heartbeat + cost log to merge driver)
- Create: `.claude/shared/hadf/phase2bis-deploy-verification/` (directory for preflight test artifacts)
- Create: `tests/framework/test_hadf_wrapper_preflight.sh`

- [ ] **Step 1: Write failing preflight test (deliberate-break)**

```bash
# tests/framework/test_hadf_wrapper_preflight.sh
#!/bin/bash
# Verifies the wrapper preflight self-check (Fix #3) detects:
# (a) missing venv binary
# (b) missing required Python import
# (c) missing .env.local (not symlink, not file)
# (d) empty required API key after sourcing
# Each scenario must produce exit 78 (EX_CONFIG)

set -e
TMPDIR=$(mktemp -d)
cd "$TMPDIR"

# Scenario A: missing venv binary
mkdir -p .venv/bin
# (no python3 binary)
touch .env.local
bash /Volumes/DevSSD/FitTracker2/scripts/hadf-phase2bis-collect.sh --subexp test --dry-run 2>err.log
RC=$?
if [ "$RC" != "78" ]; then
    echo "FAIL: missing venv expected exit 78, got $RC" >&2
    cat err.log >&2
    exit 1
fi

# Scenario B: missing .env.local
rm -f .env.local
bash /Volumes/DevSSD/FitTracker2/scripts/hadf-phase2bis-collect.sh --subexp test --dry-run 2>err.log
RC=$?
if [ "$RC" != "78" ]; then
    echo "FAIL: missing .env.local expected exit 78, got $RC" >&2
    exit 1
fi

# Scenario C: empty API key
echo "OPENAI_API_KEY=" > .env.local
bash /Volumes/DevSSD/FitTracker2/scripts/hadf-phase2bis-collect.sh --subexp test --dry-run 2>err.log
RC=$?
if [ "$RC" != "78" ]; then
    echo "FAIL: empty API key expected exit 78, got $RC" >&2
    exit 1
fi

echo "ALL PREFLIGHT TESTS PASSED"
```

- [ ] **Step 2: Run test (should fail — wrapper doesn't exist yet)**

```bash
chmod +x tests/framework/test_hadf_wrapper_preflight.sh
tests/framework/test_hadf_wrapper_preflight.sh
```

Expected: FAIL with "scripts/hadf-phase2bis-collect.sh: No such file or directory"

- [ ] **Step 3: Implement wrapper with all 4 fixes**

```bash
cat > scripts/hadf-phase2bis-collect.sh <<'EOF'
#!/bin/bash
# HADF Phase 2-bis collection wrapper
# Fixes: #1 worktree-local venv (real dir, not symlink) - relies on operator setup
#        #2 .env.local copied (not symlink) - validated by preflight check
#        #3 wrapper preflight self-check - this script
#        #4 raw-data preservation - .claude/shared/hadf/phase2bis-raw-<subexp>-<run>.jsonl

set -uo pipefail  # NOT set -e: we handle errors explicitly per check

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SUBEXP=""
DRY_RUN=false
RUN_ID=""
HEARTBEAT_LEDGER="$REPO_ROOT/.claude/shared/hadf/phase2bis-fire-heartbeat.jsonl"

# Parse args
while [[ $# -gt 0 ]]; do
    case "$1" in
        --subexp) SUBEXP="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        --run-id) RUN_ID="$2"; shift 2 ;;
        *) echo "unknown arg: $1" >&2; exit 2 ;;
    esac
done

if [ -z "$SUBEXP" ]; then
    echo "ERROR: --subexp required" >&2
    exit 2
fi

[ -z "$RUN_ID" ] && RUN_ID="$SUBEXP-$(date -u +%Y-%m-%dT%H-%M-%SZ)"

PREFLIGHT_LOG="$REPO_ROOT/.claude/shared/hadf/phase2bis-deploy-verification/preflight-$RUN_ID.log"
mkdir -p "$(dirname "$PREFLIGHT_LOG")"

log_preflight() { echo "$(date -u +%FT%TZ) [$RUN_ID] $*" | tee -a "$PREFLIGHT_LOG" >&2; }

# Heartbeat: fire_started
emit_heartbeat() {
    local event="$1"
    local extra="${2:-}"
    local ts=$(date -u +%FT%TZ)
    echo "{\"timestamp\":\"$ts\",\"subexp\":\"$SUBEXP\",\"run_id\":\"$RUN_ID\",\"event\":\"$event\"$extra}" \
        >> "$HEARTBEAT_LEDGER"
}

# ── Fix #3 PREFLIGHT CHECKS (any failure = exit 78 EX_CONFIG) ──

# Check A: venv binary executable
VENV_PYTHON="$(pwd)/.venv/bin/python3"
if [ ! -x "$VENV_PYTHON" ]; then
    log_preflight "PREFLIGHT FAIL [A]: venv python missing or not executable: $VENV_PYTHON"
    emit_heartbeat "preflight_failed" ",\"check\":\"venv_binary\""
    exit 78
fi

# Check B: required Python imports succeed
REQUIRED_IMPORTS="openai anthropic json sys time"
for mod in $REQUIRED_IMPORTS; do
    if ! "$VENV_PYTHON" -c "import $mod" 2>/dev/null; then
        log_preflight "PREFLIGHT FAIL [B]: required import failed: $mod"
        emit_heartbeat "preflight_failed" ",\"check\":\"import_$mod\""
        exit 78
    fi
done

# Check C: .env.local exists as REGULAR FILE (not symlink, not missing) — Fix #2
ENV_FILE="$(pwd)/.env.local"
if [ ! -e "$ENV_FILE" ]; then
    log_preflight "PREFLIGHT FAIL [C]: .env.local does not exist: $ENV_FILE"
    emit_heartbeat "preflight_failed" ",\"check\":\"env_local_missing\""
    exit 78
fi
if [ -L "$ENV_FILE" ]; then
    log_preflight "PREFLIGHT FAIL [C]: .env.local is a symlink (must be regular file per Fix #2): $ENV_FILE"
    emit_heartbeat "preflight_failed" ",\"check\":\"env_local_symlink\""
    exit 78
fi

# Check D: required API keys non-empty after sourcing
set -a
source "$ENV_FILE"
set +a

case "$SUBEXP" in
    subexp1)  REQUIRED_KEYS="OPENAI_API_KEY ANTHROPIC_API_KEY GOOGLE_API_KEY VERCEL_AI_GATEWAY_KEY MISTRAL_API_KEY XAI_API_KEY" ;;
    subexp2)  REQUIRED_KEYS="" ;;  # Ollama is local, no API key
    subexp3)  REQUIRED_KEYS="OPENAI_API_KEY ANTHROPIC_API_KEY AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY" ;;
    test)     REQUIRED_KEYS="OPENAI_API_KEY" ;;  # for preflight test fixture
    *)        REQUIRED_KEYS="" ;;
esac

for key in $REQUIRED_KEYS; do
    val="${!key:-}"
    if [ -z "$val" ]; then
        log_preflight "PREFLIGHT FAIL [D]: required API key empty after sourcing: $key"
        emit_heartbeat "preflight_failed" ",\"check\":\"key_$key\""
        exit 78
    fi
done

log_preflight "PREFLIGHT OK"

# Dry-run mode exits here after preflight succeeds (smoke-fire uses this)
if [ "$DRY_RUN" = true ]; then
    log_preflight "DRY_RUN mode: preflight passed; exiting before collection"
    emit_heartbeat "dry_run_complete"
    exit 0
fi

# ── Fire start ──
emit_heartbeat "fire_started"

# Delegate to Python driver (Fix #4 raw-data preservation handled there)
RAW_PATH="$REPO_ROOT/.claude/shared/hadf/phase2bis-raw-${SUBEXP}-${RUN_ID}.jsonl"
"$VENV_PYTHON" "$REPO_ROOT/scripts/hadf-phase2bis-collect.py" \
    --subexp "$SUBEXP" --run-id "$RUN_ID" --raw-out "$RAW_PATH"
COLLECT_RC=$?

# ── Fire end ──
RECORDS=0
if [ -f "$RAW_PATH" ]; then
    RECORDS=$(wc -l < "$RAW_PATH")
fi
emit_heartbeat "fire_ended" ",\"records_landed\":$RECORDS,\"collect_rc\":$COLLECT_RC"

# Cost log entry (T2-C)
COST_LOG="$REPO_ROOT/.claude/shared/hadf/phase2bis-cost-log.jsonl"
COST=$("$VENV_PYTHON" "$REPO_ROOT/scripts/hadf-cost-estimate.py" \
    --provider stub --endpoint stub --calls "$RECORDS" --avg-output-tokens 200 2>/dev/null || echo "0")
echo "{\"timestamp\":\"$(date -u +%FT%TZ)\",\"subexp\":\"$SUBEXP\",\"run_id\":\"$RUN_ID\",\"records\":$RECORDS,\"estimated_cost_usd\":$COST}" \
    >> "$COST_LOG"

exit $COLLECT_RC
EOF
chmod +x scripts/hadf-phase2bis-collect.sh
```

- [ ] **Step 4: Implement Python collection driver (Fix #4 raw-data preservation)**

```python
# scripts/hadf-phase2bis-collect.py
"""HADF Phase 2-bis collection driver. Called by hadf-phase2bis-collect.sh after preflight.

Per spec §2 + §4: 50 calls per endpoint, max_output_tokens=200, temp=0.7,
60s timeout (600s for Ollama), streaming required, no system prompt, no tools.

Writes raw .jsonl atomically (Fix #4): one line per call with TTFT, TPS, total_tokens, status.

NOTE: This is a SCAFFOLD per the implementation plan. Provider-specific call code
is stubbed pending operator API key + endpoint verification at smoke-fire time (Task A5).
The full driver is filled in iteratively during the soak window (post-A5).
"""
import argparse
import json
import sys
import time
from pathlib import Path

# Endpoint matrices per sub-exp (spec §2)
ENDPOINTS = {
    "subexp1": [
        ("openai", "gpt-4o-mini", "direct"),
        ("openai", "gpt-4o", "direct"),
        ("anthropic", "claude-haiku-4-5", "direct"),
        ("anthropic", "claude-sonnet-4-6", "direct"),
        ("google", "gemini-2-flash", "direct"),
        ("google", "gemini-2-pro", "direct"),
        ("vercel-ai-gateway", "gpt-4o-mini", "gateway"),
        ("mistral", "mistral-large-latest", "direct"),
        ("xai", "grok-4-1", "direct"),
    ],
    "subexp2": [
        ("ollama", "llama3.2:3b", "local"),
    ],
    "subexp3": [
        ("openai", "gpt-4o-mini", "direct"),
        ("anthropic", "claude-haiku-4-5", "direct"),
        ("aws-bedrock", "anthropic.claude-haiku-4-5", "bedrock"),
    ],
}

CALLS_PER_FIRE = 50
MAX_OUTPUT_TOKENS = 200
TEMPERATURE = 0.7
TIMEOUT_S = 60
OLLAMA_TIMEOUT_S = 600

def call_endpoint(provider, endpoint, prompt):
    """Stub. Replaced with provider-specific code post-A5 smoke-fire verification."""
    raise NotImplementedError(
        f"Provider call code not yet implemented for {provider}/{endpoint}. "
        "Filled in iteratively during soak window after Task A5 smoke-fire passes."
    )

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--subexp", required=True)
    p.add_argument("--run-id", required=True)
    p.add_argument("--raw-out", required=True)
    args = p.parse_args()

    if args.subexp not in ENDPOINTS:
        print(f"unknown sub-exp: {args.subexp}", file=sys.stderr)
        sys.exit(2)

    raw_path = Path(args.raw_out)
    raw_path.parent.mkdir(parents=True, exist_ok=True)

    # Load frozen prompt set (created in Task A5b — smoke-fire prerequisite)
    prompt_set_path = Path(__file__).parent.parent / ".claude/shared/hadf/phase2bis-prompt-set.json"
    if not prompt_set_path.exists():
        print(f"prompt set not found: {prompt_set_path}", file=sys.stderr)
        print("Run Task A5 to scaffold + freeze the 50-prompt set", file=sys.stderr)
        sys.exit(2)
    prompts = json.loads(prompt_set_path.read_text())["prompts"]
    assert len(prompts) == CALLS_PER_FIRE, f"prompt set must have exactly {CALLS_PER_FIRE} entries"

    # Atomic write: tmp file + rename
    tmp_path = raw_path.with_suffix(raw_path.suffix + ".tmp")
    written = 0
    with tmp_path.open("w") as f:
        for provider, endpoint, api_kind in ENDPOINTS[args.subexp]:
            for i, prompt in enumerate(prompts):
                t_start = time.time()
                try:
                    result = call_endpoint(provider, endpoint, prompt)
                    record = {
                        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                        "subexp": args.subexp,
                        "run_id": args.run_id,
                        "provider": provider,
                        "endpoint": endpoint,
                        "api_kind": api_kind,
                        "prompt_idx": i,
                        "ttft_s": result["ttft_s"],
                        "tps": result["tps"],
                        "output_tokens": result["output_tokens"],
                        "total_s": time.time() - t_start,
                        "status": "ok",
                    }
                except NotImplementedError as e:
                    record = {
                        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                        "subexp": args.subexp,
                        "run_id": args.run_id,
                        "provider": provider,
                        "endpoint": endpoint,
                        "prompt_idx": i,
                        "status": "stub",
                        "error": str(e),
                    }
                except Exception as e:
                    record = {
                        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                        "subexp": args.subexp,
                        "run_id": args.run_id,
                        "provider": provider,
                        "endpoint": endpoint,
                        "prompt_idx": i,
                        "status": "error",
                        "error": str(e),
                    }
                f.write(json.dumps(record) + "\n")
                written += 1
    # Atomic rename (Fix #4: raw-data preservation never partially-written)
    tmp_path.replace(raw_path)
    print(f"wrote {written} records to {raw_path}")

if __name__ == "__main__":
    main()
```

- [ ] **Step 5: Add raw .jsonl + heartbeat + cost log to Mechanism E merge driver**

```bash
cat >> .gitattributes <<'EOF'
.claude/shared/hadf/phase2bis-raw-*.jsonl merge=union-dedup-by-key
.claude/shared/hadf/phase2bis-fire-heartbeat.jsonl merge=union-dedup-by-key
.claude/shared/hadf/phase2bis-cost-log.jsonl merge=union-dedup-by-key
EOF
```

- [ ] **Step 6: Run preflight test (3 deliberate-break scenarios)**

```bash
tests/framework/test_hadf_wrapper_preflight.sh
```

Expected: `ALL PREFLIGHT TESTS PASSED` (3 scenarios all exit 78 as designed)

- [ ] **Step 7: Commit**

```bash
git add scripts/hadf-phase2bis-collect.sh scripts/hadf-phase2bis-collect.py .gitattributes tests/framework/test_hadf_wrapper_preflight.sh
git commit -m "feat(hadf-phase2bis): wrapper with 4 architectural fixes + preflight test (3 break scenarios pass)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task A3: Heartbeat ledger + audit script (T2-A)

**Files:**
- Create: `.claude/shared/hadf/phase2bis-fire-heartbeat.jsonl` (empty file with .gitkeep)
- Create: `scripts/hadf-phase2bis-heartbeat-audit.py`
- Create: `tests/framework/test_hadf_heartbeat_audit.py`

- [ ] **Step 1: Initialize empty heartbeat ledger**

```bash
touch .claude/shared/hadf/phase2bis-fire-heartbeat.jsonl
```

- [ ] **Step 2: Write failing test for audit script**

```python
# tests/framework/test_hadf_heartbeat_audit.py
import json
import subprocess
import tempfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]

def test_audit_detects_missed_fires():
    """Plist expects 5 fires; ledger has only 3 fire_started events → 2 missed."""
    with tempfile.TemporaryDirectory() as td:
        ledger = Path(td) / "heartbeat.jsonl"
        ledger.write_text(
            '{"timestamp":"2026-05-23T02:00:00Z","subexp":"subexp1","event":"fire_started"}\n'
            '{"timestamp":"2026-05-23T02:11:00Z","subexp":"subexp1","event":"fire_ended","records_landed":50}\n'
            '{"timestamp":"2026-05-23T08:00:00Z","subexp":"subexp1","event":"fire_started"}\n'
            '{"timestamp":"2026-05-23T08:11:00Z","subexp":"subexp1","event":"fire_ended","records_landed":50}\n'
            '{"timestamp":"2026-05-23T22:00:00Z","subexp":"subexp1","event":"fire_started"}\n'
            '{"timestamp":"2026-05-23T22:11:00Z","subexp":"subexp1","event":"fire_ended","records_landed":50}\n'
        )
        result = subprocess.run(
            ["python3", str(REPO_ROOT / "scripts/hadf-phase2bis-heartbeat-audit.py"),
             "--ledger", str(ledger),
             "--subexp", "subexp1",
             "--date", "2026-05-23",
             "--expected-times", "02:00,08:00,14:00,18:00,22:00"],
            capture_output=True, text=True
        )
        assert result.returncode == 0, result.stderr
        report = json.loads(result.stdout)
        assert report["fires_expected"] == 5
        assert report["fires_started"] == 3
        assert report["fires_completed"] == 3
        assert sorted(report["missed_fires"]) == ["14:00", "18:00"]

def test_audit_no_missed_fires():
    with tempfile.TemporaryDirectory() as td:
        ledger = Path(td) / "heartbeat.jsonl"
        events = []
        for hh in ["02:00", "08:00", "14:00", "18:00", "22:00"]:
            events.append(f'{{"timestamp":"2026-05-23T{hh}:00Z","subexp":"subexp1","event":"fire_started"}}')
            events.append(f'{{"timestamp":"2026-05-23T{hh.split(":")[0]}:11:00Z","subexp":"subexp1","event":"fire_ended","records_landed":50}}')
        ledger.write_text("\n".join(events) + "\n")
        result = subprocess.run(
            ["python3", str(REPO_ROOT / "scripts/hadf-phase2bis-heartbeat-audit.py"),
             "--ledger", str(ledger),
             "--subexp", "subexp1",
             "--date", "2026-05-23",
             "--expected-times", "02:00,08:00,14:00,18:00,22:00"],
            capture_output=True, text=True
        )
        report = json.loads(result.stdout)
        assert report["missed_fires"] == []
```

- [ ] **Step 3: Run test (should fail — script doesn't exist)**

Run: `.venv/bin/python3 -m pytest tests/framework/test_hadf_heartbeat_audit.py -v`
Expected: FAIL

- [ ] **Step 4: Implement audit script**

```python
# scripts/hadf-phase2bis-heartbeat-audit.py
"""Reconcile launchd plist fire schedule against heartbeat ledger.

Reports missed fires (expected per StartCalendarInterval but no fire_started event in ledger
within 24h of expected time). Designed to run as a daily cron during sub-exp collection.
"""
import argparse
import json
import sys
from pathlib import Path

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--ledger", required=True)
    p.add_argument("--subexp", required=True)
    p.add_argument("--date", required=True, help="YYYY-MM-DD")
    p.add_argument("--expected-times", required=True, help="HH:MM,HH:MM,... in UTC")
    args = p.parse_args()

    expected = args.expected_times.split(",")
    events = []
    for line in Path(args.ledger).read_text().splitlines():
        if not line.strip():
            continue
        try:
            ev = json.loads(line)
        except json.JSONDecodeError:
            continue
        if ev.get("subexp") != args.subexp:
            continue
        ts = ev.get("timestamp", "")
        if not ts.startswith(args.date):
            continue
        events.append(ev)

    started_times = set()
    completed_times = set()
    for ev in events:
        if ev.get("event") == "fire_started":
            ts = ev["timestamp"]
            hhmm = ts.split("T")[1][:5]
            started_times.add(hhmm)
        elif ev.get("event") == "fire_ended":
            ts = ev["timestamp"]
            hhmm = ts.split("T")[1][:5]
            completed_times.add(hhmm)

    # Match started times to nearest expected time (within ±15 min)
    matched = set()
    for exp in expected:
        eh, em = map(int, exp.split(":"))
        for actual in started_times:
            ah, am = map(int, actual.split(":"))
            delta = abs((ah * 60 + am) - (eh * 60 + em))
            if delta <= 15:
                matched.add(exp)
                break

    missed = sorted(set(expected) - matched)
    report = {
        "subexp": args.subexp,
        "date": args.date,
        "fires_expected": len(expected),
        "fires_started": len(started_times),
        "fires_completed": len(completed_times),
        "missed_fires": missed,
    }
    print(json.dumps(report))

if __name__ == "__main__":
    main()
```

- [ ] **Step 5: Run tests to verify pass**

Run: `.venv/bin/python3 -m pytest tests/framework/test_hadf_heartbeat_audit.py -v`
Expected: 2 PASSED

- [ ] **Step 6: Commit**

```bash
git add scripts/hadf-phase2bis-heartbeat-audit.py tests/framework/test_hadf_heartbeat_audit.py .claude/shared/hadf/phase2bis-fire-heartbeat.jsonl
git commit -m "feat(hadf-phase2bis): heartbeat ledger T2-A + audit script (2 tests pass)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task A4: Cost ceiling enforcement T2-C

**Files:**
- Create: `.claude/shared/hadf/phase2bis-cost-log.jsonl` (empty)
- Create: `scripts/hadf-cost-cron.py`
- Create: `tests/framework/test_hadf_cost_cron.py`

- [ ] **Step 1: Initialize empty cost log**

```bash
touch .claude/shared/hadf/phase2bis-cost-log.jsonl
```

- [ ] **Step 2: Write failing test**

```python
# tests/framework/test_hadf_cost_cron.py
import json
import subprocess
import tempfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]

def test_cost_cron_under_ceiling():
    """Cumulative $5 over the day for subexp1 → exit 0, no bootout"""
    with tempfile.TemporaryDirectory() as td:
        log = Path(td) / "cost.jsonl"
        log.write_text(
            '{"timestamp":"2026-05-23T02:00:00Z","subexp":"subexp1","records":50,"estimated_cost_usd":1.0}\n'
            '{"timestamp":"2026-05-23T08:00:00Z","subexp":"subexp1","records":50,"estimated_cost_usd":1.5}\n'
            '{"timestamp":"2026-05-23T14:00:00Z","subexp":"subexp1","records":50,"estimated_cost_usd":2.5}\n'
        )
        result = subprocess.run(
            ["python3", str(REPO_ROOT / "scripts/hadf-cost-cron.py"),
             "--log", str(log),
             "--subexp", "subexp1",
             "--ceiling-usd", "15",
             "--check-only"],
            capture_output=True, text=True
        )
        assert result.returncode == 0
        report = json.loads(result.stdout)
        assert report["cumulative_usd"] == 5.0
        assert report["exceeded"] is False
        assert report["bootout_recommended"] is False

def test_cost_cron_over_ceiling():
    """Cumulative $20 → exceeds $15 ceiling → exit 0 with bootout_recommended=true"""
    with tempfile.TemporaryDirectory() as td:
        log = Path(td) / "cost.jsonl"
        log.write_text(
            '{"timestamp":"2026-05-23T02:00:00Z","subexp":"subexp1","estimated_cost_usd":7.0}\n'
            '{"timestamp":"2026-05-23T08:00:00Z","subexp":"subexp1","estimated_cost_usd":8.0}\n'
            '{"timestamp":"2026-05-23T14:00:00Z","subexp":"subexp1","estimated_cost_usd":5.0}\n'
        )
        result = subprocess.run(
            ["python3", str(REPO_ROOT / "scripts/hadf-cost-cron.py"),
             "--log", str(log),
             "--subexp", "subexp1",
             "--ceiling-usd", "15",
             "--check-only"],
            capture_output=True, text=True
        )
        assert result.returncode == 0
        report = json.loads(result.stdout)
        assert report["cumulative_usd"] == 20.0
        assert report["exceeded"] is True
        assert report["bootout_recommended"] is True
```

- [ ] **Step 3: Run test (should fail)**

Run: `.venv/bin/python3 -m pytest tests/framework/test_hadf_cost_cron.py -v`
Expected: FAIL

- [ ] **Step 4: Implement cost cron**

```python
# scripts/hadf-cost-cron.py
"""Daily cost ceiling check for HADF Phase 2-bis.

--check-only: report cumulative + exceeded flag (used by tests)
default: if exceeded, run `launchctl bootout` on the sub-exp plist
"""
import argparse
import json
import subprocess
import sys
from pathlib import Path

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--log", required=True)
    p.add_argument("--subexp", required=True)
    p.add_argument("--ceiling-usd", type=float, default=15.0)
    p.add_argument("--check-only", action="store_true")
    p.add_argument("--plist-label", default=None,
                   help="launchd label for bootout (e.g. com.fitme.hadf-phase2bis-subexp1)")
    args = p.parse_args()

    cumulative = 0.0
    for line in Path(args.log).read_text().splitlines():
        if not line.strip():
            continue
        try:
            entry = json.loads(line)
        except json.JSONDecodeError:
            continue
        if entry.get("subexp") != args.subexp:
            continue
        cumulative += entry.get("estimated_cost_usd", 0.0)

    exceeded = cumulative > args.ceiling_usd
    report = {
        "subexp": args.subexp,
        "cumulative_usd": cumulative,
        "ceiling_usd": args.ceiling_usd,
        "exceeded": exceeded,
        "bootout_recommended": exceeded,
    }
    print(json.dumps(report))

    if exceeded and not args.check_only and args.plist_label:
        result = subprocess.run(
            ["launchctl", "bootout", f"gui/{Path.home().stat().st_uid}/{args.plist_label}"],
            capture_output=True, text=True
        )
        print(f"launchctl bootout: rc={result.returncode}", file=sys.stderr)

if __name__ == "__main__":
    main()
```

- [ ] **Step 5: Run tests to verify pass**

Run: `.venv/bin/python3 -m pytest tests/framework/test_hadf_cost_cron.py -v`
Expected: 2 PASSED

- [ ] **Step 6: Commit**

```bash
git add scripts/hadf-cost-cron.py tests/framework/test_hadf_cost_cron.py .claude/shared/hadf/phase2bis-cost-log.jsonl
git commit -m "feat(hadf-phase2bis): cost ceiling cron T2-C (\$15 daily ceiling, 2 tests pass)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task A5: Pre-flight smoke-fire T2-D + 50-prompt set

**Files:**
- Create: `scripts/hadf-phase2bis-smoke-fire.sh`
- Create: `.claude/shared/hadf/phase2bis-prompt-set.json` (50 frozen prompts)

- [ ] **Step 1: Create the 50-prompt set (frozen pre-launch)**

The 50 prompts span coding, math, factual recall, and creative writing — same distribution as Phase 2 to enable anchor comparison.

```bash
cat > .claude/shared/hadf/phase2bis-prompt-set.json <<'EOF'
{
  "frozen_at": "2026-05-12",
  "total": 50,
  "categories": {"coding": 10, "math": 10, "factual": 10, "creative": 10, "reasoning": 10},
  "prompts": [
    {"id": "c01", "category": "coding", "text": "Write a Python function that returns the nth Fibonacci number using memoization."},
    {"id": "c02", "category": "coding", "text": "Implement a binary search in JavaScript that returns the index of a target in a sorted array."},
    {"id": "c03", "category": "coding", "text": "Write a SQL query to find the second highest salary from an Employees table."},
    {"id": "c04", "category": "coding", "text": "Write a Bash one-liner that counts lines in all .py files under src/."},
    {"id": "c05", "category": "coding", "text": "Implement a debounce function in TypeScript with a 300ms delay."},
    {"id": "c06", "category": "coding", "text": "Write a Rust function that reverses a string in place."},
    {"id": "c07", "category": "coding", "text": "Write a regex that matches ISO 8601 dates."},
    {"id": "c08", "category": "coding", "text": "Implement merge sort in Go."},
    {"id": "c09", "category": "coding", "text": "Write a Python decorator that retries a function up to 3 times on exception."},
    {"id": "c10", "category": "coding", "text": "Write a CSS selector that targets every other row in a table."},
    {"id": "m01", "category": "math", "text": "What is the integral of x^2 from 0 to 5?"},
    {"id": "m02", "category": "math", "text": "Solve for x: 3x^2 + 7x - 4 = 0."},
    {"id": "m03", "category": "math", "text": "What is the determinant of [[1,2],[3,4]]?"},
    {"id": "m04", "category": "math", "text": "If f(x) = sin(x), what is f'(pi/4)?"},
    {"id": "m05", "category": "math", "text": "Compute the sum of the geometric series 1 + 1/2 + 1/4 + ... + 1/512."},
    {"id": "m06", "category": "math", "text": "What is the probability of drawing 2 aces from a standard 52-card deck without replacement?"},
    {"id": "m07", "category": "math", "text": "Find the eigenvalues of [[2,0],[0,3]]."},
    {"id": "m08", "category": "math", "text": "What is the limit of (sin x)/x as x approaches 0?"},
    {"id": "m09", "category": "math", "text": "Convert 0.625 to a fraction in lowest terms."},
    {"id": "m10", "category": "math", "text": "What is the area of a triangle with vertices (0,0), (3,0), (0,4)?"},
    {"id": "f01", "category": "factual", "text": "Who wrote the novel 'One Hundred Years of Solitude'?"},
    {"id": "f02", "category": "factual", "text": "What is the chemical symbol for tungsten?"},
    {"id": "f03", "category": "factual", "text": "In what year did the Berlin Wall fall?"},
    {"id": "f04", "category": "factual", "text": "What is the largest moon of Jupiter?"},
    {"id": "f05", "category": "factual", "text": "Who painted 'The Starry Night'?"},
    {"id": "f06", "category": "factual", "text": "What is the capital of Mongolia?"},
    {"id": "f07", "category": "factual", "text": "What language is spoken in Brazil?"},
    {"id": "f08", "category": "factual", "text": "What is the longest river in Africa?"},
    {"id": "f09", "category": "factual", "text": "Who discovered penicillin?"},
    {"id": "f10", "category": "factual", "text": "In what year was the United Nations founded?"},
    {"id": "w01", "category": "creative", "text": "Write a 4-line poem about autumn."},
    {"id": "w02", "category": "creative", "text": "Write a one-paragraph short story that begins with 'The lighthouse keeper noticed something strange.'"},
    {"id": "w03", "category": "creative", "text": "Describe a futuristic city in 3 sentences."},
    {"id": "w04", "category": "creative", "text": "Write a haiku about the ocean."},
    {"id": "w05", "category": "creative", "text": "Invent a dialogue between a clock and a calendar."},
    {"id": "w06", "category": "creative", "text": "Write a 50-word product description for a hiking backpack."},
    {"id": "w07", "category": "creative", "text": "Compose a wedding toast in 3 sentences."},
    {"id": "w08", "category": "creative", "text": "Describe the smell of rain in 2 sentences without using the word 'rain'."},
    {"id": "w09", "category": "creative", "text": "Write the opening line of a mystery novel set in a bakery."},
    {"id": "w10", "category": "creative", "text": "Write a 4-line poem in the style of haiku about a programmer's deadline."},
    {"id": "r01", "category": "reasoning", "text": "If all roses are flowers and some flowers fade quickly, can we conclude that some roses fade quickly? Explain."},
    {"id": "r02", "category": "reasoning", "text": "A train leaves City A at 10:00 going 60 mph. Another leaves City B at 11:00 going 80 mph toward A. They are 280 miles apart. When do they meet?"},
    {"id": "r03", "category": "reasoning", "text": "You have 9 coins; one is heavier. Using a balance scale only twice, find the heavy coin."},
    {"id": "r04", "category": "reasoning", "text": "Three switches outside a closed room control three bulbs inside. You may enter the room only once. How do you determine which switch controls which bulb?"},
    {"id": "r05", "category": "reasoning", "text": "If today is Wednesday, what day of the week was it 100 days ago?"},
    {"id": "r06", "category": "reasoning", "text": "A bat and a ball cost $1.10. The bat costs $1.00 more than the ball. How much does the ball cost?"},
    {"id": "r07", "category": "reasoning", "text": "Five people are in a room. Each shakes hands with every other person once. How many handshakes total?"},
    {"id": "r08", "category": "reasoning", "text": "A father is 4 times as old as his son. In 20 years he will be twice as old. What are their current ages?"},
    {"id": "r09", "category": "reasoning", "text": "If you flip a fair coin 3 times, what is the probability of getting at least one heads?"},
    {"id": "r10", "category": "reasoning", "text": "Pipe A fills a tank in 6 hours; Pipe B in 4 hours. Both open, how long to fill?"}
  ]
}
EOF
```

- [ ] **Step 2: Implement smoke-fire script**

```bash
cat > scripts/hadf-phase2bis-smoke-fire.sh <<'EOF'
#!/bin/bash
# Pre-flight smoke-fire (T2-D): 1 call/endpoint shake-out under same wrapper.
# Aborts on any error response. Catches: API key has no quota, model id rejected,
# endpoint URL changed, streaming protocol changed.
#
# Usage: scripts/hadf-phase2bis-smoke-fire.sh <subexp-id>
# Output: SMOKE_FIRE_OK or SMOKE_FIRE_FAIL with details

set -uo pipefail

SUBEXP="${1:-}"
if [ -z "$SUBEXP" ]; then
    echo "ERROR: subexp-id required (subexp1, subexp2, or subexp3)" >&2
    exit 2
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SMOKE_DIR="$REPO_ROOT/.claude/shared/hadf/phase2bis-deploy-verification"
mkdir -p "$SMOKE_DIR"
SMOKE_LOG="$SMOKE_DIR/smoke-fire-$SUBEXP-$(date -u +%Y-%m-%dT%H-%M-%SZ).log"

echo "Running smoke-fire for $SUBEXP..." | tee "$SMOKE_LOG"

# Use wrapper in dry-run mode first to validate preflight passes
"$REPO_ROOT/scripts/hadf-phase2bis-collect.sh" --subexp "$SUBEXP" --dry-run 2>&1 | tee -a "$SMOKE_LOG"
if [ "${PIPESTATUS[0]}" != "0" ]; then
    echo "SMOKE_FIRE_FAIL: preflight failed for $SUBEXP" | tee -a "$SMOKE_LOG"
    exit 1
fi

# Then 1-call/endpoint actual fire (needs real API hits — operator-driven)
# For now, scaffold marks success on preflight pass; full smoke implementation
# fills in after first real provider call code lands (post-A5 iteration).
echo "SMOKE_FIRE_OK: preflight passed (full 1-call/endpoint TBD when provider call code implemented)" | tee -a "$SMOKE_LOG"
EOF
chmod +x scripts/hadf-phase2bis-smoke-fire.sh
```

- [ ] **Step 3: Verify scripts run + log directory exists**

Run: `bash scripts/hadf-phase2bis-smoke-fire.sh subexp1 2>&1 | tail -3`
Expected: `SMOKE_FIRE_OK` OR `SMOKE_FIRE_FAIL` (depending on whether `.env.local` is present in current worktree — both are valid responses; failure here means the wrapper preflight check is doing its job)

- [ ] **Step 4: Commit**

```bash
git add scripts/hadf-phase2bis-smoke-fire.sh .claude/shared/hadf/phase2bis-prompt-set.json
git commit -m "feat(hadf-phase2bis): smoke-fire T2-D + frozen 50-prompt set (5 categories × 10)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task A6: Pre-registration scaffolding + lock script

**Files:**
- Create: `.claude/shared/hadf/preregistration-phase2bis-subexp{1,2,3}.json`
- Create: `scripts/hadf-phase2bis-lock-prereg.sh`
- Modify: `.githooks/pre-commit` (add prereg-lock check)

- [ ] **Step 1: Create 3 pre-registration skeleton files**

```bash
for n in 1 2 3; do
cat > ".claude/shared/hadf/preregistration-phase2bis-subexp${n}.json" <<EOF
{
  "subexp_id": "phase2bis-subexp${n}",
  "rq": "TBD — fill before lock per spec §1",
  "endpoints": [],
  "per_call_controls": {
    "calls_per_fire": 50,
    "max_output_tokens": 200,
    "temperature": 0.7,
    "timeout_s": 60,
    "streaming_required": true,
    "system_prompt": null,
    "tools": null,
    "prompt_set_path": ".claude/shared/hadf/phase2bis-prompt-set.json",
    "prompt_set_sha256": "TBD — computed at lock time"
  },
  "campaign_schedule": {
    "fires_per_day": 5,
    "fire_times_utc": ["02:00", "08:00", "14:00", "18:00", "22:00"],
    "duration_days": 3
  },
  "primary_metric": "silhouette score at k=5",
  "expected_yield_threshold": 600,
  "kill_criteria": [
    "n_valid < 600",
    "all endpoints simultaneously rate-limited > 2 fires consecutively",
    "ANY endpoint changes streaming protocol or model id mid-collection",
    "wrapper preflight fails 3+ times consecutively"
  ],
  "trip_wires": [
    {"name": "anchor_drift", "applies_to": "subexp3 only", "action": "methodology note, do not abort"},
    {"name": "cost_overrun_3x", "action": "pause for operator review"}
  ],
  "verdict_thresholds": {
    "pass_silhouette_min": 0.5,
    "pass_yield_min": 600,
    "fail_clusters_lt": 3
  },
  "harness_hardening_proof": {
    "env_local_sha256_at_deploy": "TBD — computed at lock time",
    "fix1_commit_hash": "TBD — git SHA where worktree-local venv was introduced",
    "preflight_test_log_path": ".claude/shared/hadf/phase2bis-deploy-verification/subexp${n}-deliberate-break.log",
    "state_owner_at_creation": "ft2"
  }
}
EOF
done
```

- [ ] **Step 2: Implement lock script**

```bash
cat > scripts/hadf-phase2bis-lock-prereg.sh <<'EOF'
#!/bin/bash
# Hash-lock a pre-registration JSON. Once locked:
# - .lock sibling file written with sha256 + timestamp + git commit
# - git tag created and pushed
# - pre-commit hook rejects further edits (unless lock is also removed)
#
# Usage: scripts/hadf-phase2bis-lock-prereg.sh <subexp-id>

set -euo pipefail

SUBEXP="${1:-}"
if [ -z "$SUBEXP" ]; then
    echo "ERROR: subexp-id required" >&2
    exit 2
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PREREG="$REPO_ROOT/.claude/shared/hadf/preregistration-phase2bis-${SUBEXP}.json"
LOCK="${PREREG}.lock"

if [ ! -f "$PREREG" ]; then
    echo "ERROR: prereg not found: $PREREG" >&2
    exit 2
fi
if [ -f "$LOCK" ]; then
    echo "ERROR: already locked: $LOCK" >&2
    exit 2
fi

# Validate JSON parses
python3 -c "import json; json.load(open('$PREREG'))"

# Compute sha256
SHA=$(shasum -a 256 "$PREREG" | awk '{print $1}')
TS=$(date -u +%FT%TZ)
USER=$(git config user.email)
COMMIT=$(git rev-parse HEAD)

# Write lock
cat > "$LOCK" <<LOCKEOF
{
  "sha256": "$SHA",
  "locked_at": "$TS",
  "locked_by": "$USER",
  "locked_commit": "$COMMIT"
}
LOCKEOF

# Git tag
TAG="prereg-phase2bis-${SUBEXP}-locked-$(date -u +%Y-%m-%d)"
git add "$PREREG" "$LOCK"
git commit -m "chore(hadf-phase2bis): lock prereg ${SUBEXP} (sha256=${SHA:0:12})"
git tag -a "$TAG" -m "Pre-registration locked for ${SUBEXP} at sha256=${SHA:0:12}"
git push origin "$TAG"

echo "Locked: $LOCK"
echo "Tag: $TAG"
echo "SHA: $SHA"
EOF
chmod +x scripts/hadf-phase2bis-lock-prereg.sh
```

- [ ] **Step 3: Add pre-commit lock check**

Find the existing `.githooks/pre-commit` end-of-file marker and add the new check:

```bash
# Read first to find the right append point
tail -10 .githooks/pre-commit
```

Then append (using a marker comment so subsequent edits are findable):

```bash
cat >> .githooks/pre-commit <<'EOF'

# ── HADF Phase 2-bis prereg lock check (added v7.8.3+ HADF P2-bis Task A6) ──
# Reject commits that modify a locked preregistration JSON unless the .lock file is also removed
for prereg in $(git diff --cached --name-only | grep -E "^\.claude/shared/hadf/preregistration-phase2bis-subexp[1-3]\.json$" || true); do
    lock="${prereg}.lock"
    # If prereg modified AND lock still exists → block
    if [ -f "$lock" ]; then
        # Check if lock is being removed in this commit
        if ! git diff --cached --name-only --diff-filter=D | grep -q "^${lock}$"; then
            echo "ERROR: $prereg is locked at $lock — refusing to modify without removing the lock"
            echo "       To unlock: git rm $lock + audit-log entry, then re-stage prereg edit"
            exit 1
        fi
    fi
done
EOF
```

- [ ] **Step 4: Test the lock check by attempting to modify a locked prereg**

```bash
# Simulate a lock for subexp1
cat > ".claude/shared/hadf/preregistration-phase2bis-subexp1.json.lock" <<'EOF'
{"sha256": "test", "locked_at": "2026-05-12T00:00:00Z", "locked_by": "test", "locked_commit": "abc"}
EOF
# Modify the prereg
echo '  "test_dirty": true,' >> .claude/shared/hadf/preregistration-phase2bis-subexp1.json
git add .claude/shared/hadf/preregistration-phase2bis-subexp1.json
.githooks/pre-commit
RC=$?
# Cleanup
git restore --staged .claude/shared/hadf/preregistration-phase2bis-subexp1.json
git checkout .claude/shared/hadf/preregistration-phase2bis-subexp1.json
rm .claude/shared/hadf/preregistration-phase2bis-subexp1.json.lock
[ "$RC" != "0" ] && echo "PASS: lock check blocked the edit" || (echo "FAIL: lock check did not fire" && exit 1)
```

Expected: `PASS: lock check blocked the edit`

- [ ] **Step 5: Commit**

```bash
git add .claude/shared/hadf/preregistration-phase2bis-subexp*.json scripts/hadf-phase2bis-lock-prereg.sh .githooks/pre-commit
git commit -m "feat(hadf-phase2bis): 3 prereg skeletons + lock script + pre-commit lock check

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task A7: Per-sub-exp worktrees scaffold (will be created at sub-exp launch time)

**Files:**
- Create: `.claude/features/hadf-phase2bis-replication/worktrees-runbook.md`

This task documents the worktree creation runbook; the actual worktrees are created at Block B sub-exp launch time (not during Block A scaffolding) so they don't sit idle on disk for 11 days during the soak window.

- [ ] **Step 1: Document worktree creation runbook**

```bash
cat > .claude/features/hadf-phase2bis-replication/worktrees-runbook.md <<'EOF'
# HADF Phase 2-bis — Per-Sub-Exp Worktree Runbook

Per spec §8 and the v7.8.1 BRANCH_ISOLATION_VIOLATION Mode B/C principle, each sub-experiment runs in a dedicated worktree at a sibling path on the SSD.

**Run at sub-exp launch (NOT during soak window).** Each worktree consumes ~2-3 GB.

## Sub-exp 1 (run on or after 2026-05-23)

```bash
# From canonical FT2 worktree
git worktree add /Volumes/DevSSD/FitTracker2-hadf-phase2bis-subexp1 -b feat/hadf-phase2bis-subexp1
cd /Volumes/DevSSD/FitTracker2-hadf-phase2bis-subexp1

# Create worktree-local venv (Fix #1: real directory, NOT symlink)
python3 -m venv .venv
.venv/bin/pip install openai anthropic google-generativeai mistralai requests boto3 pytest scikit-learn numpy

# Copy .env.local from canonical (Fix #2: regular file, NOT symlink)
cp /Volumes/DevSSD/FitTracker2/.env.local .

# Verify it's a regular file (preflight check D will fail otherwise)
file .env.local | grep -q "ASCII text" || (echo "ERROR: .env.local is not a regular text file" && exit 1)

# Update state.json with worktree_path (T2-B: BRANCH_ISOLATION_LAUNCHD_DRIFT compliance)
python3 -c "
import json
p = '.claude/features/hadf-phase2bis-replication/state.json'
s = json.load(open(p))
s['worktree_path'] = '/Volumes/DevSSD/FitTracker2-hadf-phase2bis-subexp1'
json.dump(s, open(p, 'w'), indent=2)
"
git add .claude/features/hadf-phase2bis-replication/state.json
git commit -m "chore(hadf-phase2bis-subexp1): record worktree_path for v7.8.1 LAUNCHD_DRIFT compliance"
git push -u origin feat/hadf-phase2bis-subexp1
```

## Sub-exp 2 (run on or after Sub-exp 1 PASS)

Same flow with `subexp2` substitution.

## Sub-exp 3 (run on or after Sub-exp 2 PASS)

Same flow with `subexp3` substitution. Note Sub-exp 3 needs AWS Bedrock credentials in addition to OpenAI/Anthropic.

## Synthesis (run on or after Sub-exp 3 closure)

```bash
git worktree add /Volumes/DevSSD/FitTracker2-hadf-phase2bis-synthesis -b feat/hadf-phase2bis-synthesis
cd /Volumes/DevSSD/FitTracker2-hadf-phase2bis-synthesis
# No venv needed — synthesis is pure analysis on already-collected data
```
EOF
```

- [ ] **Step 2: Commit**

```bash
git add .claude/features/hadf-phase2bis-replication/worktrees-runbook.md
git commit -m "docs(hadf-phase2bis): per-sub-exp worktree creation runbook (deferred to launch time)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task A8: Anchor-drift trip-wire (Sub-exp 3 only)

**Files:**
- Create: `scripts/hadf-phase2bis-anchor-drift-check.py`
- Create: `tests/framework/test_hadf_anchor_drift.py`

- [ ] **Step 1: Write failing test**

```python
# tests/framework/test_hadf_anchor_drift.py
import json
import subprocess
import tempfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]

def write_jsonl(path, records):
    with open(path, "w") as f:
        for r in records:
            f.write(json.dumps(r) + "\n")

def test_anchor_drift_within_tolerance():
    """Sub-exp 1 + Sub-exp 3 anchor distributions are similar → p > 0.01 → no drift"""
    with tempfile.TemporaryDirectory() as td:
        s1 = Path(td) / "s1.jsonl"
        s3 = Path(td) / "s3.jsonl"
        # Identical TTFT distributions for openai
        records1 = [{"provider": "openai", "endpoint": "gpt-4o-mini", "ttft_s": 0.5 + 0.01*i, "tps": 50.0, "status": "ok"} for i in range(50)]
        records3 = [{"provider": "openai", "endpoint": "gpt-4o-mini", "ttft_s": 0.5 + 0.01*i, "tps": 50.0, "status": "ok"} for i in range(50)]
        write_jsonl(s1, records1)
        write_jsonl(s3, records3)
        result = subprocess.run(
            ["python3", str(REPO_ROOT / "scripts/hadf-phase2bis-anchor-drift-check.py"),
             "--sub-exp-1-raw", str(s1),
             "--sub-exp-3-raw", str(s3),
             "--anchor-provider", "openai",
             "--anchor-endpoint", "gpt-4o-mini"],
            capture_output=True, text=True
        )
        assert result.returncode == 0, result.stderr
        report = json.loads(result.stdout)
        assert report["drift_detected"] is False
        assert report["ks_p_value"] > 0.01

def test_anchor_drift_detected():
    """Sub-exp 3 has shifted TTFT distribution → p < 0.01 → drift detected"""
    with tempfile.TemporaryDirectory() as td:
        s1 = Path(td) / "s1.jsonl"
        s3 = Path(td) / "s3.jsonl"
        records1 = [{"provider": "openai", "endpoint": "gpt-4o-mini", "ttft_s": 0.5 + 0.005*i, "tps": 50.0, "status": "ok"} for i in range(100)]
        records3 = [{"provider": "openai", "endpoint": "gpt-4o-mini", "ttft_s": 2.0 + 0.005*i, "tps": 50.0, "status": "ok"} for i in range(100)]
        write_jsonl(s1, records1)
        write_jsonl(s3, records3)
        result = subprocess.run(
            ["python3", str(REPO_ROOT / "scripts/hadf-phase2bis-anchor-drift-check.py"),
             "--sub-exp-1-raw", str(s1),
             "--sub-exp-3-raw", str(s3),
             "--anchor-provider", "openai",
             "--anchor-endpoint", "gpt-4o-mini"],
            capture_output=True, text=True
        )
        report = json.loads(result.stdout)
        assert report["drift_detected"] is True
        assert report["ks_p_value"] < 0.01
```

- [ ] **Step 2: Run test (should fail)**

Run: `.venv/bin/python3 -m pytest tests/framework/test_hadf_anchor_drift.py -v`
Expected: FAIL

- [ ] **Step 3: Implement anchor drift script**

```python
# scripts/hadf-phase2bis-anchor-drift-check.py
"""KS-test on anchor endpoint distributions between Sub-exp 1 and Sub-exp 3.
If p < 0.01, append methodology note to Sub-exp 3 case study (do NOT abort).
"""
import argparse
import json
import sys
from pathlib import Path

try:
    from scipy import stats
except ImportError:
    print("scipy required: pip install scipy", file=sys.stderr)
    sys.exit(2)

def load_anchor_records(path, provider, endpoint):
    records = []
    for line in Path(path).read_text().splitlines():
        if not line.strip():
            continue
        try:
            r = json.loads(line)
        except json.JSONDecodeError:
            continue
        if r.get("provider") == provider and r.get("endpoint") == endpoint and r.get("status") == "ok":
            records.append(r)
    return records

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--sub-exp-1-raw", required=True)
    p.add_argument("--sub-exp-3-raw", required=True)
    p.add_argument("--anchor-provider", required=True)
    p.add_argument("--anchor-endpoint", required=True)
    p.add_argument("--p-threshold", type=float, default=0.01)
    args = p.parse_args()

    s1 = load_anchor_records(args.sub_exp_1_raw, args.anchor_provider, args.anchor_endpoint)
    s3 = load_anchor_records(args.sub_exp_3_raw, args.anchor_provider, args.anchor_endpoint)

    if len(s1) < 30 or len(s3) < 30:
        print(json.dumps({
            "error": f"insufficient samples: s1={len(s1)}, s3={len(s3)}, need ≥30 each",
            "drift_detected": None,
        }))
        sys.exit(2)

    ttft_s1 = [r["ttft_s"] for r in s1]
    ttft_s3 = [r["ttft_s"] for r in s3]
    ttft_stat, ttft_p = stats.ks_2samp(ttft_s1, ttft_s3)

    tps_s1 = [r["tps"] for r in s1]
    tps_s3 = [r["tps"] for r in s3]
    tps_stat, tps_p = stats.ks_2samp(tps_s1, tps_s3)

    # Take the more sensitive (lower p) of the two
    p_value = min(ttft_p, tps_p)

    print(json.dumps({
        "anchor_provider": args.anchor_provider,
        "anchor_endpoint": args.anchor_endpoint,
        "n_subexp1": len(s1),
        "n_subexp3": len(s3),
        "ks_ttft_stat": ttft_stat,
        "ks_ttft_p": ttft_p,
        "ks_tps_stat": tps_stat,
        "ks_tps_p": tps_p,
        "ks_p_value": p_value,
        "p_threshold": args.p_threshold,
        "drift_detected": p_value < args.p_threshold,
    }))

if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Install scipy if not present**

```bash
.venv/bin/pip install scipy
```

- [ ] **Step 5: Run tests to verify pass**

Run: `.venv/bin/python3 -m pytest tests/framework/test_hadf_anchor_drift.py -v`
Expected: 2 PASSED

- [ ] **Step 6: Commit**

```bash
git add scripts/hadf-phase2bis-anchor-drift-check.py tests/framework/test_hadf_anchor_drift.py
git commit -m "feat(hadf-phase2bis): anchor-drift KS-test T2-E (Sub-exp 3 only, 2 tests pass)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task A9: Verdict computation script

**Files:**
- Create: `scripts/hadf-phase2bis-verdict.py`
- Create: `tests/framework/test_hadf_verdict.py`

- [ ] **Step 1: Write failing test using Phase 2 baseline data shape**

```python
# tests/framework/test_hadf_verdict.py
import json
import subprocess
import tempfile
from pathlib import Path
import random

REPO_ROOT = Path(__file__).resolve().parents[2]

def write_jsonl(path, records):
    with open(path, "w") as f:
        for r in records:
            f.write(json.dumps(r) + "\n")

def synthetic_phase2_like_data(n_per_endpoint=100, n_endpoints=9):
    """Generate data with separable cluster structure (silhouette ~0.5)"""
    random.seed(42)
    records = []
    for i in range(n_endpoints):
        provider = f"provider{i}"
        endpoint = f"endpoint{i}"
        # Each endpoint has its own (ttft, tps) cluster
        center_ttft = 0.3 + i * 0.2
        center_tps = 30.0 + i * 5.0
        for _ in range(n_per_endpoint):
            records.append({
                "provider": provider,
                "endpoint": endpoint,
                "ttft_s": center_ttft + random.gauss(0, 0.05),
                "tps": center_tps + random.gauss(0, 2.0),
                "status": "ok",
            })
    return records

def test_verdict_pass():
    """Synthetic separable data → silhouette > 0.5, clusters >= 3 → PASS"""
    with tempfile.TemporaryDirectory() as td:
        raw = Path(td) / "raw.jsonl"
        write_jsonl(raw, synthetic_phase2_like_data(n_per_endpoint=100, n_endpoints=9))
        result = subprocess.run(
            ["python3", str(REPO_ROOT / "scripts/hadf-phase2bis-verdict.py"),
             "--raw-dir", str(raw.parent),
             "--subexp", "test",
             "--silhouette-min", "0.4",
             "--yield-min", "600",
             "--clusters-min", "3",
             "--k", "5"],
            capture_output=True, text=True
        )
        assert result.returncode == 0, result.stderr
        report = json.loads(result.stdout)
        assert report["verdict"] == "PASS", f"got {report}"
        assert report["yield"] >= 600
        assert report["silhouette"] > 0.4
        assert report["clusters"] >= 3

def test_verdict_fail_low_yield():
    """Only 100 records → yield < 600 → FAIL"""
    with tempfile.TemporaryDirectory() as td:
        raw = Path(td) / "raw.jsonl"
        write_jsonl(raw, synthetic_phase2_like_data(n_per_endpoint=10, n_endpoints=10))
        result = subprocess.run(
            ["python3", str(REPO_ROOT / "scripts/hadf-phase2bis-verdict.py"),
             "--raw-dir", str(raw.parent),
             "--subexp", "test",
             "--silhouette-min", "0.4",
             "--yield-min", "600",
             "--clusters-min", "3",
             "--k", "5"],
            capture_output=True, text=True
        )
        report = json.loads(result.stdout)
        assert report["verdict"] == "FAIL"
        assert report["fail_reason"] == "low_yield"
```

- [ ] **Step 2: Run test (should fail)**

Run: `.venv/bin/python3 -m pytest tests/framework/test_hadf_verdict.py -v`
Expected: FAIL

- [ ] **Step 3: Implement verdict script**

```python
# scripts/hadf-phase2bis-verdict.py
"""Per-sub-exp verdict computation per spec §10.

Loads all phase2bis-raw-<subexp>-*.jsonl files in --raw-dir,
filters status=='ok', computes silhouette score at k=5 over (ttft_s, tps),
checks against pre-registered thresholds → emits PASS/FAIL/INCONCLUSIVE.
"""
import argparse
import json
import sys
from pathlib import Path

try:
    import numpy as np
    from sklearn.cluster import KMeans
    from sklearn.metrics import silhouette_score
except ImportError:
    print("scikit-learn + numpy required", file=sys.stderr)
    sys.exit(2)

def load_records(raw_dir):
    records = []
    for path in Path(raw_dir).glob("*.jsonl"):
        for line in path.read_text().splitlines():
            if not line.strip():
                continue
            try:
                r = json.loads(line)
            except json.JSONDecodeError:
                continue
            if r.get("status") == "ok" and "ttft_s" in r and "tps" in r:
                records.append(r)
    return records

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--raw-dir", required=True)
    p.add_argument("--subexp", required=True)
    p.add_argument("--silhouette-min", type=float, default=0.5)
    p.add_argument("--yield-min", type=int, default=600)
    p.add_argument("--clusters-min", type=int, default=3)
    p.add_argument("--k", type=int, default=5)
    args = p.parse_args()

    records = load_records(args.raw_dir)
    n_valid = len(records)

    if n_valid < args.yield_min:
        print(json.dumps({
            "subexp": args.subexp,
            "yield": n_valid,
            "verdict": "FAIL",
            "fail_reason": "low_yield",
            "yield_min_required": args.yield_min,
        }))
        return

    X = np.array([[r["ttft_s"], r["tps"]] for r in records])
    # Normalize features for fair clustering
    X_norm = (X - X.mean(axis=0)) / (X.std(axis=0) + 1e-9)

    km = KMeans(n_clusters=args.k, random_state=42, n_init=10)
    labels = km.fit_predict(X_norm)
    silhouette = silhouette_score(X_norm, labels)
    n_clusters = len(set(labels))

    verdict = "PASS"
    fail_reason = None
    if silhouette < args.silhouette_min:
        verdict = "FAIL"
        fail_reason = "low_silhouette"
    elif n_clusters < args.clusters_min:
        verdict = "FAIL"
        fail_reason = "too_few_clusters"

    report = {
        "subexp": args.subexp,
        "yield": n_valid,
        "silhouette": float(silhouette),
        "clusters": int(n_clusters),
        "k_attempted": args.k,
        "thresholds": {
            "silhouette_min": args.silhouette_min,
            "yield_min": args.yield_min,
            "clusters_min": args.clusters_min,
        },
        "verdict": verdict,
        "fail_reason": fail_reason,
    }
    print(json.dumps(report))

if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Install scikit-learn + numpy if not present**

```bash
.venv/bin/pip install scikit-learn numpy
```

- [ ] **Step 5: Run tests to verify pass**

Run: `.venv/bin/python3 -m pytest tests/framework/test_hadf_verdict.py -v`
Expected: 2 PASSED

- [ ] **Step 6: Commit**

```bash
git add scripts/hadf-phase2bis-verdict.py tests/framework/test_hadf_verdict.py
git commit -m "feat(hadf-phase2bis): verdict computation (silhouette + cluster count + thresholds)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task A10: launchd plist templates per sub-exp

**Files:**
- Create: `.claude/features/hadf-phase2bis-replication/launchd-templates/com.fitme.hadf-phase2bis-subexp{1,2,3}.plist.template`
- Create: `.claude/features/hadf-phase2bis-replication/launchd-bootstrap-runbook.md`

These are templates committed to the repo; the actual plists get installed to `~/Library/LaunchAgents/` at sub-exp launch time (NOT during soak window — they'd start firing immediately if installed).

- [ ] **Step 1: Create plist templates**

```bash
mkdir -p .claude/features/hadf-phase2bis-replication/launchd-templates

for n in 1 2 3; do
cat > ".claude/features/hadf-phase2bis-replication/launchd-templates/com.fitme.hadf-phase2bis-subexp${n}.plist.template" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.fitme.hadf-phase2bis-subexp${n}</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Volumes/DevSSD/FitTracker2-hadf-phase2bis-subexp${n}/scripts/hadf-phase2bis-collect.sh</string>
        <string>--subexp</string>
        <string>subexp${n}</string>
    </array>
    <key>WorkingDirectory</key>
    <string>/Volumes/DevSSD/FitTracker2-hadf-phase2bis-subexp${n}</string>
    <key>StartCalendarInterval</key>
    <array>
        <dict><key>Hour</key><integer>2</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Hour</key><integer>8</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Hour</key><integer>14</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Hour</key><integer>18</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Hour</key><integer>22</integer><key>Minute</key><integer>0</integer></dict>
    </array>
    <key>StandardOutPath</key>
    <string>/Volumes/DevSSD/FitTracker2-hadf-phase2bis-subexp${n}/.claude/shared/hadf/launchd-stdout-subexp${n}.log</string>
    <key>StandardErrorPath</key>
    <string>/Volumes/DevSSD/FitTracker2-hadf-phase2bis-subexp${n}/.claude/shared/hadf/launchd-stderr-subexp${n}.log</string>
    <key>RunAtLoad</key>
    <false/>
</dict>
</plist>
EOF
done
```

- [ ] **Step 2: Create bootstrap runbook**

```bash
cat > .claude/features/hadf-phase2bis-replication/launchd-bootstrap-runbook.md <<'EOF'
# HADF Phase 2-bis — launchd Bootstrap Runbook

Per spec §4: 5 fires/day at UTC 02:00/08:00/14:00/18:00/22:00. Run AT sub-exp launch time, NOT during soak window.

## Bootstrap Sub-exp 1 (on or after 2026-05-23)

```bash
# 1. Create worktree per worktrees-runbook.md if not already done
# 2. Verify go/no-go ceremony passed (see go-no-go-ceremony.md)
# 3. Lock the prereg
cd /Volumes/DevSSD/FitTracker2-hadf-phase2bis-subexp1
scripts/hadf-phase2bis-lock-prereg.sh subexp1
# 4. Copy plist into LaunchAgents
cp .claude/features/hadf-phase2bis-replication/launchd-templates/com.fitme.hadf-phase2bis-subexp1.plist.template ~/Library/LaunchAgents/com.fitme.hadf-phase2bis-subexp1.plist
# 5. Bootstrap with launchctl
launchctl bootstrap "gui/$(id -u)" ~/Library/LaunchAgents/com.fitme.hadf-phase2bis-subexp1.plist
# 6. Verify loaded
launchctl print "gui/$(id -u)/com.fitme.hadf-phase2bis-subexp1" | grep state
# 7. Wait for first fire at next UTC trigger time + 15 min, then check heartbeat
sleep 900
python3 scripts/hadf-phase2bis-heartbeat-audit.py \
  --ledger .claude/shared/hadf/phase2bis-fire-heartbeat.jsonl \
  --subexp subexp1 \
  --date $(date -u +%Y-%m-%d) \
  --expected-times 02:00,08:00,14:00,18:00,22:00
```

## Teardown Sub-exp N (after collection complete)

```bash
launchctl bootout "gui/$(id -u)/com.fitme.hadf-phase2bis-subexp${N}"
rm ~/Library/LaunchAgents/com.fitme.hadf-phase2bis-subexp${N}.plist
```
EOF
```

- [ ] **Step 3: Commit**

```bash
git add .claude/features/hadf-phase2bis-replication/launchd-templates/ .claude/features/hadf-phase2bis-replication/launchd-bootstrap-runbook.md
git commit -m "feat(hadf-phase2bis): launchd plist templates + bootstrap runbook (3 sub-exps)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task A11: 6-point go/no-go ceremony runbook

**Files:**
- Create: `.claude/features/hadf-phase2bis-replication/go-no-go-ceremony.md`

- [ ] **Step 1: Write the 6-point ceremony**

```bash
cat > .claude/features/hadf-phase2bis-replication/go-no-go-ceremony.md <<'EOF'
# HADF Phase 2-bis — Go/No-Go Ceremony

Per spec §9. Run **before** each sub-exp's launchctl plist is bootstrapped.

| # | Check | Action | Pass |
|---|-------|--------|------|
| 1 | Pre-flight smoke-fire | `bash scripts/hadf-phase2bis-smoke-fire.sh subexp${N}` | All endpoints respond within timeout |
| 2 | Cost ceiling enforcement | `python3 scripts/hadf-cost-cron.py --log .claude/shared/hadf/phase2bis-cost-log.jsonl --subexp subexp${N} --ceiling-usd 15 --check-only` | exit 0 |
| 3 | Heartbeat ledger initialized | `[ -f .claude/shared/hadf/phase2bis-fire-heartbeat.jsonl ] && [ -w .claude/shared/hadf/phase2bis-fire-heartbeat.jsonl ]` | exit 0 |
| 4 | Pre-registration hash-locked | `[ -f .claude/shared/hadf/preregistration-phase2bis-subexp${N}.json.lock ] && git tag --list "prereg-phase2bis-subexp${N}-locked-*" | grep -q .` | both true |
| 5 | Harness hardening proof populated | `python3 -c "import json; p = json.load(open('.claude/shared/hadf/preregistration-phase2bis-subexp${N}.json'))['harness_hardening_proof']; assert all(v != 'TBD' and not v.startswith('TBD') for v in p.values())"` | no AssertionError |
| 6 | Operator go/no-go recorded | `python3 -c "import json; s = json.load(open('.claude/features/hadf-phase2bis-replication/state.json')); assert s.get('phases', {}).get('research', {}).get('gnogo_recorded_at_subexp${N}')"` | no AssertionError |

## Recording the operator sign-off

Before launching Sub-exp N, the operator must:

```bash
python3 - <<PYEOF
import json
from datetime import datetime, timezone
p = '.claude/features/hadf-phase2bis-replication/state.json'
s = json.load(open(p))
s.setdefault('phases', {}).setdefault('research', {})['gnogo_recorded_at_subexp${N}'] = datetime.now(timezone.utc).isoformat()
s['phases']['research']['gnogo_operator_subexp${N}'] = '<operator-email-or-id>'
json.dump(s, open(p, 'w'), indent=2)
PYEOF

git add .claude/features/hadf-phase2bis-replication/state.json
git commit -m "chore(hadf-phase2bis-subexp${N}): operator go/no-go recorded for ceremony §9 check 6"
```

## Failure handling

If any check fails:
1. Do NOT proceed with launchctl bootstrap
2. Open issue against Linear FIT-71 with the failed check + remediation plan
3. Re-run ceremony after fix
4. Operator records the second-attempt timestamp + reason in state.json
EOF
```

- [ ] **Step 2: Commit**

```bash
git add .claude/features/hadf-phase2bis-replication/go-no-go-ceremony.md
git commit -m "feat(hadf-phase2bis): 6-point go/no-go ceremony runbook (spec §9)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task A12: Phase transition + Block A closure PR

- [ ] **Step 1: Transition state.json from research → tasks_phase**

```bash
python3 - <<'PYEOF'
import json
from datetime import datetime, timezone
p = '.claude/features/hadf-phase2bis-replication/state.json'
s = json.load(open(p))
now = datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z')
s['current_phase'] = 'tasks_phase'
s['timing']['phases']['research']['ended_at'] = now
s['timing']['phases']['tasks_phase'] = {'started_at': now}
s['phases']['research']['status'] = 'complete'
s['phases']['tasks_phase']['status'] = 'in_progress'
json.dump(s, open(p, 'w'), indent=2)
print('Transitioned to tasks_phase')
PYEOF

python3 scripts/append-feature-log.py \
  --feature hadf-phase2bis-replication \
  --event phase_transition \
  --phase tasks_phase \
  --message "Block A scaffolding complete; entering tasks phase"
```

- [ ] **Step 2: Run schema-check**

```bash
python3 scripts/check-state-schema.py --staged
```

Expected: 0 findings (all v7.8.3 gates pass: STATE_OWNER_*, PHASE_TRANSITION_NO_LOG, PHASE_TRANSITION_NO_TIMING)

- [ ] **Step 3: Run integrity-check (no NEW findings)**

```bash
python3 scripts/integrity-check.py --findings-only 2>&1 | grep -E "INCONSISTENT|FAIL" | head
```

Expected: 0 NEW findings beyond pre-existing

- [ ] **Step 4: Push + open PR**

```bash
git push -u origin feat/hadf-phase2bis-impl
gh pr create --base main --head feat/hadf-phase2bis-impl \
  --title "feat(hadf-phase2bis-replication): Block A — soak window scaffolding (12 tasks, all tests pass)" \
  --body "$(cat <<'PRBODY'
## Summary

Block A of the HADF Phase 2-bis implementation plan ([docs/superpowers/plans/2026-05-12-hadf-phase2bis-replication.md](docs/superpowers/plans/2026-05-12-hadf-phase2bis-replication.md)) — soak window scaffolding completed during 2026-05-13 → 22 ahead of the 2026-05-23 calendar gate for Sub-exp 1 collection.

## Scaffolding shipped

- **A0** Feature stub + research/prd/tasks placeholders
- **A1** Provider rate table + cost estimator (3 tests pass)
- **A2** Wrapper with 4 architectural fixes + preflight test (3 deliberate-break scenarios pass)
- **A3** Heartbeat ledger T2-A + audit script (2 tests pass)
- **A4** Cost ceiling cron T2-C ($15 daily ceiling, 2 tests pass)
- **A5** Smoke-fire T2-D + frozen 50-prompt set (5 categories × 10)
- **A6** 3 prereg skeletons + lock script + pre-commit lock check
- **A7** Per-sub-exp worktree creation runbook (deferred to launch time)
- **A8** Anchor-drift KS-test T2-E (Sub-exp 3 only, 2 tests pass)
- **A9** Verdict computation (silhouette + cluster count + thresholds, 2 tests pass)
- **A10** launchd plist templates + bootstrap runbook (3 sub-exps)
- **A11** 6-point go/no-go ceremony runbook
- **A12** Phase transition research → tasks_phase + this PR

## What's NOT in this PR

- Per-sub-exp worktrees (created at sub-exp launch, runbook in A7)
- launchd plist installation to ~/Library/LaunchAgents/ (deferred to operator runbook in A10)
- Provider call code in scripts/hadf-phase2bis-collect.py — currently NotImplementedError; filled iteratively after first smoke-fire passes

## v7.8.3 framework compliance

- [x] state_owner: "ft2" at stub creation (passes STATE_OWNER_*)
- [x] framework_version: "v7.8.3"
- [x] All Tier 2.2 phase transitions logged via append-feature-log.py
- [x] V9 driver covers .claude/logs/hadf-phase2bis-replication.log.json + raw .jsonl + heartbeat + cost log
- [x] kill_criteria_resolution null until first sub-exp closure
- [ ] Per-sub-exp worktree_path (set at launch time per worktrees-runbook.md)

## Test plan

- [x] All Block A unit tests pass (11 tests across 5 test files)
- [x] Wrapper preflight catches 3 deliberate-break scenarios (exit 78)
- [x] Pre-commit lock check blocks edits to a locked prereg
- [x] Verdict computation produces PASS on synthetic Phase 2-like data
- [x] integrity-check.py shows no NEW findings vs main

## Linear

[FIT-71](https://linear.app/fitme-project/issue/FIT-71)

🤖 Generated with [Claude Code](https://claude.com/claude-code)
PRBODY
)"
```

- [ ] **Step 5: Commit transition + push**

```bash
git add .claude/features/hadf-phase2bis-replication/state.json .claude/logs/hadf-phase2bis-replication.log.json
git commit -m "chore(hadf-phase2bis): Block A complete — phase transition research → tasks_phase

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
git push
```

---

# BLOCK B — Sub-Experiment Campaigns (2026-05-23 → ~2026-06-03)

Each sub-exp is operator-driven, not subagent-dispatchable (real-time launchd interactions + 3-day collection windows). The runbooks below are precise step-by-steps the operator follows.

> **Consolidation note 2026-05-12:** each Sub-exp closure (B13.13a/b, B14.9a/b, B15.22a/b) now produces a per-phase **ORCHID analysis report** per the template at [`docs/research/2026-05-12-hadf-phase2bis-orchid-integration.md`](../../research/2026-05-12-hadf-phase2bis-orchid-integration.md) §3.2. The synthesis case study (C16.6/7/8) produces an ORCHID v2 design spec stub + extends the framework-v7-mapping note. See the consolidation doc §6 for the exact additional sub-tasks per block. Hardware constraints (Chisel toolchain not installed → RTL blocked; everything upstream — behavioral models, DSE, framework mapping, ORCHID v2 spec writing — advances NOW) documented in §4 of that doc. State.json updated with `companion_research`, `calibration_protocol_phase`, and `external_audit_schedule` fields.

## Task B13: Sub-exp 1 launch + collection + verdict + closure

**Calendar:** 2026-05-23 → ~2026-05-26 (3 days collection + 1 day verdict + closure)

**Pre-launch (2026-05-22 evening):**
- [ ] B13.1 Operator fills in `endpoints` array of `.claude/shared/hadf/preregistration-phase2bis-subexp1.json` per spec §2 Sub-exp 1 matrix (9 endpoints)
- [ ] B13.2 Operator fills in `harness_hardening_proof` block: env_local_sha256_at_deploy, fix1_commit_hash, preflight_test_log_path, state_owner_at_creation
- [ ] B13.3 Implement provider call code in `scripts/hadf-phase2bis-collect.py` for the 6 Sub-exp 1 providers (openai, anthropic, google, vercel-ai-gateway, mistral, xai). Use streaming APIs per spec §4.
- [ ] B13.4 Run go/no-go ceremony per `.claude/features/hadf-phase2bis-replication/go-no-go-ceremony.md`
- [ ] B13.5 Lock prereg-subexp1.json: `bash scripts/hadf-phase2bis-lock-prereg.sh subexp1`
- [ ] B13.6 Operator records gnogo_recorded_at_subexp1 in state.json

**Launch (2026-05-23 ~01:55 UTC, 5 min before first 02:00 fire):**
- [ ] B13.7 Create per-sub-exp worktree per `worktrees-runbook.md`
- [ ] B13.8 Install plist: `cp .claude/features/hadf-phase2bis-replication/launchd-templates/com.fitme.hadf-phase2bis-subexp1.plist.template ~/Library/LaunchAgents/com.fitme.hadf-phase2bis-subexp1.plist`
- [ ] B13.9 Bootstrap: `launchctl bootstrap "gui/$(id -u)" ~/Library/LaunchAgents/com.fitme.hadf-phase2bis-subexp1.plist`
- [ ] B13.10 Verify loaded: `launchctl print "gui/$(id -u)/com.fitme.hadf-phase2bis-subexp1"`

**Daily monitoring (2026-05-23, 24, 25):**
- [ ] B13.11 After 22:15 UTC each day: run heartbeat audit + cost cron
  ```bash
  python3 scripts/hadf-phase2bis-heartbeat-audit.py --ledger .claude/shared/hadf/phase2bis-fire-heartbeat.jsonl --subexp subexp1 --date $(date -u +%Y-%m-%d) --expected-times 02:00,08:00,14:00,18:00,22:00
  python3 scripts/hadf-cost-cron.py --log .claude/shared/hadf/phase2bis-cost-log.jsonl --subexp subexp1 --ceiling-usd 15 --check-only
  ```
- [ ] B13.12 Operator reviews missed_fires; if any, investigate per spec §10 trip-wires

**Closure (2026-05-26 morning):**
- [ ] B13.13 Teardown launchd: `launchctl bootout "gui/$(id -u)/com.fitme.hadf-phase2bis-subexp1"; rm ~/Library/LaunchAgents/com.fitme.hadf-phase2bis-subexp1.plist`
- [ ] B13.14 Run verdict: `python3 scripts/hadf-phase2bis-verdict.py --raw-dir .claude/shared/hadf/ --subexp subexp1 --silhouette-min 0.5 --yield-min 600 --clusters-min 3 --k 5 > /tmp/subexp1-verdict.json`
- [ ] B13.15 Write Sub-exp 1 case study at `docs/case-studies/hadf-phase2bis-subexp1-case-study.md` per spec §6 (7 required sections)
- [ ] B13.16 Update state.json `tasks` block + `kill_criteria_resolution` field for Sub-exp 1
- [ ] B13.17 Snapshot: `make snapshot-phase PHASE=hadf-phase2bis-subexp1-complete`
- [ ] B13.18 Commit + PR + merge (case study + state.json update)
- [ ] B13.19 Decision gate: if verdict=PASS, proceed to B14. If FAIL or INCONCLUSIVE, halt + cross-sub-exp synthesis as a partial result

## Task B14: Sub-exp 2 launch + collection + verdict + closure

**Calendar:** ~2026-05-27 → ~2026-05-30 (gated on Sub-exp 1 PASS)

Same 19 sub-tasks as B13 with `subexp2` substitutions. Notable differences:
- Single endpoint (Ollama llama3.2:3b on M2)
- 600s timeout override per spec §4
- Cost: $0
- Provider call code: `ollama-python` library (`.venv/bin/pip install ollama`)
- Skip cost cron daily check (cost is $0)
- Verdict thresholds may need adjustment for n=750 records (vs Sub-exp 1's ~3,375) — re-validate yield_min in prereg before lock

## Task B15: Sub-exp 3 launch + collection + verdict + closure (decisive routing test)

**Calendar:** ~2026-05-31 → ~2026-06-03 (gated on Sub-exp 2 PASS)

Same 19 sub-tasks as B13 with `subexp3` substitutions PLUS:
- [ ] B15.20 After verdict computation, run anchor-drift check:
  ```bash
  python3 scripts/hadf-phase2bis-anchor-drift-check.py \
    --sub-exp-1-raw .claude/shared/hadf/phase2bis-raw-subexp1-*.jsonl \
    --sub-exp-3-raw .claude/shared/hadf/phase2bis-raw-subexp3-*.jsonl \
    --anchor-provider openai --anchor-endpoint gpt-4o-mini > /tmp/subexp3-anchor-drift-openai.json
  python3 scripts/hadf-phase2bis-anchor-drift-check.py \
    --sub-exp-1-raw .claude/shared/hadf/phase2bis-raw-subexp1-*.jsonl \
    --sub-exp-3-raw .claude/shared/hadf/phase2bis-raw-subexp3-*.jsonl \
    --anchor-provider anthropic --anchor-endpoint claude-haiku-4-5 > /tmp/subexp3-anchor-drift-anthropic.json
  ```
- [ ] B15.21 If `drift_detected: true` for either anchor, append methodology note to Sub-exp 3 case study (do NOT abort verdict per spec §7 trip-wire policy)

---

# BLOCK C — Cross-Sub-Exp Synthesis + Closure (~2026-06-04 → 07)

## Task C16: Cross-sub-exp synthesis case study

**Files:**
- Create: `docs/case-studies/hadf-phase2bis-cross-sub-exp-synthesis-case-study.md`

- [ ] **Step 1: Create synthesis case study with 5 required questions**

The synthesis case study must cover (per spec §6):
1. Anchor consistency between Sub-exp 1 and Sub-exp 3 (drift status)
2. Sub-exp 1 cloud generalization verdict
3. Sub-exp 2 cloud-vs-local separability verdict
4. Sub-exp 3 routing test verdict — does same model behind different providers fingerprint differently?
5. Overall HADF dispatch claim status: confirmed / refuted / inconclusive

Use the per-sub-exp case studies (B13.15, B14.15, B15.15) + verdict JSONs (`/tmp/subexp{1,2,3}-verdict.json`) + anchor-drift JSONs as inputs.

Frontmatter must satisfy v7.8.1 FEATURE_CLOSURE_COMPLETENESS gate (7 required fields per dev-guide §11):
- `date_written`, `dispatch_pattern`, `success_metrics`, `kill_criteria`, `framework_version`, `work_type`, `tier_tags_present`

- [ ] **Step 2: Run case-study preflight check**

```bash
python3 scripts/check-case-study-preflight.py docs/case-studies/hadf-phase2bis-cross-sub-exp-synthesis-case-study.md
```

Expected: 0 findings (no BROKEN_PR_CITATION, no CASE_STUDY_MISSING_TIER_TAGS)

- [ ] **Step 3: Commit on synthesis worktree**

```bash
cd /Volumes/DevSSD/FitTracker2-hadf-phase2bis-synthesis
git add docs/case-studies/hadf-phase2bis-cross-sub-exp-synthesis-case-study.md
git commit -m "docs(hadf-phase2bis): cross-sub-exp synthesis case study (3 verdicts + HADF claim status)"
```

## Task C17: Public showcase MDX in fitme-story (slot 30)

**Files:**
- Create: `fitme-story/content/04-case-studies/30-hadf-phase2bis-cross-sub-exp-synthesis.mdx`

- [ ] **Step 1: Create showcase MDX with timeline_position.order matching framework version**

```bash
cd /Volumes/DevSSD/fitme-story
git checkout main && git pull --ff-only
git checkout -b chore/showcase-hadf-phase2bis-synthesis
```

The showcase MDX condenses the source case study into ~1000 words for the public site. Use slot 30 (next available; 29 is cross-repo-state-sync-impl).

Frontmatter: `version: 'v7.8.3'` (HADF Phase 2-bis ran under v7.8.3); `timeline_position.order: 30` (chronological).

## Task C18: Final state.json closure (current_phase=complete)

- [ ] **Step 1: Update state.json fields**

```bash
cd /Volumes/DevSSD/FitTracker2-hadf-phase2bis-synthesis
python3 - <<'PYEOF'
import json
from datetime import datetime, timezone
p = '.claude/features/hadf-phase2bis-replication/state.json'
s = json.load(open(p))
now = datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z')

# Phase progression
s['current_phase'] = 'complete'
s['timing']['phases'].setdefault('docs', {})['ended_at'] = now
s['timing']['phases'].setdefault('learn', {'started_at': now, 'ended_at': now})
for phase in ['prd','tasks_phase','implement','test','review','merge','docs','learn']:
    s.setdefault('phases', {}).setdefault(phase, {})['status'] = 'complete'

# Required v7.8.1 closure fields
s['kill_criteria_resolution'] = "TBD — fill before commit per actual sub-exp outcomes"  # operator must replace this
s['related_prs'] = []  # populated by operator from B13/B14/B15 PRs
s['case_study'] = 'docs/case-studies/hadf-phase2bis-cross-sub-exp-synthesis-case-study.md'
s['case_study_showcase'] = 'fitme-story/content/04-case-studies/30-hadf-phase2bis-cross-sub-exp-synthesis.mdx'

json.dump(s, open(p, 'w'), indent=2)
print('Closure state.json drafted; operator must fill kill_criteria_resolution + related_prs before commit')
PYEOF
```

- [ ] **Step 2: Operator fills `kill_criteria_resolution` (FEATURE_CLOSURE_COMPLETENESS Q7) + `related_prs` array (Q6 PR-list parity)**

The value of `kill_criteria_resolution` reflects what actually happened: e.g., `"none_tripped"`, `"criterion_1_tripped_subexp2_run_extended_to_4_days_yield_recovered"`. The `related_prs` array enumerates the per-sub-exp closure PRs (B13.18, B14.18, B15.18) plus this synthesis PR.

- [ ] **Step 3: Pre-commit hook validates FEATURE_CLOSURE_COMPLETENESS**

```bash
git add .claude/features/hadf-phase2bis-replication/state.json
git commit -m "chore(hadf-phase2bis): closure — current_phase=complete + 3-sub-exp synthesis"
```

The pre-commit hook will fail if any FEATURE_CLOSURE_COMPLETENESS field is missing. Fix any reported field and re-commit.

## Task C19: Final off-SSD snapshot

```bash
make snapshot-phase PHASE=hadf-phase2bis-replication-complete
```

Expected: writes `~/Documents/FitTracker2-backups/2026-06-XX-hadf-phase2bis-replication-complete/` with state.json + log.json + MANIFEST.md + CHECKSUMS.sha256

## Task C20: Linear FIT-71 → Done

```bash
gh pr create --base main --head feat/hadf-phase2bis-synthesis \
  --title "chore(hadf-phase2bis-replication): closure — current_phase=complete + cross-sub-exp synthesis case study" \
  --body "Closes Linear FIT-71. Synthesis case study covers 3 sub-exp verdicts + anchor drift status + overall HADF dispatch claim status."
```

After merge, mark Linear FIT-71 as Done via MCP.

---

# Self-Review Checklist

This was run after writing the plan above. Issues found and fixed inline:

1. **Spec coverage:**
   - §1 RQs → covered in research.md (A0) + state.json `success_metrics`
   - §2 endpoint matrix → covered in `scripts/hadf-phase2bis-collect.py::ENDPOINTS` (A2)
   - §3 4 architectural fixes → wrapper (A2) + worktree runbook (A7)
   - §4 per-call controls + schedule → wrapper (A2) + plist templates (A10)
   - §5 pre-registration → skeletons (A6) + lock script (A6)
   - §6 verdict + case study structure → verdict script (A9) + case study task (B13.15, C16)
   - §7 kill criteria + trip-wires + non-scope → state.json kill_criteria (A0) + cost cron (A4) + anchor drift (A8)
   - §8 dedicated worktrees → runbook (A7) + plist WorkingDirectory (A10)
   - §9 go/no-go ceremony → runbook (A11)
   - §10 sub-exp orchestration → heartbeat (A3) + cost cron (A4) + smoke-fire (A5) + anchor drift (A8) + closure ceremony (B13.13–18)
   - §11 v7.8.3 compliance checklist → state.json fields (A0) + closure (C18)

2. **Placeholder scan:**
   - All `TBD` markers in pre-registration skeletons (A6) are intentional — operator fills at lock time
   - All `kill_criteria_resolution: null` in stub state.json (A0) are intentional — populated at sub-exp closures
   - `successor: TBD` in spec frontmatter (pre-existing, not in this plan)
   - **NotImplementedError in scripts/hadf-phase2bis-collect.py** — explicit placeholder for provider call code, fills iteratively post-A5 smoke-fire (B13.3)
   - No other TODO/FIXME/XXX/??? markers

3. **Type consistency:**
   - `--subexp` arg name consistent across hadf-phase2bis-collect.sh, smoke-fire.sh, lock-prereg.sh, verdict.py, anchor-drift.py
   - Pre-registration field names consistent: `harness_hardening_proof`, `verdict_thresholds`, `kill_criteria` match spec §5
   - State.json field names match v7.8.3 schema: `state_owner`, `framework_version`, `current_phase`, `kill_criteria_resolution`, `case_study`, `worktree_path`, `related_prs`
   - Heartbeat events: `fire_started`, `fire_ended`, `preflight_failed`, `dry_run_complete` — used consistently

---

**Plan complete and saved to `docs/superpowers/plans/2026-05-12-hadf-phase2bis-replication.md`. Two execution options:**

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per Task A0–A12, review between tasks, fast iteration. Block B/C remain operator-driven (real-time launchd interactions can't be subagent-dispatched).

**2. Inline Execution** — Execute Task A0–A12 in this session using executing-plans, batch execution with checkpoints for review.

**Which approach?**
