"""Shared data types for all Orchid Layer A units.

These dataclasses mirror the hardware bus signals defined in the spec:
- TaskDescriptor: 13-bit input bus to U1 (Section 10.3)
- DispatchDecision: 9-bit output from U1 (7-bit score + 2-bit tier)
- RoutingDecision: U2 output (skill IDs + tool budget)
- CacheEntry: U3 storage unit (compressed + full views)
- TraceEvent: One line from a .jsonl trace file (Section 4)
"""
from dataclasses import dataclass, field
from enum import IntEnum
from typing import Optional


class ModelTier(IntEnum):
    HAIKU = 0    # lightweight
    SONNET = 1   # standard
    OPUS = 2     # heavyweight


class WorkType(IntEnum):
    CHORE = 0
    FIX = 1
    ENHANCEMENT = 2
    FEATURE = 3


class DesignScope(IntEnum):
    TEXT_ONLY = 0
    LAYOUT = 1
    INTERACTION = 2
    FULL_REDESIGN = 3


class MESIState(IntEnum):
    MODIFIED = 0
    EXCLUSIVE = 1
    SHARED = 2
    INVALID = 3


@dataclass(frozen=True)
class TaskDescriptor:
    """13-bit input bus to U1 Dispatch Scorer (Section 10.3)."""
    view_count: int = 0          # 4 bits (0-15)
    new_types_count: int = 0     # 4 bits (0-15)
    scope_tier: DesignScope = DesignScope.TEXT_ONLY  # 2 bits
    novelty_flag: bool = False   # 1 bit
    work_type: WorkType = WorkType.FEATURE  # 2 bits
    phase: str = "implementation"  # not part of U1 bus, used by U2


@dataclass(frozen=True)
class DispatchDecision:
    """9-bit output from U1 Dispatch Scorer."""
    score: int = 0      # 7 bits (0-100)
    tier: ModelTier = ModelTier.SONNET  # 2 bits


@dataclass(frozen=True)
class RoutingDecision:
    """U2 Skill Router output."""
    skills: tuple[str, ...] = ()
    tool_budget: int = 25
    model_tier: ModelTier = ModelTier.SONNET


@dataclass
class CacheEntry:
    """U3 Cache Controller storage unit."""
    key: str = ""
    compressed_view: str = ""    # ~200 words summary
    full_entry: str = ""         # full content
    level: str = "L1"            # L1/L2/L3
    access_count: int = 0
    last_accessed_cycle: int = 0
    dirty: bool = False


@dataclass(frozen=True)
class TraceEvent:
    """One line from a .jsonl trace file (Section 4)."""
    timestamp_ns: int = 0
    event: str = "dispatch_decision"
    task: TaskDescriptor = field(default_factory=TaskDescriptor)
    decision: Optional[DispatchDecision] = None
    cache_hits: tuple[str, ...] = ()
    cache_misses: tuple[str, ...] = ()
    latency_ms: float = 0.0


@dataclass
class CycleCount:
    """Tracks simulated hardware cycles for composite score."""
    cycles: int = 0
    energy_pj: float = 0.0  # picojoules estimate

    def add(self, cycles: int, energy_per_cycle_pj: float = 1.0) -> None:
        self.cycles += cycles
        self.energy_pj += cycles * energy_per_cycle_pj
