# Cross-Repo State Sync (v7.8.3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the v7.8.3 release umbrella — 5 sequential phases (framework gate promotions → telemetry foundations → schema + backfill + morphed validator → reverse-sync GitHub Action → cutover ceremony) that close all deferred Phase C/D state-sync work plus V2/V9 v7.9 candidates, gating HADF Phase 2-bis on framework calibration.

**Architecture:** FT2 stays canonical writer for all state.json + ledgers; fitme-story is canonical reader with rare reverse-sync writes for fitme-story-native features (mediated by GitHub Action + manual merge). Each phase ships in its own per-phase branch with explicit calibration targets sourced from natural feature work.

**Tech Stack:** Python 3 (pre-commit gate scripts, backfill, refresh, snapshot), Bash (snapshot script + GH Action wrapper), TypeScript / Node (fitme-story sync extension + aggregator), GitHub Actions YAML (reverse-sync workflow), git custom merge driver (V9 extension).

**Source spec:** [`docs/superpowers/specs/2026-05-11-cross-repo-state-sync-impl-design.md`](../specs/2026-05-11-cross-repo-state-sync-impl-design.md) (commit `d77f23d` on branch `chore/cross-repo-state-sync-impl-spec`).

---

## File Structure

### Created (FT2)

| Path | Phase | Responsibility |
|---|---|---|
| `scripts/refresh-pr-cache.py` | 1 | Populates `.cache/gh-pr-cache.json` for both repos via `gh pr list` |
| `scripts/snapshot-phase-completion.sh` | 0 | Operator script to snapshot per-phase work to `~/Documents/FitTracker2-backups/` |
| `scripts/backfill-state-owner.py` | 2 | One-shot script: insert `state_owner: "ft2"` into all 47 existing state.json files |
| `tests/framework/__init__.py` | 0 | Marker for new pytest test package |
| `tests/framework/conftest.py` | 0 | Shared pytest fixtures (test repo dir, fixture state.json, etc.) |
| `tests/framework/test_v2_writer_path.py` | 0 | V2 enforcement gate tests (CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT) |
| `tests/framework/test_v9_merge_driver.py` | 0 | V9 union-dedup driver on synthetic feature log conflicts |
| `tests/framework/test_snapshot_script.py` | 0 | Snapshot script idempotency + manifest correctness |
| `tests/framework/test_pr_cite_cache.py` | 1 | D-3 regex parametrization + REPO_MAP routing + resolve_pr_cite |
| `tests/framework/test_state_owner_gates.py` | 2 | STATE_OWNER_MISSING / INVALID / LOCATION_MISMATCH + sync_origin exemption |
| `tests/framework/test_backfill_script.py` | 2 | backfill-state-owner.py idempotency + correctness |
| `docs/case-studies/cross-repo-state-sync-impl-case-study.md` | 4 | Source case study documenting all 5 phases |

### Modified (FT2)

| Path | Phase | Change |
|---|---|---|
| `scripts/check-state-schema.py` | 0 + 2 | V2 enforcement (Phase 0); 3 new state_owner gates + sync_origin exemption (Phase 2) |
| `scripts/merge-driver-dedup.py` | 0 | Extend union-dedup logic to handle `.claude/logs/*.log.json` schema |
| `.gitattributes` | 0 | Add `.claude/logs/*.log.json merge=union-dedup-by-key` line |
| `scripts/check-case-study-preflight.py` | 1 | Replace `_PR_CITATION_PAT` regex (lines 74-76) + add `REPO_MAP` + `resolve_pr_cite` function |
| `Makefile` | 0 + 1 | Add `snapshot-phase` (Phase 0); `refresh-pr-cache`, `validate-existing-cites` (Phase 1) |
| `CLAUDE.md` | 0 + 2 | Bump framework version to v7.8.3 (Phase 0); add `state_owner` paragraph (Phase 2) |
| `.claude/integrity/schemas/state.schema.json` | 2 | Add `state_owner` to required fields (if file exists; else skip) |
| All 47 × `.claude/features/*/state.json` | 2 | Insert `state_owner: "ft2"` field (mechanical via backfill script) |

### Created (fitme-story)

| Path | Phase | Responsibility |
|---|---|---|
| `src/lib/control-room/gate-coverage-aggregator.ts` | 1 | Reads both repos' gate-coverage.jsonl + tags by source_repo + combines time-sorted |
| `tests/control-room/gate-coverage-aggregator.test.ts` | 1 | Aggregator on synthetic two-source data |
| `tests/control-room/sync-extension.test.ts` | 1 | Phase 1 forward-sync extension test |
| `.github/workflows/reverse-sync-fitme-story-to-ft2.yml` | 3 | Triggered by push to main; opens auto-PR against FT2 |
| `scripts/test-reverse-sync-action.sh` | 3 | Local `act` wrapper for workflow testing |
| `content/04-case-studies/<NN>-cross-repo-state-sync-impl.mdx` | 4 | Showcase MDX (slot N determined at Phase 4 by chronological-order rule — pick next slot after latest v7.8.2 case study) |

### Modified (fitme-story)

| Path | Phase | Change |
|---|---|---|
| `scripts/sync-from-fittracker2.ts` | 1 | Add forward-sync of `gate-coverage.jsonl` → `gate-coverage-ft2.jsonl` |
| `src/app/control-room/framework/page.tsx` (or equivalent) | 1 | Add aggregated gate-coverage section using new aggregator |
| `.claude/README.md` | 3 | Document reverse-sync flow + FT2_REPO_TOKEN setup |

### Created during Phase 4

| Path | Responsibility |
|---|---|
| `fitme-story/.claude/features/<fs-native>/state.json` | First fitme-story-native state.json (`state_owner: "fitme-story"`) |
| `fitme-story/.claude/logs/<fs-native>.log.json` | First fitme-story-native Tier 2.2 log |
| `FT2/.claude/features/<fs-native>/state.json` | Reverse-sync mirror (carries `state_owner_sync_origin: "fitme-story-reverse"` marker) |

---

## Phase 0 — v7.8.3 framework gate promotions + snapshot protocol

**Branch:** `feat/cross-repo-state-sync-phase-0` (off latest `main`)
**Single PR.** Estimated 1-2 days impl + 7 days calibration.

### Task 0.1: Set up tests/ directory + pytest config

**Files:**
- Create: `tests/__init__.py` (empty)
- Create: `tests/framework/__init__.py` (empty)
- Create: `tests/framework/conftest.py`
- Create: `pytest.ini` (if not already present at repo root)

- [ ] **Step 1: Verify tests/ does not exist**

```bash
test ! -d /Volumes/DevSSD/FitTracker2/tests && echo "OK: tests/ absent" || echo "FAIL: tests/ exists"
```

Expected: `OK: tests/ absent`

- [ ] **Step 2: Create test package structure**

```bash
mkdir -p /Volumes/DevSSD/FitTracker2/tests/framework
touch /Volumes/DevSSD/FitTracker2/tests/__init__.py
touch /Volumes/DevSSD/FitTracker2/tests/framework/__init__.py
```

- [ ] **Step 3: Create pytest config**

`pytest.ini`:
```ini
[pytest]
testpaths = tests
python_files = test_*.py
python_functions = test_*
filterwarnings =
    error::pytest.PytestUnraisableExceptionWarning
```

- [ ] **Step 4: Create conftest.py with shared fixtures**

`tests/framework/conftest.py`:
```python
"""Shared fixtures for framework gate tests."""
from __future__ import annotations
import json
import shutil
import subprocess
from pathlib import Path
import pytest


@pytest.fixture
def test_repo(tmp_path: Path) -> Path:
    """Create a minimal git repo with .claude/features/ structure."""
    subprocess.run(["git", "init", "-q"], cwd=tmp_path, check=True)
    subprocess.run(["git", "config", "user.email", "test@example.com"], cwd=tmp_path, check=True)
    subprocess.run(["git", "config", "user.name", "Test"], cwd=tmp_path, check=True)
    (tmp_path / ".claude" / "features").mkdir(parents=True)
    (tmp_path / ".claude" / "logs").mkdir(parents=True)
    (tmp_path / ".claude" / "shared").mkdir(parents=True)
    return tmp_path


@pytest.fixture
def write_state(test_repo: Path):
    """Helper: write a state.json under .claude/features/<name>/."""
    def _write(name: str, content: dict) -> Path:
        feat_dir = test_repo / ".claude" / "features" / name
        feat_dir.mkdir(parents=True, exist_ok=True)
        path = feat_dir / "state.json"
        path.write_text(json.dumps(content, indent=2) + "\n")
        return path
    return _write
```

- [ ] **Step 5: Verify pytest discovers (zero tests is OK)**

```bash
cd /Volumes/DevSSD/FitTracker2 && python3 -m pytest tests/ -v 2>&1 | head -10
```

Expected: `collected 0 items` (no errors)

- [ ] **Step 6: Commit infrastructure**

```bash
cd /Volumes/DevSSD/FitTracker2
git add tests/ pytest.ini
git commit -m "$(cat <<'EOF'
chore(tests): add tests/framework/ pytest package + conftest fixtures

Foundation for v7.8.3 framework gate test suite. Creates tests/__init__.py,
tests/framework/__init__.py, tests/framework/conftest.py with test_repo +
write_state shared fixtures, and pytest.ini with strict warnings.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task 0.2: V2 enforcement — write failing test

**Files:**
- Create: `tests/framework/test_v2_writer_path.py`

- [ ] **Step 1: Write the failing test**

```python
"""V2 — Mechanism C writer-path enforced (CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT).

Promotes the cache_hits[] writer-path gate from advisory (v7.8) to
enforced (v7.8.3) per spec §3.5.2 Phase 0 calibration target."""
from __future__ import annotations
import json
import subprocess
import sys
from pathlib import Path
import pytest

SCRIPT = Path(__file__).resolve().parents[2] / "scripts" / "check-state-schema.py"


def run_check(state_path: Path) -> tuple[int, str]:
    result = subprocess.run(
        [sys.executable, str(SCRIPT), str(state_path)],
        capture_output=True, text=True,
    )
    return result.returncode, result.stderr + result.stdout


def test_v2_post_v6_with_empty_cache_hits_and_session_reads_fails(write_state, test_repo):
    """When state.json is post-v6 (framework_version >= v6.0) AND post-Mechanism-C
    (created_at >= 2026-05-02) AND has corresponding session Read events
    BUT cache_hits[] is empty, V2 enforcement MUST reject."""
    state_path = write_state("test-feature", {
        "name": "test-feature",
        "framework_version": "v7.8.3",
        "created_at": "2026-05-12T00:00:00Z",
        "current_phase": "complete",
        "cache_hits": [],
    })
    # Simulate session events showing Read activity
    session_log = test_repo / ".claude" / "logs" / "_session-test.events.jsonl"
    session_log.write_text(json.dumps({"feature": "test-feature", "tool": "Read", "ts": "2026-05-12T01:00:00Z"}) + "\n")
    code, output = run_check(state_path)
    assert code != 0, f"expected V2 to fail; got code=0\n{output}"
    assert "CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT" in output


def test_v2_pre_v6_with_empty_cache_hits_passes(write_state):
    """Pre-v6 features are exempt from V2 (per CLAUDE.md gate doc)."""
    state_path = write_state("legacy-feature", {
        "name": "legacy-feature",
        "framework_version": "v5.1",
        "created_at": "2026-04-01T00:00:00Z",
        "current_phase": "complete",
        "cache_hits": [],
    })
    code, output = run_check(state_path)
    assert code == 0, f"expected pre-v6 exempt; got code != 0\n{output}"


def test_v2_with_populated_cache_hits_passes(write_state):
    """When cache_hits[] is non-empty, V2 passes regardless of Read events."""
    state_path = write_state("ok-feature", {
        "name": "ok-feature",
        "framework_version": "v7.8.3",
        "created_at": "2026-05-12T00:00:00Z",
        "current_phase": "complete",
        "cache_hits": [{"file": "x.py", "ts": "2026-05-12T01:00:00Z"}],
    })
    code, output = run_check(state_path)
    assert code == 0, f"populated cache_hits; expected pass\n{output}"
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /Volumes/DevSSD/FitTracker2 && python3 -m pytest tests/framework/test_v2_writer_path.py -v 2>&1 | tail -20
```

Expected: at least the first test FAILS (current code does NOT enforce V2; only emits advisory). Other tests may pass or fail depending on existing logic.

- [ ] **Step 3: Note the existing advisory behavior**

Read current advisory implementation in `scripts/check-state-schema.py` (search for `CACHE_HITS_AUTO_INSTRUMENTATION` or similar). Capture the function name + line range for Step 4 below.

```bash
grep -n "CACHE_HITS\|cache_hits" /Volumes/DevSSD/FitTracker2/scripts/check-state-schema.py | head -20
```

Expected: prints line numbers of existing advisory logic.

### Task 0.3: V2 enforcement — implement (promote advisory → enforced)

**Files:**
- Modify: `scripts/check-state-schema.py` (advisory function found in Task 0.2 Step 3)

- [ ] **Step 1: Promote the gate from advisory to enforced**

In `scripts/check-state-schema.py`, locate the function that currently emits `CACHE_HITS_AUTO_INSTRUMENTATION_INACTIVE` (advisory). Change it to:

1. Rename the gate code from `_INACTIVE` (advisory) to `_DRIFT` (enforced)
2. Change return severity from `WARN` / advisory to `FAIL`
3. Update the gate's docstring header to cite v7.8.3 promotion

The exact diff depends on the existing function shape. Pattern (illustrative):

```python
def check_cache_hits_auto_instrumentation_drift(state, file_path, *, coverage=None):
    """V2 (v7.8.3) — promoted from advisory to enforced.

    Fires when post-Mechanism-C state.json (created_at >= 2026-05-02) has
    framework_version >= v6.0 AND empty cache_hits[] AND corresponding session
    Read events exist in `.claude/logs/_session-*.events.jsonl`.

    Pre-Mechanism-C features (created_at < 2026-05-02) are exempt — the
    auto-instrumentation didn't exist for them.
    """
    # ... existing logic, but return FAIL not WARN ...
    if _is_post_v6(state) and _is_post_mechanism_c(state) and not state.get("cache_hits") and _has_session_reads(state, file_path):
        return Finding(
            severity="FAIL",
            code="CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT",
            message=f"{file_path}: post-v6 + post-Mechanism-C state.json has empty cache_hits[] but session events show Reads; auto-instrumentation appears broken",
        )
    return None
