# Preflight cache schema

**Path:** `.claude/shared/preflight-cache.json`
**Producer:** `scripts/preflight.py` (invoked via `make preflight WORK_TYPE=<t> [FEATURE=<n>]`)
**Consumers:** every skill listed in [`.claude/skills/`](../../.claude/skills) reads this file in its `## Shared Data` section.
**Lifecycle:** overwritten each run. Cache is per-session (not committed); re-run when work_type or feature changes.

## Why this file exists

Before v7.8.6, every skill re-collected the same pre-work data (W1 ssh-agent, integrity findings, drift vs anchor, doc-debt, adoption baseline, branch isolation). The unified preflight runs all checks once, writes the result here, and downstream skills read instead of re-computing. Closes the per-skill duplication that the user surfaced 2026-05-15.

## Top-level schema

```json
{
  "work_type": "feature | enhancement | fix | chore",
  "feature": "<feature-name | null>",
  "generated_at": "<ISO-8601 UTC>",
  "checks": [
    {
      "name": "<check-name>",
      "status": "ok | warning | blocking | info",
      "detail": "<human-readable summary>",
      "blocking": true | false,
      "...check-specific fields..."
    }
  ],
  "summary": {
    "total_checks": <int>,
    "ok": <int>,
    "warnings": <int>,
    "blocking": <int>
  },
  "blocking_issues": ["<check-name>", ...]
}
```

## Always-run checks

| Name | Status semantics | Check-specific fields | Source |
|---|---|---|---|
| `W1_ssh_agent` | ok = ≥1 key loaded; warning = empty/unreachable | — | `ssh-add -l` exit code |
| `pr_cache_fresh` | ok = fresh; warning = refresh failed | — | `scripts/ensure-pr-cache-fresh.py` |
| `branch_isolation` | ok = on feature branch; warning = on `main` | `current_branch` | `git branch --show-current` |
| `integrity_check` | ok = 0 findings; blocking = ≥1 | `findings_count`, `advisory_count` | `scripts/integrity-check.py --findings-only` |
| `integrity_diff` | ok = no regression; warning = ≥1 regression vs 2026-05-14 anchor | `regressions: [{key, baseline, current, delta}, …]` | `scripts/integrity-diff.py --json` |
| `documentation_debt` | info | `open_count` | `.claude/shared/documentation-debt.json` |
| `measurement_adoption` | info | `fully_adopted_post_v6`, `features_post_v6`, `adoption_pct_post_v6` | `.claude/shared/measurement-adoption.json` |

## Work-type-specific checks

| Work type | Additional check | When it fires |
|---|---|---|
| `feature` | `feature_state_json` | If `--feature` provided. Reports current_phase; "no state.json yet" is OK at Phase 0 entry. |
| `enhancement` | `enhancement_parent` | If `--feature` provided. **Blocking** if parent has no `prd.md` or is not in a downstream phase. |
| `fix` | `fix_high_risk_touch` | Always. Warning if any high-risk file (DomainModels, EncryptionService, sync services, SignInService, AuthManager, AIOrchestrator) is in the working diff. |
| `chore` | `chore_infra_paths` | Always. Warning if any infra path (`.githooks/`, `.github/workflows/`, `scripts/`, `.claude/skills/`, `.claude/shared/`, `docs/architecture/`, `Makefile`, `CLAUDE.md`) is in the working diff — indicates isolated worktree is recommended. |

## Status conventions

- **ok** (✓) — pass; nothing further required
- **warning** (⚠) — advisory; review but does not block phase advancement
- **blocking** (✗) — block phase advancement until resolved
- **info** (·) — pure data surface; no judgment

A consumer skill that finds `summary.blocking > 0` MUST refuse to advance the phase until the operator clears the blocking issues.

## How skills should consume this

