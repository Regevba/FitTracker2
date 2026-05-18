# Impartial Audit Prompt Substrate Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a reproducible, deterministic audit-bundle substrate (1 helper script + 5 profile JSONs + 2 operator prompts + Makefile + CI + doc-sync) so the 2026-05-22 External Audit #1 and the 7 follow-on planned audits run through a single contract instead of one-off hand assembly.

**Architecture:** Pure-stdlib Python `scripts/audit/build_bundle.py` assembles files matched by `scripts/audit/profiles/<name>.json` glob lists, applies deterministic regex redaction (`scripts/audit/redaction.py`), and emits a hash-stamped `bundle.md` + `manifest.json` + `redaction-log.json` into `docs/audits/runs/YYYY-MM-DD-<model>/`. Two operator-facing prompts (`docs/audits/prompts/01-extraction-prompt.md` for the bundle generator, `docs/audits/prompts/02-auditor-prompt.md` for the fresh-chat auditor) parameterize over profile name. Makefile target + 2 CI workflows guarantee prompts don't bit-rot.

**Tech Stack:** Python 3 (stdlib only — no new dependencies), GitHub Actions, Markdown.

**Spec:** [`docs/superpowers/specs/2026-05-18-impartial-audit-prompt-substrate-design.md`](../specs/2026-05-18-impartial-audit-prompt-substrate-design.md)

**Naming note vs spec:** spec mentions `build-bundle.py` and `redaction-rules.py` (dashes). Plan uses underscores (`build_bundle.py`, `redaction.py`, etc.) so modules are importable. CLI invocation stays equivalent: `python3 scripts/audit/build_bundle.py --profile=base`.

**Branch:** create `feat/audit-prompt-substrate` from `main`. Spec advisory `BRANCH_ISOLATION_VIOLATION` Mode B may fire because we touch `Makefile`, `.github/workflows/*`, `scripts/audit/*`, `CLAUDE.md` — that is expected (infra surface). Per CLAUDE.md the gate is advisory in v7.8 and does not block.

