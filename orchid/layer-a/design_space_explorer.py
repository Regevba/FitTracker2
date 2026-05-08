"""Design Space Explorer — sweep OrchidConfig parameters and compare composite scores.

Runs synthetic traces through the Orchid pipeline with different configurations,
producing a comparison table showing how each parameter affects performance.

This is the main tool for architecture research on any Mac — no RTL toolchain needed.

Usage:
    python design_space_explorer.py                    # run default v1 sweep
    python design_space_explorer.py --output results   # save to custom dir
    python design_space_explorer.py --tier-aware       # v1.5 sweep (tier dim + U9 metrics)

v1.5 extension (per docs/superpowers/specs/2026-05-03-orchid-v1-5-design.md §10
+ plan §"Track D"): when ``--tier-aware`` is passed, the sweep:

1. Regenerates synthetic traces with explicit T1/T2/T3 distributions per scenario.
2. Adds v1.5 fields (u1_min_tier, U8 period/jitter) to the config space.
3. Collects U9 event counters (advisory + mandatory) into the result rows.
4. Writes a tier-aware companion JSON so analysis can compare v1 vs v1.5 directly.
"""
from __future__ import annotations

import json
import time
from dataclasses import dataclass, asdict, field
from pathlib import Path
from typing import Optional

from orchestrator import Orchestrator
from synthetic_gen import generate_all
from trace_replayer import TraceReplayer
from units.batch_scheduler import BatchScheduler
from units.cache_controller import CacheController
from units.coherence_unit import CoherenceUnit
from units.speculative_prefetcher import SpeculativePrefetcher
from units.systolic_array import SystolicArray
from units.types import Tier


@dataclass
class OrchidLayerAConfig:
    """Layer A equivalent of OrchidConfig — parameterizes the Python models.

    v1 fields control U3-U7. v1.5 fields control U1 dispatch threshold,
    U8 patrol scrubber, and U9 validation bus. v1.5 fields default to
    permissive values so v1 sweeps continue to produce identical results.
    """
    # U3: Cache Controller
    cache_entries: int = 15
    # U4: Batch Scheduler
    max_concurrent: int = 8
    queue_depth: int = 32
    # U5: Speculative Prefetcher
    prediction_table_size: int = 64
    prefetch_ahead: int = 2
    # U6: Coherence Unit
    max_writers: int = 8
    snapshot_slots: int = 4
    # U7: Systolic Array
    mesh_rows: int = 8
    mesh_cols: int = 8

    # v1.5 — U1 dispatch threshold + U8 patrol scrubber + tier distribution
    u1_min_tier: Tier = Tier.T3              # T3 = most permissive (admits everything)
    u8_period_cycles: int = 1000
    u8_jitter_pct: int = 10
    tier_dist_t1: float = 0.60               # default high-confidence-bias
    tier_dist_t2: float = 0.30
    tier_dist_t3: float = 0.10

    def label(self) -> str:
        """Short label for display."""
        v1 = (f"cache={self.cache_entries} concurrent={self.max_concurrent} "
              f"pred={self.prediction_table_size} prefetch={self.prefetch_ahead} "
              f"mesh={self.mesh_rows}x{self.mesh_cols}")
        # Only append v1.5 portion if non-default (keeps v1 sweep labels short).
        v15_default = (
            self.u1_min_tier == Tier.T3
            and self.tier_dist_t1 == 0.60
            and self.tier_dist_t2 == 0.30
            and self.tier_dist_t3 == 0.10
        )
        if v15_default:
            return v1
        return (
            f"{v1} u1_min={self.u1_min_tier.name} "
            f"tier=({self.tier_dist_t1:.0%}/{self.tier_dist_t2:.0%}/{self.tier_dist_t3:.0%})"
        )

    def tier_distribution(self) -> dict:
        return {
            "T1": self.tier_dist_t1,
            "T2": self.tier_dist_t2,
            "T3": self.tier_dist_t3,
        }


