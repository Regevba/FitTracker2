"""v1.5 type round-trip + invariant tests (spec §3, §5, §2.2, Appendix A)."""
import os
import sys

import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from units.types import (
    AssertionMode,
    Tier,
    UnitId,
    ValidationErrorCode,
    ValidationEvent,
    ValidationSeverity,
)


# --- Tier wire encoding (spec §3) ---


def test_tier_wire_encoding_matches_spec():
    """T1=01, T2=10, T3=11 on user[1:0]; 00 is reserved."""
    assert int(Tier.T1) == 0b01
    assert int(Tier.T2) == 0b10
    assert int(Tier.T3) == 0b11
    assert Tier.reserved() == 0b00


def test_tier_reserved_is_not_a_valid_member():
    """Tier(0) is reserved-zero on the wire and must not be a valid Tier."""
    with pytest.raises(ValueError):
        Tier(0)


def test_tier_worst_case_propagation():
    """U7 worst-case rule: output tier = max(input tiers) where T3 > T2 > T1
    (max IntEnum value = lowest confidence)."""
    assert max([Tier.T1, Tier.T1, Tier.T1]) == Tier.T1
    assert max([Tier.T1, Tier.T2]) == Tier.T2
    assert max([Tier.T1, Tier.T3]) == Tier.T3
    assert max([Tier.T2, Tier.T3]) == Tier.T3


# --- AssertionMode (spec §5) ---


def test_assertion_mode_default_is_log():
    """Default on reset is LOG (0b0001) per spec §5."""
    # The default isn't enforced at the type level — verified at unit instantiation.
    # Here we just confirm LOG is encoded as 0b0001 so future changes don't drift.
    assert int(AssertionMode.LOG) == 0b0001


def test_assertion_mode_lower_bits_locked_from_v1_5():
    """Bits [1:0] must cover OFF/LOG/LOG_FATAL/LOG_STICKY immutably (spec §13)."""
    assert int(AssertionMode.OFF) == 0b0000
    assert int(AssertionMode.LOG) == 0b0001
    assert int(AssertionMode.LOG_FATAL) == 0b0010
    assert int(AssertionMode.LOG_STICKY) == 0b0011


def test_assertion_mode_upper_bits_reserved():
    """Encodings 0b0100 and above are reserved for v2.0; v1.5 must not allocate."""
    valid_v1_5 = {AssertionMode.OFF, AssertionMode.LOG, AssertionMode.LOG_FATAL,
                  AssertionMode.LOG_STICKY}
    for mode in AssertionMode:
        assert mode in valid_v1_5, (
            f"AssertionMode.{mode.name}={int(mode)} added to v1.5 — should "
            f"have been reserved for v2.0 per spec §5."
        )


# --- UnitId (spec §2.2) ---


def test_unit_id_count_matches_v1_5_units():
    """v1.5 has exactly 9 units (U1–U9). U10+ are v2.0 candidates."""
    members = list(UnitId)
    assert len(members) == 9
    assert {int(u) for u in members} == set(range(1, 10))


# --- ValidationErrorCode (Appendix A) ---


def test_validation_error_code_zero_reserved():
    """Code 0x00 is reserved per spec Appendix A — must not be a member."""
    with pytest.raises(ValueError):
        ValidationErrorCode(0x00)


def test_validation_error_code_v1_5_allocation():
    """v1.5 allocates 0x01–0x0F. Codes 0x10+ reserved for v2.0+."""
    for code in ValidationErrorCode:
        assert 0x01 <= int(code) <= 0x0F, (
            f"{code.name}={int(code):#x} outside v1.5 allocation range "
            f"(spec Appendix A reserves 0x10+ for v2.0)."
        )


# --- ValidationEvent (spec §2.2) ---


def test_validation_event_default_is_log_counter():
    """Default severity is LOG_COUNTER; default is_advisory is False."""
    event = ValidationEvent(
        unit_id=UnitId.U2,
        error_code=ValidationErrorCode.LUT_PARITY,
    )
    assert event.severity == ValidationSeverity.LOG_COUNTER
    assert event.is_advisory is False
    assert event.payload == 0


def test_validation_event_routes_to_mandatory_only_when_trap():
    """Mandatory channel routing requires severity=LOG_TRAP AND not advisory."""
    # LOG_TRAP + not advisory → mandatory
    e = ValidationEvent(
        unit_id=UnitId.U2,
        error_code=ValidationErrorCode.LUT_PARITY,
        severity=ValidationSeverity.LOG_TRAP,
        is_advisory=False,
    )
    assert e.routes_to_mandatory() is True

    # LOG_TRAP + is_advisory tag → advisory (tag overrides)
    e = ValidationEvent(
        unit_id=UnitId.U2,
        error_code=ValidationErrorCode.LUT_PARITY,
        severity=ValidationSeverity.LOG_TRAP,
        is_advisory=True,
    )
    assert e.routes_to_mandatory() is False

    # LOG_COUNTER + not advisory → counter only, not mandatory
    e = ValidationEvent(
        unit_id=UnitId.U2,
        error_code=ValidationErrorCode.LUT_PARITY,
        severity=ValidationSeverity.LOG_COUNTER,
        is_advisory=False,
    )
    assert e.routes_to_mandatory() is False


def test_validation_event_is_frozen():
    """ValidationEvent must be immutable (per dataclass frozen=True)."""
    event = ValidationEvent(
        unit_id=UnitId.U2,
        error_code=ValidationErrorCode.LUT_PARITY,
    )
    with pytest.raises(AttributeError):
        event.payload = 42  # type: ignore[misc]


def test_validation_event_payload_round_trip():
    """payload is 32-bit. Verify the dataclass accepts the full range."""
    e = ValidationEvent(
        unit_id=UnitId.U3,
        error_code=ValidationErrorCode.PMU_OVERFLOW,
        payload=0xFFFFFFFF,
    )
    assert e.payload == 0xFFFFFFFF
