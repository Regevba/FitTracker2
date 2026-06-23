"""Schema + taxonomy cross-reference validation for docs/product/funnel-definitions.json.

Shipped by the `funnel-analysis-dashboards` enhancement (Enhancement of
`analytics-observability`). The JSON is the machine-readable data contract for the
5 canonical funnels (defined prose-only in ga4-funnels-and-conversions-runbook.md).
This test is its guard: it keeps the defs internally consistent AND honest about
each step event's taxonomy status, so a future Looker/control-room/Data-API consumer
can trust the file.

Each step carries `taxonomy_status` ∈ {in_taxonomy, ga4_automatic, in_code_not_taxonomy}:
  - in_taxonomy        → the event MUST appear in analytics-taxonomy.csv (column 2)
  - ga4_automatic      → the event MUST be in the file's ga4_automatic_events allowlist
  - in_code_not_taxonomy → known taxonomy drift; the event MUST be ABSENT from the CSV
                           (else the "drift" label is stale and should be promoted)
"""
from __future__ import annotations

import csv
import json
from pathlib import Path

import pytest

SCRIPTS_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = SCRIPTS_DIR.parent
DEFS_PATH = REPO_ROOT / "docs" / "product" / "funnel-definitions.json"
TAXONOMY_PATH = REPO_ROOT / "docs" / "product" / "analytics-taxonomy.csv"

VALID_TAXONOMY_STATUS = {"in_taxonomy", "ga4_automatic", "in_code_not_taxonomy"}
VALID_EVALUABLE = {"partial", "event_level", "blocked", "deferred"}


@pytest.fixture(scope="module")
def defs() -> dict:
    return json.loads(DEFS_PATH.read_text())


@pytest.fixture(scope="module")
def taxonomy_events() -> set[str]:
    """Event names from column 2 ('Event Name') of analytics-taxonomy.csv.

    The file has a comment preamble (# lines) and then a real header row; we
    skip comment lines and pull column index 1 (0-based) of every data row.
    """
    events: set[str] = set()
    with TAXONOMY_PATH.open(newline="") as fh:
        for row in csv.reader(fh):
            if not row or row[0].lstrip().startswith("#"):
                continue
            if len(row) >= 2 and row[1] and row[1] != "Event Name":
                events.add(row[1].strip())
    return events


# ---- schema ----------------------------------------------------------------

def test_defs_file_exists_and_parses(defs):
    assert defs["schema_version"] == 1
    assert isinstance(defs["funnels"], list) and len(defs["funnels"]) == 5


def test_ga4_automatic_allowlist_present(defs):
    assert isinstance(defs.get("ga4_automatic_events"), list)
    assert "first_open" in defs["ga4_automatic_events"]


def test_funnel_ids_unique(defs):
    ids = [f["id"] for f in defs["funnels"]]
    assert len(ids) == len(set(ids)), f"duplicate funnel ids: {ids}"


def test_each_funnel_well_formed(defs):
    for f in defs["funnels"]:
        assert f["id"], "funnel missing id"
        assert f["name"], f"{f['id']} missing name"
        assert isinstance(f["steps"], list) and f["steps"], f"{f['id']} has no steps"
        assert f["evaluable_now"] in VALID_EVALUABLE, f"{f['id']} bad evaluable_now {f['evaluable_now']}"
        assert f.get("evaluable_reason"), f"{f['id']} missing evaluable_reason"
        assert isinstance(f.get("kill_criteria_links"), list), f"{f['id']} kill_criteria_links not a list"


def test_steps_ordered_and_have_one_conversion_target(defs):
    for f in defs["funnels"]:
        orders = [s["order"] for s in f["steps"]]
        assert orders == sorted(orders), f"{f['id']} steps not ordered: {orders}"
        assert orders == list(range(1, len(orders) + 1)), f"{f['id']} orders not 1..N: {orders}"
        conv = [s for s in f["steps"] if s.get("conversion_target")]
        assert len(conv) == 1, f"{f['id']} must have exactly one conversion_target step, got {len(conv)}"


def test_step_taxonomy_status_valid(defs):
    for f in defs["funnels"]:
        for s in f["steps"]:
            assert s.get("event"), f"{f['id']} step {s.get('order')} missing event"
            assert s.get("taxonomy_status") in VALID_TAXONOMY_STATUS, (
                f"{f['id']} step {s['order']} bad taxonomy_status {s.get('taxonomy_status')}"
            )


# ---- cross-reference vs live taxonomy --------------------------------------

def test_in_taxonomy_events_actually_in_csv(defs, taxonomy_events):
    missing = []
    for f in defs["funnels"]:
        for s in f["steps"]:
            if s["taxonomy_status"] == "in_taxonomy" and s["event"] not in taxonomy_events:
                missing.append((f["id"], s["order"], s["event"]))
    assert not missing, f"steps marked in_taxonomy but absent from CSV: {missing}"


def test_ga4_automatic_events_in_allowlist(defs):
    allow = set(defs["ga4_automatic_events"])
    bad = []
    for f in defs["funnels"]:
        for s in f["steps"]:
            if s["taxonomy_status"] == "ga4_automatic" and s["event"] not in allow:
                bad.append((f["id"], s["order"], s["event"]))
    assert not bad, f"steps marked ga4_automatic but not in allowlist: {bad}"


def test_drift_events_really_absent_from_csv(defs, taxonomy_events):
    """A step labelled in_code_not_taxonomy must NOT be in the CSV — else the
    drift was resolved and the label is stale (promote it to in_taxonomy)."""
    stale = []
    for f in defs["funnels"]:
        for s in f["steps"]:
            if s["taxonomy_status"] == "in_code_not_taxonomy" and s["event"] in taxonomy_events:
                stale.append((f["id"], s["order"], s["event"]))
    assert not stale, (
        f"steps labelled in_code_not_taxonomy are now IN the CSV — promote to in_taxonomy: {stale}"
    )


def test_summary_consistent_with_funnels(defs):
    ids = {f["id"] for f in defs["funnels"]}
    s = defs["summary"]
    assert s["funnels_total"] == len(defs["funnels"])
    covered = set(s["evaluable_now_event_level_or_partial"]) | set(s["blocked_or_deferred"])
    assert covered == ids, f"summary funnel partition {covered} != funnel ids {ids}"
