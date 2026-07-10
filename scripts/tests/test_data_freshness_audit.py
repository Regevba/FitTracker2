"""Tests for N6 Data Freshness Audit (scripts/data-freshness-audit.py, §3.5.3).

Every assertion (A1–A4) has a deliberate-drift test that PROVES it fires — an
audit that always passes is worthless (the F16 regression-proof lesson). A
synthetic repo tree is built per-test with hand-drifted telemetry so the audit
runs against known-bad state, never the live repo.
"""
import datetime as dt
import importlib.util
import json
from pathlib import Path

_SPEC = importlib.util.spec_from_file_location(
    "data_freshness_audit",
    Path(__file__).resolve().parent.parent / "data-freshness-audit.py",
)
dfa = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(dfa)

NOW = dt.datetime(2026, 8, 12, tzinfo=dt.timezone.utc)  # first-run date, deterministic


def _iso(days_ago):
    return (NOW - dt.timedelta(days=days_ago)).strftime("%Y-%m-%dT%H:%M:%S+00:00")


def _build_repo(tmp_path, catalog: dict, f17: dict, test_files: dict | None = None):
    """Materialize a synthetic repo tree the audit can read."""
    shared = tmp_path / ".claude" / "shared"
    shared.mkdir(parents=True)
    (shared / "gate-catalog.json").write_text(json.dumps({"gates": catalog}))
    (shared / "gate-last-fired.json").write_text(json.dumps({"gates": f17}))
    (tmp_path / ".claude" / "logs").mkdir(parents=True)
    (tmp_path / ".claude" / "logs" / "gate-coverage.jsonl").write_text("")
    for rel, body in (test_files or {}).items():
        p = tmp_path / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(body)
    return tmp_path


def _healthy_gate(name, fired_days_ago=1, checked_days_ago=1, first_seen_days_ago=100,
                  firings=100, candidates=100):
    return {
        "last_fired_at": _iso(fired_days_ago),
        "last_checked_at": _iso(checked_days_ago),
        "first_seen_at": _iso(first_seen_days_ago),
        "total_firings": firings,
        "total_skips": 0,
        "total_candidates": candidates,
        "last_failed_at": None,
        "total_failure_snapshots": 0,
        "last_failure_severity": None,
    }


def _catalog_entry(name, test_rel="scripts/tests/test_x.py"):
    return {"stage": "write-time", "source": "scripts/check-state-schema.py",
            "enforcement": "enforced", "description": "x", "tier": "unit",
            "fixture_path": None, "test_files": [{"file": test_rel, "layer": "unit"}]}


def _codes(result):
    return {f["code"] for f in result["findings"]}


def _by_code(result, code):
    return [f for f in result["findings"] if f["code"] == code]


# ---- clean baseline -------------------------------------------------------

def test_clean_repo_zero_findings(tmp_path):
    catalog = {"GATE_A": _catalog_entry("GATE_A")}
    f17 = {"GATE_A": _healthy_gate("GATE_A")}
    repo = _build_repo(tmp_path, catalog, f17,
                       {"scripts/tests/test_x.py": "assert 'GATE_A' in code"})
    result = dfa.audit(NOW, repo_root=repo)
    assert result["summary"]["total"] == 0, result["findings"]


# ---- A1: orphan emission key ---------------------------------------------

def test_a1_orphan_emission_key_fails(tmp_path):
    # F17 emits a gate the catalog doesn't know — the rename-drift class.
    catalog = {"GATE_A": _catalog_entry("GATE_A")}
    f17 = {"GATE_A": _healthy_gate("GATE_A"),
           "GATE_RENAMED_OLD": _healthy_gate("GATE_RENAMED_OLD")}
    repo = _build_repo(tmp_path, catalog, f17,
                       {"scripts/tests/test_x.py": "GATE_A"})
    result = dfa.audit(NOW, repo_root=repo)
    orphans = _by_code(result, "A1_ORPHAN_EMISSION_KEY")
    assert len(orphans) == 1
    assert orphans[0]["gate"] == "GATE_RENAMED_OLD"
    assert orphans[0]["severity"] == dfa.SEV_FAIL


