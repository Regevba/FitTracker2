"""HADF Phase 3A sensing-layer tests — reference store, attestation, drift monitor.

All three producers are detection/observability ONLY (no dispatch decisions —
acting layer gated on RQ4 / Phase 3B). These tests pin the math + the advisory
contract (every output carries `advisory: true` and a confidence/disposition band).
"""
import importlib.util
import json
import os
import subprocess
import sys

import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPTS = os.path.dirname(HERE)

np = pytest.importorskip("numpy")
pytest.importorskip("scipy")


def _load(modname, filename):
    spec = importlib.util.spec_from_file_location(modname, os.path.join(SCRIPTS, filename))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


build = _load("hadf_build_reference_store", "hadf-build-reference-store.py")
attest = _load("hadf_attest", "hadf-attest.py")
drift = _load("hadf_drift_monitor", "hadf-drift-monitor.py")


def _write_raw(d, name, records):
    path = os.path.join(d, f"phase2bis-raw-{name}.jsonl")
    with open(path, "w") as fh:
        for r in records:
            fh.write(json.dumps(r) + "\n")
    return path


def _records(provider, endpoint, n, ttft, tps, seed=0):
    rng = np.random.RandomState(seed)
    out = []
    for i in range(n):
        out.append({"status": "ok", "provider": provider, "endpoint": endpoint,
                    "ttft_s": float(ttft + rng.normal(0, 0.05)),
                    "tps": float(tps + rng.normal(0, 2.0))})
    return out


# ---------- reference store builder (T1) ----------

def test_reference_store_aggregates_and_filters_low_n(tmp_path):
    raw = tmp_path / "raw"
    raw.mkdir()
    _write_raw(str(raw), "s3-fast", _records("anthropic", "haiku", 200, 0.86, 149, seed=1))
    _write_raw(str(raw), "s3-slow", _records("bedrock", "haiku", 200, 1.47, 170, seed=2))
    _write_raw(str(raw), "s3-tiny", _records("mistral", "small", 9, 0.5, 60, seed=3))  # below min-n
    out = tmp_path / "ref.json"
    rc = subprocess.run(
        [sys.executable, os.path.join(SCRIPTS, "hadf-build-reference-store.py"),
         "--raw-dir", str(raw), "--out", str(out), "--as-of", "2026-06-05", "--min-n", "50"],
        capture_output=True, text=True)
    assert rc.returncode == 0, rc.stderr
    store = json.load(open(out))
    provs = {e["provider"] for e in store["endpoints"]}
    assert provs == {"anthropic", "bedrock"}            # mistral filtered
    assert any(e["provider"] == "mistral" for e in store["excluded_low_n"])
    fast = next(e for e in store["endpoints"] if e["provider"] == "anthropic")
    assert 0.80 < fast["ttft_s"]["median"] < 0.92       # recovers the planted median
    assert len(fast["mean"]) == 2 and len(fast["cov"]) == 2


def test_reference_store_drops_implausible_ttft(tmp_path):
    raw = tmp_path / "raw"
    raw.mkdir()
    recs = _records("anthropic", "haiku", 200, 0.86, 149, seed=4)
    # inject 3 connection-stall artifacts (the Sub-exp 1B Fire-0 class: 995s/886s/124s)
    for stall in (995.5, 886.5, 124.5):
        recs.append({"status": "ok", "provider": "anthropic", "endpoint": "haiku",
                     "ttft_s": stall, "tps": 150.0})
    _write_raw(str(raw), "s3", recs)
    out = tmp_path / "ref.json"
    subprocess.run(
        [sys.executable, os.path.join(SCRIPTS, "hadf-build-reference-store.py"),
         "--raw-dir", str(raw), "--out", str(out), "--max-ttft", "30", "--min-n", "50"],
        capture_output=True, text=True, check=True)
    store = json.load(open(out))
    e = store["endpoints"][0]
    assert store["dropped_implausible_ttft_total"] == 3
    assert e["provenance"]["dropped_implausible_ttft"] == 3
    assert e["n"] == 200                       # stalls excluded from the n
    assert e["ttft_s"]["std"] < 0.2            # variance NOT swallowed by the 995s outlier


def test_reference_store_errors_on_empty(tmp_path):
    raw = tmp_path / "raw"
    raw.mkdir()
    rc = subprocess.run(
        [sys.executable, os.path.join(SCRIPTS, "hadf-build-reference-store.py"),
         "--raw-dir", str(raw), "--out", str(tmp_path / "x.json")],
        capture_output=True, text=True)
    assert rc.returncode == 1
    assert "no valid records" in rc.stderr


