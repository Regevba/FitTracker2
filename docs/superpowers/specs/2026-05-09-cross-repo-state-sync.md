# Cross-Repo State Sync — Phase C of the 2026-05-09 Framework Port

**Created:** 2026-05-09
**Closes:** Phase C of the 2026-05-09 cross-repo framework port directive ("data between main repos are synced")
**Predecessors:**
- [`2026-05-08-cross-repo-gate-asymmetry.md`](2026-05-08-cross-repo-gate-asymmetry.md) — original v7.8.2 disposition (now §8 reversed)
- fitme-story PR #72 — Phase B framework port (gates ported to fitme-story)
- FT2 PR #267 — Phase A retroactive v7.8.1 invocation on the rollup

---

## §1 The contract

```
┌─────────────────────────────────────────┐         ┌──────────────────────────────────────┐
│  FitTracker2 (canonical state)          │         │  fitme-story (deployment + display)  │
│                                         │         │                                      │
│  .claude/features/<name>/state.json     │ ──────▶ │  src/data/features/<name>.json       │
│  .claude/logs/<name>.log.json           │ ──────▶ │  src/data/logs/<name>.log.json       │
│  .claude/shared/*.json                  │ ──────▶ │  src/data/shared/*.json              │
│  .claude/integrity/snapshots/*.json     │ ──────▶ │  src/data/integrity/snapshots/*.json │
│  docs/case-studies/*.md                 │ ──────▶ │  src/data/docs/.../case-studies/*.md │
│  .claude/logs/gate-coverage.jsonl       │         │  .claude/logs/gate-coverage.jsonl    │
│       (FT2 commits log here)            │         │       (fitme-story commits here)     │
└─────────────────────────────────────────┘         └──────────────────────────────────────┘
        ▲                                                       │
        │                                                       │
        └────────── (no reverse-sync — see §3) ─────────────────┘
```

**Rule:** FitTracker2 is the **canonical source of truth** for every framework state artifact. fitme-story is a **read-only consumer** for display in `/control-room/*`.

The one exception: `.claude/logs/gate-coverage.jsonl` accumulates **independently** in each repo because Mechanism A telemetry fires on whichever repo a gate runs in. The control-room reads both files at build time.

## §2 Why this contract

Three reasons:

1. **Single canonical writer eliminates merge conflicts.** Every framework state file is "owned" by FT2 — only FT2 commits write to `.claude/features/<name>/state.json`. fitme-story consumers read from synced copies in `src/data/`.

2. **The PM workflow lives in FT2.** All `/pm-workflow {name}` invocations create the feature in FT2. `state.json` mutations (phase transitions, task completions, kill-criteria resolutions) happen in FT2. The framework gate stack (which now exists in both repos per Phase B) protects FT2's writes; fitme-story's gates fire on **its own** state.json mutations IF any happen, but the contract is "fitme-story doesn't write state.json".

3. **Reverse-sync would invert the gate model.** If fitme-story could write to FT2's `.claude/features/`, the gates would have to validate writes coming from a different repo's tooling. Keeping the writer single eliminates that complexity.

## §3 What does NOT need reverse-sync

| Artifact | Direction | Reason |
|---|---|---|
| `state.json` | FT2 → fitme-story (forward only) | FT2 is canonical; fitme-story renders from `src/data/features/`. |
| `<feature>.log.json` | FT2 → fitme-story (forward only) | Tier 2.2 logs are written by `scripts/append-feature-log.py` from FT2 cwd. |
| `case studies (.md)` | FT2 → fitme-story (forward only) | FT2 source case studies; fitme-story showcase MDX (`.mdx`) is a separate dual-outlet artifact (per `docs/case-studies/dual-outlet-pattern.md`). |
| `gate-coverage.jsonl` | per-repo, no sync | Each repo's hook writes its own. Control-room reads both at build time (Phase C-2 task — see §5). |
| `_session-*.events.jsonl` | per-repo, no sync | Mechanism C session attribution is per-cwd; not synced. |
| `documentation-debt.json` | FT2 → fitme-story (forward only) | Same canonical-source rule. |
| `measurement-adoption-history.json` | FT2 → fitme-story (forward only) | Same. |

## §4 Forward sync mechanism (existing)