# ---- A2: stale candidacy --------------------------------------------------

def test_a2_stale_candidacy_nonevent_fails(tmp_path):
    catalog = {"GATE_A": _catalog_entry("GATE_A")}
    f17 = {"GATE_A": _healthy_gate("GATE_A", checked_days_ago=45)}  # > 30d window
    repo = _build_repo(tmp_path, catalog, f17, {"scripts/tests/test_x.py": "GATE_A"})
    result = dfa.audit(NOW, repo_root=repo)
    stale = _by_code(result, "A2_STALE_CANDIDACY")
    assert len(stale) == 1 and stale[0]["severity"] == dfa.SEV_FAIL


def test_a2_stale_candidacy_event_gated_is_advisory(tmp_path):
    # GATE_EVENT is declared event-gated via the injectable set — a synthetic name,
    # so no real gate-name string lands in this test file (keeps gate-catalog honest).
    catalog = {"GATE_EVENT": _catalog_entry("GATE_EVENT")}
    f17 = {"GATE_EVENT": _healthy_gate("GATE_EVENT", checked_days_ago=45)}
    repo = _build_repo(tmp_path, catalog, f17, {"scripts/tests/test_x.py": "GATE_EVENT"})
    result = dfa.audit(NOW, repo_root=repo, event_gated={"GATE_EVENT"})
    stale = _by_code(result, "A2_STALE_CANDIDACY")
    assert len(stale) == 1 and stale[0]["severity"] == dfa.SEV_ADVISORY


def test_a2_within_window_passes(tmp_path):
    catalog = {"GATE_A": _catalog_entry("GATE_A")}
    f17 = {"GATE_A": _healthy_gate("GATE_A", checked_days_ago=29)}
    repo = _build_repo(tmp_path, catalog, f17, {"scripts/tests/test_x.py": "GATE_A"})
    result = dfa.audit(NOW, repo_root=repo)
    assert not _by_code(result, "A2_STALE_CANDIDACY")


# ---- A3: fire freshness ---------------------------------------------------

def test_a3_zero_candidate_miswire_is_advisory(tmp_path):
    g = _healthy_gate("GATE_A", firings=0, candidates=0)
    g["last_fired_at"] = None
    g["last_checked_at"] = None
    catalog = {"GATE_A": _catalog_entry("GATE_A")}
    repo = _build_repo(tmp_path, catalog, {"GATE_A": g}, {"scripts/tests/test_x.py": "GATE_A"})
    result = dfa.audit(NOW, repo_root=repo)
    z = _by_code(result, "A3_ZERO_CANDIDATE")
    assert len(z) == 1 and z[0]["severity"] == dfa.SEV_ADVISORY


def test_a3_healthy_zero_no_finding(tmp_path):
    # has candidates, 0 firings, never fired — legitimate healthy-zero. No finding.
    g = _healthy_gate("GATE_HEALTHY_ZERO", firings=0, candidates=1936)
    g["last_fired_at"] = None
    catalog = {"GATE_HEALTHY_ZERO": _catalog_entry("GATE_HEALTHY_ZERO")}
    repo = _build_repo(tmp_path, catalog, {"GATE_HEALTHY_ZERO": g},
                       {"scripts/tests/test_x.py": "GATE_HEALTHY_ZERO"})
    result = dfa.audit(NOW, repo_root=repo)
    assert not _by_code(result, "A3_NEVER_FIRED")
    assert not _by_code(result, "A3_ZERO_CANDIDATE")


def test_a3_index_inconsistency_fires(tmp_path):
    # firings>0 but last_fired_at null — the F17 index-keying inconsistency class.
    g = _healthy_gate("GATE_A", firings=50, candidates=50)
    g["last_fired_at"] = None
    catalog = {"GATE_A": _catalog_entry("GATE_A")}
    repo = _build_repo(tmp_path, catalog, {"GATE_A": g}, {"scripts/tests/test_x.py": "GATE_A"})
    result = dfa.audit(NOW, repo_root=repo)
    nf = _by_code(result, "A3_NEVER_FIRED")
    assert len(nf) == 1 and nf[0]["severity"] == dfa.SEV_FAIL