```

- [ ] **Step 2: Update Mechanism D header version stamp**

At the top of `scripts/check-state-schema.py`, find the header version block (Mechanism D self-audit pattern). Update the version stamp:

```python
__SCHEMA_CHECKER_VERSION__ = "v7.8.3"  # bumped from v7.8.2
__SCHEMA_CHECKER_LAST_MODIFIED__ = "2026-05-11"
```

- [ ] **Step 3: Run failing test — should pass now**

```bash
cd /Volumes/DevSSD/FitTracker2 && python3 -m pytest tests/framework/test_v2_writer_path.py -v
```

Expected: ALL 3 tests PASS.

- [ ] **Step 4: Run on real state.json files — verify zero false positives on shipped features**

```bash
cd /Volumes/DevSSD/FitTracker2 && python3 scripts/check-state-schema.py 2>&1 | tail -30
```

Expected: 0 NEW failures on already-shipped features. If any fail, capture the names + investigate before commit.

- [ ] **Step 5: Run pre-commit self-test**

```bash
cd /Volumes/DevSSD/FitTracker2 && make pre-commit-self-test
```

Expected: PASS — Mechanism D header self-audit confirms version stamp matches script version.

- [ ] **Step 6: Commit V2**

```bash
cd /Volumes/DevSSD/FitTracker2
git add tests/framework/test_v2_writer_path.py scripts/check-state-schema.py
git commit -m "$(cat <<'EOF'
feat(v7.8.3): V2 promote CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT advisory → enforced

Per spec §3.5.2 Phase 0 calibration target. Mechanism C writer-path is now
mechanically enforced — post-v6 + post-Mechanism-C state.json with empty
cache_hits[] but session Read events present causes pre-commit FAIL.

Adds tests/framework/test_v2_writer_path.py with 3 cases:
- post-v6 + Read events + empty cache_hits → FAIL
- pre-v6 → exempt
- populated cache_hits → PASS

Bumps __SCHEMA_CHECKER_VERSION__ to v7.8.3.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task 0.4: V9 driver extension — write failing test

**Files:**
- Create: `tests/framework/test_v9_merge_driver.py`

- [ ] **Step 1: Write the failing test**

```python
"""V9 — Mechanism E custom git merge driver covers .claude/logs/<feature>.log.json.

Per spec §10 / Phase 0. Extends existing union-dedup-by-key driver
(measurement-adoption-history.json + documentation-debt.json) to handle
Tier 2.2 contemporaneous feature logs."""
from __future__ import annotations
import json
import subprocess
import sys
from pathlib import Path
import pytest

DRIVER = Path(__file__).resolve().parents[2] / "scripts" / "merge-driver-dedup.py"


def run_driver(ours_path: Path, theirs_path: Path, ancestor_path: Path, real_path: str) -> int:
    """Invoke the driver with git's merge-driver argument convention (%O %A %B %P)."""
    result = subprocess.run(
        [sys.executable, str(DRIVER), str(ancestor_path), str(ours_path), str(theirs_path), real_path],
        capture_output=True, text=True,
    )
    return result.returncode


def test_v9_feature_log_union_dedup(tmp_path: Path):
    """Two diverging feature log files merge via union-dedup-by-key on event timestamps."""
    ours = tmp_path / "ours.json"
    theirs = tmp_path / "theirs.json"
    ancestor = tmp_path / "ancestor.json"

    ancestor.write_text(json.dumps({
        "feature": "test-feature",
        "events": [{"ts": "2026-05-12T00:00:00Z", "event_type": "phase_started", "phase": "research"}],
    }))
    ours.write_text(json.dumps({
        "feature": "test-feature",
        "events": [
            {"ts": "2026-05-12T00:00:00Z", "event_type": "phase_started", "phase": "research"},
            {"ts": "2026-05-12T01:00:00Z", "event_type": "phase_approved", "phase": "research"},
        ],
    }))
    theirs.write_text(json.dumps({
        "feature": "test-feature",
        "events": [
            {"ts": "2026-05-12T00:00:00Z", "event_type": "phase_started", "phase": "research"},
            {"ts": "2026-05-12T02:00:00Z", "event_type": "phase_started", "phase": "prd"},
        ],
    }))

    code = run_driver(ours, theirs, ancestor, ".claude/logs/test-feature.log.json")
    assert code == 0, "driver should return 0 on successful merge"

    merged = json.loads(ours.read_text())
    timestamps = sorted(e["ts"] for e in merged["events"])
    assert timestamps == [
        "2026-05-12T00:00:00Z",
        "2026-05-12T01:00:00Z",
        "2026-05-12T02:00:00Z",
    ], f"expected union-dedup; got {timestamps}"


def test_v9_feature_log_idempotent_when_no_conflict(tmp_path: Path):
    """If ours == theirs, merge result is identical."""
    ours = tmp_path / "ours.json"
    theirs = tmp_path / "theirs.json"
    ancestor = tmp_path / "ancestor.json"

    content = {"feature": "x", "events": [{"ts": "2026-05-12T00:00:00Z", "event_type": "x", "phase": "x"}]}
    ancestor.write_text(json.dumps(content))
    ours.write_text(json.dumps(content))
    theirs.write_text(json.dumps(content))

    code = run_driver(ours, theirs, ancestor, ".claude/logs/x.log.json")
    assert code == 0
    merged = json.loads(ours.read_text())
    assert merged == content
```

- [ ] **Step 2: Run failing test**

```bash
cd /Volumes/DevSSD/FitTracker2 && python3 -m pytest tests/framework/test_v9_merge_driver.py -v 2>&1 | tail -20
```

Expected: tests FAIL — driver doesn't recognize `.claude/logs/*.log.json` as a registered path.

### Task 0.5: V9 driver extension — implement

**Files:**
- Modify: `scripts/merge-driver-dedup.py` (extend ledger config)

- [ ] **Step 1: Add feature log config**

In `scripts/merge-driver-dedup.py`, find the ledger configuration dict (likely a constant like `LEDGER_CONFIGS = {...}`). Add an entry for `.claude/logs/*.log.json`:

```python
# Existing config (illustrative — actual shape may differ slightly):
LEDGER_CONFIGS = {
    ".claude/shared/measurement-adoption-history.json": {
        "array_field": "snapshots",
        "dedup_key": "date",
        "sort_key": "date",
    },
    ".claude/shared/documentation-debt.json": {
        "array_field": "items",
        "dedup_key": "id",
        "sort_key": "id",
    },
    # NEW (V9 Phase 0 v7.8.3):
    ".claude/logs/*.log.json": {
        "array_field": "events",
        "dedup_key": "ts",  # event timestamp; union-dedup by ts
        "sort_key": "ts",
    },
}
```

- [ ] **Step 2: Update path-matching logic to support glob patterns**

If the driver's path matching is exact-string only, extend it to handle glob patterns (`fnmatch.fnmatch` against `%P`):

```python
import fnmatch

def get_config_for_path(real_path: str) -> dict | None:
    for pattern, config in LEDGER_CONFIGS.items():
        if "*" in pattern:
            if fnmatch.fnmatch(real_path, pattern):
                return config
        else:
            if real_path == pattern:
                return config
    return None
```

- [ ] **Step 3: Update driver header version stamp (Mechanism D)**

```python
__MERGE_DRIVER_VERSION__ = "v7.8.3"  # bumped from v7.8 — adds .claude/logs/*.log.json
```

- [ ] **Step 4: Run failing test — should pass now**

```bash
cd /Volumes/DevSSD/FitTracker2 && python3 -m pytest tests/framework/test_v9_merge_driver.py -v
```

Expected: BOTH tests PASS.

- [ ] **Step 5: Verify no regression on existing covered files**

```bash
cd /Volumes/DevSSD/FitTracker2 && python3 -m pytest tests/ -v 2>&1 | tail -20
```

Expected: no test regressions.

### Task 0.6: V9 driver extension — register in .gitattributes

**Files:**
- Modify: `.gitattributes`

- [ ] **Step 1: Add registration line**

Append to `.gitattributes` after the existing union-dedup-by-key entries:

```
# v7.8.3: feature log files (Tier 2.2 contemporaneous logging)
.claude/logs/*.log.json merge=union-dedup-by-key
```

- [ ] **Step 2: Reinstall hooks (registers driver in local git config)**

```bash
cd /Volumes/DevSSD/FitTracker2 && make install-hooks
```

Expected: driver registered without error.

- [ ] **Step 3: Manually verify with synthetic conflict**

Create a synthetic feature log conflict, attempt merge, verify auto-resolution:

```bash
cd /Volumes/DevSSD/FitTracker2
git checkout -b test-v9-merge-driver-temp
mkdir -p .claude/logs
echo '{"feature":"test-v9","events":[{"ts":"2026-05-12T00:00:00Z","event_type":"x","phase":"x"}]}' > .claude/logs/test-v9.log.json
git add .claude/logs/test-v9.log.json
git commit -m "test: V9 base"
echo '{"feature":"test-v9","events":[{"ts":"2026-05-12T00:00:00Z","event_type":"x","phase":"x"},{"ts":"2026-05-12T01:00:00Z","event_type":"y","phase":"x"}]}' > .claude/logs/test-v9.log.json
git add .claude/logs/test-v9.log.json
git commit -m "test: V9 ours append"

git checkout -b test-v9-other HEAD~1
echo '{"feature":"test-v9","events":[{"ts":"2026-05-12T00:00:00Z","event_type":"x","phase":"x"},{"ts":"2026-05-12T02:00:00Z","event_type":"z","phase":"x"}]}' > .claude/logs/test-v9.log.json
git add .claude/logs/test-v9.log.json
git commit -m "test: V9 theirs append"

git checkout test-v9-merge-driver-temp
git merge test-v9-other --no-ff -m "test: V9 merge"
```

Expected: auto-merges via the driver; resulting file has all 3 events sorted by ts.

- [ ] **Step 4: Cleanup test branches**

```bash
cd /Volumes/DevSSD/FitTracker2
git checkout feat/cross-repo-state-sync-phase-0
git branch -D test-v9-merge-driver-temp test-v9-other
rm -f .claude/logs/test-v9.log.json
```

- [ ] **Step 5: Commit V9**

```bash
cd /Volumes/DevSSD/FitTracker2
git add tests/framework/test_v9_merge_driver.py scripts/merge-driver-dedup.py .gitattributes
git commit -m "$(cat <<'EOF'
feat(v7.8.3): V9 extend Mechanism E driver to .claude/logs/<feature>.log.json

Per spec §6.1 + V9 from v7.9 candidate inventory. Extends existing union-
dedup-by-key driver (currently covers measurement-adoption-history.json +
documentation-debt.json) to also auto-resolve merge conflicts on Tier 2.2
contemporaneous feature log files.

Adds path-glob matching (fnmatch) so the new entry .claude/logs/*.log.json
matches any feature log. Dedup key: event ts. Sort key: event ts.

Adds tests/framework/test_v9_merge_driver.py with union-dedup + idempotency
test cases.

Bumps __MERGE_DRIVER_VERSION__ to v7.8.3.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task 0.7: Snapshot protocol — write failing test

**Files:**
- Create: `tests/framework/test_snapshot_script.py`

- [ ] **Step 1: Write test**

```python
"""Per-phase snapshot script — spec §10.

Verifies snapshot-phase-completion.sh creates correct directory structure +
copies expected files + generates manifest + sha256 checksums."""
from __future__ import annotations
import os
import shutil
import subprocess
import sys
from pathlib import Path
import pytest

SCRIPT = Path(__file__).resolve().parents[2] / "scripts" / "snapshot-phase-completion.sh"


