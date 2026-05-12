#!/usr/bin/env python3
# __SCHEMA_CHECKER_VERSION__ = "v7.8.3-phase2"
"""
Validate `.claude/features/*/state.json` files against the canonical schema.

Canonical schema rules (enforced at write time via the pre-commit hook):

1. **SCHEMA_DRIFT** — use `current_phase`, not the legacy `phase` key.
   Surfaced by the 2026-04-21 structural meta-analysis (2 of 40 files used
   the legacy key); both since migrated.
2. **PR_NUMBER_UNRESOLVED** — if `phases.merge.pr_number` is set, verify the
   PR resolves via `gh pr view`. Closes Gemini audit Tier 1.2's
   "integrate with sources of truth" recommendation at write-time rather
   than only post-hoc on the 72h integrity cycle. Skipped gracefully if
   `gh` is unavailable (CI without GH_TOKEN, offline dev, etc.).
3. **PHASE_TRANSITION_NO_LOG** (Phase 1a, added 2026-04-24) — if
   `current_phase` changes vs the committed state.json, require a matching
   `phase_started` / `phase_approved` event in the feature's contemporaneous
   log file within `PHASE_EVENT_FRESHNESS_MIN` minutes. Promotes Tier 2.2
   contemporaneous logging from Class B (agent-dependent, silent gap) to
   Class A (mechanically enforced).
4. **PHASE_TRANSITION_NO_TIMING** (Phase 1b, added 2026-04-24) — if
   `current_phase` changes, require `timing.phases[OLD].ended_at` +
   `timing.phases[NEW].started_at` to be present and non-null. Promotes
   Tier 1.1 per-phase timing from narrative to mechanical.

Usage:
    scripts/check-state-schema.py                    # scan all state.json files
    scripts/check-state-schema.py <path> [<path>...] # validate specific files
    scripts/check-state-schema.py --staged           # validate git-staged files

Exit codes:
    0  all validated files pass all checks
    1  one or more files violate a check (message on stderr)
    2  usage error or missing file

Bypass (emergency only): `git commit --no-verify`. The 72h integrity cycle
still catches any drift introduced through bypass.
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

# Mechanism A (v7.8 §4.1): per-gate coverage tracking. Imported at module
# level so test_check_state_schema.py keeps working — gate functions accept
# an optional `coverage` kwarg defaulting to None (no behavior change when
# absent), and `validate_file` instantiates a tracker that persists across
# all the per-file calls within one validation run.
sys.path.insert(0, str(Path(__file__).resolve().parent))
from gate_coverage import GateCoverage  # noqa: E402


REPO_ROOT = Path(__file__).resolve().parent.parent
FEATURES_DIR = REPO_ROOT / ".claude" / "features"
LOGS_DIR = REPO_ROOT / ".claude" / "logs"
GATE_COVERAGE_LEDGER = LOGS_DIR / "gate-coverage.jsonl"

# Path to the T6 cu_v2 validator (hyphen prevents a direct import; we use
# importlib.util — same pattern used in test_check_state_schema.py to load
# check-state-schema.py itself).  The module is loaded once at first call and
# cached so the import overhead is paid only once per script invocation.
_VALIDATE_CU_V2_PATH = Path(__file__).resolve().parent / "validate-cu-v2.py"
_validate_cu_v2_module = None


def _get_validate_cu_v2():
    """Lazily load validate-cu-v2.py and return the module."""
    global _validate_cu_v2_module
    if _validate_cu_v2_module is None:
        import importlib.util
        spec = importlib.util.spec_from_file_location(
            "_validate_cu_v2", _VALIDATE_CU_V2_PATH
        )
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        _validate_cu_v2_module = mod
    return _validate_cu_v2_module

# How fresh the most-recent phase-transition log event must be to satisfy the
# PHASE_TRANSITION_NO_LOG check. 15 minutes is deliberately generous to
# accommodate multi-step commits (log first, then state.json, then commit)
# without false positives. The 72h cycle is the belt for anything slower.
PHASE_EVENT_FRESHNESS_MIN = 15

# v6.0 shipped 2026-04-16. Post-v6 features are expected to have at least one
# cache_hits[] entry recorded by the M1 instrumentation (scripts/log-cache-hit.py)
# before reaching current_phase=complete. Features created before this date are
# exempt — they predate the adoption requirement.
V6_SHIP_DATE = "2026-04-16"

# v7.8 ships Mechanism C — the PostToolUse:Read hook + observe-cache-hit.py
# that auto-collects cache_hits[] events without agent attention (closes the
# Class B writer-path gap, issue #140). Features whose entire active period
# predates MECHANISM_C_SHIP_DATE are exempt from CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT
# (formerly CACHE_HITS_EMPTY_POST_V6, promoted in v7.8.3): the
# auto-instrumentation that would have populated cache_hits[] mechanically did
# not exist during their lifecycle, so an empty array is "instrumentation didn't
# exist" not "instrumentation failed to fire." Approximation by created_at: a
# feature whose created_at is on/after this date is fully covered. Features
# created before but completed after may be partially covered — the gate
# accepts a false negative there rather than a false positive that blocks PRs.
# Added 2026-05-02 for v7.8 PR-1; predicate becomes "≥N hits where N calibrated"
# in v7.9 once Mechanism C has accumulated 7+ days of data.
MECHANISM_C_SHIP_DATE = "2026-05-02"

# T5 (Block B, framework-v7-8-branch-isolation): infra-path classifier globs.
# Per PRD §4.1 + integration-spec.md §1.2. When a staged commit touches any
# of these paths, Mode B (every-commit-fires) is triggered for the
# BRANCH_ISOLATION_VIOLATION gate. Glob patterns match `fnmatch`-style
# (no recursive `**`).
_INFRA_PATH_GLOBS = (
    ".githooks/*",
    ".github/workflows/*",
    "scripts/*",
    ".claude/skills/*",
    ".claude/shared/*",
    "CLAUDE.md",
    "docs/architecture/*",
    "Makefile",
)

# T6 (Block B): gate ships in advisory mode at v7.8 — fires telemetry but does
# not block commits. v7.9 promotion flips this to True (blocking). The gate
# can also be controlled per-feature via state.json::isolation_opt_out (Q3)
# but that override does NOT apply when the staged commit is infra work
# (Mode B always fires regardless of opt-out).
BRANCH_ISOLATION_ADVISORY_MODE = True

# Canonical `framework_version` form. Accepts `v<major>.<minor>` and
# `pre-v<major>.<minor>` (for features that predate framework versioning
# but want to record their lineage). Bare numbers like "7.6" are rejected
# so that downstream consumers (measurement-adoption-report.py) can rely
# on a single canonical form. Added 2026-05-01 per Gap B in the audit.
_FRAMEWORK_VERSION_RE = re.compile(r"^(pre-)?v\d+\.\d+(\.\d+)?$")


# Event types that count as satisfying a phase transition.
PHASE_TRANSITION_EVENT_TYPES = {
    "phase_started",
    "phase_approved",
    "phase_transition",
    "tier_closure",
    "harness_closure",
    "runtime_verification",
    "implementation_checkpoint",
    "test_run",
    "merge_recorded",
    "docs_published",
}


# Module-level PR cache. Populated lazily on first PR-resolving check so we
# only call `gh pr list` once per script invocation, not once per file.
# None = "not yet loaded"; set() = "loaded but empty or unavailable".
_PR_CACHE: set[int] | None = None
_PR_CACHE_LOADED: bool = False


def _load_pr_cache() -> set[int] | None:
    """Load all PR numbers via `gh pr list --state all`.

    Returns None if `gh` is unavailable or unauthenticated — the caller skips
    the PR-resolution check rather than failing the hook. We never want a
    missing GH_TOKEN or an offline dev environment to block a legitimate
    commit; the 72h integrity cycle catches PR drift anyway.
    """
    global _PR_CACHE, _PR_CACHE_LOADED
    if _PR_CACHE_LOADED:
        return _PR_CACHE
    _PR_CACHE_LOADED = True
    try:
        out = subprocess.check_output(
            ["gh", "pr", "list", "--state", "all", "--limit", "500",
             "--json", "number"],
            text=True, stderr=subprocess.DEVNULL,
        )
        _PR_CACHE = {p["number"] for p in json.loads(out)}
    except (subprocess.CalledProcessError, FileNotFoundError,
            json.JSONDecodeError):
        _PR_CACHE = None
    return _PR_CACHE


def _feature_slug_from_path(path: Path) -> str | None:
    """Extract the feature slug from a state.json path.

    `.claude/features/<slug>/state.json` → `<slug>`. Returns None if the
    path is outside the features directory.
    """
    try:
        rel = path.resolve().relative_to(FEATURES_DIR)
    except ValueError:
        return None
    parts = rel.parts
    if len(parts) < 2 or parts[-1] != "state.json":
        return None
    return parts[0]


def _load_committed_state(path: Path) -> dict | None:
    """Load the currently-committed (HEAD) version of a state.json file.

    Returns None if the file doesn't exist in HEAD (new feature) or git is
    unavailable. The caller treats None as "no previous state to diff against."
    """
    try:
        rel = path.resolve().relative_to(REPO_ROOT)
    except ValueError:
        return None
    try:
        out = subprocess.check_output(
            ["git", "show", f"HEAD:{rel}"],
            cwd=REPO_ROOT, text=True, stderr=subprocess.DEVNULL,
        )
        return json.loads(out)
    except (subprocess.CalledProcessError, json.JSONDecodeError):
        return None


def _parse_iso(raw: str) -> datetime | None:
    """Parse an ISO 8601 timestamp, returning a timezone-aware UTC datetime."""
    if not isinstance(raw, str):
        return None
    normalized = raw.strip().replace("Z", "+00:00")
    try:
        dt = datetime.fromisoformat(normalized)
    except ValueError:
        return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


def _load_feature_log(feature_slug: str) -> dict | None:
    """Load .claude/logs/<feature>.log.json, return None if it doesn't exist."""
    log_path = LOGS_DIR / f"{feature_slug}.log.json"
    if not log_path.exists():
        return None
    try:
        return json.loads(log_path.read_text())
    except json.JSONDecodeError:
        return None