The forward sync already exists in fitme-story at [`scripts/sync-from-fittracker2.ts`](https://github.com/Regevba/fitme-story/blob/main/scripts/sync-from-fittracker2.ts) (342 lines, Pattern 4.b from research.md).

**It runs at:**
- `npm run prebuild` (local dev)
- Vercel `buildCommand` (production)

**It currently syncs:**
- `.claude/shared/*.json` → `src/data/shared/*.json`
- `.claude/features/<name>/state.json` → `src/data/features/<name>.json`
- `docs/**` (case studies + dev guide + glossary source) → `src/data/docs/**`
- `.claude/integrity/snapshots/*.json` → `src/data/integrity/snapshots/*.json`

**It misses (Phase C-1 task):**
- `.claude/logs/<feature>.log.json` — Tier 2.2 contemporaneous event streams. The control-room currently has no view of per-feature event history; adding sync unlocks future "feature event timeline" UI.

## §5 What Phase C ships

### C-1 (this PR) — Forward sync extension

Extend `sync-from-fittracker2.ts` to also sync `.claude/logs/*.log.json` files into `src/data/logs/<name>.log.json`. Same idempotent pattern as the existing per-feature state.json sync.

### C-2 (this PR) — Documentation

This spec doc (`docs/superpowers/specs/2026-05-09-cross-repo-state-sync.md`).

### C-3 (this PR) — fitme-story `.claude/README.md` clarification

Update fitme-story's `.claude/README.md` to reference this contract: fitme-story `.claude/features/` directory is for transient/local work only; the canonical record is always in FT2.

### C-4 (deferred) — Cross-repo gate-coverage aggregator

The control-room currently reads only FT2's `gate-coverage.jsonl`. To show fitme-story's gate fires too, the control-room needs a cross-repo aggregator that reads:
- `FT2/.claude/logs/gate-coverage.jsonl` (synced via existing forward sync — needs to be added)
- `fitme-story/.claude/logs/gate-coverage.jsonl` (local, no sync needed)

Defer to a follow-up since fitme-story's gate-coverage.jsonl is empty today (no fitme-story commits have hit gates yet — Phase B was the first port).

### C-5 (deferred) — Reverse-sync alarm

If fitme-story ever has its own `.claude/features/<name>/state.json` (a fitme-story-native feature), the contract says it lives in FT2 instead. To enforce the contract, add a fitme-story pre-commit gate that rejects commits introducing fitme-story-native state.json files. Defer until the situation arises.

## §6 What this resolves

The 2026-05-09 user directive said: "**every feature on fitme story must invoke full framework from now on and obey all rules to data between main repos are synced**."

| Clause | Resolved by |
|---|---|
| "every feature on fitme story must invoke full framework" | **Phase B** (fitme-story PR #72) — gate stack ported to fitme-story; pre-commit hook + integrity workflow + .claude/ seeds in place. |
| "obey all rules" | **Phase B** (gates fire on fitme-story commits exactly as on FT2). |
| "data between main repos are synced" | **Phase C** (this spec) — explicit sync contract documented; forward sync extended to include logs. |

## §7 What this does NOT resolve (Phase D candidates)

- **fitme-story-native features.** If a feature lives entirely in fitme-story (e.g., a public-site-only enhancement that never touches FT2 code), where does its state.json go? Current contract: FT2. But this might feel awkward. **Phase D candidate:** evaluate whether fitme-story should own state.json for fitme-story-only features, with a sync-back to FT2 for unified reporting.
- **Real-time bi-directional state.** The existing sync runs at build time. If both repos are active simultaneously, fitme-story's view can be stale by minutes. Currently acceptable; **Phase D candidate** if it becomes an issue.
- **Cross-repo PR-cite resolution.** The `BROKEN_PR_CITATION` gate's `gh pr list` cache only sees the current repo's PRs. Cross-repo cites use `repo#N` syntax (per the case-study-preflight script's regex avoidance). **Phase D candidate:** unified cross-repo PR cache.

## §8 Cross-references

- v7.8.2 cross-repo asymmetry spec (now superseded by Phase B + this Phase C): [`2026-05-08-cross-repo-gate-asymmetry.md`](2026-05-08-cross-repo-gate-asymmetry.md) §8 reversal addendum
- Dual-outlet pattern (FT2 case study ↔ fitme-story showcase MDX): [`../../case-studies/dual-outlet-pattern.md`](../../case-studies/dual-outlet-pattern.md)
- fitme-story sync script: [`fitme-story/scripts/sync-from-fittracker2.ts`](https://github.com/Regevba/fitme-story/blob/main/scripts/sync-from-fittracker2.ts)
- fitme-story framework port: [`fitme-story/.claude/README.md`](https://github.com/Regevba/fitme-story/blob/main/.claude/README.md)

## §9 Disposition record

| Aspect | Decision |
|---|---|
| **Canonical state location** | FT2 (`.claude/features/<name>/state.json` + `.claude/logs/<feature>.log.json`) |
| **Forward sync direction** | FT2 → fitme-story (read-only consumer) |
| **Reverse sync** | NONE today; per-repo `gate-coverage.jsonl` not synced (control-room reads both) |
| **Phase C scope** | Spec doc + extend forward sync to include logs + clarify fitme-story `.claude/README.md` |
| **Phase D candidates** | fitme-story-native state.json + real-time sync + cross-repo PR cache |
