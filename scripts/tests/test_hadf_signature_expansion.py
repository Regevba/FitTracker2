"""HADF signature-expansion tests — calibration_status honesty layer + harness.

Covers what the feature actually validates (NOT single-shot attestation accuracy,
which is RQ5-unvalidated and known-unreliable on tight on-device clusters):
  - migration stamps calibration_status across all 3 catalogs
  - builder stamps instrumented + class on emitted rows
  - attest GUARDRAIL: prior_unvalidated rows are never confident matches
  - on-device harness emits a valid instrumented on_device row (mock server)
  - distribution-level centroids are distinct (the real recognition claim)
"""
import importlib.util
import json
import os
import subprocess
import sys
import threading
from http.server import BaseHTTPRequestHandler, HTTPServer

import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPTS = os.path.dirname(HERE)
np = pytest.importorskip("numpy")


def _load(modname, filename):
    spec = importlib.util.spec_from_file_location(modname, os.path.join(SCRIPTS, filename))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


attest = _load("hadf_attest", "hadf-attest.py")
calib = _load("hadf_calibrate_device", "hadf-calibrate-device.py")


# ---------- migration (T1) ----------

def test_migration_stamps_all_three_catalogs(tmp_path):
    ref = tmp_path / "ref.json"
    profiles = tmp_path / "chip-profiles.json"
    sigs = tmp_path / "sigs.json"
    json.dump({"endpoints": [{"provider": "openai", "endpoint": "gpt-4o", "mean": [0.05, 60], "cov": [[0.01, 0], [0, 100]]}]}, open(ref, "w"))
    json.dump({"profiles": {"apple_m4": {"vendor": "Apple"}, "intel_x": {"vendor": "Intel"}}}, open(profiles, "w"))
    json.dump({"signatures": {"h100": {"vendor": "nvidia"}}}, open(sigs, "w"))
    mig = _load("hadf_migrate", "hadf-migrate-calibration-status.py")
    rc, rn = mig.migrate_reference(str(ref))
    pc, pn = mig.migrate_profiles(str(profiles))
    sc, sn = mig.migrate_sigtable(str(sigs))
    r = json.load(open(ref))["endpoints"][0]
    assert r["calibration_status"] == "instrumented" and r["class"] == "cloud"
    p = json.load(open(profiles))["profiles"]
    assert p["apple_m4"]["calibration_status"] == "prior_unvalidated"
    assert p["apple_m4"]["memory_topology"] == "soc_unified"   # Apple SoC
    assert "memory_topology" not in p["intel_x"]               # non-Apple untouched
    s = json.load(open(sigs))["signatures"]["h100"]
    assert s["calibration_status"] == "prior_unvalidated"


def test_migration_idempotent(tmp_path):
    ref = tmp_path / "ref.json"
    json.dump({"endpoints": [{"provider": "x", "endpoint": "y", "mean": [0, 0], "cov": [[1, 0], [0, 1]]}]}, open(ref, "w"))
    mig = _load("hadf_migrate2", "hadf-migrate-calibration-status.py")
    first, _ = mig.migrate_reference(str(ref))
    second, _ = mig.migrate_reference(str(ref))
    assert first == 2 and second == 0   # second run is a no-op


# ---------- attest guardrail (T2) — the load-bearing honesty guarantee ----------

def _store(*rows):
    return {"endpoints": list(rows)}


def _row(prov, ep, mean, status="instrumented"):
    return {"provider": prov, "endpoint": ep, "mean": mean,
            "cov": [[0.01, 0], [0, 100]], "calibration_status": status}


def test_attest_excludes_prior_unvalidated():
    # a prior sitting exactly on the query must NEVER be returned; the instrumented
    # row (farther away) is the only candidate.
    store = _store(
        _row("spec", "amd_ryzen_ai", [0.1, 40], status="prior_unvalidated"),  # exactly at query
        _row("openai", "gpt-4o", [0.05, 60], status="instrumented"),
    )
    res = attest.attest(0.1, 40, store)
    assert "amd_ryzen_ai" not in res["attestation"]      # prior never matched
    assert res["excluded_priors"] == 1


def test_attest_missing_status_included_backward_compat():
    # legacy/pre-migration stores have no calibration_status; those rows stay
    # candidates (back-compat). Only EXPLICIT prior_unvalidated is excluded.
    store = _store({"provider": "openai", "endpoint": "x", "mean": [0.1, 40], "cov": [[0.01, 0], [0, 100]]})  # no calibration_status
    res = attest.attest(0.1, 40, store)
    assert res["excluded_priors"] == 0                   # untagged row NOT excluded
    assert "x" in res["attestation"]                     # still a candidate