def _recent_phase_event(log: dict, target_phase: str | None, freshness_min: int) -> dict | None:
    """Return the most recent event that satisfies a phase transition check.

    Criteria: event.event_type in PHASE_TRANSITION_EVENT_TYPES AND its
    timestamp is within freshness_min of now (not counting retroactive
    events, which are explicitly marked and don't satisfy a live transition).
    """
    events = log.get("events") if isinstance(log, dict) else None
    if not isinstance(events, list):
        return None
    now = datetime.now(timezone.utc)
    threshold = now - timedelta(minutes=freshness_min)
    for event in reversed(events):
        if not isinstance(event, dict):
            continue
        if event.get("recording_mode") == "retroactive":
            continue
        if event.get("event_type") not in PHASE_TRANSITION_EVENT_TYPES:
            continue
        ts = _parse_iso(event.get("timestamp", ""))
        if ts is None or ts < threshold:
            continue
        if target_phase and event.get("phase") not in {target_phase, None}:
            # Event phase doesn't match the destination — keep looking. An
            # event with phase=None is accepted (older events pre-dating the
            # phase field).
            continue
        return event
    return None


def check_cache_hits_empty_post_v6(
    state: dict, *, coverage: GateCoverage | None = None
) -> list[dict]:
    """Reject current_phase=complete when post-Mechanism-C feature has empty cache_hits[].

    Closes the writer-path adoption gap (issue #140). v7.6 hooks check key
    presence; v7.7 the hook checked for non-empty content on post-v6 features
    at completion (silent-pass: 0/46 effective coverage — see
    project_framework_gaps_audit_2026_04_30.md). v7.8 PR-1 fixes the gate by:

    1. Dual-read of `created_at` ∪ `created` (Audit Gap A — 43/46 features
       used the legacy `created` field at v7.7 ship time; the gate's
       `state.get("created_at", "")` returned empty and silently passed).
    2. Tighter exemption: features whose created_at predates Mechanism C
       (the PostToolUse:Read hook that auto-collects cache_hits[]) are
       exempt — their lifecycle had no auto-instrumentation, so an empty
       array is "instrumentation didn't exist" not "instrumentation failed."

    The combined effect: the gate fires only on features that COULD have had
    cache_hits[] populated mechanically. v7.9 promotes the predicate from
    "non-empty" to "≥N calibrated" once the auto-collection has accumulated
    7+ days of data.

    Returns a list with one finding dict (code=CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT) if the
    check fails, or an empty list if the check passes or is not applicable.
    """
    findings: list[dict] = []
    GATE = "CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT"
    if coverage is not None:
        coverage.candidate(GATE)
    # Dual-read: prefer the canonical `created_at`; fall back to legacy `created`
    # for features that haven't been migrated yet. v7.9 will drop the fallback.
    created = state.get("created_at") or state.get("created", "")
    current_phase = state.get("current_phase", "")
    cache_hits = state.get("cache_hits", None)

    # Pre-v6 features are exempt from the adoption requirement.
    if not created or created < V6_SHIP_DATE:
        if coverage is not None:
            coverage.skip(GATE, "no_created_at" if not created else "pre_v6")
        return findings
    # Pre-Mechanism-C features are exempt: the auto-instrumentation that
    # populates cache_hits[] mechanically did not exist during their
    # lifecycle. Empty array means "no instrumentation" not "instrumentation
    # failed to fire" — the gate would be a false positive.
    if created < MECHANISM_C_SHIP_DATE:
        if coverage is not None:
            coverage.skip(GATE, "pre_mechanism_c")
        return findings
    # Gate only fires at completion — in-progress features are not yet blocked.
    if current_phase != "complete":
        if coverage is not None:
            coverage.skip(GATE, "not_complete")
        return findings
    # Past every early-return gate now — the predicate is actually evaluated.
    if coverage is not None:
        coverage.checked(GATE)
    # If cache_hits key is absent entirely or has entries, no finding.
    if cache_hits is None or len(cache_hits) > 0:
        return findings

    findings.append({
        "code": "CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT",
        "feature": state.get("feature_name", "unknown"),
        "message": (
            "Post-Mechanism-C feature reached current_phase=complete with "
            "empty cache_hits[]. The PostToolUse:Read hook + "
            "scripts/observe-cache-hit.py should populate cache_hits[] "
            "automatically on every cache read; an empty array at "
            "completion means the hook isn't firing or active-feature "
            "attribution is broken. See .claude/settings.json + "
            "scripts/observe-cache-hit.py + issue #140."
        ),
        "severity": "failure",
    })
    return findings


EXEMPT_CASE_STUDY_TYPES = {
    "no_case_study_required",
    "pre_pm_workflow_backfill",
    "roundup",
    "framework_meta_retroactive",
}


