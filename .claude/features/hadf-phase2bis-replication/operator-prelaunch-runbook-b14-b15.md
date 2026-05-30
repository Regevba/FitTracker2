# HADF Phase 2-bis — Operator pre-launch runbook for B14 + B15

> **Authored:** 2026-05-28 (Phase E Day 7) as B14/B15 pre-work.
> **Status:** awaits operator approval at each ▶ checkpoint. No automated
> step in this file fires until the operator explicitly runs the marked
> command. Every step that hits a real API, costs money, or installs a
> launchd job is gated.

## Pre-prepared by Claude (no operator action required)

The following are already in place on the `feat/hadf-phase2bis-impl` worktree:

| Artifact | Path | What changed |
|---|---|---|
| Collector provider gates | `scripts/hadf-phase2bis-collect.py` | Added `_call_bedrock()` + ollama branch via OpenAI-compat. `NotImplementedError` no longer raised for `ollama` or `aws-bedrock`. |
| Dependency manifest | `scripts/requirements-hadf-phase2.txt` | Added `boto3`, `botocore`, `google-genai`, `scipy`. Ollama uses existing `openai` SDK via compat layer. |
| Sub-exp 2 prereg | `.claude/shared/hadf/preregistration-phase2bis-subexp2.json` | Filled with RQ2 verbatim from spec §1, Ollama endpoint per §2, 600s per-call timeout per §4, KS p < 0.01 primary metric per spec, anchor-free per H1. |
| Sub-exp 3 prereg | `.claude/shared/hadf/preregistration-phase2bis-subexp3.json` | Filled with RQ3 verbatim from spec §1, 3-endpoint matrix per §2 (openai+anthropic anchors + aws-bedrock routing target), signature_delta_ratio primary metric per spec, anchor-drift trip-wire active. |
| Showcase MDX | fitme-story `chore/hadf-block-c-showcase-placeholder-2026-05-27` worktree | Renamed `22c-…` → `22e-…` to avoid collision with existing `22c-stats-v2.mdx`. Frontmatter `order: 22.7` unchanged. |

The preregs still have **`TBD` values** that the lock script (`scripts/hadf-phase2bis-lock-prereg.sh`) will fill in at lock time:
- `harness_hardening_proof.env_local_sha256_at_deploy` — computed live
- `operator_prerequisites.*` — operator verifies + sets these before lock

The preregs ARE NOT locked. They remain editable. Locking is an explicit operator action below.

---

## Phase 1 — Sub-exp 1 closure (PREREQUISITE for B14)

B14 cannot launch until Sub-exp 1 closes and `anchor-drift-check.py` has Sub-exp 1 raw data to compare against.

▶ **Operator action 1.A** — confirm Sub-exp 1 has hit the 3-day window:

```bash
ls /Volumes/DevSSD/FitTracker2-feature-hadf-phase2bis-impl/.claude/shared/hadf/phase2bis-raw-subexp1-*.jsonl | wc -l
```

Expect ≥ 15 fire files (5 fires/day × 3 days). If less, wait until 2026-05-28 evening UTC.

▶ **Operator action 1.B** — run the verdict script + capture output:

```bash
cd /Volumes/DevSSD/FitTracker2-feature-hadf-phase2bis-impl
.venv/bin/python scripts/hadf-phase2bis-verdict.py \
  --raw-dir .claude/shared/hadf/ \
  --subexp subexp1 \
  --silhouette-min 0.5 \
  --yield-min 600 \
  --clusters-min 3 \
  | tee .claude/shared/hadf/verdict-subexp1-$(date -u +%Y-%m-%dT%H-%M-%SZ).json
```

Expected: `{"verdict": "PASS", "silhouette": ~0.66, "clusters": 5}` (dry-run on 2026-05-28 already showed silhouette 0.6645).

▶ **Operator action 1.C** — unload the Sub-exp 1 launchd job (stops further fires):

