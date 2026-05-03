"""U8 Patrol Scrubber — periodic on-chip state audit (spec §2.1).

The scrubber walks U2/U3/U4/U6 state on a configurable cadence and emits
validation events on detected drift. Per the v1.5 design spec §2.1, the
walk FSM cycles through:

    IDLE → WALK_U2 → WALK_U3 → WALK_U4 → WALK_U6 → IDLE

with one state transition per cycle. Probes run on entry to a walk state.
After the IDLE → WALK_U2 transition, the next walk is scheduled at
`current_cycle + jittered_period()`.

**Period jitter is mandatory** (spec §8 hardening). Construction with
`jitter_pct=0` raises `ValueError` — a constant period would expose a
timing oracle to attackers running on adjacent cores.

Probes are injected as callables (`Callable[[], list[ValidationEvent]]`).
A probe of `None` causes that walk state to skip silently. This lets
tests exercise individual probes without standing up the full unit set.
"""
from __future__ import annotations

import os
import sys
from dataclasses import dataclass, field
from enum import IntEnum
from random import Random
from typing import Callable, List, Optional

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from units.types import ValidationEvent


class WalkState(IntEnum):
    """Walk FSM states (spec §2.1)."""

    IDLE = 0
    WALK_U2 = 1
    WALK_U3 = 2
    WALK_U4 = 3
    WALK_U6 = 4


ProbeFn = Callable[[], List[ValidationEvent]]


@dataclass
class PatrolScrubber:
    """Periodically walks on-chip state and emits validation events.

    Period jitter (default ±10%) is mandatory — initialization with
    ``jitter_pct=0`` raises ``ValueError`` per spec §8 hardening.

    Probes are injected as callables that return their findings as
    ``ValidationEvent`` lists. Missing probes are skipped (no-op).

    Attributes:
        period_cycles: nominal walk period in cycles. The actual delay
            between walks is ``period_cycles ± (period_cycles * jitter_pct / 100)``.
        jitter_pct: jitter percentage in (0, 100]. Default 10.
        u2_lut_probe: probe for U2 Skill Router LUT parity (None to skip).
        u3_scratchpad_probe: probe for U3 scratchpad tier consistency.
        u4_fifo_probe: probe for U4 FIFO depth invariant.
        u6_mesi_probe: probe for U6 MESI state invariant.
        rng_seed: deterministic seed for jitter (for testing).
    """

    period_cycles: int
    jitter_pct: int = 10
    u2_lut_probe: Optional[ProbeFn] = None
    u3_scratchpad_probe: Optional[ProbeFn] = None
    u4_fifo_probe: Optional[ProbeFn] = None
    u6_mesi_probe: Optional[ProbeFn] = None
    rng_seed: int = 0

    state: WalkState = field(default=WalkState.IDLE, init=False)
    cycle: int = field(default=0, init=False)
    next_walk_at: int = field(default=0, init=False)
    violations_total: int = field(default=0, init=False)
    last_violation: Optional[ValidationEvent] = field(default=None, init=False)
    _rng: Random = field(init=False, repr=False)

    def __post_init__(self) -> None:
        if self.jitter_pct == 0:
            raise ValueError(
                "jitter_pct must be > 0 — period jitter is mandatory per "
                "spec §8 hardening (eliminates timing oracle for adjacent-core "
                "attackers). Set to at least 1; recommended 10."
            )
        if not (0 < self.jitter_pct <= 100):
            raise ValueError(
                f"jitter_pct must be in (0, 100]; got {self.jitter_pct}"
            )
        if self.period_cycles <= 0:
            raise ValueError(
                f"period_cycles must be > 0; got {self.period_cycles}"
            )
        self._rng = Random(self.rng_seed)
        self.next_walk_at = self._jittered_period()

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def step(self, advance_cycles: int = 1) -> List[ValidationEvent]:
        """Advance the cycle counter; return any events emitted this step.

        Args:
            advance_cycles: cycles to advance (default 1). For tests it can
                be useful to advance multiple cycles at once.

        Returns:
            List of ``ValidationEvent`` emitted this step. Empty when the
            FSM is idle and no probe fires.
        """
        events: List[ValidationEvent] = []
        for _ in range(advance_cycles):
            self.cycle += 1
            next_state = self._next_state()
            if next_state != self.state:
                events.extend(self._enter_state(next_state))
            self.state = next_state
        return events

    # ------------------------------------------------------------------
    # FSM
    # ------------------------------------------------------------------

    def _next_state(self) -> WalkState:
        """Compute the next FSM state given the current state + cycle."""
        if self.state == WalkState.IDLE:
            return WalkState.WALK_U2 if self.cycle >= self.next_walk_at else WalkState.IDLE
        if self.state == WalkState.WALK_U2:
            return WalkState.WALK_U3
        if self.state == WalkState.WALK_U3:
            return WalkState.WALK_U4
        if self.state == WalkState.WALK_U4:
            return WalkState.WALK_U6
        if self.state == WalkState.WALK_U6:
            # Walk complete; schedule next walk with fresh jitter.
            self.next_walk_at = self.cycle + self._jittered_period()
            return WalkState.IDLE
        return WalkState.IDLE  # defensive

    def _enter_state(self, state: WalkState) -> List[ValidationEvent]:
        """Run the probe associated with the entered walk state."""
        if state == WalkState.WALK_U2:
            return self._run_probe(self.u2_lut_probe)
        if state == WalkState.WALK_U3:
            return self._run_probe(self.u3_scratchpad_probe)
        if state == WalkState.WALK_U4:
            return self._run_probe(self.u4_fifo_probe)
        if state == WalkState.WALK_U6:
            return self._run_probe(self.u6_mesi_probe)
        return []

    def _run_probe(self, probe: Optional[ProbeFn]) -> List[ValidationEvent]:
        """Invoke a probe (if present) and update violation counters."""
        if probe is None:
            return []
        events = probe() or []
        for event in events:
            self.violations_total += 1
            self.last_violation = event
        return events

    # ------------------------------------------------------------------
    # Period jitter
    # ------------------------------------------------------------------

    def _jittered_period(self) -> int:
        """Return the next period length with ±jitter_pct% jitter applied.

        Uses an integer-only computation so the jittered period is always
        a whole number of cycles. Floors at 1 to guarantee forward progress.
        """
        jitter_range = (self.period_cycles * self.jitter_pct) // 100
        if jitter_range < 1:
            jitter_range = 1  # always introduce *some* variation
        jitter = self._rng.randint(-jitter_range, jitter_range)
        return max(1, self.period_cycles + jitter)
