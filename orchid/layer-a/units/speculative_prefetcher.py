"""U5 — Speculative Prefetcher. Prediction table (BTB-style). Records phase transitions, predicts next phases. Hardware: 1-2 cycles prediction, 1 cycle recording. 64 entries, 4 context bits."""
from collections import defaultdict
from .types import CycleCount

class SpeculativePrefetcher:
    def __init__(self, table_size: int = 64, prefetch_ahead: int = 2):
        self.table_size = table_size
        self.prefetch_ahead = prefetch_ahead
        self._transitions: dict[str, dict[str, int]] = defaultdict(lambda: defaultdict(int))
        self._cycle = 0
        self.cycle_log: list[CycleCount] = []
        self.miss_stats: dict[str, int] = defaultdict(int)

    def record_transition(self, from_phase: str, to_phase: str) -> None:
        self._cycle += 1
        self._transitions[from_phase][to_phase] += 1
        self.cycle_log.append(CycleCount(cycles=1, energy_pj=1.0))

    def predict(self, current_phase: str) -> list[str]:
        self._cycle += 2
        self.cycle_log.append(CycleCount(cycles=2, energy_pj=2.0))
        if current_phase not in self._transitions:
            return []
        predictions = []
        phase = current_phase
        for _ in range(self.prefetch_ahead):
            if phase not in self._transitions:
                break
            successors = self._transitions[phase]
            if not successors:
                break
            best = max(successors, key=successors.get)
            predictions.append(best)
            phase = best
        return predictions

    def record_miss(self, phase: str, reason: str) -> None:
        self.miss_stats[reason] += 1

    def accuracy(self, test_sequence: list[str]) -> float:
        if len(test_sequence) < 2:
            return 0.0
        correct = 0
        total = len(test_sequence) - 1
        for i in range(total):
            preds = self.predict(test_sequence[i])
            if preds and preds[0] == test_sequence[i + 1]:
                correct += 1
        return correct / total

    @property
    def current_cycle(self) -> int:
        return self._cycle