**Target ship:** 2026-05-21 (one day before Audit #1 on 2026-05-22).

---

## File Structure

```
docs/audits/
├── prompts/
│   ├── 01-extraction-prompt.md    [Task 11]
│   └── 02-auditor-prompt.md       [Task 12]
└── runs/
    └── .gitkeep                   [Task 1 — keeps dir tracked, contents gitignored]

scripts/audit/
├── __init__.py                    [Task 1]
├── redaction.py                   [Task 2 — pure regex module]
├── profile.py                     [Task 3 — profile JSON loader + glob expansion]
├── state_snapshot.py              [Task 4 — generated `_state-snapshot.json` content]
├── build_bundle.py                [Task 5 — CLI orchestrator]
├── check_prompts.py               [Task 13 — prompt self-check CLI]
├── profiles/
│   ├── base.json                  [Task 6]
│   ├── v7-9-promotion.json        [Task 7]
│   ├── v7-9-1-f16-plus-hadf.json  [Task 8]
│   ├── v8-0-gates-plus-hadf-closure.json  [Task 9]
│   └── freshness.json             [Task 10]
└── tests/
    ├── __init__.py                [Task 1]
    ├── test_redaction.py          [Task 2]
    ├── test_profile.py            [Task 3]
    ├── test_state_snapshot.py     [Task 4]
    ├── test_build_bundle.py       [Task 5]
    └── test_check_prompts.py      [Task 13]

.github/workflows/
├── audit-prompts-weekly.yml       [Task 15]
└── audit-bundle-on-tag.yml        [Task 16]

Modified:
├── Makefile                       [Task 14 — add 2 targets]
├── .gitignore                     [Task 1 — exclude docs/audits/runs/*/]
├── CLAUDE.md                      [Task 17]
├── docs/master-plan/infra-master-plan-2026-05-12.md   [Task 17]
├── docs/master-plan/2026-05-12-consolidated-review-linear-notion-prep.md   [Task 17]
└── docs/case-studies/meta-analysis/unclosable-gaps.md  [Task 17]

Created (doc-sync):
└── docs/case-studies/meta-analysis/external-audit-stream.md   [Task 17]
```

---

## Task 1: Scaffold + gitignore + scaffold tests directory

**Files:**
- Create: `scripts/audit/__init__.py`
- Create: `scripts/audit/tests/__init__.py`
- Create: `docs/audits/runs/.gitkeep`
- Modify: `.gitignore`

- [ ] **Step 1: Create branch and scaffold directories**

```bash
git checkout -b feat/audit-prompt-substrate
mkdir -p scripts/audit/tests scripts/audit/profiles docs/audits/prompts docs/audits/runs
```

- [ ] **Step 2: Create empty `__init__.py` files**

```bash
touch scripts/audit/__init__.py scripts/audit/tests/__init__.py
touch docs/audits/runs/.gitkeep
```

- [ ] **Step 3: Add gitignore rule for per-run outputs**

Add at the bottom of `.gitignore`:

```
# Audit bundles — per-run outputs are gitignored by default;
# trust/audits/YYYY-MM-DD-<model>/ holds the reports we commit.
docs/audits/runs/*/
!docs/audits/runs/.gitkeep
```

- [ ] **Step 4: Verify the gitignore rule**

```bash
mkdir -p docs/audits/runs/test-run
touch docs/audits/runs/test-run/bundle.md
git status --short docs/audits/runs/
# Expected: shows only docs/audits/runs/.gitkeep, NOT test-run/bundle.md
rm -rf docs/audits/runs/test-run
```

- [ ] **Step 5: Commit**

```bash
git add scripts/audit/__init__.py scripts/audit/tests/__init__.py docs/audits/runs/.gitkeep .gitignore
git commit -m "chore(audit): scaffold audit-prompt-substrate directories + gitignore"
```

---

## Task 2: Redaction rules module (TDD)

**Files:**
- Create: `scripts/audit/redaction.py`
- Create: `scripts/audit/tests/test_redaction.py`

- [ ] **Step 1: Write the failing tests first**

Create `scripts/audit/tests/test_redaction.py`:

```python
import re
import unittest
from scripts.audit.redaction import redact, REDACTION_RULES


class TestRedaction(unittest.TestCase):
    def test_email_is_redacted(self):
        text, counts = redact("Contact regvash21@gmail.com for details.")
        self.assertEqual(text, "Contact [REDACTED_EMAIL] for details.")
        self.assertEqual(counts.get("email"), 1)

    def test_service_account_redacted_before_general_email(self):
        text, counts = redact("SA: ga4-mcp-reader@fitme-490515.iam.gserviceaccount.com here")
        # Must be tagged as service_account, NOT email
        self.assertIn("[REDACTED_SERVICE_ACCOUNT]", text)
        self.assertNotIn("[REDACTED_EMAIL]", text)
        self.assertEqual(counts.get("service_account"), 1)
        self.assertNotIn("email", counts)

    def test_gcp_project_id_redacted(self):
        text, counts = redact("Project fitme-490515 is live.")
        self.assertEqual(text, "Project [REDACTED_GCP_PROJECT] is live.")
        self.assertEqual(counts.get("gcp_project"), 1)

    def test_ga4_property_id_redacted(self):
        text, counts = redact("GA4 property 531124395 connected.")
        self.assertIn("[REDACTED_GA4_PROPERTY]", text)
        self.assertEqual(counts.get("ga4_property"), 1)

    def test_ga4_property_does_not_match_random_9_digit(self):
        text, counts = redact("Commit 123456789 unrelated.")
        # Random 9-digit numbers should NOT be redacted (would catch PR numbers, SHAs)
        self.assertIn("123456789", text)
        self.assertNotIn("ga4_property", counts)

    def test_oauth_token_redacted(self):
        token = "ya29." + "A" * 80
        text, counts = redact(f"Auth header: {token} end")
        self.assertIn("[REDACTED_OAUTH_TOKEN]", text)
        self.assertNotIn(token, text)

    def test_ssd_path_replaced(self):
        text, _ = redact("File at /Volumes/DevSSD/FitTracker2/scripts/foo.py")
        self.assertEqual(text, "File at <repo>/scripts/foo.py")

    def test_home_path_replaced(self):
        text, _ = redact("Backup at /Users/regevbarak/Documents/backup")
        self.assertEqual(text, "Backup at <home>/Documents/backup")

    def test_sentry_dsn_redacted(self):
        dsn = "https://abc123def@o12345.ingest.sentry.io/67890"
        text, counts = redact(f"DSN: {dsn}")
        self.assertIn("[REDACTED_SENTRY_DSN]", text)
        self.assertEqual(counts.get("sentry_dsn"), 1)

    def test_pr_numbers_kept_intact(self):
        text, counts = redact("PR #380 merged; commit fea3cd4 referenced.")
        # PR numbers and commit SHAs must remain visible to the auditor
        self.assertIn("PR #380", text)
        self.assertIn("fea3cd4", text)

    def test_github_owner_kept_intact(self):
        text, _ = redact("Regevba/FitTracker2 is the repo.")
        self.assertIn("Regevba/FitTracker2", text)

    def test_no_redaction_on_clean_text(self):
        text, counts = redact("This is a perfectly clean sentence with no secrets.")
        self.assertEqual(text, "This is a perfectly clean sentence with no secrets.")
        self.assertEqual(counts, {})

    def test_multiple_redactions_counted(self):
        text, counts = redact("Email a@b.com and a@c.com")
        self.assertEqual(counts.get("email"), 2)
        self.assertEqual(text.count("[REDACTED_EMAIL]"), 2)

    def test_rules_list_is_ordered_specific_first(self):
        # Regression guard: oauth before service_account before email
        rule_names = [r[0] for r in REDACTION_RULES]
        self.assertLess(rule_names.index("oauth_token"), rule_names.index("service_account"))
        self.assertLess(rule_names.index("service_account"), rule_names.index("email"))


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd /Volumes/DevSSD/FitTracker2
python3 -m unittest scripts.audit.tests.test_redaction -v
```

Expected: `ModuleNotFoundError: No module named 'scripts.audit.redaction'` (module not written yet).

- [ ] **Step 3: Implement the module**

Create `scripts/audit/redaction.py`:

```python
"""Deterministic regex redaction for audit bundles.

Single source of truth for what gets stripped from files before they
leave the repo as an external-audit bundle. Standard depth per
docs/superpowers/specs/2026-05-18-impartial-audit-prompt-substrate-design.md §6.

Rule order matters: more specific patterns must run BEFORE general ones
so the tag in redaction-log.json identifies the correct rule.
"""
from __future__ import annotations
import re
from typing import Tuple, Dict

REDACTION_RULES: list[tuple[str, re.Pattern, str]] = [
    # OAuth tokens (most specific shape)
    ("oauth_token", re.compile(r"ya29\.[A-Za-z0-9_-]{60,}"), "[REDACTED_OAUTH_TOKEN]"),
    # Service account emails (specific subset of email shape)
    ("service_account", re.compile(r"[\w.+-]+@[\w.-]+\.iam\.gserviceaccount\.com"), "[REDACTED_SERVICE_ACCOUNT]"),
    # Sentry DSN (specific URL shape)
    ("sentry_dsn", re.compile(r"https://[a-f0-9]+@[a-z0-9.-]+\.ingest\.sentry\.io/\d+"), "[REDACTED_SENTRY_DSN]"),
    # Vercel automation bypass tokens
    ("vercel_bypass", re.compile(r"(?i)vercel_automation_bypass_secret=[A-Za-z0-9_-]+"), "vercel_automation_bypass_secret=[REDACTED]"),
    # General email (catches everything after the specific shapes above)
    ("email", re.compile(r"[\w.+-]+@[\w.-]+\.\w+"), "[REDACTED_EMAIL]"),
    # GCP project ID — specific literal (word-boundary so PR/SHA prefixes don't match)
    ("gcp_project", re.compile(r"\bfitme-490515\b"), "[REDACTED_GCP_PROJECT]"),
    # GA4 property ID — specific literal
    ("ga4_property", re.compile(r"\b531124395\b"), "[REDACTED_GA4_PROPERTY]"),
    # Absolute paths (longest first so the SSD path matches before any user-home pattern)
    ("ssd_path", re.compile(r"/Volumes/DevSSD/FitTracker2"), "<repo>"),
    ("home_path", re.compile(r"/Users/regevbarak"), "<home>"),
]


def redact(text: str) -> Tuple[str, Dict[str, int]]:
    """Apply all redaction rules in order.

    Returns (redacted_text, {rule_name: count}).
    A rule with zero matches is omitted from the count dict.
    """
    counts: Dict[str, int] = {}
    for name, pattern, replacement in REDACTION_RULES:
        text, n = pattern.subn(replacement, text)
        if n > 0:
            counts[name] = counts.get(name, 0) + n
    return text, counts
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
python3 -m unittest scripts.audit.tests.test_redaction -v
```

Expected: `OK` — all 13 tests pass.

- [ ] **Step 5: Commit**

```bash
git add scripts/audit/redaction.py scripts/audit/tests/test_redaction.py
git commit -m "feat(audit): redaction module with rule-order tests"
```

---

## Task 3: Profile loader module (TDD)

**Files:**
- Create: `scripts/audit/profile.py`
- Create: `scripts/audit/tests/test_profile.py`
- Create: `scripts/audit/profiles/base.json` (minimal fixture for the test; final content lands in Task 6)

- [ ] **Step 1: Write the failing tests**

Create `scripts/audit/tests/test_profile.py`:

```python
import json
import tempfile
import unittest
from pathlib import Path
from scripts.audit.profile import load_profile, expand_globs, Profile


class TestProfile(unittest.TestCase):
    def test_load_base_profile(self):
        p = load_profile("base")
        self.assertEqual(p.name, "base")
        self.assertIsNone(p.inherits_from)
        self.assertGreater(len(p.globs), 0)

    def test_inheritance_resolves(self):
        # Create temp profile that inherits from base
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp) / "base.json"
            base.write_text(json.dumps({
                "profile_name": "base",
                "description": "base",
                "inherits_from": None,
                "globs": ["docs/foo.md"],
                "additional_state_snapshot_features": []
            }))
            child = Path(tmp) / "child.json"
            child.write_text(json.dumps({
                "profile_name": "child",
                "description": "child",
                "inherits_from": "base",
                "additional_globs": ["docs/bar.md"],
                "additional_state_snapshot_features": ["feature-x"]
            }))
            p = load_profile("child", profile_dir=Path(tmp))
            self.assertIn("docs/foo.md", p.globs)
            self.assertIn("docs/bar.md", p.globs)
            self.assertIn("feature-x", p.state_snapshot_features)

    def test_circular_inheritance_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            a = Path(tmp) / "a.json"
            a.write_text(json.dumps({
                "profile_name": "a", "description": "", "inherits_from": "b",
                "additional_globs": [], "additional_state_snapshot_features": []
            }))
            b = Path(tmp) / "b.json"
            b.write_text(json.dumps({
                "profile_name": "b", "description": "", "inherits_from": "a",
                "additional_globs": [], "additional_state_snapshot_features": []
            }))
            with self.assertRaises(ValueError) as ctx:
                load_profile("a", profile_dir=Path(tmp))
            self.assertIn("circular", str(ctx.exception).lower())

    def test_unknown_parent_raises(self):
        with tempfile.TemporaryDirectory() as tmp:
            c = Path(tmp) / "c.json"
            c.write_text(json.dumps({
                "profile_name": "c", "description": "", "inherits_from": "missing",
                "additional_globs": [], "additional_state_snapshot_features": []
            }))
            with self.assertRaises(FileNotFoundError):
                load_profile("c", profile_dir=Path(tmp))

    def test_expand_globs_alphabetical(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "docs").mkdir()
            (root / "docs" / "b.md").write_text("b")
            (root / "docs" / "a.md").write_text("a")
            (root / "docs" / "c.md").write_text("c")
            result = expand_globs(["docs/*.md"], root=root)
            # Must be alphabetical for determinism
            self.assertEqual([p.name for p in result], ["a.md", "b.md", "c.md"])

    def test_expand_globs_deduplicates(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "docs").mkdir()
            (root / "docs" / "a.md").write_text("a")
            result = expand_globs(["docs/*.md", "docs/a.md"], root=root)
            self.assertEqual(len(result), 1)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Create the minimal `base.json` fixture (full content in Task 6)**

```json
{
  "profile_name": "base",
  "description": "Stub base profile — full content in Task 6",
  "inherits_from": null,
  "globs": [
    "docs/case-studies/**/*.md"
  ],
  "additional_state_snapshot_features": []
}
```

Save to `scripts/audit/profiles/base.json`.

- [ ] **Step 3: Run tests to verify they fail**

```bash
python3 -m unittest scripts.audit.tests.test_profile -v
```

Expected: `ModuleNotFoundError: No module named 'scripts.audit.profile'`.

- [ ] **Step 4: Implement the module**

Create `scripts/audit/profile.py`:

```python
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
    seen: set[Path] = set()
    for pattern in globs:
        for match in root.glob(pattern):
            if match.is_file():
                seen.add(match.resolve())
    return sorted(seen, key=lambda p: str(p.relative_to(root)))
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
python3 -m unittest scripts.audit.tests.test_profile -v
```

Expected: `OK` — all 6 tests pass.

- [ ] **Step 6: Commit**

```bash
git add scripts/audit/profile.py scripts/audit/tests/test_profile.py scripts/audit/profiles/base.json
git commit -m "feat(audit): profile loader with inheritance + glob expansion + stub base profile"
```

---

## Task 4: State snapshot generator (TDD)

**Files:**
- Create: `scripts/audit/state_snapshot.py`
- Create: `scripts/audit/tests/test_state_snapshot.py`

- [ ] **Step 1: Write the failing tests**

Create `scripts/audit/tests/test_state_snapshot.py`:

```python
import json
import tempfile
import unittest
from pathlib import Path
from scripts.audit.state_snapshot import build_state_snapshot, SNAPSHOT_FIELDS


class TestStateSnapshot(unittest.TestCase):
    def test_required_fields_constant(self):
        expected = {
            "current_phase", "framework_version", "success_metrics",
            "kill_criteria", "kill_criteria_resolution", "case_study_link"
        }
        self.assertEqual(set(SNAPSHOT_FIELDS), expected)

    def test_snapshot_extracts_fields(self):
        with tempfile.TemporaryDirectory() as tmp:
            features = Path(tmp) / ".claude" / "features"
            (features / "foo").mkdir(parents=True)
            (features / "foo" / "state.json").write_text(json.dumps({
                "current_phase": "complete",
                "framework_version": "v7.8.6",
                "success_metrics": ["wau"],
                "kill_criteria": ["wau<100"],
                "kill_criteria_resolution": "did not fire",
                "case_study_link": "docs/case-studies/foo.md",
                "tasks": [...]  # extra field that must be DROPPED
            }))
            snap = build_state_snapshot(features_root=features)
            self.assertIn("foo", snap)
            self.assertEqual(snap["foo"]["current_phase"], "complete")
            self.assertEqual(snap["foo"]["framework_version"], "v7.8.6")
            self.assertNotIn("tasks", snap["foo"])

    def test_missing_state_json_skipped(self):
        with tempfile.TemporaryDirectory() as tmp:
            features = Path(tmp) / ".claude" / "features"
            (features / "no-state").mkdir(parents=True)
            snap = build_state_snapshot(features_root=features)
            self.assertEqual(snap, {})

    def test_subset_filter(self):
        with tempfile.TemporaryDirectory() as tmp:
            features = Path(tmp) / ".claude" / "features"
            for name in ["a", "b", "c"]:
                (features / name).mkdir(parents=True)
                (features / name / "state.json").write_text(json.dumps({
                    "current_phase": "complete", "framework_version": "v7.8.6"
                }))
            snap = build_state_snapshot(features_root=features, only=["a", "c"])
            self.assertEqual(set(snap.keys()), {"a", "c"})

    def test_missing_fields_become_null(self):
        with tempfile.TemporaryDirectory() as tmp:
            features = Path(tmp) / ".claude" / "features"
            (features / "x").mkdir(parents=True)
            (features / "x" / "state.json").write_text(json.dumps({"current_phase": "complete"}))
            snap = build_state_snapshot(features_root=features)
            self.assertIsNone(snap["x"]["framework_version"])
            self.assertIsNone(snap["x"]["kill_criteria"])


if __name__ == "__main__":
    unittest.main()
```

Replace the `[...]` placeholder in the test with `[]` (empty list) — that placeholder isn't valid JSON.

- [ ] **Step 2: Run tests to verify they fail**

```bash
python3 -m unittest scripts.audit.tests.test_state_snapshot -v
```

Expected: `ModuleNotFoundError`.

- [ ] **Step 3: Implement the module**

Create `scripts/audit/state_snapshot.py`:

```python
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
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
python3 -m unittest scripts.audit.tests.test_state_snapshot -v
```

Expected: `OK` — all 5 tests pass.

- [ ] **Step 5: Commit**

```bash
git add scripts/audit/state_snapshot.py scripts/audit/tests/test_state_snapshot.py
git commit -m "feat(audit): state snapshot generator with field whitelist"
```

---

## Task 5: Bundle builder CLI (TDD)

**Files:**
- Create: `scripts/audit/build_bundle.py`
- Create: `scripts/audit/tests/test_build_bundle.py`

- [ ] **Step 1: Write the failing tests**

Create `scripts/audit/tests/test_build_bundle.py`:

```python
import hashlib
import json
import re
import shutil
import tempfile
import unittest
from pathlib import Path
from scripts.audit.build_bundle import build, BundleResult


class TestBundleBuilder(unittest.TestCase):
    def _setup_minimal_repo(self, tmp: Path) -> Path:
        """Create a minimal repo skeleton with one case study + one profile."""
        (tmp / "docs" / "case-studies").mkdir(parents=True)
        (tmp / "docs" / "case-studies" / "alpha.md").write_text(
            "# Alpha\nEmail: regvash21@gmail.com\nProject fitme-490515.\n"
        )
        (tmp / "scripts" / "audit" / "profiles").mkdir(parents=True)
        (tmp / "scripts" / "audit" / "profiles" / "base.json").write_text(json.dumps({
            "profile_name": "base",
            "description": "test",
            "inherits_from": None,
            "globs": ["docs/case-studies/*.md"],
            "additional_state_snapshot_features": []
        }))
        (tmp / "docs" / "audits" / "runs").mkdir(parents=True)
        return tmp

    def test_bundle_is_created_and_files_inlined(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self._setup_minimal_repo(Path(tmp))
            result = build("base", repo_root=root, run_label="2026-05-22-test")
            self.assertTrue(result.bundle_path.exists())
            content = result.bundle_path.read_text()
            self.assertIn("### FILE: docs/case-studies/alpha.md", content)

    def test_redaction_applied_to_bundle_content(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self._setup_minimal_repo(Path(tmp))
            result = build("base", repo_root=root, run_label="2026-05-22-test")
            content = result.bundle_path.read_text()
            self.assertNotIn("regvash21@gmail.com", content)
            self.assertNotIn("fitme-490515", content)
            self.assertIn("[REDACTED_EMAIL]", content)
            self.assertIn("[REDACTED_GCP_PROJECT]", content)

    def test_manifest_records_per_file_hashes(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self._setup_minimal_repo(Path(tmp))
            result = build("base", repo_root=root, run_label="2026-05-22-test")
            manifest = json.loads(result.manifest_path.read_text())
            self.assertIn("files", manifest)
            self.assertEqual(len(manifest["files"]), 1)
            entry = manifest["files"][0]
            self.assertEqual(entry["path"], "docs/case-studies/alpha.md")
            self.assertIn("sha256_pre_redaction", entry)
            self.assertIn("sha256_post_redaction", entry)
            self.assertIn("bytes", entry)
            self.assertIn("redactions_applied", entry)

    def test_redaction_log_records_counts_not_values(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self._setup_minimal_repo(Path(tmp))
            result = build("base", repo_root=root, run_label="2026-05-22-test")
            log = json.loads(result.redaction_log_path.read_text())
            self.assertIn("rule_counts", log)
            self.assertEqual(log["rule_counts"].get("email"), 1)
            self.assertEqual(log["rule_counts"].get("gcp_project"), 1)
            # Verify NO redacted values are stored
            log_str = json.dumps(log)
            self.assertNotIn("regvash21", log_str)
            self.assertNotIn("fitme-490515", log_str)

    def test_bundle_is_deterministic(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self._setup_minimal_repo(Path(tmp))
            r1 = build("base", repo_root=root, run_label="run-1", fixed_timestamp="2026-05-22T00:00:00Z")
            r2 = build("base", repo_root=root, run_label="run-2", fixed_timestamp="2026-05-22T00:00:00Z")
            # Bundle bodies must be identical given identical inputs + timestamp
            self.assertEqual(r1.bundle_sha256, r2.bundle_sha256)

    def test_bundle_header_contains_profile_and_hash(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self._setup_minimal_repo(Path(tmp))
            result = build("base", repo_root=root, run_label="2026-05-22-test")
            content = result.bundle_path.read_text()
            self.assertIn("# Profile: base", content)
            self.assertRegex(content, r"# Bundle SHA256: [a-f0-9]{64}")
            self.assertRegex(content, r"# build_bundle.py SHA256: [a-f0-9]{64}")

    def test_size_warning_above_threshold(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self._setup_minimal_repo(Path(tmp))
            # Create a huge file (~2MB → ~500K tokens)
            (root / "docs" / "case-studies" / "huge.md").write_text("x" * 2_000_000)
            result = build("base", repo_root=root, run_label="big-test")
            self.assertTrue(result.size_warning_emitted)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
python3 -m unittest scripts.audit.tests.test_build_bundle -v
```

Expected: `ModuleNotFoundError`.

- [ ] **Step 3: Implement the bundle builder**

Create `scripts/audit/build_bundle.py`:

```python
#!/usr/bin/env python3
"""Build a deterministic, redacted audit bundle from a profile.

Usage:
    python3 scripts/audit/build_bundle.py --profile=base
    python3 scripts/audit/build_bundle.py --profile=v7-9-promotion --run-label=2026-05-22-claude
"""
from __future__ import annotations
import argparse
import datetime as dt
import hashlib
import json
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

# Make scripts/audit importable when run as a script
SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR.parent.parent))

from scripts.audit.redaction import redact  # noqa: E402
from scripts.audit.profile import load_profile, expand_globs  # noqa: E402
from scripts.audit.state_snapshot import build_state_snapshot  # noqa: E402


REPO_ROOT = Path(__file__).resolve().parent.parent.parent
SIZE_WARN_BYTES = 2_000_000  # ~500K tokens
DEFAULT_RUNS_DIR = REPO_ROOT / "docs" / "audits" / "runs"


@dataclass
class BundleResult:
    bundle_path: Path
    manifest_path: Path
    redaction_log_path: Path
    bundle_sha256: str
    size_warning_emitted: bool


def _sha256(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def _self_sha256() -> str:
    return _sha256(Path(__file__).read_text())


def build(
    profile_name: str,
    repo_root: Path = REPO_ROOT,
    run_label: Optional[str] = None,
    fixed_timestamp: Optional[str] = None,
    runs_dir: Optional[Path] = None,
) -> BundleResult:
    """Build the bundle. Returns a BundleResult with paths + summary hash."""
    profile = load_profile(profile_name, profile_dir=repo_root / "scripts" / "audit" / "profiles")
    files = expand_globs(profile.globs, root=repo_root)

    run_label = run_label or dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%d-%H%M%S")
    timestamp = fixed_timestamp or dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    runs_dir = runs_dir or (repo_root / "docs" / "audits" / "runs")
    run_dir = runs_dir / run_label
    run_dir.mkdir(parents=True, exist_ok=True)

    manifest_entries: list[dict] = []
    bundle_parts: list[str] = []
    total_rule_counts: dict[str, int] = {}
    size_warning_emitted = False

    # Body assembly: files first (alphabetical via expand_globs), then state snapshot
    for f in files:
        rel = f.relative_to(repo_root).as_posix()
        original = f.read_text()
        pre_hash = _sha256(original)
        redacted, counts = redact(original)
        post_hash = _sha256(redacted)
        for k, v in counts.items():
            total_rule_counts[k] = total_rule_counts.get(k, 0) + v
        bundle_parts.append(f"### FILE: {rel}\n\n{redacted}\n")
        manifest_entries.append({
            "path": rel,
            "sha256_pre_redaction": pre_hash,
            "sha256_post_redaction": post_hash,
            "bytes": len(redacted.encode("utf-8")),
            "redactions_applied": counts,
        })

    # State snapshot
    if profile.state_snapshot_features or profile.name == "base":
        only = profile.state_snapshot_features or None
        snap = build_state_snapshot(
            features_root=repo_root / ".claude" / "features",
            only=only,
        )
        snap_text = json.dumps(snap, indent=2, sort_keys=True)
        snap_redacted, snap_counts = redact(snap_text)
        for k, v in snap_counts.items():
            total_rule_counts[k] = total_rule_counts.get(k, 0) + v
        bundle_parts.append(f"### FILE: _state-snapshot.json\n\n```json\n{snap_redacted}\n```\n")
        manifest_entries.append({
            "path": "_state-snapshot.json",
            "sha256_pre_redaction": _sha256(snap_text),
            "sha256_post_redaction": _sha256(snap_redacted),
            "bytes": len(snap_redacted.encode("utf-8")),
            "redactions_applied": snap_counts,
        })

    body = "\n---\n\n".join(bundle_parts)
    body_hash = _sha256(body)

    toc_lines = [f"- {e['path']}" for e in manifest_entries]
    header = (
        f"# FitTracker2 Impartial Audit Bundle\n"
        f"# Generated: {timestamp}\n"
        f"# Profile: {profile.name}\n"
        f"# Bundle SHA256: {body_hash}\n"
        f"# build_bundle.py SHA256: {_self_sha256()}\n"
        f"# File count: {len(manifest_entries)}\n"
        f"# Redaction count: {sum(total_rule_counts.values())}\n\n"
        f"## Table of Contents\n" + "\n".join(toc_lines) + "\n\n---\n\n"
    )

    bundle_text = header + body
    bundle_path = run_dir / "bundle.md"
    bundle_path.write_text(bundle_text)

    if len(bundle_text.encode("utf-8")) > SIZE_WARN_BYTES:
        size_warning_emitted = True
        print(
            f"WARNING: bundle is {len(bundle_text):,} bytes (>{SIZE_WARN_BYTES:,}). "
            "Consider --split-by-section in a future version.",
            file=sys.stderr,
        )

    manifest_path = run_dir / "manifest.json"
    manifest_path.write_text(json.dumps({
        "profile": profile.name,
        "generated": timestamp,
        "bundle_sha256": body_hash,
        "build_bundle_py_sha256": _self_sha256(),
        "file_count": len(manifest_entries),
        "files": manifest_entries,
    }, indent=2))

    redaction_log_path = run_dir / "redaction-log.json"
    redaction_log_path.write_text(json.dumps({
        "profile": profile.name,
        "generated": timestamp,
        "rule_counts": total_rule_counts,
        "total_redactions": sum(total_rule_counts.values()),
    }, indent=2))

    return BundleResult(
        bundle_path=bundle_path,
        manifest_path=manifest_path,
        redaction_log_path=redaction_log_path,
        bundle_sha256=body_hash,
        size_warning_emitted=size_warning_emitted,
    )


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--profile", required=True)
    p.add_argument("--run-label", default=None)
    args = p.parse_args()
    result = build(args.profile, run_label=args.run_label)
    print(f"Bundle written: {result.bundle_path}")
    print(f"Manifest:       {result.manifest_path}")
    print(f"Redaction log:  {result.redaction_log_path}")
    print(f"Bundle SHA256:  {result.bundle_sha256}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
python3 -m unittest scripts.audit.tests.test_build_bundle -v
```

Expected: `OK` — all 7 tests pass.

- [ ] **Step 5: Commit**

```bash
git add scripts/audit/build_bundle.py scripts/audit/tests/test_build_bundle.py
git commit -m "feat(audit): deterministic bundle builder with manifest + redaction log"
```

---

## Task 6: Write the canonical `base.json` profile

**Files:**
- Modify: `scripts/audit/profiles/base.json`

- [ ] **Step 1: Replace the Task 3 stub with canonical content**

```json
{
  "profile_name": "base",
  "description": "Foundation profile — case studies + measurement ledgers + prior audits. All other profiles inherit from this.",
  "inherits_from": null,
  "globs": [
    "docs/case-studies/**/*.md",
    ".claude/shared/measurement-adoption.json",
    ".claude/shared/measurement-adoption-history.json",
    ".claude/shared/documentation-debt.json",
    ".claude/shared/case-study-monitoring.json",
    ".claude/shared/case-study-t1-references.json",
    "trust/audits/**/*.md"
  ],
  "additional_state_snapshot_features": []
}
```

- [ ] **Step 2: Smoke-test by running the builder against the real repo**

```bash
python3 scripts/audit/build_bundle.py --profile=base --run-label=smoke-base
ls -lh docs/audits/runs/smoke-base/
```

Expected: `bundle.md`, `manifest.json`, `redaction-log.json` all present; `bundle.md` is > 100KB given the real corpus.

- [ ] **Step 3: Verify no operator email/GCP/GA4 IDs leaked into bundle**

```bash
grep -c "regvash21\|fitme-490515\|531124395\|/Volumes/DevSSD\|/Users/regevbarak" docs/audits/runs/smoke-base/bundle.md
```

Expected: `0`. If nonzero, audit `redaction.py` regex coverage.

- [ ] **Step 4: Clean up smoke run (it's gitignored anyway)**

```bash
rm -rf docs/audits/runs/smoke-base
```

- [ ] **Step 5: Commit**

```bash
git add scripts/audit/profiles/base.json
git commit -m "feat(audit): canonical base profile — case studies + measurement + prior audits"
```

---

## Task 7: Write `v7-9-promotion.json` profile (External Audit #1)

**Files:**
- Create: `scripts/audit/profiles/v7-9-promotion.json`

- [ ] **Step 1: Write the profile**

```json
{
  "profile_name": "v7-9-promotion",
  "description": "External Audit #1 (2026-05-22) — v7.9 promotion data + HADF Sub-exp 1 prereg",
  "inherits_from": "base",
  "additional_globs": [
    ".claude/shared/gate-coverage-weekly.jsonl",
    ".claude/shared/measurement-adoption-history.json",
    "docs/case-studies/meta-analysis/v7-9-measurement-window-2026-05-11.md",
    "docs/superpowers/specs/2026-05-11-hadf-phase2bis-replication-design.md",
    "docs/superpowers/specs/2026-05-02-framework-v7-8-and-v7-9-bridge-design.md"
  ],
  "additional_state_snapshot_features": [
    "hadf-phase2bis-replication",
    "framework-v7-9-promotion"
  ]
}
```

- [ ] **Step 2: Smoke-test**

```bash
python3 scripts/audit/build_bundle.py --profile=v7-9-promotion --run-label=smoke-v7-9
ls -lh docs/audits/runs/smoke-v7-9/
rm -rf docs/audits/runs/smoke-v7-9
```

Expected: bundle generated; manifest includes the 4 extra files.

- [ ] **Step 3: Commit**

```bash
git add scripts/audit/profiles/v7-9-promotion.json
git commit -m "feat(audit): v7-9-promotion profile for External Audit #1 (2026-05-22)"
```

---

## Task 8: Write `v7-9-1-f16-plus-hadf.json` profile (External Audit #2)

**Files:**
- Create: `scripts/audit/profiles/v7-9-1-f16-plus-hadf.json`

- [ ] **Step 1: Write the profile**

```json
{
  "profile_name": "v7-9-1-f16-plus-hadf",
  "description": "External Audit #2 (2026-06-12) — F16 try-repo fixture corpus + HADF Sub-exps 1-3 raw data integrity",
  "inherits_from": "v7-9-promotion",
  "additional_globs": [
    "docs/master-plan/v7-9-1-f16-try-repo-harness-prd-2026-05-13.md",
    "docs/case-studies/meta-analysis/*hadf*.md"
  ],
  "additional_state_snapshot_features": []
}
```

- [ ] **Step 2: Smoke-test + cleanup**

```bash
python3 scripts/audit/build_bundle.py --profile=v7-9-1-f16-plus-hadf --run-label=smoke-v7-9-1
rm -rf docs/audits/runs/smoke-v7-9-1
```

Expected: bundle generated.

- [ ] **Step 3: Commit**

```bash
git add scripts/audit/profiles/v7-9-1-f16-plus-hadf.json
git commit -m "feat(audit): v7-9-1-f16-plus-hadf profile for External Audit #2 (2026-06-12)"
```

---

## Task 9: Write `v8-0-gates-plus-hadf-closure.json` profile (External Audit #3)

**Files:**
- Create: `scripts/audit/profiles/v8-0-gates-plus-hadf-closure.json`

- [ ] **Step 1: Write the profile**

```json
{
  "profile_name": "v8-0-gates-plus-hadf-closure",
  "description": "External Audit #3 (2026-08-05) — v8.0 gate calibration honesty + HADF Block C synthesis + ORCHID v2",
  "inherits_from": "base",
  "additional_globs": [
    ".claude/shared/gate-coverage-weekly.jsonl",
    "docs/case-studies/meta-analysis/*hadf*.md",
    "docs/case-studies/meta-analysis/*orchid*.md",
    "docs/master-plan/v8-0-docket-ranking-2026-05-13.md"
  ],
  "additional_state_snapshot_features": []
}
```

- [ ] **Step 2: Smoke-test + cleanup**

```bash
python3 scripts/audit/build_bundle.py --profile=v8-0-gates-plus-hadf-closure --run-label=smoke-v8-0
rm -rf docs/audits/runs/smoke-v8-0
```

- [ ] **Step 3: Commit**

```bash
git add scripts/audit/profiles/v8-0-gates-plus-hadf-closure.json
git commit -m "feat(audit): v8-0-gates-plus-hadf-closure profile for External Audit #3 (2026-08-05)"
```

---

## Task 10: Write `freshness.json` profile (Data Freshness Audits #1-#4)

**Files:**
- Create: `scripts/audit/profiles/freshness.json`

- [ ] **Step 1: Write the profile**

Note: freshness audits are different — they validate "are the canonical names still aligned?" not "are the claims true?". So the profile pulls source files alongside the docs.

```json
{
  "profile_name": "freshness",
  "description": "Data Freshness Audits (T+90d / T+180d / T+270d / T+365d) — gate emission keys ↔ function names ↔ test names canonicality",
  "inherits_from": "base",
  "additional_globs": [
    "scripts/integrity-check.py",
    "scripts/check-state-schema.py",
    "scripts/validate-tier-tags.py",
    ".claude/integrity/README.md",
    ".claude/integrity/observed-patterns.md",
    ".claude/shared/gate-coverage-weekly.jsonl"
  ],
  "additional_state_snapshot_features": []
}
```

- [ ] **Step 2: Smoke-test + cleanup**

```bash
python3 scripts/audit/build_bundle.py --profile=freshness --run-label=smoke-freshness
rm -rf docs/audits/runs/smoke-freshness
```

- [ ] **Step 3: Commit**

```bash
git add scripts/audit/profiles/freshness.json
git commit -m "feat(audit): freshness profile for quarterly Data Freshness Audits (#1-#4)"
```

---

## Task 11: Write `01-extraction-prompt.md` (Product 1)

**Files:**
- Create: `docs/audits/prompts/01-extraction-prompt.md`

- [ ] **Step 1: Write the operator-facing extraction prompt**

```markdown
# Extraction Prompt — Impartial Audit Bundle Generator

> **Audience:** the operator running Claude Code (or equivalent) on `<repo>` immediately before an external audit.
> **Output:** a deterministic, redacted `bundle.md` + `manifest.json` + `redaction-log.json` in `docs/audits/runs/YYYY-MM-DD-<auditor-model>/`.
> **Reproducibility contract:** same inputs + same `build_bundle.py` SHA256 → identical `bundle.md` SHA256.

---

## How to run

1. Verify you are on a clean `main` (no uncommitted changes that should be in the bundle):

   ```bash
   git status --short
   git pull --ff-only
   ```

2. Pick the profile that matches the audit date (see table below).

3. Run the builder:

   ```bash
   make audit-bundle PROFILE=<profile-name>
   ```

   or equivalently:

   ```bash
   python3 scripts/audit/build_bundle.py --profile=<profile-name> --run-label=YYYY-MM-DD-<auditor-model>
   ```

4. Verify the output:

   ```bash
   ls -lh docs/audits/runs/<run-label>/
   # Expected: bundle.md, manifest.json, redaction-log.json
   head -10 docs/audits/runs/<run-label>/bundle.md
   # Expected: hash-stamped header with profile name + bundle SHA256
   ```

5. Spot-check redaction by grepping for known sensitive patterns:

   ```bash
   grep -c "regvash21\|fitme-490515\|531124395\|/Volumes/DevSSD\|/Users/regevbarak" docs/audits/runs/<run-label>/bundle.md
   # Expected: 0
   ```

6. Open `docs/audits/runs/<run-label>/bundle.md`, copy its full content, and paste it into a fresh chat **after** pasting `docs/audits/prompts/02-auditor-prompt.md`.

7. When the auditor returns its 3-phase report, save it to `trust/audits/<run-label>/report.md` and commit alongside `manifest.json` + `redaction-log.json`.

---

## Profile selection table

| Audit date | Audit label | Profile |
|---|---|---|
| 2026-05-22 | External Audit #1 | `v7-9-promotion` |
| 2026-06-12 | External Audit #2 | `v7-9-1-f16-plus-hadf` |
| 2026-08-05 | External Audit #3 | `v8-0-gates-plus-hadf-closure` |
| 2026-08-12 | Data Freshness Audit #1 | `freshness` |
| 2026-10-08 | External Audit #4 | TBD — defaults to `base` until scope decided |
| 2026-11-12 | Data Freshness Audit #2 | `freshness` |
| 2027-02-12 | Data Freshness Audit #3 | `freshness` |
| 2027-05-12 | Data Freshness Audit #4 | `freshness` |

---

## What the bundle contains

Each profile inherits from `base`:

- `docs/case-studies/**/*.md` (every case study + meta-analyses)
- `.claude/shared/measurement-adoption.json`
- `.claude/shared/measurement-adoption-history.json`
- `.claude/shared/documentation-debt.json`
- `.claude/shared/case-study-monitoring.json`
- `.claude/shared/case-study-t1-references.json`
- `trust/audits/**/*.md` (prior audits — gives the auditor precedent)
- Generated `_state-snapshot.json` (subset of every feature's state.json)

Profile-specific globs add HADF prereg, F16 fixtures, ORCHID synthesis, gate-coverage ledgers, or the integrity-check sources (for freshness profile).

---

## What gets redacted

Single source of truth: `scripts/audit/redaction.py`. Standard depth:

- Email addresses → `[REDACTED_EMAIL]`
- Service account emails → `[REDACTED_SERVICE_ACCOUNT]`
- GCP project IDs → `[REDACTED_GCP_PROJECT]`
- GA4 property IDs → `[REDACTED_GA4_PROPERTY]`
- OAuth tokens, Sentry DSNs, Vercel bypass tokens → `[REDACTED_*]`
- Absolute paths `/Volumes/DevSSD/FitTracker2` → `<repo>`, `/Users/regevbarak` → `<home>`

Kept intact (deliberately):

- GitHub usernames `Regevba` and repo names `Regevba/FitTracker2`, `Regevba/fitme-story` (public on GitHub anyway)
- PR numbers `#NNN`, commit SHAs, branch names
- The pseudonym "the operator"

---

## Failure modes

| Symptom | Cause | Fix |
|---|---|---|
| `python3 -m unittest scripts.audit.tests.test_redaction` fails | Local redaction regex drift | Run `make audit-prompts-self-check` |
| Bundle SHA differs across consecutive runs | Generation timestamp leaked into hashed body | Pass `--run-label` explicitly; the body excludes the timestamp |
| Bundle > 500KB warning | Profile too broad for chat context | Re-run with narrower profile, or split manually by section |
| `grep` finds a redacted-pattern leak | New PII shape introduced in the corpus | Add a rule to `scripts/audit/redaction.py` + test in `tests/test_redaction.py` |
| Profile JSON missing parent | New profile inherits from a deleted base | Restore parent profile or change `inherits_from` |

---

## Companion: the auditor prompt

Once the bundle is built, the operator pastes [`02-auditor-prompt.md`](./02-auditor-prompt.md) **first** into the fresh chat, then the bundle content. The auditor returns a 3-phase report (Inventory → Discrepancies → Corrections) per the schema defined there.
```

- [ ] **Step 2: Verify the prompt has no placeholders**

```bash
grep -E "TODO|TBD|FIXME|<placeholder>" docs/audits/prompts/01-extraction-prompt.md
```

Expected: only the deliberate `TBD` for Audit #4 scope (currently unknown, documented as such).

- [ ] **Step 3: Commit**

```bash
git add docs/audits/prompts/01-extraction-prompt.md
git commit -m "feat(audit): extraction prompt (Product 1) for operator-side bundle generation"
```

---

## Task 12: Write `02-auditor-prompt.md` (Product 2)

**Files:**
- Create: `docs/audits/prompts/02-auditor-prompt.md`

- [ ] **Step 1: Write the auditor-facing prompt**

```markdown
# Impartial Auditor Prompt

> **Audience:** an external LLM (Claude.ai, ChatGPT, Gemini, etc.) receiving an audit bundle in a fresh chat.
> **Source bundle:** generated by `scripts/audit/build_bundle.py` per [`01-extraction-prompt.md`](./01-extraction-prompt.md).
> **Output:** a 3-phase report — Inventory → Discrepancies → Corrections — written to a single markdown document.

---

## Your role

You are an impartial data auditor. You will receive a single concatenated bundle of files from an external project. Your job is to produce a three-phase audit report with strict separation of observation from interpretation. You are not a consultant, advisor, or collaborator. You do not infer intent. You do not assess "quality" qualitatively. You count, compare, and report deltas.

---

## Hard constraints

1. Every numeric claim in your report MUST cite a bundle location as `<path>:<line-range>` (e.g., `docs/case-studies/foo.md:42-44`). Uncited numbers are forbidden.
2. Phase 1 OUTPUT MUST be tables only. No prose paragraphs. No adjectives. No words like "impressive," "concerning," "robust."
3. Phase 2 discrepancies MUST follow the schema below. If a finding does not fit the schema, log it under `unstructured_observations[]` — do not paraphrase it into the schema.
4. When data is ambiguous, log `INSUFFICIENT_DATA` with the specific ambiguity. Do not guess. Do not "interpret in light of context."
5. Phase 3 corrections MUST be concrete (line-level edits, file deletions, ledger field additions). No corrections of the form "consider reviewing X" or "the team might want to."
6. You may not access external tools (web, code execution). The bundle is the only ground truth.
7. If the operator asks you to elaborate beyond the report or speculate, refuse and cite constraint §7 of this prompt.

---

## Phase 1 — INVENTORY (table-only)

Produce exactly this table. No prose surrounding it. Counts are integers. Source-path column lists the bundle path(s) where the count was derived.

| Metric | Count | Source paths |
|---|---|---|
| `case_studies_total` | | |
| `case_studies_with_yaml_frontmatter` | | |
| `case_studies_missing_required_field` (per field — 7 required fields: `date_written` or `date`, `dispatch_pattern`, `success_metrics` or `primary_metric`, `kill_criteria`, `framework_version`, `work_type`, `tier_tags_present`) | | |
| `quantitative_claims_total` (regex `\b\d+(\.\d+)?%?\b`, exclude dates / PR numbers / commit SHAs / file paths / version strings like `v7.8.6`) | | |
| `quantitative_claims_tagged_T1` | | |
| `quantitative_claims_tagged_T2` | | |
| `quantitative_claims_tagged_T3` | | |
| `quantitative_claims_untagged` | | |
| `T1_claims_with_ledger_reference` (cross-checked against `.claude/shared/case-study-t1-references.json` and `.claude/shared/measurement-adoption.json` in the bundle) | | |
| `T1_claims_without_ledger_reference` | | |
| `kill_criteria_declared_total` | | |
| `kill_criteria_with_resolution_field` | | |
| `kill_criteria_missing_resolution` | | |
| `framework_versions_referenced` (unique set, e.g. `{v7.5, v7.6, v7.7, v7.8, v7.8.1, ...}`) | | |
| `prior_audits_in_bundle` | | |

---

## Phase 2 — DISCREPANCY LOG

Each finding is one JSON object inside a fenced code block. Concatenate all findings into a single fenced JSON array.

Schema:

```json
[
  {
    "id": "D-001",
    "claim_location": "docs/case-studies/foo.md:42",
    "claim_value": "92min stress-test wall time",
    "claim_tier_tag": "T1",
    "evidence_location": ".claude/shared/case-study-t1-references.json:18",
    "evidence_value": "92",
    "delta_type": "match | numeric_mismatch | missing_evidence | tier_label_mismatch | orphan_citation | broken_pr_reference | date_inconsistency",
    "delta_magnitude_if_numeric": null
  }
]
```

`delta_type` values are exclusive:

- `match` — claim value equals evidence value. (Log only if the claim has a tier tag; matches without tier tags are tier_label_mismatch.)
- `numeric_mismatch` — both claim and evidence have numeric values, but they differ.
- `missing_evidence` — claim asserts a T1 number but no ledger reference exists.
- `tier_label_mismatch` — claim is labeled `T1` but evidence is `T2` or `T3` (or vice versa).
- `orphan_citation` — claim references a file/path that does not exist in the bundle.
- `broken_pr_reference` — claim cites `PR #N` but the PR is not referenced in `state.json::tasks[].pr_number` or the case study's `related_prs` field.
- `date_inconsistency` — claim references a date that contradicts the corresponding state.json `current_phase` / framework version timeline.

After the JSON array, include an `unstructured_observations` section for findings that genuinely do not fit any schema field:

```markdown
### unstructured_observations

- `O-001` — location: `docs/case-studies/bar.md:78-92` — observation: [exact textual quote] — why it does not fit Phase 2 schema: [one-line mechanical reason]
```

No `severity` field anywhere. You do not rank.

---

## Phase 3 — CORRECTIONS

Each correction is a concrete edit. Schema:

```json
[
  {
    "id": "C-001",
    "type": "edit | delete | add_ledger_entry | retract_claim",
    "target_location": "docs/case-studies/foo.md:42",
    "current_text": "92min wall time",
    "proposed_text": "92min wall time [T1]",
    "rationale": "Tier tag missing; numeric value matches ledger at .claude/shared/case-study-t1-references.json:18. Adding [T1] makes the existing match explicit."
  }
]
```

`type` values:

- `edit` — replace `current_text` with `proposed_text` at `target_location`.
- `delete` — remove `current_text` at `target_location`. `proposed_text` is `null`.
- `add_ledger_entry` — append a JSON object to `target_location` (a ledger file). `current_text` is the suggested object as a string.
- `retract_claim` — claim cannot be substantiated by any evidence in the bundle; suggest removing the claim sentence entirely or rewriting as a T2/T3 narrative.

The `rationale` field is the ONLY place interpretation is allowed, and it is limited to "what mechanical evidence in the bundle supports this correction." It is one sentence.

Do not prioritize corrections. Do not group them by severity. Do not categorize by impact. The operator decides which to apply.

---

## Refusal template

If asked to do anything outside this contract, return only:

> Refused per prompt constraint §7. Auditor scope is bounded to inventory, discrepancy logging, and mechanical corrections. The original bundle is the ground truth; the operator's project owns interpretation.

---

## What follows this prompt

The next message you receive will be the bundle content — a single markdown document beginning with `# FitTracker2 Impartial Audit Bundle` and ending after the last `### FILE:` block. Read it in full before producing any output. Then produce the three phases in order: Inventory, Discrepancies, Corrections.
```

- [ ] **Step 2: Verify the prompt has no placeholders**

```bash
grep -E "TODO|TBD|FIXME|<placeholder>" docs/audits/prompts/02-auditor-prompt.md
```

Expected: no matches (this prompt has none).

- [ ] **Step 3: Commit**

```bash
git add docs/audits/prompts/02-auditor-prompt.md
git commit -m "feat(audit): auditor prompt (Product 2) with 3-phase schema + refusal template"
```

---

## Task 13: Prompt self-check CLI (TDD)

**Files:**
- Create: `scripts/audit/check_prompts.py`
- Create: `scripts/audit/tests/test_check_prompts.py`

- [ ] **Step 1: Write the failing tests**

```python
import tempfile
import unittest
from pathlib import Path
from scripts.audit.check_prompts import check_prompts, CheckResult


class TestCheckPrompts(unittest.TestCase):
    def _setup_valid_prompts(self, tmp: Path) -> Path:
        prompts = tmp / "docs" / "audits" / "prompts"
        prompts.mkdir(parents=True)
        (prompts / "01-extraction-prompt.md").write_text(
            "# Extraction\n## How to run\n`make audit-bundle PROFILE=base`\n"
            "Profile selection table\n| 2026-05-22 | External Audit #1 | v7-9-promotion |\n"
        )
        (prompts / "02-auditor-prompt.md").write_text(
            "# Auditor\n## Hard constraints\n1. cite\n## Phase 1 — INVENTORY\n"
            "## Phase 2 — DISCREPANCY\n```json\n[{\"id\": \"D-001\"}]\n```\n"
            "## Phase 3 — CORRECTIONS\n## Refusal template\n"
        )
        return tmp

    def test_valid_prompts_pass(self):
        with tempfile.TemporaryDirectory() as tmp:
            self._setup_valid_prompts(Path(tmp))
            result = check_prompts(repo_root=Path(tmp))
            self.assertTrue(result.passed)
            self.assertEqual(result.failures, [])

    def test_placeholder_detected(self):
        with tempfile.TemporaryDirectory() as tmp:
            self._setup_valid_prompts(Path(tmp))
            (Path(tmp) / "docs" / "audits" / "prompts" / "02-auditor-prompt.md").write_text(
                "# Auditor\n## Hard constraints\nTODO: write this\n"
            )
            result = check_prompts(repo_root=Path(tmp))
            self.assertFalse(result.passed)
            self.assertTrue(any("TODO" in f for f in result.failures))

    def test_missing_required_section_detected(self):
        with tempfile.TemporaryDirectory() as tmp:
            self._setup_valid_prompts(Path(tmp))
            (Path(tmp) / "docs" / "audits" / "prompts" / "02-auditor-prompt.md").write_text(
                "# Auditor\n## Hard constraints\nstuff\n"  # missing Phase 1/2/3/Refusal
            )
            result = check_prompts(repo_root=Path(tmp))
            self.assertFalse(result.passed)
            failures_text = " ".join(result.failures)
            self.assertIn("Phase 1", failures_text)

    def test_missing_prompt_file_detected(self):
        with tempfile.TemporaryDirectory() as tmp:
            (Path(tmp) / "docs" / "audits" / "prompts").mkdir(parents=True)
            result = check_prompts(repo_root=Path(tmp))
            self.assertFalse(result.passed)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
python3 -m unittest scripts.audit.tests.test_check_prompts -v
```

Expected: `ModuleNotFoundError`.

- [ ] **Step 3: Implement the CLI**

Create `scripts/audit/check_prompts.py`:

```python
#!/usr/bin/env python3
"""Lint the two audit prompts for placeholders + required sections.

Usage:
    python3 scripts/audit/check_prompts.py
    (or: make audit-prompts-self-check)
"""
from __future__ import annotations
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent.parent

PLACEHOLDER_PATTERNS = [r"\bTODO\b", r"\bFIXME\b", r"<placeholder>"]
# Note: "TBD" appears legitimately in 01-extraction-prompt.md for Audit #4 scope.
# Suppress TBD detection there; flag it elsewhere.

EXTRACTION_REQUIRED_SECTIONS = ["How to run", "Profile selection table"]
AUDITOR_REQUIRED_SECTIONS = [
    "Hard constraints",
    "Phase 1",
    "Phase 2",
    "Phase 3",
    "Refusal template",
]


@dataclass
class CheckResult:
    passed: bool
    failures: list[str] = field(default_factory=list)


def _check_placeholders(content: str, path: str, allow_tbd: bool = False) -> list[str]:
    failures = []
    patterns = list(PLACEHOLDER_PATTERNS)
    if not allow_tbd:
        patterns.append(r"\bTBD\b")
    for pattern in patterns:
        if re.search(pattern, content):
            failures.append(f"{path}: contains forbidden token matching /{pattern}/")
    return failures


def _check_sections(content: str, required: list[str], path: str) -> list[str]:
    failures = []
    for section in required:
        if section not in content:
            failures.append(f"{path}: missing required section '{section}'")
    return failures


def check_prompts(repo_root: Path = REPO_ROOT) -> CheckResult:
    prompts_dir = repo_root / "docs" / "audits" / "prompts"
    extraction = prompts_dir / "01-extraction-prompt.md"
    auditor = prompts_dir / "02-auditor-prompt.md"

    failures: list[str] = []
    if not extraction.exists():
        failures.append(f"missing file: {extraction}")
    if not auditor.exists():
        failures.append(f"missing file: {auditor}")
    if failures:
        return CheckResult(passed=False, failures=failures)

    extraction_text = extraction.read_text()
    auditor_text = auditor.read_text()

    failures.extend(_check_placeholders(extraction_text, str(extraction), allow_tbd=True))
    failures.extend(_check_placeholders(auditor_text, str(auditor), allow_tbd=False))
    failures.extend(_check_sections(extraction_text, EXTRACTION_REQUIRED_SECTIONS, str(extraction)))
    failures.extend(_check_sections(auditor_text, AUDITOR_REQUIRED_SECTIONS, str(auditor)))

    return CheckResult(passed=not failures, failures=failures)


def main() -> int:
    result = check_prompts()
    if result.passed:
        print("OK — audit prompts pass self-check.")
        return 0
    print("FAIL — audit prompts have issues:")
    for f in result.failures:
        print(f"  - {f}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
python3 -m unittest scripts.audit.tests.test_check_prompts -v
```

Expected: `OK` — all 4 tests pass.

- [ ] **Step 5: Run the check against real prompts**

```bash
python3 scripts/audit/check_prompts.py
```

Expected: `OK — audit prompts pass self-check.`

- [ ] **Step 6: Commit**

```bash
git add scripts/audit/check_prompts.py scripts/audit/tests/test_check_prompts.py
git commit -m "feat(audit): prompt self-check CLI for placeholder + section validation"
```

---

## Task 14: Makefile targets

**Files:**
- Modify: `Makefile`

- [ ] **Step 1: Add the two targets to `Makefile`**

Append at the end of the file (do not insert mid-file — risk of breaking existing rules):

```make
# ─────────────────────────────────────────────────────────────
# Impartial Audit Substrate
# ─────────────────────────────────────────────────────────────

.PHONY: audit-bundle audit-prompts-self-check

audit-bundle:
	@if [ -z "$(PROFILE)" ]; then \
		echo "Usage: make audit-bundle PROFILE=<name>"; \
		echo "Available profiles: base v7-9-promotion v7-9-1-f16-plus-hadf v8-0-gates-plus-hadf-closure freshness"; \
		exit 1; \
	fi
	python3 scripts/audit/build_bundle.py --profile=$(PROFILE) $(if $(RUN_LABEL),--run-label=$(RUN_LABEL))

audit-prompts-self-check:
	python3 scripts/audit/check_prompts.py
```

- [ ] **Step 2: Smoke-test both targets**

```bash
make audit-prompts-self-check
# Expected: OK — audit prompts pass self-check.

make audit-bundle PROFILE=base RUN_LABEL=smoke-make
ls docs/audits/runs/smoke-make/
rm -rf docs/audits/runs/smoke-make
```

Expected: bundle, manifest, redaction-log all present.

- [ ] **Step 3: Verify error message on missing PROFILE**

```bash
make audit-bundle
# Expected: prints usage + lists profiles + exits 1
```

- [ ] **Step 4: Commit**

```bash
git add Makefile
git commit -m "feat(audit): Makefile targets audit-bundle + audit-prompts-self-check"
```

---

## Task 15: Weekly prompts-self-check CI workflow

**Files:**
- Create: `.github/workflows/audit-prompts-weekly.yml`

- [ ] **Step 1: Write the workflow**

```yaml
name: audit-prompts-weekly

on:
  schedule:
    - cron: '0 6 * * 1'  # Mondays 06:00 UTC (1h after framework-status-weekly)
  workflow_dispatch:
  pull_request:
    paths:
      - 'docs/audits/prompts/**'
      - 'scripts/audit/**'
      - '.github/workflows/audit-prompts-weekly.yml'

jobs:
  self-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.11'
      - name: Run prompt self-check
        run: make audit-prompts-self-check
      - name: Run audit module tests
        run: |
          python3 -m unittest scripts.audit.tests.test_redaction
          python3 -m unittest scripts.audit.tests.test_profile
          python3 -m unittest scripts.audit.tests.test_state_snapshot
          python3 -m unittest scripts.audit.tests.test_build_bundle
          python3 -m unittest scripts.audit.tests.test_check_prompts
      - name: Open issue on failure (scheduled only)
        if: ${{ failure() && github.event_name == 'schedule' }}
        uses: actions/github-script@v7
        with:
          script: |
            const title = `audit-prompts-weekly: self-check failed on ${new Date().toISOString().split('T')[0]}`;
            const body = `The weekly audit-prompts self-check failed.\n\nRun: ${context.serverUrl}/${context.repo.owner}/${context.repo.repo}/actions/runs/${context.runId}\n\nLikely causes: prompt edited with a placeholder / required section removed / redaction regex regression.\n\nFix: run \`make audit-prompts-self-check\` locally and address the listed failures.`;
            await github.rest.issues.create({
              owner: context.repo.owner,
              repo: context.repo.repo,
              title,
              body,
              labels: ['audit-substrate', 'priority-high'],
            });
```

- [ ] **Step 2: Validate YAML syntax**

```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/audit-prompts-weekly.yml'))"
```

Expected: no output (valid YAML).

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/audit-prompts-weekly.yml
git commit -m "ci(audit): weekly prompt self-check + module tests; opens issue on failure"
```

---

## Task 16: Tag-triggered bundle workflow

**Files:**
- Create: `.github/workflows/audit-bundle-on-tag.yml`

- [ ] **Step 1: Write the workflow**

```yaml
name: audit-bundle-on-tag

on:
  push:
    tags:
      - 'external-audit-*'

jobs:
  build-bundle:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: actions/setup-python@v5
        with:
          python-version: '3.11'
      - name: Infer profile from tag
        id: profile
        run: |
          TAG="${GITHUB_REF##*/}"
          case "$TAG" in
            external-audit-1-*|*-v7-9-promotion-*) echo "name=v7-9-promotion" >> "$GITHUB_OUTPUT" ;;
            external-audit-2-*|*-v7-9-1-*)         echo "name=v7-9-1-f16-plus-hadf" >> "$GITHUB_OUTPUT" ;;
            external-audit-3-*|*-v8-0-*)           echo "name=v8-0-gates-plus-hadf-closure" >> "$GITHUB_OUTPUT" ;;
            external-audit-freshness-*)            echo "name=freshness" >> "$GITHUB_OUTPUT" ;;
            *)                                     echo "name=base" >> "$GITHUB_OUTPUT" ;;
          esac
      - name: Build bundle
        run: |
          make audit-bundle PROFILE=${{ steps.profile.outputs.name }} RUN_LABEL=${GITHUB_REF##*/}
      - name: Upload bundle artifact
        uses: actions/upload-artifact@v4
        with:
          name: audit-bundle-${{ github.ref_name }}
          path: docs/audits/runs/${{ github.ref_name }}/
          retention-days: 90
```

- [ ] **Step 2: Validate YAML syntax**

```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/audit-bundle-on-tag.yml'))"
```

Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/audit-bundle-on-tag.yml
git commit -m "ci(audit): tag-triggered bundle builder; uploads 90d artifact for replay"
```

---

## Task 17: Cross-reference doc-sync

**Files:**
- Modify: `CLAUDE.md`
- Modify: `docs/master-plan/infra-master-plan-2026-05-12.md`
- Modify: `docs/master-plan/2026-05-12-consolidated-review-linear-notion-prep.md`
- Modify: `docs/case-studies/meta-analysis/unclosable-gaps.md`
- Create: `docs/case-studies/meta-analysis/external-audit-stream.md`

- [ ] **Step 1: Add CLAUDE.md pointer**

Find the "### Case studies" section in `CLAUDE.md` (`grep -n "### Case studies" CLAUDE.md`). Append immediately after that section's last bullet:

```markdown
- External audit substrate: [`docs/audits/prompts/`](docs/audits/prompts/) — two operator-facing prompts + `scripts/audit/build_bundle.py` deterministic bundle helper. Powers the External Audits (2026-05-22, 2026-06-12, 2026-08-05, 2026-10-08) + quarterly Data Freshness Audits (2026-08-12, 2026-11-12, 2027-02-12, 2027-05-12) per infra master plan §5. Spec: [`docs/superpowers/specs/2026-05-18-impartial-audit-prompt-substrate-design.md`](docs/superpowers/specs/2026-05-18-impartial-audit-prompt-substrate-design.md).
```

- [ ] **Step 2: Add infra master plan §3.8 + §5 annotations**

In `docs/master-plan/infra-master-plan-2026-05-12.md`, find the end of §3.7 (`grep -n "^## 3\." docs/master-plan/infra-master-plan-2026-05-12.md` then jump to the section after 3.7). Insert a new §3.8:

```markdown
### 3.8 External Audit Substrate

The 4 External Audits + 4 quarterly Data Freshness Audits booked in §5 run through a single substrate: `docs/audits/prompts/01-extraction-prompt.md` (operator-side) + `docs/audits/prompts/02-auditor-prompt.md` (fresh-chat auditor) + `scripts/audit/build_bundle.py` (deterministic, redacted bundle generator). Profile JSON files at `scripts/audit/profiles/*.json` parameterize the substrate per audit date — same prompts, different file set. Spec: [`docs/superpowers/specs/2026-05-18-impartial-audit-prompt-substrate-design.md`](../superpowers/specs/2026-05-18-impartial-audit-prompt-substrate-design.md).

This addresses unclosable-gap #5 (Tier 3.3 external replication — see §6.1).
```

In §5 (calendar), annotate each external audit row with `(profile: <name>)`. Example edit pattern:

```markdown
| **2026-05-22** | External Audit #1 (v7.9 promotion data + HADF Sub-exp 1 prereg, profile: `v7-9-promotion`) | §3.8 |
```

Apply the same `(profile: <name>)` annotation to the other 7 audit rows in §5.

- [ ] **Step 3: Annotate the unclosable-gaps file**

In `docs/case-studies/meta-analysis/unclosable-gaps.md`, find the gap #5 entry (Tier 3.3 external replication). Append at the end of that entry:

```markdown

**Operational handle (added 2026-05-18):** the impartial audit prompt substrate at `docs/audits/prompts/` + `scripts/audit/build_bundle.py` makes external replication a cheap, repeatable operator task. Does not close the gap (still requires an external operator running the prompts in a fresh chat), but reduces per-audit overhead from "hand-assemble bundle + hand-write prompt" to "run `make audit-bundle PROFILE=<name>` + paste". Spec: [`docs/superpowers/specs/2026-05-18-impartial-audit-prompt-substrate-design.md`](../../../docs/superpowers/specs/2026-05-18-impartial-audit-prompt-substrate-design.md).
```

- [ ] **Step 4: Create the external-audit-stream.md ledger**

```markdown
# External Audit Stream — Append-Only Ledger

> Per-audit summary log. One row appended after each External Audit + Data Freshness Audit completes. Source: [`docs/audits/prompts/`](../../audits/prompts/) substrate.

| Date | Audit label | Profile | Auditor model | Bundle SHA256 | Discrepancies count | Corrections proposed | Corrections accepted | Report path |
|---|---|---|---|---|---|---|---|---|
| _(seed row — first audit ships 2026-05-22)_ | — | — | — | — | — | — | — | — |

## Process

After each audit:
1. Append a row with the audit's metadata.
2. Save the auditor's full report to `trust/audits/YYYY-MM-DD-<model>/report.md`.
3. Save the corresponding `manifest.json` + `redaction-log.json` alongside the report.
4. The bundle.md itself is optional to commit — controlled by spec §12 OQ #1 decision.

## Cross-reference

- Substrate spec: [`docs/superpowers/specs/2026-05-18-impartial-audit-prompt-substrate-design.md`](../../superpowers/specs/2026-05-18-impartial-audit-prompt-substrate-design.md)
- Infra master plan calendar: [`docs/master-plan/infra-master-plan-2026-05-12.md`](../../master-plan/infra-master-plan-2026-05-12.md) §5
- Unclosable-gaps #5 (operational handle): [`docs/case-studies/meta-analysis/unclosable-gaps.md`](unclosable-gaps.md)
```

Save to `docs/case-studies/meta-analysis/external-audit-stream.md`.

- [ ] **Step 5: Run integrity check to verify cross-refs**

```bash
make integrity-check
```

Expected: 0 new findings (the doc-sync edits don't change `current_phase` or claim numbers in case studies).

- [ ] **Step 6: Commit**

```bash
git add CLAUDE.md docs/master-plan/infra-master-plan-2026-05-12.md docs/case-studies/meta-analysis/unclosable-gaps.md docs/case-studies/meta-analysis/external-audit-stream.md
git commit -m "docs(audit): cross-reference substrate from CLAUDE.md + infra plan + unclosable-gaps + new stream ledger"
```

---

## Task 18: End-to-end smoke test + open PR

**Files:** none new

- [ ] **Step 1: Run the full test suite**

```bash
python3 -m unittest discover scripts/audit/tests -v
```

Expected: all tests pass across all 5 modules.

- [ ] **Step 2: Run all 5 profiles end-to-end**

```bash
for profile in base v7-9-promotion v7-9-1-f16-plus-hadf v8-0-gates-plus-hadf-closure freshness; do
  make audit-bundle PROFILE=$profile RUN_LABEL=smoke-$profile
done
```

Expected: 5 runs complete cleanly. Spot-check each for redaction:

```bash
for profile in base v7-9-promotion v7-9-1-f16-plus-hadf v8-0-gates-plus-hadf-closure freshness; do
  echo "=== $profile ==="
  grep -c "regvash21\|fitme-490515\|531124395" docs/audits/runs/smoke-$profile/bundle.md
done
```

Expected: all zeros.

- [ ] **Step 3: Verify determinism — run `base` twice with the same fixed timestamp**

```bash
python3 -c "from scripts.audit.build_bundle import build; print(build('base', run_label='det-1', fixed_timestamp='2026-05-18T00:00:00Z').bundle_sha256)"
python3 -c "from scripts.audit.build_bundle import build; print(build('base', run_label='det-2', fixed_timestamp='2026-05-18T00:00:00Z').bundle_sha256)"
```

Expected: both prints output the same 64-char hex string.

- [ ] **Step 4: Clean up smoke runs**

```bash
rm -rf docs/audits/runs/smoke-* docs/audits/runs/det-*
```

- [ ] **Step 5: Run full repo integrity check**

```bash
make integrity-check
```

Expected: 0 new findings introduced by this branch.

- [ ] **Step 6: Push branch and open PR**

```bash
git push -u origin feat/audit-prompt-substrate
gh pr create --title "feat(audit): impartial audit prompt substrate for External Audits #1-#4 + 4 Data Freshness Audits" --body "$(cat <<'EOF'
## Summary

Ships the reproducible audit-bundle substrate that powers the 8 audits booked in infra master plan §5 (External Audits 2026-05-22, 06-12, 08-05, 10-08; Data Freshness Audits 2026-08-12, 11-12, 2027-02-12, 05-12).

**Two operator-facing prompts:**
- `docs/audits/prompts/01-extraction-prompt.md` — instructs the operator (in Claude Code) to run `make audit-bundle PROFILE=<name>` to produce a redacted, hash-stamped bundle
- `docs/audits/prompts/02-auditor-prompt.md` — pasted into a fresh-chat external LLM ahead of the bundle; constrains it to a 3-phase output (Inventory → Discrepancies → Corrections)

**One deterministic backbone:**
- `scripts/audit/build_bundle.py` — pure-stdlib Python; same inputs + same script SHA256 → identical bundle SHA256

**Five profile JSONs** parameterize the substrate per audit date (base, v7-9-promotion, v7-9-1-f16-plus-hadf, v8-0-gates-plus-hadf-closure, freshness).

**CI:** weekly self-check workflow + tag-triggered bundle workflow.

**Doc-sync:** CLAUDE.md, infra master plan §3.8 + §5, unclosable-gaps #5 operational handle, new external-audit-stream.md ledger.

Spec: `docs/superpowers/specs/2026-05-18-impartial-audit-prompt-substrate-design.md`
Plan: `docs/superpowers/plans/2026-05-18-impartial-audit-prompt-substrate.md`

## Test plan
- [x] All 5 modules' unit tests pass (`python3 -m unittest discover scripts/audit/tests`)
- [x] All 5 profiles produce valid bundles via `make audit-bundle PROFILE=<name>` smoke test
- [x] Determinism check: same inputs + fixed timestamp → identical bundle SHA256
- [x] Redaction check: `grep` for known PII patterns returns 0 across all 5 profile bundles
- [x] `make audit-prompts-self-check` passes
- [x] `make integrity-check` shows 0 new findings
- [ ] CI weekly workflow runs green on first scheduled fire (Monday 06:00 UTC after merge)
- [ ] 2026-05-22 External Audit #1 runs end-to-end through the substrate without operator-side hand-editing (primary success metric per spec §13)

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Expected: PR URL printed; PR description matches the template.

---

## Self-Review (write-time)

Spec coverage check:
- §1 Problem → addressed: every task lands a piece of the substrate
- §2 Goals → reproducibility (Task 5 determinism test), mechanical output (Task 12 schema), deterministic redaction (Task 2), scope profile (Tasks 6-10)
- §3 Audit calendar → 5 profiles cover all 8 audits (Tasks 6-10)
- §4 Architecture → file layout matches (3-layer: prompts + helper + per-run output)
- §5 Scope decisions → reflected in module behavior + profile content
- §6 Extraction prompt contract → Task 11 writes it
- §7 Auditor prompt contract → Task 12 writes it (3-phase schema explicit)
- §8 Profile system → Task 3 implements + Tasks 6-10 ship the 5 profiles
- §9 Lifecycle integration → Task 14 (Makefile) + Tasks 15-16 (CI) + Task 17 (state.json field is in spec only; deferred to a follow-up plan since it's advisory)
- §10 Post-audit flow → Task 17 creates the stream ledger
- §11 Cross-references → Task 17
- §13 Success criteria → embedded in Task 18 test plan

Placeholder scan:
- Task 4 test code contains a literal `[...]` that I called out as needing replacement to `[]` — the engineer must apply this fix. Flagged inline.
- Task 11 deliberately preserves `TBD` for Audit #4 scope (documented in spec OQ); check_prompts.py allows TBD in the extraction prompt only.
- No other placeholders.

Type consistency:
- `BundleResult` dataclass fields match across Task 5 implementation + test + Task 18 smoke test ✓
- `Profile` dataclass fields match across Task 3 implementation + test ✓
- `CheckResult` dataclass fields match across Task 13 implementation + test ✓
- Function signatures consistent: `redact(text) -> (str, dict)`, `load_profile(name)`, `expand_globs(globs, root)`, `build_state_snapshot(features_root, only)`, `build(profile_name, repo_root, run_label, fixed_timestamp, runs_dir)`, `check_prompts(repo_root)` ✓

One scope deferral noted: spec §9 mentions `external_audit_schedule` as an optional state.json field. This plan does NOT add a schema validator for it because it's advisory in v0. If you want the field validation, it's a one-task follow-up.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-05-18-impartial-audit-prompt-substrate.md`. Two execution options:

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration. Best for this plan because each task is well-bounded with explicit TDD steps, and the redaction module + bundle builder benefit from independent code-review checkpoints.

**2. Inline Execution** — Execute tasks in this session using `executing-plans`, batch execution with checkpoints. Faster wall-clock; less protected from drift across tasks.

Which approach?
