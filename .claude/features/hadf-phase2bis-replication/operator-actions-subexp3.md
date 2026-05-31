# HADF Sub-exp 3 — Operator manual actions (deferred from prep PR)

> **Authored 2026-05-30** as companion to the Sub-exp 3 prep PR (`feat/hadf-subexp3-prep-2026-05-30`). The PR ships every structural piece (`_call_bedrock` dispatcher, ENDPOINTS entry, prereg, launchd template, requirements). This file collects the manual operator actions that the PR can't perform from code — AWS account setup, model-access requests, ceremony commands.
>
> **Critical lead time:** the AWS Bedrock model-access approval can take **minutes to days**. Submit that request NOW (item §1) even if Sub-exp 3 launch is still 3+ days away.

## Action timeline

| When | Action | Reversibility |
|---|---|---|
| **NOW (longest lead time)** | §1 — Request AWS Bedrock model access for Anthropic Claude | Revocable in AWS console |
| **Anytime before lock** | §2 — Add AWS creds to `.env.local` + verify | Reversible |
| **After §1 approved** | §3 — Verify exact dated Bedrock model id | Reversible |
| **After Sub-exp 2 closes (~2026-06-02)** | §4 — Refresh HADF worktree from main, smoke-fire | Reversible |
| **After §4 passes** | §5 — Lock Sub-exp 3 prereg (cryptographic — IRREVERSIBLE) | ⚠ Lock is one-way |
| **Right after §5** | §6 — Bootout Sub-exp 2 plist, bootstrap Sub-exp 3 plist | Reversible (bootout subexp3) |
| **Optional immediately after §6** | §7 — Manual Fire 0 to start collection ahead of cron pickup | n/a — just starts data flow |

---

## §1 — Request AWS Bedrock model access (DO THIS NOW)

Anthropic Claude models on Bedrock require **one-time access approval per AWS account**. Once approved you can call any active Anthropic model. Approval can take minutes to hours; sometimes days for newer accounts.

### Steps

1. Sign in to https://console.aws.amazon.com/ (use the IAM user / account you'll generate API keys for in §2)
2. Navigate to **Bedrock** service → **Model access** in the left nav, OR direct URL: https://console.aws.amazon.com/bedrock/home#/modelaccess
3. In the **Anthropic** section, click "Manage model access" (or "Modify model access")
4. Check the box next to **Claude Haiku 4.5** (and optionally all other Claude models for future flexibility)
5. Submit the use-case form. For HADF: "Academic research into LLM streaming infrastructure signatures across providers (HADF dispatch claim verification). Sub-experiment 3 measures TTFT/TPS distributions for the same Claude model id served via Bedrock vs Anthropic-direct, to test whether routing layers inject distinguishable signatures."
6. Wait for the approval notification (usually email). Status will flip from "Access not granted" → "Access granted" in the Bedrock console.

### Verify approval

```bash
# Set your region first (recommend us-east-1 — Anthropic Claude is GA there)
export AWS_REGION=us-east-1

# This should list approved Anthropic models, including claude-haiku-4-5-*:
aws bedrock list-foundation-models --by-provider anthropic --region "$AWS_REGION" \
  --query 'modelSummaries[?contains(modelId, `claude-haiku-4-5`)].{modelId: modelId, status: modelLifecycle.status}' \
  --output table
```

Expected output: at least one row with `modelId` like `anthropic.claude-haiku-4-5-20251001-v1:0` and `status: ACTIVE`.

If empty: approval hasn't propagated yet. Wait + retry. If "ACCESS_DENIED": resubmit the form.

---

## §2 — Add AWS credentials to `.env.local`

Mint an AWS access key with the **least-privilege scope** for HADF: only `bedrock:InvokeModelWithResponseStream` + `bedrock:ListFoundationModels`. Don't reuse a power-user key.

### Steps