```bash
launchctl bootout gui/$(id -u)/com.fitme.hadf-phase2bis-subexp1
launchctl print gui/$(id -u)/com.fitme.hadf-phase2bis-subexp1 2>&1 | head -3
# Expected: "Could not find service" — confirms unloaded
```

▶ **Operator action 1.D** — populate `kill_criteria_resolution` + flip B13 in state.json, then commit on the `feat/hadf-phase2bis-impl` branch (NOT main — Mode C gate enforced as of v7.9).

---

## Phase 2 — Sub-exp 2 (Ollama) operator setup

▶ **Operator action 2.A** — install Ollama daemon + pull the model (NO cost; local-only):

```bash
# Install (one-time): https://ollama.com/download — Mac native installer
# Or via Homebrew:
brew install ollama
brew services start ollama

# Verify daemon:
curl -s http://localhost:11434/api/version | python3 -c "import json,sys; print(json.load(sys.stdin))"
# Expected: {"version": "0.3.x" or higher}

# Pull the model (~2 GB download):
ollama pull llama3.2:3b
ollama list | grep llama3.2:3b
# Capture the model digest — required for the kill_criterion "model_digest_drift":
ollama show llama3.2:3b --modelfile | grep -E "^(FROM|PARAMETER)"
```

▶ **Operator action 2.B** — install Sub-exp 2 Python deps + smoke-fire (will hit Ollama daemon ~150 times = 50 calls × 3 dry-fire iterations; no cost):

```bash
cd /Volumes/DevSSD/FitTracker2-feature-hadf-phase2bis-impl
.venv/bin/pip install -r scripts/requirements-hadf-phase2.txt
.venv/bin/python -c "import boto3; import scipy; print('deps ok')"

# Smoke-fire — validates preflight + 1 call per endpoint (50 calls total for subexp2):
scripts/hadf-phase2bis-smoke-fire.sh subexp2 2>&1 | tee .claude/shared/hadf/phase2bis-deploy-verification/subexp2-smoke-$(date -u +%Y-%m-%dT%H-%M-%SZ).log
# Expected last line: "SMOKE_FIRE_OK: preflight passed"
```

If smoke-fire fails on Ollama connectivity, check `lsof -i :11434` — the daemon must be listening. If the daemon is bound only to `0.0.0.0`, the OpenAI-compat client at `http://localhost:11434/v1` should still work, but you can override via `export OLLAMA_BASE_URL=http://127.0.0.1:11434/v1`.

▶ **Operator action 2.C** — confirm + freeze the harness-hardening-proof fields:

```bash
# Update operator_prerequisites in the prereg with actual values:
sha256sum .env.local
# Copy that hash into operator_prerequisites.env_local_sha256 (NOT yet locking — that's step 2.D)

ollama list | grep llama3.2:3b
# Capture the digest into operator_prerequisites.model_digest
```

▶ **Operator action 2.D** — lock the prereg (IRREVERSIBLE — cryptographic commit):

```bash
scripts/hadf-phase2bis-lock-prereg.sh subexp2
# Inspects .claude/shared/hadf/preregistration-phase2bis-subexp2.json
# Computes sha256, writes sibling .lock file, creates signed git tag,
# pushes tag to origin. Pre-commit hook will reject any further edits.
```

▶ **Operator action 2.E** — install + load the Sub-exp 2 launchd job:

```bash
# Customize the plist template if the worktree path differs.
# Current subexp1 fires from /Volumes/DevSSD/FitTracker2-feature-hadf-phase2bis-impl;
# the template assumes per-sub-exp worktree at /Volumes/DevSSD/FitTracker2-hadf-phase2bis-subexp2.
# Either (a) create that worktree:
git worktree add -B feat/hadf-phase2bis-subexp2 \
  /Volumes/DevSSD/FitTracker2-hadf-phase2bis-subexp2 \
  feat/hadf-phase2bis-impl
# OR (b) edit the plist to use the shared worktree (the pattern subexp1 uses today).

# Install + load:
cp .claude/features/hadf-phase2bis-replication/launchd-templates/com.fitme.hadf-phase2bis-subexp2.plist.template \
   ~/Library/LaunchAgents/com.fitme.hadf-phase2bis-subexp2.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.fitme.hadf-phase2bis-subexp2.plist
launchctl print gui/$(id -u)/com.fitme.hadf-phase2bis-subexp2 2>&1 | grep "state ="
# Expected: state = active OR state = not running (idle between fires)
```

