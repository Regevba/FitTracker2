"""Unit tests for scripts/tracking-drift-check.py.

Kill-criterion coverage: the gate must catch open-but-shipped drift (true
positives) while NOT firing on legitimately-open rows (false positives) —
struck-through rows, Done-section rows, future-work rows, and open child
enhancements whose complete PARENT they merely name.
"""
import importlib.util
from pathlib import Path

_SPEC = importlib.util.spec_from_file_location(
    "tracking_drift_check",
    Path(__file__).resolve().parent.parent / "tracking-drift-check.py",
)
tdc = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(tdc)

SLUGS = {
    "readiness-aware-training-alert": ["readiness", "aware", "training", "alert"],
    "ucc-passkey-auth": ["passkey", "auth"],
    "f16-try-repo-harness": ["repo", "harness"],
    "push-notifications": ["push", "notifications"],
    "smart-reminders": ["smart", "reminders"],
}


def _scan(tmp_path, text):
    f = tmp_path / "backlog.md"
    f.write_text(text)
    # scan_file derives a relative path from REPO_ROOT; point it at the file.
    orig = tdc.REPO_ROOT
    tdc.REPO_ROOT = tmp_path
    try:
        return tdc.scan_file(f, SLUGS)
    finally:
        tdc.REPO_ROOT = orig


def test_self_contradiction_open_checkbox_with_ship_marker_in_title(tmp_path):
    out = _scan(tmp_path, "- [ ] **F99 — Thing — SHIPPED 2026-06-04** body\n")
    assert len(out) == 1
    assert out[0]["signal"] == "self_contradiction"


def test_ship_marker_outside_title_is_not_flagged(tmp_path):
    # "CLOSED" references a different cross-linked item, not this row's status.
    out = _scan(tmp_path, "- [ ] **R15 — Playwright specs** was CLOSED via #137\n")
    assert out == []


def test_state_cross_ref_rice_row_for_complete_feature(tmp_path):
    out = _scan(
        tmp_path,
        "| 13.0 | **C2 — Readiness-Aware Training Alert** (parent: smart-reminders) | x |\n",
    )
    assert len(out) == 1
    assert out[0]["signal"] == "state_complete_cross_ref"
    assert out[0]["feature"] == "readiness-aware-training-alert"


def test_state_cross_ref_open_checkbox_for_complete_feature(tmp_path):
    out = _scan(tmp_path, "- [ ] **F16 — pre-commit try-repo harness** added\n")
    assert len(out) == 1
    assert out[0]["feature"] == "f16-try-repo-harness"


def test_struck_through_row_skipped(tmp_path):
    out = _scan(tmp_path, "| ~~13.0~~ | ~~**C2 — Readiness-Aware Training Alert**~~ |\n")
    assert out == []


def test_done_section_rows_skipped(tmp_path):
    text = (
        "## Done (Shipped)\n"
        "| 100 | **F16 — pre-commit try-repo harness** | shipped |\n"
        "## Planned\n"
    )
    assert _scan(tmp_path, text) == []


def test_future_work_phrase_suppresses(tmp_path):
    out = _scan(
        tmp_path,
        "- [ ] **F16 — try-repo harness** deferred to v8.x next pass\n",
    )
    assert out == []


def test_integration_counterparty_not_flagged(tmp_path):
    # Names complete `push-notifications` but the deliverable is the integration.
    out = _scan(
        tmp_path,
        "- [ ] **Smart Reminders ↔ Push Notifications v2 deep-link integration** body\n",
    )
    assert out == []


def test_parent_in_parenthetical_does_not_flag_open_child(tmp_path):
    # Title core (parens stripped) names no complete feature; parent is in parens.
    out = _scan(
        tmp_path,
        "- [ ] **New consumer wiring** (Enhancement; parent: smart-reminders) body\n",
    )
    assert out == []


def test_plain_open_row_no_evidence_not_flagged(tmp_path):
    out = _scan(tmp_path, "- [ ] **Rep max calculator (1RM estimation UI)**\n")
    assert out == []
