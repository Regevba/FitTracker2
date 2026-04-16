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