class ConfigurableOrchestrator(Orchestrator):
    """Orchestrator that accepts a config for parameter sweeps."""

    def __init__(self, config: OrchidLayerAConfig):
        # Don't call super().__init__() — we're replacing the v1 units.
        self.cache = CacheController(max_entries=config.cache_entries)
        self.scheduler = BatchScheduler(
            max_concurrent=config.max_concurrent,
            queue_depth=config.queue_depth,
        )
        self.prefetcher = SpeculativePrefetcher(
            table_size=config.prediction_table_size,
            prefetch_ahead=config.prefetch_ahead,
        )
        self.coherence = CoherenceUnit(
            max_writers=config.max_writers,
            snapshot_slots=config.snapshot_slots,
        )
        self.systolic = SystolicArray(
            mesh_rows=config.mesh_rows,
            mesh_cols=config.mesh_cols,
        )
        # v1.5 wiring (always present; defaults are permissive)
        from units.patrol_scrubber import PatrolScrubber
        from units.validation_bus import ValidationBus
        self.validation_bus = ValidationBus(num_sources=8)
        self.patrol_scrubber = PatrolScrubber(
            period_cycles=config.u8_period_cycles,
            jitter_pct=config.u8_jitter_pct,
            rng_seed=0,
        )
        self.u1_min_tier = config.u1_min_tier

        self._last_phase = None
        self._total_cycles = 0
        self._total_energy = 0.0


@dataclass
class SweepResult:
    config_label: str
    config: dict
    trace_name: str
    events_processed: int
    total_cycles: int
    cache_hit_rate: float
    cold_hit_rate: float
    warm_hit_rate: float
    composite_score: float
    wall_time_ms: float
    # v1.5 — populated only by the tier-aware sweep; zero otherwise.
    u9_total_advisory: int = 0
    u9_total_mandatory: int = 0
    u8_violations_total: int = 0
    low_tier_input_count: int = 0  # how many tasks tripped U1's threshold


def run_sweep(
    traces_dir: Path,
    configs: list[OrchidLayerAConfig],
    trace_filter: Optional[str] = None,
    collect_u9_metrics: bool = False,
) -> list[SweepResult]:
    """Run all configs against all traces, return results.

    Args:
        traces_dir: directory containing .jsonl trace files.
        configs: list of OrchidLayerAConfig to sweep.
        trace_filter: optional substring filter on trace file names.
        collect_u9_metrics: when True (v1.5 tier-aware mode), populate the
            U9/U8 fields on each SweepResult by querying the orchestrator
            after the trace finishes replaying.
    """
    results = []

    trace_files = sorted(traces_dir.glob("*.jsonl"))
    if trace_filter:
        trace_files = [f for f in trace_files if trace_filter in f.name]

    for config in configs:
        for trace_file in trace_files:
            start = time.perf_counter()

            # Create a replayer with this config's orchestrator
            replayer = TraceReplayer()
            replayer.orchestrator = ConfigurableOrchestrator(config)
            replay_result = replayer.replay(trace_file)

            wall_ms = (time.perf_counter() - start) * 1000

            # v1.5 — pull U9/U8 counters off the orchestrator if requested.
            u9_advisory = 0
            u9_mandatory = 0
            u8_violations = 0
            low_tier_count = 0
            if collect_u9_metrics:
                from units.types import UnitId, ValidationErrorCode
                u9_advisory = replayer.orchestrator.u9_total_advisory()
                u9_mandatory = replayer.orchestrator.u9_total_mandatory()
                u8_violations = replayer.orchestrator.u8_violations_total()
                low_tier_count = replayer.orchestrator.u9_advisory_count(
                    UnitId.U1, ValidationErrorCode.LOW_TIER_INPUT
                )

            results.append(SweepResult(
                config_label=config.label(),
                config=asdict(config),
                trace_name=trace_file.stem,
                events_processed=replay_result.events_processed,
                total_cycles=replay_result.total_cycles,
                cache_hit_rate=replay_result.cache_hit_rate,
                cold_hit_rate=replay_result.cold_hit_rate,
                warm_hit_rate=replay_result.warm_hit_rate,
                composite_score=replay_result.composite_score,
                wall_time_ms=round(wall_ms, 2),
                u9_total_advisory=u9_advisory,
                u9_total_mandatory=u9_mandatory,
                u8_violations_total=u8_violations,
                low_tier_input_count=low_tier_count,
            ))

    return results