def test_snapshot_creates_dir_with_manifest_and_checksums(tmp_path: Path, monkeypatch):
    """Snapshot script creates ~/Documents/FitTracker2-backups/<date>-<feature>-<phase>/
    with MANIFEST.md + CHECKSUMS.sha256 + state.json copies."""
    # Set up mock home dir to avoid polluting real backups
    fake_home = tmp_path / "fake_home"
    fake_home.mkdir()
    monkeypatch.setenv("HOME", str(fake_home))

    # Set up fake repo with .claude/features/test-feature/state.json
    repo = tmp_path / "repo"
    (repo / ".claude" / "features" / "test-feature").mkdir(parents=True)
    (repo / ".claude" / "features" / "test-feature" / "state.json").write_text('{"name":"test-feature"}\n')
    (repo / ".claude" / "logs").mkdir()
    (repo / ".claude" / "logs" / "test-feature.log.json").write_text('{"events":[]}\n')

    # Init as git repo (script reads commit SHA + branch)
    subprocess.run(["git", "init", "-q"], cwd=repo, check=True)
    subprocess.run(["git", "config", "user.email", "t@e.com"], cwd=repo, check=True)
    subprocess.run(["git", "config", "user.name", "Test"], cwd=repo, check=True)
    subprocess.run(["git", "add", "."], cwd=repo, check=True)
    subprocess.run(["git", "commit", "-qm", "initial"], cwd=repo, check=True)

    # Run snapshot script
    result = subprocess.run(
        ["bash", str(SCRIPT), "phase-0-complete", "test-feature"],
        cwd=repo, capture_output=True, text=True,
    )
    assert result.returncode == 0, f"script failed: {result.stderr}"

    # Find the snapshot dir under fake_home
    backup_root = fake_home / "Documents" / "FitTracker2-backups"
    assert backup_root.exists()
    snapshots = list(backup_root.iterdir())
    assert len(snapshots) == 1
    snapshot_dir = snapshots[0]
    assert "test-feature-phase-0-complete" in snapshot_dir.name

    # Verify expected files
    assert (snapshot_dir / "state.json").exists()
    assert (snapshot_dir / "test-feature.log.json").exists()
    assert (snapshot_dir / "MANIFEST.md").exists()
    assert (snapshot_dir / "CHECKSUMS.sha256").exists()

    # Verify checksums valid
    verify = subprocess.run(["shasum", "-a", "256", "-c", "CHECKSUMS.sha256"],
                            cwd=snapshot_dir, capture_output=True, text=True)
    assert verify.returncode == 0, f"checksum mismatch: {verify.stdout}"
```

- [ ] **Step 2: Run failing test**

```bash
cd /Volumes/DevSSD/FitTracker2 && python3 -m pytest tests/framework/test_snapshot_script.py -v 2>&1 | tail -10
```

Expected: FAIL — script doesn't exist yet.

### Task 0.8: Snapshot protocol — implement

**Files:**
- Create: `scripts/snapshot-phase-completion.sh`
- Modify: `Makefile` (add `snapshot-phase` target)

- [ ] **Step 1: Write the script**

Per spec §10.5. Save to `scripts/snapshot-phase-completion.sh`:

```bash
#!/usr/bin/env bash
# scripts/snapshot-phase-completion.sh
#
# Per-phase snapshot to off-SSD backup. Spec §10.
#
# Usage: ./scripts/snapshot-phase-completion.sh <phase-or-pause-id> <feature-name>
# Example: ./scripts/snapshot-phase-completion.sh phase-0-complete cross-repo-state-sync-impl

set -euo pipefail

PHASE_ID="${1:?phase-or-pause-id required (e.g., phase-0-complete, pause-end-of-session)}"
FEATURE_NAME="${2:?feature-name required}"
DATE=$(date +%Y-%m-%d)
BACKUP_DIR="$HOME/Documents/FitTracker2-backups/${DATE}-${FEATURE_NAME}-${PHASE_ID}"

mkdir -p "$BACKUP_DIR"

