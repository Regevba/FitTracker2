"""U2 — Skill Router. ROM-based lookup table + priority decoder.

Maps phase to skills + tool budget. The phase's model_tier overrides the
input tier — the phase knows better than the scorer what resources it needs.
Budget is derived from the resolved phase_tier, not the raw input tier.

Hardware analogy: 1-2 clock cycles (combinational ROM lookup + mux).
"""
from .types import ModelTier, RoutingDecision

# Extracted directly from .claude/shared/skill-routing.json phase_skills.
# Each entry: phase → (skills, phase_tier)
# phase_tier overrides the input tier and determines the tool budget.
PHASE_SKILLS: dict[str, tuple[tuple[str, ...], ModelTier]] = {
    "research":            (("research", "cx"),            ModelTier.OPUS),
    "prd":                 (("pm-workflow", "analytics"),  ModelTier.OPUS),
    "tasks":               (("pm-workflow",),              ModelTier.SONNET),
    "ux_or_integration":   (("ux", "design"),              ModelTier.OPUS),
    "implementation":      (("dev", "design"),             ModelTier.SONNET),
    "testing":             (("qa", "analytics"),           ModelTier.SONNET),
    "review":              (("dev", "qa"),                 ModelTier.OPUS),
    "merge":               (("release", "dev"),            ModelTier.SONNET),
    "documentation":       (("marketing", "cx"),           ModelTier.SONNET),
    "learn":               (("cx", "analytics", "ops"),   ModelTier.SONNET),
}

# Tool budget per resolved tier (from dispatch-intelligence.json model_routing).
_TOOL_BUDGETS: dict[ModelTier, int] = {
    ModelTier.HAIKU:  10,
    ModelTier.SONNET: 25,
    ModelTier.OPUS:   50,
}

# Fallback for unknown phases: safe default skills, OPUS tier for coverage.
_FALLBACK: tuple[tuple[str, ...], ModelTier] = (("pm-workflow",), ModelTier.OPUS)


def route(score: int, tier: ModelTier, phase: str) -> RoutingDecision:
    """ROM lookup: resolve skills and tool budget for the given phase.

    Args:
        score: Dispatch score from U1 (0-100). Not used for routing; kept on
               the bus for downstream trace logging.
        tier:  Input model tier from U1. Overridden by the phase's own tier.
        phase: PM workflow phase name (e.g. "research", "implementation").

    Returns:
        RoutingDecision with skills, tool_budget, and resolved model_tier.
    """
    skills, phase_tier = PHASE_SKILLS.get(phase, _FALLBACK)
    budget = _TOOL_BUDGETS[phase_tier]
    return RoutingDecision(skills=skills, tool_budget=budget, model_tier=phase_tier)
