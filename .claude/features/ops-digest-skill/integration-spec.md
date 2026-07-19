# Integration Spec — ops-digest-skill (F23 / FIT-205)

`has_ui = false` → this is the Phase 3b technical-contract spec.

## 1. Interfaces / contracts

### CLI
```
python3 scripts/ops-digest.py [--json] [--window-days N] [--no-write] [--today YYYY-MM-DD]
make ops-digest [ARGS="--json"|"--window-days N"]
```
- **stdout:** human-readable digest (default) or JSON (`--json`).
- **exit code:** `0` normally; `1` only on a hard integrity `fail` (hook-gateable).
- **snapshot:** `.claude/shared/ops-digest.json` (schema below) unless `--no-write`.

### JSON snapshot schema
```json
{
  "generated_at": "ISO-8601",
  "head": "<short sha>", "branch": "<name>", "window_days": 14,
  "overall_verdict": "ok|warn|fail|unknown",
  "sections": {
    "deploy_ci":  { "verdict", "recent_merges": [{"pr","subject"}], "bot_pr_health" },
    "integrity":  { "verdict", "overall": "PASS|WARN|FAIL", "layers": [...] },
    "telemetry":  { "verdict", "adoption": {"fully_adopted","post_v6","status","generated_at"} },
    "cadence":    { "verdict", "upcoming": [{"id","due","in_days","what"}] }
  }
}
```

## 2. Producer dependencies (composed, read-only)

| Section | Producer | Coupling | Failure mode |
|---|---|---|---|
| Deploy/CI | `git log` + `scripts/check-bot-pr-health.py` | exit code + subject regex `\(#N\)$` | timeout/error → section `unknown` |
| Integrity | `scripts/integrity-telemetry-sweep.py` | stdout `OVERALL: (PASS\|WARN\|FAIL)` regex | error → `unknown` |
| Telemetry | `.claude/shared/measurement-adoption.json` | read `summary.*` (dual-read fallback to top-level) | missing/malformed → `unknown` |
| Cadence | `.claude/shared/must-have-cadence-followups.md` | table rows w/ ISO date, skip `~~struck~~` | missing → `unknown` |

**Contract stance:** couple to each producer's **stable text/exit contract**, not
its full output. A producer format change degrades one section to `unknown`
(surfaced, never silent) — the fail-soft invariant.

## 3. Error handling

- `_run()` wraps every subprocess with a timeout; `TimeoutExpired`/`OSError` →
  `(124, "__error__: ...")` → that section only becomes `unknown`.
- Snapshot write failure → stderr warning, digest still prints (best-effort).
- `overall_verdict` = max severity across sections; `unknown` outranks `ok` but
  not `warn`/`fail`, so a degraded producer never masks a real problem nor
  manufactures a false `fail`.

## 4. Backward compatibility

Purely additive. No existing script, gate, schema, or make target changes
behavior. `.PHONY` updated to include `ops-digest`. No new enforcement gate.

## 5. Env overrides (testability)

- `OPS_DIGEST_REPO_ROOT` — override repo root (used by the try-repo-style tests).
- `--today YYYY-MM-DD` — deterministic cadence-window testing.