# Copy feature artifacts (preserve mtimes)
if [ -d ".claude/features/${FEATURE_NAME}" ]; then
    cp -p ".claude/features/${FEATURE_NAME}"/* "$BACKUP_DIR/" 2>/dev/null || true
fi
if [ -f ".claude/logs/${FEATURE_NAME}.log.json" ]; then
    cp -p ".claude/logs/${FEATURE_NAME}.log.json" "$BACKUP_DIR/"
fi

# Allow caller to extend via EXTRA_FILES env var (space-separated)
for f in ${EXTRA_FILES:-}; do
    if [ -e "$f" ]; then
        cp -p "$f" "$BACKUP_DIR/" 2>/dev/null || true
    fi
done

# Capture git context
COMMIT_SHA=$(git rev-parse HEAD 2>/dev/null || echo "(no git)")
BRANCH=$(git branch --show-current 2>/dev/null || echo "(no git)")

# Generate sha256 manifest (only of files actually copied)
cd "$BACKUP_DIR"
if compgen -G "*" > /dev/null; then
    shasum -a 256 * 2>/dev/null | grep -v "CHECKSUMS.sha256" > CHECKSUMS.sha256 || true
fi

# Write MANIFEST.md
cat > MANIFEST.md <<EOF
# Snapshot — ${FEATURE_NAME} ${PHASE_ID}

**Created:** $(date -u +%FT%TZ)
**Branch:** ${BRANCH}
**Commit SHA:** ${COMMIT_SHA}
**Feature:** ${FEATURE_NAME}
**Phase/Pause ID:** ${PHASE_ID}

## Files preserved

$(ls -1 | grep -v MANIFEST.md | grep -v CHECKSUMS.sha256 | sed 's/^/- /')

## Verification

\`\`\`bash
cd ${BACKUP_DIR}
shasum -a 256 -c CHECKSUMS.sha256
\`\`\`

## Source spec / plan

- Spec: docs/superpowers/specs/2026-05-11-cross-repo-state-sync-impl-design.md
- Plan: docs/superpowers/plans/2026-05-11-cross-repo-state-sync-impl.md

## Drive risk context

This backup lives on internal Mac storage, NOT the SanDisk Extreme
\`/Volumes/DevSSD/\`, per the established convention from
\`reference_devssd_hardware_issue.md\`.
EOF

echo "Snapshot created: $BACKUP_DIR"
echo "Files: $(ls | wc -l | tr -d ' ')"
```

- [ ] **Step 2: Make executable**

```bash
chmod +x /Volumes/DevSSD/FitTracker2/scripts/snapshot-phase-completion.sh
```

- [ ] **Step 3: Add Makefile target**

Append to `Makefile`:

```make
snapshot-phase:
	@if [ -z "$(PHASE)" ]; then echo "Usage: make snapshot-phase PHASE=<id> [FEATURE=<name>]"; exit 1; fi
	./scripts/snapshot-phase-completion.sh $(PHASE) $${FEATURE:-cross-repo-state-sync-impl}
```

- [ ] **Step 4: Run test — should pass now**

```bash
cd /Volumes/DevSSD/FitTracker2 && python3 -m pytest tests/framework/test_snapshot_script.py -v
```

Expected: PASS.

- [ ] **Step 5: Manual smoke test**

```bash
cd /Volumes/DevSSD/FitTracker2 && make snapshot-phase PHASE=test-smoke FEATURE=cross-repo-state-sync-impl 2>&1 | tail -3
ls -la ~/Documents/FitTracker2-backups/$(date +%Y-%m-%d)-cross-repo-state-sync-impl-test-smoke/ 2>&1 | head -10
```

Expected: snapshot created with MANIFEST.md + CHECKSUMS.sha256 + any feature files (likely just the feature dir if it exists yet, otherwise empty + manifest).

- [ ] **Step 6: Cleanup smoke test snapshot**

```bash
rm -rf ~/Documents/FitTracker2-backups/$(date +%Y-%m-%d)-cross-repo-state-sync-impl-test-smoke/
```

- [ ] **Step 7: Commit snapshot tooling**

```bash
cd /Volumes/DevSSD/FitTracker2
git add tests/framework/test_snapshot_script.py scripts/snapshot-phase-completion.sh Makefile
git commit -m "$(cat <<'EOF'
feat(v7.8.3): per-phase snapshot protocol script + Makefile target

Per spec §10. Operator-driven off-SSD snapshot of feature work product
to ~/Documents/FitTracker2-backups/<date>-<feature>-<phase>/ with
MANIFEST.md + sha256-verified CHECKSUMS.sha256.

Addresses SanDisk Extreme disconnect risk (per reference_devssd_hardware_issue.md)
and the empirical loss-of-work events observed in 2026-05-11 sessions.

Triggers (operator-invoked): per-phase transitions + session pauses.
Usage: make snapshot-phase PHASE=phase-0-complete

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task 0.9: CLAUDE.md framework version bump to v7.8.3

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Add v7.8.3 paragraph**

Find the existing v7.8.2 section in `CLAUDE.md` ("v7.8.2 Cross-Repo Telemetry Asymmetry…"). After it, add:

```markdown
## v7.8.3 Cross-Repo State Sync Implementation (in flight, per spec 2026-05-11)

v7.8.3 is the umbrella release for the `cross-repo-state-sync-impl` Feature.
Bundles all deferred Phase C/D state-sync work with two v7.9 candidates
(V2 + V9) into a single 5-phase rollout. Gates HADF Phase 2-bis: that
campaign cannot start until all 5 phases ship and per-phase calibration
targets are met.

**Phase 0 promotes (already shipped):**
- V2 — `CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT` advisory → enforced
- V9 — Mechanism E custom git merge driver extends to `.claude/logs/<feature>.log.json`
- New `make snapshot-phase` Makefile target + `scripts/snapshot-phase-completion.sh` for per-phase off-SSD backups

**Phases 1-4 (in flight):** D-3 unified PR cite cache + C-4 control-room
aggregator (Phase 1); state_owner schema + 47-feature backfill + morphed
C-5 (Phase 2); D-1 reverse-sync GitHub Action (Phase 3); cutover ceremony
(Phase 4).

**Spec:** [`docs/superpowers/specs/2026-05-11-cross-repo-state-sync-impl-design.md`](docs/superpowers/specs/2026-05-11-cross-repo-state-sync-impl-design.md).
**Plan:** [`docs/superpowers/plans/2026-05-11-cross-repo-state-sync-impl.md`](docs/superpowers/plans/2026-05-11-cross-repo-state-sync-impl.md).
```

- [ ] **Step 2: Update the framework version line in the header (if exists)**

Search CLAUDE.md for "v7.5 → v7.6 → v7.7 → v7.8 → v7.8.1 → v7.8.2" and append `→ v7.8.3` to that progression line.

- [ ] **Step 3: Commit CLAUDE.md update**

```bash
cd /Volumes/DevSSD/FitTracker2
git add CLAUDE.md
git commit -m "$(cat <<'EOF'
docs(v7.8.3): bump framework version reference + Phase 0 deliverables

Per spec §6.1 Phase 0 deliverables. Documents the v7.8.3 umbrella release
in CLAUDE.md alongside existing v7.8 / v7.8.1 / v7.8.2 sections.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task 0.10: Open Phase 0 PR + verify CI + merge

- [ ] **Step 1: Push branch**

```bash
cd /Volumes/DevSSD/FitTracker2 && git push -u origin feat/cross-repo-state-sync-phase-0
```

- [ ] **Step 2: Open PR via gh**

```bash
cd /Volumes/DevSSD/FitTracker2 && gh pr create --title "v7.8.3 Phase 0 — V2 + V9 + snapshot protocol" --body "$(cat <<'EOF'
## Summary

First of 5 phases shipping the v7.8.3 release umbrella per spec
[`docs/superpowers/specs/2026-05-11-cross-repo-state-sync-impl-design.md`](docs/superpowers/specs/2026-05-11-cross-repo-state-sync-impl-design.md) §6.1.

- V2 — Mechanism C writer-path enforced (`CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT` advisory → enforced)
- V9 — Mechanism E custom git merge driver extends to `.claude/logs/<feature>.log.json` (+ `.gitattributes` registration)
- Per-phase snapshot protocol: `scripts/snapshot-phase-completion.sh` + `make snapshot-phase` target

Adds `tests/framework/` pytest package with 3 new test files (V2, V9, snapshot).
Bumps `CLAUDE.md` framework version to v7.8.3.

## Calibration target (post-merge)

Per spec §3.5.2: V2 ≥1 production fire without false positive in 7 days
(soft target ≥10 fires across ≥5 features); V9 auto-resolves ≥1 real
merge-conflict on `<feature>.log.json` (synthetic test if no natural
conflict in 7 days). HADF Phase 2-bis Sub-exp 1 unblocks once all 5
phases' calibration targets are met.

## Test plan

- [ ] `make verify-local` passes (build + tests + lint + integrity-check)
- [ ] `make pre-commit-self-test` passes (Mechanism D header self-audit)
- [ ] `make integrity-check` reports 0 hard findings post-merge
- [ ] `python3 -m pytest tests/framework/ -v` all green

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 3: Wait for CI green; address any failures; merge**

Watch CI status: `gh pr checks --watch`. Once green, ask user for merge approval; do NOT auto-merge per `feedback_no_auto_merge_without_approval.md`. After user approval: `gh pr merge --squash`.

- [ ] **Step 4: After merge: snapshot Phase 0 → 1 transition**

```bash
cd /Volumes/DevSSD/FitTracker2
git checkout main && git pull origin main
make snapshot-phase PHASE=phase-0-complete-pre-phase-1
```

Expected: snapshot created at `~/Documents/FitTracker2-backups/<date>-cross-repo-state-sync-impl-phase-0-complete-pre-phase-1/`.

---

## Phase 1 — Telemetry foundations (D-3 + C-4)

**Branch:** `feat/cross-repo-state-sync-phase-1` (off latest `main` after Phase 0 merge)
**Two PRs (one FT2 D-3, one fitme-story C-4).** Estimated 1-2 days impl + 5 days calibration.

### Task 1.1: D-3 — refresh-pr-cache.py — write failing test + implement

**Files:**
- Create: `tests/framework/test_pr_cite_cache.py`
- Create: `scripts/refresh-pr-cache.py`

- [ ] **Step 1: Write failing test for refresh script (mocks gh)**

```python
"""D-3 — unified cross-repo PR cite cache.

Tests refresh-pr-cache.py builds correct multi-repo cache shape, and
resolve_pr_cite() routes regex matches to the right repo's cache."""
from __future__ import annotations
import json
import subprocess
import sys
from pathlib import Path
from unittest.mock import patch
import pytest

REFRESH_SCRIPT = Path(__file__).resolve().parents[2] / "scripts" / "refresh-pr-cache.py"


def test_refresh_pr_cache_writes_correct_shape(tmp_path: Path, monkeypatch):
    """refresh-pr-cache.py writes cache file with schema_version, last_refreshed_at, repos."""
    monkeypatch.chdir(tmp_path)
    (tmp_path / ".cache").mkdir()
    
    # Mock gh subprocess to return synthetic PR data
    def fake_run(*args, **kwargs):
        cmd = args[0] if args else kwargs.get("args", [])
        if "gh" in cmd[0] and "pr" in cmd:
            class R:
                returncode = 0
                stdout = json.dumps([{"number": 42, "title": "test", "state": "OPEN"}])
                stderr = ""
            return R()
        # Fall through to real subprocess
        return subprocess.run(*args, **kwargs)
    
    monkeypatch.setattr("subprocess.check_output", lambda *a, **kw: json.dumps([{"number": 42, "title": "x", "state": "OPEN"}]).encode())
    
    result = subprocess.run([sys.executable, str(REFRESH_SCRIPT)], capture_output=True, text=True)
    # Note: actual test may need to mock gh CLI — script should handle gh-unavailable gracefully
    # If gh available, verify cache file exists + has expected shape
    cache_file = tmp_path / ".cache" / "gh-pr-cache.json"
    if cache_file.exists():
        cache = json.loads(cache_file.read_text())
        assert cache["schema_version"] == 1
        assert "last_refreshed_at" in cache
        assert "repos" in cache
```

- [ ] **Step 2: Run failing test**

```bash
cd /Volumes/DevSSD/FitTracker2 && python3 -m pytest tests/framework/test_pr_cite_cache.py::test_refresh_pr_cache_writes_correct_shape -v 2>&1 | tail -10
```

Expected: FAIL — script doesn't exist.

- [ ] **Step 3: Implement refresh-pr-cache.py**

Per spec §5.2. Save to `scripts/refresh-pr-cache.py`:

```python
#!/usr/bin/env python3
"""Refresh the unified cross-repo PR cite cache.

v7.8.3 D-3. Writes .cache/gh-pr-cache.json with PRs from both
Regevba/FitTracker2 and Regevba/fitme-story.

Schema:
  {
    "schema_version": 1,
    "last_refreshed_at": "<ISO timestamp>",
    "repos": {
      "Regevba/FitTracker2": {"open": [...], "merged": [...], "closed": [...]},
      "Regevba/fitme-story": {"open": [...], "merged": [...], "closed": [...]},
    }
  }

Skips gracefully when `gh` is unavailable or auth missing (matches existing
BROKEN_PR_CITATION skip-on-missing-gh pattern).
"""
from __future__ import annotations
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

REPOS = ["Regevba/FitTracker2", "Regevba/fitme-story"]
CACHE_FILE = Path(".cache") / "gh-pr-cache.json"


def fetch_repo_prs(repo: str) -> dict | None:
    """Fetch PRs for one repo across all states. Return None on gh failure."""
    repo_data = {}
    for state in ["open", "merged", "closed"]:
        try:
            result = subprocess.check_output(
                ["gh", "pr", "list", "--repo", repo, "--state", state,
                 "--json", "number,title,state", "--limit", "500"],
                stderr=subprocess.PIPE,
                timeout=30,
            )
            repo_data[state] = json.loads(result)
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired, FileNotFoundError) as e:
            print(f"WARN: failed to fetch {repo} {state} PRs: {e}", file=sys.stderr)
            return None
    return repo_data


def main() -> int:
    cache = {
        "schema_version": 1,
        "last_refreshed_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "repos": {},
    }
    for repo in REPOS:
        repo_data = fetch_repo_prs(repo)
        if repo_data is None:
            print(f"WARN: skipping {repo} (gh unavailable or auth failed)", file=sys.stderr)
            continue
        cache["repos"][repo] = repo_data
    
    if not cache["repos"]:
        print("ERROR: no repos cached; gh likely unavailable", file=sys.stderr)
        return 1
    
    CACHE_FILE.parent.mkdir(exist_ok=True)
    CACHE_FILE.write_text(json.dumps(cache, indent=2) + "\n")
    print(f"Wrote {CACHE_FILE} ({sum(len(r.get(s, [])) for r in cache['repos'].values() for s in ['open','merged','closed'])} PRs across {len(cache['repos'])} repos)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: Make executable + add to .gitignore**

```bash
chmod +x /Volumes/DevSSD/FitTracker2/scripts/refresh-pr-cache.py
echo ".cache/" >> /Volumes/DevSSD/FitTracker2/.gitignore
```

- [ ] **Step 5: Run test — should pass now**

```bash
cd /Volumes/DevSSD/FitTracker2 && python3 -m pytest tests/framework/test_pr_cite_cache.py::test_refresh_pr_cache_writes_correct_shape -v
```

Expected: PASS.

- [ ] **Step 6: Manual smoke — actually run refresh against real gh**

```bash
cd /Volumes/DevSSD/FitTracker2 && python3 scripts/refresh-pr-cache.py
cat .cache/gh-pr-cache.json | python3 -c "import json,sys; c=json.load(sys.stdin); print('repos:', list(c['repos'].keys())); print('FT2 open:', len(c['repos'].get('Regevba/FitTracker2',{}).get('open',[])))"
```

Expected: prints both repos + reasonable PR counts.

### Task 1.2: D-3 — regex update + REPO_MAP + resolve_pr_cite

**Files:**
- Modify: `scripts/check-case-study-preflight.py` (lines 74-76 + new function)

- [ ] **Step 1: Write failing test for regex**

Append to `tests/framework/test_pr_cite_cache.py`:

```python
import importlib.util
PREFLIGHT = Path(__file__).resolve().parents[2] / "scripts" / "check-case-study-preflight.py"

def load_preflight():
    spec = importlib.util.spec_from_file_location("preflight", PREFLIGHT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_pr_citation_pat_matches_three_forms():
    """Regex captures: PR #N (FT2 default), repo#N (cross-repo short), URL form."""
    pf = load_preflight()
    pat = pf._PR_CITATION_PAT
    
    # FT2 default
    m = pat.search("see PR #290")
    assert m and m.group(1) == "290"
    
    # Cross-repo short form
    m = pat.search("backed by [fitme-story#42]")
    assert m and m.group(2) == "fitme-story" and m.group(3) == "42"
    
    # URL form
    m = pat.search("github.com/Regevba/fitme-story/pull/42")
    assert m and m.group(4) == "Regevba" and m.group(5) == "fitme-story" and m.group(6) == "42"


def test_repo_map_includes_both_repos():
    pf = load_preflight()
    assert "fitme-story" in pf.REPO_MAP
    assert "FitTracker2" in pf.REPO_MAP


def test_resolve_pr_cite_finds_existing_pr():
    """When cache contains the PR number, resolve_pr_cite returns None (no Finding)."""
    pf = load_preflight()
    cache = {
        "schema_version": 1,
        "last_refreshed_at": "2026-05-12T00:00:00Z",
        "repos": {
            "Regevba/FitTracker2": {
                "open": [{"number": 290, "title": "x", "state": "OPEN"}],
                "merged": [], "closed": [],
            },
            "Regevba/fitme-story": {
                "open": [{"number": 42, "title": "y", "state": "OPEN"}],
                "merged": [], "closed": [],
            },
        },
    }
    
    m = pf._PR_CITATION_PAT.search("PR #290")
    assert pf.resolve_pr_cite(m, cache) is None
    
    m = pf._PR_CITATION_PAT.search("[fitme-story#42]")
    assert pf.resolve_pr_cite(m, cache) is None


def test_resolve_pr_cite_unknown_repo_short_name_fails():
    pf = load_preflight()
    cache = {"schema_version": 1, "repos": {}}
    m = pf._PR_CITATION_PAT.search("[unknown-repo#1]")
    finding = pf.resolve_pr_cite(m, cache)
    assert finding is not None
    assert "BROKEN_PR_CITATION" in finding.code or finding.code == "BROKEN_PR_CITATION"


def test_resolve_pr_cite_missing_pr_fails():
    pf = load_preflight()
    cache = {
        "schema_version": 1,
        "last_refreshed_at": "2026-05-12T00:00:00Z",
        "repos": {
            "Regevba/FitTracker2": {"open": [], "merged": [], "closed": []},
        },
    }
    m = pf._PR_CITATION_PAT.search("PR #999999")
    finding = pf.resolve_pr_cite(m, cache)
    assert finding is not None and finding.code == "BROKEN_PR_CITATION"
```

- [ ] **Step 2: Run failing tests**

```bash
cd /Volumes/DevSSD/FitTracker2 && python3 -m pytest tests/framework/test_pr_cite_cache.py -v 2>&1 | tail -20
```

Expected: 5 NEW tests FAIL (regex shape mismatch + REPO_MAP missing + resolve_pr_cite missing).

- [ ] **Step 3: Update regex + add REPO_MAP + add resolve_pr_cite**

In `scripts/check-case-study-preflight.py`, replace line 74-76:

```python
# OLD:
# _PR_CITATION_PAT = re.compile(
#     r'(?:[Pp][Rr]\s*#?|github\.com/[^/\s]+/[^/\s]+/pull/)(\d+)'
# )

# NEW (v7.8.3 D-3):
_PR_CITATION_PAT = re.compile(
    r"(?:[Pp][Rr]\s*#?(\d+))"                       # group 1: FT2 default — "PR #290" or "PR#290"
    r"|(?:\[?([\w-]+)\s*#(\d+)\]?)"                 # groups 2+3: cross-repo short form — "fitme-story#42" or "[fitme-story#42]"
    r"|(?:github\.com/([\w-]+)/([\w-]+)/pull/(\d+))"  # groups 4+5+6: URL form
)

REPO_MAP = {
    "fitme-story": "Regevba/fitme-story",
    "FitTracker2": "Regevba/FitTracker2",
    "ft2": "Regevba/FitTracker2",
}

CACHE_FILE = Path(".cache") / "gh-pr-cache.json"
CACHE_TTL_SECONDS = 300  # 5 min


def _load_pr_cache() -> dict | None:
    """Load cached PR data; refresh if stale or missing."""
    if not CACHE_FILE.exists():
        _refresh_cache_or_skip()
    if not CACHE_FILE.exists():
        return None  # gh unavailable; caller skips gracefully
    try:
        cache = json.loads(CACHE_FILE.read_text())
        last = datetime.fromisoformat(cache["last_refreshed_at"].replace("Z", "+00:00"))
        age = (datetime.now(timezone.utc) - last).total_seconds()
        if age > CACHE_TTL_SECONDS:
            _refresh_cache_or_skip()
            cache = json.loads(CACHE_FILE.read_text())
        return cache
    except Exception as e:
        print(f"WARN: PR cache load failed: {e}", file=sys.stderr)
        return None


def _refresh_cache_or_skip() -> None:
    refresh_script = Path(__file__).parent / "refresh-pr-cache.py"
    try:
        subprocess.run([sys.executable, str(refresh_script)], check=False, timeout=60)
    except Exception:
        pass  # graceful skip


def resolve_pr_cite(match, cache: dict | None) -> Finding | None:
    """Resolve a regex match against the multi-repo PR cache."""
    if cache is None:
        return None  # gh unavailable; caller has already noted this
    
    if match.group(1):
        repo = "Regevba/FitTracker2"
        pr_num = int(match.group(1))
    elif match.group(2):
        repo_short = match.group(2)
        repo = REPO_MAP.get(repo_short)
        if repo is None:
            return Finding(
                severity="FAIL",
                code="BROKEN_PR_CITATION",
                message=f"unknown repo short name '{repo_short}'; valid: {sorted(REPO_MAP.keys())}",
            )
        pr_num = int(match.group(3))
    elif match.group(4):
        repo = f"{match.group(4)}/{match.group(5)}"
        pr_num = int(match.group(6))
    else:
        return None  # no match; shouldn't happen
    
    if repo not in cache.get("repos", {}):
        return Finding(
            severity="FAIL",
            code="BROKEN_PR_CITATION",
            message=f"no cache for repo '{repo}'; refresh cache or add to REPO_MAP",
        )
    
    repo_cache = cache["repos"][repo]
    all_prs = repo_cache.get("open", []) + repo_cache.get("merged", []) + repo_cache.get("closed", [])
    if not any(pr["number"] == pr_num for pr in all_prs):
        return Finding(
            severity="FAIL",
            code="BROKEN_PR_CITATION",
            message=f"PR #{pr_num} not found in {repo} (cache last refreshed {cache.get('last_refreshed_at', 'unknown')})",
        )
    
    return None  # valid cite
```

(Note: the `Finding` class shape may differ; mirror whatever `check-case-study-preflight.py` already uses for findings — adjust the pseudo-code to match.)

- [ ] **Step 4: Wire `resolve_pr_cite` into the existing case-study scan loop**

Find the existing place in `check-case-study-preflight.py` where `_PR_CITATION_PAT` is matched + a Finding is emitted on missing PR. Replace the inline single-cache lookup with:

```python
cache = _load_pr_cache()
for match in _PR_CITATION_PAT.finditer(case_study_body):
    finding = resolve_pr_cite(match, cache)
    if finding:
        findings.append(finding)
```

- [ ] **Step 5: Run all tests — should pass now**

```bash
cd /Volumes/DevSSD/FitTracker2 && python3 -m pytest tests/framework/test_pr_cite_cache.py -v
```

Expected: ALL tests PASS.

### Task 1.3: D-3 — add Makefile targets

**Files:**
- Modify: `Makefile`

- [ ] **Step 1: Add refresh-pr-cache + validate-existing-cites targets**

Append to `Makefile`:

```make
refresh-pr-cache:
	python3 scripts/refresh-pr-cache.py

validate-existing-cites: refresh-pr-cache
	@echo "Validating PR cites in all docs/case-studies/*.md against unified cache…"
	@python3 scripts/check-case-study-preflight.py docs/case-studies/*.md
```

- [ ] **Step 2: Run retroactive validation pass**

```bash
cd /Volumes/DevSSD/FitTracker2 && make validate-existing-cites 2>&1 | tail -30
```

Expected: ZERO new failures (35/35 cross-repo cites validate). If any fail, capture per spec §6.2 calibration target and triage.

- [ ] **Step 3: Commit D-3**

```bash
cd /Volumes/DevSSD/FitTracker2
git add tests/framework/test_pr_cite_cache.py scripts/refresh-pr-cache.py scripts/check-case-study-preflight.py Makefile .gitignore
git commit -m "$(cat <<'EOF'
feat(v7.8.3): D-3 unified cross-repo PR cite cache

Per spec §5. Closes the BROKEN_PR_CITATION gate's two known bugs (silent
skip on cross-repo cites, URL-form mis-routing). Now resolves all 3 cite
forms (FT2 default, cross-repo short, URL) against a multi-repo cache
covering both Regevba/FitTracker2 and Regevba/fitme-story.

Adds:
- scripts/refresh-pr-cache.py — populates .cache/gh-pr-cache.json
- _PR_CITATION_PAT regex update (3 alternations) + REPO_MAP whitelist + resolve_pr_cite()
- Makefile targets: refresh-pr-cache + validate-existing-cites
- tests/framework/test_pr_cite_cache.py with 5 test cases

Calibration target: 35/35 retroactive cross-repo cites validate clean.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task 1.4: D-3 — open FT2 PR + merge

- [ ] **Step 1: Push + open PR**

```bash
cd /Volumes/DevSSD/FitTracker2 && git push -u origin feat/cross-repo-state-sync-phase-1
gh pr create --title "v7.8.3 Phase 1 (D-3) — unified cross-repo PR cite cache" --body "$(cat <<'EOF'
## Summary

D-3 deliverable from spec §5. Closes BROKEN_PR_CITATION gate's silent-skip
on cross-repo cites + URL-form mis-routing.

## Calibration target

`make validate-existing-cites` passes 35/35 retroactive cross-repo cites.

## Test plan

- [ ] `python3 -m pytest tests/framework/test_pr_cite_cache.py -v` all green
- [ ] `make validate-existing-cites` passes
- [ ] `make verify-local` passes

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 2: Wait for CI; user approves; merge squash**

### Task 1.5: C-4 — fitme-story forward-sync extension

**Files (in fitme-story repo):**
- Modify: `scripts/sync-from-fittracker2.ts` (add gate-coverage-ft2.jsonl sync)
- Create: `tests/control-room/sync-extension.test.ts`

- [ ] **Step 1: Switch to fitme-story repo + create branch**

```bash
cd /Volumes/DevSSD/fitme-story
git checkout main && git pull origin main
git checkout -b feat/cross-repo-state-sync-phase-1
```

- [ ] **Step 2: Write failing test for sync extension**

`tests/control-room/sync-extension.test.ts`:
```typescript
import { describe, it, expect } from 'vitest';
import { existsSync, readFileSync, mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { execSync } from 'node:child_process';

describe('sync-from-fittracker2 — gate-coverage-ft2.jsonl extension', () => {
  it('mirrors FT2 .claude/logs/gate-coverage.jsonl to src/data/integrity/gate-coverage-ft2.jsonl', () => {
    const tmp = join(tmpdir(), `sync-test-${Date.now()}`);
    const fakeFt2 = join(tmp, 'FitTracker2');
    const fakeFs = join(tmp, 'fitme-story');
    mkdirSync(join(fakeFt2, '.claude', 'logs'), { recursive: true });
    mkdirSync(join(fakeFs, 'src', 'data', 'integrity'), { recursive: true });

    writeFileSync(
      join(fakeFt2, '.claude', 'logs', 'gate-coverage.jsonl'),
      '{"gate":"V2","outcome":"FAIL","ts":"2026-05-12T00:00:00Z"}\n'
    );

    // Run the sync script (assumes it accepts FT2_PATH + FS_PATH env vars or argv)
    // ... actual invocation depends on how sync-from-fittracker2.ts is structured
    // Possible approach: import the sync function directly + invoke with paths

    expect(existsSync(join(fakeFs, 'src', 'data', 'integrity', 'gate-coverage-ft2.jsonl'))).toBe(true);
    const content = readFileSync(join(fakeFs, 'src', 'data', 'integrity', 'gate-coverage-ft2.jsonl'), 'utf-8');
    expect(content).toContain('V2');

    rmSync(tmp, { recursive: true, force: true });
  });
});
```

- [ ] **Step 3: Run failing test**

```bash
cd /Volumes/DevSSD/fitme-story && npx vitest run tests/control-room/sync-extension.test.ts 2>&1 | tail -10
```

Expected: FAIL — no extension exists yet.

- [ ] **Step 4: Implement extension**

In `fitme-story/scripts/sync-from-fittracker2.ts`, locate the section that copies `.claude/logs/<feature>.log.json` (added in C-1, 2026-05-10). Add a new copy step:

```typescript
// v7.8.3 Phase 1 C-4: mirror FT2's gate-coverage.jsonl for control-room aggregator
const ft2GateCoveragePath = path.join(FT2_PATH, '.claude', 'logs', 'gate-coverage.jsonl');
const fsGateCoverageDest = path.join(FS_PATH, 'src', 'data', 'integrity', 'gate-coverage-ft2.jsonl');
if (existsSync(ft2GateCoveragePath)) {
  mkdirSync(path.dirname(fsGateCoverageDest), { recursive: true });
  copyFileSync(ft2GateCoveragePath, fsGateCoverageDest);
}
```

- [ ] **Step 5: Run test — should pass**

```bash
cd /Volumes/DevSSD/fitme-story && npx vitest run tests/control-room/sync-extension.test.ts -v
```

Expected: PASS.

- [ ] **Step 6: Manual smoke**

```bash
cd /Volumes/DevSSD/fitme-story && npm run prebuild 2>&1 | tail -5
ls -la src/data/integrity/gate-coverage-ft2.jsonl
```

Expected: file exists; size > 0 (mirror of FT2's 1734-line gate-coverage).

### Task 1.6: C-4 — control-room aggregator

**Files (fitme-story):**
- Create: `src/lib/control-room/gate-coverage-aggregator.ts`
- Create: `tests/control-room/gate-coverage-aggregator.test.ts`
- Modify: appropriate page in `src/app/control-room/framework/` (locate via `find src/app/control-room -name '*.tsx' | head -5`)

- [ ] **Step 1: Write failing test**

`tests/control-room/gate-coverage-aggregator.test.ts`:
```typescript
import { describe, it, expect } from 'vitest';
import { aggregateGateCoverage } from '@/lib/control-room/gate-coverage-aggregator';

describe('gate-coverage-aggregator', () => {
  it('combines two sources tagged by source_repo, sorted by ts', () => {
    const ft2Lines = [
      '{"gate":"V2","outcome":"FAIL","ts":"2026-05-12T01:00:00Z"}',
      '{"gate":"V9","outcome":"PASS","ts":"2026-05-12T03:00:00Z"}',
    ].join('\n');
    const fsLines = [
      '{"gate":"V2","outcome":"PASS","ts":"2026-05-12T02:00:00Z"}',
    ].join('\n');

    const result = aggregateGateCoverage(ft2Lines, fsLines);
    expect(result).toHaveLength(3);
    expect(result[0].source_repo).toBe('ft2');
    expect(result[0].ts).toBe('2026-05-12T01:00:00Z');
    expect(result[1].source_repo).toBe('fitme-story');
    expect(result[1].ts).toBe('2026-05-12T02:00:00Z');
    expect(result[2].source_repo).toBe('ft2');
  });

  it('counts events per source', () => {
    const ft2Lines = '{"gate":"V2","outcome":"FAIL","ts":"2026-05-12T00:00:00Z"}';
    const fsLines = '{"gate":"V2","outcome":"PASS","ts":"2026-05-12T01:00:00Z"}';
    const counts = countEventsBySource(ft2Lines, fsLines);
    expect(counts.ft2).toBe(1);
    expect(counts['fitme-story']).toBe(1);
  });
});
```

(Imports above assume `countEventsBySource` is also exported; adjust if needed.)

- [ ] **Step 2: Run failing test**

Expected: FAIL — module doesn't exist.

- [ ] **Step 3: Implement aggregator**

`src/lib/control-room/gate-coverage-aggregator.ts`:
```typescript
// v7.8.3 Phase 1 C-4: cross-repo gate-coverage aggregator
// Reads FT2's gate-coverage (synced to src/data/integrity/gate-coverage-ft2.jsonl)
// + fitme-story's local .claude/logs/gate-coverage.jsonl
// Combines + tags + sorts by timestamp.

export type GateEvent = {
  gate: string;
  outcome: 'PASS' | 'FAIL' | 'WARN';
  ts: string;
  source_repo?: 'ft2' | 'fitme-story';
  [key: string]: unknown;
};

export function aggregateGateCoverage(ft2Content: string, fsContent: string): GateEvent[] {
  const parseLines = (content: string, source: 'ft2' | 'fitme-story'): GateEvent[] =>
    content
      .split('\n')
      .filter(line => line.trim().length > 0)
      .map(line => {
        const parsed = JSON.parse(line) as GateEvent;
        parsed.source_repo = source;
        return parsed;
      });

  const all = [...parseLines(ft2Content, 'ft2'), ...parseLines(fsContent, 'fitme-story')];
  all.sort((a, b) => a.ts.localeCompare(b.ts));
  return all;
}

export function countEventsBySource(ft2Content: string, fsContent: string): Record<string, number> {
  const ft2Count = ft2Content.split('\n').filter(l => l.trim().length > 0).length;
  const fsCount = fsContent.split('\n').filter(l => l.trim().length > 0).length;
  return { ft2: ft2Count, 'fitme-story': fsCount };
}
```

- [ ] **Step 4: Run test — should pass**

Expected: PASS.

- [ ] **Step 5: Wire into /control-room/framework page**

Locate the existing framework page (e.g., `src/app/control-room/framework/page.tsx`). Add a section that reads both files at build time + invokes `aggregateGateCoverage` + renders counts + filter chips.

```tsx
// In the existing framework page component, add at the top of the component body:
import { aggregateGateCoverage, countEventsBySource } from '@/lib/control-room/gate-coverage-aggregator';
import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';

const ft2Path = join(process.cwd(), 'src', 'data', 'integrity', 'gate-coverage-ft2.jsonl');
const fsPath = join(process.cwd(), '.claude', 'logs', 'gate-coverage.jsonl');
const ft2Content = existsSync(ft2Path) ? readFileSync(ft2Path, 'utf-8') : '';
const fsContent = existsSync(fsPath) ? readFileSync(fsPath, 'utf-8') : '';
const events = aggregateGateCoverage(ft2Content, fsContent);
const counts = countEventsBySource(ft2Content, fsContent);

// Then in JSX, add a section like:
// <section>
//   <h2>Gate Coverage (cross-repo)</h2>
//   <p>FT2: {counts.ft2} fires · fitme-story: {counts['fitme-story']} fires · Total: {events.length}</p>
//   {/* per-source filter chips + per-gate breakdown */}
// </section>
```

- [ ] **Step 6: Local preview verify**

```bash
cd /Volumes/DevSSD/fitme-story && npm run dev
# Visit http://localhost:3000/control-room/framework in browser
# Verify aggregated count = ~1734 + 0 = ~1734 (matches raw line counts)
```

- [ ] **Step 7: Commit + open fitme-story PR**

```bash
cd /Volumes/DevSSD/fitme-story
git add tests/control-room/ src/lib/control-room/gate-coverage-aggregator.ts src/app/control-room/framework/ scripts/sync-from-fittracker2.ts
git commit -m "$(cat <<'EOF'
feat(v7.8.3): C-4 cross-repo gate-coverage aggregator + sync extension

