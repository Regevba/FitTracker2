"""U4 Batch Scheduler tests. FIFO queue + round-robin arbiter. Groups tasks by tier, dispatches in waves. Max 8 concurrent slots, 32 queue depth."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from units.types import TaskDescriptor, DispatchDecision, ModelTier, WorkType

def test_enqueue_and_dispatch_single():
    from units.batch_scheduler import BatchScheduler
    bs = BatchScheduler(max_concurrent=8, queue_depth=32)
    task = TaskDescriptor(work_type=WorkType.FIX)
    decision = DispatchDecision(score=20, tier=ModelTier.HAIKU)
    bs.enqueue(task, decision)
    wave = bs.dispatch_wave()
    assert len(wave) == 1
    assert wave[0][1].tier == ModelTier.HAIKU

def test_groups_by_tier():
    from units.batch_scheduler import BatchScheduler
    bs = BatchScheduler(max_concurrent=8, queue_depth=32)
    for i in range(3):
        bs.enqueue(TaskDescriptor(work_type=WorkType.CHORE), DispatchDecision(score=10, tier=ModelTier.HAIKU))
    for i in range(2):
        bs.enqueue(TaskDescriptor(work_type=WorkType.FEATURE), DispatchDecision(score=80, tier=ModelTier.OPUS))
    wave = bs.dispatch_wave()
    tiers = [d.tier for _, d in wave]
    haiku_indices = [i for i, t in enumerate(tiers) if t == ModelTier.HAIKU]
    opus_indices = [i for i, t in enumerate(tiers) if t == ModelTier.OPUS]
    assert max(haiku_indices) < min(opus_indices)

def test_respects_max_concurrent():
    from units.batch_scheduler import BatchScheduler
    bs = BatchScheduler(max_concurrent=4, queue_depth=32)
    for i in range(10):
        bs.enqueue(TaskDescriptor(work_type=WorkType.FIX), DispatchDecision(score=20, tier=ModelTier.HAIKU))
    wave = bs.dispatch_wave()
    assert len(wave) == 4
    assert bs.pending == 6

def test_queue_depth_limit():
    from units.batch_scheduler import BatchScheduler
    bs = BatchScheduler(max_concurrent=8, queue_depth=4)
    for i in range(6):
        bs.enqueue(TaskDescriptor(work_type=WorkType.CHORE), DispatchDecision(score=5, tier=ModelTier.HAIKU))
    assert bs.pending == 4

def test_empty_dispatch_returns_empty():
    from units.batch_scheduler import BatchScheduler
    bs = BatchScheduler(max_concurrent=8, queue_depth=32)
    wave = bs.dispatch_wave()
    assert wave == []
