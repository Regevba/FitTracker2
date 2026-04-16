"""U2 Skill Router tests. Validates routing matches skill-routing.json phase_skills."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from units.types import ModelTier, RoutingDecision


def test_research_phase_routes_to_research_cx():
    from units.skill_router import route
    result = route(score=80, tier=ModelTier.OPUS, phase="research")
    assert result.skills == ("research", "cx")
    assert result.model_tier == ModelTier.OPUS


def test_implementation_phase_routes_to_dev_design():
    from units.skill_router import route
    result = route(score=50, tier=ModelTier.SONNET, phase="implementation")
    assert result.skills == ("dev", "design")
    assert result.model_tier == ModelTier.SONNET


def test_tasks_phase_routes_to_pm_workflow():
    from units.skill_router import route
    result = route(score=30, tier=ModelTier.HAIKU, phase="tasks")
    assert result.skills == ("pm-workflow",)
    assert result.model_tier == ModelTier.SONNET  # phase overrides tier


def test_unknown_phase_returns_fallback():
    from units.skill_router import route
    result = route(score=50, tier=ModelTier.SONNET, phase="nonexistent")
    assert result.skills == ("pm-workflow",)
    assert result.model_tier == ModelTier.OPUS  # fallback = opus


def test_tool_budget_scales_with_tier():
    from units.skill_router import route
    # Budget comes from the phase's model_tier, not the input tier.
    # tasks phase_tier = SONNET → budget 25
    haiku_result = route(score=10, tier=ModelTier.HAIKU, phase="tasks")
    # implementation phase_tier = SONNET → budget 25
    sonnet_result = route(score=50, tier=ModelTier.SONNET, phase="implementation")
    # review phase_tier = OPUS → budget 50
    opus_result = route(score=80, tier=ModelTier.OPUS, phase="review")
    assert haiku_result.tool_budget == 25   # tasks phase = SONNET budget
    assert sonnet_result.tool_budget == 25  # implementation phase = SONNET budget
    assert opus_result.tool_budget == 50    # review phase = OPUS budget


def test_all_phases_have_at_least_one_skill():
    from units.skill_router import route, PHASE_SKILLS
    for phase in PHASE_SKILLS:
        result = route(score=50, tier=ModelTier.SONNET, phase=phase)
        assert len(result.skills) >= 1, f"Phase {phase} has no skills"