def default_sweep_configs() -> list[OrchidLayerAConfig]:
    """Generate configs for the default parameter sweep."""
    configs = []

    # Baseline
    configs.append(OrchidLayerAConfig())

    # Sweep cache_entries: 5, 10, 15, 20, 30
    for n in [5, 10, 20, 30]:
        configs.append(OrchidLayerAConfig(cache_entries=n))

    # Sweep max_concurrent: 2, 4, 8, 16
    for n in [2, 4, 16]:
        configs.append(OrchidLayerAConfig(max_concurrent=n))

    # Sweep prefetch_ahead: 0, 1, 2, 4
    for n in [0, 1, 4]:
        configs.append(OrchidLayerAConfig(prefetch_ahead=n))

    # Sweep prediction_table_size: 16, 32, 64, 128
    for n in [16, 32, 128]:
        configs.append(OrchidLayerAConfig(prediction_table_size=n))

    # Sweep mesh_rows/cols: 4x4, 8x8, 16x16
    for n in [4, 16]:
        configs.append(OrchidLayerAConfig(mesh_rows=n, mesh_cols=n))

    # Extreme configs
    configs.append(OrchidLayerAConfig(
        cache_entries=5, max_concurrent=2, prefetch_ahead=0,
    ))  # minimal
    configs.append(OrchidLayerAConfig(
        cache_entries=30, max_concurrent=16, prefetch_ahead=4,
        prediction_table_size=128, mesh_rows=16, mesh_cols=16,
    ))  # maximal

    return configs


def print_results(results: list[SweepResult]) -> None:
    """Print results as a formatted table."""
    # Group by trace
    traces = sorted(set(r.trace_name for r in results))

    for trace in traces:
        trace_results = [r for r in results if r.trace_name == trace]
        trace_results.sort(key=lambda r: r.composite_score, reverse=True)

        print(f"\n{'='*80}")
        print(f"Trace: {trace} ({trace_results[0].events_processed} events)")
        print(f"{'='*80}")
        print(f"{'Config':<55} {'Hit%':>6} {'Cycles':>8} {'Score':>12} {'ms':>6}")
        print(f"{'-'*55} {'-'*6} {'-'*8} {'-'*12} {'-'*6}")

        baseline_score = trace_results[-1].composite_score  # worst = baseline
        for r in trace_results:
            speedup = r.composite_score / baseline_score if baseline_score > 0 else 0
            marker = " ***" if r.config_label == OrchidLayerAConfig().label() else ""
            print(f"{r.config_label:<55} {r.cache_hit_rate:>5.1%} {r.total_cycles:>8} "
                  f"{r.composite_score:>12.0f} {r.wall_time_ms:>5.1f}{marker}")


def save_results(results: list[SweepResult], output_dir: Path, filename: str = "design_space_sweep.json") -> None:
    """Save results to JSON."""
    output_dir.mkdir(parents=True, exist_ok=True)
    output_path = output_dir / filename

    def _enum_safe(obj):
        """Convert IntEnum values (Tier) to ints for JSON-serializability."""
        if hasattr(obj, "name") and hasattr(obj, "value"):
            return obj.name  # store as label like "T2" for readability
        if isinstance(obj, dict):
            return {k: _enum_safe(v) for k, v in obj.items()}
        if isinstance(obj, list):
            return [_enum_safe(x) for x in obj]
        return obj

    payload = [_enum_safe(asdict(r)) for r in results]
    with open(output_path, "w") as f:
        json.dump(payload, f, indent=2)
    print(f"\nResults saved to {output_path}")


def tier_aware_sweep_configs() -> list[OrchidLayerAConfig]:
    """v1.5 sweep: vary u1_min_tier and tier_distribution while holding
    v1 hardware knobs at the recommended defaults.

    Goals:
    - Verify dispatcher actually de-rates T3 paths (per v2 mapping research §9 Q4).
    - Provide data for v7.9 enforcement-threshold calibration.
    - Quantify the U8/U9 observability cost (events emitted per N tasks).
    """
    configs = []

    # Sweep u1_min_tier with default distribution (60/30/10).
    for tier in (Tier.T1, Tier.T2, Tier.T3):
        configs.append(OrchidLayerAConfig(u1_min_tier=tier))

    # Sweep tier distribution at u1_min_tier=T2 (mid-permissive threshold).
    distributions = [
        (1.00, 0.00, 0.00),  # all T1 (best confidence) — should produce zero advisory
        (0.50, 0.50, 0.00),  # half-half T1/T2 — still no advisory at u1_min=T2
        (0.30, 0.30, 0.40),  # T3-heavy — should drive LOW_TIER_INPUT advisory rate up
        (0.00, 0.00, 1.00),  # all T3 — every task trips threshold
    ]
    for t1, t2, t3 in distributions:
        configs.append(OrchidLayerAConfig(
            u1_min_tier=Tier.T2,
            tier_dist_t1=t1,
            tier_dist_t2=t2,
            tier_dist_t3=t3,
        ))

    # Sweep U8 patrol period with default distribution.
    for period in (100, 1000, 10000):
        configs.append(OrchidLayerAConfig(u8_period_cycles=period))

    return configs


