"""Shared data types for all Orchid Layer A units.

These dataclasses mirror the hardware bus signals defined in the spec:
- TaskDescriptor: 13-bit input bus to U1 (Section 10.3)
- DispatchDecision: 9-bit output from U1 (7-bit score + 2-bit tier)
- RoutingDecision: U2 output (skill IDs + tool budget)
- CacheEntry: U3 storage unit (compressed + full views)
- TraceEvent: One line from a .jsonl trace file (Section 4)

v1.5 additions (per docs/superpowers/specs/2026-05-03-orchid-v1-5-design.md):
- Tier: 2-bit data-quality tier (T1/T2/T3) propagated across TileLink user[1:0]
- AssertionMode: 4-bit per-unit advisory→enforced flip register
- UnitId: 4-bit unit identifier for ValidationEvent
- ValidationEvent: U9 Validation Bus message format
- ValidationErrorCode: 5-bit error code allocation (Appendix A)
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


# v1.5 — define Tier early so TaskDescriptor can default it (spec §3).
class Tier(IntEnum):
    """Data-quality tier propagated across TileLink user[1:0] (v1.5 spec §3).

    Wire encoding (immutable from v1.5 onward):
        00 -> reserved (must-be-zero on transmit, ignore on receive)
        01 -> T1 Instrumented (high confidence)
        10 -> T2 Declared (medium confidence) — default for v1 backward compat
        11 -> T3 Narrative (low confidence)

    Worst-case-on-output: max(Tier) returns the LOWEST confidence
    (T3 > T2 > T1) per spec §3.
    """
    T1 = 1
    T2 = 2
    T3 = 3

    @classmethod
    def reserved(cls) -> int:
        return 0


@dataclass(frozen=True)
class TaskDescriptor:
    """13-bit input bus to U1 Dispatch Scorer (Section 10.3).

    v1.5 extension: `data_tier` is a 2-bit data-quality tier (T1/T2/T3)
    that propagates across TileLink `user[1:0]` (v1.5 spec §3). It is
    independent of `scope_tier` (DesignScope) and `tier` in
    DispatchDecision (ModelTier). The default is T2 (Declared) so existing
    v1 traces without an explicit tier replay correctly.
    """
    view_count: int = 0          # 4 bits (0-15)
    new_types_count: int = 0     # 4 bits (0-15)
    scope_tier: DesignScope = DesignScope.TEXT_ONLY  # 2 bits
    novelty_flag: bool = False   # 1 bit
    work_type: WorkType = WorkType.FEATURE  # 2 bits
    phase: str = "implementation"  # not part of U1 bus, used by U2
    data_tier: Tier = Tier.T2   # 2 bits — v1.5 spec §3


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


# ============================================================================
# v1.5 additions — per spec §3, §5, §6, §2.2, Appendix A
# (Tier defined earlier in the file so TaskDescriptor can default it.)
# ============================================================================


class AssertionMode(IntEnum):
    """Per-unit advisory→enforced flip register (spec §5).

    4-bit encoding. Bits [1:0] are locked from v1.5 onward.
    Bits [3:2] reserved for v2.0+.
    """
    OFF = 0          # No-op. Counter doesn't increment. Test/burn-in only.
    LOG = 1          # Counter increments. No trap. (default on reset)
    LOG_FATAL = 2    # Counter increments. Raises trap on receipt.
    LOG_STICKY = 3   # Counter increments + sticky bit set. No trap.


class UnitId(IntEnum):
    """4-bit unit identifier for ValidationEvent (spec §2.2)."""
    U1 = 1  # Dispatch Scorer
    U2 = 2  # Skill Router
    U3 = 3  # Cache Controller
    U4 = 4  # Batch Scheduler
    U5 = 5  # Speculative Prefetcher
    U6 = 6  # Coherence Unit
    U7 = 7  # Systolic Array
    U8 = 8  # Patrol Scrubber (v1.5)
    U9 = 9  # Validation Bus (v1.5)


class ValidationErrorCode(IntEnum):
    """5-bit error code allocation (spec Appendix A).

    Codes 0x10-0x1F reserved for v2.0+. Code 0x00 must not be used.
    """
    LOW_TIER_INPUT = 0x01           # U1 — input tier below u1_min_tier
    DISPATCH_TIMEOUT = 0x02         # U1 — score not produced within budget
    LUT_PARITY = 0x03               # U2 — skill-router LUT parity violation
    LUT_MISS = 0x04                 # U2 — skill not found in LUT
    CACHE_TIER_MISMATCH = 0x05      # U3 — scratchpad tier inconsistent with input
    PMU_OVERFLOW = 0x06             # U3 — selected counter overflowed
    FIFO_INVARIANT = 0x07           # U4 — head>tail or tail>depth
    TIER_PRIORITY_STARVE = 0x08     # U4 — T1 batch waited > threshold (P1 advisory)
    MISPREDICT_BURST = 0x09         # U5 — mispredict rate exceeded threshold
    MESI_INVARIANT = 0x0A           # U6 — MESI state vector violates invariant
    TILELINK_USER_NONZERO = 0x0B    # U6 — reserved user[7:2] non-zero (v1.5)
    SYSTOLIC_TIER_DOWNGRADE = 0x0C  # U7 — output tier downgraded (informational)
    PATROL_PERIOD_NO_JITTER = 0x0D  # U8 — period configured without jitter
    PATROL_VIOLATION = 0x0E         # U8 — patrol scrubber detected invariant break
    ARBITER_STARVATION = 0x0F       # U9 — mandatory-channel source starved


class ValidationSeverity(IntEnum):
    """2-bit severity field on ValidationEvent (spec §2.2).

    Distinct from is_advisory tag — severity hints intended handling;
    is_advisory routes the event to the advisory channel regardless.
    """
    ADVISORY_ONLY = 0   # advisory channel only, no counter
    LOG_COUNTER = 1     # log + counter increment
    LOG_TRAP = 2        # log + raises trap (mandatory channel)
    RESERVED = 3        # reserved for v2.0+


@dataclass(frozen=True)
class ValidationEvent:
    """U9 Validation Bus message (spec §2.2).

    Wire-level: 4-bit unit_id + 8-bit error_code + 2-bit severity + 1-bit
    is_advisory + 32-bit payload = 47 bits transmitted per event.
    """
    unit_id: UnitId
    error_code: ValidationErrorCode
    severity: ValidationSeverity = ValidationSeverity.LOG_COUNTER
    is_advisory: bool = False  # tag overrides severity for routing
    payload: int = 0           # 32-bit error-specific (observed value, expected, etc.)

    def routes_to_mandatory(self) -> bool:
        """True iff this event raises a trap (mandatory channel + LOG_TRAP)."""
        if self.is_advisory:
            return False
        return self.severity == ValidationSeverity.LOG_TRAP
