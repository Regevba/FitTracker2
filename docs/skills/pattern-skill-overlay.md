# Pattern↔Skill Preflight Overlay (v7.9.1)

> When one of the 12 skills (`.claude/skills/*`) activates, it should know
> exactly which [Observed Patterns Catalog](../../.claude/integrity/observed-patterns.md)
> patterns can block its kind of work — and proactively probe the mechanized
> ones so blockers are cleared **before** work begins, not discovered
> reactively when a gate fires mid-task.
>
> Established 2026-06-04 (`feature/pattern-skill-preflight-overlay`). Catalog
> self-doc: [`observed-patterns.md` W29](../../.claude/integrity/observed-patterns.md).

## The HYBRID model

The catalog has two kinds of patterns:

| Kind | Count | How the overlay treats it |
|---|---|---|
| **Mechanized** (a script can detect it) | ~23 | **Probe** it live via `make skill-preflight` |
| **Manual / compile / discipline** | ~28 | **Checklist** it — surface as an awareness line |

So the overlay *probes what it can* and *reminds you of the rest*.

## Pieces

| Piece | Path | Role |
|---|---|---|
| Source of truth | [`.claude/shared/pattern-skill-map.json`](../../.claude/shared/pattern-skill-map.json) | One entry per work-blocking catalog pattern → which skills it blocks + detector + remediation |
| Shared probes | [`scripts/preflight_checks.py`](../../scripts/preflight_checks.py) | Importable check functions (shared with `make preflight`) |
| Overlay runner | [`scripts/skill-preflight.py`](../../scripts/skill-preflight.py) | `--skill <name>` — probes mechanized, checklists manual, writes `skill_overlay` to the cache |
| Section generator | [`scripts/generate-skill-preflight-sections.py`](../../scripts/generate-skill-preflight-sections.py) | Regenerates each SKILL.md's preflight table (idempotent) |
| Self-audit | `PATTERN_SKILL_UNMAPPED` in [`scripts/integrity-check.py`](../../scripts/integrity-check.py) | Advisory — flags catalog IDs missing from the map |

## `pattern-skill-map.json` schema

A JSON array of 51 objects (one per work-blocking pattern):

```json
{
  "id": "#12",
  "title": "PR_CACHE_STALE — empty/stale cache → cascading false positives",
  "section": "gate",
  "blocker": false,
  "detector": "scripts/ensure-pr-cache-fresh.py",
  "autoheal": true,
  "skills": ["pm-workflow", "dev"],
  "remediation": "Auto-refreshes via scripts/ensure-pr-cache-fresh.py; run make refresh-pr-cache if findings persist."
}
```

| Field | Type | Meaning |
|---|---|---|
| `id` | string | Catalog ID — `#1`–`#23` (gate) or `W1`–`W28` (workflow) |
| `title` | string | Catalog entry title |
| `section` | `"gate"` \| `"workflow"` | Which catalog section |
| `blocker` | bool | Does ignoring this block/break the work (vs. an advisory)? |
| `detector` | path \| `"manual"` | Mechanized probe script, or `"manual"` for checklist-only |
| `autoheal` | bool | Does the detector fix the condition itself (e.g. PR-cache refresh)? |
| `skills` | string[] | Skills whose work this pattern can block (many-to-many) |
| `remediation` | string | One-line fix |

### Detector → probe registry

`detector` must be `"manual"` or one of these (resolved by `skill-preflight.py`):

| Detector | Probe (in `preflight_checks.py`) | Covers |
|---|---|---|
| `scripts/integrity-check.py` | `check_integrity()` | gate patterns (cycle-time findings) |
| `scripts/ensure-pr-cache-fresh.py` | `check_pr_cache_fresh()` | `#12`, `W11` (auto-heals) |
| `scripts/check-ssh-agent.sh` | `check_w1_ssh_agent()` | `W1` |
| `scripts/check-branch-drift.py` | `check_branch_drift()` | `W9` |
| `scripts/preflight_checks.py` | `check_workflow_name_collision()` | `W26` (thin grep probe) |

## Usage

```bash
# Probe the patterns that can block /dev work, right now:
make skill-preflight SKILL=dev

# Machine-readable:
python3 scripts/skill-preflight.py --skill dev --json

# Regenerate every SKILL.md preflight table after editing the map:
make gen-skill-preflight
```

`skill-preflight` exit codes: **0** = no mechanized blocker tripped (advisories /
manual items OK); **1** = a `blocker:true` detector tripped; **2** = invalid input.

### `skill_overlay` cache block

`skill-preflight.py` writes an **additive** key into
`.claude/shared/preflight-cache.json` (existing keys untouched):

```json
"skill_overlay": {
  "dev": {
    "generated_at": "2026-06-04T09:09:25Z",
    "checked":  ["#12", "#13", "W1", "W9", "W26"],
    "blocking": [],
    "advisory": ["#12", "W1", "W26"],
    "manual":   ["#23", "W3", "W4", "W5", "W7", "W10", "W17", "W21", "W22", "W23", "W24", "W25", "W28"]
  }
}
```

See [`preflight-cache-schema.md`](preflight-cache-schema.md#skill_overlay-additive-v791) for the full schema.

## Skill → pattern mapping (current)

| Skill | Mapped patterns |
|---|---|
| pm-workflow | `#1`–`#13`, `#15`–`#21`, `W2`, `W6`, `W20`, `W27` |
| dev | `#12`, `#13`, `#23`, `W1`, `W3`, `W4`, `W5`, `W7`, `W9`, `W10`, `W17`, `W21`–`W26`, `W28` |
| qa | `#22`, `W21`, `W22`, `W23`, `W25`, `W28` |
| design | `#6`, `#8`, `#14`, `W14` |
| ops | `#23`, `W8`, `W11`, `W12`, `W13`, `W18`, `W19` |
| release | `W4`, `W15`, `W18`, `W19`, `W26`, `W28` |
| marketing | `W15`, `W18` |
| analytics | `#2`, `#7`, `W19` |
| cx | `W8` |
| research | `W20` |
| ux | `#6`, `#16`, `W16` |
| brainstorm-pm | `#17`, `W2`, `W6` |

> Regenerate this section's source from the map; the SKILL.md tables are the
> authoritative per-skill view (`make gen-skill-preflight`).

## Maintenance: adding a new catalog pattern

1. Append the pattern entry to [`observed-patterns.md`](../../.claude/integrity/observed-patterns.md) (+ index row).
2. Add a matching entry to [`pattern-skill-map.json`](../../.claude/shared/pattern-skill-map.json) with ≥1 skill.
3. Run `make gen-skill-preflight`.
4. `make integrity-check` — `PATTERN_SKILL_UNMAPPED` advisory reminds you if step 2 was skipped.

Meta-entries that document tooling rather than a work-blocking pattern (e.g.
`W29`, which documents this overlay) are intentionally kept out of the map and
exempted via the `SELF_DOC_EXEMPT` set in `integrity-check.py`.
