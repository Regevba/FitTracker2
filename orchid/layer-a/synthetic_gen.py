"""Generates 5 synthetic trace files for Orchid benchmarking.

v1.5 extension (per docs/superpowers/specs/2026-05-03-orchid-v1-5-design.md §3):
each event row now carries a ``tier`` field — one of ``"T1"``, ``"T2"``,
``"T3"`` — drawn from a configurable distribution. Default distribution
is ``{T1: 60%, T2: 30%, T3: 10%}`` (high-confidence-heavy).

Backward compat: traces without a ``tier`` field continue to replay
correctly because :func:`trace_replayer` defaults missing tiers to T2 (per L7).
"""
import json
import random
from pathlib import Path
from typing import Dict, Mapping, Optional

# v1.5 — default tier distribution. Bias toward T1 since most measured
# data in the framework is instrumented (high confidence).
DEFAULT_TIER_DISTRIBUTION: Dict[str, float] = {"T1": 0.60, "T2": 0.30, "T3": 0.10}


def _validate_tier_distribution(dist: Mapping[str, float]) -> None:
    """Sanity-check a tier distribution before sampling from it."""
    if set(dist.keys()) != {"T1", "T2", "T3"}:
        raise ValueError(
            f"tier_distribution must have keys {{T1, T2, T3}}; got {sorted(dist.keys())}"
        )
    total = sum(dist.values())
    if not (0.99 <= total <= 1.01):
        raise ValueError(f"tier_distribution must sum to 1.0; got {total:.4f}")
    if any(v < 0 for v in dist.values()):
        raise ValueError("tier_distribution values must be non-negative")


def _sample_tier(rng: random.Random, dist: Mapping[str, float]) -> str:
    """Sample a tier label from the given distribution."""
    return rng.choices(["T1", "T2", "T3"], weights=[dist["T1"], dist["T2"], dist["T3"]])[0]


def generate_all(
    output_dir,
    seed: int = 42,
    tier_distribution: Optional[Mapping[str, float]] = None,
) -> None:
    """Generate the 5 standard synthetic trace files.

    Args:
        output_dir: directory to write the trace files into.
        seed: RNG seed for deterministic generation.
        tier_distribution: tier sampling weights. Default
            ``{"T1": 0.60, "T2": 0.30, "T3": 0.10}``.
    """
    dist = dict(tier_distribution or DEFAULT_TIER_DISTRIBUTION)
    _validate_tier_distribution(dist)
    rng = random.Random(seed)
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    _write(output_dir / "burst_haiku.jsonl", _burst_haiku(rng, dist))
    _write(output_dir / "contention_opus.jsonl", _contention_opus(rng, dist))
    _write(output_dir / "alternating_chains.jsonl", _alternating_chains(rng, dist))
    _write(output_dir / "random_uniform.jsonl", _random_uniform(rng, dist))
    _write(output_dir / "cold_to_warm.jsonl", _cold_to_warm(rng, dist))

def _write(path, events):
    with open(path, "w") as f:
        for e in events:
            f.write(json.dumps(e) + "\n")

def _burst_haiku(rng, dist):
    return [_event(rng, dist, i * 10, "chore", "tasks", vc=0, ntc=0) for i in range(100)]


def _contention_opus(rng, dist):
    return [
        _event(rng, dist, i * 100, "feature", "implementation", vc=8, ntc=5, novelty=True)
        for i in range(50)
    ]


def _alternating_chains(rng, dist):
    phases = ["ux_or_integration", "implementation", "testing"]
    events = []
    for cycle in range(50):
        for j, phase in enumerate(phases):
            events.append(_event(rng, dist, cycle * 3000 + j * 1000, "feature", phase, vc=3, ntc=1))
    return events


def _random_uniform(rng, dist):
    work_types = ["chore", "fix", "enhancement", "feature"]
    phases = ["research", "prd", "tasks", "implementation", "testing", "review", "merge"]
    events = []
    for i in range(500):
        events.append(
            _event(
                rng,
                dist,
                i * 100,
                rng.choice(work_types),
                rng.choice(phases),
                vc=rng.randint(0, 10),
                ntc=rng.randint(0, 8),
                novelty=rng.random() < 0.1,
            )
        )
    return events


def _cold_to_warm(rng, dist):
    events = []
    phases = ["research", "prd", "tasks", "ux_or_integration", "implementation", "testing", "review"]
    for i, phase in enumerate(phases):
        events.append(_event(rng, dist, i * 1000, "feature", phase, vc=2, ntc=1))
    for i in range(100):
        events.append(
            _event(
                rng,
                dist,
                len(phases) * 1000 + i * 100,
                "enhancement",
                "implementation",
                vc=1,
                ntc=0,
            )
        )
    return events


def _event(rng, dist, ts, work_type, phase, vc=0, ntc=0, novelty=False):
    """Build one trace row. v1.5: includes a ``tier`` field per spec §3."""
    return {
        "timestamp_ns": ts,
        "event": "dispatch_decision",
        "task": {
            "work_type": work_type,
            "phase": phase,
            "view_count": vc,
            "new_types_count": ntc,
            "scope_tier": "text_only",
            "novelty_flag": novelty,
            "tier": _sample_tier(rng, dist),  # v1.5 — propagated to U1 via TaskDescriptor.data_tier
        },
    }


if __name__ == "__main__":
    generate_all(Path(__file__).parent.parent / "traces" / "synthetic")
    print("Generated 5 synthetic trace files (v1.5 — tier column included).")
