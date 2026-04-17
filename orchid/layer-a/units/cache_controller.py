"""U3 — Cache Controller. Scratchpad SRAM with LRU eviction and compression. 15 entries, 48KB scratchpad + 16KB prefetch staging. Hardware: multi-cycle (read: 1-2, write: 2-3, expand: 3-5 cycles)."""
from __future__ import annotations
from collections import OrderedDict
from typing import Optional
from .types import CacheEntry, CycleCount

class CacheController:
    def __init__(self, max_entries: int = 15):
        self.max_entries = max_entries
        self._store: OrderedDict[str, CacheEntry] = OrderedDict()
        self._cycle = 0
        self.stats = {"L1_hits": 0, "L1_misses": 0, "L2_hits": 0, "L2_misses": 0, "L3_hits": 0, "L3_misses": 0}
        self.cycle_log: list[CycleCount] = []

    def get(self, key: str) -> Optional[CacheEntry]:
        self._cycle += 2
        if key in self._store:
            self._store.move_to_end(key)
            entry = self._store[key]
            entry.access_count += 1
            entry.last_accessed_cycle = self._cycle
            level_key = f"{entry.level}_hits"
            if level_key in self.stats:
                self.stats[level_key] += 1
            else:
                self.stats["L1_hits"] += 1
            self.cycle_log.append(CycleCount(cycles=2, energy_pj=2.0))
            return entry
        self.stats["L1_misses"] += 1
        self.cycle_log.append(CycleCount(cycles=2, energy_pj=2.0))
        return None

    def put(self, entry: CacheEntry) -> Optional[str]:
        self._cycle += 3
        evicted = None
        if entry.key in self._store:
            self._store.move_to_end(entry.key)
            self._store[entry.key] = entry
        else:
            if len(self._store) >= self.max_entries:
                evicted_key, _ = self._store.popitem(last=False)
                evicted = evicted_key
            self._store[entry.key] = entry
        entry.last_accessed_cycle = self._cycle
        self.cycle_log.append(CycleCount(cycles=3, energy_pj=3.0))
        return evicted

    def expand(self, key: str) -> Optional[str]:
        self._cycle += 5
        if key in self._store:
            self._store.move_to_end(key)
            self.cycle_log.append(CycleCount(cycles=5, energy_pj=5.0))
            return self._store[key].full_entry
        self.cycle_log.append(CycleCount(cycles=5, energy_pj=5.0))
        return None

    def hit_rate(self) -> float:
        total_hits = self.stats["L1_hits"] + self.stats["L2_hits"] + self.stats["L3_hits"]
        total_misses = self.stats["L1_misses"] + self.stats["L2_misses"] + self.stats["L3_misses"]
        total = total_hits + total_misses
        return total_hits / total if total > 0 else 0.0

    @property
    def current_cycle(self) -> int:
        return self._cycle

    @property
    def size(self) -> int:
        return len(self._store)
