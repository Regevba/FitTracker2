"""U1 Dispatch Scorer tests. Validates scoring rules match v5.2 dispatch-intelligence.json."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from units.types import TaskDescriptor, DispatchDecision, ModelTier, WorkType, DesignScope

def test_simple_chore_scores_low():
    from units.dispatch_scorer import score
    task = TaskDescriptor(work_type=WorkType.CHORE, view_count=0, new_types_count=0)
    result = score(task)
    assert result.tier == ModelTier.HAIKU
    assert result.score < 30

def test_feature_with_many_views_scores_high():
    from units.dispatch_scorer import score
    task = TaskDescriptor(work_type=WorkType.FEATURE, view_count=6, new_types_count=4, scope_tier=DesignScope.INTERACTION, novelty_flag=True)
    result = score(task)
    assert result.tier == ModelTier.OPUS
    assert result.score > 70

def test_enhancement_mid_range():
    from units.dispatch_scorer import score
    task = TaskDescriptor(work_type=WorkType.ENHANCEMENT, view_count=2, new_types_count=1, scope_tier=DesignScope.LAYOUT)
    result = score(task)
    assert result.tier == ModelTier.SONNET
    assert 30 <= result.score <= 70

def test_score_is_deterministic():
    from units.dispatch_scorer import score
    task = TaskDescriptor(work_type=WorkType.FIX, view_count=1, new_types_count=0)
    results = [score(task) for _ in range(100)]
    assert all(r == results[0] for r in results)

def test_score_range():
    from units.dispatch_scorer import score
    for wt in WorkType:
        for vc in range(0, 16, 3):
            for ntc in range(0, 16, 3):
                for scope in DesignScope:
                    for novelty in [False, True]:
                        task = TaskDescriptor(work_type=wt, view_count=vc, new_types_count=ntc, scope_tier=scope, novelty_flag=novelty)
                        result = score(task)
                        assert 0 <= result.score <= 100, f"Score {result.score} out of range for {task}"
                        assert result.tier in ModelTier

def test_tier_boundaries():
    from units.dispatch_scorer import score, TIER_THRESHOLDS
    assert TIER_THRESHOLDS == (34, 67)
