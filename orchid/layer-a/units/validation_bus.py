"""U9 Validation Bus — mandatory + advisory channels (spec §2.2).

Receives ValidationEvent messages from U1-U8 and routes them to one of two
channels:

- **Mandatory channel** — events with `severity=LOG_TRAP` and `is_advisory=False`.
  Per-source FIFOs feed a round-robin arbiter; one event drained per `step()`
  call. The arbiter is starvation-free: a busy source cannot block others.
  Dispatched events invoke the optional `trap_callback`.

- **Advisory channel** — everything else (LOG_COUNTER severity, or any event
  with `is_advisory=True`). Counted in a per-(unit, error_code) matrix.
  No trap; no arbitration; counter increment is synchronous on `submit()`.

Both channels also write into the optional log buffer (P1 — disabled by
default in v1.5.0; capacity controlled by `log_buffer_entries`).

Routing decision is encapsulated in `ValidationEvent.routes_to_mandatory()`
(see types.py), so changes to severity semantics happen in one place.
"""
from __future__ import annotations

import os
import sys
from collections import defaultdict, deque
from dataclasses import dataclass, field
from typing import Callable, Deque, Dict, List, Optional, Tuple

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from units.types import UnitId, ValidationErrorCode, ValidationEvent


TrapCallback = Callable[[ValidationEvent], None]


# Source ordering on the bus (matches UnitId values 1..8). U9 is the
# destination — it does not submit to itself.
_SOURCE_ORDER: Tuple[UnitId, ...] = (
    UnitId.U1,
    UnitId.U2,
    UnitId.U3,
    UnitId.U4,
    UnitId.U5,
    UnitId.U6,
    UnitId.U7,
    UnitId.U8,
)


class ValidationBus:
    """Per spec §2.2.

    P0 in v1.5: mandatory channel (RR-arbitrated) + advisory channel
    (counter matrix) + optional log buffer.
    P1 deferred to v1.5.1: 256-entry log buffer was reserved in spec but
    is enabled here via `log_buffer_entries` for advance prototyping.
    """

    def __init__(
        self,
        num_sources: int = 8,
        log_buffer_entries: int = 0,
        trap_callback: Optional[TrapCallback] = None,
    ) -> None:
        if num_sources != 8:
            raise ValueError(
                f"num_sources must be 8 in v1.5 (one per U1-U8); got {num_sources}. "
                f"Wider source counts are a v2.0 conversation."
            )
        if log_buffer_entries < 0:
            raise ValueError(
                f"log_buffer_entries must be >= 0; got {log_buffer_entries}"
            )

        self._sources = _SOURCE_ORDER
        self._mandatory_queues: Dict[UnitId, Deque[ValidationEvent]] = {
            uid: deque() for uid in self._sources
        }
        self._rr_pointer: int = 0  # index into _sources

        self._mandatory_counts: Dict[UnitId, int] = defaultdict(int)
        self._advisory_counts: Dict[Tuple[UnitId, ValidationErrorCode], int] = defaultdict(int)

        self._trap_callback = trap_callback
        self._log_buffer: Optional[Deque[ValidationEvent]] = (
            deque(maxlen=log_buffer_entries) if log_buffer_entries > 0 else None
        )

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def submit(self, event: ValidationEvent) -> None:
        """Accept an event from any source unit and route it to a channel.

        Mandatory events go to a per-source FIFO and are drained by `step()`.
        Advisory events increment a counter immediately and (if enabled)
        land in the log buffer.
        """
        if event.routes_to_mandatory():
            self._mandatory_queues[event.unit_id].append(event)
        else:
            self._advisory_counts[(event.unit_id, event.error_code)] += 1
            if self._log_buffer is not None:
                self._log_buffer.append(event)

    def step(self) -> Optional[ValidationEvent]:
        """Drain at most one mandatory event via RR arbitration.

        Returns:
            The drained event, or None if all per-source FIFOs are empty.

        On drain: the per-source mandatory counter increments, the
        `trap_callback` (if provided) is invoked, and the event lands in
        the log buffer (if enabled). The RR pointer advances to the slot
        AFTER the drained source, so the same source cannot saturate the
        bus.
        """
        n = len(self._sources)
        for offset in range(n):
            idx = (self._rr_pointer + offset) % n
            source = self._sources[idx]
            queue = self._mandatory_queues[source]
            if queue:
                event = queue.popleft()
                self._mandatory_counts[source] += 1
                self._rr_pointer = (idx + 1) % n
                if self._trap_callback is not None:
                    self._trap_callback(event)
                if self._log_buffer is not None:
                    self._log_buffer.append(event)
                return event
        return None

    def drain_all(self) -> List[ValidationEvent]:
        """Drain every queued mandatory event via repeated `step()` calls.

        Useful for tests that don't care about cycle-by-cycle RR behavior.
        Returns the events in drain order.
        """
        drained: List[ValidationEvent] = []
        while True:
            event = self.step()
            if event is None:
                break
            drained.append(event)
        return drained

    # ------------------------------------------------------------------
    # Counters
    # ------------------------------------------------------------------

    def get_mandatory_count(self, unit_id: UnitId) -> int:
        """Per-source mandatory event drain count."""
        return self._mandatory_counts[unit_id]

    def get_advisory_count(
        self, unit_id: UnitId, error_code: ValidationErrorCode
    ) -> int:
        """Per-(unit, error_code) advisory event count."""
        return self._advisory_counts[(unit_id, error_code)]

    def total_mandatory_count(self) -> int:
        """Sum across all sources."""
        return sum(self._mandatory_counts.values())

    def total_advisory_count(self) -> int:
        """Sum across the entire (unit, error_code) matrix."""
        return sum(self._advisory_counts.values())

    # ------------------------------------------------------------------
    # Queue inspection (for tests + diagnostics)
    # ------------------------------------------------------------------

    def queue_depth(self, unit_id: UnitId) -> int:
        """Pending mandatory events from a given source."""
        return len(self._mandatory_queues[unit_id])

    def total_queued(self) -> int:
        """Pending mandatory events across all sources."""
        return sum(len(q) for q in self._mandatory_queues.values())

    # ------------------------------------------------------------------
    # Log buffer (P1)
    # ------------------------------------------------------------------

    def log_buffer_capacity(self) -> int:
        """Buffer capacity (0 = disabled)."""
        return self._log_buffer.maxlen if self._log_buffer is not None else 0

    def log_buffer_size(self) -> int:
        """Current buffer fill level."""
        return len(self._log_buffer) if self._log_buffer is not None else 0

    def log_buffer_snapshot(self) -> List[ValidationEvent]:
        """Read-only snapshot of buffer contents (oldest first)."""
        return list(self._log_buffer) if self._log_buffer is not None else []