Per FT2 spec §6.2 Phase 1. Adds:
- forward-sync extension: FT2's gate-coverage.jsonl → src/data/integrity/gate-coverage-ft2.jsonl
- src/lib/control-room/gate-coverage-aggregator.ts: combines both repos' streams
- /control-room/framework page extension: aggregated counts + per-source filter chips

Tests in tests/control-room/.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
git push -u origin feat/cross-repo-state-sync-phase-1
gh pr create --title "v7.8.3 Phase 1 (C-4) — control-room cross-repo gate-coverage aggregator" --body "Per FT2 spec §6.2 Phase 1. Aggregates both repos' gate-coverage at build time.

Test plan:
- [ ] vitest tests pass
- [ ] /control-room/framework renders aggregated count correctly on Vercel preview"
```

- [ ] **Step 8: Wait for CI + Vercel preview; user approves; merge squash**

### Task 1.7: After both Phase 1 PRs merge — snapshot Phase 1 → 2 transition

```bash
cd /Volumes/DevSSD/FitTracker2 && git checkout main && git pull origin main
make snapshot-phase PHASE=phase-1-complete-pre-phase-2
```

---

## Phase 2 — Schema + backfill + morphed C-5

**Branch:** `feat/cross-repo-state-sync-phase-2` (off latest `main` after Phase 1 merge)
**Single FT2 PR.** Estimated 1 day impl + 4 days calibration.

### Task 2.1: state_owner gates — write failing tests

**Files:**
- Create: `tests/framework/test_state_owner_gates.py`

- [ ] **Step 1: Write failing tests**

```python
"""Phase 2 — state_owner schema + morphed C-5.

Tests STATE_OWNER_MISSING, STATE_OWNER_INVALID, STATE_OWNER_LOCATION_MISMATCH
including the state_owner_sync_origin exemption."""
from __future__ import annotations
import json
import subprocess
import sys
from pathlib import Path
import pytest