# ---------- attestation (T2) ----------

def _toy_store():
    return {"endpoints": [
        {"provider": "anthropic", "endpoint": "haiku", "mean": [0.86, 149],
         "cov": [[0.0025, 0.0], [0.0, 4.0]]},
        {"provider": "bedrock", "endpoint": "haiku", "mean": [1.47, 170],
         "cov": [[0.0025, 0.0], [0.0, 4.0]]},
    ]}


def test_attest_strong_match_at_centroid():
    res = attest.attest(1.47, 170, _toy_store())
    assert res["attestation"] == "bedrock/haiku"
    assert res["confidence_band"] == "strong"
    assert res["advisory"] is True
    assert "Do NOT route" in res["caveat"]


def test_attest_uncertain_for_unseen_substrate():
    # far from both centroids in σ-units → uncertain
    res = attest.attest(5.0, 400, _toy_store())
    assert res["confidence_band"] == "uncertain"
    assert res["attestation"] == "unknown / unseen substrate"


def test_attest_never_omits_advisory_flag():
    for ttft, tps in [(0.86, 149), (1.47, 170), (3.0, 250)]:
        assert attest.attest(ttft, tps, _toy_store())["advisory"] is True


# ---------- drift monitor (T3) ----------

def test_drift_stable_when_window_matches_baseline(tmp_path):
    store = tmp_path / "ref.json"
    json.dump({"endpoints": [{"provider": "anthropic", "endpoint": "haiku",
                              "mean": [0.86, 149], "cov": [[0.0025, 0.0], [0.0, 4.0]],
                              "ttft_s": {"mean": 0.86, "std": 0.05, "median": 0.86},
                              "tps": {"mean": 149, "std": 2.0, "median": 149}}]}, open(store, "w"))
    win = _write_raw(str(tmp_path), "win", _records("anthropic", "haiku", 100, 0.86, 149, seed=7))
    out = tmp_path / "drift.jsonl"
    res = subprocess.run(
        [sys.executable, os.path.join(SCRIPTS, "hadf-drift-monitor.py"),
         "--store", str(store), "--window", win, "--out", str(out), "--as-of", "2026-06-05"],
        capture_output=True, text=True)
    assert res.returncode == 0, res.stderr
    row = json.loads(open(out).read().strip().splitlines()[-1])
    assert row["disposition"] == "stable"
    assert row["advisory"] is True
    assert row["rebaseline_recommended"] is False


def test_drift_significant_when_window_shifts(tmp_path):
    store = tmp_path / "ref.json"
    json.dump({"endpoints": [{"provider": "anthropic", "endpoint": "haiku",
                              "mean": [0.86, 149], "cov": [[0.0025, 0.0], [0.0, 4.0]],
                              "ttft_s": {"mean": 0.86, "std": 0.05, "median": 0.86},
                              "tps": {"mean": 149, "std": 2.0, "median": 149}}]}, open(store, "w"))
    # window TTFT shifted by ~0.4s → many σ on a 0.05 std
    win = _write_raw(str(tmp_path), "win", _records("anthropic", "haiku", 100, 1.30, 149, seed=8))
    out = tmp_path / "drift.jsonl"
    res = subprocess.run(
        [sys.executable, os.path.join(SCRIPTS, "hadf-drift-monitor.py"),
         "--store", str(store), "--window", win, "--out", str(out)],
        capture_output=True, text=True)
    assert res.returncode == 0, res.stderr
    row = json.loads(open(out).read().strip().splitlines()[-1])
    assert row["disposition"] == "significant_drift"
    assert row["rebaseline_recommended"] is True
    assert row["ks_diverged"] is True


def test_drift_insufficient_window(tmp_path):
    store = tmp_path / "ref.json"
    json.dump({"endpoints": [{"provider": "anthropic", "endpoint": "haiku",
                              "mean": [0.86, 149], "cov": [[0.0025, 0.0], [0.0, 4.0]],
                              "ttft_s": {"mean": 0.86, "std": 0.05, "median": 0.86},
                              "tps": {"mean": 149, "std": 2.0, "median": 149}}]}, open(store, "w"))
    win = _write_raw(str(tmp_path), "win", _records("anthropic", "haiku", 5, 0.86, 149, seed=9))
    out = tmp_path / "drift.jsonl"
    subprocess.run(
        [sys.executable, os.path.join(SCRIPTS, "hadf-drift-monitor.py"),
         "--store", str(store), "--window", win, "--out", str(out)],
        capture_output=True, text=True, check=True)
    row = json.loads(open(out).read().strip().splitlines()[-1])
    assert row["disposition"] == "insufficient_window"
