"""U6 Coherence Unit tests. MESI-like FSM. Max 8 writers, 4 snapshot slots. Zero corruption across 10,000 random scenarios."""
import sys, os, random
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from units.types import MESIState


def test_exclusive_write():
    from units.coherence_unit import CoherenceUnit
    cu = CoherenceUnit(max_writers=8, snapshot_slots=4)
    assert cu.request_write("writer_0", "file_a") is True
    assert cu.get_state("file_a") == MESIState.MODIFIED


def test_shared_read():
    from units.coherence_unit import CoherenceUnit
    cu = CoherenceUnit(max_writers=8, snapshot_slots=4)
    cu.request_read("reader_0", "file_a")
    cu.request_read("reader_1", "file_a")
    assert cu.get_state("file_a") == MESIState.SHARED


def test_write_invalidates_shared():
    from units.coherence_unit import CoherenceUnit
    cu = CoherenceUnit(max_writers=8, snapshot_slots=4)
    cu.request_read("reader_0", "file_a")
    cu.request_read("reader_1", "file_a")
    assert cu.get_state("file_a") == MESIState.SHARED
    assert cu.request_write("writer_0", "file_a") is True
    assert cu.get_state("file_a") == MESIState.MODIFIED


def test_concurrent_write_blocked():
    from units.coherence_unit import CoherenceUnit
    cu = CoherenceUnit(max_writers=8, snapshot_slots=4)
    cu.request_write("writer_0", "file_a")
    assert cu.request_write("writer_1", "file_a") is False


def test_release_allows_next_writer():
    from units.coherence_unit import CoherenceUnit
    cu = CoherenceUnit(max_writers=8, snapshot_slots=4)
    cu.request_write("writer_0", "file_a")
    cu.release("writer_0", "file_a")
    assert cu.request_write("writer_1", "file_a") is True


def test_snapshot_and_rollback():
    from units.coherence_unit import CoherenceUnit
    cu = CoherenceUnit(max_writers=8, snapshot_slots=4)
    cu.request_write("w0", "f1")
    cu.snapshot("f1", "original content")
    cu.release("w0", "f1")
    restored = cu.rollback("f1")
    assert restored == "original content"


def test_no_corruption_under_stress():
    from units.coherence_unit import CoherenceUnit
    cu = CoherenceUnit(max_writers=8, snapshot_slots=4)
    random.seed(42)
    files = [f"file_{i}" for i in range(5)]
    writers = [f"writer_{i}" for i in range(8)]
    for _ in range(10_000):
        op = random.choice(["read", "write", "release"])
        writer = random.choice(writers)
        file = random.choice(files)
        if op == "read":
            cu.request_read(writer, file)
        elif op == "write":
            cu.request_write(writer, file)
        elif op == "release":
            cu.release(writer, file)
    assert cu.corruption_count == 0