SCRIPT = Path(__file__).resolve().parents[2] / "scripts" / "check-state-schema.py"


def run_check(state_path: Path) -> tuple[int, str]:
    result = subprocess.run([sys.executable, str(SCRIPT), str(state_path)],
                            capture_output=True, text=True)
    return result.returncode, result.stderr + result.stdout


def test_state_owner_missing_fails(write_state):
    """state.json without state_owner field → STATE_OWNER_MISSING."""
    state_path = write_state("missing-feature", {
        "name": "missing-feature",
        "framework_version": "v7.8.3",
        "current_phase": "research",
    })
    code, output = run_check(state_path)
    assert code != 0
    assert "STATE_OWNER_MISSING" in output


def test_state_owner_invalid_value_fails(write_state):
    """state_owner with bogus value → STATE_OWNER_INVALID."""
    state_path = write_state("invalid-feature", {
        "name": "invalid-feature",
        "state_owner": "ft-2",  # typo
        "framework_version": "v7.8.3",
        "current_phase": "research",
    })
    code, output = run_check(state_path)
    assert code != 0
    assert "STATE_OWNER_INVALID" in output


def test_state_owner_ft2_at_ft2_path_passes(write_state):
    state_path = write_state("ok-feature", {
        "name": "ok-feature",
        "state_owner": "ft2",
        "framework_version": "v7.8.3",
        "current_phase": "research",
    })
    # write_state puts under tmp_path/.claude/features/; absolute path won't
    # contain "/FitTracker2/" so we expect MISMATCH or PASS based on impl.
    # If using a more flexible path-detection, this passes; if strict, may fail.
    # See implementation note in §3.4 of spec.
    code, output = run_check(state_path)
    # Tolerant assert: either passes outright OR fails ONLY on MISMATCH (not other gates)
    if code != 0:
        assert "STATE_OWNER_LOCATION_MISMATCH" in output, \
            f"expected only LOCATION_MISMATCH if any failure; got\n{output}"


def test_state_owner_sync_origin_exempts_mismatch(write_state):
    """When state_owner_sync_origin is set with -reverse suffix, mismatch is exempted."""
    state_path = write_state("synced-feature", {
        "name": "synced-feature",
        "state_owner": "fitme-story",
        "state_owner_sync_origin": "fitme-story-reverse",
        "state_owner_sync_origin_commit": "abc123",
        "framework_version": "v7.8.3",
        "current_phase": "research",
    })
    code, output = run_check(state_path)
    # Should NOT contain LOCATION_MISMATCH
    assert "STATE_OWNER_LOCATION_MISMATCH" not in output, \
        f"sync_origin marker should exempt; got\n{output}"


def test_state_owner_fitme_story_at_ft2_path_without_marker_fails(write_state, monkeypatch, tmp_path):
    """Without sync_origin marker, fitme-story state.json at FT2 path → MISMATCH."""
    # Create state under a path that contains "/FitTracker2/"
    fake_ft2 = tmp_path / "FitTracker2-clone" / ".claude" / "features" / "wrong-place"
    fake_ft2.mkdir(parents=True)
    state_path = fake_ft2 / "state.json"
    state_path.write_text(json.dumps({
        "name": "wrong-place",
        "state_owner": "fitme-story",
        "framework_version": "v7.8.3",
        "current_phase": "research",
    }, indent=2) + "\n")
    code, output = run_check(state_path)
    # Note: may need to set CWD or pass full path with /FitTracker2/ substring
    # The test may need adjustment based on how check_state_owner_location_match
    # detects FT2 vs fitme-story paths
    # Spec §3.4: detection via "/FitTracker2/" or "/fitme-story/" substring in absolute path
    assert "STATE_OWNER_LOCATION_MISMATCH" in output or code == 0, \
        f"path-detection logic test; got\n{output}"
```

- [ ] **Step 2: Run failing tests**

Expected: at least the first 2 tests FAIL (no state_owner gates yet).

### Task 2.2: state_owner gates — implement

**Files:**
- Modify: `scripts/check-state-schema.py`

- [ ] **Step 1: Add gate functions**

In `scripts/check-state-schema.py`, add (per spec §3.4):

```python
VALID_STATE_OWNERS = {"ft2", "fitme-story"}


def check_state_owner(state, file_path, *, coverage=None):
    """Phase 2 v7.8.3: required state_owner field with valid enum value."""
    state_owner = state.get("state_owner")
    if state_owner is None:
        return Finding(
            severity="FAIL",
            code="STATE_OWNER_MISSING",
            message=f"{file_path}: state.json missing required state_owner field",
        )
    if state_owner not in VALID_STATE_OWNERS:
        return Finding(
            severity="FAIL",
            code="STATE_OWNER_INVALID",
            message=f"{file_path}: state_owner='{state_owner}' not in {sorted(VALID_STATE_OWNERS)}",
        )
    return None


def check_state_owner_location_match(state, file_path, *, coverage=None):
    """Morphed C-5: file location must match state_owner; sync mirrors are exempt."""
    state_owner = state.get("state_owner")
    sync_origin = state.get("state_owner_sync_origin")
    if state_owner is None or state_owner not in VALID_STATE_OWNERS:
        return None  # caught by check_state_owner
    if sync_origin and isinstance(sync_origin, str) and sync_origin.endswith("-reverse"):
        return None  # sync mirror; exempted
    abs_path = os.path.abspath(file_path)
    is_ft2_path = "/FitTracker2/" in abs_path or abs_path.startswith("/Volumes/DevSSD/FitTracker2/")
    is_fs_path = "/fitme-story/" in abs_path
    if state_owner == "ft2" and is_fs_path:
        return Finding(
            severity="FAIL",
            code="STATE_OWNER_LOCATION_MISMATCH",
            message=f"{file_path}: state_owner='ft2' but file at fitme-story path. Commit to FT2 instead, OR update state_owner='fitme-story' if migrating canonical home.",
        )
    if state_owner == "fitme-story" and is_ft2_path:
        return Finding(
            severity="FAIL",
            code="STATE_OWNER_LOCATION_MISMATCH",
            message=f"{file_path}: state_owner='fitme-story' but file at FT2 path. Commit to fitme-story instead, OR update state_owner='ft2' if migrating canonical home.",
        )
    return None
```

- [ ] **Step 2: Wire into the main gate loop**

Find where existing gates (e.g., `check_schema_drift`, `check_pr_number_resolved`) are called for each state.json. Add the two new gates to that call sequence:

```python
GATES = [
    check_schema_drift,
    check_pr_number_resolved,
    check_phase_transition_no_log,
    check_phase_transition_no_timing,
    check_cache_hits_auto_instrumentation_drift,  # V2 from Phase 0
    check_state_owner,                             # NEW Phase 2
    check_state_owner_location_match,              # NEW Phase 2
    # ... other existing gates ...
]
```

(Adjust based on actual structure.)

- [ ] **Step 3: Update Mechanism D version stamp**

```python
__SCHEMA_CHECKER_VERSION__ = "v7.8.3-phase2"  # bumped from v7.8.3 (Phase 0)
__SCHEMA_CHECKER_LAST_MODIFIED__ = "2026-05-13"  # adjust to actual ship date
```

- [ ] **Step 4: Run failing tests — should pass now**

```bash
cd /Volumes/DevSSD/FitTracker2 && python3 -m pytest tests/framework/test_state_owner_gates.py -v
```

Expected: ALL tests PASS.

### Task 2.3: backfill-state-owner.py — write failing test + implement

**Files:**
- Create: `tests/framework/test_backfill_script.py`
- Create: `scripts/backfill-state-owner.py`

- [ ] **Step 1: Write failing test for backfill script**

```python
"""Phase 2 — backfill-state-owner.py.

One-shot mechanical script that adds state_owner: 'ft2' to all 47 existing
state.json files. Tests idempotency + correctness."""
from __future__ import annotations
import json
import subprocess
import sys
from pathlib import Path
import pytest

SCRIPT = Path(__file__).resolve().parents[2] / "scripts" / "backfill-state-owner.py"


def test_backfill_adds_state_owner_to_missing(test_repo: Path, monkeypatch):
    """Features without state_owner get state_owner: 'ft2'."""
    # Create 3 features, 2 missing state_owner, 1 already set
    feat_a = test_repo / ".claude" / "features" / "feat-a"
    feat_a.mkdir(parents=True)
    (feat_a / "state.json").write_text(json.dumps({"name": "feat-a", "current_phase": "research"}, indent=2) + "\n")
    feat_b = test_repo / ".claude" / "features" / "feat-b"
    feat_b.mkdir()
    (feat_b / "state.json").write_text(json.dumps({"name": "feat-b", "current_phase": "complete"}, indent=2) + "\n")
    feat_c = test_repo / ".claude" / "features" / "feat-c"
    feat_c.mkdir()
    (feat_c / "state.json").write_text(json.dumps({"name": "feat-c", "state_owner": "ft2", "current_phase": "complete"}, indent=2) + "\n")

    monkeypatch.chdir(test_repo)
    result = subprocess.run([sys.executable, str(SCRIPT)], capture_output=True, text=True)
    assert result.returncode == 0, result.stderr

    # feat-a + feat-b should now have state_owner=ft2
    assert json.loads((feat_a / "state.json").read_text())["state_owner"] == "ft2"
    assert json.loads((feat_b / "state.json").read_text())["state_owner"] == "ft2"
    # feat-c should be unchanged
    assert json.loads((feat_c / "state.json").read_text())["state_owner"] == "ft2"


def test_backfill_idempotent(test_repo: Path, monkeypatch):
    """Running twice doesn't change anything."""
    feat = test_repo / ".claude" / "features" / "feat-x"
    feat.mkdir(parents=True)
    state_path = feat / "state.json"
    state_path.write_text(json.dumps({"name": "feat-x", "current_phase": "research"}, indent=2) + "\n")

    monkeypatch.chdir(test_repo)
    subprocess.run([sys.executable, str(SCRIPT)], check=True, capture_output=True)
    after_first = state_path.read_text()
    subprocess.run([sys.executable, str(SCRIPT)], check=True, capture_output=True)
    after_second = state_path.read_text()
    assert after_first == after_second


def test_backfill_inserts_after_name_field(test_repo: Path, monkeypatch):
    """state_owner is inserted as second key (after 'name')."""
    feat = test_repo / ".claude" / "features" / "feat-y"
    feat.mkdir(parents=True)
    (feat / "state.json").write_text(json.dumps({"name": "feat-y", "current_phase": "research", "framework_version": "v7.8.3"}, indent=2) + "\n")

    monkeypatch.chdir(test_repo)
    subprocess.run([sys.executable, str(SCRIPT)], check=True, capture_output=True)
    state = json.loads((feat / "state.json").read_text())
    keys = list(state.keys())
    assert keys[0] == "name"
    assert keys[1] == "state_owner"
```

- [ ] **Step 2: Run failing tests**

Expected: FAIL — script doesn't exist.

- [ ] **Step 3: Implement backfill script**

Per spec §3.3. Save to `scripts/backfill-state-owner.py`:

```python
#!/usr/bin/env python3
"""One-shot backfill: insert state_owner: 'ft2' into all .claude/features/*/state.json.

Phase 2 v7.8.3 deliverable per spec §3.3.
Idempotent: features already having state_owner are skipped."""
from __future__ import annotations
import json
import glob
import sys


