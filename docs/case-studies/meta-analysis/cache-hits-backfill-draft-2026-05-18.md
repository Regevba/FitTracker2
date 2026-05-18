# Cache-Hits Surgical Backfill — Draft + 2026-05-22 Execution Recipe

> **Generated:** 2026-05-18 (during v7.9 calibration freeze; execution deferred to 2026-05-22)
> **Source recommendation:** [Action 5 of PR #392 verdict report](../../../.claude/shared/telemetry-audit-t7-9-0-decision-2026-05-18.md) — non-blocking
> **Companion decisions:** [FIT-69 grandfather essay](kill-criteria-resolution-backfill-decision-2026-05-18.md) (same calibration-window protection logic)
> **Target features (3):** `framework-v7-8-bridge`, `code-connect-automation`, `cross-repo-state-sync-impl`
> **Total entries to author:** 8 cache_hits across 3 features (3 + 2 + 3)

## TL;DR

Three complete post-Mechanism-C features have empty `cache_hits[]`. The PR #392 verdict report recommended a surgical backfill but assumed Mechanism C session-ledger attribution would be reliable. **It is not** — the `active_feature` field on session-ledger events in the 2026-05-04 → 2026-05-11 window is mostly empty string. This document substitutes a case-study-evidence backfill methodology (better than session-ledger mining for this window), drafts the 8 honest entries here, and defers state.json execution to 2026-05-22 to avoid contaminating the 2026-05-15 → 2026-05-21 v7.9 calibration window.

## Why deferred to 2026-05-22

Same contamination-protection logic as the [FIT-69 grandfather decision](kill-criteria-resolution-backfill-decision-2026-05-18.md):

- Editing 3 state.json files now writes ~15 new `candidate` rows into `gate-coverage.jsonl` (each state.json-scanning gate fires per staged file; ~5 gates × 3 files; rows show `checked=0, skipped=1, skip_reason=not_complete_transition` since `current_phase` isn't changing)
- This is small noise relative to the existing 1,850-entry ledger
- BUT the v7.9 promotion criterion #2 is "no false positives baseline" — applying the no-contamination rule consistently is more defensible than carving out a "but this case is small" exception
- Same precedent as the C1 F14/F15 dispatch-test deferral to 2026-05-22

## Methodology change vs PR #392 Action 5

| Aspect | PR #392 Action 5 assumption | What I found 2026-05-18 |
|---|---|---|
| Backfill source | Mechanism C session ledgers (`.claude/logs/_session-*.events.jsonl`) with `active_feature` attribution | 48 session ledgers exist locally; `active_feature` field is **mostly empty string `""`** on events in target window (2026-05-04 → 11); mechanical attribution fails |
| Recommended path | Mine ledgers, filter Reads by active-feature, convert to cache_hits | Use case-study documented reuse evidence; cite the predecessor pattern + reuse type in each entry's `task_context` |
| Volume estimate | "10 features with empty cache_hits" | Stays accurate; I'm targeting the 3 HIGH-priority complete features per the verdict's prioritization |
| Effort estimate | 30-45 min | 20 min draft + 15 min mechanical execution 2026-05-22 |
| Honesty risk | Could over-fit (count all Reads as hits) | Case-study evidence anchors each entry to documented reuse |

**Finding for FIT-95 (F1 backfill sprint) scope:** the session-ledger attribution gap predates Mechanism C maturity. FIT-95 scope should account for this: features created 2026-05-02 → 2026-05-14 likely have unreliable `active_feature` attribution on their session-ledger events because the marker file convention wasn't yet operator-trained at that point. Going forward (post-v7.8.6), the `.claude/active-feature` marker is set on every `/pm-workflow` entry, so newer features will have reliable attribution.

## Draft cache_hits entries (to apply 2026-05-22)

All entries below carry an explicit `[RETROACTIVE-BACKFILL 2026-05-18]` prefix in `task_context` so a future reader can never confuse them with real-time observations. Timestamps approximate the feature's implementation window (mid-day of the most active session).

### `framework-v7-8-bridge` — 3 entries

Case study: [`framework-v7-8-bridge-case-study.md`](../framework-v7-8-bridge-case-study.md). Created 2026-05-04, complete.

```json
[
  {
    "timestamp": "2026-05-03T12:00:00Z",
    "cache_level": "L3",
    "skill": "dev",
    "cache_key": "framework-v7-7-validity-closure:cache-hits-empty-post-v6-gate-pattern",
    "hit_type": "adapted",
    "task_context": "[RETROACTIVE-BACKFILL 2026-05-18] Reused v7.7's CACHE_HITS_EMPTY_POST_V6 gate pattern from framework-v7-7-validity-closure; fixed silent-pass via dual-read (created_at ∪ created); upgraded the meta-instrumentation to Mechanism A coverage assertion. See case study Section 2 trigger + Section 4 implementation."
  },
  {
    "timestamp": "2026-05-03T14:00:00Z",
    "cache_level": "L3",
    "skill": "dev",
    "cache_key": "framework-v7-7:advisory-to-enforced-calibration-window-pattern",
    "hit_type": "adapted",
    "task_context": "[RETROACTIVE-BACKFILL 2026-05-18] Reused the 7-day calibration window pattern (advisory → enforced) introduced in v7.7. Applied as the mechanism that gates v7.9 promotion of V2 (CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT)."
  },
  {
    "timestamp": "2026-05-04T08:00:00Z",
    "cache_level": "L2",
    "skill": "dev",
    "cache_key": "tier-1-1-write-time-gate-mechanism-pattern",
    "hit_type": "adapted",
    "task_context": "[RETROACTIVE-BACKFILL 2026-05-18] Reused the Tier 1.1 pre-commit hook mechanism (scripts/check-state-schema.py registration + .githooks/pre-commit dispatch glue) from earlier framework versions. Extended with Mechanism C PostToolUse:Read hook + scripts/observe-cache-hit.py."
  }
]
```

### `code-connect-automation` — 2 entries

Case study: [`code-connect-automation-case-study.md`](../code-connect-automation-case-study.md). Created 2026-05-10, complete.

```json
[
  {
    "timestamp": "2026-05-09T15:00:00Z",
    "cache_level": "L3",
    "skill": "design",
    "cache_key": "figma-mcp-bridge:use_figma-write-pattern",
    "hit_type": "adapted",
    "task_context": "[RETROACTIVE-BACKFILL 2026-05-18] Reused the Figma MCP use_figma write pattern (from prior fitme-story Figma generation work) for scaffolding .figma.tsx and .figma.swift mapping template files. The bridge from code → Figma was the established pattern; this feature extended it to code → Figma library mapping bidirectionally."
  },
  {
    "timestamp": "2026-05-10T10:00:00Z",
    "cache_level": "L2",
    "skill": "dev",
    "cache_key": "ci-workflow-scaffold:figma-publish-pattern",
    "hit_type": "adapted",
    "task_context": "[RETROACTIVE-BACKFILL 2026-05-18] Reused existing GH Actions CI workflow scaffold (matrix runner + repo-secret-gated step pattern from prior workflows) for both repos' figma-code-connect-publish.yml. Token-gated skip-on-missing behavior matches established convention."
  }
]
```

### `cross-repo-state-sync-impl` — 3 entries

Case study: [`cross-repo-state-sync-impl-case-study.md`](../cross-repo-state-sync-impl-case-study.md). Created 2026-05-11, complete.

```json
[
  {
    "timestamp": "2026-05-10T18:00:00Z",
    "cache_level": "L3",
    "skill": "dev",
    "cache_key": "framework-v7-8-bridge:mechanism-e-merge-driver-pattern",
    "hit_type": "exact",
    "task_context": "[RETROACTIVE-BACKFILL 2026-05-18] The Mechanism E merge driver (scripts/merge-driver-dedup.py + .gitattributes registration) shipped in v7.8. This feature extends it to .claude/logs/<feature>.log.json via glob pattern — pure extension of the existing driver, no new logic. Case study Section 5 V9 description."
  },
  {
    "timestamp": "2026-05-10T20:00:00Z",
    "cache_level": "L3",
    "skill": "dev",
    "cache_key": "v7-8-2-cross-repo-asymmetry:documented-exemption-pattern",
    "hit_type": "adapted",
    "task_context": "[RETROACTIVE-BACKFILL 2026-05-18] Reused the documented-exemption pattern from v7.8.2 (docs/superpowers/specs/2026-05-08-cross-repo-gate-asymmetry.md) for the state_owner field decision — chose explicit enum marker over implicit detection. Same shape: code the rule, document the exception, gate enforces the convention."
  },
  {
    "timestamp": "2026-05-11T11:00:00Z",
    "cache_level": "L2",
    "skill": "dev",
    "cache_key": "framework-v7-8:advisory-to-enforced-calibration-window-pattern",
    "hit_type": "adapted",
    "task_context": "[RETROACTIVE-BACKFILL 2026-05-18] Reused the 7-day calibration window pattern (advisory → enforced) for the V2 promotion in Phase 0. CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT had been advisory for 7 days with zero false positives, then promoted to enforced. Case study Phase 0 description."
  }
]
```

## 2026-05-22 execution recipe

After 2026-05-21 v7.9 promotion decision lands, run on a feature branch:

```bash
# 1. Branch off main
git checkout -b chore/cache-hits-surgical-backfill-2026-05-22

# 2. Use the canonical writer-path (preserves Tier 1.1 + Tier 2.2 dual-write)
for entry in $(seq 1 3); do
  python3 scripts/append-feature-log.py \
    --feature framework-v7-8-bridge \
    --event-type cache_hit \
    --phase implementation \
    --cache-hit L3 \
    --cache-key "framework-v7-7-validity-closure:cache-hits-empty-post-v6-gate-pattern" \
    --cache-hit-type adapted \
    --cache-skill dev \
    --summary "[RETROACTIVE-BACKFILL 2026-05-18 draft] ..." \
    --retroactive \
    --retroactive-reason "Surgical backfill per PR #392 Action 5; calibration-window-deferred draft authored 2026-05-18, executed 2026-05-22"
  # ... repeat for each entry per the draft above
done

# 3. Verify
for f in framework-v7-8-bridge code-connect-automation cross-repo-state-sync-impl; do
  jq '.cache_hits | length' .claude/features/$f/state.json
done
# Expected: 3, 2, 3

# 4. Verify integrity
make integrity-check
# Expected: 0 findings + 0 advisories (cache_hits no longer empty on the 3 features)

# 5. Commit + PR
git add .claude/features/{framework-v7-8-bridge,code-connect-automation,cross-repo-state-sync-impl}/state.json \
        .claude/logs/{framework-v7-8-bridge,code-connect-automation,cross-repo-state-sync-impl}.log.json
git commit -m "chore(cache-hits): surgical backfill 3 complete features per PR #392 Action 5"
git push -u origin chore/cache-hits-surgical-backfill-2026-05-22
gh pr create --title "..." --body "..."
```

The `--retroactive` + `--retroactive-reason` flags are critical — they mark each event as a backfill rather than a real-time observation in the Tier 2.2 log.

## What this document IS NOT

- It is NOT an authorization to backfill the other 7 post-Mechanism-C empty-cache_hits features (`3d-interactive-framework-flow-diagram`, `hadf-phase2bis-replication`, `analytics-observability`, `framework-v7-9-promotion`, `ucc-passkey-auth-audit-log-redis-fix`, `ucc-sign-in-figma-mapping`, `ios-code-connect`). Those are deferred to FIT-95 (F1 backfill sprint) per the verdict report.
- It is NOT a precedent for mechanical Reads → cache_hits conversion. Each entry here is anchored to specific case-study-documented reuse evidence.
- It does NOT auto-execute. The execution requires operator action on 2026-05-22 (or later); this document is the draft + recipe.

## Cross-references

- [`.claude/shared/telemetry-audit-t7-9-0-decision-2026-05-18.md`](../../../.claude/shared/telemetry-audit-t7-9-0-decision-2026-05-18.md) §"Action 5 recommendation" — source
- [`kill-criteria-resolution-backfill-decision-2026-05-18.md`](kill-criteria-resolution-backfill-decision-2026-05-18.md) — same contamination-protection precedent
- [`framework-v7-8-bridge-case-study.md`](../framework-v7-8-bridge-case-study.md) — reuse evidence source
- [`code-connect-automation-case-study.md`](../code-connect-automation-case-study.md) — reuse evidence source
- [`cross-repo-state-sync-impl-case-study.md`](../cross-repo-state-sync-impl-case-study.md) — reuse evidence source
- [`.claude/shared/must-have-cadence-followups.md`](../../../.claude/shared/must-have-cadence-followups.md) §C1 — same 2026-05-22 deferral pattern (F14/F15)
- FIT-95 (Linear) — broader backfill sprint scope; this document delimits 3 features explicitly OUT of FIT-95 scope (handled here) and the remaining 7 IN-scope

## Decision record

| Date | Action | Author |
|---|---|---|
| 2026-05-18 | Draft + recipe authored; state.json execution deferred to 2026-05-22 | Operator (Regev) + Claude Opus 4.7 |
| 2026-05-22 | Execute the recipe above; commit + PR | TBD (operator or scheduled agent) |
| Post-execution | Update PR #392 verdict report's Action 5 follow-up status | TBD |
