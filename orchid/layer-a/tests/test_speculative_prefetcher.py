"""U5 Speculative Prefetcher tests. Prediction table (BTB-style). 64 entries, 4 context bits. Target: >=70% accuracy on deterministic sequences."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

def test_predict_after_learning():
    from units.speculative_prefetcher import SpeculativePrefetcher
    sp = SpeculativePrefetcher(table_size=64, prefetch_ahead=2)
    for _ in range(5):
        sp.record_transition("research", "prd")
    predictions = sp.predict("research")
    assert "prd" in predictions

def test_predict_unknown_phase():
    from units.speculative_prefetcher import SpeculativePrefetcher
    sp = SpeculativePrefetcher(table_size=64, prefetch_ahead=2)
    predictions = sp.predict("never_seen")
    assert predictions == []

def test_prefetch_ahead_limit():
    from units.speculative_prefetcher import SpeculativePrefetcher
    sp = SpeculativePrefetcher(table_size=64, prefetch_ahead=2)
    sp.record_transition("a", "b")
    sp.record_transition("b", "c")
    sp.record_transition("c", "d")
    predictions = sp.predict("a")
    assert len(predictions) <= 2

def test_accuracy_on_deterministic_sequence():
    from units.speculative_prefetcher import SpeculativePrefetcher
    sp = SpeculativePrefetcher(table_size=64, prefetch_ahead=1)
    sequence = ["research", "prd", "tasks", "implementation", "testing", "review", "merge"]
    for _ in range(5):
        for i in range(len(sequence) - 1):
            sp.record_transition(sequence[i], sequence[i + 1])
    correct = 0
    total = len(sequence) - 1
    for i in range(total):
        preds = sp.predict(sequence[i])
        if preds and preds[0] == sequence[i + 1]:
            correct += 1
    accuracy = correct / total
    assert accuracy >= 0.7, f"Accuracy {accuracy:.1%} < 70%"

def test_context_aware_miss_recording():
    from units.speculative_prefetcher import SpeculativePrefetcher
    sp = SpeculativePrefetcher(table_size=64, prefetch_ahead=1)
    sp.record_miss("implementation", "wrong_context")
    assert sp.miss_stats["wrong_context"] == 1
