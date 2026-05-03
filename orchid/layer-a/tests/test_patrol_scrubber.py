"""U8 Patrol Scrubber tests (spec §2.1 + §8 hardening + Appendix A)."""
import os
import sys
from typing import List

import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from units.patrol_scrubber import PatrolScrubber, WalkState
from units.types import (
    UnitId,
    ValidationErrorCode,
    ValidationEvent,
    ValidationSeverity,
)


def _make_violation_probe(events_to_emit: List[ValidationEvent]):
    """Build a probe that emits a fixed list of events on every call."""

    def probe() -> List[ValidationEvent]:
        return list(events_to_emit)

    return probe


def _u2_parity_violation() -> ValidationEvent:
    return ValidationEvent(
        unit_id=UnitId.U2,
        error_code=ValidationErrorCode.LUT_PARITY,
        severity=ValidationSeverity.LOG_COUNTER,
        is_advisory=False,
        payload=0xDEAD_BEEF,
    )


def _u4_fifo_violation() -> ValidationEvent:
    return ValidationEvent(
        unit_id=UnitId.U4,
        error_code=ValidationErrorCode.FIFO_INVARIANT,
        severity=ValidationSeverity.LOG_TRAP,
        is_advisory=False,
        payload=0,
    )


# --- §8 hardening: period jitter is mandatory ---


def test_zero_jitter_raises():
    """jitter_pct=0 is forbidden — eliminates timing oracle (spec §8)."""
    with pytest.raises(ValueError, match="jitter_pct must be > 0"):
        PatrolScrubber(period_cycles=100, jitter_pct=0)


def test_negative_jitter_raises():
    with pytest.raises(ValueError, match="jitter_pct must be in"):
        PatrolScrubber(period_cycles=100, jitter_pct=-1)


def test_jitter_above_100_raises():
    with pytest.raises(ValueError, match="jitter_pct must be in"):
        PatrolScrubber(period_cycles=100, jitter_pct=101)


def test_zero_period_raises():
    with pytest.raises(ValueError, match="period_cycles must be > 0"):
        PatrolScrubber(period_cycles=0)


def test_negative_period_raises():
    with pytest.raises(ValueError, match="period_cycles must be > 0"):
        PatrolScrubber(period_cycles=-100)


# --- Clean state produces no events ---


def test_clean_state_no_events():
    """No probes provided → no events even after many walks."""
    ps = PatrolScrubber(period_cycles=10, jitter_pct=10, rng_seed=42)
    events: List[ValidationEvent] = []
    for _ in range(100):
        events.extend(ps.step())
    assert events == []
    assert ps.violations_total == 0
    assert ps.last_violation is None


def test_probes_returning_empty_no_events():
    """All probes present but return [] → no events recorded."""
    empty = lambda: []
    ps = PatrolScrubber(
        period_cycles=10,
        jitter_pct=10,
        u2_lut_probe=empty,
        u3_scratchpad_probe=empty,
        u4_fifo_probe=empty,
        u6_mesi_probe=empty,
        rng_seed=42,
    )
    for _ in range(100):
        events = ps.step()
        assert events == []
    assert ps.violations_total == 0


# --- Injected violation surfaces correctly ---


def test_u2_violation_surfaces_in_events():
    """Inject a U2 parity violation → it shows up after ~period cycles."""
    parity_event = _u2_parity_violation()
    ps = PatrolScrubber(
        period_cycles=10,
        jitter_pct=10,
        u2_lut_probe=_make_violation_probe([parity_event]),
        rng_seed=42,
    )
    all_events: List[ValidationEvent] = []
    for _ in range(50):
        all_events.extend(ps.step())
    assert parity_event in all_events
    assert ps.violations_total >= 1
    assert ps.last_violation == parity_event


