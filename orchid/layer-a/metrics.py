"""Composite score calculator for Orchid benchmarks.
Formula: Score = w1*(1/latency_ns) + w2*throughput_dps + w3*(1/energy_pj)
where w1=0.4, w2=0.35, w3=0.25
"""
W_LATENCY = 0.4
W_THROUGHPUT = 0.35
W_ENERGY = 0.25

def composite_score(latency_ns: float, throughput_dps: float, energy_pj: float) -> float:
    lat_term = W_LATENCY * (1.0 / latency_ns) if latency_ns > 0 else 0.0
    thr_term = W_THROUGHPUT * throughput_dps
    eng_term = W_ENERGY * (1.0 / energy_pj) if energy_pj > 0 else 0.0
    return lat_term + thr_term + eng_term

def speedup_ratio(orchid_score: float, baseline_score: float) -> float:
    if baseline_score <= 0:
        return 0.0
    return orchid_score / baseline_score