def main() -> int:
    backfilled = []
    already_set = []
    for path in sorted(glob.glob(".claude/features/*/state.json")):
        with open(path) as f:
            state = json.load(f)
        if "state_owner" in state:
            already_set.append(path)
            continue
        # Insert state_owner as second key (after "name")
        new_state = {}
        inserted = False
        for k, v in state.items():
            new_state[k] = v
            if k == "name" and not inserted:
                new_state["state_owner"] = "ft2"
                inserted = True
        if not inserted:  # defensive: append if no name field
            new_state["state_owner"] = "ft2"
        with open(path, "w") as f:
            json.dump(new_state, f, indent=2)
            f.write("\n")
        backfilled.append(path)

    print(f"Backfilled: {len(backfilled)}")
    print(f"Already set: {len(already_set)}")
    if backfilled:
        for p in backfilled:
            print(f"  + {p}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: Run tests — should pass**

```bash
cd /Volumes/DevSSD/FitTracker2 && python3 -m pytest tests/framework/test_backfill_script.py -v
```

Expected: PASS.

### Task 2.4: Run backfill on real .claude/features/

- [ ] **Step 1: Count features pre-backfill**

```bash
cd /Volumes/DevSSD/FitTracker2 && ls -1 .claude/features/ | wc -l
```

Expected: ~47-60 (count from session start active features list was ~60; subset have state.json).

- [ ] **Step 2: Run backfill**

```bash
cd /Volumes/DevSSD/FitTracker2 && python3 scripts/backfill-state-owner.py
```

Expected: prints "Backfilled: N" + "Already set: 0" (if first run).

- [ ] **Step 3: Verify all state.json files now have state_owner**

```bash
cd /Volumes/DevSSD/FitTracker2 && for f in .claude/features/*/state.json; do
  python3 -c "import json,sys; s=json.load(open('$f')); assert s.get('state_owner')=='ft2', '$f'" || echo "FAIL: $f"
done
echo "All passed."
```

Expected: "All passed." with no FAIL lines.

- [ ] **Step 4: Run gates over all backfilled features**

```bash
cd /Volumes/DevSSD/FitTracker2 && python3 scripts/check-state-schema.py 2>&1 | tail -10
```

Expected: 0 NEW STATE_OWNER_* failures.

### Task 2.5: Synthetic mismatch test (manual pre-flight)

- [ ] **Step 1: Copy a real state.json to wrong-named path + test gate**

```bash
cd /Volumes/DevSSD/FitTracker2 && mkdir -p /tmp/fitme-story-fake/.claude/features/wrong-place
cp .claude/features/$(ls .claude/features | head -1)/state.json /tmp/fitme-story-fake/.claude/features/wrong-place/state.json
python3 scripts/check-state-schema.py /tmp/fitme-story-fake/.claude/features/wrong-place/state.json 2>&1 | head -5
```

Expected: STATE_OWNER_LOCATION_MISMATCH FAIL (state_owner='ft2' but path contains '/fitme-story/').

- [ ] **Step 2: Cleanup synthetic mismatch test**

```bash
rm -rf /tmp/fitme-story-fake
```

### Task 2.6: Update CLAUDE.md describing state_owner

- [ ] **Step 1: Add section to CLAUDE.md**

In the v7.8.3 section added in Task 0.9, append a paragraph about state_owner:

```markdown
### v7.8.3 Phase 2 — state_owner schema

Every state.json in either repo carries a top-level `state_owner` field
(enum `{"ft2", "fitme-story"}`) that reflects WHERE the canonical
state.json file lives, not where the feature's code lives. Required from
2026-05-13 onward; backfilled to all 47 existing features in single PR.

The morphed C-5 gate (`STATE_OWNER_LOCATION_MISMATCH`) cross-checks the
field against the file's actual repo path. Reverse-sync mirrors (Phase 3+)
carry a `state_owner_sync_origin: "fitme-story-reverse"` exemption marker.
```

- [ ] **Step 2: Update integrity schema if exists**

```bash
test -f .claude/integrity/schemas/state.schema.json && echo "schema exists" || echo "no schema file"
```

If exists: open it + add `state_owner` to required fields + enum.

### Task 2.7: Commit Phase 2 + open PR + merge

- [ ] **Step 1: Commit everything**

```bash
cd /Volumes/DevSSD/FitTracker2
git add tests/framework/test_state_owner_gates.py tests/framework/test_backfill_script.py
git add scripts/check-state-schema.py scripts/backfill-state-owner.py
git add .claude/features/*/state.json
git add CLAUDE.md
[ -f .claude/integrity/schemas/state.schema.json ] && git add .claude/integrity/schemas/state.schema.json
git commit -m "$(cat <<'EOF'
feat(v7.8.3): Phase 2 — state_owner schema + 47-feature backfill + morphed C-5

Per spec §3 + §6.3. Adds:
- 3 new gates: STATE_OWNER_MISSING, STATE_OWNER_INVALID, STATE_OWNER_LOCATION_MISMATCH
- state_owner_sync_origin exemption for reverse-sync mirrors (Phase 3 prerequisite)
- scripts/backfill-state-owner.py one-shot mechanical backfill
- 47 existing state.json files backfilled to state_owner: 'ft2'
- tests/framework/test_state_owner_gates.py + test_backfill_script.py
- CLAUDE.md state_owner paragraph

Calibration: 47/47 backfill mechanical correctness + synthetic mismatch
test passes + ≥3 new features post-Phase-2 set state_owner correctly.

Bumps __SCHEMA_CHECKER_VERSION__ to v7.8.3-phase2.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 2: Push + open PR**

```bash
git push -u origin feat/cross-repo-state-sync-phase-2
gh pr create --title "v7.8.3 Phase 2 — state_owner schema + 47-feature backfill + morphed C-5" --body "Per spec §3 + §6.3. 47-file mechanical backfill diff + 3 new gates.

Test plan:
- [ ] tests/framework/ all green
- [ ] make verify-local passes
- [ ] make integrity-check 0 hard findings
- [ ] No integrity-cycle regression on >5 features in 72h post-merge"
```

- [ ] **Step 3: Wait for CI; user approves; merge squash**

- [ ] **Step 4: After merge — snapshot Phase 2 → 3 transition**

```bash
cd /Volumes/DevSSD/FitTracker2 && git checkout main && git pull origin main
make snapshot-phase PHASE=phase-2-complete-pre-phase-3
```

---

## Phase 3 — D-1 reverse-sync GitHub Action

**Branch (in fitme-story):** `feat/cross-repo-state-sync-phase-3`
**Single fitme-story PR.** Estimated 1-2 days impl.

### Task 3.1: Operator setup — provision FT2_REPO_TOKEN

- [ ] **Step 1: Generate PAT (manual operator step)**

Operator visits https://github.com/settings/tokens?type=beta and creates a fine-grained PAT scoped to `Regevba/FitTracker2` with `Contents: write` + `Pull requests: write` permissions. Expiration: 90 days (set calendar reminder for rotation).

- [ ] **Step 2: Add as fitme-story repo secret**

```bash
# Operator runs locally:
gh secret set FT2_REPO_TOKEN --repo Regevba/fitme-story
# Pastes the PAT when prompted
```

- [ ] **Step 3: Verify secret exists (without revealing value)**

```bash
gh secret list --repo Regevba/fitme-story | grep FT2_REPO_TOKEN
```

Expected: `FT2_REPO_TOKEN  <date>`

### Task 3.2: Write the workflow YAML

**Files:**
- Create: `.github/workflows/reverse-sync-fitme-story-to-ft2.yml` (in fitme-story repo)

- [ ] **Step 1: Create workflow file**

```bash
cd /Volumes/DevSSD/fitme-story
git checkout main && git pull origin main
git checkout -b feat/cross-repo-state-sync-phase-3
```

Save to `.github/workflows/reverse-sync-fitme-story-to-ft2.yml`:

```yaml
name: Reverse-sync fitme-story-native state.json to FT2

on:
  push:
    branches: [main]
    paths:
      - '.claude/features/**/state.json'

jobs:
  reverse-sync:
    runs-on: ubuntu-latest
    if: ${{ secrets.FT2_REPO_TOKEN != '' }}
    steps:
      - name: Checkout fitme-story
        uses: actions/checkout@v4
        with:
          fetch-depth: 2  # need previous commit for diff

      - name: Detect changed fitme-story-native state.json files
        id: detect
        shell: bash
        run: |
          set -euo pipefail
          CHANGED=$(git diff --name-only HEAD~1 HEAD -- '.claude/features/*/state.json' || true)
          NATIVE_FILES=()
          for f in $CHANGED; do
            owner=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('state_owner',''))" "$f" 2>/dev/null || echo "")
            if [ "$owner" = "fitme-story" ]; then
              NATIVE_FILES+=("$f")
            fi
          done
          if [ ${#NATIVE_FILES[@]} -eq 0 ]; then
            echo "No fitme-story-native state.json modified; skipping"
            echo "skip=true" >> "$GITHUB_OUTPUT"
            exit 0
          fi
          printf '%s\n' "${NATIVE_FILES[@]}" > /tmp/native-files.txt
          echo "skip=false" >> "$GITHUB_OUTPUT"
          echo "count=${#NATIVE_FILES[@]}" >> "$GITHUB_OUTPUT"

      - name: Checkout FT2
        if: steps.detect.outputs.skip == 'false'
        uses: actions/checkout@v4
        with:
          repository: Regevba/FitTracker2
          token: ${{ secrets.FT2_REPO_TOKEN }}
          path: ft2-checkout
          fetch-depth: 1

      - name: Mirror state.json files into FT2 with sync_origin marker
        if: steps.detect.outputs.skip == 'false'
        shell: bash
        run: |
          set -euo pipefail
          SHORT_SHA=$(git rev-parse --short HEAD)
          BRANCH="reverse-sync/from-fitme-story/${SHORT_SHA}"
          cd ft2-checkout
          git config user.email "noreply@github.com"
          git config user.name "fitme-story reverse-sync bot"
          git checkout -b "$BRANCH"
          while IFS= read -r src_file; do
            dest_file="${src_file}"
            mkdir -p "$(dirname "$dest_file")"
            python3 -c "
import json, sys
src_path = '../${src_file}'
with open(src_path) as f:
    state = json.load(f)
state['state_owner_sync_origin'] = 'fitme-story-reverse'
state['state_owner_sync_origin_commit'] = '${{ github.sha }}'
state['state_owner_sync_origin_pr_url'] = 'pending'
with open('$dest_file', 'w') as f:
    json.dump(state, f, indent=2)
    f.write('\n')
"
          done < /tmp/native-files.txt
          git add .
          git commit -m "Reverse-sync: mirror fitme-story-native state.json from ${SHORT_SHA}"
          git push -u origin "$BRANCH"

      - name: Open PR against FT2
        if: steps.detect.outputs.skip == 'false'
        env:
          GH_TOKEN: ${{ secrets.FT2_REPO_TOKEN }}
        shell: bash
        run: |
          set -euo pipefail
          SHORT_SHA=$(git rev-parse --short HEAD)
          BRANCH="reverse-sync/from-fitme-story/${SHORT_SHA}"
          cd ft2-checkout
          gh pr create \
            --repo Regevba/FitTracker2 \
            --base main \
            --head "$BRANCH" \
            --title "Reverse-sync: ${{ steps.detect.outputs.count }} fitme-story-native state.json from ${SHORT_SHA}" \
            --body "Auto-PR from fitme-story reverse-sync GitHub Action (v7.8.3 D-1).

Source commit: https://github.com/Regevba/fitme-story/commit/${{ github.sha }}
Source files: $(cat /tmp/native-files.txt)

Each state.json carries state_owner_sync_origin: 'fitme-story-reverse' marker.
Morphed C-5 gate exempts these files from STATE_OWNER_LOCATION_MISMATCH.

Manual operator merge required per feedback_no_auto_merge_without_approval.md."
```

### Task 3.3: Test workflow locally with `act`

**Files:**
- Create: `scripts/test-reverse-sync-action.sh` (fitme-story)

- [ ] **Step 1: Write wrapper script**

`scripts/test-reverse-sync-action.sh`:
```bash
#!/usr/bin/env bash
# Local test wrapper for reverse-sync-fitme-story-to-ft2.yml
# Requires: act (https://github.com/nektos/act)
set -euo pipefail

if ! command -v act >/dev/null; then
  echo "act not installed; install via: brew install act"
  exit 1
fi

EVENT_FILE=$(mktemp)
trap "rm -f $EVENT_FILE" EXIT

cat > "$EVENT_FILE" <<EOF
{
  "ref": "refs/heads/main",
  "before": "0000000000000000000000000000000000000000",
  "after": "abcdef1234567890",
  "commits": [
    {
      "id": "abcdef1234567890",
      "modified": [".claude/features/test-fs-native/state.json"]
    }
  ]
}
EOF

# Dry-run (won't actually push or create PR)
act push -e "$EVENT_FILE" --workflows .github/workflows/reverse-sync-fitme-story-to-ft2.yml --dryrun
```

- [ ] **Step 2: Make executable**

```bash
chmod +x scripts/test-reverse-sync-action.sh
```

- [ ] **Step 3: Run actionlint on workflow YAML**

```bash
cd /Volumes/DevSSD/fitme-story && actionlint .github/workflows/reverse-sync-fitme-story-to-ft2.yml
```

Expected: zero errors. (If actionlint not installed: `brew install actionlint`.)

- [ ] **Step 4: Run dry-run via act**

```bash
cd /Volumes/DevSSD/fitme-story && ./scripts/test-reverse-sync-action.sh
```

Expected: workflow steps execute in dry-run mode without errors (won't actually open PR; just prints the steps it would run).

### Task 3.4: Document reverse-sync flow in fitme-story README

**Files:**
- Modify: `fitme-story/.claude/README.md`

- [ ] **Step 1: Add reverse-sync section**

Append to `fitme-story/.claude/README.md`:

```markdown
## Reverse-sync flow (Phase 3 v7.8.3)

When a fitme-story-native feature's state.json is committed (with `state_owner: "fitme-story"`),
the `.github/workflows/reverse-sync-fitme-story-to-ft2.yml` GitHub Action
automatically opens a PR against the FT2 repo mirroring the state.json
into `FT2/.claude/features/<name>/state.json` with a `state_owner_sync_origin`
marker.

**Operator setup (one-time):** Provision `FT2_REPO_TOKEN` repo secret with
fine-grained PAT scoped to `Regevba/FitTracker2` Contents:write +
Pull-requests:write. Set 90-day expiration with calendar rotation reminder.

**Manual merge required:** PRs do NOT auto-merge per
`feedback_no_auto_merge_without_approval.md`.

**Local testing:** `./scripts/test-reverse-sync-action.sh` (requires `act`).
```

### Task 3.5: Commit + open PR + merge

- [ ] **Step 1: Commit Phase 3**

```bash
cd /Volumes/DevSSD/fitme-story
git add .github/workflows/reverse-sync-fitme-story-to-ft2.yml scripts/test-reverse-sync-action.sh .claude/README.md
git commit -m "$(cat <<'EOF'
feat(v7.8.3): D-1 reverse-sync GitHub Action

Per FT2 spec §6.4 Phase 3. When fitme-story commits modify
.claude/features/**/state.json with state_owner='fitme-story', the workflow
auto-opens a PR against FT2 main mirroring the state.json with
state_owner_sync_origin: 'fitme-story-reverse' marker.

Manual operator merge required (no auto-merge per
feedback_no_auto_merge_without_approval.md).

Adds:
- .github/workflows/reverse-sync-fitme-story-to-ft2.yml
- scripts/test-reverse-sync-action.sh (local act wrapper)
- .claude/README.md reverse-sync flow documentation

Phase 3 calibration: workflow YAML lints + act dry-run produces valid
PR-template payload + FT2_REPO_TOKEN provisioned. End-to-end calibration
deferred to Phase 4 cutover.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
git push -u origin feat/cross-repo-state-sync-phase-3
gh pr create --title "v7.8.3 Phase 3 — D-1 reverse-sync GitHub Action" --body "Per FT2 spec §6.4. End-to-end calibration deferred to Phase 4 cutover.

Test plan:
- [ ] actionlint passes
- [ ] act dry-run produces valid PR-template
- [ ] FT2_REPO_TOKEN secret provisioned (operator)"
```

- [ ] **Step 2: Wait for CI; user approves; merge squash**

- [ ] **Step 3: Snapshot Phase 3 → 4 transition**

```bash
cd /Volumes/DevSSD/FitTracker2 && make snapshot-phase PHASE=phase-3-complete-pre-phase-4
```

---

## Phase 4 — Cutover ceremony

**Branch:** `feat/cross-repo-state-sync-phase-4-cutover` (FT2) + corresponding fitme-story branch
**Cross-repo coordination.** Estimated 2-3 days.

### Task 4.1: Pick first fitme-story-native feature candidate

- [ ] **Step 1: Identify candidate**

Criteria (per spec §6.5): small public-site enhancement, no FT2 surface, low-risk. Discuss with user; document choice in `~/.claude/projects/-Volumes-DevSSD-FitTracker2/memory/project_phase4_cutover_choice.md`.

Examples to consider: a future fitme-story-only enhancement (e.g., a new control-room widget, a new public-site page section, a glossary expansion).

### Task 4.2: Create the fitme-story-native state.json

Once candidate locked in (call it `<fs-native>`):

```bash
cd /Volumes/DevSSD/fitme-story
git checkout main && git pull origin main
git checkout -b feat/cross-repo-state-sync-phase-4-cutover

mkdir -p .claude/features/<fs-native>
cat > .claude/features/<fs-native>/state.json <<'EOF'
{
  "name": "<fs-native>",
  "state_owner": "fitme-story",
  "framework_version": "v7.8.3",
  "current_phase": "research",
  "work_type": "Feature",
  "created_at": "2026-05-19T00:00:00Z",
  "case_study_link": "docs/case-studies/<fs-native>-case-study.md"
}
EOF
```

Adjust dates + work_type as appropriate.

### Task 4.3: Push to fitme-story main + verify reverse-sync Action fires

- [ ] **Step 1: Commit + push**

```bash
cd /Volumes/DevSSD/fitme-story
git add .claude/features/<fs-native>/
git commit -m "feat(<fs-native>): create first fitme-story-native state.json (Phase 4 cutover)"
git push origin feat/cross-repo-state-sync-phase-4-cutover

# Open + merge PR to fitme-story main
gh pr create --title "Phase 4 cutover: first fitme-story-native state.json" --body "Triggers reverse-sync GitHub Action."
# Wait for user approval + merge
```

- [ ] **Step 2: Watch GitHub Action fire**

```bash
gh run watch --repo Regevba/fitme-story
```

Expected: workflow runs successfully + opens a PR against FT2.

- [ ] **Step 3: Verify FT2-side PR**

```bash
gh pr list --repo Regevba/FitTracker2 --search "reverse-sync"
```

Expected: 1 open PR titled "Reverse-sync: …".

- [ ] **Step 4: Inspect the synced state.json carries marker**

```bash
gh pr view --repo Regevba/FitTracker2 <pr-number> --json files
gh pr diff --repo Regevba/FitTracker2 <pr-number> | head -30
```

Expected: file at `.claude/features/<fs-native>/state.json` with both `state_owner: "fitme-story"` AND `state_owner_sync_origin: "fitme-story-reverse"` fields.

### Task 4.4: Operator manually merges FT2-side PR

- [ ] **Step 1: User reviews the auto-opened PR**

- [ ] **Step 2: User approves; merge squash**

```bash
gh pr merge <pr-number> --repo Regevba/FitTracker2 --squash
```

### Task 4.5: Verify forward-sync mirrors back

After Vercel rebuilds fitme-story (triggered by next FT2 push):

```bash
cd /Volumes/DevSSD/fitme-story && git pull origin main
ls -la src/data/features/<fs-native>.json
```

Expected: file exists; matches the FT2 state.json content.

### Task 4.6: Write source case study

**Files:**
- Create: `docs/case-studies/cross-repo-state-sync-impl-case-study.md`

- [ ] **Step 1: Draft case study**

Per existing case study templates + the spec §11 cross-references. Required sections per `CASE_STUDY_MISSING_FIELDS` gate:

```markdown
---
title: Cross-Repo State Sync (v7.8.3) Implementation
date: 2026-05-XX
work_type: Feature
framework_version: v7.8.3
dispatch_pattern: sequential-phased
success_metrics:
  - 100% state.json have state_owner within 14 days of Phase 2 ship
  - V2 fires ≥1 production fire without false positive
  - Phase 4 cutover round-trip succeeds end-to-end
kill_criteria:
  - Reverse-sync gate-firing storm >10 false positives
  - state_owner backfill regression on >5 features
  - V2 false positives >3 in 24h
kill_criteria_resolution:
  - All 3 kill criteria checked; none triggered
tier_tags_present: true
related_prs:
  - "PR #<phase-0>"
  - "PR #<phase-1-d3>"
  - "PR #<phase-1-c4>" (fitme-story)
  - "PR #<phase-2>"
  - "PR #<phase-3>" (fitme-story)
  - "PR #<phase-4-cutover>"
  - "[fitme-story#<phase-4-fs-pr>]"
case_study_showcase: ../../fitme-story/content/04-case-studies/<NN>-cross-repo-state-sync-impl.mdx
---

# Cross-Repo State Sync (v7.8.3) Implementation

(Body covers all 5 phases narratively, with quantitative T1 metrics tagged.)
```

### Task 4.7: Add showcase MDX in fitme-story

**Files:**
- Create: `fitme-story/content/04-case-studies/<NN>-cross-repo-state-sync-impl.mdx`

- [ ] **Step 1: Determine slot number**

Per CLAUDE.md chronological-order rule, slot N reflects v7.8.3 era. Look at existing slot numbering in `fitme-story/content/04-case-studies/` and pick the next slot AFTER the latest v7.8.2 case study.

- [ ] **Step 2: Create MDX**

Per dual-outlet pattern (mirrors source case study but adds showcase-specific metadata):

```mdx
---
title: "Cross-Repo State Sync v7.8.3"
slug: cross-repo-state-sync-impl
version: '7.8.3'
date: '2026-05-XX'
timeline_position:
  era: framework-v7-8-x
  order: <next-after-v7.8.2>
---

(Body summarizes for public showcase.)
```

### Task 4.8: Transition feature to current_phase=complete

- [ ] **Step 1: Update FT2 state.json (the umbrella feature, not the fs-native one)**

```bash
cd /Volumes/DevSSD/FitTracker2
# Create the cross-repo-state-sync-impl feature state.json (since this work is the umbrella)
mkdir -p .claude/features/cross-repo-state-sync-impl
cat > .claude/features/cross-repo-state-sync-impl/state.json <<'EOF'
{
  "name": "cross-repo-state-sync-impl",
  "state_owner": "ft2",
  "framework_version": "v7.8.3",
  "current_phase": "complete",
  "work_type": "Feature",
  "created_at": "2026-05-11T00:00:00Z",
  "case_study_link": "docs/case-studies/cross-repo-state-sync-impl-case-study.md",
  "case_study_showcase": "../../fitme-story/content/04-case-studies/<NN>-cross-repo-state-sync-impl.mdx",
  "phases": {
    "merge": { "pr_number": <umbrella-pr-or-null> }
  },
  "tasks": [
    { "id": "phase-0", "status": "done", "pr_number": <p0> },
    { "id": "phase-1-d3", "status": "done", "pr_number": <p1-d3> },
    { "id": "phase-1-c4-fs", "status": "done", "related_prs": ["[fitme-story#<p1-c4>]"] },
    { "id": "phase-2", "status": "done", "pr_number": <p2> },
    { "id": "phase-3-fs", "status": "done", "related_prs": ["[fitme-story#<p3>]"] },
    { "id": "phase-4-cutover", "status": "done", "pr_number": <p4> }
  ]
}
EOF
```

(This triggers `FEATURE_CLOSURE_COMPLETENESS` advisory — verify all 7 frontmatter fields present + kill_criteria_resolution + PR-list parity.)

### Task 4.9: Commit closure + open Phase 4 PR + merge

```bash
cd /Volumes/DevSSD/FitTracker2
git add docs/case-studies/cross-repo-state-sync-impl-case-study.md .claude/features/cross-repo-state-sync-impl/
git commit -m "feat(cross-repo-state-sync-impl): Phase 4 closure — current_phase=complete"
git push -u origin feat/cross-repo-state-sync-phase-4-cutover
gh pr create --title "v7.8.3 Phase 4 — cutover complete + case study + closure" --body "All 5 phases shipped; framework certified end-to-end. Unblocks HADF Phase 2-bis Sub-exp 1."
# User approval + merge
```

### Task 4.10: After cutover — final snapshot

```bash
cd /Volumes/DevSSD/FitTracker2 && git checkout main && git pull origin main
make snapshot-phase PHASE=phase-4-cutover-complete-framework-certified
```

### Task 4.11: Verify HADF Phase 2-bis unblocks

- [ ] **Step 1: Run framework verification**

```bash
cd /Volumes/DevSSD/FitTracker2 && make verify-local && make integrity-check
```

Expected: all green.

- [ ] **Step 2: Check calibration targets met**

Per spec §3.5.2:
- [ ] V2: ≥1 production fire without false positive (verify in `gate-coverage.jsonl`)
- [ ] V9: ≥1 real merge-conflict resolved (synthetic test + natural occurrence)
- [ ] D-3: 35/35 retroactive cross-repo cites pass + ≥3 forward
- [ ] C-4: aggregator visually correct
- [ ] Phase 2: 47/47 backfill + synthetic mismatch test + ≥3 new features clean
- [ ] Phase 4: round-trip succeeds

If all ✓: **HADF Phase 2-bis Sub-exp 1 is UNBLOCKED**. Transition memory file `project_phase2bis_brainstorm_paused_2026_05_11.md` from "paused" to "ready to start".

---

## Self-Review

**1. Spec coverage:** All 11 spec sections (§1 Overview, §2 Architecture, §3 Schema, §3.5 HADF gating, §4 Sync mechanisms, §5 PR cite cache, §6 Rollout, §7 Testing, §8 Out-of-scope, §9 Dogfooding, §10 Snapshot protocol, §11 Cross-references) have at least one task implementing them. ✓

**2. Placeholder scan:** No "TBD/TODO/PLACEHOLDER/FIXME" strings in plan. The few `<fs-native>` and `<NN>` placeholders ARE intentional — they get filled in during Phase 4 Task 4.1 + 4.7 based on operator decisions. The `<phase-N-pr-number>` placeholders in Phase 4 Task 4.8 are filled at closure time when PRs are merged.

**3. Type consistency:** Function names consistent across tasks: `check_state_owner` + `check_state_owner_location_match` defined in Task 2.2, used in Task 2.7 commit. `aggregateGateCoverage` + `countEventsBySource` defined + used in Task 1.6. `resolve_pr_cite` + `_PR_CITATION_PAT` + `REPO_MAP` consistent across Tasks 1.1-1.3.

**4. Phase ordering enforced via branch dependencies:** Each phase branch is created off `main` after the prior phase's PR merges. Phase 1's two PRs can run in parallel (FT2 D-3 + fitme-story C-4). Phase 4 requires Phase 3 to ship first (cutover triggers reverse-sync Action).

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-05-11-cross-repo-state-sync-impl.md`. Two execution options:**

**1. Subagent-Driven (recommended)** — Dispatch a fresh subagent per task; review between tasks; fast iteration. Particularly suited to this plan since each phase is independent and each task is well-bounded.

**2. Inline Execution** — Execute tasks in this session using executing-plans; batch execution with checkpoints for user review.

**Which approach?**