```python
import json
from pathlib import Path

cache = json.loads(Path(".claude/shared/preflight-cache.json").read_text())
if cache["summary"]["blocking"] > 0:
    raise SystemExit(f"preflight blocking: {cache['blocking_issues']}")

# Specific datum lookup:
adoption_pct = next(
    c.get("adoption_pct_post_v6")
    for c in cache["checks"] if c["name"] == "measurement_adoption"
)
```

## Cache staleness

The cache has no expiry mechanism — the consumer is responsible for re-running `make preflight` when:
- Switching feature
- Switching work_type
- Crossing a commit boundary that touches state.json or shared ledgers
- After a long pause (cron + 72h cycle may have fired)

`scripts/preflight.py` is idempotent and fast (~5s on a clean tree). Re-run liberally.

## Cross-layer freshness companion (added 2026-05-28)

`make preflight` auto-chains `make freshness-check` (`scripts/cross-layer-freshness.py`) which writes a separate ASCII summary to stdout — it does NOT extend the JSON cache. Skills that need the freshness datums consume them via:

```bash
python3 scripts/cross-layer-freshness.py --format=json
```

The freshness check covers 6 layers `make preflight` does not:

| Layer | Producer | Purpose |
|---|---|---|
| `recent_merged_prs` | `gh pr list --state merged --search "merged:>=…"` BOTH repos | Catch operator-shipped work the session thought was open |
| `worktree_divergence` | `git worktree list` + `git rev-list --left-right --count` per worktree | Flag stale worktrees (behind > 7) before they overwrite shipped work |
| `memory_drift` | `MEMORY.md` keyword scan vs `.claude/features/*/state.json::current_phase` | Surface memory entries claiming "in flight" for already-complete features |
| `linear_sync` | Linear GraphQL (requires `LINEAR_API_KEY`) | FIT-team root issue status vs local state.json |
| `gh_scope` | `gh auth status` parse | Detect missing OAuth scopes (e.g. `admin:public_key`) that silently 404 diagnostic API calls. Added 2026-05-28. |
| `signing` | `SSH_AUTH_SOCK` + `ssh-add -l` + `git config user.signingkey` + `ioreg` (YubiKey USB presence) | Catch the 2026-05-28 footgun: user.signingkey expects YubiKey but agent has Touch ID only + YubiKey absent → 15s pause per commit. Added 2026-05-28. |

JSON schema (see `scripts/cross-layer-freshness.py::collect_freshness()` for the producer):

```json
{
  "generated_at": "<ISO-8601 UTC>",
  "days": 7,
  "since": "<YYYY-MM-DD>",
  "layers": {
    "recent_merged_prs": {
      "FitTracker2": {"status": "ok|unavailable", "count": <int>, "prs": [{"number","title","headRefName","mergedAt"}]},
      "fitme-story": {…}
    },
    "worktree_divergence": [
      {"path","branch","head","ahead","behind","stale_warning":true|false}
    ],
    "memory_drift": [
      {"line_no","feature_slug","claim_phrase","snippet","actual_phase","drift":true}
    ],
    "linear_sync": {"status":"checked|skipped_no_token|error","epics":[…]}
  },
  "summary": {
    "recent_pr_count_total": <int>,
    "stale_worktrees": <int>,
    "memory_drift_count": <int>,
    "linear_status": "<string>"
  }
}
```

Rationale: [`feedback_cross_layer_freshness_check.md`](../../memory/feedback_cross_layer_freshness_check.md) (auto-memory) — established 2026-05-28 after a session-state failure mode where work prep duplicated already-merged PRs.

## Related

- `docs/master-plan/data-integrity-and-rollback-2026-05-14.md` §2.1 — drift window this closes
- `docs/master-plan/infra-master-plan-2026-05-12.md` §4.1 — v7.9 promotion calendar
- `.claude/integrity/observed-patterns.md` — W1 (ssh) + W3 (CI check) + W9 (branch drift) + W20 (stale-session-state) patterns the preflight surfaces
- `scripts/preflight.py` — producer
- `scripts/integrity-diff.py` — drift-vs-anchor comparator the preflight invokes
