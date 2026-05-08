"""Tier propagation — cross-cutting v1.5 primitive (spec §3).

Tier values cross every functional unit. This module is the canonical
home of the rules:

- **Worst-case-on-output (U7 Systolic Array):** output tier = `max(inputs)`,
  where `max` of `IntEnum` returns the largest integer — and per spec §3
  T3=0b11 > T2=0b10 > T1=0b01 — i.e. *lowest confidence* wins.
- **Dispatch threshold (U1 Dispatch Scorer):** an input below the
  configured `min_tier_required` raises a `LOW_TIER_INPUT` advisory.
- **Eviction priority (U3 Cache Controller):** under capacity pressure,
  T3 entries evict before T2, before T1 — i.e. lowest-confidence-first.

These rules are implemented as pure functions (no state) so they can be
called from any unit's behavioral model and any directed test.
"""
from __future__ import annotations

import os
import sys
from typing import Iterable, List, Optional

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from units.types import (
    Tier,
    UnitId,
    ValidationErrorCode,
    ValidationEvent,
    ValidationSeverity,
)


def propagate(inputs: Iterable[Tier]) -> Tier:
    """Worst-case tier propagation rule (spec §3 + §2.2 worst-case rule).

    Args:
        inputs: 1-or-more tiers entering a combinator (e.g. U7 systolic).

    Returns:
        Tier matching `max(inputs)` — i.e. the **lowest** confidence input
        wins because T3 (narrative) has the largest IntEnum value.

    Raises:
        ValueError: if `inputs` is empty (no propagation possible).
    """
    inputs_list = list(inputs)
    if not inputs_list:
        raise ValueError(
            "propagate() requires at least one input tier; "
            "an empty input list has no defined output tier."
        )
    return max(inputs_list)


def should_dispatch(input_tier: Tier, min_tier_required: Tier) -> bool:
    """Whether U1 should dispatch a task with the given input tier.

    Args:
        input_tier: tier of the task's CU v2 input bus.
        min_tier_required: the dispatch threshold from `u1_min_tier` CSR.

    Returns:
        True if `input_tier <= min_tier_required` (strict-or-equal — a
        T1 input meets a T1 minimum, T2, or T3 threshold).

    Note: the test uses `<=` because lower IntEnum values mean *higher*
    confidence (T1=0b01 < T2=0b10 < T3=0b11). A `min_tier_required` of
    `T2` admits T1 and T2 but not T3.
    """
    return int(input_tier) <= int(min_tier_required)


def low_tier_input_event(
    input_tier: Tier, min_tier_required: Tier
) -> Optional[ValidationEvent]:
    """Build a `LOW_TIER_INPUT` advisory event for U1 if dispatch fails.

    Returns `None` when dispatch is allowed; otherwise a fresh
    `ValidationEvent` ready to submit to U9.

    Per Appendix A error code 0x01.
    """
    if should_dispatch(input_tier, min_tier_required):
        return None
    return ValidationEvent(
        unit_id=UnitId.U1,
        error_code=ValidationErrorCode.LOW_TIER_INPUT,
        severity=ValidationSeverity.LOG_COUNTER,
        is_advisory=False,  # routes via severity=LOG_COUNTER → advisory
        payload=(int(input_tier) << 4) | int(min_tier_required),
    )


def evict_priority(entry_tier: Tier) -> int:
    """Eviction priority for U3 Cache Controller (spec §3 §8 P0).

    Higher returned value → evicted first under capacity pressure. Mapping:

    | Tier | Priority |
    |------|----------|
    | T3   | 3 (evict first) |
    | T2   | 2 |
    | T1   | 1 (evict last)  |

    The mapping is identical to `int(Tier)` — kept as a separate function
    so the eviction policy is named in code, not implicit in an IntEnum.
    """
    return int(entry_tier)


def sort_for_eviction(entries: List[Tier]) -> List[Tier]:
    """Return tiers sorted in eviction order (highest priority first).

    Args:
        entries: list of cache-entry tiers under consideration for eviction.

    Returns:
        New list sorted T3 → T2 → T1 (lowest confidence evicted first).
        Stable sort preserves insertion order within a tier (LRU-like).
    """
    return sorted(entries, key=evict_priority, reverse=True)


def systolic_output_tier(input_a_tier: Tier, input_b_tier: Tier) -> Tier:
    """U7 Systolic Array specialization of `propagate()`.

    Output of a 2-input matmul-style operation gets `max(a, b)` — the
    worst-case (lowest-confidence) input wins.
    """
    return propagate([input_a_tier, input_b_tier])
