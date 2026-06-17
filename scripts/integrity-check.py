#!/usr/bin/env python3
"""
State.json integrity check + snapshot + cross-cycle diff.

Scans .claude/features/*/state.json for inconsistencies (phase lies, task lies,
missing case-study linkage, schema drift) and produces a snapshot JSON. Also
runs Auditor Agent checks on case-study .md files (broken PR citations).
When run with --compare-to, also emits a diff vs a previous snapshot.

Checks:
    Feature-level (from state.json):
        PHASE_LIE, TASK_LIE, NO_CS_LINK, V2_FILE_MISSING,
        PARTIAL_SHIP_TERMINAL, SCHEMA_DRIFT, NO_PHASE, NO_STATE, INVALID_JSON,
        PR_NUMBER_UNRESOLVED, CU_V2_INVALID

    Case-study-level (Auditor Agent, added 2026-04-21):
        BROKEN_PR_CITATION — PR number cited in a .md does not resolve via `gh pr view`.
        Skipped gracefully if `gh` is unavailable or unauthenticated.
        CASE_STUDY_MISSING_TIER_TAGS — post-2026-04-21 case study lacks T1/T2/T3 tags.

Usage:
    scripts/integrity-check.py --snapshot .claude/integrity/snapshots/2026-04-20T04-00Z.json
    scripts/integrity-check.py --snapshot <new> --compare-to <previous>
    scripts/integrity-check.py --findings-only

Exit codes:
    0  clean / same-or-better-than-previous
    1  new findings introduced OR features disappeared since previous

Designed to run both locally (make integrity-check) and in the 72h GitHub
Actions cycle (.github/workflows/integrity-cycle.yml).
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
FEATURES_DIR = REPO_ROOT / ".claude" / "features"
CASE_STUDIES_DIR = REPO_ROOT / "docs" / "case-studies"
LOGS_DIR = REPO_ROOT / ".claude" / "logs"
GATE_COVERAGE_LEDGER = LOGS_DIR / "gate-coverage.jsonl"

# v7.10 cycle-time coverage (built 2026-06-10): the write-time gates emit
# Mechanism A coverage from check-state-schema.py, but three cycle-time checks
# (BROKEN_PR_CITATION, CASE_STUDY_MISSING_TIER_TAGS, PATTERN_SKILL_UNMAPPED) ran
# WITHOUT emitting any coverage row — so the F17 index + GATE_COVERAGE_ZERO
# meta-check could not see them. If one silently stopped checking, nothing
# detected it (a silent-pass blind spot surfaced by the 2026-06-10 audit). We
# instrument them with the same GateCoverage tracker the write-time gates use,
# tagged mode="cycle" so the downstream index distinguishes cycle-time coverage
# from staged/explicit write-time coverage.
sys.path.insert(0, str(Path(__file__).resolve().parent))
from gate_coverage import GateCoverage  # noqa: E402

# v7.9.1 F-LAUNCHD-DRIFT-EXTENSION sub-fix (b):
# When ensure-pr-cache-fresh.py fails in cron context, it writes this sentinel.
# We read it at startup and skip BROKEN_PR_CITATION + PR_NUMBER_UNRESOLVED
# with explicit messaging — closing the 2026-05-24 incident class (319 phantom
# findings from cron-context gh auth failure).
REFRESH_FAILED_FLAG = REPO_ROOT / ".claude" / "shared" / "pr-cache-refresh-failed.flag"
REFRESH_FAILED_FLAG_TTL_SECONDS = 3600  # 1h — flag expires; stale flag is ignored


def pr_cache_refresh_failed_recently() -> tuple[bool, dict | None]:
    """Return (skip_pr_gates, payload) — True if a fresh sentinel exists.

    Stale flags (>1h old) are ignored so a forgotten flag from a previous
    cron run doesn't suppress today's real findings. Kill criterion #3
    enforcement.
    """
    if not REFRESH_FAILED_FLAG.exists():
        return False, None
    try:
        payload = json.loads(REFRESH_FAILED_FLAG.read_text())
        ts = payload.get("ts", "")
        # ts format: YYYY-MM-DDTHH:MM:SSZ
        flag_dt = datetime.strptime(ts, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
        age_seconds = (datetime.now(timezone.utc) - flag_dt).total_seconds()
        if age_seconds > REFRESH_FAILED_FLAG_TTL_SECONDS:
            return False, payload  # stale; ignore
        return True, payload
    except (json.JSONDecodeError, ValueError, OSError):
        return False, None

# T7: load validate-cu-v2.py (importlib.util — hyphen prevents direct import).
# Cached at module level so the load happens once per integrity-check run.
_validate_cu_v2_module = None


def _get_validate_cu_v2():
    """Lazily load validate-cu-v2.py and return the module (cached)."""
    global _validate_cu_v2_module
    if _validate_cu_v2_module is None:
        import importlib.util
        _path = REPO_ROOT / "scripts" / "validate-cu-v2.py"
        spec = importlib.util.spec_from_file_location("_validate_cu_v2", _path)
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        _validate_cu_v2_module = mod
    return _validate_cu_v2_module

COMPLETE_PHASE_STATUSES = {"approved", "complete", "completed", "done", "skipped", "closed"}
OPEN_TASK_STATUSES = {"pending", "in_progress", "open", "blocked"}
TERMINAL_FEATURE_PHASES = {"complete", "completed", "closed", "done", "cancelled"}

SKIP_CASE_STUDY_FILES = {"README.md", "case-study-template.md"}


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def git_head() -> str:
    try:
        return subprocess.check_output(
            ["git", "-C", str(REPO_ROOT), "rev-parse", "HEAD"],
            text=True,
        ).strip()
    except Exception:
        return "unknown"


def first_commit_date(path: Path) -> str | None:
    try:
        rel = path.relative_to(REPO_ROOT)
    except ValueError:
        return None
    try:
        out = subprocess.check_output(
            [
                "git", "-C", str(REPO_ROOT), "log",
                "--follow", "--diff-filter=A", "--format=%ad", "--date=short",
                "--", str(rel),
            ],
            text=True,
        ).strip()
    except Exception:
        return None
    lines = [l for l in out.splitlines() if l]
    return lines[-1] if lines else None


def feature_phase(d: dict) -> str | None:
    return d.get("current_phase") or d.get("phase")


def audit_feature(feat_dir: Path, coverage: "GateCoverage | None" = None) -> tuple[dict, list[dict]]:
    """Audit one feature directory. Returns (summary, findings)."""
    findings: list[dict] = []
    # v7.10+: emit Mechanism A cycle coverage for PHASE_LIE so the F17 index +
    # GATE_COVERAGE_ZERO meta-check can observe this per-feature check.
    if coverage is not None:
        coverage.candidate("PHASE_LIE")
    state_path = feat_dir / "state.json"
    summary = {
        "name": feat_dir.name,
        "phase": None,
        "case_study": None,
        "case_study_type": None,
        "task_total": 0,
        "task_completed": 0,
        "state_hash": None,
    }
    if not state_path.exists():
        findings.append({
            "feature": feat_dir.name, "severity": "CRITICAL", "code": "NO_STATE",
            "message": "no state.json",
        })
        if coverage is not None:
            coverage.skip("PHASE_LIE", "no_state")
        return summary, findings

    raw = state_path.read_text()
    summary["state_hash"] = hashlib.sha256(raw.encode("utf-8")).hexdigest()[:16]
    try:
        d = json.loads(raw)
    except Exception as e:
        findings.append({
            "feature": feat_dir.name, "severity": "CRITICAL", "code": "INVALID_JSON",
            "message": f"invalid JSON: {e}",
        })
        if coverage is not None:
            coverage.skip("PHASE_LIE", "invalid_json")
        return summary, findings

    feat = d.get("feature", feat_dir.name)
    summary["name"] = feat
    phase = feature_phase(d)
    summary["phase"] = phase
    summary["case_study"] = d.get("case_study") or d.get("parent_case_study")
    summary["case_study_type"] = d.get("case_study_type")

    if phase is None:
        findings.append({
            "feature": feat, "severity": "WARN", "code": "NO_PHASE",
            "message": "no phase field (neither current_phase nor phase)",
        })
        if coverage is not None:
            coverage.skip("PHASE_LIE", "no_phase")
        return summary, findings

    # Task summary
    tasks_raw = d.get("tasks")
    task_list: list = []
    if isinstance(tasks_raw, list):
        task_list = tasks_raw
    elif isinstance(tasks_raw, dict):
        task_list = tasks_raw.get("task_list", []) or []
    summary["task_total"] = len([t for t in task_list if isinstance(t, dict)])
    summary["task_completed"] = sum(
        1 for t in task_list
        if isinstance(t, dict) and t.get("status") in ("completed", "done", "complete")
    )

    is_terminal = phase in TERMINAL_FEATURE_PHASES

    # Phase-lie exemptions:
    # - pre-PM-workflow backfills (use legacy phase vocabulary)
    # - roundup-classified features (covered by consolidation CS, sub-phase granularity not meaningful)
    # - framework_meta_retroactive (v7.8) — framework-version meta features
    #   whose framework version itself shipped before spec discipline; sub-phase
    #   granularity not meaningful since the work predates the phase model
    cs_type = d.get("case_study_type")
    is_phase_check_exempt = cs_type in ("pre_pm_workflow_backfill", "roundup", "framework_meta_retroactive")

    if coverage is not None:
        if not is_terminal:
            coverage.skip("PHASE_LIE", "not_terminal")
        elif is_phase_check_exempt:
            coverage.skip("PHASE_LIE", f"exempt_{cs_type}")
        else:
            coverage.checked("PHASE_LIE")

    # Check #1: phase lie
    if is_terminal and not is_phase_check_exempt:
        incomplete = []
        for pname, pobj in (d.get("phases") or {}).items():
            if not isinstance(pobj, dict):
                continue
            pstatus = pobj.get("status")
            if pstatus and pstatus not in COMPLETE_PHASE_STATUSES and pstatus != "pending_na":
                incomplete.append(f"{pname}={pstatus}")
        if incomplete:
            findings.append({
                "feature": feat, "severity": "INCONSISTENT", "code": "PHASE_LIE",
                "message": f"top-level {phase} but sub-phases not approved: {', '.join(incomplete)}",
            })

    # Check #2: task lie
    if is_terminal and task_list:
        open_tasks = [
            t for t in task_list
            if isinstance(t, dict) and t.get("status") in OPEN_TASK_STATUSES
        ]
        if open_tasks:
            ids = [t.get("id", "?") for t in open_tasks[:10]]
            findings.append({
                "feature": feat, "severity": "INCONSISTENT", "code": "TASK_LIE",
                "message": f"top-level {phase} but {len(open_tasks)} tasks not done: {','.join(ids)}"
                           + (",…" if len(open_tasks) > 10 else ""),
            })

    # Check #3: missing case-study linkage (excluding roundup + backfill +
    # no_case_study_required + framework_meta_retroactive). Note:
    # is_phase_check_exempt covers pre_pm_workflow_backfill and roundup;
    # no_case_study_required is a v7.7 addition for operational artifacts
    # that warrant no narrative; framework_meta_retroactive is a v7.8
    # addition for framework-version meta features whose framework version
    # itself shipped before spec discipline was established.
    _NO_CS_EXEMPT_TYPES = {"roundup", "no_case_study_required", "framework_meta_retroactive"}
    if is_terminal and not is_phase_check_exempt:
        has_cs = bool(d.get("case_study") or d.get("parent_case_study"))
        if not has_cs and d.get("case_study_type") not in _NO_CS_EXEMPT_TYPES:
            findings.append({
                "feature": feat, "severity": "MISSING", "code": "NO_CS_LINK",
                "message": "terminal phase but no case_study / parent_case_study / case_study_type linkage",
            })

    # Check #4: declared v2 file missing
    v2_path = d.get("v2_file_path")
    if v2_path and is_terminal:
        full = REPO_ROOT / v2_path
        if not full.exists():
            findings.append({
                "feature": feat, "severity": "MISSING", "code": "V2_FILE_MISSING",
                "message": f"v2_file_path declared ({v2_path}) but file does not exist",
            })

    # Check #5: partial_ship flagged alongside terminal phase
    if is_terminal and d.get("partial_ship") is True:
        findings.append({
            "feature": feat, "severity": "INCONSISTENT", "code": "PARTIAL_SHIP_TERMINAL",
            "message": "partial_ship=true with terminal phase — should be downgraded OR flag removed",
        })

    # Check #6: state.json schema drift (phase vs current_phase)
    # Canonical is `current_phase`. Legacy `phase`-only files must be migrated
    # so downstream tooling only has to read one key.
    if "phase" in d and "current_phase" not in d:
        findings.append({
            "feature": feat, "severity": "WARN", "code": "SCHEMA_DRIFT",
            "message": "uses legacy `phase` key; canonical is `current_phase`",
        })

    # Check #7: merge-phase pr_number must resolve via gh pr view
    # (Tier 1.2 subset — prevents state.json from retaining dead PR links).
    # pr_cache is injected by build_snapshot; skipped gracefully if unavailable.
    merge_obj = (d.get("phases") or {}).get("merge")
    if isinstance(merge_obj, dict):
        pr_number = merge_obj.get("pr_number")
        if isinstance(pr_number, int) and _PR_CACHE is not None:
            # v7.8.3: _PR_CACHE is now multi-repo dict; check FT2 repo specifically.
            _ft2_prs = _CACHE_FT2_NUMBERS(_PR_CACHE)
            if pr_number not in _ft2_prs:
                findings.append({
                    "feature": feat,
                    "severity": "INCONSISTENT",
                    "code": "PR_NUMBER_UNRESOLVED",
                    "message": f"phases.merge.pr_number = {pr_number} "
                               f"does not resolve on GitHub",
                })

    # Check #8: CU_V2_INVALID — validate the cu_v2 field when present.
    # (T7, added 2026-04-27). Pre-v6 features without the cu_v2 key are
    # exempt; the validator returns [] for them. Uses the same importlib.util
    # loader as check-state-schema.py to avoid subprocess overhead.
    try:
        cu_v2_errors = _get_validate_cu_v2().validate(d)
        for err_msg in cu_v2_errors:
            findings.append({
                "feature": feat,
                "severity": "INCONSISTENT",
                "code": "CU_V2_INVALID",
                "message": err_msg,
            })
    except Exception as exc:
        # If the validator itself errors (e.g. missing file), emit a WARN
        # rather than crashing the whole integrity-check run.
        findings.append({
            "feature": feat,
            "severity": "WARN",
            "code": "CU_V2_INVALID",
            "message": f"validator raised exception: {exc}",
        })

    return summary, findings


# Module-level PR cache. Populated by build_snapshot() once per run so
# per-feature audit_feature() calls can reuse it without repeated gh invocations.
# v7.8.3 D-3: type morphed from set[int] | None to multi-repo dict | None.
_PR_CACHE: dict | None = None


def _CACHE_FT2_NUMBERS(cache: dict) -> set[int]:
    """Extract the set of FitTracker2 PR numbers from the multi-repo cache dict.

    Used by PR_NUMBER_UNRESOLVED check in audit_feature() which only
    verifies state.json::phases.merge.pr_number (always a FT2 PR).
    """
    ft2 = cache.get("repos", {}).get("Regevba/FitTracker2", {})
    return {
        pr["number"]
        for lst in (ft2.get("open", []), ft2.get("merged", []), ft2.get("closed", []))
        for pr in lst
    }


# -- Case-study citation checks (Auditor Agent extensions, 2026-04-21) ------

# Match PR citations with high-precision context:
#   "PR #123", "PR#123", "pr #123"                   → group 1 (FT2 default)
#   "[fitme-story#42]"                               → groups 2+3 (cross-repo short)
#   "github.com/owner/repo/pull/123"                 → groups 4+5+6 (URL form)
# Avoids raw "#123" (too many false positives from list numbers, issues, etc.).
# Cross-repo short form requires brackets to avoid false positives on
# "PRs #96-#116", "issue #140", "Fix#123", etc.
# v7.8.3 D-3: updated to 3-alternation form; kept in sync with
#             check-case-study-preflight.py (sync invariant per A2).
_PR_CITATION_PAT = re.compile(
    r"(?:[Pp][Rr]\s*#(\d+))"                              # group 1: FT2 default
    r"|(?:\[([\w-]+)\s*#(\d+)\])(?!\()"                   # groups 2+3: cross-repo short (brackets, NOT markdown link)
    r"|(?:github\.com/([\w-]+)/([\w-]+)/pull/(\d+))"     # groups 4+5+6: URL form
)

# Whitelist mapping repo short names → full "owner/repo" identifiers.
# Kept in sync with check-case-study-preflight.py REPO_MAP (A2 sync invariant).
_CITATION_REPO_MAP: dict[str, str] = {
    "fitme-story": "Regevba/fitme-story",
    "FitTracker2": "Regevba/FitTracker2",
    "ft2": "Regevba/FitTracker2",
}


def load_pr_cache() -> dict | None:
    """Load multi-repo cached PR data from .cache/gh-pr-cache.json.

    v7.8.3 D-3: was set[int] | None (FT2-only). Now returns the multi-repo
    dict shape:
      {"schema_version": 1, "last_refreshed_at": "...",
       "repos": {"Regevba/FitTracker2": {open,merged,closed}, ...}}

    Falls back to a legacy `gh pr list` call for backward compatibility when
    the cache file doesn't exist.

    Returns None if gh is unavailable AND no cache exists (graceful degradation:
    check is skipped rather than failing the whole integrity cycle).
    """
    cache_file = REPO_ROOT / ".cache" / "gh-pr-cache.json"
    if cache_file.exists():
        try:
            return json.loads(cache_file.read_text())
        except Exception:
            pass  # fall through to live gh call

    # Fallback: legacy single-repo gh call (FT2-only).
    try:
        out = subprocess.check_output(
            ["gh", "pr", "list", "--state", "all", "--limit", "500",
             "--json", "number"],
            text=True, stderr=subprocess.DEVNULL,
        )
        numbers = [p["number"] for p in json.loads(out)]
        # Wrap in multi-repo shape so callers work uniformly.
        return {
            "schema_version": 1,
            "last_refreshed_at": None,
            "repos": {
                "Regevba/FitTracker2": {
                    "open": [{"number": n} for n in numbers],
                    "merged": [],
                    "closed": [],
                }
            },
        }
    except (subprocess.CalledProcessError, FileNotFoundError,
            json.JSONDecodeError):
        return None


def _resolve_pr_cite_integrity(match: re.Match, cache: dict) -> str | None:
    """Resolve a _PR_CITATION_PAT match against the multi-repo cache (integrity-check variant).

    Returns an error message string if broken, None if valid.
    Internal helper for audit_case_study_citations().
    """
    if match.group(1):
        repo = "Regevba/FitTracker2"
        pr_num = int(match.group(1))
    elif match.group(2):
        repo_short = match.group(2)
        repo = _CITATION_REPO_MAP.get(repo_short)
        if repo is None:
            return f"cites [{repo_short}#{match.group(3)}] with unknown repo short name '{repo_short}'"
        pr_num = int(match.group(3))
    elif match.group(4):
        repo = f"{match.group(4)}/{match.group(5)}"
        pr_num = int(match.group(6))
    else:
        return None

    repos = cache.get("repos", {})
    if repo not in repos:
        return f"cites PR #{pr_num} in unknown repo '{repo}' (not in cache)"

    repo_cache = repos[repo]
    all_prs = (
        repo_cache.get("open", [])
        + repo_cache.get("merged", [])
        + repo_cache.get("closed", [])
    )
    if not any(pr["number"] == pr_num for pr in all_prs):
        return f"cites PR #{pr_num} in {repo} which does not resolve on GitHub"

    return None


def audit_case_study_citations(pr_cache: dict | None, coverage: "GateCoverage | None" = None) -> list[dict]:
    """Scan every case study .md for PR citations; flag broken ones.

    If pr_cache is None, skip gracefully (gh not available). Returns findings
    with code=BROKEN_PR_CITATION and feature=<relative-path-to-md>.

    Excludes files under `docs/case-studies/meta-analysis/`: those documents
    discuss citations (including false positives), so any PR number appearing
    in their prose is meta-reference, not a real evidentiary claim.

    v7.8.3 D-3: uses resolve_pr_cite() for cross-repo routing via REPO_MAP.
    v7.10: emits Mechanism A coverage (gate BROKEN_PR_CITATION) when `coverage`
    is supplied — every candidate .md is checked unless filtered out.
    """
    if pr_cache is None or not CASE_STUDIES_DIR.exists():
        if coverage is not None:
            coverage.skip("BROKEN_PR_CITATION", "no_pr_cache_or_dir")
        return []
    findings: list[dict] = []
    for f in sorted(CASE_STUDIES_DIR.rglob("*.md")):
        if coverage is not None:
            coverage.candidate("BROKEN_PR_CITATION")
        if f.name in SKIP_CASE_STUDY_FILES:
            if coverage is not None:
                coverage.skip("BROKEN_PR_CITATION", "skip_listed_file")
            continue
        if "meta-analysis" in f.relative_to(CASE_STUDIES_DIR).parts:
            if coverage is not None:
                coverage.skip("BROKEN_PR_CITATION", "meta_analysis_prose")
            continue
        try:
            text = f.read_text()
        except Exception:
            if coverage is not None:
                coverage.skip("BROKEN_PR_CITATION", "unreadable")
            continue
        if coverage is not None:
            coverage.checked("BROKEN_PR_CITATION")
        for m in _PR_CITATION_PAT.finditer(text):
            err = _resolve_pr_cite_integrity(m, pr_cache)
            if err is not None:
                findings.append({
                    "feature": str(f.relative_to(REPO_ROOT)),
                    "severity": "INCONSISTENT",
                    "code": "BROKEN_PR_CITATION",
                    "message": err,
                })
    return findings


# Data-quality tiers convention came in on 2026-04-21 (Gemini audit Tier 2.3).
# Forward-only by policy: case studies dated before this date are exempt.
_TIER_CONVENTION_DATE = "2026-04-21"
_DATE_WRITTEN_PAT = re.compile(
    r"(?im)^\*\*Date written:\*\*\s*(\d{4}-\d{2}-\d{2})|^>\s*\*\*Date:\*\*\s*(\d{4}-\d{2}-\d{2})"
)
# Match T1/T2/T3 labels in their canonical forms:
#   "(T1)", "(T2)", "(T3)", "T1 — ...", "T2: ...", etc.
_TIER_TAG_PAT = re.compile(r"\bT[123]\b[\s—:.\)\(]")


def check_cache_hits_auto_instrumentation_inactive(coverage: "GateCoverage | None" = None) -> list[dict]:
    """Advisory: features with attributed Read events but empty cache_hits[].

    v7.8 Mechanism C wiring (T11 — bridge design §4.3, item 6). The
    PostToolUse:Read hook (`scripts/observe-cache-hit.py`) appends Read
    events to `.claude/logs/_session-<id>.events.jsonl` tagged with the
    `.claude/active-feature` lockfile value. This advisory aggregates
    those attributions and flags features where session events show Reads
    but `state.json::cache_hits[]` is empty — an early warning that
    Mechanism C's auto-collection isn't propagating to state.json (which
    is what v7.9 will promote to enforced via the dual-write contract).

    Severity: ADVISORY only — doesn't affect exit code or finding_count.
    Silent on a fresh install with no session events yet.
    """
    findings: list[dict] = []
    GATE = "CACHE_HITS_AUTO_INSTRUMENTATION_INACTIVE"
    logs_dir = REPO_ROOT / ".claude" / "logs"
    features_dir = REPO_ROOT / ".claude" / "features"
    if not logs_dir.exists() or not features_dir.exists():
        if coverage is not None:
            coverage.skip(GATE, "logs_or_features_dir_missing")
        return findings

    reads_by_feature: dict[str, int] = {}
    for ledger in logs_dir.glob("_session-*.events.jsonl"):
        try:
            text = ledger.read_text()
        except OSError:
            continue
        for line in text.splitlines():
            if not line.strip():
                continue
            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                continue
            if event.get("tool_name") != "Read":
                continue
            feature = (event.get("active_feature") or "").strip()
            if not feature:
                continue
            reads_by_feature[feature] = reads_by_feature.get(feature, 0) + 1

    for feature, count in sorted(reads_by_feature.items()):
        if coverage is not None:
            coverage.candidate(GATE)
        state_path = features_dir / feature / "state.json"
        if not state_path.exists():
            if coverage is not None:
                coverage.skip(GATE, "no_state")
            continue
        try:
            state = json.loads(state_path.read_text())
        except json.JSONDecodeError:
            if coverage is not None:
                coverage.skip(GATE, "invalid_json")
            continue
        if coverage is not None:
            coverage.checked(GATE)
        cache_hits = state.get("cache_hits")
        if isinstance(cache_hits, list) and len(cache_hits) > 0:
            continue
        findings.append({
            "feature": feature,
            "severity": "ADVISORY",
            "code": "CACHE_HITS_AUTO_INSTRUMENTATION_INACTIVE",
            "message": (
                f"{feature}: session ledgers attribute {count} Read "
                f"event(s) to this feature, but state.json::cache_hits[] "
                f"is empty/absent. v7.8 Mechanism C captures session "
                f"events; state.json::cache_hits requires manual "
                f"scripts/log-cache-hit.py until v7.9 promotes "
                f"observe-cache-hit.py to dual-write. See bridge design "
                f"§4.3 + .claude/active-feature lockfile."
            ),
        })
    return findings


def check_branch_isolation_historical(coverage: "GateCoverage | None" = None) -> list[dict]:
    """T17 (Block D, framework-v7-8-branch-isolation): forward-only advisory.

    Audits .claude/features/<f>/state.json against `git log --all --oneline -- path/`
    to detect features whose entire git history happened on `main` (no
    feature/<name> branch ever existed). Forward-only: applies only to
    features with created_at >= 2026-05-07 (this gate's ship date).

    Severity: ADVISORY. Doesn't affect exit code. Surfaces post-hoc the
    failure mode that BRANCH_ISOLATION_VIOLATION (write-time) prevents
    going forward — useful for catching --no-verify bypasses or pre-gate
    ship history.
    """
    findings: list[dict] = []
    GATE = "BRANCH_ISOLATION_HISTORICAL"
    SHIP_DATE = "2026-05-07"
    features_dir = REPO_ROOT / ".claude" / "features"
    if not features_dir.exists():
        if coverage is not None:
            coverage.skip(GATE, "features_dir_missing")
        return findings

    for state_path in sorted(features_dir.glob("*/state.json")):
        feature = state_path.parent.name
        if coverage is not None:
            coverage.candidate(GATE)
        try:
            state = json.loads(state_path.read_text())
        except json.JSONDecodeError:
            if coverage is not None:
                coverage.skip(GATE, "invalid_json")
            continue

        # Forward-only: skip pre-ship-date features
        created = state.get("created_at") or state.get("created", "")
        if not created or created[:10] < SHIP_DATE:
            if coverage is not None:
                coverage.skip(GATE, "pre_ship_date")
            continue

        # Honor opt-out
        if state.get("isolation_opt_out") is True:
            if coverage is not None:
                coverage.skip(GATE, "isolation_opt_out")
            continue

        # F11: exempt reverse-sync-mirrored files. The reverse-sync bot mirrors
        # fitme-story-native state.json into FT2 on a `reverse-sync/*` branch and
        # stamps `state_owner_sync_origin` ending in "-reverse". Such files
        # legitimately never touch an FT2 `feature/*` or `chore/*` branch — the
        # isolation discipline lives in the source repo — so the historical
        # advisory would false-positive on them.
        sync_origin = state.get("state_owner_sync_origin", "")
        if isinstance(sync_origin, str) and sync_origin.endswith("-reverse"):
            if coverage is not None:
                coverage.skip(GATE, "reverse_sync_mirror")
            continue

        # Skip features that have a recorded merge PR — the PR existed on a
        # feature branch even if squash-merge erased the attribution from
        # `git log --source`. The advisory targets features that never had
        # a PR (work happened entirely on main, no isolation), not those
        # whose branches were cleanly merged + deleted.
        merge_phase = (state.get("phases") or {}).get("merge") or {}
        if isinstance(merge_phase, dict) and isinstance(merge_phase.get("pr_number"), int):
            if coverage is not None:
                coverage.skip(GATE, "has_merge_pr")
            continue

        # Also skip features that have been pre-PM-workflow-backfilled or
        # otherwise tagged with an exempt case_study_type — those were
        # historically reconstructed and don't claim isolation discipline.
        cs_type = state.get("case_study_type", "")
        if cs_type in ("pre_pm_workflow_backfill", "no_case_study_required",
                       "roundup", "framework_meta_retroactive"):
            if coverage is not None:
                coverage.skip(GATE, f"exempt_{cs_type}")
            continue

        # Get all branches that touched this feature's directory
        feature_dir_relative = state_path.parent.relative_to(REPO_ROOT).as_posix()
        try:
            out = subprocess.check_output(
                ["git", "log", "--all", "--oneline", "--source",
                 "--", feature_dir_relative],
                cwd=REPO_ROOT,
                text=True,
                stderr=subprocess.DEVNULL,
            )
        except Exception:
            if coverage is not None:
                coverage.skip(GATE, "git_log_failed")
            continue

        # Past all early-skip gates: this feature is actually evaluated.
        if coverage is not None:
            coverage.checked(GATE)

        # Parse: each line starts with "<sha> <ref>" via --source. We want
        # to know if ANY commit landed on a feature/<name> branch.
        on_feature_branch = False
        for line in out.splitlines():
            line = line.strip()
            if not line:
                continue
            # Format with --source: "abc1234 refs/heads/feature/name commit message"
            # Newer git uses "<sha>\t<ref>" or similar — parse loosely.
            parts = line.split(None, 2)
            if len(parts) >= 2:
                ref = parts[1] if "/" in parts[1] else ""
                # F11: reverse-sync/* is also a legitimate origin (secondary
                # signal alongside the state_owner_sync_origin "-reverse" skip).
                if "feature/" in ref or "chore/" in ref or "reverse-sync/" in ref:
                    on_feature_branch = True
                    break

        # Fallback: when --delete-branch is used on PR merge, the feature/<name>
        # ref disappears and `git log --source` only shows the squash commit on
        # main. Accept a conventional-commit subject like `chore(<feature>):`
        # or `feat(<feature>):` as evidence the work originated in a branch.
        # False-positive risk is negligible: gaming requires direct-to-main
        # commit AND naming the feature in the subject — the opposite of how
        # bypasses look.
        if not on_feature_branch:
            try:
                subjects = subprocess.check_output(
                    ["git", "log", "--all", "--format=%s",
                     "--", feature_dir_relative],
                    cwd=REPO_ROOT, text=True, stderr=subprocess.DEVNULL,
                )
                cc_pattern = re.compile(
                    r"^(?:chore|feat|fix|docs|refactor|test|perf|style|ci|build)"
                    r"\(" + re.escape(feature) + r"\)", re.MULTILINE,
                )
                if cc_pattern.search(subjects):
                    on_feature_branch = True
            except Exception:
                pass

        if not on_feature_branch:
            findings.append({
                "feature": feature,
                "severity": "ADVISORY",
                "code": "BRANCH_ISOLATION_HISTORICAL",
                "message": (
                    f"{feature}: feature created {created[:10]} (>= ship date "
                    f"{SHIP_DATE}) but git history shows no feature/* or "
                    f"chore/* branch touched its files. Likely committed "
                    f"directly on main, bypassing branch isolation. Set "
                    f"state.json::isolation_opt_out: true with a reason to "
                    f"silence this advisory if intentional."
                ),
            })
    return findings


def _plist_references_ft2(plist_path: Path, program_args: list, wd: str | None) -> bool:
    """Return True iff the plist appears to be an FT2-related launchd job.

    Heuristic (any one is sufficient):
      - filename contains "fittracker" (case-insensitive)
      - ProgramArguments references a path under this repo
      - WorkingDirectory starts with a known FT2 repo path

    Used by sub-fix (a) so the path-resolution advisory fires for ALL FT2
    plists (not just feature-attached ones). The 2026-05-19 SSD migration
    broke the daily-checkpoint plist (no feature attached) for 5 days
    silently; without this broader scan, the new sub-checks wouldn't catch it.
    """
    if "fittracker" in plist_path.name.lower():
        return True
    all_args_str = " ".join(str(a) for a in program_args)
    if "/FitTracker2" in all_args_str or "/fitme-story" in all_args_str:
        return True
    if isinstance(wd, str) and ("/FitTracker2" in wd or "/fitme-story" in wd):
        return True
    return False


def check_branch_isolation_launchd_drift() -> list[dict]:
    """T18 (Block D, framework-v7-8-branch-isolation): macOS-only advisory.

    Scans ~/Library/LaunchAgents/*.plist files for jobs related to this repo.

    Original (T18): for jobs that reference scripts writing to
    .claude/features/<feature>/, verifies their WorkingDirectory key resolves
    to the expected worktree path (per state.json::worktree_path). Triggered
    by the HADF Phase 2 incident (2026-04-30).

    Sub-fix (a) extension (v7.9.1, 2026-06-04): for ALL FT2-related plists
    (detected via filename heuristic + ProgramArguments + WorkingDirectory
    pattern), validates 3 path-resolution health checks:
      (i)   WorkingDirectory path resolves to an extant directory
      (ii)  ProgramArguments[0] script path resolves to an extant file
      (iii) StandardOutPath / StandardErrorPath parent dir is writable

    Catches the 2026-05-19 SSD-migration drift class (5 silently-broken cron
    days from `/Volumes/DevSSD 1/...` path hardcoding) on day 1.

    Skipped on Linux/CI (launchd is macOS-only).
    """
    findings: list[dict] = []
    if sys.platform != "darwin":
        return findings

    launchagents = Path.home() / "Library" / "LaunchAgents"
    if not launchagents.exists():
        return findings

    features_dir = REPO_ROOT / ".claude" / "features"
    if not features_dir.exists():
        return findings

    # Build map of feature → expected worktree (for the T18 worktree check)
    expected_worktrees: dict[str, str] = {}
    for state_path in features_dir.glob("*/state.json"):
        try:
            state = json.loads(state_path.read_text())
        except json.JSONDecodeError:
            continue
        wt = state.get("worktree_path")
        if isinstance(wt, str) and wt:
            expected_worktrees[state_path.parent.name] = wt

    try:
        import plistlib
    except ImportError:
        return findings

    for plist_path in launchagents.glob("*.plist"):
        try:
            with open(plist_path, "rb") as f:
                plist = plistlib.load(f)
        except (plistlib.InvalidFileException, OSError):
            continue

        program_args = plist.get("ProgramArguments", []) or []
        wd = plist.get("WorkingDirectory")
        all_args_str = " ".join(str(a) for a in program_args)

        # T18 original: feature-attached worktree mismatch check.
        if isinstance(wd, str) and expected_worktrees:
            for feature, expected_wt in expected_worktrees.items():
                if f".claude/features/{feature}" in all_args_str:
                    if not wd.startswith(expected_wt):
                        findings.append({
                            "feature": feature,
                            "severity": "ADVISORY",
                            "code": "BRANCH_ISOLATION_LAUNCHD_DRIFT",
                            "message": (
                                f"{feature}: launchd plist {plist_path.name} "
                                f"references this feature in ProgramArguments but "
                                f"WorkingDirectory ({wd}) does not start with the "
                                f"expected worktree ({expected_wt}). Relative writes "
                                f"from this job will resolve against the wrong tree. "
                                f"This is the same failure mode that caused the "
                                f"HADF Phase 2 incident (2026-04-30)."
                            ),
                        })

        # Sub-fix (a): broader path-resolution health checks for any FT2 plist.
        if not _plist_references_ft2(plist_path, program_args, wd):
            continue

        # (i) WorkingDirectory exists as a directory.
        if isinstance(wd, str) and wd:
            wd_path = Path(wd)
            if not wd_path.is_dir():
                findings.append({
                    "feature": "_launchd",
                    "severity": "ADVISORY",
                    "code": "BRANCH_ISOLATION_LAUNCHD_DRIFT",
                    "message": (
                        f"launchd plist {plist_path.name}: WorkingDirectory "
                        f"({wd}) does not resolve to an extant directory. "
                        f"launchd will silently exit 78 every fire. This is the "
                        f"2026-05-19 SSD-migration class — `/Volumes/DevSSD 1/...` "
                        f"vs canonical `/Volumes/DevSSD/...` after a mount swap."
                    ),
                })

        # (ii) ProgramArguments[0] script path exists as a file.
        if program_args:
            # Skip interpreter prefix; find the first real script/binary path.
            # `/bin/bash <script>` → check the script.
            # `python3 <script>` → check the script.
            first = str(program_args[0])
            interpreter_prefixes = {
                "/bin/bash", "/bin/sh", "/usr/bin/env",
                "python3", "python", "/usr/bin/python3",
            }
            target_arg = (
                str(program_args[1]) if (first in interpreter_prefixes
                                          and len(program_args) > 1)
                else first
            )
            # Only check absolute paths — interpreter-name forms like "bash"
            # rely on PATH resolution and are out of scope.
            if target_arg.startswith("/"):
                target_path = Path(target_arg)
                if not target_path.is_file():
                    findings.append({
                        "feature": "_launchd",
                        "severity": "ADVISORY",
                        "code": "BRANCH_ISOLATION_LAUNCHD_DRIFT",
                        "message": (
                            f"launchd plist {plist_path.name}: ProgramArguments "
                            f"script ({target_arg}) does not resolve to an extant "
                            f"file. Cron will silently exit 78 every fire. Either "
                            f"the script moved (post-refactor) or the path "
                            f"hardcoded a stale mount point."
                        ),
                    })

        # (iii) StandardOutPath + StandardErrorPath parent dir is writable.
        for key in ("StandardOutPath", "StandardErrorPath"):
            out_path_str = plist.get(key)
            if not isinstance(out_path_str, str) or not out_path_str:
                continue
            out_parent = Path(out_path_str).parent
            if not out_parent.exists():
                findings.append({
                    "feature": "_launchd",
                    "severity": "ADVISORY",
                    "code": "BRANCH_ISOLATION_LAUNCHD_DRIFT",
                    "message": (
                        f"launchd plist {plist_path.name}: {key} ({out_path_str}) "
                        f"parent directory does not exist. launchd cannot write "
                        f"the log file; daemon may refuse to load entirely."
                    ),
                })
                continue
            if not os.access(out_parent, os.W_OK):
                findings.append({
                    "feature": "_launchd",
                    "severity": "ADVISORY",
                    "code": "BRANCH_ISOLATION_LAUNCHD_DRIFT",
                    "message": (
                        f"launchd plist {plist_path.name}: {key} parent "
                        f"({out_parent}) is not writable by current user. "
                        f"launchd cannot capture stdout/stderr; failures will "
                        f"be invisible to `launchctl list <label>`."
                    ),
                })

    return findings


def check_feature_closure_completeness_cycle() -> list[dict]:
    """T19 (Block D): cycle-time mirror of FEATURE_CLOSURE_COMPLETENESS.

    Re-runs the same predicates as the write-time gate against every
    feature with current_phase=complete. Catches --no-verify bypasses
    and any drift introduced post-merge. Forward-only: applies to features
    with created_at >= 2026-05-07.

    Severity: ADVISORY in v7.8; promoted to gating findings in v7.9.
    """
    findings: list[dict] = []
    SHIP_DATE = "2026-05-07"
    features_dir = REPO_ROOT / ".claude" / "features"
    if not features_dir.exists():
        return findings

    # Reuse the predicate from check-state-schema.py
    try:
        spec_module = importlib.util.spec_from_file_location(
            "_check_schema",
            REPO_ROOT / "scripts" / "check-state-schema.py",
        )
        if spec_module is None or spec_module.loader is None:
            return findings
        css = importlib.util.module_from_spec(spec_module)
        spec_module.loader.exec_module(css)
    except Exception:
        return findings

    for state_path in sorted(features_dir.glob("*/state.json")):
        try:
            state = json.loads(state_path.read_text())
        except json.JSONDecodeError:
            continue

        if state.get("current_phase") != "complete":
            continue

        # Forward-only
        created = state.get("created_at") or state.get("created", "")
        if not created or created[:10] < SHIP_DATE:
            continue

        # Run the predicate (force enforce_transition=True so it executes)
        # We bypass the diff-based "is this a transition?" check by setting
        # enforce_transition and reading the state directly.
        try:
            sub_findings = css.check_feature_closure_completeness(
                state, state_path, coverage=None, enforce_transition=True,
            )
        except Exception:
            continue

        for sf in sub_findings:
            findings.append({
                "feature": state_path.parent.name,
                "severity": "ADVISORY",
                "code": "FEATURE_CLOSURE_COMPLETENESS",
                "message": (
                    f"{state_path.parent.name}: cycle-time mirror detected "
                    f"closure-completeness violation ({sf.get('violation', 'unknown')}). "
                    f"{sf.get('remediation', '')}"
                ),
            })
    return findings


def check_state_tasks_filesystem_drift(coverage: "GateCoverage | None" = None) -> list[dict]:
    """F1 (v8.x docket, Theme A): STATE_TASKS_FILESYSTEM_DRIFT cycle-time advisory.

    Detects the task ledger (state.json::tasks[]) drifting from the work that
    actually shipped. For every feature with current_phase=complete and an
    empty/missing tasks[], fires when (a) the feature was created on/after the
    v7.6 task-discipline date AND (b) it is not a framework-meta feature AND
    (c) the filesystem shows shipped artifacts (a case study, related_prs, or a
    merge PR number). The fire means: the work shipped, but the ledger is empty.

    Empirically surfaced when 5-of-10 roadmap-stress-test sub-features were
    `complete` with empty tasks[] despite shipped work (the post-squash-merge
    drift class F2 catches at Phase 0; this is its standing cycle-time mirror).

    Severity: ADVISORY only — never affects finding_count or exit code. This is
    a backlog-surfacing advisory (like TIER_TAG_LIKELY_INCORRECT), not a
    promotion candidate. Pre-task-discipline features (created < 2026-04-25) are
    skipped as bounded backfill-debt, not active drift.

    Emits Mechanism A coverage (gate STATE_TASKS_FILESYSTEM_DRIFT) when
    `coverage` is supplied — one candidate per complete+empty-tasks feature.

    Full design: .claude/features/f1-state-tasks-filesystem-drift/calibration-artifacts.md
    """
    GATE = "STATE_TASKS_FILESYSTEM_DRIFT"
    TASK_DISCIPLINE_DATE = "2026-04-25"  # v7.6 ship — task-ledger discipline began
    BACKFILL_EXEMPT = {
        "pre_pm_workflow_backfill", "roundup",
        "no_case_study_required", "framework_meta_retroactive",
    }
    findings: list[dict] = []
    if not FEATURES_DIR.exists():
        if coverage is not None:
            coverage.skip(GATE, "features_dir_missing")
        return findings

    for state_path in sorted(FEATURES_DIR.glob("*/state.json")):
        name = state_path.parent.name
        try:
            d = json.loads(state_path.read_text())
        except (OSError, json.JSONDecodeError):
            continue

        if d.get("current_phase") != "complete":
            continue
        tasks = d.get("tasks") or []
        if tasks:
            continue  # populated ledger — not a candidate

        # Candidate: complete + empty tasks[].
        if coverage is not None:
            coverage.candidate(GATE)

        created = (d.get("created_at") or d.get("created") or "")[:10]
        if created and created < TASK_DISCIPLINE_DATE:
            if coverage is not None:
                coverage.skip(GATE, "pre_task_discipline")
            continue

        if (
            name.startswith("framework-v")
            or (d.get("work_type") or "").lower() == "framework"
            or (d.get("work_subtype") or "").startswith("framework")
            or d.get("case_study_type") in BACKFILL_EXEMPT
            or (d.get("platforms_tested_provenance") or "").startswith("exempt:")
        ):
            if coverage is not None:
                coverage.skip(GATE, "exempt_framework_meta")
            continue

        # Filesystem half: is there shipped-artifact evidence?
        if (CASE_STUDIES_DIR / f"{name}-case-study.md").exists():
            artifact = "case study"
        elif d.get("related_prs"):
            artifact = "related_prs"
        elif (d.get("phases", {}).get("merge", {}) or {}).get("pr_number"):
            artifact = f"merge PR #{d['phases']['merge']['pr_number']}"
        else:
            if coverage is not None:
                coverage.skip(GATE, "no_shipped_artifact")
            continue

        if coverage is not None:
            coverage.checked(GATE)
        findings.append({
            "feature": name,
            "severity": "ADVISORY",
            "code": GATE,
            "message": (
                f"{name}: complete with shipped artifacts ({artifact}) but "
                f"tasks[] is empty — the task ledger drifted from the work. "
                f"Backfill tasks[] (e.g. `make close-feature FEATURE={name}`) "
                f"or tag the feature exempt (case_study_type / framework-meta)."
            ),
        })
    return findings


def check_dependency_graph_cycles(coverage: "GateCoverage | None" = None) -> list[dict]:
    """F3 (v8.x docket, Theme A): DEPENDENCY_GRAPH_CYCLE cycle-time advisory.

    Builds a directed dependency graph across all features from the structured
    edges scheduled_after.predecessor + parent_feature (edge A->B means "A is
    scheduled after / depends on B") and flags graph-integrity problems:

      1. dangling — an edge target is not an existing feature directory
      2. self-loop — A -> A
      3. cycle — a directed cycle A -> B -> ... -> A (deduped via canonical
         rotation so the same cycle isn't reported from every member)

    Surfaced because one dependency cycle was caught manually, post-hoc, on a
    multi-feature roadmap. `depends_on` is intentionally EXCLUDED: in practice
    it holds free-text prerequisites, not feature names, so treating it as an
    edge would manufacture dangling-reference false positives.

    Severity: ADVISORY only — never affects finding_count or exit code.
    Emits Mechanism A coverage (gate DEPENDENCY_GRAPH_CYCLE) when `coverage` is
    supplied — one candidate per feature that carries >=1 structured edge.

    Full design: .claude/features/f3-dependency-graph-cycle-check/calibration-artifacts.md
    """
    GATE = "DEPENDENCY_GRAPH_CYCLE"
    findings: list[dict] = []
    if not FEATURES_DIR.exists():
        if coverage is not None:
            coverage.skip(GATE, "features_dir_missing")
        return findings

    nodes: set[str] = set()
    states: dict[str, dict] = {}
    for state_path in sorted(FEATURES_DIR.glob("*/state.json")):
        name = state_path.parent.name
        nodes.add(name)
        try:
            states[name] = json.loads(state_path.read_text())
        except (OSError, json.JSONDecodeError):
            states[name] = {}

    def _edges(d: dict) -> list[tuple[str, str]]:
        """(kind, target) structured dependency edges for one feature."""
        out: list[tuple[str, str]] = []
        sa = d.get("scheduled_after")
        if isinstance(sa, dict) and isinstance(sa.get("predecessor"), str) and sa["predecessor"]:
            out.append(("scheduled_after", sa["predecessor"]))
        elif isinstance(sa, str) and sa:
            out.append(("scheduled_after", sa))
        pf = d.get("parent_feature")
        if isinstance(pf, str) and pf:
            out.append(("parent_feature", pf))
        return out

    adj: dict[str, list[str]] = {}
    for name in sorted(nodes):
        edges = _edges(states.get(name, {}))
        if not edges:
            continue
        # Candidate: a graph participant (has >=1 structured edge).
        if coverage is not None:
            coverage.candidate(GATE)
            coverage.checked(GATE)
        for kind, tgt in edges:
            if tgt not in nodes:
                findings.append({
                    "feature": name,
                    "severity": "ADVISORY",
                    "code": GATE,
                    "message": (
                        f"{name}: {kind} references '{tgt}', which is not an "
                        f"existing feature (dangling dependency reference)."
                    ),
                })
                continue
            if tgt == name:
                findings.append({
                    "feature": name,
                    "severity": "ADVISORY",
                    "code": GATE,
                    "message": f"{name}: {kind} points at itself (self-dependency).",
                })
                continue
            adj.setdefault(name, []).append(tgt)

    # Cycle detection (iterative DFS, WHITE/GREY/BLACK) with canonical dedup.
    WHITE, GREY, BLACK = 0, 1, 2
    color = {n: WHITE for n in nodes}
    seen_cycles: set[tuple[str, ...]] = set()

    def _canonical(cycle: list[str]) -> tuple[str, ...]:
        # cycle is the node list from the back-edge target to the current node
        # (no repeated closing node); rotate so the lexicographically smallest
        # node leads → one canonical key per distinct cycle.
        if not cycle:
            return tuple()
        i = cycle.index(min(cycle))
        return tuple(cycle[i:] + cycle[:i])

    def _dfs(start: str) -> None:
        stack = [(start, iter(adj.get(start, [])))]
        path = [start]
        color[start] = GREY
        while stack:
            u, it = stack[-1]
            advanced = False
            for v in it:
                if color.get(v) == GREY:  # back-edge → cycle
                    idx = path.index(v)
                    key = _canonical(path[idx:])
                    if key not in seen_cycles:
                        seen_cycles.add(key)
                        findings.append({
                            "feature": v,
                            "severity": "ADVISORY",
                            "code": GATE,
                            "message": (
                                "dependency cycle detected: "
                                + " -> ".join(list(key) + [key[0]])
                                + " (scheduled_after / parent_feature). Break the "
                                "cycle — a feature cannot transitively depend on itself."
                            ),
                        })
                elif color.get(v) == WHITE:
                    color[v] = GREY
                    path.append(v)
                    stack.append((v, iter(adj.get(v, []))))
                    advanced = True
                    break
            if not advanced:
                color[u] = BLACK
                stack.pop()
                path.pop()

    for n in sorted(nodes):
        if color[n] == WHITE:
            _dfs(n)
    return findings


def check_gate_coverage_zero() -> list[dict]:
    """GATE_COVERAGE_ZERO (advisory, v7.10 candidate — built 2026-06-08).

    Reads the F17 `gate-last-fired.json` index (refreshed before integrity-check
    runs). Flags a HISTORICALLY-ACTIVE gate that went SILENT while the telemetry
    corpus stayed active — i.e. it stopped being evaluated as a candidate even
    though other gates kept firing. This is the PR #317 dispatch-unreachable /
    silent-pass failure mode (a gate whose check site became unreachable so it
    no longer emits Mechanism A coverage).

    Relative-staleness semantic (low false-positive):
      - corpus_latest = most recent candidate activity across ALL gates (proves
        the framework is actively committing + telemetry is flowing).
      - A gate with >= MIN_CANDIDATES historical candidates whose own last
        activity is > STALE_DAYS behind corpus_latest → flagged.

    Advisory only; the relative threshold + the 14-day v7.10 calibration window
    absorb the legitimate "this gate only fires on rare transitions" case.
    """
    index_path = REPO_ROOT / ".claude" / "shared" / "gate-last-fired.json"
    findings: list[dict] = []
    if not index_path.is_file():
        return findings
    try:
        idx = json.loads(index_path.read_text())
    except (json.JSONDecodeError, OSError):
        return findings
    gates = idx.get("gates", {})
    if not isinstance(gates, dict) or not gates:
        return findings

    MIN_CANDIDATES = 20   # only consider gates with real historical coverage
    STALE_DAYS = 14       # silent for this long (relative to the corpus) → flag

    def _p(ts):
        if not ts:
            return None
        try:
            return datetime.fromisoformat(str(ts).replace("Z", "+00:00"))
        except (ValueError, TypeError):
            return None

    def _last_activity(stats: dict):
        parsed = [p for p in (_p(stats.get("last_checked_at")),
                              _p(stats.get("last_skipped_at"))) if p]
        return max(parsed) if parsed else None

    activities = {g: _last_activity(s) for g, s in gates.items() if isinstance(s, dict)}
    corpus_latest = max((a for a in activities.values() if a), default=None)
    if corpus_latest is None:
        return findings

    for gate, stats in sorted(gates.items()):
        if not isinstance(stats, dict):
            continue

        # v7.10 refinement — the MIS-WIRE signature (distinct from the staleness
        # case below). A gate REGISTERED in the index but whose every counter is
        # zero (candidates == checked == skipped == firings == 0) has a check
        # site that runs but never reaches a single candidate — the classic
        # "gate function present, emission key wrong / loop unreachable" bug the
        # cache_hits keying incident was. NOT the same as a healthy zero-firing
        # gate (e.g. STATE_OWNER_MISSING: thousands of candidates, zero
        # violations) — those have non-zero candidates and are silent here.
        # Checked BEFORE the MIN_CANDIDATES filter, which would otherwise skip it.
        if (
            stats.get("total_candidates", 0) == 0
            and stats.get("total_checked", stats.get("total_firings", 0)) == 0
            and stats.get("total_skips", 0) == 0
            # T13: a gate with failure history is demonstrably running (it caught
            # a violation recorded in an integrity snapshot) — it's a cycle-time
            # code that doesn't emit Mechanism A coverage, NOT a mis-wired gate.
            and stats.get("last_failed_at") is None
        ):
            findings.append({
                "feature": "—",
                "severity": "ADVISORY",
                "code": "GATE_COVERAGE_ZERO",
                "message": (
                    f"GATE_COVERAGE_ZERO: gate `{gate}` is registered in the "
                    f"coverage index but every counter is zero "
                    f"(candidates=0, checked=0, skipped=0) — its check site runs "
                    f"but never reaches a candidate. Likely mis-wired emission "
                    f"key or an unreachable loop (cache_hits-keying bug class). "
                    f"Advisory; v7.10 enforcement candidate."
                ),
            })
            continue

        if stats.get("total_candidates", 0) < MIN_CANDIDATES:
            continue
        last = activities.get(gate)
        if last is None:
            continue
        behind_days = (corpus_latest - last).days
        if behind_days > STALE_DAYS:
            findings.append({
                "feature": "—",
                "severity": "ADVISORY",
                "code": "GATE_COVERAGE_ZERO",
                "message": (
                    f"GATE_COVERAGE_ZERO: gate `{gate}` ({stats.get('total_candidates')} "
                    f"historical candidates) last emitted Mechanism A coverage "
                    f"{last.date()}, {behind_days}d behind the corpus latest "
                    f"({corpus_latest.date()}). It may have stopped being evaluated — "
                    f"verify its check site is still reachable (PR #317 silent-pass class). "
                    f"Advisory; v7.10 enforcement candidate."
                ),
            })
    return findings


def check_tier_tags_advisory(coverage: "GateCoverage | None" = None) -> list[dict]:
    """Run validate-tier-tags.py; emit findings as ADVISORY (not failure).

    Added v7.7 M3 T18. This is the 14th cycle-time check code.
    Advisory severity: appears in output but does NOT cause non-zero exit
    and is NOT counted in finding_count (to preserve regression baseline).
    Promotion to gating decided +7 days based on FP-rate baseline (T19).
    """
    GATE = "TIER_TAG_LIKELY_INCORRECT"
    if coverage is not None:
        coverage.candidate(GATE)
    try:
        result = subprocess.run(
            ["python3", str(REPO_ROOT / "scripts" / "validate-tier-tags.py"),
             "--all"],
            capture_output=True, text=True,
            cwd=str(REPO_ROOT),
        )
        if coverage is not None:
            coverage.checked(GATE)
        findings = []
        for line in result.stdout.strip().split("\n"):
            if line:
                findings.append({
                    "feature": line.split(":")[1].strip() if ":" in line else "unknown",
                    "severity": "ADVISORY",
                    "code": "TIER_TAG_LIKELY_INCORRECT",
                    "message": line,
                })
        return findings
    except Exception as exc:
        if coverage is not None:
            coverage.skip(GATE, "checker_exception")
        return [{
            "feature": "validate-tier-tags",
            "severity": "ADVISORY",
            "code": "TIER_TAG_LIKELY_INCORRECT",
            "message": f"heuristic checker raised exception: {exc}",
        }]


def audit_case_study_tier_tags(coverage: "GateCoverage | None" = None) -> list[dict]:
    """Flag post-2026-04-21 case studies that lack any T1/T2/T3 tier tag.

    Added 2026-04-24 per Gemini audit Tier 2.3 enforcement follow-through.
    The data-quality-tiers convention requires every quantitative metric in a
    case study dated on or after the convention's introduction to carry a
    tier label. This check counts presence, not exhaustiveness — a single
    T1/T2/T3 mention is enough to pass. Exhaustive enforcement would produce
    too many false positives on legitimate non-metric prose.

    Exempt: files under `docs/case-studies/meta-analysis/`, the template,
    README, data-quality-tiers.md itself, and any case study whose extracted
    "Date written:" header is older than 2026-04-21 (forward-only policy).

    v7.10: emits Mechanism A coverage (gate CASE_STUDY_MISSING_TIER_TAGS) when
    `coverage` is supplied — a candidate becomes `checked` only once it passes
    the forward-only date filter (post-convention dated case studies).
    """
    if not CASE_STUDIES_DIR.exists():
        if coverage is not None:
            coverage.skip("CASE_STUDY_MISSING_TIER_TAGS", "no_dir")
        return []
    findings: list[dict] = []
    for f in sorted(CASE_STUDIES_DIR.rglob("*.md")):
        if coverage is not None:
            coverage.candidate("CASE_STUDY_MISSING_TIER_TAGS")
        if f.name in SKIP_CASE_STUDY_FILES or f.name == "data-quality-tiers.md":
            if coverage is not None:
                coverage.skip("CASE_STUDY_MISSING_TIER_TAGS", "skip_listed_file")
            continue
        if "meta-analysis" in f.relative_to(CASE_STUDIES_DIR).parts:
            if coverage is not None:
                coverage.skip("CASE_STUDY_MISSING_TIER_TAGS", "meta_analysis_prose")
            continue
        try:
            text = f.read_text()
        except Exception:
            if coverage is not None:
                coverage.skip("CASE_STUDY_MISSING_TIER_TAGS", "unreadable")
            continue
        # Extract date_written from the header (same regex family as
        # documentation-debt-report.py uses, plus explicit capture).
        date_match = _DATE_WRITTEN_PAT.search(text)
        if not date_match:
            if coverage is not None:
                coverage.skip("CASE_STUDY_MISSING_TIER_TAGS", "no_date_header")
            continue  # No date extracted — can't determine if post-convention
        date_written = date_match.group(1) or date_match.group(2)
        if not date_written or date_written < _TIER_CONVENTION_DATE:
            if coverage is not None:
                coverage.skip("CASE_STUDY_MISSING_TIER_TAGS", "pre_convention_date")
            continue  # Pre-convention — grandfathered by the forward-only policy
        if coverage is not None:
            coverage.checked("CASE_STUDY_MISSING_TIER_TAGS")
        if not _TIER_TAG_PAT.search(text):
            findings.append({
                "feature": str(f.relative_to(REPO_ROOT)),
                "severity": "WARN",
                "code": "CASE_STUDY_MISSING_TIER_TAGS",
                "message": f"dated {date_written} (>= {_TIER_CONVENTION_DATE}) "
                           f"but contains no T1/T2/T3 tier tag; see "
                           f"docs/case-studies/data-quality-tiers.md",
            })
    return findings


def check_pattern_skill_unmapped(coverage: "GateCoverage | None" = None) -> list[dict]:
    """Advisory: Observed-Patterns-Catalog IDs missing from pattern-skill-map.json.

    v7.9.1 pattern↔skill overlay. Parses every pattern ID from the catalog
    section headings (`### #N …` gate entries + `### WN …` workflow entries)
    and flags any that is absent from `.claude/shared/pattern-skill-map.json`
    OR present but mapped to zero skills. Keeps the overlay map honest as the
    append-only catalog grows: a new pattern added to observed-patterns.md
    without a corresponding map entry surfaces here.

    Severity: ADVISORY only — never affects finding_count or exit code.
    Silent when either file is missing (degrades gracefully).

    v7.10: emits Mechanism A coverage (gate PATTERN_SKILL_UNMAPPED) when
    `coverage` is supplied — one candidate per catalog pattern ID evaluated.
    """
    catalog = REPO_ROOT / ".claude" / "integrity" / "observed-patterns.md"
    map_path = REPO_ROOT / ".claude" / "shared" / "pattern-skill-map.json"
    if not catalog.exists() or not map_path.exists():
        if coverage is not None:
            coverage.skip("PATTERN_SKILL_UNMAPPED", "catalog_or_map_missing")
        return []

    import re as _re
    try:
        text = catalog.read_text()
    except OSError:
        if coverage is not None:
            coverage.skip("PATTERN_SKILL_UNMAPPED", "catalog_unreadable")
        return []
    # Section headings: "### #12 ..." (gate) or "### W9 — ..." (workflow).
    catalog_ids = set(_re.findall(r"^### (#\d+|W\d+)\b", text, flags=_re.MULTILINE))
    if not catalog_ids:
        if coverage is not None:
            coverage.skip("PATTERN_SKILL_UNMAPPED", "no_catalog_ids")
        return []

    try:
        entries = json.loads(map_path.read_text())
    except (OSError, json.JSONDecodeError):
        if coverage is not None:
            coverage.skip("PATTERN_SKILL_UNMAPPED", "map_unreadable")
        return []
    mapped = {e.get("id"): e.get("skills", []) for e in entries}

    # Self-doc meta-entries: catalog patterns that document the overlay TOOL
    # itself (not a work-blocking pattern), intentionally absent from the
    # work-blocking map. W33 documents the pattern↔skill overlay (v7.9.1).
    # (Originally numbered W29 when the feature branch opened 2026-06-04 10:29 UTC;
    #  renumbered to W33 during rebase because PRs #620/#621/#623/#625 landed
    #  W29-W32 the same afternoon with non-overlay content.)
    SELF_DOC_EXEMPT = {"W33"}

    findings: list[dict] = []
    for pid in sorted(catalog_ids - SELF_DOC_EXEMPT, key=lambda x: (x[0] != "#", x)):
        if coverage is not None:
            coverage.candidate("PATTERN_SKILL_UNMAPPED")
            coverage.checked("PATTERN_SKILL_UNMAPPED")
        if pid not in mapped:
            findings.append({
                "feature": "pattern-skill-map",
                "severity": "ADVISORY",
                "code": "PATTERN_SKILL_UNMAPPED",
                "message": (
                    f"catalog pattern {pid} (observed-patterns.md) is absent "
                    f"from .claude/shared/pattern-skill-map.json — add an entry "
                    f"+ re-run `make gen-skill-preflight`."
                ),
            })
        elif not mapped[pid]:
            findings.append({
                "feature": "pattern-skill-map",
                "severity": "ADVISORY",
                "code": "PATTERN_SKILL_UNMAPPED",
                "message": (
                    f"catalog pattern {pid} is present in pattern-skill-map.json "
                    f"but mapped to zero skills — assign >=1 skill."
                ),
            })
    return findings


def discover_case_studies() -> list[dict]:
    results = []
    if not CASE_STUDIES_DIR.exists():
        return results
    for f in sorted(CASE_STUDIES_DIR.glob("*.md")):
        if f.name in SKIP_CASE_STUDY_FILES:
            continue
        stat = f.stat()
        results.append({
            "path": str(f.relative_to(REPO_ROOT)),
            "size_bytes": stat.st_size,
            "first_commit_date": first_commit_date(f),
        })
    return results


def build_snapshot(snapshot_trigger: str) -> dict:
    # v7.9.1 F-LAUNCHD-DRIFT-EXTENSION sub-fix (b):
    # If ensure-pr-cache-fresh.py wrote a fresh failure flag (within the last
    # hour, typically from cron context where gh auth is unavailable), the PR
    # cache is known-stale. Skipping BROKEN_PR_CITATION + PR_NUMBER_UNRESOLVED
    # avoids 300+ phantom findings; the operator sees one explicit advisory
    # ("PR_CACHE_REFRESH_FAILED") in the report instead.
    skip_pr_gates, refresh_flag_payload = pr_cache_refresh_failed_recently()

    # Load PR cache ONCE, before the per-feature loop, so audit_feature()
    # and audit_case_study_citations() share the same gh call result.
    global _PR_CACHE
    _PR_CACHE = load_pr_cache() if not skip_pr_gates else None
    citation_check_ran = _PR_CACHE is not None and not skip_pr_gates

    # v7.10: cycle-time Mechanism A coverage tracker. Created BEFORE the
    # per-feature loop so audit_feature() can emit PHASE_LIE coverage, and
    # reused by the standalone cycle checks below. mode="cycle" distinguishes
    # these full-corpus scans from the write-time gates' staged coverage.
    # Tests opt out via GATE_COVERAGE_LEDGER_DISABLED=1.
    cycle_coverage = GateCoverage(mode="cycle")

    feature_summaries = []
    findings = []
    for d in sorted(FEATURES_DIR.iterdir()) if FEATURES_DIR.exists() else []:
        if not d.is_dir():
            continue
        summary, feat_findings = audit_feature(d, coverage=cycle_coverage)
        feature_summaries.append(summary)
        findings.extend(feat_findings)

    pr_cache_failed_advisory: list[dict] = []
    if skip_pr_gates:
        # Filter PR_NUMBER_UNRESOLVED out of per-feature findings — the cache
        # is known-empty so every cite is a false positive.
        findings = [f for f in findings if f.get("code") != "PR_NUMBER_UNRESOLVED"]
        ts = (refresh_flag_payload or {}).get("ts", "unknown")
        ctx = (refresh_flag_payload or {}).get("context", "unknown")
        reason = (refresh_flag_payload or {}).get("reason", "no reason recorded")
        pr_cache_failed_advisory.append({
            "feature": "_meta",
            "severity": "ADVISORY",
            "code": "PR_CACHE_REFRESH_FAILED",
            "message": (
                f"PR cache refresh failed in {ctx} context at {ts} "
                f"(reason: {reason[:160]}). Skipped BROKEN_PR_CITATION + "
                f"PR_NUMBER_UNRESOLVED to avoid phantom findings. "
                f"Investigate `gh auth status` under cron context."
            ),
        })
    # cycle_coverage (created before the per-feature loop above) accumulates
    # Mechanism A coverage for cycle-time checks. mode="cycle" distinguishes
    # these full-corpus scans from the write-time gates' staged coverage.
    if pr_cache_failed_advisory:
        # Cache known-stale: BROKEN_PR_CITATION was deliberately not run.
        cycle_coverage.skip("BROKEN_PR_CITATION", "pr_cache_refresh_failed")
    else:
        # Auditor Agent case-study citation checks
        findings.extend(audit_case_study_citations(_PR_CACHE, coverage=cycle_coverage))
    findings.extend(audit_case_study_tier_tags(coverage=cycle_coverage))

    # v7.7 M3 T18: advisory tier-tag correctness heuristic (14th check code).
    # v7.8 M2 PR-3 T11: advisory cache_hits auto-instrumentation early-warning
    # (15th check code). Both are ADVISORY severity — included in findings[]
    # for observability but NOT counted in finding_count (preserves regression
    # detection / exit code). v7.10+: all four legacy advisories below now emit
    # cycle coverage so the F17 index + GATE_COVERAGE_ZERO can observe them.
    advisory_findings = (
        check_branch_isolation_historical(coverage=cycle_coverage)
        + check_branch_isolation_launchd_drift()
        + check_feature_closure_completeness_cycle()
        + check_tier_tags_advisory(coverage=cycle_coverage)
        + check_cache_hits_auto_instrumentation_inactive(coverage=cycle_coverage)
        + pr_cache_failed_advisory  # v7.9.1 F-LAUNCHD-DRIFT-EXTENSION sub-fix (b)
        + check_pattern_skill_unmapped(coverage=cycle_coverage)  # v7.9.1 overlay
        + check_gate_coverage_zero()  # v7.10 candidate (built 2026-06-08, advisory)
        + check_state_tasks_filesystem_drift(coverage=cycle_coverage)  # F1 (v8.x Theme A)
        + check_dependency_graph_cycles(coverage=cycle_coverage)  # F3 (v8.x Theme A)
    )
    all_findings = findings + advisory_findings

    # v7.10: persist cycle-time coverage so the F17 index + GATE_COVERAGE_ZERO
    # can observe these three checks. Best-effort: a write failure must never
    # break the integrity scan (the findings above are the load-bearing output).
    if os.environ.get("GATE_COVERAGE_LEDGER_DISABLED") != "1":
        try:
            cycle_coverage.write_jsonl(GATE_COVERAGE_LEDGER)
        except OSError:
            pass

    non_advisory_count = len(findings)

    return {
        "timestamp": now_iso(),
        "commit_head": git_head(),
        "snapshot_context": {
            "trigger": snapshot_trigger,
            "counts_for_trend": snapshot_trigger == "scheduled_cycle",
        },
        "feature_count": len(feature_summaries),
        "case_study_count": len(discover_case_studies()),
        "finding_count": non_advisory_count,
        "advisory_finding_count": len(advisory_findings),
        "findings_by_severity": {
            sev: sum(1 for x in all_findings if x["severity"] == sev)
            for sev in ["CRITICAL", "INCONSISTENT", "MISSING", "WARN", "ADVISORY"]
        },
        "auditor_agent": {
            "citation_check_ran": citation_check_ran,
            "known_pr_count": (
                sum(
                    len(r.get("open", [])) + len(r.get("merged", [])) + len(r.get("closed", []))
                    for r in _PR_CACHE.get("repos", {}).values()
                )
                if _PR_CACHE is not None else None
            ),
        },
        "features": feature_summaries,
        "case_studies": discover_case_studies(),
        "findings": all_findings,
    }


def diff_snapshots(current: dict, previous: dict) -> dict:
    prev_feats = {f["name"]: f for f in previous.get("features", [])}
    curr_feats = {f["name"]: f for f in current.get("features", [])}
    added = sorted(set(curr_feats) - set(prev_feats))
    removed = sorted(set(prev_feats) - set(curr_feats))
    changed = []
    for name in sorted(set(curr_feats) & set(prev_feats)):
        pf, cf = prev_feats[name], curr_feats[name]
        if pf.get("phase") != cf.get("phase"):
            changed.append({"name": name, "field": "phase",
                            "from": pf.get("phase"), "to": cf.get("phase")})
        if pf.get("state_hash") != cf.get("state_hash") and \
           pf.get("phase") == cf.get("phase"):
            changed.append({"name": name, "field": "state_hash",
                            "from": pf.get("state_hash"), "to": cf.get("state_hash")})
        if pf.get("case_study") != cf.get("case_study"):
            changed.append({"name": name, "field": "case_study",
                            "from": pf.get("case_study"), "to": cf.get("case_study")})

    prev_cs = {c["path"] for c in previous.get("case_studies", [])}
    curr_cs = {c["path"] for c in current.get("case_studies", [])}
    cs_added = sorted(curr_cs - prev_cs)
    cs_removed = sorted(prev_cs - curr_cs)

    prev_findings = {(f["feature"], f["code"]) for f in previous.get("findings", [])}
    curr_findings = {(f["feature"], f["code"]) for f in current.get("findings", [])}
    findings_new = sorted(curr_findings - prev_findings)
    findings_resolved = sorted(prev_findings - curr_findings)

    return {
        "previous_timestamp": previous.get("timestamp"),
        "current_timestamp": current.get("timestamp"),
        "features": {"added": added, "removed": removed, "changed": changed},
        "case_studies": {"added": cs_added, "removed": cs_removed},
        "findings": {
            "new": [{"feature": f, "code": c} for f, c in findings_new],
            "resolved": [{"feature": f, "code": c} for f, c in findings_resolved],
            "prev_count": previous.get("finding_count", 0),
            "curr_count": current.get("finding_count", 0),
        },
    }


def render_findings(findings: list[dict]) -> str:
    non_advisory = [f for f in findings if f.get("severity") != "ADVISORY"]
    advisory = [f for f in findings if f.get("severity") == "ADVISORY"]
    if not findings:
        return "✅ No findings."
    lines = [f"{len(non_advisory)} findings"
             + (f" + {len(advisory)} advisory:" if advisory else ":") + "\n"]
    by_sev: dict[str, list] = {}
    for f in findings:
        by_sev.setdefault(f["severity"], []).append(f)
    for sev in ["CRITICAL", "INCONSISTENT", "MISSING", "WARN"]:
        if sev not in by_sev:
            continue
        lines.append(f"## {sev} ({len(by_sev[sev])})")
        for f in sorted(by_sev[sev], key=lambda x: x["feature"]):
            lines.append(f"  - {f['feature']} [{f['code']}]: {f['message']}")
        lines.append("")
    if "ADVISORY" in by_sev:
        lines.append(f"## ADVISORY (not gating) ({len(by_sev['ADVISORY'])})")
        for f in sorted(by_sev["ADVISORY"], key=lambda x: x["feature"]):
            lines.append(f"  - [{f['code']}]: {f['message']}")
        lines.append("")
    return "\n".join(lines)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--snapshot", help="Write snapshot to this path")
    p.add_argument("--compare-to", help="Previous snapshot path for diff")
    p.add_argument("--findings-only", action="store_true",
                   help="Print findings to stdout, no file writes")
    p.add_argument("--strict", action="store_true",
                   help="Exit 1 on ANY findings (default: only on regressions)")
    p.add_argument(
        "--snapshot-trigger",
        choices=["manual", "scheduled_cycle", "local_baseline"],
        default="manual",
        help="Annotate the snapshot source so downstream tools can distinguish cycle data from ad hoc runs.",
    )
    args = p.parse_args()

    snapshot = build_snapshot(args.snapshot_trigger)
    print(f"Features scanned: {snapshot['feature_count']}")
    print(f"Case studies: {snapshot['case_study_count']}")
    advisory_count = snapshot.get("advisory_finding_count", 0)
    advisory_suffix = f" + {advisory_count} advisory" if advisory_count else ""
    non_advisory_sevs = {k: v for k, v in snapshot['findings_by_severity'].items()
                         if v and k != "ADVISORY"}
    print(f"Findings: {snapshot['finding_count']}{advisory_suffix} "
          f"({', '.join(f'{k}={v}' for k, v in non_advisory_sevs.items())})")
    print()
    print(render_findings(snapshot["findings"]))

    if args.findings_only:
        sys.exit(1 if (args.strict and snapshot["finding_count"]) else 0)

    if args.snapshot:
        sp = Path(args.snapshot)
        sp.parent.mkdir(parents=True, exist_ok=True)
        sp.write_text(json.dumps(snapshot, indent=2) + "\n")
        print(f"\nSnapshot written: {sp}")

    if args.compare_to:
        prev = json.loads(Path(args.compare_to).read_text())
        diff = diff_snapshots(snapshot, prev)
        print("\n=== Diff vs previous ===")
        print(json.dumps(diff, indent=2))

        # Exit status
        regression = (
            bool(diff["features"]["removed"]) or
            bool(diff["case_studies"]["removed"]) or
            bool(diff["findings"]["new"])
        )
        if regression:
            print("\n❌ REGRESSION detected vs previous snapshot.")
            sys.exit(1)
        print("\n✅ No regression vs previous snapshot.")

    if args.strict and snapshot["finding_count"]:
        sys.exit(1)


if __name__ == "__main__":
    main()
