#!/usr/bin/env python3
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


REPO_ROOT = Path(__file__).resolve().parent.parent
FEATURES_DIR = REPO_ROOT / ".claude" / "features"
LOGS_DIR = REPO_ROOT / ".claude" / "logs"

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


def check_cache_hits_empty_post_v6(state: dict) -> list[dict]:
    """Reject current_phase=complete when post-v6 feature has empty cache_hits[].

    Closes the writer-path adoption gap (issue #140). v7.6 hooks check key
    presence; v7.7 this hook checks for non-empty content on post-v6 features
    at completion. M1 instrumentation (scripts/log-cache-hit.py) is expected
    to populate cache_hits[] on every cache read; an empty array at completion
    means either the instrumentation is missing for this feature's cache calls,
    or the cache was never read.

    Returns a list with one finding dict (code=CACHE_HITS_EMPTY_POST_V6) if the
    check fails, or an empty list if the check passes or is not applicable.
    """
    findings: list[dict] = []
    created = state.get("created_at", "")
    current_phase = state.get("current_phase", "")
    cache_hits = state.get("cache_hits", None)

    # Pre-v6 features are exempt from the adoption requirement.
    if not created or created < V6_SHIP_DATE:
        return findings
    # Gate only fires at completion — in-progress features are not yet blocked.
    if current_phase != "complete":
        return findings
    # If cache_hits key is absent entirely or has entries, no finding.
    if cache_hits is None or len(cache_hits) > 0:
        return findings

    findings.append({
        "code": "CACHE_HITS_EMPTY_POST_V6",
        "feature": state.get("feature_name", "unknown"),
        "message": (
            "Post-v6 feature reached current_phase=complete with empty "
            "cache_hits[]. M1 instrumentation should populate this on "
            "every cache read; an empty array at completion means either "
            "the instrumentation is missing for this feature's cache "
            "calls, or the cache was never read. See "
            "scripts/log-cache-hit.py and issue #140."
        ),
        "severity": "failure",
    })
    return findings


EXEMPT_CASE_STUDY_TYPES = {"no_case_study_required", "pre_pm_workflow_backfill", "roundup"}


def check_state_no_case_study_link(state: dict) -> list[dict]:
    """Reject current_phase=complete without case_study link or exempt tag.

    Closes the write-time linkage gate (STATE_NO_CASE_STUDY_LINK). A feature
    reaching completion without a case study link (direct or via
    parent_case_study) or an explicit exempt tag is a process violation:
    every shipped feature either has a narrative or a recorded reason why
    one was waived.

    Exempt tags (EXEMPT_CASE_STUDY_TYPES):
      - no_case_study_required  (new in v7.7 — operational artifacts)
      - pre_pm_workflow_backfill (v7.6 — pre-PM-workflow features)
      - roundup                  (v7.6 — covered by consolidation case study)

    Returns a list with one finding dict (code=STATE_NO_CASE_STUDY_LINK) if the
    check fails, or an empty list if the check passes or is not applicable.
    """
    findings: list[dict] = []
    if state.get("current_phase") != "complete":
        return findings
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
            "'pre_pm_workflow_backfill' / 'roundup') with "
            "case_study_exempt_reason."
        ),
        "severity": "failure",
    })
    return findings


def check_cu_v2_schema(state: dict) -> list[dict]:
    """Validate the cu_v2 field in a state dict using the T6 validator.

    Delegates to validate-cu-v2.py's `validate()` function (importlib.util
    import — no rename needed; same pattern used by tests). Pre-v6 features
    that lack the cu_v2 key are exempt and pass immediately.

    Returns a list with one finding dict per violation (code=CU_V2_INVALID),
    or an empty list when the state passes or is exempt.
    """
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


def validate_file(path: Path, *, enforce_transition: bool = True) -> list[str]:
    """Return a list of human-readable violation messages for one file.

    `enforce_transition` controls whether the phase-transition checks (1a,
    1b) run. Those only make sense during a commit (staged mode), not on the
    periodic full-corpus scan — so the `--staged` caller passes True, while
    `--all` scans disable them.
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
    if "phase" in d and "current_phase" not in d:
        errors.append(
            f"{path}: uses legacy `phase` key; canonical is `current_phase`. "
            f"Rename the key (value stays the same)."
        )

    # Check 2: PR_NUMBER_UNRESOLVED — phases.merge.pr_number must resolve
    merge_obj = (d.get("phases") or {}).get("merge")
    if isinstance(merge_obj, dict):
        pr_number = merge_obj.get("pr_number")
        if isinstance(pr_number, int):
            pr_cache = _load_pr_cache()
            if pr_cache is not None and pr_number not in pr_cache:
                errors.append(
                    f"{path}: phases.merge.pr_number = {pr_number} does not "
                    f"resolve on GitHub. Fix the number or remove the field "
                    f"before advancing to the merge phase."
                )

    # Check 5: CACHE_HITS_EMPTY_POST_V6 — post-v6 features must have at least
    # one cache_hits[] entry recorded before reaching current_phase=complete.
    # This runs on both staged and full-corpus scans (unlike the phase-transition
    # checks it doesn't need a diff — it inspects current state only).
    for finding in check_cache_hits_empty_post_v6(d):
        errors.append(
            f"{path}: [{finding['code']}] {finding['message']}"
        )

    # Check 7: STATE_NO_CASE_STUDY_LINK — current_phase=complete requires a
    # case_study link or an EXEMPT_CASE_STUDY_TYPES tag. Closes the v7.7 M2
    # linkage gate (T11). Runs on both staged and full-corpus scans.
    for finding in check_state_no_case_study_link(d):
        errors.append(
            f"{path}: [{finding['code']}] {finding['message']}"
        )

    # Check 6: CU_V2_INVALID — validates the cu_v2 field schema when present.
    # Pre-v6 features that lack the cu_v2 key are exempt (validator returns []).
    # Runs on both staged and full-corpus scans (no diff needed — checks content
    # only).
    for finding in check_cu_v2_schema(d):
        errors.append(
            f"{path}: [{finding['code']}] {finding['message']}"
        )

    # Checks 3 + 4: phase-transition gates. Skip if we're doing a full-corpus
    # scan — those checks only make sense at commit time.
    if not enforce_transition:
        return errors

    new_phase = d.get("current_phase") or d.get("phase")
    committed = _load_committed_state(path)
    old_phase = None
    if committed is not None:
        old_phase = committed.get("current_phase") or committed.get("phase")

    phase_changed = (new_phase != old_phase) and new_phase is not None
    if not phase_changed:
        return errors

    feature_slug = _feature_slug_from_path(path)

    # Check 3 (PHASE_TRANSITION_NO_LOG): a fresh log event must exist.
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

    if not files:
        print(f"No state.json files to validate (mode={mode}).")
        return 0

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

    all_errors: list[str] = []
    for p in files:
        all_errors.extend(validate_file(p, enforce_transition=enforce_transition))

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
