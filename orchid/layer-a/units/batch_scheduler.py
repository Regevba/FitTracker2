"""U4 — Batch Scheduler. FIFO queue + round-robin arbiter. Groups by tier, dispatches in waves. Max 8 concurrent, 32 queue depth. Hardware: enqueue 1 cycle, dispatch_wave 2-3 cycles."""
from collections import deque
from .types import TaskDescriptor, DispatchDecision, ModelTier, CycleCount


class BatchScheduler:
    def __init__(self, max_concurrent: int = 8, queue_depth: int = 32):
        self.max_concurrent = max_concurrent
        self.queue_depth = queue_depth
        self._queue: deque[tuple[TaskDescriptor, DispatchDecision]] = deque()
        self._cycle = 0
        self.cycle_log: list[CycleCount] = []

    def enqueue(self, task: TaskDescriptor, decision: DispatchDecision) -> bool:
        self._cycle += 1
        if len(self._queue) >= self.queue_depth:
            self.cycle_log.append(CycleCount(cycles=1, energy_pj=0.5))
            return False
        self._queue.append((task, decision))
        self.cycle_log.append(CycleCount(cycles=1, energy_pj=0.5))
        return True

    def dispatch_wave(self) -> list[tuple[TaskDescriptor, DispatchDecision]]:
        self._cycle += 3
        if not self._queue:
            self.cycle_log.append(CycleCount(cycles=1, energy_pj=0.5))
            return []
        items = list(self._queue)
        items.sort(key=lambda x: x[1].tier)
        wave = items[:self.max_concurrent]
        remaining = items[self.max_concurrent:]
        self._queue = deque(remaining)
        self.cycle_log.append(CycleCount(cycles=3, energy_pj=3.0))
        return wave

    @property
    def pending(self) -> int:
        return len(self._queue)

    @property
    def current_cycle(self) -> int:
        return self._cycle
