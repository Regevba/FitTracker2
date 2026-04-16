"""Generates 5 synthetic trace files for Orchid benchmarking."""
import json
import random
from pathlib import Path

def generate_all(output_dir, seed=42):
    random.seed(seed)
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    _write(output_dir / "burst_haiku.jsonl", _burst_haiku())
    _write(output_dir / "contention_opus.jsonl", _contention_opus())
    _write(output_dir / "alternating_chains.jsonl", _alternating_chains())
    _write(output_dir / "random_uniform.jsonl", _random_uniform())
    _write(output_dir / "cold_to_warm.jsonl", _cold_to_warm())

def _write(path, events):
    with open(path, "w") as f:
        for e in events:
            f.write(json.dumps(e) + "\n")

def _burst_haiku():
    return [_event(i * 10, "chore", "tasks", vc=0, ntc=0) for i in range(100)]

def _contention_opus():
    return [_event(i * 100, "feature", "implementation", vc=8, ntc=5, novelty=True) for i in range(50)]

def _alternating_chains():
    phases = ["ux_or_integration", "implementation", "testing"]
    events = []
    for cycle in range(50):
        for j, phase in enumerate(phases):
            events.append(_event(cycle * 3000 + j * 1000, "feature", phase, vc=3, ntc=1))
    return events

def _random_uniform():
    work_types = ["chore", "fix", "enhancement", "feature"]
    phases = ["research", "prd", "tasks", "implementation", "testing", "review", "merge"]
    events = []
    for i in range(500):
        events.append(_event(
            i * 100, random.choice(work_types), random.choice(phases),
            vc=random.randint(0, 10), ntc=random.randint(0, 8),
            novelty=random.random() < 0.1
        ))
    return events

def _cold_to_warm():
    events = []
    phases = ["research", "prd", "tasks", "ux_or_integration", "implementation", "testing", "review"]
    for i, phase in enumerate(phases):
        events.append(_event(i * 1000, "feature", phase, vc=2, ntc=1))
    for i in range(100):
        events.append(_event(len(phases) * 1000 + i * 100, "enhancement", "implementation", vc=1, ntc=0))
    return events

def _event(ts, work_type, phase, vc=0, ntc=0, novelty=False):
    return {
        "timestamp_ns": ts,
        "event": "dispatch_decision",
        "task": {"work_type": work_type, "phase": phase, "view_count": vc, "new_types_count": ntc, "scope_tier": "text_only", "novelty_flag": novelty},
    }

if __name__ == "__main__":
    generate_all(Path(__file__).parent.parent / "traces" / "synthetic")
    print("Generated 5 synthetic trace files.")
