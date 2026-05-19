"""Profile loader for audit bundles.

A profile is a JSON file at scripts/audit/profiles/<name>.json that lists
glob patterns + optional state-snapshot feature names. Profiles can inherit
from a single parent via `inherits_from`. Inheritance is flat (no diamond
inheritance) and circular references are rejected.
"""
from __future__ import annotations
import json
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional


REPO_ROOT = Path(__file__).resolve().parent.parent.parent
DEFAULT_PROFILE_DIR = REPO_ROOT / "scripts" / "audit" / "profiles"


@dataclass
class Profile:
    name: str
    description: str
    inherits_from: Optional[str]
    globs: list[str] = field(default_factory=list)
    state_snapshot_features: list[str] = field(default_factory=list)


def load_profile(name: str, profile_dir: Path = DEFAULT_PROFILE_DIR, _seen: Optional[set] = None) -> Profile:
    """Load a profile, resolving inheritance.

    Raises FileNotFoundError if a parent profile is missing.
    Raises ValueError on circular inheritance.
    """
    if _seen is None:
        _seen = set()
    if name in _seen:
        raise ValueError(f"Circular inheritance detected involving profile '{name}' (chain: {_seen})")
    _seen.add(name)

    profile_path = profile_dir / f"{name}.json"
    if not profile_path.exists():
        raise FileNotFoundError(f"Profile not found: {profile_path}")

    raw = json.loads(profile_path.read_text())
    parent_name = raw.get("inherits_from")

    if parent_name:
        parent = load_profile(parent_name, profile_dir=profile_dir, _seen=_seen)
        globs = list(parent.globs)
        snap_features = list(parent.state_snapshot_features)
        globs.extend(raw.get("additional_globs", []))
        snap_features.extend(raw.get("additional_state_snapshot_features", []))
    else:
        globs = list(raw.get("globs", []))
        snap_features = list(raw.get("additional_state_snapshot_features", []))

    return Profile(
        name=raw["profile_name"],
        description=raw.get("description", ""),
        inherits_from=parent_name,
        globs=globs,
        state_snapshot_features=snap_features,
    )


def expand_globs(globs: list[str], root: Path = REPO_ROOT) -> list[Path]:
    """Expand glob patterns relative to root. Returns sorted, deduplicated absolute paths."""
    # Resolve root so that match.resolve() (which may traverse macOS /var → /private/var
    # symlinks) stays in the subpath of root for relative_to() ordering.
    resolved_root = root.resolve()
    seen: set[Path] = set()
    for pattern in globs:
        for match in resolved_root.glob(pattern):
            if match.is_file():
                seen.add(match.resolve())
    return sorted(seen, key=lambda p: str(p.relative_to(resolved_root)))
