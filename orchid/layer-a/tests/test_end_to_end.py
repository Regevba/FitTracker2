import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

def test_composite_score_formula():
    from metrics import composite_score
    score = composite_score(latency_ns=100, throughput_dps=1000, energy_pj=50)
    assert score > 0
    score2 = composite_score(latency_ns=100, throughput_dps=2000, energy_pj=50)
    assert score2 > score

def test_speedup_ratio():
    from metrics import speedup_ratio
    baseline = 10.0
    orchid = 20.0
    assert speedup_ratio(orchid, baseline) == 2.0


import json
from pathlib import Path

def test_replay_synthetic_burst_haiku():
    from trace_replayer import TraceReplayer
    trace_path = Path(__file__).parent.parent.parent / "traces" / "synthetic" / "burst_haiku.jsonl"
    replayer = TraceReplayer()
    results = replayer.replay(trace_path)
    assert results.events_processed == 100
    assert results.total_cycles > 0
    assert results.composite_score > 0

def test_replay_cold_to_warm_shows_improvement():
    from trace_replayer import TraceReplayer
    trace_path = Path(__file__).parent.parent.parent / "traces" / "synthetic" / "cold_to_warm.jsonl"
    replayer = TraceReplayer()
    results = replayer.replay(trace_path)
    assert results.warm_hit_rate > results.cold_hit_rate

def test_replay_produces_results_dict():
    from trace_replayer import TraceReplayer
    trace_path = Path(__file__).parent.parent.parent / "traces" / "synthetic" / "random_uniform.jsonl"
    replayer = TraceReplayer()
    results = replayer.replay(trace_path)
    results_dict = results.to_dict()
    assert "events_processed" in results_dict
    assert "composite_score" in results_dict
    assert "cache_hit_rate" in results_dict
    assert "total_cycles" in results_dict