▶ **Operator action 2.F** — wait 3 days. At the end of Sub-exp 2 window (~2026-05-31):

```bash
launchctl bootout gui/$(id -u)/com.fitme.hadf-phase2bis-subexp2
.venv/bin/python scripts/hadf-phase2bis-verdict.py --raw-dir .claude/shared/hadf/ --subexp subexp2 ...
```

(Sub-exp 2 uses a different primary metric — KS-distinguishability — so the verdict script may need a `--metric ks` flag added. See Phase 4 below.)

---

## Phase 3 — Sub-exp 3 (Bedrock vs Anthropic-direct) operator setup

▶ **Operator action 3.A** — AWS account prep:

```bash
aws sts get-caller-identity
# Expected: {"UserId": ..., "Account": ..., "Arn": ...}
# If this fails: `aws configure` (set AWS_ACCESS_KEY_ID + AWS_SECRET_ACCESS_KEY + AWS_REGION)

export AWS_REGION=us-east-1  # or us-west-2 — anywhere Anthropic Claude is GA

# Request Bedrock model access (one-time per AWS account):
# Open https://console.aws.amazon.com/bedrock/home#/modelaccess
# Request access to "Anthropic > Claude Haiku 4.5" — approval can take minutes
# to hours. Until approved, all converse_stream calls will return AccessDeniedException.

# Verify access:
aws bedrock list-foundation-models --by-provider anthropic --region $AWS_REGION \
  | python3 -c "import json,sys; d=json.load(sys.stdin); [print(m['modelId']) for m in d['modelSummaries'] if 'haiku' in m['modelId']]"
# Expected: includes anthropic.claude-haiku-4-5-<date>-v1:0
```

▶ **Operator action 3.B** — verify the exact Bedrock model id matches what the prereg + collector expect:

```bash
# Compare:
grep '"endpoint": "anthropic.claude' .claude/shared/hadf/preregistration-phase2bis-subexp3.json
# Current prereg: "anthropic.claude-haiku-4-5-20251001-v1:0"
# If actual model id differs, edit BOTH the prereg AND scripts/hadf-phase2bis-collect.py ENDPOINTS["subexp3"]
# BEFORE locking. After locking the prereg becomes immutable.
```

▶ **Operator action 3.C** — smoke-fire (≈$0.05 — 150 calls total: 50 each × OpenAI + Anthropic + Bedrock):

```bash
scripts/hadf-phase2bis-smoke-fire.sh subexp3 2>&1 | tee .claude/shared/hadf/phase2bis-deploy-verification/subexp3-smoke-$(date -u +%Y-%m-%dT%H-%M-%SZ).log
```

▶ **Operator action 3.D** — lock + install plist (same pattern as Sub-exp 2):

```bash
scripts/hadf-phase2bis-lock-prereg.sh subexp3
cp .claude/features/hadf-phase2bis-replication/launchd-templates/com.fitme.hadf-phase2bis-subexp3.plist.template \
   ~/Library/LaunchAgents/com.fitme.hadf-phase2bis-subexp3.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.fitme.hadf-phase2bis-subexp3.plist
```

▶ **Operator action 3.E** — wait 3 days (~2026-06-04). After collection:

```bash
launchctl bootout gui/$(id -u)/com.fitme.hadf-phase2bis-subexp3
.venv/bin/python scripts/hadf-phase2bis-anchor-drift-check.py \
  --sub-exp-1-raw .claude/shared/hadf/ \
  --sub-exp-3-raw .claude/shared/hadf/ \
  --anchor-provider openai \
  --anchor-endpoint gpt-4o-mini \
  --p-threshold 0.01
# Then run verdict-script for subexp3 routing test (Phase 4 update needed).
```

