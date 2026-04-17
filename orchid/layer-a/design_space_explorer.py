"""Design Space Explorer — sweep OrchidConfig parameters and compare composite scores.

Runs synthetic traces through the Orchid pipeline with different configurations,
producing a comparison table showing how each parameter affects performance.

This is the main tool for architecture research on any Mac — no RTL toolchain needed.

Usage:
    python design_space_explorer.py                    # run default sweep
    python design_space_explorer.py --output results   # save to custom dir
"""
from __future__ import annotations

import json
import time
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Optional

from orchestrator import Orchestrator
from trace_replayer import TraceReplayer
from units.cache_controller import CacheController
from units.batch_scheduler import BatchScheduler
from units.speculative_prefetcher import SpeculativePrefetcher
from units.coherence_unit import CoherenceUnit
from units.systolic_array import SystolicArray


@dataclass
class OrchidLayerAConfig:
    """Layer A equivalent of OrchidConfig — parameterizes the Python models."""
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

    def label(self) -> str:
        """Short label for display."""
        return (f"cache={self.cache_entries} concurrent={self.max_concurrent} "
                f"pred={self.prediction_table_size} prefetch={self.prefetch_ahead} "
                f"mesh={self.mesh_rows}x{self.mesh_cols}")


class ConfigurableOrchestrator(Orchestrator):
    """Orchestrator that accepts a config for parameter sweeps."""
    def __init__(self, config: OrchidLayerAConfig):
        # Don't call super().__init__() — we're replacing the units
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


def run_sweep(
    traces_dir: Path,
    configs: list[OrchidLayerAConfig],
    trace_filter: Optional[str] = None,
) -> list[SweepResult]:
    """Run all configs against all traces, return results."""
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


def save_results(results: list[SweepResult], output_dir: Path) -> None:
    """Save results to JSON."""
    output_dir.mkdir(parents=True, exist_ok=True)
    output_path = output_dir / "design_space_sweep.json"
    with open(output_path, "w") as f:
        json.dump([asdict(r) for r in results], f, indent=2)
    print(f"\nResults saved to {output_path}")


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Orchid Design Space Explorer")
    parser.add_argument("--output", default="../results/layer_a",
                        help="Output directory for results")
    parser.add_argument("--trace", default=None,
                        help="Filter traces by name substring")
    args = parser.parse_args()

    traces_dir = Path(__file__).parent.parent / "traces" / "synthetic"
    output_dir = Path(args.output)

    print("Orchid Design Space Explorer")
    print(f"Traces: {traces_dir}")
    print(f"Output: {output_dir}")

    configs = default_sweep_configs()
    print(f"Configs: {len(configs)}")
    print()

    results = run_sweep(traces_dir, configs, args.trace)
    print_results(results)
    save_results(results, output_dir)
