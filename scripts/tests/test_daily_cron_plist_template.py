"""Guard the daily-checkpoint launchd template against the 2026-07-14 regression.

That day the 06:00 cron recorded a +512 phantom integrity regression (441
BROKEN_PR_CITATION + 71 PR_NUMBER_UNRESOLVED) because the plist did not signal
cron context — launchd doesn't reliably export LAUNCHD_LABEL, so the empty-PR-cache
suppression (F-LAUNCHD-DRIFT-EXTENSION) never engaged. The fix sets CRON_CONTEXT=1
in the plist. It had a second bug too: a stale /Volumes/DevSSD source path.
"""
import plistlib
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent
TEMPLATE = REPO / "infrastructure" / "launchd" / "com.fittracker.daily-integrity-checkpoint.plist.template"


def _load():
    return plistlib.loads(TEMPLATE.read_bytes())


def test_template_is_valid_plist():
    d = _load()
    assert d["Label"] == "com.fittracker.daily-integrity-checkpoint"


def test_cron_context_is_set():
    # The reliable cron-context signal — without it the phantom-finding
    # suppression silently no-ops on the 06:00 launchd fire.
    assert _load()["EnvironmentVariables"].get("CRON_CONTEXT") == "1"


def test_no_stale_ssd_source_path():
    d = _load()
    joined = " ".join(d["ProgramArguments"]) + " " + d["WorkingDirectory"]
    assert "/Volumes/DevSSD" not in joined, "stale SSD path — source lives on internal storage"
    assert "/Developer/FitMe/FitTracker2" in d["WorkingDirectory"]
    assert d["ProgramArguments"][1].endswith("scripts/daily-integrity-checkpoint.py")
