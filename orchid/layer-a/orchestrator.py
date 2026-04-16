"""Orchid Orchestrator — wires U1-U7 into a single pipeline."""
from __future__ import annotations
from dataclasses import dataclass
from typing import Optional
from units.types import TaskDescriptor, DispatchDecision, RoutingDecision, CacheEntry
from units.dispatch_scorer import score as u1_score
from units.skill_router import route as u2_route
from units.cache_controller import CacheController
from units.batch_scheduler import BatchScheduler
from units.speculative_prefetcher import SpeculativePrefetcher
from units.coherence_unit import CoherenceUnit
from units.systolic_array import SystolicArray


@dataclass
class PipelineResult:
    dispatch: DispatchDecision
    routing: RoutingDecision
    cache_hit: bool
    total_cycles: int
    total_energy_pj: float


class Orchestrator:
    def __init__(self) -> None:
        self.cache = CacheController(max_entries=15)
        self.scheduler = BatchScheduler(max_concurrent=8, queue_depth=32)
        self.prefetcher = SpeculativePrefetcher(table_size=64, prefetch_ahead=2)
        self.coherence = CoherenceUnit(max_writers=8, snapshot_slots=4)
        self.systolic = SystolicArray(mesh_rows=8, mesh_cols=8)
        self._last_phase: Optional[str] = None
        self._total_cycles: int = 0
        self._total_energy: float = 0.0

    def process(self, task: TaskDescriptor) -> PipelineResult:
        # U1: Score (1 cycle)
        dispatch = u1_score(task)
        self._total_cycles += 1
        self._total_energy += 1.0

        # U2: Route (2 cycles)
        routing = u2_route(dispatch.score, dispatch.tier, task.phase)
        self._total_cycles += 2
        self._total_energy += 2.0

        # U5: Speculative prefetch on phase change
        if self._last_phase and self._last_phase != task.phase:
            self.prefetcher.record_transition(self._last_phase, task.phase)
            predictions = self.prefetcher.predict(task.phase)
            for pred_phase in predictions:
                self.cache.put(CacheEntry(
                    key="prefetch_" + pred_phase,
                    compressed_view="prefetched for " + pred_phase,
                    level="L1"
                ))

        # U3: Cache lookup
        cache_key = routing.skills[0] + "_L1" if routing.skills else "unknown"
        cached = self.cache.get(cache_key)
        cache_hit = cached is not None
        if not cache_hit:
            self.cache.put(CacheEntry(
                key=cache_key,
                compressed_view=routing.skills[0] + " compressed view" if routing.skills else "",
                full_entry=routing.skills[0] + " full entry" if routing.skills else "",
                level="L1"
            ))

        # U4: Enqueue for batch
        self.scheduler.enqueue(task, dispatch)

        # Accumulate cycles from stateful units
        self._total_cycles += self.cache.current_cycle
        self._total_energy += sum(c.energy_pj for c in self.cache.cycle_log[-2:]) if self.cache.cycle_log else 0

        self._last_phase = task.phase

        return PipelineResult(
            dispatch=dispatch,
            routing=routing,
            cache_hit=cache_hit,
            total_cycles=self._total_cycles,
            total_energy_pj=self._total_energy,
        )
