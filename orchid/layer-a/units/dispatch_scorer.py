"""U1 — Dispatch Scorer. Pure combinational logic. Maps CU v2 continuous factors to a complexity score (0-100) and model tier (haiku/sonnet/opus). Hardware: single clock cycle, 13-bit input bus, 9-bit output.

Scoring formula (from v6.0 CU v2):
  base = work_type weight (chore=10, fix=20, enhancement=40, feature=60)
  + view_count contribution (0-15 points)
  + new_types contribution (0-10 points, capped)
  + scope_tier (0/3/6/10 points)
  + novelty_flag (+5 points)
  Clamped to [0, 100].

Tier thresholds: score < 34 -> haiku, 34 <= score < 67 -> sonnet, score >= 67 -> opus
"""
from .types import TaskDescriptor, DispatchDecision, ModelTier, WorkType, DesignScope

TIER_THRESHOLDS = (34, 67)

_WORK_TYPE_BASE = {
    WorkType.CHORE: 10, WorkType.FIX: 20, WorkType.ENHANCEMENT: 40, WorkType.FEATURE: 60,
}

_SCOPE_POINTS = {
    DesignScope.TEXT_ONLY: 0, DesignScope.LAYOUT: 3, DesignScope.INTERACTION: 6, DesignScope.FULL_REDESIGN: 10,
}

def score(task: TaskDescriptor) -> DispatchDecision:
    raw = _WORK_TYPE_BASE[task.work_type]
    raw += min(task.view_count, 15)
    raw += min(task.new_types_count, 10)
    raw += _SCOPE_POINTS[task.scope_tier]
    if task.novelty_flag:
        raw += 5
    clamped = max(0, min(100, raw))
    if clamped < TIER_THRESHOLDS[0]:
        tier = ModelTier.HAIKU
    elif clamped < TIER_THRESHOLDS[1]:
        tier = ModelTier.SONNET
    else:
        tier = ModelTier.OPUS
    return DispatchDecision(score=clamped, tier=tier)
