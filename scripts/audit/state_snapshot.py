"""Generate _state-snapshot.json — a subset view of every feature's state.json.

Included in audit bundles so the auditor can cross-check case study claims
against framework state without us shipping the full state.json corpus.
Field whitelist per spec §6.
"""
from __future__ import annotations
import json
from pathlib import Path
from typing import Optional


REPO_ROOT = Path(__file__).resolve().parent.parent.parent

SNAPSHOT_FIELDS = [
    "current_phase",
    "framework_version",
    "success_metrics",
    "kill_criteria",
    "kill_criteria_resolution",
    "case_study_link",
]


def build_state_snapshot(
    features_root: Path = REPO_ROOT / ".claude" / "features",
    only: Optional[list[str]] = None,
) -> dict[str, dict]:
    """Read every state.json under features_root; return a {feature: subset_dict} mapping.

    If `only` is given, restrict to feature names in that list.
    Features without state.json are skipped silently.
    Fields missing from a state.json are set to None.
    """
    snapshot: dict[str, dict] = {}
    if not features_root.exists():
        return snapshot
    for feature_dir in sorted(features_root.iterdir()):
        if not feature_dir.is_dir():
            continue
        if only is not None and feature_dir.name not in only:
            continue
        state_path = feature_dir / "state.json"
        if not state_path.exists():
            continue
        try:
            data = json.loads(state_path.read_text())
        except json.JSONDecodeError:
            continue
        snapshot[feature_dir.name] = {field: data.get(field) for field in SNAPSHOT_FIELDS}
    return snapshot
