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
