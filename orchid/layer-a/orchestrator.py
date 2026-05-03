"""Orchid Orchestrator — wires U1-U7 (v1) + U8/U9 (v1.5) into a single pipeline.

v1.5 additions (per docs/superpowers/specs/2026-05-03-orchid-v1-5-design.md):

- **U8 Patrol Scrubber** runs in the background, advancing one cycle per
  ``process()`` call. Probes are injectable; without probes the scrubber
  walks silently.
- **U9 Validation Bus** receives events from any unit (including U1's
  dispatch-threshold advisory and U8's patrol findings) and routes them
  to mandatory or advisory channels per ``ValidationEvent.routes_to_mandatory()``.
- **U1 dispatch threshold** — a task with ``data_tier`` higher (i.e. lower
  confidence) than the configured ``u1_min_tier`` raises a
  ``LOW_TIER_INPUT`` advisory event; the task still dispatches but the
  event is recorded.

All v1.5 wiring is additive. Construction with no v1.5 args matches v1
behavior; the new units sit idle until the caller provides probes or a
trap callback.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Callable, Dict, Optional

from units.batch_scheduler import BatchScheduler
from units.cache_controller import CacheController
from units.coherence_unit import CoherenceUnit
from units.dispatch_scorer import score as u1_score
from units.patrol_scrubber import PatrolScrubber, ProbeFn
from units.skill_router import route as u2_route
from units.speculative_prefetcher import SpeculativePrefetcher
from units.systolic_array import SystolicArray
from units.tier_propagator import low_tier_input_event
from units.types import (
    CacheEntry,
    DispatchDecision,
    RoutingDecision,
    TaskDescriptor,
    Tier,
    UnitId,
    ValidationErrorCode,
    ValidationEvent,
)
from units.validation_bus import ValidationBus


@dataclass
class PipelineResult:
    dispatch: DispatchDecision
    routing: RoutingDecision
    cache_hit: bool
    total_cycles: int
    total_energy_pj: float
    # v1.5: number of validation events emitted to U9 during this process() call.
    u9_events_this_step: int = 0


class Orchestrator:
    """Wires v1 units (U1-U7) + v1.5 additions (U8 Patrol Scrubber, U9 Validation Bus)."""

    def __init__(
        self,
        # v1 units (no parameter changes — backward-compatible defaults)
        max_cache_entries: int = 15,
        max_concurrent_batches: int = 8,
        batch_queue_depth: int = 32,
        prefetcher_table_size: int = 64,
        prefetch_ahead: int = 2,
        max_writers: int = 8,
        snapshot_slots: int = 4,
        mesh_rows: int = 8,
        mesh_cols: int = 8,
        # v1.5: U8 Patrol Scrubber configuration
        u8_period_cycles: int = 1000,
        u8_jitter_pct: int = 10,
        u8_probes: Optional[Dict[str, ProbeFn]] = None,
        u8_rng_seed: int = 0,
        # v1.5: U9 Validation Bus configuration
        u9_log_buffer_entries: int = 0,
        trap_callback: Optional[Callable[[ValidationEvent], None]] = None,
        # v1.5: U1 dispatch threshold (T3 = most permissive — admits everything)
        u1_min_tier: Tier = Tier.T3,
    ) -> None:
        # v1 stateful units
        self.cache = CacheController(max_entries=max_cache_entries)
        self.scheduler = BatchScheduler(
            max_concurrent=max_concurrent_batches, queue_depth=batch_queue_depth
        )
        self.prefetcher = SpeculativePrefetcher(
            table_size=prefetcher_table_size, prefetch_ahead=prefetch_ahead
        )
        self.coherence = CoherenceUnit(max_writers=max_writers, snapshot_slots=snapshot_slots)
        self.systolic = SystolicArray(mesh_rows=mesh_rows, mesh_cols=mesh_cols)

        # v1.5 additions
        self.validation_bus = ValidationBus(
            num_sources=8,
            log_buffer_entries=u9_log_buffer_entries,
            trap_callback=trap_callback,
        )
        probes = u8_probes or {}
        self.patrol_scrubber = PatrolScrubber(
            period_cycles=u8_period_cycles,
            jitter_pct=u8_jitter_pct,
            u2_lut_probe=probes.get("u2_lut"),
            u3_scratchpad_probe=probes.get("u3_scratchpad"),
            u4_fifo_probe=probes.get("u4_fifo"),
            u6_mesi_probe=probes.get("u6_mesi"),
            rng_seed=u8_rng_seed,
        )
        self.u1_min_tier = u1_min_tier

        # Internal state
        self._last_phase: Optional[str] = None
        self._total_cycles: int = 0
        self._total_energy: float = 0.0

    # ------------------------------------------------------------------
    # Pipeline
    # ------------------------------------------------------------------

    def process(self, task: TaskDescriptor) -> PipelineResult:
        """Run one task through the pipeline.

        Side effects: cycle counters advance, U8 patrol scrubber advances by 1
        cycle, validation events get submitted to U9.
        """
        events_before = self.validation_bus.total_advisory_count() + \
            self.validation_bus.total_mandatory_count()

        # v1.5 — U1 dispatch threshold check (advisory only; doesn't block dispatch).
        low_tier_event = low_tier_input_event(task.data_tier, self.u1_min_tier)
        if low_tier_event is not None:
            self.validation_bus.submit(low_tier_event)

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
                self.cache.put(
                    CacheEntry(
                        key="prefetch_" + pred_phase,
                        compressed_view="prefetched for " + pred_phase,
                        level="L1",
                    )
                )

        # U3: Cache lookup
        cache_key = routing.skills[0] + "_L1" if routing.skills else "unknown"
        cached = self.cache.get(cache_key)
        cache_hit = cached is not None
        if not cache_hit:
            self.cache.put(
                CacheEntry(
                    key=cache_key,
                    compressed_view=routing.skills[0] + " compressed view"
                    if routing.skills
                    else "",
                    full_entry=routing.skills[0] + " full entry"
                    if routing.skills
                    else "",
                    level="L1",
                )
            )

        # U4: Enqueue for batch
        self.scheduler.enqueue(task, dispatch)

        # Accumulate cycles from stateful units
        self._total_cycles += self.cache.current_cycle
        self._total_energy += (
            sum(c.energy_pj for c in self.cache.cycle_log[-2:])
            if self.cache.cycle_log
            else 0
        )

        # v1.5 — Advance U8 patrol scrubber by 1 cycle; submit any events to U9.
        u8_events = self.patrol_scrubber.step()
        for event in u8_events:
            self.validation_bus.submit(event)

        # v1.5 — Drain one mandatory event per cycle (RR arbitration).
        self.validation_bus.step()

        self._last_phase = task.phase

        events_after = self.validation_bus.total_advisory_count() + \
            self.validation_bus.total_mandatory_count()

        return PipelineResult(
            dispatch=dispatch,
            routing=routing,
            cache_hit=cache_hit,
            total_cycles=self._total_cycles,
            total_energy_pj=self._total_energy,
            u9_events_this_step=events_after - events_before,
        )

    # ------------------------------------------------------------------
    # Validation-event query API (for tests + metrics)
    # ------------------------------------------------------------------

    def u9_advisory_count(
        self, unit_id: UnitId, error_code: ValidationErrorCode
    ) -> int:
        return self.validation_bus.get_advisory_count(unit_id, error_code)

    def u9_mandatory_count(self, unit_id: UnitId) -> int:
        return self.validation_bus.get_mandatory_count(unit_id)

    def u9_total_advisory(self) -> int:
        return self.validation_bus.total_advisory_count()

    def u9_total_mandatory(self) -> int:
        return self.validation_bus.total_mandatory_count()

    def u8_violations_total(self) -> int:
        return self.patrol_scrubber.violations_total