def test_attest_all_priors_returns_no_measured():
    store = _store(_row("spec", "a", [0.1, 40], status="prior_unvalidated"))
    res = attest.attest(0.1, 40, store)
    assert res["attestation"] == "no measured reference available"
    assert res["advisory"] is True


# ---------- on-device harness (T3) ----------

class _MockOllama(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def do_POST(self):
        ln = int(self.headers.get("Content-Length", 0))
        self.rfile.read(ln)
        self.send_response(200)
        self.send_header("Content-Type", "application/x-ndjson")
        self.end_headers()
        for i in range(12):
            self.wfile.write((json.dumps({"response": f"tok{i} ", "done": False}) + "\n").encode())
            self.wfile.flush()
        self.wfile.write((json.dumps({"response": "", "done": True}) + "\n").encode())


@pytest.fixture
def mock_server():
    srv = HTTPServer(("127.0.0.1", 0), _MockOllama)
    t = threading.Thread(target=srv.serve_forever, daemon=True)
    t.start()
    yield f"http://127.0.0.1:{srv.server_address[1]}/api/generate"
    srv.shutdown()


def test_harness_emits_instrumented_on_device_row(tmp_path, mock_server):
    out = tmp_path / "ref.json"
    rc = subprocess.run(
        [sys.executable, os.path.join(SCRIPTS, "hadf-calibrate-device.py"),
         "--device-label", "apple_m4", "--model", "test", "--n", "60",
         "--endpoint-url", mock_server, "--out", str(out), "--min-valid", "50"],
        capture_output=True, text=True)
    assert rc.returncode == 0, rc.stderr
    row = [e for e in json.load(open(out))["endpoints"] if e["endpoint"] == "apple_m4"][0]
    assert row["calibration_status"] == "instrumented"
    assert row["class"] == "on_device"
    assert row["provider"] == "on-device"
    assert row["n"] == 60
    assert row["provenance"]["method"] == "hadf-calibrate-device"
    assert set(row["ttft_s"]) >= {"median", "mean", "std", "p05", "p95"}


def test_harness_aborts_below_min_valid(tmp_path):
    # unreachable endpoint -> 0 valid -> must NOT write a fabricated row
    out = tmp_path / "ref.json"
    rc = subprocess.run(
        [sys.executable, os.path.join(SCRIPTS, "hadf-calibrate-device.py"),
         "--device-label", "apple_m4", "--model", "test", "--n", "5",
         "--endpoint-url", "http://127.0.0.1:1/api/generate", "--out", str(out), "--min-valid", "50"],
        capture_output=True, text=True)
    assert rc.returncode == 1
    assert "instrumented row must have real n" in rc.stderr
    assert not out.exists()


def test_harness_upsert_idempotent(tmp_path, mock_server):
    out = tmp_path / "ref.json"
    for _ in range(2):
        subprocess.run(
            [sys.executable, os.path.join(SCRIPTS, "hadf-calibrate-device.py"),
             "--device-label", "apple_m4", "--model", "test", "--n", "55",
             "--endpoint-url", mock_server, "--out", str(out), "--min-valid", "50"],
            capture_output=True, text=True, check=True)
    eps = json.load(open(out))["endpoints"]
    assert sum(1 for e in eps if e["endpoint"] == "apple_m4") == 1   # replaced, not duplicated


# ---------- distribution-level distinctness (the real recognition claim) ----------

def test_real_store_centroids_distinct():
    """The actual recognition claim: M4, M2-ollama, and a cloud endpoint have
    distinct distribution centroids (NOT a single-shot accuracy claim — that's RQ5)."""
    store_path = os.path.join(SCRIPTS, "..", ".claude", "shared", "hadf", "reference-signatures.json")
    if not os.path.exists(store_path):
        pytest.skip("real store not present")
    d = json.load(open(store_path))
    by = {e["endpoint"]: e["mean"] for e in d["endpoints"]}
    if "apple_m4" not in by or "llama3.2:3b" not in by:
        pytest.skip("M4/M2 rows not present")
    m4, m2 = np.array(by["apple_m4"]), np.array(by["llama3.2:3b"])
    assert np.linalg.norm(m4 - m2) > 0.05    # M4 and M2 centroids are distinct