def regenerate_tier_aware_traces(target_dir: Path, configs: list[OrchidLayerAConfig], base_seed: int = 42) -> dict:
    """Regenerate traces under each unique tier distribution.

    Returns a dict mapping config-label -> trace-dir so the runner can
    replay each config's tasks against the matching trace set.
    """
    target_dir.mkdir(parents=True, exist_ok=True)
    distinct_dists = {}
    for cfg in configs:
        key = (cfg.tier_dist_t1, cfg.tier_dist_t2, cfg.tier_dist_t3)
        if key in distinct_dists:
            continue
        sub_dir = target_dir / f"dist_T1_{int(cfg.tier_dist_t1*100)}_T2_{int(cfg.tier_dist_t2*100)}_T3_{int(cfg.tier_dist_t3*100)}"
        generate_all(sub_dir, seed=base_seed, tier_distribution=cfg.tier_distribution())
        distinct_dists[key] = sub_dir
    return distinct_dists


def run_tier_aware_sweep(
    base_traces_dir: Path,
    output_dir: Path,
    seed: int = 42,
) -> list[SweepResult]:
    """End-to-end v1.5 tier-aware DSE: regenerate traces + run sweep + collect U9 metrics.

    Args:
        base_traces_dir: parent directory; per-distribution sub-dirs are created here.
        output_dir: where the JSON snapshot is saved.
        seed: deterministic base seed for trace generation.

    Returns the list of SweepResult so callers can do further analysis.
    """
    configs = tier_aware_sweep_configs()
    print(f"v1.5 tier-aware sweep: {len(configs)} configs")

    dist_to_dir = regenerate_tier_aware_traces(base_traces_dir, configs, base_seed=seed)
    print(f"  generated traces for {len(dist_to_dir)} distinct tier distributions")

    all_results: list[SweepResult] = []
    for cfg in configs:
        key = (cfg.tier_dist_t1, cfg.tier_dist_t2, cfg.tier_dist_t3)
        traces_dir = dist_to_dir[key]
        cfg_results = run_sweep(traces_dir, [cfg], collect_u9_metrics=True)
        all_results.extend(cfg_results)

    save_results(all_results, output_dir, filename="design_space_sweep_tier_aware.json")
    return all_results


def print_tier_aware_summary(results: list[SweepResult]) -> None:
    """Tier-aware results table: focus on U9 events + cache_hit_rate per config."""
    traces = sorted(set(r.trace_name for r in results))
    for trace in traces:
        trace_results = [r for r in results if r.trace_name == trace]
        print(f"\n{'=' * 100}")
        print(f"Trace: {trace}")
        print(f"{'=' * 100}")
        print(
            f"{'Config':<70} {'Hit%':>5} {'U9 adv':>7} {'U9 mand':>8} {'LowT':>5} {'Cycles':>9}"
        )
        print(f"{'-' * 70} {'-' * 5} {'-' * 7} {'-' * 8} {'-' * 5} {'-' * 9}")
        for r in trace_results:
            print(
                f"{r.config_label[:70]:<70} {r.cache_hit_rate:>4.1%} "
                f"{r.u9_total_advisory:>7} {r.u9_total_mandatory:>8} "
                f"{r.low_tier_input_count:>5} {r.total_cycles:>9}"
            )


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Orchid Design Space Explorer")
    parser.add_argument("--output", default="../results/layer_a",
                        help="Output directory for results")
    parser.add_argument("--trace", default=None,
                        help="Filter traces by name substring")
    parser.add_argument("--tier-aware", action="store_true",
                        help="Run v1.5 tier-aware sweep (Track D D2)")
    parser.add_argument("--seed", type=int, default=42,
                        help="Base seed for tier-aware trace generation")
    args = parser.parse_args()

    output_dir = Path(args.output)

    if args.tier_aware:
        print("Orchid Design Space Explorer — v1.5 tier-aware mode")
        print(f"Output: {output_dir}")
        print()
        base_traces_dir = Path(__file__).parent.parent / "traces" / "tier_aware_2026_05_03"
        results = run_tier_aware_sweep(base_traces_dir, output_dir, seed=args.seed)
        print_tier_aware_summary(results)
    else:
        traces_dir = Path(__file__).parent.parent / "traces" / "synthetic"
        print("Orchid Design Space Explorer — v1 baseline mode")
        print(f"Traces: {traces_dir}")
        print(f"Output: {output_dir}")

        configs = default_sweep_configs()
        print(f"Configs: {len(configs)}")
        print()

        results = run_sweep(traces_dir, configs, args.trace)
        print_results(results)
        save_results(results, output_dir)
    save_results(results, output_dir)