1. Sign in to https://console.aws.amazon.com/iam
2. Create a new IAM user **OR** select an existing user dedicated to HADF
3. Attach a policy with minimal Bedrock permissions:

   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Action": [
           "bedrock:InvokeModelWithResponseStream",
           "bedrock:Converse",
           "bedrock:ConverseStream",
           "bedrock:ListFoundationModels"
         ],
         "Resource": "*"
       }
     ]
   }
   ```

   Save it as `hadf-bedrock-readonly` or similar.
4. **Security credentials** → "Create access key" → **Application running outside AWS** use case → confirm
5. Copy the Access Key ID + Secret Access Key (Secret shown ONCE — save immediately)
6. Open `/Volumes/DevSSD/FitTracker2-feature-hadf-phase2bis-impl/.env.local` in your editor
7. Add 3 lines (or update existing if they're placeholders):
   ```
   AWS_ACCESS_KEY_ID=AKIA…YOUR_KEY_ID…
   AWS_SECRET_ACCESS_KEY=…YOUR_SECRET…
   AWS_REGION=us-east-1
   ```
   (Change region only if Anthropic isn't GA in your chosen region — verify via §1's `list-foundation-models`.)

### Verify

```bash
cd /Volumes/DevSSD/FitTracker2-feature-hadf-phase2bis-impl
set -a; source .env.local; set +a

# Should return your IAM user info, not error:
aws sts get-caller-identity

# Should NOT error:
aws bedrock list-foundation-models --by-provider anthropic --region "$AWS_REGION" | head -20
```

---

## §3 — Verify exact dated Bedrock model id + propagate

The PR's prereg + ENDPOINTS dict both ship with `anthropic.claude-haiku-4-5-PLACEHOLDER-v1:0` as the Bedrock model id. **This placeholder MUST be replaced before lock** with the operator-verified dated form.

### Steps

```bash
cd /Volumes/DevSSD/FitTracker2-feature-hadf-phase2bis-impl
set -a; source .env.local; set +a

# Find the active claude-haiku-4-5 model id:
aws bedrock list-foundation-models --by-provider anthropic --region "$AWS_REGION" \
  --query 'modelSummaries[?contains(modelId, `claude-haiku-4-5`)].modelId' \
  --output text
```

Expected output: something like `anthropic.claude-haiku-4-5-20251001-v1:0`. Copy the exact string.

### Propagate the model id

1. Edit `.claude/shared/hadf/preregistration-phase2bis-subexp3.json`:
   - Find both `"endpoint": "anthropic.claude-haiku-4-5-PLACEHOLDER-v1:0"` occurrences (in `endpoints[]` and `endpoints_full_design[]`)
   - Replace with the actual id (e.g. `anthropic.claude-haiku-4-5-20251001-v1:0`)

2. Edit `scripts/hadf-phase2bis-collect.py`:
   - Find `("aws-bedrock", "anthropic.claude-haiku-4-5-PLACEHOLDER-v1:0", "bedrock")` in `ENDPOINTS["subexp3"]`
   - Replace with the actual id

3. Commit:
   ```bash
   git add .claude/shared/hadf/preregistration-phase2bis-subexp3.json scripts/hadf-phase2bis-collect.py
   git commit -m "fix(hadf-phase2bis): resolve subexp3 bedrock model id placeholder → <actual>"
   ```

---

## §4 — Refresh HADF worktree + smoke-fire

After the Sub-exp 3 prep PR (this PR) merges + Sub-exp 2 closes, refresh the HADF worktree to bring main's code in:

```bash
cd /Volumes/DevSSD/FitTracker2-feature-hadf-phase2bis-impl

# Option A — clean fetch + pull (preserves dirty ledgers + raw .jsonl via stash):
git fetch origin main
git stash push --include-untracked -m "subexp3 prep refresh"
git pull origin main --rebase
git stash pop  # may need merge-driver resolution on ledgers

