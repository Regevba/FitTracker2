# Cross-Repo State Sync — Implementation Design (v7.8.3 Release Umbrella)

**Created:** 2026-05-11
**Feature name:** `cross-repo-state-sync-impl`
**Framework version (immutable on this feature's state.json):** `v7.8.3`
**Predecessors:**
- [`2026-05-09-cross-repo-state-sync.md`](2026-05-09-cross-repo-state-sync.md) — Phase C contract (FT2-canonical-writer / fitme-story-canonical-reader); Phase D candidates D-1/D-2/D-3 surfaced
- [`2026-05-08-cross-repo-gate-asymmetry.md`](2026-05-08-cross-repo-gate-asymmetry.md) §8 reversal addendum — F7/F8 closed via Phase B port; v7.8.2 disposition stands for `_session-*.events.jsonl`
- [`2026-05-02-framework-v7-8-and-v7-9-bridge-design.md`](2026-05-02-framework-v7-8-and-v7-9-bridge-design.md) — v7.8 Mechanisms A-F; V1 GATE_COVERAGE_ZERO meta-check planned for v7.9
- [`2026-05-07-branch-isolation-out-of-scope.md`](2026-05-07-branch-isolation-out-of-scope.md) — 7 v8.0+ candidates (out of scope here)
- fitme-story PR #72 (Phase B framework port, 2026-05-09)
- FT2 PR #271 + fitme-story PR #74 (Phase C-1/C-2/C-3 ship, 2026-05-10)

**Brainstorm artifact:** `/Users/regevbarak/.claude/projects/-Volumes-DevSSD-FitTracker2/memory/project_phase2bis_brainstorm_paused_2026_05_11.md` (HADF Phase 2-bis brainstorm, paused awaiting this Feature's completion) and `/Users/regevbarak/.claude/projects/-Volumes-DevSSD-FitTracker2/memory/project_phase_c_brainstorm_2026_05_11.md` (this Feature's brainstorm 6 design decisions).

---

## §1 Overview + Scope

This Feature implements all deferred Phase C and Phase D items from the 2026-05-09 cross-repo state-sync spec, bundled with two additional v7.9 candidates (V2 + V9) that extend the v7.5-v7.8.2 framework hardening line into a unified v7.8.3 release. It is also the gate that unblocks HADF Phase 2-bis: that campaign cannot start until every framework deliverable below ships AND each phase's calibration target is met.

### §1.1 Why one umbrella Feature (not two parallel tracks)

The original 2026-05-11 sequencing decision (Q1) chose to land cross-repo state sync BEFORE HADF Phase 2-bis. The cross-reference audit then surfaced two specific v7.9 candidates (V2 Mechanism C writer-path enforcement, V9 Mechanism E driver extension to feature logs) that match the same theme — cross-repo / cross-tool integrity hardening — and naturally bundle into the same release. A single PM-workflow Feature with a 5-phase rollout produces one coordinated PR sequence, one case study, and one validated framework state instead of two parallel tracks competing for the shared touch-surface (`scripts/`, `.claude/shared/`, `.claude/features/*/state.json`, `.githooks/`).

### §1.2 Scope inclusions (5 phases)

| Phase | Deliverable | Risk |
|---|---|---|
| **0** | v7.8.3 framework gate promotions: V2 (`CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT` enforced) + V9 (Mechanism E driver covers `<feature>.log.json`) + snapshot protocol script | LOW — both gate promotions have calibration data; snapshot is operator tooling |
| **1** | Telemetry foundations: D-3 unified cross-repo PR cite cache + C-4 control-room cross-repo gate-coverage aggregator + forward-sync extension for `gate-coverage-ft2.jsonl` | LOW — read-only telemetry |
| **2** | `state_owner` schema marker + 47-feature backfill + morphed C-5 location-mismatch validator | MED — schema change with backfill; integrity-cycle regression risk |
| **3** | D-1 reverse-sync infrastructure: GitHub Action opens auto-PR against FT2 when fitme-story-native state.json changes | MED-HIGH — new infra; reverse-sync conflict-with-forward-sync risk |
| **4** | Cutover ceremony: pick first fitme-story-native feature, mark, round-trip end-to-end, document case study + showcase MDX | LOW — validation only |

### §1.3 Scope exclusions

Explicit non-scope items are listed exhaustively in §8. Notable: HADF Phase 2-bis itself is OUT (its spec lives separately and is gated on this Feature's completion), real-time bi-directional sync is DEFERRED, cross-org PR cite validation is DEFERRED, V1 `GATE_COVERAGE_ZERO` meta-check ships as a separate v7.9 promotion.

### §1.4 Primary success metrics

1. 100% of state.json files in either repo have `state_owner` field within 14 days of Phase 2 ship
2. V2 Mechanism C writer-path enforcement firing on at least one production commit before HADF Phase 2-bis Sub-exp 1 launch
3. All 4 framework calibration targets (per §3.5) achieved before HADF Phase 2-bis Sub-exp 1 launch
4. Phase 4 cutover round-trip succeeds end-to-end (the cutover IS the framework certification)

### §1.5 Kill criteria

- If reverse-sync PRs (Phase 3) create a gate-firing storm (>10 false-positive failures in first week of Phase 3 production) → halt Phase 3, fall back to manual sync-back
- If `state_owner` backfill (Phase 2) triggers integrity-cycle regression on >5 features within 72h post-merge → roll back schema change
- If V2 enforcement (Phase 0) fires on >3 already-shipped features (false positives) → revert V2 to advisory and add 7-day calibration period
- HADF Phase 2-bis Sub-exp 1 launch is BLOCKED until all 5 phases ship AND each phase's calibration targets are met. If calibration targets aren't met within 21 days of Phase 4 cutover, escalate the calibration gap to a separate work item before HADF starts.

---

## §2 Architecture + data flow diagram

### §2.1 Component layout (what lives where, who writes it, who reads it)

```
FitTracker2 (canonical writer for FT2-owned + cross-repo features)
├── .claude/features/<name>/state.json          [state_owner: "ft2" — written here, mirrored to fitme-story]
├── .claude/logs/<feature>.log.json             [Tier 2.2 stream — written here, mirrored to fitme-story]
├── .claude/shared/*.json                       [framework ledgers — written here, mirrored to fitme-story]
│   ├── measurement-adoption-history.json       [Mechanism E driver: union-dedup]
│   ├── documentation-debt.json                 [Mechanism E driver: union-dedup]
│   └── gate-coverage.jsonl                     [per-repo — NOT synced bidirectionally; control-room reads both]
├── docs/case-studies/*.md                      [canonical source — written here, mirrored to fitme-story]
├── .githooks/pre-commit                        [V2 enforces CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT]
└── scripts/
    ├── observe-cache-hit.py                    [writer-path source for Mechanism C — V2 enforces output validity]
    ├── merge-driver-dedup.py                   [V9 extends to cover .claude/logs/*.log.json]
    ├── unified-pr-cite-cache.py                [NEW Phase 1 — bidirectional cross-repo gh cache]
    ├── snapshot-phase-completion.sh            [NEW Phase 0 — operator snapshot tooling]
    ├── refresh-pr-cache.py                     [NEW Phase 1 — populates .cache/gh-pr-cache.json]
    ├── backfill-state-owner.py                 [NEW Phase 2 — one-shot mechanical backfill]
    └── check-{state-schema,case-study-preflight}.py
                                                [V2 + D-3 + morphed C-5 + state_owner gates]

fitme-story (canonical reader for FT2-owned; canonical writer for fitme-story-native)
├── src/data/{features,logs,shared,integrity,docs}/  [synced mirrors of FT2 — read-only]
├── content/04-case-studies/*.mdx               [showcase — NOT mirror; dual-outlet pattern]
├── .claude/features/<fs-native>/state.json     [NEW Phase 4 onward — state_owner: "fitme-story"]
├── .claude/logs/<fs-native>.log.json           [NEW Phase 4 onward]
├── .claude/logs/gate-coverage.jsonl            [per-repo — accumulates locally; empty today, populated as fitme-story commits hit gates]
├── .githooks/pre-commit                        [Phase B port + V2 enforce + morphed C-5]
├── src/lib/control-room/gate-coverage-aggregator.ts  [NEW Phase 1 — reads both repos' gate-coverage]
└── scripts/sync-from-fittracker2.ts            [forward sync — prebuild + Vercel build]

GitHub Actions (cross-repo orchestration)
├── .github/workflows/pr-integrity-check.yml    [v7.6 per-PR review bot — already shipped]
├── .github/workflows/framework-status-weekly.yml  [v7.6 weekly cron — already shipped]
└── .github/workflows/reverse-sync-fitme-story-to-ft2.yml  [NEW Phase 3]
```

### §2.2 Data flow diagram

```
                        ┌─────────────────────────────────────────────┐
                        │  FitTracker2 (canonical writer)             │
                        │                                             │
                        │  /pm-workflow + manual edits write here.    │
                        │  All state.json with state_owner="ft2"      │
                        │  AND all cross-repo features live here.     │
                        └────────────────┬──────────┬─────────────────┘
                                         │          │
                                         │          │ sync-from-fittracker2.ts
                          gate-coverage  │          │ (forward, build-time)
                          .jsonl writes  │          │
                          locally,       │          ▼
                          control-room   │   ┌────────────────────────────────────────┐
                          aggregator     │   │  fitme-story (reader + native writer)  │
                          reads BOTH     │   │                                        │
                          repos at       │   │  src/data/* mirrors FT2 (read-only).   │
                          build time     │   │  Native features: state_owner=         │
                          (NEW Phase 1)  │   │  "fitme-story" → reverse-sync to FT2.  │
                                         │   └─────────────┬──────────────────────────┘
                                         │                 │
                                         │                 │ reverse-sync GH Action
                                         │                 │ (NEW Phase 3 — opens PR
                                         │                 │  against FT2 main)
                                         │                 │
                                         │                 ▼
                                         │   ┌────────────────────────────────────────┐
                                         │   │  FT2 PR review (full gate stack)       │
                                         │   │  + manual operator merge → loops top   │
                                         │   └────────────────────────────────────────┘
                                         │
                                         ▼
                        ┌─────────────────────────────────────────────┐
                        │  control-room cross-repo aggregator          │
                        │  (reads FT2 + fitme-story gate-coverage,     │
                        │   PR-cite cache; renders /control-room/*)    │
                        │  (NEW Phase 1)                               │
                        └─────────────────────────────────────────────┘
```

### §2.3 Per-commit gate firing sequence

**FT2 commit (canonical-writer path):**
1. Pre-commit hook → `check-state-schema.py` runs ~15 mechanical gates including NEW V2 (`CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT` enforced)
2. Pre-commit hook → `check-case-study-preflight.py` runs case-study gates
   - **NEW Phase 1:** `BROKEN_PR_CITATION` resolves both `PR #N` (FT2) AND `[fitme-story#N]` / URL form via unified PR cache
   - **NEW Phase 2:** `STATE_OWNER_LOCATION_MISMATCH` — FT2 commit modifying `state_owner: "fitme-story"` (without sync_origin marker) → reject
3. Mechanism A → `gate-coverage.jsonl` appended for every gate fire (existing behavior)
4. Commit succeeds
5. (Asynchronously) Push triggers fitme-story Vercel rebuild → `sync-from-fittracker2.ts` mirrors changed FT2 artifacts into `fitme-story/src/data/`

**fitme-story commit (canonical-reader path + occasional native writer):**
1. Pre-commit hook (Phase B port) runs the same gate stack including V2
2. **NEW Phase 2:** `STATE_OWNER_LOCATION_MISMATCH` — fitme-story commit modifying `state_owner: "ft2"` file → reject (must come from FT2)
3. fitme-story's local `.claude/logs/gate-coverage.jsonl` appended
4. Commit succeeds
5. (If fitme-story-native state.json modified) Push to fitme-story `main` triggers reverse-sync GitHub Action
6. Action opens PR against FT2 with synced state.json under `.claude/features/<fs-native>/state.json` (carries `state_owner_sync_origin: "fitme-story-reverse"` marker)
7. PR runs through full FT2 gate stack (Mechanism A, integrity gates, morphed C-5 — exempted via sync_origin marker) before manual merge

### §2.4 Sync trigger summary

| Direction | Mechanism | Trigger | Latency | Phase |
|---|---|---|---|---|
| FT2 → fitme-story (state, logs, shared, docs) | `sync-from-fittracker2.ts` prebuild | `npm run prebuild` (local) | Immediate | Pre-Phase-C |
| FT2 → fitme-story (same artifacts) | `sync-from-fittracker2.ts` Vercel build | `buildCommand` (prod) | ~minutes | Pre-Phase-C |
| FT2 → fitme-story (`<feature>.log.json`) | sync extension | Same as above | Same | C-1 (shipped 2026-05-10) |
| FT2 → fitme-story (`gate-coverage-ft2.jsonl`) | sync extension | Same as above | Same | NEW Phase 1 |
| fitme-story → FT2 (native state.json + sync_origin marker) | GitHub Action `reverse-sync-fitme-story-to-ft2.yml` | Push to fitme-story `main` modifying `.claude/features/**/state.json` | ~minutes (Action queue) + manual operator merge | NEW Phase 3 |
| `gate-coverage.jsonl` (per-repo, NO sync) | Pre-commit hook fire | Per commit | Immediate (read by aggregator at build time) | NEW Phase 1 (aggregator only; no sync) |
| Control-room aggregator | Build-time computation + hourly cron | Per Vercel deploy / hourly | ~minutes | NEW Phase 1 |
| `<feature>.log.json` merge-driver auto-resolution | git merge | Per merge with conflict | Immediate | NEW Phase 0 (V9) |

### §2.5 Deliberate non-features

- No real-time bi-directional sync (PR-based with manual merge IS the safety net)
- No `<feature>.log.json` reverse-sync for fitme-story-native features (logs stay in fitme-story)
- No cross-repo `gate-coverage.jsonl` sync (per-repo; aggregator reads both)
- No fitme-story write of `state_owner: "ft2"` files (morphed C-5 enforces this)
- No automatic rollback of failed reverse-sync PRs (operator manual triage per `feedback_no_auto_merge_without_approval.md`)

---

## §3 Schema + state_owner field + 47-feature backfill

### §3.1 Field shape

Simple string enum, top-level position (immediately after `name`, before `framework_version`):

```json
{
  "name": "feature-name",
  "state_owner": "ft2",
  "framework_version": "v7.8.3",
  "current_phase": "...",
  ...
}
```

Valid values: `{"ft2", "fitme-story"}`. Required from Phase 2 onward.

### §3.2 Backfill heuristic

`state_owner` reflects **where the state.json file LIVES**, not where the feature's code lives. Empirical test: every existing FT2 feature lives at `FT2/.claude/features/<name>/state.json`. Therefore all 47 backfill mechanically to `state_owner: "ft2"`. Cross-repo features (UCC, fitme-story-public-enhancements, etc.) are no exception — their state lives in FT2.

The ONLY way a feature gets `"fitme-story"` is if its state.json lives at `fitme-story/.claude/features/<name>/state.json`. Today: zero such features. Phase 4 cutover creates the first one.

### §3.3 Backfill mechanics

`scripts/backfill-state-owner.py` runs once during Phase 2:

```python
import json, glob, sys

backfilled = []
already_set = []
for path in sorted(glob.glob(".claude/features/*/state.json")):
    with open(path) as f:
        state = json.load(f)
    if "state_owner" in state:
        already_set.append(path)
        continue
    new_state = {}
    for k, v in state.items():
        new_state[k] = v
        if k == "name":
            new_state["state_owner"] = "ft2"
    if "name" not in state:  # defensive: append if no name field
        new_state["state_owner"] = "ft2"
    with open(path, "w") as f:
        json.dump(new_state, f, indent=2)
        f.write("\n")
    backfilled.append(path)

print(f"Backfilled {len(backfilled)}; {len(already_set)} already had state_owner")
sys.exit(0 if backfilled or already_set else 1)
```

**Commit strategy:** one-shot PR, single commit. Uniform mechanical diff (47× one-line addition) is the cleanest signal.

### §3.4 New gates

Added to `scripts/check-state-schema.py`:

```python
VALID_STATE_OWNERS = {"ft2", "fitme-story"}

def check_state_owner(state, file_path):
    """Phase 2 forward: required field, valid enum value."""
    state_owner = state.get("state_owner")
    if state_owner is None:
        return Finding("FAIL", "STATE_OWNER_MISSING", "state.json missing required state_owner field")
    if state_owner not in VALID_STATE_OWNERS:
        return Finding("FAIL", "STATE_OWNER_INVALID",
                       f"state_owner='{state_owner}' not in {VALID_STATE_OWNERS}")
    return None

def check_state_owner_location_match(state, file_path):
    """Morphed C-5: file location must match state_owner; sync mirrors are exempt."""
    state_owner = state.get("state_owner")
    sync_origin = state.get("state_owner_sync_origin")
    if state_owner is None or state_owner not in VALID_STATE_OWNERS:
        return None  # caught by check_state_owner
    if sync_origin and sync_origin.endswith("-reverse"):
        return None  # sync mirror; exempted
    abs_path = os.path.abspath(file_path)
    is_ft2_path = "/FitTracker2/" in abs_path or abs_path.startswith("/Volumes/DevSSD/FitTracker2/")
    is_fs_path = "/fitme-story/" in abs_path
    if state_owner == "ft2" and is_fs_path:
        return Finding("FAIL", "STATE_OWNER_LOCATION_MISMATCH",
                       "state_owner='ft2' but file at fitme-story path. "
                       "Commit to FT2 instead, OR update state_owner='fitme-story' "
                       "if migrating canonical home.")
    if state_owner == "fitme-story" and is_ft2_path:
        return Finding("FAIL", "STATE_OWNER_LOCATION_MISMATCH",
                       "state_owner='fitme-story' but file at FT2 path. "
                       "Commit to fitme-story instead, OR update state_owner='ft2' "
                       "if migrating canonical home.")
    return None
```

### §3.5 HADF Phase 2-bis gating + calibration data acquisition plan

#### §3.5.1 The principle

Phase 2's contamination root cause was launching a 15-day measurement campaign on framework infrastructure that hadn't been exercised in real-world conditions. Phase 2-bis must NOT repeat this. Each new framework gate / driver / sync mechanism shipped in this Feature must accumulate proof-of-real-world-correctness from natural feature work BEFORE HADF Sub-exp 1 fires.

#### §3.5.2 Per-phase calibration targets

| Phase | New mechanism | Calibration target | Calibration source |
|---|---|---|---|
| 0 | V2 Mechanism C writer-path enforced | ≥1 production fire without false positive (proves writer-path wires up); soft target ≥10 fires across ≥5 features | Natural state.json mutations from in-flight features (`ios-ui-audit-p1-burndown`, `fitme-story-public-enhancements`, `ios-code-connect`, this Feature itself) |
| 0 | V9 Mechanism E driver extension | Driver auto-resolves ≥1 real merge conflict on `<feature>.log.json` | Natural; if no conflict in 7 days, manufacture synthetic test |
| 1 | D-3 unified PR cite cache | (a) Retroactive: 35/35 existing cross-repo cites validate; (b) Forward: ≥3 new case study commits with cross-repo cites pass the gate | (a) mechanical (run cache build over existing corpus); (b) natural case study writing |
| 1 | C-4 control-room aggregator | Aggregator renders correct counts from both repos' gate-coverage.jsonl | Visual confirmation in `/control-room/framework` |
| 2 | state_owner schema + backfill | 47/47 backfill success + 0 integrity-cycle regressions in 72h | Mechanical (the backfill PR itself is the calibration) |
| 2 | Morphed C-5 location-mismatch | Gate catches deliberate mismatch | Synthetic test — explicit pre-flight check |
| 3 | D-1 reverse-sync GitHub Action | Workflow YAML lints; first real trigger opens valid PR | NO calibration possible until Phase 4 cutover |
| 4 | Cutover ceremony | First fitme-story-native feature round-trips end-to-end | THE cutover IS the calibration |

#### §3.5.3 Estimated calibration windows

| Phase | Ship date estimate | Calibration window | Calibration end estimate |
|---|---|---|---|
| 0 | Day 1-2 | 5-7 days natural feature work | Day 9 |
| 1 | Day 2-3 | 3-5 days (retroactive validation mechanical) | Day 8 |
| 2 | Day 4-5 | 3-4 days (backfill mechanical + synthetic test) | Day 9 |
| 3 | Day 6-7 | 0 days (deferred to Phase 4) | Day 7 |
| 4 cutover | Day 8-9 | 1-3 days end-to-end verification | Day 12 |

**Total framework + calibration: ~12 days. HADF Phase 2-bis Sub-exp 1 earliest start: 2026-05-23.**

#### §3.5.4 Failure modes + escalation

| Failure | Escalation |
|---|---|
| V2 doesn't fire even once in 7 days | Manufacture synthetic state.json mutation that should trigger V2; verify gate fires; only then declare calibration met |
| D-3 cache build fails on >0 of the 35 retroactive cites | Triage failing cites; either fix cache routing OR mark specific cites as exempt; do NOT lower target |
| Backfill triggers integrity-cycle regression on >5 features | Per existing kill criterion in §1, roll back schema change + re-design |
| Phase 4 cutover round-trip fails | HADF blocked indefinitely; reverse-sync infrastructure is the linchpin |
| Calibration window extends past 21 days post-Phase-4 cutover | Spawn dedicated work item to investigate before HADF starts; document in `framework-calibration-failure` memory entry |

---

## §4 Sync mechanisms

### §4.1 Forward sync — UNCHANGED behavior + ONE Phase 1 extension

The existing `fitme-story/scripts/sync-from-fittracker2.ts` (342 lines) is canonical. Behavior unchanged for all currently-synced artifacts:

- `.claude/shared/*.json` → `src/data/shared/*.json` (already shipped pre-Phase-C)
- `.claude/features/<name>/state.json` → `src/data/features/<name>.json` (already shipped pre-Phase-C)
- `.claude/integrity/snapshots/*.json` → `src/data/integrity/snapshots/*.json` (already shipped pre-Phase-C)
- `docs/**` → `src/data/docs/**` (already shipped pre-Phase-C)
- `.claude/logs/<feature>.log.json` → `src/data/logs/<name>.log.json` (C-1 shipped 2026-05-10)

**ONE Phase 1 extension (NEW):**
- `FT2/.claude/logs/gate-coverage.jsonl` → `fitme-story/src/data/integrity/gate-coverage-ft2.jsonl`

The destination filename is suffixed `-ft2` to disambiguate from fitme-story's own `gate-coverage.jsonl` at `fitme-story/.claude/logs/gate-coverage.jsonl` (read directly, no sync).

**Trigger points (unchanged):** `npm run prebuild` (local) + Vercel `buildCommand` (prod).

### §4.2 Reverse sync — NEW Phase 3 GitHub Action

**File:** `.github/workflows/reverse-sync-fitme-story-to-ft2.yml` (lives in fitme-story repo)

**Trigger:** `push` to fitme-story `main` where any file matches `.claude/features/**/state.json`.

**Job sequence:**
1. **Detect changed fitme-story-native state.json files.** `git diff` between push HEAD and previous main; filter for `.claude/features/<name>/state.json`; for each, parse JSON and validate `state_owner == "fitme-story"`. Files where `state_owner != "fitme-story"` are skipped (would never legitimately exist; if they do, they're a morphed-C-5 false negative — log warning).
2. **Compute mirror destination.** Mirror to `FT2/.claude/features/<name>/state.json` with two added fields:
   ```json
   {
     "state_owner": "fitme-story",
     "state_owner_sync_origin": "fitme-story-reverse",
     "state_owner_sync_origin_commit": "<fitme-story-commit-sha>",
     "state_owner_sync_origin_pr_url": "<github-pr-url-of-this-reverse-sync-pr>",
     ... (rest of state.json unchanged)
   }
   ```
3. **Open a PR against FT2 main** via `gh pr create` (requires `FT2_REPO_TOKEN` secret with write access to FT2). Branch: `reverse-sync/from-fitme-story/<short-sha>`.
4. **PR runs through full FT2 gate stack.** morphed C-5 sees `state_owner: "fitme-story"` + path is FT2, but `state_owner_sync_origin` marker exempts the file.
5. **Manual operator merge.** No auto-merge per `feedback_no_auto_merge_without_approval.md`.

**Idempotency:** if same fitme-story commit pushed twice, Action checks for existing open PR with same source SHA and updates instead of duplicating.

**Failure modes:**
| Failure | Handling |
|---|---|
| `FT2_REPO_TOKEN` missing/expired | Action fails with clear error; operator regenerates; no records lost |
| FT2 main diverged | Action attempts fresh branch from current FT2 main; if conflicts persist, marks PR draft |
| Gates reject PR | PR stays open + failing; operator triages |

### §4.3 Telemetry aggregator (C-4)

Two `gate-coverage.jsonl` sources (per-repo, NEVER synced bidirectionally):
| Source | Read path | Today's volume | Growth |
|---|---|---|---|
| FT2 commits | `fitme-story/src/data/integrity/gate-coverage-ft2.jsonl` (Phase 1 sync extension) | 1734 lines | Fast |
| fitme-story commits | `fitme-story/.claude/logs/gate-coverage.jsonl` (read directly) | 0 lines today | Slow today; grows post-Phase-B port |

**Aggregator:** new `fitme-story/src/lib/control-room/gate-coverage-aggregator.ts` reads both at build time, parses each line as JSON event, tags with `source_repo`, combines time-sorted, renders in `/control-room/framework` with per-source filter chips + aggregate counts + per-gate breakdown. Updates per Vercel deploy + hourly cron.

### §4.4 The `state_owner_sync_origin` exemption marker

This is the contract that lets D-1 reverse-sync coexist with morphed C-5. The marker is set ONLY by the D-1 GitHub Action's deterministic mirror writes. A human commit would have no `state_owner_sync_origin` field → location-mismatch fires → reject. The marker also creates audit traceability via the `_commit` and `_pr_url` sub-fields. The marker stays on the FT2 mirror permanently; if the feature is later migrated back to FT2 ownership, the marker is dropped in the same commit that sets the new ownership.

---

## §5 Unified PR cite cache (D-3)

### §5.1 What's broken today

`scripts/check-case-study-preflight.py:74-76` has two bugs:
- **B1 Silent skip:** regex matches `PR #N` and `github.com/X/Y/pull/N` URL form, but `[fitme-story#42]` syntax doesn't match either alternation. Cross-repo cites pass without validation. **Volume: 35 `fitme-story#N` cites in `docs/case-studies/`.**
- **B2 URL-form mis-routes:** when `github.com/Regevba/fitme-story/pull/42` is found, gate validates against LOCAL FT2-only `gh pr list` cache → false positive `BROKEN_PR_CITATION`.

D-3 closes both in one shot.

### §5.2 Cache architecture

Single file at `.cache/gh-pr-cache.json` (FT2-resident; gitignored; rebuilt on demand).

```json
{
  "schema_version": 1,
  "last_refreshed_at": "2026-05-11T09:30:00Z",
  "repos": {
    "Regevba/FitTracker2": {
      "open":   [{"number": 290, "title": "...", "state": "OPEN"}, ...],
      "merged": [...],
      "closed": [...]
    },
    "Regevba/fitme-story": {
      "open": [...], "merged": [...], "closed": [...]
    }
  }
}
```

**Refresh script:** new `scripts/refresh-pr-cache.py` runs `gh pr list --repo X --state all --json number,title,state --limit 500` for each repo in `REPOS = ["Regevba/FitTracker2", "Regevba/fitme-story"]`. **TTL:** 5 minutes. **Triggers:** lazy refresh on pre-commit hook if cache stale + `make refresh-pr-cache` (manual) + per-PR CI.

### §5.3 Updated regex + REPO_MAP

Replaces lines 74-76 of `check-case-study-preflight.py`:

```python
_PR_CITATION_PAT = re.compile(
    r"(?:PR\s*#(\d+))"                              # group 1: FT2 default
    r"|(?:\[?([\w-]+)\s*#(\d+)\]?)"                 # groups 2+3: cross-repo short form
    r"|(?:github\.com/([\w-]+)/([\w-]+)/pull/(\d+))"  # groups 4+5+6: URL form
)
REPO_MAP = {
    "fitme-story": "Regevba/fitme-story",
    "FitTracker2": "Regevba/FitTracker2",
    "ft2": "Regevba/FitTracker2",
}
```

### §5.4 Cache routing logic

```python
def resolve_pr_cite(match, cache):
    if match.group(1):
        repo = "Regevba/FitTracker2"
        pr_num = int(match.group(1))
    elif match.group(2):
        repo_short = match.group(2)
        repo = REPO_MAP.get(repo_short)
        if repo is None:
            return Finding("FAIL", "BROKEN_PR_CITATION",
                f"unknown repo short name '{repo_short}'; valid: {sorted(REPO_MAP.keys())}")
        pr_num = int(match.group(3))
    elif match.group(4):
        repo = f"{match.group(4)}/{match.group(5)}"
        pr_num = int(match.group(6))

    if repo not in cache["repos"]:
        return Finding("FAIL", "BROKEN_PR_CITATION",
            f"no cache for repo '{repo}'; refresh cache or add to REPO_MAP")
    repo_cache = cache["repos"][repo]
    all_prs = repo_cache.get("open", []) + repo_cache.get("merged", []) + repo_cache.get("closed", [])
    if not any(pr["number"] == pr_num for pr in all_prs):
        return Finding("FAIL", "BROKEN_PR_CITATION",
            f"PR #{pr_num} not found in {repo} (cache last refreshed {cache['last_refreshed_at']})")
    return None
```

### §5.5 Retroactive validation pass (Phase 1 calibration target)

`make validate-existing-cites` runs `check-case-study-preflight.py` against every case study under `docs/case-studies/` using the new cache. **Expected:** 35/35 existing cross-repo cites validate cleanly + 0 false positives on existing FT2 cites. Failures indicate a real bug (typo'd PR number that the original silent-skip masked).

---

## §6 5-phase rollout + per-phase success criteria + rollback

### §6.1 Phase 0 — v7.8.3 framework gate promotions + snapshot protocol

**Deliverables (single PR):**
- V2: promote `CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT` advisory → enforced
- V9: extend `merge-driver-dedup.py` to handle `.claude/logs/<feature>.log.json` + update `.gitattributes`
- NEW `scripts/snapshot-phase-completion.sh` + `make snapshot-phase` Makefile target (per §10)
- Bump CLAUDE.md framework version reference to v7.8.3

**Branch:** `feat/cross-repo-state-sync-phase-0` (per OQ-2: per-phase branches).
**Immediate success criteria:** `make verify-local` passes; Mechanism D header self-audit passes; `make integrity-check` reports 0 hard findings.
**Calibration targets:** V2 ≥1 production fire (soft ≥10 across ≥5 features); V9 ≥1 real merge-conflict resolved (manufacture synthetic if no natural conflict in 7 days).
**Rollback:** V2 false positives >3 in 24h → revert to advisory in 5-line hotfix; V9 corruption → revert `.gitattributes`, restore log file from git history.
**Wall-clock:** ship Day 1-2; calibration Days 2-9.
**Blocks:** Phases 1-4.

### §6.2 Phase 1 — Telemetry foundations (D-3 + C-4 + forward-sync extension)

**Deliverables (two PRs — one FT2, one fitme-story):**
- D-3 (FT2): `scripts/refresh-pr-cache.py` + `.cache/gh-pr-cache.json` (gitignored) + `Makefile` `refresh-pr-cache` target + updated regex/REPO_MAP/`resolve_pr_cite` + retroactive validation script + `make validate-existing-cites` target
- C-4 (fitme-story): forward-sync extension for `gate-coverage-ft2.jsonl` + `src/lib/control-room/gate-coverage-aggregator.ts` + `/control-room/framework` page extension

**Branches:** `feat/cross-repo-state-sync-phase-1` (FT2) + `feat/cross-repo-state-sync-phase-1` (fitme-story).
**Immediate success:** both PRs merge; `make validate-existing-cites` passes 35/35 retroactive; control-room renders aggregated count visually correct.
**Calibration:** D-3 35/35 retroactive + ≥3 forward; C-4 0 build errors + visually correct.
**Rollback:** D-3 regex regression → revert; C-4 build error → revert aggregator + remove from page.
**Wall-clock:** ship Day 2-3; calibration Days 3-8.
**Blocks:** Phase 4 (cutover case study cites cross-repo PRs); HADF Phase 2-bis case studies.

### §6.3 Phase 2 — Schema + backfill + morphed C-5

**Deliverables (single FT2 PR):**
- New `state_owner` enum schema field
- New gates `STATE_OWNER_MISSING`, `STATE_OWNER_INVALID`, `STATE_OWNER_LOCATION_MISMATCH` in `check-state-schema.py`
- `.claude/integrity/schemas/state.schema.json` update (if exists)
- `scripts/backfill-state-owner.py` + execution producing 47-file diff
- CLAUDE.md update describing the field + morphed C-5

**Branch:** `feat/cross-repo-state-sync-phase-2`.
**Immediate success:** 47/47 backfill in single commit; PR merges; new gates fire on backfill commit (validates backward-compat); `make integrity-check` 0 hard findings.
**Calibration:** 47/47 mechanical correctness; synthetic mismatch test passes; ≥3 new features post-Phase-2 set state_owner correctly.
**Rollback:** integrity-cycle regression on >5 features → revert schema change in single commit.
**Wall-clock:** ship Day 4-5; calibration Days 5-9.
**Blocks:** Phase 3.

### §6.4 Phase 3 — D-1 reverse-sync GitHub Action

**Deliverables (single fitme-story PR):**
- `.github/workflows/reverse-sync-fitme-story-to-ft2.yml`
- Operator setup doc for `FT2_REPO_TOKEN` secret (PAT with `repo` scope, scoped to FitTracker2 only)
- `state_owner_sync_origin` exemption logic in morphed C-5 (added Phase 2; activation here)
- README addition documenting reverse-sync flow

**Branch:** `feat/cross-repo-state-sync-phase-3`.
**Immediate success:** YAML lints; operator confirms token scope; `act` dry-run produces valid PR-template payload.
**Calibration:** deferred to Phase 4 (no fitme-story-native features exist yet).
**Rollback:** disable workflow file (`.yml.disabled` rename); no state migration needed.
**Wall-clock:** ship Day 6-7; calibration deferred.
**Blocks:** Phase 4.

### §6.5 Phase 4 — Cutover ceremony

**Deliverables (cross-repo coordination):**
- Pick first fitme-story-native feature (criteria: small public-site enhancement, no FT2 surface, low-risk)
- Create `fitme-story/.claude/features/<fs-native>/state.json` with `state_owner: "fitme-story"`
- Push to fitme-story main → trigger reverse-sync Action → verify PR opens against FT2 with sync_origin marker
- Operator manually merges FT2-side PR
- Verify forward-sync mirrors back to `fitme-story/src/data/features/<fs-native>.json` on next Vercel build
- Source case study at `docs/case-studies/cross-repo-state-sync-impl-case-study.md`
- Showcase MDX at `fitme-story/content/04-case-studies/<NN>-cross-repo-state-sync-impl.mdx` (slot N matching v7.8.3 era)

**Branch:** `feat/cross-repo-state-sync-phase-4-cutover` (FT2) + corresponding fitme-story branch.
**Immediate success:** round-trip succeeds; all 5 phases verifiable; case study + showcase MDX ship through `FEATURE_CLOSURE_COMPLETENESS`.
**Calibration:** THE cutover IS the calibration. Successful round-trip = framework certified → HADF Phase 2-bis Sub-exp 1 unblocks.
**Rollback:** PR fails → leave fs-native state.json in fitme-story; manually create FT2 mirror; document workaround; investigate Action bug; re-cutover later.
**Wall-clock:** ship Day 8-9; verification Days 9-12.
**Blocks:** HADF Phase 2-bis Sub-exp 1 launch.

### §6.6 Cumulative timeline + HADF gating

| Day | Activity | Status |
|---|---|---|
| 1-2 | Phase 0 PR ships | V2 enforced + V9 driver extended + snapshot protocol live |
| 2-3 | Phase 1 PRs ship | D-3 cache + C-4 aggregator deployed |
| 3-9 | Phase 0 + 1 calibration windows | V2/V9/D-3 calibrated by Day 9 |
| 4-5 | Phase 2 PR ships | 47-feature backfill complete + morphed C-5 enforced |
| 5-9 | Phase 2 calibration | Synthetic mismatch test + ≥3 new features clean |
| 6-7 | Phase 3 PR ships | Reverse-sync workflow deployed (untriggered) |
| 8-9 | Phase 4 cutover | First round-trip succeeds; framework certified |
| 9-12 | Phase 4 case study + showcase MDX | All 5 phases shipped + closed |
| **13** | **HADF Phase 2-bis Sub-exp 1 EARLIEST start** | All framework calibration met |

**Total: ~12 days framework + calibration. HADF Phase 2-bis Sub-exp 1 earliest start: 2026-05-23.**

### §6.7 Cross-phase nuclear-option rollback

If multiple phases need simultaneous rollback OR Phase 4 round-trip fails repeatedly: revert all phase commits in reverse order (4 → 3 → 2 → 1 → 0); state.json files lose `state_owner` (acceptable; back to pre-Phase-2 state); reverse-sync workflow disabled; V2 reverts to advisory; V9 driver reverts to ledger-only; spawn new design session; HADF Phase 2-bis blocked indefinitely. Probability low — per-phase rollbacks should catch issues earlier.

---

## §7 Testing strategy

### §7.1 Per-phase test surface

| Phase | Unit tests | Integration smoke | End-to-end |
|---|---|---|---|
| 0 V2 + V9 | V2 logic on synthetic state.json + cache_hits[] inputs; V9 driver on synthetic conflicting feature logs | V2 fires on real pre-commit hook in test repo; V9 resolves real `git merge` conflict | V2 fires on actual feature work (calibration); V9 resolves at least one real conflict |
| 1 D-3 + C-4 | Regex parametrized for 3 cite forms + edges; resolve_pr_cite routing; cache refresh shape | Pre-commit hook + test case study with mix of cites; aggregator on synthetic gate-coverage pair | Retroactive 35/35 validation; control-room visual confirmation post-deploy |
| 2 Schema + morphed C-5 | All gate branches + sync_origin exemption; backfill script + idempotency | Backfill on real `.claude/features/`; pre-commit on backfill commit | Synthetic mismatch test (`cp` to wrong path → REJECT) |
| 3 D-1 GH Action | Detect-changed-files; mirror state.json marker injection | `act` local runner produces valid PR-template; `actionlint` YAML check | Phase 4 cutover IS the end-to-end test |
| 4 Cutover | N/A | N/A | Real round-trip end-to-end |

### §7.2 Test infrastructure additions

**FT2 pytest** (new `tests/framework/`): `test_state_owner_gates.py`, `test_pr_cite_cache.py`, `test_v2_writer_path.py`, `test_v9_merge_driver.py`, `test_backfill_script.py`. Run in `make verify-local` + per-PR CI.

**fitme-story Node tests** (new `tests/control-room/`): `gate-coverage-aggregator.test.ts`, `sync-extension.test.ts`.

**GitHub Action local emulation**: new `scripts/test-reverse-sync-action.sh` wrapping `act push` against test event payload + `actionlint` YAML check.

### §7.3 Test coverage philosophy

- Every new gate has unit tests for every pass/fail branch
- Integration smoke tests catch wiring regressions
- End-to-end tests ARE the calibration targets from §3.5
- No mocking of `gh pr list` in integration tests (mock-vs-prod divergence is the Phase 2 contamination class)
- No flaky tests permitted — anything intermittent is a bug, not skipped

---

## §8 Out-of-scope + locked decisions

### §8.1 Explicit non-scope items

| Item | Reason for deferral |
|---|---|
| Real-time bi-directional state (webhook-based) | PR-based reverse-sync with manual merge IS the safety net |
| Auto-categorization heuristics for `state_owner` | All 47 are ft2; `/pm-workflow` asks the question for new features |
| Migration of existing FT2 features to fitme-story-native | Phase 4 cutover picks ONE first feature; bulk migration is separate |
| `_session-*.events.jsonl` cross-repo sync | Per-cwd per v7.8.2 cross-repo asymmetry disposition |
| V1 `GATE_COVERAGE_ZERO` meta-check | Separate v7.9 promotion (calibration data already met) |
| V4 `experiment_outcome` enum on `tasks[]` | Per Q2 answer (V2 only); accept stress-test workaround |
| V5 `make complete-feature --dry-run` | Per Q2 answer; accept friction at P2-bis closures |
| V14 `BRANCH_ISOLATION_HISTORICAL` enforced | Forward-only audit; doesn't intersect Phase C |
| V15 `BRANCH_ISOLATION_LAUNCHD_DRIFT` enforced | P2-bis Fix #3 supersedes for the campaign use case |
| V17 `kill_criteria_resolution` backfill on 61 grandfathered case studies | Independent; affects pre-existing data |
| Cross-org PR cites (e.g., `vercel/next.js#12345`) | URL form works without validation |
| Issue cites (`#42` for issues) | Out of scope; only PR cites validated |
| Cite-in-code-block exclusion list | Author discipline mitigation |
| Rollback automation for failed reverse-sync PRs | Manual triage per `feedback_no_auto_merge_without_approval.md` |
| HADF Phase 2-bis itself | Design happens AFTER framework calibration window |
| Performance / load testing | Per-commit timescales; no SLA |
| Snapshot testing for control-room render | Visual confirmation IS calibration target |
| Cross-OS testing | macOS-only repo convention |

### §8.2 Locked decisions (per OQ-1, OQ-2, OQ-3)

- **OQ-1:** Spec at `docs/superpowers/specs/2026-05-11-cross-repo-state-sync-impl-design.md`; Feature name `cross-repo-state-sync-impl`. v7.8.3 framework version explained in spec body but not in filename.
- **OQ-2:** Per-phase branches: `feat/cross-repo-state-sync-phase-{0,1,2,3,4-cutover}`. Each merges as separate PR.
- **OQ-3:** `framework_version: "v7.8.3"` immutable on this Feature's state.json. CLAUDE.md tracks current framework version separately.

---

## §9 Dogfooding compliance — this Feature runs through ALL existing v7.5→v7.8.2 gates

Every Phase 0-4 commit is subject to the full framework stack. No exemptions added by this Feature. Coverage map:

### §9.1 Write-time gates (pre-commit hook)

| Gate | Source | Fires on this Feature? |
|---|---|---|
| `SCHEMA_DRIFT` | v7.5 | YES |
| `PR_NUMBER_UNRESOLVED` | v7.5 | YES (post-Phase-1 cross-repo via D-3) |
| `PHASE_TRANSITION_NO_LOG` | v7.6 | YES on every phase transition |
| `PHASE_TRANSITION_NO_TIMING` | v7.6 | YES |
| `BROKEN_PR_CITATION` | v7.6 + Phase 1 D-3 extension | YES |
| `CASE_STUDY_MISSING_TIER_TAGS` | v7.6 | YES on Phase 4 case study |
| `CACHE_HITS_EMPTY_POST_V6` | v7.7 + Phase 0 V2 enforcement | YES — Mechanism C captures session attribution |
| `CU_V2_INVALID` | v7.7 | YES |
| `STATE_NO_CASE_STUDY_LINK` | v7.7 | YES on Phase 4 closure |
| `CASE_STUDY_MISSING_FIELDS` | v7.7 | YES on Phase 4 case study |
| `ISOLATION_OPT_OUT_REASON_MISSING` | v7.8.1 | N/A (does NOT opt out) |
| `BRANCH_ISOLATION_VIOLATION` (Mode B) | v7.8.1 advisory → v7.9 enforced ~2026-05-21 | YES advisory; possibly enforced by Phase 4 |
| `FEATURE_CLOSURE_COMPLETENESS` | v7.8.1 advisory → v7.9 enforced | YES on Phase 4 closure |
| `STATE_OWNER_MISSING / INVALID / LOCATION_MISMATCH` | NEW Phase 2 | YES — own state.json must comply |

### §9.2 Cycle-time gates (72h via GitHub Actions)

All 16 check codes apply: `PHASE_LIE`, `TASK_LIE`, `NO_CS_LINK`, `V2_FILE_MISSING`, `PARTIAL_SHIP_TERMINAL`, `NO_STATE`, `INVALID_JSON`, `NO_PHASE`, `SCHEMA_DRIFT`, `PR_NUMBER_UNRESOLVED`, `BROKEN_PR_CITATION`, `CASE_STUDY_MISSING_TIER_TAGS`, `CU_V2_INVALID`, `BRANCH_ISOLATION_HISTORICAL`, `BRANCH_ISOLATION_LAUNCHD_DRIFT`, `FEATURE_CLOSURE_COMPLETENESS` cycle-time mirror.

### §9.3 v7.8 Bridge mechanisms (advisory but emitting telemetry)

| Mechanism | Coverage on this Feature |
|---|---|
| **A** Coverage-asserting gates → `gate-coverage.jsonl` | Every gate fire emits to ledger; calibration data for V1 future enforcement |
| **B** Schema field-rename detection + dual-read | `state_owner` is a Mechanism B candidate (new field); backward-compat handled |
| **C** PostToolUse:Read hook → `_session-<id>.events.jsonl` | Captures every Read during this Feature's Claude Code sessions; populates `cache_hits[]` automatically |
| **D** Pre-commit hook header self-audit | NEW gates V2 + V9 + Phase 2 schema gates carry header version stamps; Mechanism D validates them |
| **E** Custom git merge driver | Covers `measurement-adoption-history.json` + `documentation-debt.json`; Phase 0 V9 EXTENDS to `<feature>.log.json` (this Feature's own log gets driver coverage) |
| **F** Membrane-status advisory | `make membrane-status` + SessionStart hook surfaces this Feature as active in-flight work |

### §9.4 v7.6 per-PR + weekly defenses

`pr-integrity-check.yml` runs per-PR on each phase's PR; `framework-status-weekly.yml` Mondays appends snapshot to measurement-adoption-history capturing this Feature's progress.

### §9.5 Case study monitoring

- Source case study at `docs/case-studies/cross-repo-state-sync-impl-case-study.md` — subject to all case-study gates
- Showcase MDX at `fitme-story/content/04-case-studies/<NN>-cross-repo-state-sync-impl.mdx` — subject to dual-outlet pattern + chronological-order rule (slot N reflecting v7.8.3 era)
- The (paused/unbuilt) "Case Study Monitoring Extension" memory entry refers to a forward-only trigger that's not yet shipped; if it ships before Phase 4, this Feature's case study fires it. Currently no-op.

### §9.6 v7.8.2 cross-repo telemetry asymmetry

Doesn't impact this Feature (FT2 commits hit gates; fitme-story commits hit gates per Phase B port). Documented exemption stays valid.

### §9.7 Net assessment

Zero new exemptions added by this Feature. The Feature is the dogfood test of its own framework additions + every prior framework gate.

---

## §10 Per-phase snapshot protocol

### §10.1 Why this is in scope

Phase 2's contamination AND this very session's VS Code shutdown both demonstrate empirical loss-of-work risk. The SSD has documented disconnect risk per `reference_devssd_hardware_issue.md`. This Feature has 5 phases × ~12 days wall-clock with significant per-phase work product. The snapshot protocol is a safety net, not a feature; cheap to add (~50 lines of bash + Makefile target). Generalizable: same script works for any future Feature that wants per-phase snapshots.

### §10.2 Snapshot triggers

- Phase 0 → 1 transition (after Phase 0 PR merges + V2/V9 calibration target met)
- Phase 1 → 2 transition (after D-3 retroactive 35/35 + C-4 deploy)
- Phase 2 → 3 transition (after backfill PR + morphed C-5 synthetic test passes)
- Phase 3 → 4 transition (after reverse-sync workflow YAML lints + token verified)
- Phase 4 cutover completion
- **Session pause** (if work spans multiple sessions, regardless of phase position)

### §10.3 Snapshot contents (matches `2026-05-08-hadf-preservation/` pattern)

- All `.claude/features/cross-repo-state-sync-impl/` files (state.json, prd.md, tasks.md, log.json mirror)
- All Phase-relevant scripts modified or added
- All Phase-relevant test files
- All Phase-relevant case study + showcase MDX (Phase 4 onward)
- Current commit SHA + branch name + PR number(s)
- `MANIFEST.md` (provenance + restoration recipe)
- `CHECKSUMS.sha256` (sha256 of every file)

### §10.4 Destination

Internal Mac storage at `~/Documents/FitTracker2-backups/<date>-cross-repo-state-sync-impl-<phase-or-pause>/`. Examples:
- `~/Documents/FitTracker2-backups/2026-05-13-cross-repo-state-sync-impl-phase-0-complete/`
- `~/Documents/FitTracker2-backups/2026-05-15-cross-repo-state-sync-impl-pause-end-of-session/`

NOT on the SSD (per existing SSD-disconnect remediation pattern from `reference_devssd_hardware_issue.md`).

### §10.5 New helper script `scripts/snapshot-phase-completion.sh`

```bash
#!/usr/bin/env bash
# Usage: ./scripts/snapshot-phase-completion.sh <phase-or-pause-id> <feature-name>
# Example: ./scripts/snapshot-phase-completion.sh phase-0-complete cross-repo-state-sync-impl
set -euo pipefail

PHASE_ID="${1:?phase-or-pause-id required}"
FEATURE_NAME="${2:?feature-name required}"
DATE=$(date +%Y-%m-%d)
BACKUP_DIR="$HOME/Documents/FitTracker2-backups/${DATE}-${FEATURE_NAME}-${PHASE_ID}"

mkdir -p "$BACKUP_DIR"
cp -p ".claude/features/${FEATURE_NAME}"/* "$BACKUP_DIR/" 2>/dev/null || true
cp -p ".claude/logs/${FEATURE_NAME}.log.json" "$BACKUP_DIR/" 2>/dev/null || true
# Phase-specific files (caller can extend via env var EXTRA_FILES)
for f in ${EXTRA_FILES:-}; do
    cp -p "$f" "$BACKUP_DIR/" 2>/dev/null || true
done

# Generate manifest
cd "$BACKUP_DIR"
shasum -a 256 *.* > CHECKSUMS.sha256 2>/dev/null || true
cat > MANIFEST.md <<EOF
# Snapshot — ${FEATURE_NAME} ${PHASE_ID}

**Created:** $(date -u +%FT%TZ)
**Branch:** $(cd - >/dev/null && git branch --show-current)
**Commit SHA:** $(cd - >/dev/null && git rev-parse HEAD)
**Feature:** ${FEATURE_NAME}
**Phase/Pause ID:** ${PHASE_ID}

## Restoration

\`\`\`bash
shasum -a 256 -c CHECKSUMS.sha256
\`\`\`

EOF

echo "Snapshot created: $BACKUP_DIR"
echo "Files: $(ls "$BACKUP_DIR" | wc -l)"
```

### §10.6 Makefile target

```make
snapshot-phase:
	./scripts/snapshot-phase-completion.sh $(PHASE) cross-repo-state-sync-impl
```

Operator runs `make snapshot-phase PHASE=phase-0-complete` after each milestone.

### §10.7 Retention

Indefinite (matches V2-rule HISTORICAL file retention policy in CLAUDE.md). Old snapshots accumulate but each is small (<100 KB typical). Operator-managed.

---

## §11 Cross-references

- Phase C contract: [`2026-05-09-cross-repo-state-sync.md`](2026-05-09-cross-repo-state-sync.md)
- v7.8 Bridge design: [`2026-05-02-framework-v7-8-and-v7-9-bridge-design.md`](2026-05-02-framework-v7-8-and-v7-9-bridge-design.md)
- v7.8.1 spec: [`framework-v7-8-branch-isolation/prd.md`](../../../.claude/features/framework-v7-8-branch-isolation/prd.md)
- v7.8.2 cross-repo asymmetry disposition: [`2026-05-08-cross-repo-gate-asymmetry.md`](2026-05-08-cross-repo-gate-asymmetry.md)
- Branch isolation out-of-scope (v8.0+ candidates): [`2026-05-07-branch-isolation-out-of-scope.md`](2026-05-07-branch-isolation-out-of-scope.md)
- HADF Phase 2-bis brainstorm + 3 cross-references (the gated Feature): `/Users/regevbarak/.claude/projects/-Volumes-DevSSD-FitTracker2/memory/project_phase2bis_brainstorm_paused_2026_05_11.md`
- This Feature's brainstorm 6 design decisions: `/Users/regevbarak/.claude/projects/-Volumes-DevSSD-FitTracker2/memory/project_phase_c_brainstorm_2026_05_11.md`
- Off-SSD audit backup (created during this brainstorm): `~/Documents/FitTracker2-backups/2026-05-11-phase2bis-brainstorm-audit/`
- Forward-sync canonical: [`fitme-story/scripts/sync-from-fittracker2.ts`](https://github.com/Regevba/fitme-story/blob/main/scripts/sync-from-fittracker2.ts)
- BROKEN_PR_CITATION gate today: [`scripts/check-case-study-preflight.py`](../../../scripts/check-case-study-preflight.py) (lines 74-76)
- Existing Mechanism E driver: [`scripts/merge-driver-dedup.py`](../../../scripts/merge-driver-dedup.py)
- Existing Mechanism C source: [`scripts/observe-cache-hit.py`](../../../scripts/observe-cache-hit.py)