def check_state_no_case_study_link(
    state: dict, *, coverage: GateCoverage | None = None
) -> list[dict]:
    """Reject current_phase=complete without case_study link or exempt tag.

    Closes the write-time linkage gate (STATE_NO_CASE_STUDY_LINK). A feature
    reaching completion without a case study link (direct or via
    parent_case_study) or an explicit exempt tag is a process violation:
    every shipped feature either has a narrative or a recorded reason why
    one was waived.

    Exempt tags (EXEMPT_CASE_STUDY_TYPES):
      - no_case_study_required    (new in v7.7 — operational artifacts)
      - pre_pm_workflow_backfill  (v7.6 — pre-PM-workflow features)
      - roundup                   (v7.6 — covered by consolidation case study)
      - framework_meta_retroactive (v7.8 — framework-version meta features
                                    where the framework version itself shipped
                                    before spec discipline was established;
                                    case study + git history are the source of
                                    truth, no spec/plan/PRD chain to backfill)

    Returns a list with one finding dict (code=STATE_NO_CASE_STUDY_LINK) if the
    check fails, or an empty list if the check passes or is not applicable.
    """
    findings: list[dict] = []
    GATE = "STATE_NO_CASE_STUDY_LINK"
    if coverage is not None:
        coverage.candidate(GATE)
    if state.get("current_phase") != "complete":
        if coverage is not None:
            coverage.skip(GATE, "not_complete")
        return findings
    if coverage is not None:
        coverage.checked(GATE)
    has_link = bool(state.get("case_study") or state.get("parent_case_study"))
    is_exempt = state.get("case_study_type") in EXEMPT_CASE_STUDY_TYPES
    if has_link or is_exempt:
        return findings
    findings.append({
        "code": "STATE_NO_CASE_STUDY_LINK",
        "feature": state.get("feature_name", "unknown"),
        "message": (
            "Feature reached current_phase=complete without case_study / "
            "parent_case_study link or case_study_type exempt tag. Add a "
            "case_study field pointing to "
            "docs/case-studies/<feature>-case-study.md, or a "
            "parent_case_study field pointing to the parent case study, OR "
            "add case_study_type: 'no_case_study_required' (or "
            "'pre_pm_workflow_backfill' / 'roundup' / "
            "'framework_meta_retroactive') with case_study_exempt_reason."
        ),
        "severity": "failure",
    })
    return findings


def check_cu_v2_schema(
    state: dict, *, coverage: GateCoverage | None = None
) -> list[dict]:
    """Validate the cu_v2 field in a state dict using the T6 validator.

    Delegates to validate-cu-v2.py's `validate()` function (importlib.util
    import — no rename needed; same pattern used by tests). Pre-v6 features
    that lack the cu_v2 key are exempt and pass immediately.

    Returns a list with one finding dict per violation (code=CU_V2_INVALID),
    or an empty list when the state passes or is exempt.
    """
    GATE = "CU_V2_INVALID"
    if coverage is not None:
        coverage.candidate(GATE)
    if "cu_v2" not in state:
        if coverage is not None:
            coverage.skip(GATE, "field_absent")
        return []
    if coverage is not None:
        coverage.checked(GATE)
    mod = _get_validate_cu_v2()
    raw_errors: list[str] = mod.validate(state)
    if not raw_errors:
        return []
    feature = state.get("feature_name", "unknown")
    return [
        {
            "code": "CU_V2_INVALID",
            "feature": feature,
            "message": err,
            "severity": "failure",
        }
        for err in raw_errors
    ]


# v7.8.3 Phase 2: valid values for the state_owner field.
VALID_STATE_OWNERS = {"ft2", "fitme-story"}


def check_state_owner(
    state: dict, *, coverage: GateCoverage | None = None
) -> list[dict]:
    """Phase 2 v7.8.3 gate: required state_owner field with valid enum value.

    Per spec §3.4. Required from 2026-05-13 onward (Phase 2 ship date).
    Valid values: 'ft2' | 'fitme-story'.

    Returns a list with one finding dict if the check fails, or an empty list
    when the state passes.
    """
    GATE_MISSING = "STATE_OWNER_MISSING"
    GATE_INVALID = "STATE_OWNER_INVALID"
    if coverage is not None:
        coverage.candidate(GATE_MISSING)
        coverage.candidate(GATE_INVALID)

    state_owner = state.get("state_owner")
    feature = state.get("feature_name", state.get("name", "unknown"))

    if state_owner is None:
        if coverage is not None:
            coverage.checked(GATE_MISSING)
            coverage.skip(GATE_INVALID, "state_owner_absent")
        return [{
            "code": GATE_MISSING,
            "feature": feature,
            "message": (
                "state.json missing required state_owner field. "
                "Set state_owner='ft2' for FT2-canonical features (the default), "
                "or 'fitme-story' for fitme-story-canonical features."
            ),
            "severity": "failure",
        }]

    if coverage is not None:
        coverage.skip(GATE_MISSING, "state_owner_present")
        coverage.checked(GATE_INVALID)

    if state_owner not in VALID_STATE_OWNERS:
        return [{
            "code": GATE_INVALID,
            "feature": feature,
            "message": (
                f"state_owner='{state_owner}' is not a valid value. "
                f"Must be one of: {sorted(VALID_STATE_OWNERS)}."
            ),
            "severity": "failure",
        }]

    return []


def check_state_owner_location_match(
    state: dict,
    file_path: Path,
    *,
    coverage: GateCoverage | None = None,
) -> list[dict]:
    """Morphed C-5 (v7.8.3 Phase 2): file location must match state_owner.

    Per spec §4.4. The state_owner_sync_origin marker (set by D-1 reverse-sync
    GitHub Action in Phase 3) exempts sync mirrors from the location-mismatch
    check — when the sync action writes a fitme-story state.json into the FT2
    tree as a mirror, it sets state_owner_sync_origin='fitme-story-reverse'.

    Returns a list with one finding dict if the check fails, or an empty list
    when the state passes, the file path is neutral (neither repo), or a sync
    mirror exemption applies.
    """
    import os
    GATE = "STATE_OWNER_LOCATION_MISMATCH"
    if coverage is not None:
        coverage.candidate(GATE)

    state_owner = state.get("state_owner")
    if state_owner is None or state_owner not in VALID_STATE_OWNERS:
        # Caught upstream by check_state_owner; skip to avoid double-report.
        if coverage is not None:
            coverage.skip(GATE, "state_owner_invalid_or_absent")
        return []

    sync_origin = state.get("state_owner_sync_origin")
    if isinstance(sync_origin, str) and sync_origin.endswith("-reverse"):
        # D-1 sync mirror — location mismatch is by design.
        if coverage is not None:
            coverage.skip(GATE, "sync_mirror_exempt")
        return []

    abs_path = os.path.abspath(str(file_path))
    # Match the actual repo path, NOT feature names that happen to start
    # with the repo prefix.
    #
    # FT2: match /FitTracker2 followed by [-/] (covers canonical /FitTracker2/
    # AND sibling worktrees like /FitTracker2-cross-repo-state-sync-phase-2/).
    #
    # fitme-story: require trailing slash /fitme-story/ — must be a directory
    # within the fitme-story repo root. Critical: do NOT use \b — feature
    # names commonly start with "fitme-story-" (e.g. fitme-story-design-
    # system-p2-cleanup, fitme-story-public-enhancements) and \b would
    # falsely match these as fitme-story-canonical. Worktree edge case
    # (e.g. /fitme-story-cross-repo-state-sync-phase-1/) is handled at the
    # operator level (such worktrees would commit through fitme-story's
    # gate stack which has its own awareness).
    is_ft2_path = bool(re.search(r"/FitTracker2[-/]", abs_path))
    is_fs_path = "/fitme-story/" in abs_path

    if not is_ft2_path and not is_fs_path:
        # Path is neutral (e.g. /tmp, test fixtures) — cannot determine mismatch.
        if coverage is not None:
            coverage.skip(GATE, "path_neutral")
        return []

    if coverage is not None:
        coverage.checked(GATE)

    feature = state.get("feature_name", state.get("name", "unknown"))

    if state_owner == "ft2" and is_fs_path:
        return [{
            "code": GATE,
            "feature": feature,
            "message": (
                f"state_owner='ft2' but file is at a fitme-story path. "
                f"Commit to the FT2 repo instead, OR update state_owner='fitme-story' "
                f"if migrating canonical home."
            ),
            "severity": "failure",
        }]

    if state_owner == "fitme-story" and is_ft2_path:
        return [{
            "code": GATE,
            "feature": feature,
            "message": (
                f"state_owner='fitme-story' but file is at a FT2 path "
                f"(sync_origin marker absent). "
                f"Commit to fitme-story instead, OR update state_owner='ft2' "
                f"if migrating canonical home."
            ),
            "severity": "failure",
        }]

    return []


