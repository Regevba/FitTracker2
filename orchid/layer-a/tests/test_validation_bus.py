"""U9 Validation Bus tests (spec §2.2 + Appendix A)."""
import os
import sys
from typing import List

import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from units.types import (
    UnitId,
    ValidationErrorCode,
    ValidationEvent,
    ValidationSeverity,
)
from units.validation_bus import ValidationBus


# --- Helpers ---


def _trap_event(unit_id: UnitId, error_code: ValidationErrorCode) -> ValidationEvent:
    """A LOG_TRAP severity event that routes to the mandatory channel."""
    return ValidationEvent(
        unit_id=unit_id,
        error_code=error_code,
        severity=ValidationSeverity.LOG_TRAP,
        is_advisory=False,
        payload=0,
    )


def _advisory_event(unit_id: UnitId, error_code: ValidationErrorCode) -> ValidationEvent:
    """A LOG_COUNTER severity event that routes to the advisory channel."""
    return ValidationEvent(
        unit_id=unit_id,
        error_code=error_code,
        severity=ValidationSeverity.LOG_COUNTER,
        is_advisory=False,
        payload=0,
    )


def _tagged_advisory_event(
    unit_id: UnitId, error_code: ValidationErrorCode
) -> ValidationEvent:
    """LOG_TRAP severity but `is_advisory=True` — tag overrides severity."""
    return ValidationEvent(
        unit_id=unit_id,
        error_code=error_code,
        severity=ValidationSeverity.LOG_TRAP,
        is_advisory=True,
        payload=0,
    )


# --- Construction ---


def test_default_num_sources_is_8():
    bus = ValidationBus()
    assert bus.queue_depth(UnitId.U1) == 0


def test_non_8_sources_raises():
    """v1.5 locks num_sources at 8 (one per U1-U8)."""
    with pytest.raises(ValueError, match="num_sources must be 8"):
        ValidationBus(num_sources=4)


def test_negative_log_buffer_raises():
    with pytest.raises(ValueError, match=">= 0"):
        ValidationBus(log_buffer_entries=-1)


def test_log_buffer_disabled_by_default():
    """Per spec §2.2, log buffer is P1; v1.5.0 default = 0 (disabled)."""
    bus = ValidationBus()
    assert bus.log_buffer_capacity() == 0
    assert bus.log_buffer_size() == 0
    assert bus.log_buffer_snapshot() == []


# --- Channel routing ---


def test_advisory_event_increments_counter_no_callback():
    """LOG_COUNTER severity → advisory channel; no trap fires."""
    fired: List[ValidationEvent] = []
    bus = ValidationBus(trap_callback=fired.append)

    bus.submit(_advisory_event(UnitId.U2, ValidationErrorCode.LUT_MISS))
    assert bus.get_advisory_count(UnitId.U2, ValidationErrorCode.LUT_MISS) == 1
    assert fired == []
    assert bus.total_queued() == 0


def test_advisory_event_with_tag_does_not_fire_trap():
    """`is_advisory=True` overrides LOG_TRAP severity → advisory routing."""
    fired: List[ValidationEvent] = []
    bus = ValidationBus(trap_callback=fired.append)

    bus.submit(_tagged_advisory_event(UnitId.U2, ValidationErrorCode.LUT_PARITY))
    assert fired == []
    assert bus.get_advisory_count(UnitId.U2, ValidationErrorCode.LUT_PARITY) == 1


def test_mandatory_event_queues_until_step():
    """Mandatory event sits in a per-source FIFO until step() drains it."""
    fired: List[ValidationEvent] = []
    bus = ValidationBus(trap_callback=fired.append)

    bus.submit(_trap_event(UnitId.U2, ValidationErrorCode.LUT_PARITY))
    assert fired == []  # not drained yet
    assert bus.queue_depth(UnitId.U2) == 1

    drained = bus.step()
    assert drained is not None
    assert drained.unit_id == UnitId.U2
    assert len(fired) == 1
    assert bus.queue_depth(UnitId.U2) == 0
    assert bus.get_mandatory_count(UnitId.U2) == 1


def test_step_returns_none_when_empty():
    bus = ValidationBus()
    assert bus.step() is None


# --- RR arbitration: starvation-freedom ---


def test_rr_does_not_starve_quiet_source():
    """Saturated U2 + 1 event from U7 → U7 drains within RR window."""
    fired: List[ValidationEvent] = []
    bus = ValidationBus(trap_callback=fired.append)

    # U2 is the loudest source.
    for _ in range(100):
        bus.submit(_trap_event(UnitId.U2, ValidationErrorCode.LUT_PARITY))

    # U7 has just one event.
    bus.submit(_trap_event(UnitId.U7, ValidationErrorCode.SYSTOLIC_TIER_DOWNGRADE))

    # After draining U2 once, the RR pointer skips ahead, so U7 must
    # drain within the next pass through the source list.
    bus.step()  # drains U2[0]
    bus.step()  # drains U7[0]
    assert bus.get_mandatory_count(UnitId.U7) == 1