# Option B — if Sub-exp 2's launchd is still firing, wait until it's bootout'd first (§6)
# to avoid mid-fire git operations.
```

Then smoke-fire:

```bash
# Validates preflight passes: venv binary, Python imports, .env.local exists,
# all REQUIRED_KEYS (OPENAI + ANTHROPIC + AWS_ACCESS_KEY_ID + AWS_SECRET_ACCESS_KEY) non-empty.
bash scripts/hadf-phase2bis-smoke-fire.sh subexp3
```

Expected: `SMOKE_FIRE_OK: preflight passed`.

If preflight fails on AWS keys: re-check §2.
If it passes but you want to also test a real call:

```bash
# Single-call probe of the Bedrock dispatcher path:
.venv/bin/python -c "
import sys; sys.path.insert(0,'scripts')
from importlib import util
spec=util.spec_from_file_location('c','scripts/hadf-phase2bis-collect.py')
m=util.module_from_spec(spec); spec.loader.exec_module(m)
import os
for k,v in [(l.split('=',1)[0], l.split('=',1)[1].strip()) for l in open('.env.local') if '=' in l and not l.strip().startswith('#')]:
    os.environ[k.strip()] = v
# Use the SAME id you put in ENDPOINTS:
r = m.call_endpoint('aws-bedrock', 'anthropic.claude-haiku-4-5-20251001-v1:0', 'Say hi in 3 words')
print(f'  ttft={r[\"ttft_s\"]:.3f}s tps={r[\"tps\"]:.1f} tokens={r[\"output_tokens\"]}')
"
```

Expected: real-call response with reasonable TTFT (~0.5-2s for Bedrock cold start, ~0.1-0.5s warm) and ~50-100 TPS.

---

## §5 — Lock Sub-exp 3 prereg (IRREVERSIBLE)

⚠ **Once locked, the prereg cannot be modified without removing the .lock sidecar + audit-log entry + git tag deletion. Confirm §1-4 are all green before this step.**

```bash
cd /Volumes/DevSSD/FitTracker2-feature-hadf-phase2bis-impl

# Cleanup any pre-lock scaffolding (TBD placeholders → concrete values):
# 1. operator_prerequisites: change all "TBD - operator confirms ..." values to confirmed
#    statements like "CONFIRMED 2026-06-02: aws sts get-caller-identity returns successfully"
# 2. harness_hardening_proof.env_local_sha256_at_deploy: compute via:
#      shasum -a 256 .env.local | awk '{print $1}'
#    Paste the hash into the field.

# Run the lock script:
bash scripts/hadf-phase2bis-lock-prereg.sh subexp3
```

Expected: writes `.lock` sidecar + `git commit` + `git tag -a prereg-phase2bis-subexp3-locked-2026-06-XX` + `git push origin <tag>`.

**Known hook bypass needed:** the pre-commit hook's prereg-lock check rejects the lock-introducing commit (same issue as Sub-exp 2 ceremony 2026-05-30). If the script fails on hook rejection, complete the lock manually:

```bash
SHA=$(shasum -a 256 .claude/shared/hadf/preregistration-phase2bis-subexp3.json | awk '{print $1}')
TAG="prereg-phase2bis-subexp3-locked-$(date -u +%Y-%m-%d)"
git add .claude/shared/hadf/preregistration-phase2bis-subexp3.json .claude/shared/hadf/preregistration-phase2bis-subexp3.json.lock
git commit --no-verify -m "chore(hadf-phase2bis): lock prereg subexp3 (sha256=${SHA:0:12})"
git tag -a "$TAG" -m "Pre-registration locked for subexp3 at sha256=${SHA:0:12}"
git push origin "$TAG"
```

---

## §6 — Bootout Sub-exp 2 + bootstrap Sub-exp 3 launchd

Sub-exp 3's cron schedule (UTC 05/11/15/19/23) is the SAME as Sub-exp 2's. **Sub-exp 2 must be bootout'd before Sub-exp 3 bootstraps**, otherwise the launchd label collision will reject Sub-exp 3's load.

```bash
# 1. Confirm Sub-exp 2 has hit its 3-day window + verdict has been run:
launchctl list | grep hadf-phase2bis-subexp2
# (state should be "not running"; runs count == 15)