def validate_file(
    path: Path,
    *,
    enforce_transition: bool = True,
    coverage: GateCoverage | None = None,
) -> list[str]:
    """Return a list of human-readable violation messages for one file.

    `enforce_transition` controls whether the phase-transition checks (1a,
    1b) run. Those only make sense during a commit (staged mode), not on the
    periodic full-corpus scan — so the `--staged` caller passes True, while
    `--all` scans disable them.

    `coverage` (Mechanism A, v7.8 §4.1) is an optional accumulator. When
    provided, every gate records candidate / checked / skipped(reason)
    stats so a downstream meta-check can detect silent-pass failures (a
    gate that runs every commit but never exercises real data). Default
    None preserves backward-compat for existing tests.
    """
    errors: list[str] = []
    if not path.exists():
        errors.append(f"{path}: does not exist")
        return errors
    try:
        d = json.loads(path.read_text())
    except json.JSONDecodeError as e:
        errors.append(f"{path}: invalid JSON ({e})")
        return errors

    # Check 1: SCHEMA_DRIFT — legacy `phase` key
    if coverage is not None:
        coverage.candidate("SCHEMA_DRIFT_LEGACY_PHASE")
        coverage.checked("SCHEMA_DRIFT_LEGACY_PHASE")
    if "phase" in d and "current_phase" not in d:
        errors.append(
            f"{path}: uses legacy `phase` key; canonical is `current_phase`. "
            f"Rename the key (value stays the same)."
        )

    # Check 1b (added 2026-05-01): SCHEMA_DRIFT — legacy `created` key.
    # Surfaced by the 2026-04-30 framework gaps audit: 43 of 46 state.json
    # files used `created` while the v7.7 CACHE_HITS_EMPTY_POST_V6 gate read
    # `created_at`, producing 0/46 effective gate coverage (silent-pass).
    # Migration done in chore/framework-honesty-fixes-2026-05-01; this check
    # blocks regression. Same pattern as the legacy-`phase` check above.
    if coverage is not None:
        coverage.candidate("SCHEMA_DRIFT_LEGACY_CREATED")
        coverage.checked("SCHEMA_DRIFT_LEGACY_CREATED")
    if "created" in d and "created_at" not in d:
        errors.append(
            f"{path}: uses legacy `created` key; canonical is `created_at`. "
            f"Rename the key (value stays the same)."
        )

    # Check 1c (added 2026-05-01): FRAMEWORK_VERSION_FORMAT — when set, the
    # `framework_version` field must use the canonical `vX.Y` form (e.g.
    # `v7.7`, `v6.0`, `pre-v5.0`). Surfaced by the 2026-04-30 audit: 6 of 46
    # files stored unprefixed numbers ("7.6", "6.0") and 39 omitted the field
    # entirely, leaving the measurement-adoption-report.py heuristic to
    # *guess* which features are post-v6. This check enforces format only —
    # absence is allowed pending the backfill PR. Once the field is
    # backfilled across all 46 features, a follow-up will promote this from
    # format-only to presence-required.
    fv = d.get("framework_version")
    if coverage is not None:
        coverage.candidate("FRAMEWORK_VERSION_FORMAT")
        if fv is None:
            coverage.skip("FRAMEWORK_VERSION_FORMAT", "field_absent")
        else:
            coverage.checked("FRAMEWORK_VERSION_FORMAT")
    if fv is not None and not _FRAMEWORK_VERSION_RE.match(str(fv)):
        errors.append(
            f"{path}: framework_version = {fv!r} is not in canonical "
            f"`vX.Y` form (e.g. `v7.7`, `v6.0`, `pre-v5.0`). Rewrite with "
            f"the `v` prefix so the measurement-adoption report can "
            f"categorize this feature deterministically."
        )

    # Check 1d (T1, framework-v7-8-branch-isolation, advisory in v7.8 → enforced in v7.9):
    # ISOLATION_OPT_OUT_REASON_MISSING — when state.json::isolation_opt_out is True,
    # the companion isolation_opt_out_reason field must be a non-empty string.
    # Rationale: opt-out without explanation is silent drift; future-cycle audit
    # can't tell whether the opt-out is legitimate or stale. Per
    # `framework-v7-8-branch-isolation/integration-spec.md` §3.3 + PRD §3.1.
    iso_opt = d.get("isolation_opt_out", False)
    if coverage is not None:
        coverage.candidate("ISOLATION_OPT_OUT_REASON_MISSING")
        if iso_opt is True:
            coverage.checked("ISOLATION_OPT_OUT_REASON_MISSING")
        else:
            coverage.skip("ISOLATION_OPT_OUT_REASON_MISSING", "opt_out_false_or_absent")
    if iso_opt is True:
        reason = d.get("isolation_opt_out_reason", "")
        if not isinstance(reason, str) or not reason.strip():
            errors.append(
                f"{path}: isolation_opt_out=true requires a non-empty "
                f"isolation_opt_out_reason field. Set the reason "
                f"explaining why this feature opts out of branch-isolation "
                f"enforcement, or change isolation_opt_out to false."
            )

    # Check 2: PR_NUMBER_UNRESOLVED — phases.merge.pr_number must resolve
    if coverage is not None:
        coverage.candidate("PR_NUMBER_UNRESOLVED")
    merge_obj = (d.get("phases") or {}).get("merge")
    if isinstance(merge_obj, dict):
        pr_number = merge_obj.get("pr_number")
        if isinstance(pr_number, int):
            pr_cache = _load_pr_cache()
            if pr_cache is None:
                if coverage is not None:
                    coverage.skip("PR_NUMBER_UNRESOLVED", "gh_unavailable")
            else:
                if coverage is not None:
                    coverage.checked("PR_NUMBER_UNRESOLVED")
                if pr_number not in pr_cache:
                    errors.append(
                        f"{path}: phases.merge.pr_number = {pr_number} does not "
                        f"resolve on GitHub. Fix the number or remove the field "
                        f"before advancing to the merge phase."
                    )
        else:
            if coverage is not None:
                coverage.skip("PR_NUMBER_UNRESOLVED", "field_absent")
    else:
        if coverage is not None:
            coverage.skip("PR_NUMBER_UNRESOLVED", "field_absent")

    # Check 5: CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT (v7.8.3, enforced) — post-v6
    # post-Mechanism-C features must have at least one cache_hits[] entry recorded
    # before reaching current_phase=complete. Promoted from CACHE_HITS_EMPTY_POST_V6
    # (advisory) per spec §6.1 Phase 0 Task 0.3.
    # This runs on both staged and full-corpus scans (unlike the phase-transition
    # checks it doesn't need a diff — it inspects current state only).
    for finding in check_cache_hits_empty_post_v6(d, coverage=coverage):
        errors.append(
            f"{path}: [{finding['code']}] {finding['message']}"
        )

    # Check 7: STATE_NO_CASE_STUDY_LINK — current_phase=complete requires a
    # case_study link or an EXEMPT_CASE_STUDY_TYPES tag. Closes the v7.7 M2
    # linkage gate (T11). Runs on both staged and full-corpus scans.
    for finding in check_state_no_case_study_link(d, coverage=coverage):
        errors.append(
            f"{path}: [{finding['code']}] {finding['message']}"
        )

    # Check 6: CU_V2_INVALID — validates the cu_v2 field schema when present.
    # Pre-v6 features that lack the cu_v2 key are exempt (validator returns []).
    # Runs on both staged and full-corpus scans (no diff needed — checks content
    # only).
    for finding in check_cu_v2_schema(d, coverage=coverage):
        errors.append(
            f"{path}: [{finding['code']}] {finding['message']}"
        )

    # Check 10 (v7.8.3 Phase 2): STATE_OWNER_MISSING + STATE_OWNER_INVALID —
    # every state.json must carry a state_owner field with a valid enum value.
    # Runs on both staged and full-corpus scans (no diff needed).
    for finding in check_state_owner(d, coverage=coverage):
        errors.append(
            f"{path}: [{finding['code']}] {finding['message']}"
        )

    # Check 11 (v7.8.3 Phase 2, morphed C-5): STATE_OWNER_LOCATION_MISMATCH —
    # the file location (repo path) must match state_owner. Sync mirrors
    # (state_owner_sync_origin ending in '-reverse') are exempt.
    # Runs on both staged and full-corpus scans.
    for finding in check_state_owner_location_match(d, path, coverage=coverage):
        errors.append(
            f"{path}: [{finding['code']}] {finding['message']}"
        )

    # Check 9 (T11-T14, framework-v7-8-branch-isolation): FEATURE_CLOSURE_COMPLETENESS
    # gate. Fires when staged state.json transitions current_phase → complete.
    # Validates 7 required case-study frontmatter fields + Q7 kill_criteria_resolution
    # + Q6 bidirectional PR-list parity. Advisory in v7.8: prints to stderr,
    # does not block. v7.9 promotion adds findings to errors[].
    for finding in check_feature_closure_completeness(
        d, path, coverage=coverage, enforce_transition=enforce_transition
    ):
        if finding.get("advisory"):
            details = []
            if finding.get("violation") == "missing_required_fields":
                details.append(f"  Missing fields: {finding['missing_fields']}")
            elif finding.get("violation") == "kill_criteria_resolution_missing":
                details.append("  Issue: kill_criteria is set but kill_criteria_resolution is empty")
            elif finding.get("violation") == "pr_list_parity_mismatch":
                details.append(f"  state.json → case study (state_only): {finding['state_only']}")
                details.append(f"  case study → state.json (case_only): {finding['case_only']}")
            print(
                f"[ADVISORY] {finding['code']}: {finding['feature']}\n"
                f"  Case study: {finding['case_study']}\n"
                + "\n".join(details) + "\n"
                f"  Remediation: {finding['remediation']}",
                file=sys.stderr,
            )
        else:
            errors.append(
                f"{path}: [{finding['code']}] {finding.get('violation', 'unknown')}: "
                f"{finding['remediation']}"
            )

    # Check 8 Mode C (T6, framework-v7-8-branch-isolation): per-state.json
    # BRANCH_ISOLATION_VIOLATION check. Fires when non-infra feature's
    # state.json mutates current_phase from a branch other than the expected
    # feature branch. Mode B (infra) is handled commit-level in main().
    # Advisory in v7.8: prints warning to stderr, does NOT add to errors list.
    for finding in check_branch_isolation_violation_per_file(
        d, path, coverage=coverage, enforce_transition=enforce_transition
    ):
        if finding.get("advisory"):
            print(
                f"[ADVISORY] {finding['code']} (Mode {finding['mode']}): "
                f"{path}\n"
                f"  Feature: {finding.get('feature', 'unknown')}\n"
                f"  Expected branch: {finding['expected']}\n"
                f"  Current branch: {finding['got']}\n"
                f"  Phase transition: {finding.get('phase_transition', 'n/a')}\n"
                f"  Remediation: {finding['remediation']}",
                file=sys.stderr,
            )
        else:
            errors.append(
                f"{path}: [{finding['code']}] expected branch={finding['expected']}, "
                f"got branch={finding['got']}. {finding['remediation']}"
            )

    # Checks 3 + 4: phase-transition gates. Skip if we're doing a full-corpus
    # scan — those checks only make sense at commit time.
    if coverage is not None:
        coverage.candidate("PHASE_TRANSITION_NO_LOG")
        coverage.candidate("PHASE_TRANSITION_NO_TIMING")
    if not enforce_transition:
        if coverage is not None:
            coverage.skip("PHASE_TRANSITION_NO_LOG", "not_staged_mode")
            coverage.skip("PHASE_TRANSITION_NO_TIMING", "not_staged_mode")
        return errors

    new_phase = d.get("current_phase") or d.get("phase")
    committed = _load_committed_state(path)
    old_phase = None
    if committed is not None:
        old_phase = committed.get("current_phase") or committed.get("phase")

    phase_changed = (new_phase != old_phase) and new_phase is not None
    if not phase_changed:
        if coverage is not None:
            coverage.skip("PHASE_TRANSITION_NO_LOG", "no_phase_change")
            coverage.skip("PHASE_TRANSITION_NO_TIMING", "no_phase_change")
        return errors

    feature_slug = _feature_slug_from_path(path)

    # Check 3 (PHASE_TRANSITION_NO_LOG): a fresh log event must exist.
    if coverage is not None:
        coverage.checked("PHASE_TRANSITION_NO_LOG")
    if feature_slug is not None:
        log = _load_feature_log(feature_slug)
        if log is None:
            errors.append(
                f"{path}: current_phase changed to `{new_phase}` but "
                f"`.claude/logs/{feature_slug}.log.json` does not exist. "
                f"Run `python3 scripts/append-feature-log.py --feature "
                f"{feature_slug} --event-type phase_started --phase {new_phase} "
                f"--summary '...'` before committing. Emergency bypass: "
                f"`git commit --no-verify`."
            )
        elif _recent_phase_event(log, new_phase, PHASE_EVENT_FRESHNESS_MIN) is None:
            errors.append(
                f"{path}: current_phase changed to `{new_phase}` but no "
                f"recent (<{PHASE_EVENT_FRESHNESS_MIN} min) matching event in "
                f"`.claude/logs/{feature_slug}.log.json`. Append a "
                f"phase_started / phase_approved / tier_closure event first."
            )

    # Check 4 (PHASE_TRANSITION_NO_TIMING): timing fields must be populated.
    if coverage is not None:
        coverage.checked("PHASE_TRANSITION_NO_TIMING")
    phases_block = d.get("phases")
    timing = d.get("timing") or {}
    timing_phases = timing.get("phases") if isinstance(timing, dict) else None
    if not isinstance(timing_phases, dict):
        timing_phases = {}
    # Require started_at on the new phase.
    new_phase_timing = timing_phases.get(new_phase) or {}
    if not isinstance(new_phase_timing, dict) or not new_phase_timing.get("started_at"):
        errors.append(
            f"{path}: current_phase changed to `{new_phase}` but "
            f"`timing.phases.{new_phase}.started_at` is missing or empty. "
            f"Write an ISO 8601 timestamp before committing."
        )
    # Require ended_at on the old phase (if there was one).
    if old_phase:
        old_phase_timing = timing_phases.get(old_phase) or {}
        if not isinstance(old_phase_timing, dict) or not old_phase_timing.get("ended_at"):
            errors.append(
                f"{path}: current_phase transitioned from `{old_phase}` → "
                f"`{new_phase}` but `timing.phases.{old_phase}.ended_at` is "
                f"missing or empty. Record when the prior phase closed."
            )

    return errors