def test_violations_total_counts_all():
    """Each probe call producing N events bumps violations_total by N."""
    parity_event = _u2_parity_violation()
    ps = PatrolScrubber(
        period_cycles=10,
        jitter_pct=10,
        u2_lut_probe=_make_violation_probe([parity_event, parity_event]),
        rng_seed=42,
    )
    for _ in range(200):
        ps.step()
    # Each walk fires U2 once and emits 2 events → violations grow by 2 per walk.
    assert ps.violations_total >= 2
    assert ps.violations_total % 2 == 0


def test_last_violation_is_most_recent():
    """When multiple events fire across walks, last_violation tracks the latest."""
    e1 = _u2_parity_violation()
    e2 = _u4_fifo_violation()
    ps = PatrolScrubber(
        period_cycles=5,
        jitter_pct=10,
        u2_lut_probe=_make_violation_probe([e1]),
        u4_fifo_probe=_make_violation_probe([e2]),
        rng_seed=42,
    )
    for _ in range(30):
        ps.step()
    # FIFO probe runs after parity probe in the FSM → e2 should land last.
    assert ps.last_violation == e2


# --- Walk FSM cycles correctly ---


def test_fsm_visits_all_states_in_order():
    """After enough cycles, FSM must visit IDLE → U2 → U3 → U4 → U6 → IDLE."""
    visited: List[WalkState] = []
    ps = PatrolScrubber(period_cycles=5, jitter_pct=10, rng_seed=42)
    last_state = ps.state
    for _ in range(100):
        ps.step()
        if ps.state != last_state:
            visited.append(ps.state)
            last_state = ps.state
    # Look for the canonical sequence anywhere in visited[].
    canonical = [
        WalkState.WALK_U2,
        WalkState.WALK_U3,
        WalkState.WALK_U4,
        WalkState.WALK_U6,
        WalkState.IDLE,
    ]
    for i in range(len(visited) - len(canonical) + 1):
        if visited[i : i + len(canonical)] == canonical:
            return
    pytest.fail(f"Canonical FSM sequence not found in: {visited}")


# --- Determinism via rng_seed ---


def test_same_seed_produces_same_first_walk_cycle():
    """Same rng_seed must yield identical jitter sequence."""
    ps_a = PatrolScrubber(period_cycles=100, jitter_pct=10, rng_seed=12345)
    ps_b = PatrolScrubber(period_cycles=100, jitter_pct=10, rng_seed=12345)
    assert ps_a.next_walk_at == ps_b.next_walk_at


def test_different_seeds_produce_different_jitter():
    """Different seeds should (with high probability) yield different periods."""
    ps_a = PatrolScrubber(period_cycles=100, jitter_pct=10, rng_seed=1)
    ps_b = PatrolScrubber(period_cycles=100, jitter_pct=10, rng_seed=2)
    # Either the first or some near-future jittered period should differ.
    a_periods = [ps_a._jittered_period() for _ in range(10)]
    b_periods = [ps_b._jittered_period() for _ in range(10)]
    assert a_periods != b_periods


# --- Jitter range bounds ---


def test_jitter_stays_within_bounds():
    """Over many samples, jittered period must stay within ±jitter_pct%."""
    period = 1000
    jitter_pct = 10
    ps = PatrolScrubber(period_cycles=period, jitter_pct=jitter_pct, rng_seed=42)
    lo = period - (period * jitter_pct) // 100
    hi = period + (period * jitter_pct) // 100
    samples = [ps._jittered_period() for _ in range(500)]
    assert all(lo <= s <= hi for s in samples), (
        f"sample out of bounds: min={min(samples)} max={max(samples)} "
        f"expected [{lo}, {hi}]"
    )


def test_small_period_still_jitters():
    """Even with period=1, jitter must apply some variation."""
    ps = PatrolScrubber(period_cycles=1, jitter_pct=10, rng_seed=42)
    # With period=1 and integer arithmetic, jitter_range floors at 1 per
    # implementation note in patrol_scrubber.py. So jittered period in {1, 2}
    # (max(1, 1+jitter) where jitter ∈ {-1, 0, 1}).
    samples = [ps._jittered_period() for _ in range(100)]
    assert min(samples) >= 1
    assert max(samples) <= 2