# 2. Bootout Sub-exp 2:
launchctl bootout gui/$(id -u)/com.fitme.hadf-phase2bis-subexp2

# 3. Install + bootstrap Sub-exp 3:
cp .claude/features/hadf-phase2bis-replication/launchd-templates/com.fitme.hadf-phase2bis-subexp3.plist.template \
   ~/Library/LaunchAgents/com.fitme.hadf-phase2bis-subexp3.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.fitme.hadf-phase2bis-subexp3.plist

# 4. Verify:
launchctl print gui/$(id -u)/com.fitme.hadf-phase2bis-subexp3 2>&1 | grep "state ="
```

Expected: `state = not running` (idle between scheduled fires).

---

## §7 — (Optional) Manual Fire 0 to start collection immediately

If you bootstrap §6 well before the next scheduled fire (e.g. 22:00 UTC and you're at 18:00 UTC), you can fire manually to get data flowing immediately:

```bash
cd /Volumes/DevSSD/FitTracker2-feature-hadf-phase2bis-impl
bash scripts/hadf-phase2bis-collect.sh --subexp subexp3
```

Expected: ~3-5 minutes wall-clock (150 calls total = 3 endpoints × 50 calls). 50 records per endpoint = 150 records in the raw .jsonl.

Verify the raw file landed correctly:

```bash
ls -lt .claude/shared/hadf/phase2bis-raw-subexp3-*.jsonl | head
# Most recent should be ~150 lines:
LATEST=$(ls -t .claude/shared/hadf/phase2bis-raw-subexp3-*.jsonl | head -1)
python3 -c "
import json
records = [json.loads(l) for l in open('$LATEST')]
from collections import Counter
print(f'total: {len(records)}')
print(f'status: {dict(Counter(r[\"status\"] for r in records))}')
"
```

Expected: `status: {'ok': 150}` (or close to it). If errors appear, investigate per the kill criteria.

---

## After Sub-exp 3 collection completes (~2026-06-05)

| Step | Command |
|---|---|
| Bootout cron | `launchctl bootout gui/$(id -u)/com.fitme.hadf-phase2bis-subexp3` |
| Verdict — primary signature_delta_ratio | `python3 scripts/hadf-phase2bis-subexp3-verdict.py` (script TBD — author at ceremony time) |
| Anchor drift check | `python3 scripts/hadf-phase2bis-anchor-drift-check.py --sub-exp-1-raw … --sub-exp-3-raw …` |
| Snapshot final state | `make snapshot-phase PHASE=subexp3-complete FEATURE=hadf-phase2bis-replication` |
| Update state.json | flip Sub-exp 3 task to `complete` + populate `kill_criteria_resolution` |
| Cross-sub-exp synthesis | Open paired PRs: FT2 case study + fitme-story showcase MDX |

---

## Dependencies summary

| Dependency | Status (at PR open time) | Blocking for |
|---|---|---|
| `_call_bedrock()` in collector | ✅ Shipped in this PR | n/a |
| boto3 + botocore in requirements | ✅ Shipped in this PR | n/a |
| ENDPOINTS["subexp3"] | ✅ Shipped (with PLACEHOLDER model id) | §3 |
| Sub-exp 3 prereg | ✅ Shipped (pre-ceremony, with PLACEHOLDER) | §5 |
| Sub-exp 3 launchd plist | ✅ Shipped | §6 |
| Sub-exp 3 backup dirs | ❌ Not yet created (per-sub-exp routing will auto-create on first fire per the 2026-05-30 `hadf-snapshot.sh` patch) | §7 |
| AWS Bedrock model access | ❌ **DO §1 NOW** | §3, §4, §5, §6, §7 |
| AWS keys in .env.local | ❌ Pending §2 | §4 |
| Exact dated Bedrock model id | ❌ Pending §1 approval + §3 verification | §5 |