def collect_staged_state_files() -> list[Path]:
    """Return list of staged state.json paths under .claude/features/."""
    try:
        out = subprocess.check_output(
            ["git", "diff", "--cached", "--name-only", "--diff-filter=ACMR"],
            text=True,
        )
    except subprocess.CalledProcessError:
        return []
    paths = []
    for line in out.splitlines():
        if not line:
            continue
        if line.startswith(".claude/features/") and line.endswith("/state.json"):
            p = REPO_ROOT / line
            if p.exists():
                paths.append(p)
    return paths


def collect_all_state_files() -> list[Path]:
    if not FEATURES_DIR.exists():
        return []
    return sorted(FEATURES_DIR.glob("*/state.json"))


def collect_all_staged_files() -> list[str]:
    """Return ALL staged files (not just state.json). Used by Block B's
    BRANCH_ISOLATION_VIOLATION gate to detect infra-path commits."""
    try:
        out = subprocess.check_output(
            ["git", "diff", "--cached", "--name-only", "--diff-filter=ACMR"],
            cwd=REPO_ROOT,
            text=True,
        )
    except Exception:
        return []
    return [line.strip() for line in out.splitlines() if line.strip()]


def _matches_any_glob(path: str, globs: tuple[str, ...]) -> bool:
    """fnmatch-style wildcard matching for path globs."""
    import fnmatch
    return any(fnmatch.fnmatch(path, g) for g in globs)