---

## Phase 4 — Block C synthesis (after all three sub-exps close)

Block C case-study skeleton already lives on two worktrees:
- FT2: `.claude/worktrees/chore+hadf-block-c-case-study-skeleton-2026-05-27`
- fitme-story: `.worktrees/hadf-block-c` (MDX now at `22e-…`)

▶ **Operator actions for Block C:**

1. Fill §3.A / §3.B / §3.C verdicts in the synthesis case study from each sub-exp's verdict JSON
2. Fill §4 anchor-drift analysis from `hadf-phase2bis-anchor-drift-check.py` output
3. Fill §5 overall HADF claim disposition per the decision table in the MDX
4. Open PR pair (FT2 + fitme-story) — they ship together; chronological-order rule applies
5. Final integrity check + `kill_criteria_resolution` populated

---

## Outstanding code work (deferred — NOT blocking B14/B15 launch)

These items can be addressed during Sub-exp 2 collection window (3 days of idle time):

1. **`scripts/hadf-phase2bis-verdict.py` extension** — current script computes silhouette + cluster count only (works for Sub-exp 1). Needs:
   - `--metric ks` flag for Sub-exp 2 KS-distinguishability calculation (cloud-vs-local)
   - `--metric signature_delta_ratio` flag for Sub-exp 3 Mahalanobis routing-test calculation
   - Or split into 3 sub-commands. Current line count: 86. Estimated addition: ~50 lines.

2. **Heartbeat ledger extension** — `phase2bis-fire-heartbeat.jsonl` records each fire's PREFLIGHT_OK marker; needs subexp2 + subexp3 entries to start flowing.

3. **Cost log** — `phase2bis-cost-log.jsonl` will accumulate Sub-exp 3 Bedrock costs (~$1 expected). Existing trip-wire `cost_overrun_3x` checks against this ledger.

---

## Approval gates — none of the below fire without explicit operator command

| # | Action | Cost | Reversible? |
|---|---|---|---|
| 1.B | Sub-exp 1 verdict run | $0 (offline analysis) | Yes |
| 1.C | Unload Sub-exp 1 plist | $0 | Reload to undo |
| 2.A | Install Ollama + pull model | $0 (2 GB disk) | Uninstall to undo |
| 2.B | Sub-exp 2 smoke-fire | $0 (local Ollama only) | n/a — read-only |
| 2.D | **Lock Sub-exp 2 prereg** | $0 | **IRREVERSIBLE** — cryptographic commit |
| 2.E | Install Sub-exp 2 plist | $0 (3 days of local CPU) | Bootout to undo |
| 3.A | Request Bedrock model access | $0 (AWS account change) | Revoke in console |
| 3.C | Sub-exp 3 smoke-fire | ~$0.05 | n/a — read-only |
| 3.D | **Lock Sub-exp 3 prereg + install plist** | ~$1 over 3 days | **IRREVERSIBLE lock** + plist bootoutable |

---

## Files modified by Claude in this prep pass

```
scripts/hadf-phase2bis-collect.py                                  +75 -8 lines
scripts/requirements-hadf-phase2.txt                               +8 -1 lines
.claude/shared/hadf/preregistration-phase2bis-subexp2.json         (full rewrite)
.claude/shared/hadf/preregistration-phase2bis-subexp3.json         (full rewrite)
.claude/features/hadf-phase2bis-replication/operator-prelaunch-runbook-b14-b15.md  (NEW)

fitme-story:.worktrees/hadf-block-c/content/04-case-studies/
  22c-hadf-phase2bis-cross-sub-exp-synthesis.mdx → 22e-...mdx       (git mv)
```

No commits made. No locks fired. No launchd jobs touched. No real API calls.
