"""U6 — Coherence Unit. MESI-like protocol FSM. Max 8 writers, 4 snapshot slots. Hardware: 2-3 cycles per transition."""
from __future__ import annotations
from collections import defaultdict
from typing import Optional, Dict, Set
from .types import MESIState, CycleCount


class CoherenceUnit:
    def __init__(self, max_writers: int = 8, snapshot_slots: int = 4):
        self.max_writers = max_writers
        self.snapshot_slots = snapshot_slots
        self._state: Dict[str, MESIState] = {}
        self._owner: Dict[str, Optional[str]] = {}
        self._readers: Dict[str, Set[str]] = defaultdict(set)
        self._snapshots: Dict[str, str] = {}
        self._cycle = 0
        self.corruption_count = 0
        self.cycle_log: list[CycleCount] = []

    def get_state(self, file: str) -> MESIState:
        return self._state.get(file, MESIState.INVALID)

    def request_read(self, reader: str, file: str) -> bool:
        self._cycle += 2
        self.cycle_log.append(CycleCount(cycles=2, energy_pj=2.0))
        state = self._state.get(file, MESIState.INVALID)
        if state == MESIState.INVALID:
            self._readers[file].add(reader)
            self._state[file] = MESIState.SHARED if len(self._readers[file]) > 1 else MESIState.EXCLUSIVE
            return True
        elif state in (MESIState.SHARED, MESIState.EXCLUSIVE):
            self._readers[file].add(reader)
            if len(self._readers[file]) > 1:
                self._state[file] = MESIState.SHARED
            return True
        elif state == MESIState.MODIFIED:
            self._readers[file].add(reader)
            return True
        return True

    def request_write(self, writer: str, file: str) -> bool:
        self._cycle += 3
        self.cycle_log.append(CycleCount(cycles=3, energy_pj=3.0))
        state = self._state.get(file, MESIState.INVALID)
        if state == MESIState.MODIFIED:
            if self._owner.get(file) == writer:
                return True
            return False
        self._readers[file].discard(writer)
        self._state[file] = MESIState.MODIFIED
        self._owner[file] = writer
        return True

    def release(self, writer: str, file: str) -> None:
        self._cycle += 2
        self.cycle_log.append(CycleCount(cycles=2, energy_pj=2.0))
        if self._owner.get(file) == writer:
            self._owner[file] = None
            if len(self._readers[file]) > 1:
                self._state[file] = MESIState.SHARED
            elif self._readers[file]:
                self._state[file] = MESIState.EXCLUSIVE
            else:
                self._state[file] = MESIState.INVALID
        self._readers[file].discard(writer)

    def snapshot(self, file: str, content: str) -> bool:
        if len(self._snapshots) >= self.snapshot_slots and file not in self._snapshots:
            return False
        self._snapshots[file] = content
        return True

    def rollback(self, file: str) -> Optional[str]:
        return self._snapshots.pop(file, None)

    @property
    def current_cycle(self) -> int:
        return self._cycle