def _is_infra_commit(staged_files: list[str]) -> bool:
    """T5: classify a commit as infra/framework/hub work per PRD §4.1.

    Returns True if ANY staged file matches the infra-path globs OR if the
    commit modifies a state.json whose work_subtype is framework_feature
    or work_type is chore.
    """
    # Path-glob check
    for p in staged_files:
        if _matches_any_glob(p, _INFRA_PATH_GLOBS):
            return True
    # Feature-classification check
    for p in staged_files:
        if p.startswith(".claude/features/") and p.endswith("/state.json"):
            full = REPO_ROOT / p
            if full.exists():
                try:
                    d = json.loads(full.read_text())
                    if d.get("work_subtype") == "framework_feature":
                        return True
                    if d.get("work_type") == "chore":
                        return True
                except (json.JSONDecodeError, OSError):
                    continue
    return False


def _get_current_branch() -> str:
    """Returns current git branch (not detached HEAD)."""
    try:
        return subprocess.check_output(
            ["git", "rev-parse", "--abbrev-ref", "HEAD"],
            cwd=REPO_ROOT,
            text=True,
        ).strip()
    except Exception:
        return ""


_BRANCH_ISOLATION_EXEMPT_PATH = REPO_ROOT / ".claude" / "shared" / "branch-isolation-exempt.json"
_branch_isolation_exempt: list[str] | None = None


def _load_branch_isolation_exempt() -> list[str]:
    """Load the exempt-pattern allowlist. Cached after first call."""
    global _branch_isolation_exempt
    if _branch_isolation_exempt is not None:
        return _branch_isolation_exempt
    try:
        d = json.loads(_BRANCH_ISOLATION_EXEMPT_PATH.read_text())
        patterns = [
            p["glob"]
            for p in d.get("patterns", [])
            if isinstance(p, dict) and isinstance(p.get("glob"), str)
        ]
        _branch_isolation_exempt = patterns
    except (FileNotFoundError, json.JSONDecodeError, OSError):
        _branch_isolation_exempt = []
    return _branch_isolation_exempt


def _commit_is_fully_exempt(staged_files: list[str]) -> bool:
    """Return True if every staged file matches an exempt pattern.

    Per integration-spec §3.3: exemption applies only when ALL staged files
    are in the allowlist. A mixed commit (CLAUDE.md + a feature file) is NOT
    exempt.
    """
    exempt = _load_branch_isolation_exempt()
    if not exempt:
        return False
    return all(_matches_any_glob(f, tuple(exempt)) for f in staged_files)


def check_branch_isolation_violation_commit_level(
    staged_files: list[str], *, coverage: GateCoverage | None = None
) -> list[dict]:
    """T6 + T7 + T8: commit-level BRANCH_ISOLATION_VIOLATION check.

    Mode B (per Q1): fires on every commit when staged files match infra
    glob OR feature classifies as infra. The gate enforces that the commit
    is NOT happening on `main` (it should be on a `feature/*` or `chore/*`
    branch). Per-feature `isolation_opt_out: true` is IGNORED for infra
    work (Q3 override).

    Mode C is handled per-file in validate_file() (separate predicate).

    Returns a list with one finding dict if the gate fires, else empty.
    Advisory mode (v7.8): the caller prints findings to stderr but does
    NOT add them to the blocking errors list. v7.9 promotion flips this
    to enforcement.
    """
    findings: list[dict] = []
    GATE = "BRANCH_ISOLATION_VIOLATION"
    if coverage is not None:
        coverage.candidate(GATE)

    if not staged_files:
        if coverage is not None:
            coverage.skip(GATE, "no_staged_files")
        return findings

    is_infra = _is_infra_commit(staged_files)
    if not is_infra:
        # Mode C is handled per-file in validate_file() — commit-level skip.
        if coverage is not None:
            coverage.skip(GATE, "not_infra_commit_level")
        return findings

    # Mode B fires. Check exemption allowlist first.
    if _commit_is_fully_exempt(staged_files):
        if coverage is not None:
            coverage.skip(GATE, "all_paths_exempt")
        return findings

    if coverage is not None:
        coverage.checked(GATE)

    current_branch = _get_current_branch()
    if not current_branch:
        # Detached HEAD or git error — don't fire (can't determine state)
        return findings

    if current_branch == "main":
        findings.append({
            "code": GATE,
            "mode": "B (infra)",
            "expected": "feature/<name> or chore/<name> branch",
            "got": current_branch,
            "advisory": BRANCH_ISOLATION_ADVISORY_MODE,
            "staged_files_sample": staged_files[:5],
            "remediation": (
                "Auto-isolate to a feature/* or chore/* branch before committing. "
                "Run: scripts/create-isolated-worktree.py --feature <slug> "
                "--create-if-missing  (or invoke superpowers:using-git-worktrees "
                "from an agent context). Emergency bypass: git commit --no-verify "
                "(recorded as manual_bypass)."
            ),
        })

    return findings


_PR_CITATION_RE = re.compile(r'(?:[Pp][Rr]\s*#?|github\.com/[^/\s]+/[^/\s]+/pull/)(\d+)')
_FM_LINE_RE = re.compile(r'^\s*([a-zA-Z_][a-zA-Z0-9_-]*)\s*:\s*(.*)$')


def _parse_case_study_frontmatter(text: str) -> dict:
    """Minimal YAML frontmatter parser. Returns top-level scalar / list keys.

    Doesn't handle nested objects — sufficient for detecting required-field
    presence + extracting `related_prs: [N1, N2]` and `pr_citation_exempt`
    array shape. For deeper YAML, the doc-debt scanner uses regex which is
    sufficient for presence checks.
    """
    if not text.startswith("---"):
        return {}
    end = text.find("\n---", 3)
    if end == -1:
        return {}
    fm_text = text[3:end].strip()
    fm: dict = {}
    current_list_key: str | None = None
    for raw in fm_text.splitlines():
        line = raw.rstrip()
        if not line.strip():
            current_list_key = None
            continue
        if line.startswith("  - "):
            if current_list_key is not None:
                fm.setdefault(current_list_key, [])
                fm[current_list_key].append(line[4:].strip().strip('"').strip("'"))
            continue
        m = _FM_LINE_RE.match(line)
        if not m:
            current_list_key = None
            continue
        key, val = m.group(1), m.group(2).strip()
        if val == "":
            # Could be a list key
            current_list_key = key
            fm[key] = []
        elif val.startswith("[") and val.endswith("]"):
            inner = val[1:-1].strip()
            fm[key] = [v.strip().strip('"').strip("'") for v in inner.split(",")] if inner else []
            current_list_key = None
        else:
            fm[key] = val.strip('"').strip("'")
            current_list_key = None
    return fm


def _resolve_case_study_path(state: dict) -> Path | None:
    """Resolve the case study file referenced by state.json::case_study (or
    case_study_path / case_study_link / parent_case_study). Returns absolute
    path or None if not set / not found."""
    for key in ("case_study", "case_study_path", "case_study_link", "parent_case_study"):
        val = state.get(key)
        if isinstance(val, str) and val:
            p = REPO_ROOT / val
            if p.exists():
                return p
    return None


