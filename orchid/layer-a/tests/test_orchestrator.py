"""Orchestrator tests — full pipeline integration."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from units.types import TaskDescriptor, WorkType, DesignScope

def test_pipeline_processes_single_event():
    from orchestrator import Orchestrator
    orch = Orchestrator()
    task = TaskDescriptor(work_type=WorkType.FEATURE, view_count=3, new_types_count=2, phase="implementation")
    result = orch.process(task)
    assert result.dispatch.score > 0
    assert len(result.routing.skills) >= 1
    assert result.total_cycles > 0

def test_pipeline_accumulates_cycles():
    from orchestrator import Orchestrator
    orch = Orchestrator()
    t1 = TaskDescriptor(work_type=WorkType.FIX, phase="testing")
    t2 = TaskDescriptor(work_type=WorkType.FEATURE, view_count=5, phase="implementation")
    r1 = orch.process(t1)
    r2 = orch.process(t2)
    assert r2.total_cycles > r1.total_cycles

def test_cache_warms_over_repeated_phases():
    from orchestrator import Orchestrator
    orch = Orchestrator()
    for _ in range(5):
        orch.process(TaskDescriptor(work_type=WorkType.ENHANCEMENT, phase="implementation"))
    assert orch.cache.hit_rate() > 0