def test_rr_round_robin_when_all_saturated():
    """Every source saturated → drains evenly across all sources."""
    bus = ValidationBus()
    for uid in UnitId:
        if uid == UnitId.U9:  # U9 is destination, not source
            continue
        for _ in range(5):
            bus.submit(_trap_event(uid, ValidationErrorCode.LUT_PARITY))

    # Drain 8 events. RR should pick one per source in order.
    drained = [bus.step() for _ in range(8)]
    drained_units = [e.unit_id for e in drained if e is not None]
    # Each source should be hit exactly once over 8 steps.
    assert len(drained_units) == 8
    assert sorted({int(u) for u in drained_units}) == [1, 2, 3, 4, 5, 6, 7, 8]


def test_drain_all_empties_every_queue():
    bus = ValidationBus()
    for uid in (UnitId.U2, UnitId.U4, UnitId.U7):
        for _ in range(3):
            bus.submit(_trap_event(uid, ValidationErrorCode.LUT_PARITY))

    drained = bus.drain_all()
    assert len(drained) == 9
    assert bus.total_queued() == 0
    assert bus.total_mandatory_count() == 9


# --- Per-(unit, error_code) advisory matrix ---


def test_advisory_matrix_indexed_by_unit_and_error():
    bus = ValidationBus()
    # Same unit, same error → counter increments.
    bus.submit(_advisory_event(UnitId.U3, ValidationErrorCode.PMU_OVERFLOW))
    bus.submit(_advisory_event(UnitId.U3, ValidationErrorCode.PMU_OVERFLOW))
    assert bus.get_advisory_count(UnitId.U3, ValidationErrorCode.PMU_OVERFLOW) == 2

    # Same unit, different error → distinct slot.
    bus.submit(_advisory_event(UnitId.U3, ValidationErrorCode.CACHE_TIER_MISMATCH))
    assert bus.get_advisory_count(UnitId.U3, ValidationErrorCode.PMU_OVERFLOW) == 2
    assert (
        bus.get_advisory_count(UnitId.U3, ValidationErrorCode.CACHE_TIER_MISMATCH) == 1
    )

    # Different unit, same error → distinct slot.
    bus.submit(_advisory_event(UnitId.U4, ValidationErrorCode.PMU_OVERFLOW))
    assert bus.get_advisory_count(UnitId.U4, ValidationErrorCode.PMU_OVERFLOW) == 1


def test_total_counters():
    bus = ValidationBus()
    bus.submit(_advisory_event(UnitId.U2, ValidationErrorCode.LUT_MISS))
    bus.submit(_advisory_event(UnitId.U3, ValidationErrorCode.PMU_OVERFLOW))
    bus.submit(_trap_event(UnitId.U4, ValidationErrorCode.FIFO_INVARIANT))
    bus.step()  # drain the mandatory one

    assert bus.total_advisory_count() == 2
    assert bus.total_mandatory_count() == 1


# --- Log buffer (P1, optional) ---


def test_log_buffer_captures_advisory_events():
    bus = ValidationBus(log_buffer_entries=10)
    bus.submit(_advisory_event(UnitId.U2, ValidationErrorCode.LUT_MISS))
    bus.submit(_advisory_event(UnitId.U3, ValidationErrorCode.PMU_OVERFLOW))

    snap = bus.log_buffer_snapshot()
    assert len(snap) == 2
    assert snap[0].unit_id == UnitId.U2
    assert snap[1].unit_id == UnitId.U3


def test_log_buffer_captures_drained_mandatory_events():
    bus = ValidationBus(log_buffer_entries=10)
    bus.submit(_trap_event(UnitId.U2, ValidationErrorCode.LUT_PARITY))
    # Not in buffer yet — only added after drain.
    assert bus.log_buffer_size() == 0

    bus.step()
    assert bus.log_buffer_size() == 1
    assert bus.log_buffer_snapshot()[0].unit_id == UnitId.U2


def test_log_buffer_drops_oldest_at_capacity():
    """Circular buffer with maxlen=3 evicts oldest entries."""
    bus = ValidationBus(log_buffer_entries=3)
    for code in (
        ValidationErrorCode.LUT_PARITY,
        ValidationErrorCode.LUT_MISS,
        ValidationErrorCode.PMU_OVERFLOW,
        ValidationErrorCode.CACHE_TIER_MISMATCH,
    ):
        bus.submit(_advisory_event(UnitId.U2, code))

    snap = bus.log_buffer_snapshot()
    assert len(snap) == 3
    # Oldest (LUT_PARITY) should have been evicted.
    codes = [e.error_code for e in snap]
    assert ValidationErrorCode.LUT_PARITY not in codes
    assert ValidationErrorCode.CACHE_TIER_MISMATCH in codes


def test_log_buffer_capacity_zero_means_disabled():
    bus = ValidationBus(log_buffer_entries=0)
    bus.submit(_advisory_event(UnitId.U2, ValidationErrorCode.LUT_MISS))
    assert bus.log_buffer_size() == 0
    assert bus.log_buffer_snapshot() == []