def _collect_state_pr_numbers(state: dict) -> set[int]:
    """T14 helper: gather all PR numbers cited in state.json.

    Sources:
      - phases.merge.pr_number
      - tasks[].pr_number
      - tasks[].related_prs (list of ints)
      - phases.<phase>.pr_number for any phase
    """
    prs: set[int] = set()
    phases = state.get("phases") or {}
    for ph in phases.values():
        if isinstance(ph, dict):
            n = ph.get("pr_number")
            if isinstance(n, int):
                prs.add(n)
    tasks = state.get("tasks") or []
    if isinstance(tasks, list):
        for t in tasks:
            if not isinstance(t, dict):
                continue
            n = t.get("pr_number")
            if isinstance(n, int):
                prs.add(n)
            related = t.get("related_prs") or []
            if isinstance(related, list):
                for r in related:
                    if isinstance(r, int):
                        prs.add(r)
    return prs


def _collect_case_study_pr_numbers(case_study_text: str, frontmatter: dict) -> set[int]:
    """T14 helper: gather all PR numbers cited in a case study (body + frontmatter)."""
    prs = {int(m.group(1)) for m in _PR_CITATION_RE.finditer(case_study_text)}
    related = frontmatter.get("related_prs") or []
    if isinstance(related, list):
        for r in related:
            try:
                # Strings like "FT2 #234 (foo bar)" — extract the number
                if isinstance(r, str):
                    m = re.search(r'#(\d+)', r)
                    if m:
                        prs.add(int(m.group(1)))
                elif isinstance(r, int):
                    prs.add(r)
            except (ValueError, TypeError):
                continue
    return prs


# T11 (Block C, framework-v7-8-branch-isolation):
# Required case-study frontmatter fields at current_phase=complete transitions.
# 7 fields per PRD §4.2 + integration-spec §3.4.
_CLOSURE_REQUIRED_FIELDS = [
    "date_written",  # OR `date` synonym
    "dispatch_pattern",
    "success_metrics",  # OR `primary_metric` synonym
    "kill_criteria",
    "framework_version",
    "work_type",
    "tier_tags_present",
]
_CLOSURE_FIELD_SYNONYMS = {
    "date_written": ["date_written", "date"],
    "success_metrics": ["success_metrics", "primary_metric"],
}


def check_feature_closure_completeness(
    state: dict, path: Path, *, coverage: GateCoverage | None = None,
    enforce_transition: bool = True,
) -> list[dict]:
    """T11-T14 (Block C, framework-v7-8-branch-isolation):
    FEATURE_CLOSURE_COMPLETENESS gate.

    Fires when staged state.json transitions current_phase → 'complete'.
    Validates:
      - T12: 7 required frontmatter fields in linked case study
      - T13: kill_criteria_resolution required when kill_criteria set (Q7)
      - T14: bidirectional PR-list parity state.json ↔ case study (Q6)

    Returns list of finding dicts. Advisory in v7.8 (caller prints to stderr,
    does NOT block); v7.9 promotion adds findings to errors[] for blocking.
    """
    findings: list[dict] = []
    GATE = "FEATURE_CLOSURE_COMPLETENESS"
    if coverage is not None:
        coverage.candidate(GATE)

    if not enforce_transition:
        if coverage is not None:
            coverage.skip(GATE, "not_staged_mode")
        return findings

    new_phase = state.get("current_phase")
    if new_phase != "complete":
        if coverage is not None:
            coverage.skip(GATE, "not_complete_transition")
        return findings

    committed = _load_committed_state(path)
    old_phase = committed.get("current_phase") if committed else None
    if old_phase == "complete":
        # Already complete (this commit doesn't transition; just edits the complete state)
        if coverage is not None:
            coverage.skip(GATE, "no_phase_change")
        return findings

    # Resolve case study
    case_study_path = _resolve_case_study_path(state)
    if case_study_path is None:
        # The STATE_NO_CASE_STUDY_LINK gate handles this; we skip so we don't
        # double-report. But emit candidate-checked so coverage shows the gate ran.
        if coverage is not None:
            coverage.skip(GATE, "no_case_study_link")
        return findings

    if coverage is not None:
        coverage.checked(GATE)

    case_text = case_study_path.read_text()
    fm = _parse_case_study_frontmatter(case_text)
    feature_slug = _feature_slug_from_path(path)

    # T12: 7 required field check (with synonym resolution)
    missing_fields: list[str] = []
    for field in _CLOSURE_REQUIRED_FIELDS:
        synonyms = _CLOSURE_FIELD_SYNONYMS.get(field, [field])
        present = False
        for syn in synonyms:
            val = fm.get(syn)
            if val is not None and (
                (isinstance(val, str) and val.strip() not in ("", "[]", "null"))
                or (isinstance(val, list) and len(val) > 0)
            ):
                present = True
                break
        # tier_tags_present is a boolean field
        if field == "tier_tags_present":
            v = fm.get("tier_tags_present")
            if isinstance(v, str):
                present = v.lower() == "true"
            elif isinstance(v, bool):
                present = v
            else:
                # Fall back: check if body has any T1/T2/T3 tag
                present = bool(_TIER_TAG_RE.search(case_text))
        if not present:
            missing_fields.append(field)

    if missing_fields:
        findings.append({
            "code": GATE,
            "feature": feature_slug,
            "case_study": str(case_study_path.relative_to(REPO_ROOT)),
            "violation": "missing_required_fields",
            "missing_fields": missing_fields,
            "advisory": BRANCH_ISOLATION_ADVISORY_MODE,  # same advisory flag for v7.8
            "remediation": (
                f"Case study {case_study_path.relative_to(REPO_ROOT)} is missing "
                f"required frontmatter fields: {', '.join(missing_fields)}. "
                "Add them before transitioning to current_phase=complete."
            ),
        })

    # T13: Q7 — kill_criteria_resolution required when kill_criteria set
    has_kill = bool(fm.get("kill_criteria"))
    has_resolution = bool(fm.get("kill_criteria_resolution"))
    if has_kill and not has_resolution:
        findings.append({
            "code": GATE,
            "feature": feature_slug,
            "case_study": str(case_study_path.relative_to(REPO_ROOT)),
            "violation": "kill_criteria_resolution_missing",
            "advisory": BRANCH_ISOLATION_ADVISORY_MODE,
            "remediation": (
                "kill_criteria is set but kill_criteria_resolution is empty. "
                "Add a resolution that addresses each kill threshold (mention "
                "thresholds OR use 'not tripped' / 'deferred' / 'superseded' / "
                "'passed' to indicate disposition)."
            ),
        })

    # T14: Q6 — bidirectional PR-list parity
    state_prs = _collect_state_pr_numbers(state)
    case_prs = _collect_case_study_pr_numbers(case_text, fm)
    exempt_raw = fm.get("pr_citation_exempt") or []
    exempt: set[int] = set()
    if isinstance(exempt_raw, list):
        for e in exempt_raw:
            try:
                if isinstance(e, dict):
                    n = e.get("pr_number")
                    if isinstance(n, int):
                        exempt.add(n)
                elif isinstance(e, int):
                    exempt.add(e)
                elif isinstance(e, str):
                    m = re.search(r'\d+', e)
                    if m:
                        exempt.add(int(m.group(0)))
            except (ValueError, TypeError):
                continue

    state_only = (state_prs - case_prs) - exempt
    case_only = (case_prs - state_prs) - exempt

    if state_only or case_only:
        findings.append({
            "code": GATE,
            "feature": feature_slug,
            "case_study": str(case_study_path.relative_to(REPO_ROOT)),
            "violation": "pr_list_parity_mismatch",
            "state_only": sorted(state_only),
            "case_only": sorted(case_only),
            "advisory": BRANCH_ISOLATION_ADVISORY_MODE,
            "remediation": (
                f"PR-list parity mismatch (Q6 bidirectional). "
                f"In state.json but missing from case study: {sorted(state_only)}. "
                f"In case study but missing from state.json: {sorted(case_only)}. "
                "Add the missing PRs to whichever side or list them in "
                "case study frontmatter `pr_citation_exempt: [{pr_number, reason}]`."
            ),
        })

    return findings


