"""Trace Replayer — feeds .jsonl traces through the Orchid pipeline."""
from __future__ import annotations
import json
from dataclasses import dataclass, field
from pathlib import Path
from orchestrator import Orchestrator
from units.types import TaskDescriptor, WorkType, DesignScope
from metrics import composite_score

_WORK_TYPE_MAP = {
    "chore": WorkType.CHORE,
    "fix": WorkType.FIX,
    "enhancement": WorkType.ENHANCEMENT,
    "feature": WorkType.FEATURE,
}
_SCOPE_MAP = {
    "text_only": DesignScope.TEXT_ONLY,
    "layout": DesignScope.LAYOUT,
    "interaction": DesignScope.INTERACTION,
    "full_redesign": DesignScope.FULL_REDESIGN,
}


@dataclass
class ReplayResults:
    events_processed: int = 0
    total_cycles: int = 0
    total_energy_pj: float = 0.0
    cache_hit_rate: float = 0.0
    cold_hit_rate: float = 0.0
    warm_hit_rate: float = 0.0
    composite_score: float = 0.0
    per_event_cycles: list = field(default_factory=list)

    def to_dict(self):
        return {
            "events_processed": self.events_processed,
            "total_cycles": self.total_cycles,
            "total_energy_pj": self.total_energy_pj,
            "cache_hit_rate": self.cache_hit_rate,
            "cold_hit_rate": self.cold_hit_rate,
            "warm_hit_rate": self.warm_hit_rate,
            "composite_score": self.composite_score,
        }


class TraceReplayer:
    def __init__(self):
        self.orchestrator = Orchestrator()

    def replay(self, trace_path):
        events = self._load_trace(Path(trace_path))
        results = ReplayResults()
        cold_hits, cold_total = 0, 0
        warm_hits, warm_total = 0, 0
        cold_threshold = min(10, len(events) // 4) if events else 10

        for i, event in enumerate(events):
            task = self._parse_task(event)
            pipeline_result = self.orchestrator.process(task)
            results.events_processed += 1
            results.per_event_cycles.append(pipeline_result.total_cycles)

            if i < cold_threshold:
                cold_total += 1
                if pipeline_result.cache_hit:
                    cold_hits += 1
            else:
                warm_total += 1
                if pipeline_result.cache_hit:
                    warm_hits += 1

        results.total_cycles = self.orchestrator.cache.current_cycle
        results.total_energy_pj = sum(c.energy_pj for c in self.orchestrator.cache.cycle_log)
        results.cache_hit_rate = self.orchestrator.cache.hit_rate()
        results.cold_hit_rate = cold_hits / cold_total if cold_total > 0 else 0.0
        results.warm_hit_rate = warm_hits / warm_total if warm_total > 0 else 0.0

        if results.total_cycles > 0 and results.events_processed > 0:
            latency_ns = results.total_cycles
            throughput = results.events_processed / (results.total_cycles / 1e9) if results.total_cycles > 0 else 0
            energy = results.total_energy_pj if results.total_energy_pj > 0 else 1.0
            results.composite_score = composite_score(latency_ns, throughput, energy)

        return results

    def _load_trace(self, path):
        events = []
        with open(path) as f:
            for line in f:
                line = line.strip()
                if line:
                    events.append(json.loads(line))
        return events

    def _parse_task(self, event):
        task_data = event.get("task", {})
        return TaskDescriptor(
            work_type=_WORK_TYPE_MAP.get(task_data.get("work_type", "feature"), WorkType.FEATURE),
            view_count=task_data.get("view_count", 0),
            new_types_count=task_data.get("new_types_count", 0),
            scope_tier=_SCOPE_MAP.get(task_data.get("scope_tier", "text_only"), DesignScope.TEXT_ONLY),
            novelty_flag=task_data.get("novelty_flag", False),
            phase=task_data.get("phase", "implementation"),
        )
