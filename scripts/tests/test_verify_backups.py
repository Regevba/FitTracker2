"""FIT-206 / DI-Q3 — off-SSD backup verification.

Builds fake dated snapshot dirs with real CHECKSUMS.sha256 in a tmp tree, then:
  * clean tree verifies OK,
  * a corrupted (mutated) file is detected as `mismatch`,
  * a file listed in CHECKSUMS but deleted is detected as `missing`,
  * a MISSING off-SSD root is tolerated (present: false, not a failure),
  * only the N most-recent dirs are checked,
  * the failure sentinel flag is written on failure and cleared on success.
"""
from __future__ import annotations

import hashlib
import importlib.util
import json
import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPTS_DIR = REPO_ROOT / "scripts"
SCRIPT_PATH = SCRIPTS_DIR / "verify-backups.py"

sys.path.insert(0, str(SCRIPTS_DIR))
_spec = importlib.util.spec_from_file_location("verify_backups", SCRIPT_PATH)
_mod = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_mod)  # type: ignore[union-attr]


def _make_snapshot(root: Path, date: str, files: dict[str, str], with_checksums: bool = True) -> Path:
    """Create root/<date>/ with the given files + a valid CHECKSUMS.sha256."""
    snap = root / date
    snap.mkdir(parents=True, exist_ok=True)
    for name, content in files.items():
        (snap / name).write_text(content)
    if with_checksums:
        lines = []
        for name, content in files.items():
            h = hashlib.sha256(content.encode()).hexdigest()
            lines.append(f"{h}  ./{name}")
        (snap / "CHECKSUMS.sha256").write_text("\n".join(lines) + "\n")
    return snap


def test_clean_tree_passes(tmp_path):
    local = tmp_path / "daily"
    _make_snapshot(local, "2026-07-08", {"metrics.json": "{}", "a.txt": "hello"})
    result = _mod.verify_backups(local, tmp_path / "nonexistent-ssd", recent=7)
    assert result["ok"] is True
    assert result["total_failures"] == 0
    ssd_loc = next(l for l in result["locations"] if l["label"] == "ssd")
    assert ssd_loc["present"] is False  # missing SSD tolerated


def test_corrupted_file_detected(tmp_path):
    local = tmp_path / "daily"
    snap = _make_snapshot(local, "2026-07-08", {"a.txt": "hello", "b.txt": "world"})
    # bit-rot: mutate a.txt after checksums were written
    (snap / "a.txt").write_text("HELLO-corrupted")
    result = _mod.verify_backups(local, tmp_path / "ssd", recent=7)
    assert result["ok"] is False
    assert result["total_failures"] == 1
    local_loc = next(l for l in result["locations"] if l["label"] == "local")
    reasons = [f["reason"] for s in local_loc["snapshots"] for f in s["failures"]]
    assert reasons == ["mismatch"]


def test_missing_file_detected(tmp_path):
    local = tmp_path / "daily"
    snap = _make_snapshot(local, "2026-07-08", {"a.txt": "hello", "gone.txt": "bye"})
    (snap / "gone.txt").unlink()
    result = _mod.verify_backups(local, tmp_path / "ssd", recent=7)
    assert result["ok"] is False
    reasons = [f["reason"] for l in result["locations"] for s in l["snapshots"] for f in s["failures"]]
    assert "missing" in reasons


def test_no_checksums_dir_is_skipped_not_failed(tmp_path):
    local = tmp_path / "daily"
    _make_snapshot(local, "2026-07-08", {"a.txt": "hi"}, with_checksums=False)
    result = _mod.verify_backups(local, tmp_path / "ssd", recent=7)
    assert result["ok"] is True  # no checksums → skipped, not a failure
    local_loc = next(l for l in result["locations"] if l["label"] == "local")
    assert local_loc["snapshots"][0]["status"] == "no_checksums"
    assert local_loc["snapshots_checked"] == 0


def test_only_recent_n_checked(tmp_path):
    local = tmp_path / "daily"
    for d in ("2026-07-01", "2026-07-02", "2026-07-03", "2026-07-04"):
        _make_snapshot(local, d, {"a.txt": "x"})
    dirs = _mod.recent_snapshot_dirs(local, recent=2)
    assert [p.name for p in dirs] == ["2026-07-04", "2026-07-03"]  # newest first


def test_non_date_dirs_ignored(tmp_path):
    local = tmp_path / "daily"
    _make_snapshot(local, "2026-07-08", {"a.txt": "x"})
    (local / "post-regression-evidence-2026-07-08T1200Z").mkdir()  # sibling-style name, not a daily
    (local / "README.md").write_text("notes")
    dirs = _mod.recent_snapshot_dirs(local, recent=7)
    assert [p.name for p in dirs] == ["2026-07-08"]


def test_main_writes_flag_on_failure_and_clears_on_success(tmp_path, monkeypatch):
    local = tmp_path / "daily"
    snap = _make_snapshot(local, "2026-07-08", {"a.txt": "hello"})
    monkeypatch.setenv("BACKUP_VERIFY_LOCAL_ROOT", str(local))
    monkeypatch.setenv("BACKUP_VERIFY_SSD_ROOT", str(tmp_path / "ssd"))
    result_file = tmp_path / "result.json"
    failed_flag = tmp_path / "failed.flag"
    monkeypatch.setattr(_mod, "RESULT_FILE", result_file)
    monkeypatch.setattr(_mod, "FAILED_FLAG", failed_flag)
    monkeypatch.setattr(sys, "argv", ["verify-backups.py"])

    # 1. corrupt → failure → flag written, exit 1
    (snap / "a.txt").write_text("corrupted")
    assert _mod.main() == 1
    assert failed_flag.exists()
    assert json.loads(result_file.read_text())["ok"] is False

    # 2. repair → success → flag cleared, exit 0
    (snap / "a.txt").write_text("hello")
    assert _mod.main() == 0
    assert not failed_flag.exists()
    assert json.loads(result_file.read_text())["ok"] is True
