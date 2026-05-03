"""Tier propagation tests (spec §3, Appendix A error code 0x01)."""
import os
import sys

import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from units.tier_propagator import (
    evict_priority,
    low_tier_input_event,
    propagate,
    should_dispatch,
    sort_for_eviction,
    systolic_output_tier,
)
from units.types import (
    Tier,
    UnitId,
    ValidationErrorCode,
    ValidationSeverity,
)


# --- propagate() — worst-case rule ---


def test_propagate_single_input_returns_same():
    assert propagate([Tier.T1]) == Tier.T1
    assert propagate([Tier.T2]) == Tier.T2
    assert propagate([Tier.T3]) == Tier.T3


def test_propagate_picks_max_intenum_value():
    """Worst-case = max IntEnum value (lowest confidence wins)."""
    assert propagate([Tier.T1, Tier.T2]) == Tier.T2
    assert propagate([Tier.T1, Tier.T3]) == Tier.T3
    assert propagate([Tier.T2, Tier.T3]) == Tier.T3
    assert propagate([Tier.T1, Tier.T2, Tier.T3]) == Tier.T3


def test_propagate_homogeneous_inputs():
    assert propagate([Tier.T1, Tier.T1, Tier.T1]) == Tier.T1
    assert propagate([Tier.T2, Tier.T2]) == Tier.T2


def test_propagate_empty_raises():
    """No inputs → no defined output tier."""
    with pytest.raises(ValueError, match="requires at least one input"):
        propagate([])


def test_propagate_accepts_iterable():
    """Generators, tuples, sets all work — duck typing."""
    assert propagate(t for t in [Tier.T1, Tier.T3]) == Tier.T3
    assert propagate((Tier.T2, Tier.T1)) == Tier.T2


# --- should_dispatch() — U1 threshold semantics ---


def test_dispatch_threshold_t1_strictest():
    """min=T1 admits only T1 inputs."""
    assert should_dispatch(Tier.T1, Tier.T1) is True
    assert should_dispatch(Tier.T2, Tier.T1) is False
    assert should_dispatch(Tier.T3, Tier.T1) is False


def test_dispatch_threshold_t2_admits_t1_and_t2():
    assert should_dispatch(Tier.T1, Tier.T2) is True
    assert should_dispatch(Tier.T2, Tier.T2) is True
    assert should_dispatch(Tier.T3, Tier.T2) is False


def test_dispatch_threshold_t3_admits_everything():
    """min=T3 is the most permissive setting — all inputs dispatch."""
    assert should_dispatch(Tier.T1, Tier.T3) is True
    assert should_dispatch(Tier.T2, Tier.T3) is True
    assert should_dispatch(Tier.T3, Tier.T3) is True


# --- low_tier_input_event() — Appendix A 0x01 ---


def test_low_tier_event_returns_none_when_dispatch_allowed():
    """Allowed dispatch → no advisory event."""
    assert low_tier_input_event(Tier.T1, Tier.T2) is None
    assert low_tier_input_event(Tier.T2, Tier.T2) is None
    assert low_tier_input_event(Tier.T3, Tier.T3) is None


def test_low_tier_event_when_dispatch_denied():
    event = low_tier_input_event(Tier.T3, Tier.T2)
    assert event is not None
    assert event.unit_id == UnitId.U1
    assert event.error_code == ValidationErrorCode.LOW_TIER_INPUT
    assert event.severity == ValidationSeverity.LOG_COUNTER
    assert event.is_advisory is False  # routes via severity → advisory
    # payload encodes (input_tier, min_required) for diagnostic readout.
    assert event.payload == (int(Tier.T3) << 4) | int(Tier.T2)


def test_low_tier_event_payload_decodable():
    """Payload must round-trip the (input, min_required) pair."""
    for input_tier in (Tier.T2, Tier.T3):
        for min_required in (Tier.T1, Tier.T2):
            ev = low_tier_input_event(input_tier, min_required)
            if ev is None:
                continue
            decoded_input = (ev.payload >> 4) & 0xF
            decoded_min = ev.payload & 0xF
            assert decoded_input == int(input_tier)
            assert decoded_min == int(min_required)


# --- evict_priority() + sort_for_eviction() — U3 ---


def test_evict_priority_t3_first():
    assert evict_priority(Tier.T3) > evict_priority(Tier.T2)
    assert evict_priority(Tier.T2) > evict_priority(Tier.T1)


def test_evict_priority_matches_int_value():
    """The mapping is currently identity, locked in v1.5."""
    assert evict_priority(Tier.T1) == 1
    assert evict_priority(Tier.T2) == 2
    assert evict_priority(Tier.T3) == 3


def test_sort_for_eviction_t3_first():
    """Eviction order: T3 → T2 → T1."""
    inputs = [Tier.T1, Tier.T3, Tier.T2, Tier.T1]
    out = sort_for_eviction(inputs)
    assert out == [Tier.T3, Tier.T2, Tier.T1, Tier.T1]


def test_sort_for_eviction_stable():
    """Stable sort within a tier preserves insertion order (LRU-like)."""
    # Three T2 entries — original order should survive.
    inputs = [Tier.T2, Tier.T1, Tier.T2, Tier.T3, Tier.T2]
    out = sort_for_eviction(inputs)
    # T3 first, then 3 T2 in original order, then T1.
    assert out == [Tier.T3, Tier.T2, Tier.T2, Tier.T2, Tier.T1]


def test_sort_for_eviction_does_not_mutate_input():
    inputs = [Tier.T1, Tier.T3, Tier.T2]
    _ = sort_for_eviction(inputs)
    assert inputs == [Tier.T1, Tier.T3, Tier.T2]  # untouched


def test_sort_for_eviction_empty():
    assert sort_for_eviction([]) == []


# --- systolic_output_tier() — U7 specialization ---


def test_systolic_2input_worst_case():
    assert systolic_output_tier(Tier.T1, Tier.T1) == Tier.T1
    assert systolic_output_tier(Tier.T1, Tier.T2) == Tier.T2
    assert systolic_output_tier(Tier.T2, Tier.T1) == Tier.T2  # commutative
    assert systolic_output_tier(Tier.T2, Tier.T3) == Tier.T3