_TIER_TAG_RE = re.compile(r"\bT[123]\b[\s—:.\)\(]")


def check_branch_isolation_violation_per_file(
    state: dict, path: Path, *, coverage: GateCoverage | None = None,
    enforce_transition: bool = True,
) -> list[dict]:
    """T6 Mode C: per-state.json check.

    Fires when a non-infra feature's state.json mutates current_phase from a
    branch other than `state.json::branch`. Honored opt-out: if
    state.json::isolation_opt_out is True, the gate skips.

    Only runs in staged mode (where we can detect phase changes via diff
    against committed). Full-corpus scans cannot tell transitions.
    """
    findings: list[dict] = []
    GATE = "BRANCH_ISOLATION_VIOLATION_MODE_C"

    if coverage is not None:
        coverage.candidate(GATE)

    if not enforce_transition:
        if coverage is not None:
            coverage.skip(GATE, "not_staged_mode")
        return findings

    # Skip if feature opts out (per Q3; infra override handled commit-level)
    if state.get("isolation_opt_out") is True:
        if coverage is not None:
            coverage.skip(GATE, "feature_opt_out")
        return findings

    expected_branch = state.get("branch")
    if not expected_branch or expected_branch == "main":
        # Feature has no branch declared OR claims to live on main — skip.
        if coverage is not None:
            coverage.skip(GATE, "no_expected_branch")
        return findings

    # Detect current_phase mutation
    new_phase = state.get("current_phase")
    committed = _load_committed_state(path)
    old_phase = committed.get("current_phase") if committed else None
    if new_phase == old_phase:
        if coverage is not None:
            coverage.skip(GATE, "no_phase_change")
        return findings

    # Phase mutation detected; check current branch matches expected
    if coverage is not None:
        coverage.checked(GATE)
    current_branch = _get_current_branch()
    if not current_branch or current_branch == expected_branch:
        return findings

    findings.append({
        "code": "BRANCH_ISOLATION_VIOLATION",
        "mode": "C (current_phase mutation)",
        "feature": _feature_slug_from_path(path),
        "expected": expected_branch,
        "got": current_branch,
        "phase_transition": f"{old_phase} → {new_phase}",
        "advisory": BRANCH_ISOLATION_ADVISORY_MODE,
        "remediation": (
            "Mutate state.json::current_phase only from the feature's declared "
            f"branch ({expected_branch}). Switch branches first. To opt out "
            "for this feature only, set state.json::isolation_opt_out: true "
            "with a non-empty isolation_opt_out_reason."
        ),
    })
    return findings


def main() -> int:
    args = sys.argv[1:]
    if args == ["--staged"]:
        files = collect_staged_state_files()
        mode = "staged"
    elif not args:
        files = collect_all_state_files()
        mode = "all"
    else:
        files = [Path(a).resolve() for a in args]
        mode = "explicit"

    # Phase-transition checks (1a, 1b) only fire at commit time. Full-corpus
    # scans cannot tell what's a "transition" — they just see current state.
    # Override via FORCE_TRANSITION_CHECKS=1 (used by the regression test
    # harness so synthetic-fixture assertions can exercise the same code
    # path as a real `--staged` invocation without polluting the git index).
    import os
    enforce_transition = (
        mode == "staged"
        or os.environ.get("FORCE_TRANSITION_CHECKS") == "1"
    )

    # Mechanism A (v7.8 §4.1): instantiate per-run gate-coverage tracker.
    # Pass to validate_file so each gate records candidate / checked /
    # skipped(reason) stats. Ledger gets one event per gate at the end of
    # the run. Skip ledger writes in CI ($GITHUB_ACTIONS=true) so PR-bot
    # noise stays out — local + scheduled runs are the data source.
    coverage = GateCoverage(mode=mode)

    all_errors: list[str] = []

    # T8 (Block B, framework-v7-8-branch-isolation): commit-level
    # BRANCH_ISOLATION_VIOLATION check (Mode B — infra-path classifier).
    # Runs ONCE per script invocation in staged mode. Advisory in v7.8:
    # prints warning to stderr, does NOT add to errors list.
    #
    # NOTE: this block runs BEFORE the no-state-files early exit. Mode B
    # fires on infra-path commits regardless of whether state.json is in
    # the staged set, so scaffolding commits (scripts/, .claude/shared/,
    # .githooks/, etc.) without a state.json must still be evaluated.
    # Pre-2026-05-12 the early-exit was above this block, silently bypassing
    # Mode B for ~9 commits in HADF Phase 2-bis Block A (A3–A11).
    if mode == "staged":
        all_staged = collect_all_staged_files()
        for finding in check_branch_isolation_violation_commit_level(
            all_staged, coverage=coverage
        ):
            if finding.get("advisory"):
                print(
                    f"[ADVISORY] {finding['code']} (Mode {finding['mode']})\n"
                    f"  Expected: {finding['expected']}\n"
                    f"  Got branch: {finding['got']}\n"
                    f"  Staged files (sample): {finding['staged_files_sample']}\n"
                    f"  Remediation: {finding['remediation']}",
                    file=sys.stderr,
                )
            else:
                all_errors.append(
                    f"COMMIT-LEVEL: [{finding['code']}] expected branch={finding['expected']}, "
                    f"got branch={finding['got']}. {finding['remediation']}"
                )

    # Persist the coverage ledger. Failure to write must not affect the
    # exit code — Mechanism A is advisory in v7.8; the gate verdict is
    # what gates the commit. Tests opt out via GATE_COVERAGE_LEDGER_DISABLED=1.
    # The ledger path is gitignored — CI writes are no-ops as far as git is
    # concerned, but the longitudinal data accumulates on local + scheduled
    # cron runs (the data source for the v7.9 GATE_COVERAGE_ZERO meta-check).
    skip_ledger = os.environ.get("GATE_COVERAGE_LEDGER_DISABLED") == "1"

    def _persist_coverage_ledger() -> None:
        if skip_ledger:
            return
        try:
            coverage.write_jsonl(GATE_COVERAGE_LEDGER)
        except OSError as e:
            print(f"warning: gate-coverage ledger write failed ({e})",
                  file=sys.stderr)

    if not files:
        _persist_coverage_ledger()
        if all_errors:
            print(f"✗ STATE_SCHEMA: {len(all_errors)} violation(s) "
                  f"(mode={mode}, files scanned=0)",
                  file=sys.stderr)
            for err in all_errors:
                print(f"  - {err}", file=sys.stderr)
            return 1
        print(f"No state.json files to validate (mode={mode}).")
        return 0

    for p in files:
        all_errors.extend(
            validate_file(p, enforce_transition=enforce_transition, coverage=coverage)
        )

    _persist_coverage_ledger()

    if all_errors:
        print(f"✗ STATE_SCHEMA: {len(all_errors)} violation(s) "
              f"(mode={mode}, files scanned={len(files)})",
              file=sys.stderr)
        for err in all_errors:
            print(f"  - {err}", file=sys.stderr)
        return 1

    pr_cache = _PR_CACHE if _PR_CACHE_LOADED else None
    pr_note = ""
    if pr_cache is not None:
        pr_note = f" (PR-resolution: {len(pr_cache)} known PRs)"
    elif _PR_CACHE_LOADED:
        pr_note = " (PR-resolution skipped — gh unavailable)"
    print(f"✓ All {len(files)} state.json files pass all checks "
          f"(mode={mode}){pr_note}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
