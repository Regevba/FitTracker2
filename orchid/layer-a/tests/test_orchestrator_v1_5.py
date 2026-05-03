"""End-to-end tests for v1.5 orchestrator wiring (spec §2.1, §2.2, §3).

Acceptance per plan §L5: clean trace produces zero U9 events; injected
fault-injection trace produces non-zero U9 events.
"""
import os
import sys
from typing import List

import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from orchestrator import Orchestrator
from units.types import (
    DesignScope,
    TaskDescriptor,
    Tier,
    UnitId,
    ValidationErrorCode,
    ValidationEvent,
    ValidationSeverity,
    WorkType,
)


def _make_task(tier: Tier = Tier.T2, phase: str = "implementation") -> TaskDescriptor:
    return TaskDescriptor(
        view_count=3,
        new_types_count=1,
        scope_tier=DesignScope.LAYOUT,
        novelty_flag=False,
        work_type=WorkType.FEATURE,
        phase=phase,
        data_tier=tier,
    )


# --- v1 backward compat ---


def test_orchestrator_v1_default_construction_works():
    """No v1.5 args supplied → orchestrator processes tasks like v1."""
    orch = Orchestrator()
    result = orch.process(_make_task())
    assert result.dispatch is not None
    assert result.routing is not None
    # No probes provided + permissive u1_min_tier=T3 → zero events.
    assert result.u9_events_this_step == 0
    assert orch.u9_total_advisory() == 0
    assert orch.u9_total_mandatory() == 0


def test_orchestrator_v1_pipeline_advances_cycles():
    """v1 cycle accounting still works — total_cycles strictly increases."""
    orch = Orchestrator()
    cycles = []
    for _ in range(5):
        cycles.append(orch.process(_make_task()).total_cycles)
    assert cycles == sorted(cycles)
    assert cycles[-1] > cycles[0]


# --- L5 acceptance: clean trace = zero events ---


def test_clean_trace_produces_zero_events():
    """Clean tasks (data_tier ≤ u1_min_tier, no probes) → zero U9 events."""
    orch = Orchestrator(u1_min_tier=Tier.T3)
    for _ in range(50):
        result = orch.process(_make_task(tier=Tier.T1))
    assert orch.u9_total_advisory() == 0
    assert orch.u9_total_mandatory() == 0


# --- L5 acceptance: injected fault = non-zero events ---


def test_low_tier_input_below_threshold_raises_advisory():
    """Task with data_tier=T3 + u1_min_tier=T2 → LOW_TIER_INPUT advisory."""
    orch = Orchestrator(u1_min_tier=Tier.T2)
    orch.process(_make_task(tier=Tier.T3))
    assert (
        orch.u9_advisory_count(UnitId.U1, ValidationErrorCode.LOW_TIER_INPUT) == 1
    )
    assert orch.u9_total_advisory() == 1
    assert orch.u9_total_mandatory() == 0  # advisory only, no trap


def test_low_tier_does_not_block_dispatch():
    """Even when input tier is below threshold, dispatch still completes
    (advisory-only, not blocking — per spec §3 + §5 LOG semantics)."""
    orch = Orchestrator(u1_min_tier=Tier.T1)
    result = orch.process(_make_task(tier=Tier.T3))
    assert result.dispatch is not None
    assert result.routing is not None
    assert orch.u9_total_advisory() == 1


def test_at_threshold_no_event():
    """Tier exactly at threshold → no event (≤ admits)."""
    orch = Orchestrator(u1_min_tier=Tier.T2)
    orch.process(_make_task(tier=Tier.T2))
    orch.process(_make_task(tier=Tier.T1))
    assert orch.u9_total_advisory() == 0


# --- U8 patrol scrubber injection ---


def test_u8_probe_emits_events_through_pipeline():
    """Inject a probe that fires every walk → events accumulate on U9."""
    parity_event = ValidationEvent(
        unit_id=UnitId.U2,
        error_code=ValidationErrorCode.LUT_PARITY,
        severity=ValidationSeverity.LOG_COUNTER,
        is_advisory=False,
    )

    def parity_probe() -> List[ValidationEvent]:
        return [parity_event]

    orch = Orchestrator(
        u1_min_tier=Tier.T3,
        u8_period_cycles=3,  # short period so events fire during the test
        u8_jitter_pct=10,
        u8_probes={"u2_lut": parity_probe},
        u8_rng_seed=42,
    )
    # Run enough process() calls to trigger several walks.
    for _ in range(30):
        orch.process(_make_task())

    # U2 LUT parity probe fired at least once → at least 1 advisory event
    # for (U2, LUT_PARITY).
    assert (
        orch.u9_advisory_count(UnitId.U2, ValidationErrorCode.LUT_PARITY) >= 1
    )
    assert orch.u8_violations_total() >= 1


def test_u8_no_probes_means_no_events():
    """Without any probes wired, U8 walks silently → no U9 events emitted."""
    orch = Orchestrator(
        u1_min_tier=Tier.T3,
        u8_period_cycles=3,
        u8_jitter_pct=10,
        # u8_probes={} — explicitly no probes
        u8_rng_seed=42,
    )
    for _ in range(50):
        orch.process(_make_task())
    assert orch.u8_violations_total() == 0
    assert orch.u9_total_advisory() == 0


# --- Mandatory event integration ---


def test_mandatory_event_via_u8_probe_fires_trap():
    """A LOG_TRAP probe event routes through U8 → U9 mandatory channel.
    The orchestrator drains 1 mandatory event per process() call via RR."""
    fired: List[ValidationEvent] = []

    fifo_violation = ValidationEvent(
        unit_id=UnitId.U4,
        error_code=ValidationErrorCode.FIFO_INVARIANT,
        severity=ValidationSeverity.LOG_TRAP,
        is_advisory=False,
    )

    def fifo_probe() -> List[ValidationEvent]:
        return [fifo_violation]

    orch = Orchestrator(
        u1_min_tier=Tier.T3,
        u8_period_cycles=3,
        u8_jitter_pct=10,
        u8_probes={"u4_fifo": fifo_probe},
        u8_rng_seed=42,
        trap_callback=fired.append,
    )
    for _ in range(50):
        orch.process(_make_task())

    # The probe was fired at U4 walks; events queued on U4's mandatory FIFO;
    # process() drains one per call → at least one trap should have fired.
    assert len(fired) >= 1
    assert orch.u9_mandatory_count(UnitId.U4) >= 1
    # All fired events should be the FIFO violation we injected.
    for ev in fired:
        assert ev.unit_id == UnitId.U4
        assert ev.error_code == ValidationErrorCode.FIFO_INVARIANT


# --- u9_events_this_step counter ---


def test_u9_events_this_step_reflects_per_call_increment():
    """PipelineResult.u9_events_this_step counts only this call's events."""
    orch = Orchestrator(u1_min_tier=Tier.T2)

    # First call: tier=T1 → no event.
    r1 = orch.process(_make_task(tier=Tier.T1))
    assert r1.u9_events_this_step == 0

    # Second call: tier=T3 → one LOW_TIER_INPUT advisory event.
    r2 = orch.process(_make_task(tier=Tier.T3))
    assert r2.u9_events_this_step == 1

    # Third call: tier=T1 again → no event this step (cumulative still 1).
    r3 = orch.process(_make_task(tier=Tier.T1))
    assert r3.u9_events_this_step == 0
    assert orch.u9_total_advisory() == 1