# ---- A4: test-reference currency -----------------------------------------

def test_a4_missing_test_file_fails(tmp_path):
    catalog = {"GATE_A": _catalog_entry("GATE_A", test_rel="scripts/tests/test_gone.py")}
    f17 = {"GATE_A": _healthy_gate("GATE_A")}
    repo = _build_repo(tmp_path, catalog, f17)  # no test file written
    result = dfa.audit(NOW, repo_root=repo)
    assert _by_code(result, "A4_MISSING_TEST_FILE")


def test_a4_name_drift_fails(tmp_path):
    # test file exists but does not reference the gate name — a rename would KeyError.
    catalog = {"GATE_A": _catalog_entry("GATE_A")}
    f17 = {"GATE_A": _healthy_gate("GATE_A")}
    repo = _build_repo(tmp_path, catalog, f17,
                       {"scripts/tests/test_x.py": "def test_unrelated(): pass"})
    result = dfa.audit(NOW, repo_root=repo)
    d = _by_code(result, "A4_TEST_NAME_DRIFT")
    assert len(d) == 1 and d[0]["severity"] == dfa.SEV_FAIL


def test_a4_no_test_files_is_advisory(tmp_path):
    entry = _catalog_entry("GATE_A")
    entry["test_files"] = []
    repo = _build_repo(tmp_path, {"GATE_A": entry}, {"GATE_A": _healthy_gate("GATE_A")})
    result = dfa.audit(NOW, repo_root=repo)
    a = _by_code(result, "A4_NO_TEST_FILES")
    assert len(a) == 1 and a[0]["severity"] == dfa.SEV_ADVISORY


# ---- exempt gate ----------------------------------------------------------

def test_no_coverage_exempt_gate_skipped_in_a2_a3(tmp_path):
    # A gate declared no-coverage-exempt emits no coverage — must not be flagged
    # stale/never-fired. Synthetic name injected via the exempt set.
    g = _healthy_gate("GATE_EXEMPT", checked_days_ago=999)
    g["last_fired_at"] = None
    catalog = {"GATE_EXEMPT": _catalog_entry("GATE_EXEMPT", test_rel="scripts/tests/test_c.py")}
    repo = _build_repo(tmp_path, catalog, {"GATE_EXEMPT": g},
                       {"scripts/tests/test_c.py": "GATE_EXEMPT"})
    result = dfa.audit(NOW, repo_root=repo, no_coverage_exempt={"GATE_EXEMPT"})
    assert not _by_code(result, "A2_STALE_CANDIDACY")
    assert not _by_code(result, "A3_NEVER_FIRED")


# ---- CLI + live smoke -----------------------------------------------------

def test_strict_exit_code_on_fail(tmp_path, monkeypatch):
    catalog = {"GATE_A": _catalog_entry("GATE_A", test_rel="scripts/tests/test_gone.py")}
    repo = _build_repo(tmp_path, catalog, {"GATE_A": _healthy_gate("GATE_A")})
    monkeypatch.setenv("REPO_ROOT_OVERRIDE", str(repo))  # resolved at call time
    assert dfa.main(["--strict", "--now", "2026-08-12T00:00:00Z"]) == 1
    assert dfa.main(["--now", "2026-08-12T00:00:00Z"]) == 0  # advisory default → rc 0 even with FAIL


def test_env_override_resolved_at_call_time(tmp_path, monkeypatch):
    repo = _build_repo(tmp_path, {"GATE_A": _catalog_entry("GATE_A")},
                       {"GATE_A": _healthy_gate("GATE_A")},
                       {"scripts/tests/test_x.py": "GATE_A"})
    monkeypatch.setenv("REPO_ROOT_OVERRIDE", str(repo))
    result = dfa.audit(NOW)  # no repo_root arg → must pick up env
    assert result["gates_in_catalog"] == 1


def test_live_repo_audit_runs():
    # Against the real repo: must run without error and return a well-formed result.
    result = dfa.audit(dt.datetime(2026, 7, 10, tzinfo=dt.timezone.utc))
    assert result["gates_in_catalog"] >= 30
    assert "summary" in result and "fail" in result["summary"]
